#!/usr/bin/env python3
"""Conferência estática dos fluxos do n8n deste diretório (24/10/2026). Só leitura, só biblioteca padrão.

Uso:  python3 -I conferir-fluxos.py [arquivo.json ...]     (sem argumentos: todos os .json da pasta)

O que confere, em cada fluxo:
- JSON válido com name, nodes (lista) e connections (objeto); nomes de nó únicos.
- Toda ligação sai de um nó que existe e chega num nó que existe; toda referência $('Nome') nas expressões aponta
  para um nó do fluxo; nó Switch não tem mais saídas ligadas do que regras + 1 (a extra).
- Nenhum nó dos tipos travados na VPS (Execute Command, Read/Write File, Local File Trigger) e nenhum nó de pacote
  comunitário; nó de código sem require() e sem $env (N8N_BLOCK_ENV_ACCESS_IN_NODE=true).
- Credenciais só por referência (id/nome), nunca com valor; nenhum texto com cara de segredo (chave do Resend,
  sb_secret_, JWT, 64 hex do token); nenhum e-mail fora dos domínios de exemplo/remetente.
- Nó Webhook com autenticação (não "none") e caminho sem sufixo secreto (o sufixo só existe na produção).
- Fluxo que recebe a Assiny: execuções com sucesso não são guardadas (INT-08).
Sai com código 1 se achar problema.
"""
import glob
import json
import os
import re
import sys

TRAVADOS = {"n8n-nodes-base.executeCommand", "n8n-nodes-base.readWriteFile", "n8n-nodes-base.localFileTrigger"}
DOMINIOS_OK = ("crystalnowpp.com.br", "exemplo.com.br", "resend.dev", "exemplo.com")
SEGREDOS = [
    (re.compile(r"\bre_[A-Za-z0-9_-]{20,}"), "chave do Resend"),
    (re.compile(r"\bsb_(secret|publishable)_[A-Za-z0-9_-]{10,}"), "chave do Supabase"),
    (re.compile(r"\beyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{10,}"), "JWT"),
    (re.compile(r"\b[0-9a-f]{64}\b"), "token de 64 hex"),
    (re.compile(r"assiny-compras-[0-9a-f]{16,}"), "sufixo secreto do webhook"),
]
EMAIL = re.compile(r"[A-Za-z0-9._%+-]+@([A-Za-z0-9.-]+\.[A-Za-z]{2,})")
REF = re.compile(r"\$\(\s*'([^']+)'\s*\)")


def textos(o):
    if isinstance(o, str):
        yield o
    elif isinstance(o, dict):
        for v in o.values():
            yield from textos(v)
    elif isinstance(o, list):
        for v in o:
            yield from textos(v)


def conferir(caminho):
    problemas = []
    try:
        with open(caminho, encoding="utf-8") as f:
            wf = json.load(f)
    except (OSError, ValueError) as e:
        return [f"JSON inválido: {e}"]
    if not isinstance(wf.get("name"), str) or not isinstance(wf.get("nodes"), list) or not isinstance(wf.get("connections"), dict):
        return ["faltam name/nodes/connections"]
    nomes = [n.get("name") for n in wf["nodes"]]
    if len(set(nomes)) != len(nomes):
        problemas.append("nome de nó repetido")
    por_nome = {n.get("name"): n for n in wf["nodes"]}
    tipos = {n.get("name"): n.get("type", "") for n in wf["nodes"]}

    for de, saidas in wf["connections"].items():
        if de not in por_nome:
            problemas.append(f"ligação sai de nó inexistente: {de}")
        lista = (saidas or {}).get("main") or []
        if tipos.get(de) == "n8n-nodes-base.switch":
            regras = len((((por_nome[de].get("parameters") or {}).get("rules") or {}).get("values")) or [])
            extra = 1 if (((por_nome[de].get("parameters") or {}).get("options") or {}).get("fallbackOutput") == "extra") else 0
            if len(lista) > regras + extra:
                problemas.append(f'"{de}": {len(lista)} saídas ligadas para {regras} regras (+{extra} extra)')
        for saida in lista:
            for l in saida or []:
                if l.get("node") not in por_nome:
                    problemas.append(f'ligação de "{de}" chega em nó inexistente: {l.get("node")}')

    for n in wf["nodes"]:
        nome, tipo = n.get("name"), n.get("type", "")
        if tipo in TRAVADOS:
            problemas.append(f'"{nome}" usa nó travado na VPS: {tipo}')
        if not tipo.startswith("n8n-nodes-base.") and not tipo.startswith("@n8n/"):
            problemas.append(f'"{nome}" usa nó de fora do pacote padrão: {tipo}')
        for cred in (n.get("credentials") or {}).values():
            if isinstance(cred, dict) and set(cred) - {"id", "name"}:
                problemas.append(f'"{nome}": credencial com campos além de id/nome')
        if tipo == "n8n-nodes-base.code":
            js = (n.get("parameters") or {}).get("jsCode", "")
            if re.search(r"\brequire\s*\(", js):
                problemas.append(f'"{nome}": require() no nó de código')
            if "$env" in js:
                problemas.append(f'"{nome}": $env no nó de código')
        if tipo == "n8n-nodes-base.webhook":
            p = n.get("parameters") or {}
            # GET de saúde (sem corpo) pode ficar sem autenticação; qualquer webhook que recebe dados, não.
            if p.get("authentication") in (None, "", "none") and str(p.get("httpMethod", "GET")).upper() != "GET":
                problemas.append(f'"{nome}": webhook sem autenticação')
            if re.search(r"-[0-9a-f]{16,}$", str(p.get("path", ""))):
                problemas.append(f'"{nome}": o caminho do webhook traz o sufixo secreto da produção')
        for t in textos(n.get("parameters")):
            for ref in REF.findall(t):
                if ref not in por_nome:
                    problemas.append(f'"{nome}" referencia $(\'{ref}\') que não existe')

    for t in textos(wf):
        for rx, rotulo in SEGREDOS:
            if rx.search(t):
                problemas.append(f"texto com cara de {rotulo}")
        for dom in EMAIL.findall(t):
            if not dom.lower().endswith(DOMINIOS_OK):
                problemas.append(f"e-mail fora dos domínios de exemplo: @{dom}")

    # INT-08: fluxo que leva dado de aluna ao Supabase ou à API do app não guarda execuções com sucesso.
    urls = " ".join(str((n.get("parameters") or {}).get("url", "")) for n in wf["nodes"])
    if ("supabase.co" in urls or "api.crystalnowpp.com.br" in urls) \
            and (wf.get("settings") or {}).get("saveDataSuccessExecution") != "none":
        problemas.append("fluxo com dado de aluna guarda execuções com sucesso (INT-08): settings.saveDataSuccessExecution deve ser 'none'")
    return sorted(set(problemas))


def main():
    pasta = os.path.dirname(os.path.abspath(__file__))
    arquivos = sys.argv[1:] or sorted(glob.glob(os.path.join(pasta, "*.json")))
    ruim = False
    for a in arquivos:
        probs = conferir(a)
        print(("PROBLEMA " if probs else "ok       ") + os.path.basename(a))
        for p in probs:
            print("   - " + p)
        ruim = ruim or bool(probs)
    sys.exit(1 if ruim else 0)


if __name__ == "__main__":
    main()
