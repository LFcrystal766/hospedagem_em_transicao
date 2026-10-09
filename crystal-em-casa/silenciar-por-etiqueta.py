#!/usr/bin/env python3
"""Silencia (ou religa) a Crystal do WhatsApp para quem tem uma etiqueta no LendChat (09/10/2026).

Uso, na VPS:
    python3 silenciar-por-etiqueta.py            # silenciar
    python3 silenciar-por-etiqueta.py religar    # desfazer, mesma etiqueta

1. Pede o token de acesso do LendChat (Perfil > Access Token), sem mostrar na tela.
2. Lista as etiquetas da conta e pergunta qual usar.
3. Junta os telefones dos CONTATOS e das CONVERSAS com a etiqueta (o LendChat é um Chatwoot).
4. Mostra só a contagem e pede confirmação ("SIM").
5. Chama app_whatsapp_silenciar_telefones no Supabase (crystal-em-casa/supabase/
   app_whatsapp_silenciar_telefones.sql) em lotes de 1000, com a service_role de
   /root/crystal/app/.externos.

Nunca imprime telefone, nome nem token: só contagens e códigos HTTP. Só biblioteca padrão.
"""

import getpass
import http.client
import json
import math
import os
import re
import sys
import time
import urllib.error
import urllib.request

LENDCHAT = os.environ.get("LENDCHAT_URL", "https://lendchat.agencialendaria.ai").rstrip("/")
EXTERNOS = os.environ.get("CRYSTAL_EXTERNOS", "/root/crystal/app/.externos")
LOTE = 1000
MAX_PAGINAS = 2000
PAUSA_S = float(os.environ.get("PAUSA_S", "0.2"))


class Falha(Exception):
    pass


def pedir(metodo, url, cabecalhos, corpo=None):
    dados = json.dumps(corpo).encode() if corpo is not None else None
    req = urllib.request.Request(url, data=dados, method=metodo, headers={
        "accept": "application/json", "content-type": "application/json", **cabecalhos})
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            texto = r.read().decode()
    except urllib.error.HTTPError as e:
        raise Falha(f"HTTP {e.code} em {url.split('?')[0].replace(LENDCHAT, '')}") from None
    except urllib.error.URLError as e:
        raise Falha(f"sem resposta ({type(e.reason).__name__})") from None
    except (OSError, http.client.HTTPException) as e:
        raise Falha(f"conexão caiu ({type(e).__name__})") from None
    try:
        return json.loads(texto) if texto.strip() else None
    except ValueError:
        raise Falha("resposta não é JSON") from None


def digitos(tel):
    d = re.sub(r"\D", "", tel or "")
    return d if len(d) >= 10 else None


def paginar(url_base, cab, etiqueta, tamanho, extrair):
    filtro = {"payload": [{"attribute_key": "labels", "filter_operator": "equal_to",
                           "values": [etiqueta], "query_operator": None}]}
    achados, itens, pagina, total = set(), 0, 1, None
    while pagina <= MAX_PAGINAS:
        r = pedir("POST", f"{url_base}?page={pagina}", cab, filtro) or {}
        lista = r.get("payload") or []
        if total is None:
            meta = r.get("meta") or {}
            total = meta.get("count", meta.get("all_count"))
        if not lista:
            break
        for item in lista:
            itens += 1
            d = digitos(extrair(item))
            if d:
                achados.add(d)
        if total is not None and pagina >= math.ceil(int(total) / tamanho):
            break
        pagina += 1
        time.sleep(PAUSA_S)
    return achados, itens


def ler_externos():
    valores = {}
    with open(EXTERNOS) as f:
        for linha in f:
            nome, _, valor = linha.strip().partition("=")
            valores[nome] = valor.strip().strip('"').strip("'")
    url, chave = valores.get("SUPABASE_URL", ""), valores.get("SUPABASE_SERVICE_ROLE_KEY", "")
    if not url or not chave:
        raise Falha(f"SUPABASE_URL ou SUPABASE_SERVICE_ROLE_KEY faltando em {EXTERNOS}")
    return url.rstrip("/"), chave


def main():
    religar = len(sys.argv) > 1 and sys.argv[1] == "religar"
    acao = "RELIGAR" if religar else "SILENCIAR"
    token = getpass.getpass("Token de acesso do LendChat (Perfil > Access Token; não aparece na tela): ").strip()
    if not token:
        raise Falha("token vazio")
    cab = {"api_access_token": token}

    contas = (pedir("GET", f"{LENDCHAT}/api/v1/profile", cab) or {}).get("accounts") or []
    if not contas:
        raise Falha("o token não dá acesso a nenhuma conta do LendChat")
    if len(contas) == 1:
        conta = contas[0]
    else:
        for i, c in enumerate(contas, 1):
            print(f"  {i}. {c.get('name')} (id {c.get('id')})")
        conta = contas[int(input("Número da conta: ").strip()) - 1]
    base = f"{LENDCHAT}/api/v1/accounts/{conta['id']}"

    etiquetas = sorted({(e.get("title") or "").strip() for e in
                        ((pedir("GET", f"{base}/labels", cab) or {}).get("payload") or []) if e.get("title")})
    print(f"Etiquetas da conta {conta.get('name')}:")
    for i, t in enumerate(etiquetas, 1):
        print(f"  {i}. {t}")
    escolha = input("Número ou nome da etiqueta: ").strip()
    etiqueta = etiquetas[int(escolha) - 1] if escolha.isdigit() and 0 < int(escolha) <= len(etiquetas) else escolha.lower()
    if etiqueta not in etiquetas:
        raise Falha("etiqueta não existe na conta")

    print("Buscando contatos e conversas com a etiqueta (só contagens)...")
    # Etiqueta pode estar no contato, na conversa ou nos dois: junta os dois lados. Um lado
    # que o LendChat recusar (versão sem o filtro) não derruba o outro.
    falhas = []
    try:
        de_contatos, n_contatos = paginar(f"{base}/contacts/filter", cab, etiqueta, 15,
                                          lambda c: c.get("phone_number"))
    except Falha as e:
        de_contatos, n_contatos = set(), f"não deu ({e})"
        falhas.append(e)
    try:
        de_conversas, n_conversas = paginar(f"{base}/conversations/filter", cab, etiqueta, 25,
                                            lambda c: ((c.get("meta") or {}).get("sender") or {}).get("phone_number"))
    except Falha as e:
        de_conversas, n_conversas = set(), f"não deu ({e})"
        falhas.append(e)
    if len(falhas) == 2:
        raise Falha(f"o LendChat recusou as duas buscas ({falhas[0]})")
    telefones = sorted(de_contatos | de_conversas)
    token = cab = None
    print(f"  contatos com a etiqueta: {n_contatos} | conversas com a etiqueta: {n_conversas}")
    print(f"  telefones diferentes (10+ dígitos): {len(telefones)}")
    if not telefones:
        print("Nada a fazer.")
        return
    if input(f"{acao} a Crystal do WhatsApp para esses {len(telefones)} números? Digite SIM: ").strip() != "SIM":
        print("Cancelado. Nada mudou.")
        return

    url, chave = ler_externos()
    cab_sb = {"apikey": chave, "authorization": f"Bearer {chave}"}
    soma = {"telefones": 0, "achados": 0, "leads": 0}
    for i in range(0, len(telefones), LOTE):
        r = pedir("POST", f"{url}/rest/v1/rpc/app_whatsapp_silenciar_telefones", cab_sb,
                  {"p_telefones": telefones[i:i + LOTE], "p_silenciar": not religar}) or {}
        for k in soma:
            soma[k] += int(r.get(k) or 0)
        print(f"  lote {i // LOTE + 1}: ok")
    chave = cab_sb = None
    print(f"Feito ({acao}): telefones válidos {soma['telefones']} | conversas do WhatsApp achadas "
          f"{soma['achados']} | conversas que mudaram {soma['leads']}")


if __name__ == "__main__":
    try:
        main()
    except Falha as e:
        print(f"ERRO: {e}. Nada foi alterado depois deste ponto.")
        sys.exit(1)
    except (KeyboardInterrupt, EOFError):
        print("\nInterrompido.")
        sys.exit(130)
