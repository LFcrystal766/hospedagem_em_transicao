#!/usr/bin/env python3
"""Liga o repasse do pacote de imagens no fluxo "Crystal · compra e reembolso da Assiny" (13/10/2026).

Uso, na VPS, como root:
    python3 compra-assiny-imagens.py             # acrescenta os 2 nós, reimporta, reativa e confere
    python3 compra-assiny-imagens.py --testar    # só confere (leitura): nós, credencial, ativo, webhook
    python3 compra-assiny-imagens.py --voltar    # reimporta a cópia mais recente (de antes da mudança)
    python3 compra-assiny-imagens.py --voltar /root/crystal/n8n-copias/compra-assiny-AAAAMMDD-HHMMSS.json

O que muda no fluxo (o mesmo que está em crystal-em-casa/n8n/compra-assiny.json):
  "Responder à Assiny" -> IF "Produto fora da lista?" ($json.acao == 'ignorado' e $json.motivo == 'produto')
  -> HTTP "Repassar ao app (pacote de imagens)": POST do corpo cru da Assiny em
  https://api.crystalnowpp.com.br/webhooks/imagens, com a MESMA credencial do nó
  "Desligar no app (reembolso)" (Authorization: Bearer <segredo do reembolso>), 3 tentativas.
  A API decide se o produto é um pacote (Configurações > pacotes de imagens) e credita ou estorna;
  o que não é pacote ela responde 200 e ignora. Os outros 8 nós não mudam.

Passos:
1. Acha o fluxo pelo webhook "assiny-compras" (e o nome), confere que o rascunho do editor é igual à
   versão publicada (senão para: publicar ou descartar no editor antes).
2. Se os 2 nós e a ligação já existem e o fluxo está ativo, não mexe em nada (rodar de novo não duplica).
3. Exporta e guarda cópia em /root/crystal/n8n-copias/ (0600; só ids e nomes de credencial, nenhum
   segredo), acrescenta o que falta, importa com o MESMO id, grava a versão no histórico do n8n
   (o n8n 1.123 só ativa versão que exista lá), ativa e reinicia o n8n (editor, webhook, worker).
4. Confere: ativo, versão publicada = a salva, 10 nós, ligação, credencial do reembolso no nó novo,
   webhook registrado e, pelo endereço público, 403 sem token (não dispara compra).

Durante a reinicialização (1 a 2 min) o webhook pode responder 404/502: a Assiny reenvia. Rodar em
hora calma. Nunca lê nem imprime segredo. Só biblioteca padrão.

SÓ PARA A VERSÃO DE 13/10 DO FLUXO. O compra-assiny.json de 24/10 (revisão de segurança) já traz o repasse de
imagens e tem outra forma (13 nós, nó "Conferir e enxugar"); este script recusa mexer nele. Para o fluxo novo:
conferir-fluxos.py (estático) e compra-assiny-credenciais.py (credenciais e teste de ponta a ponta).
"""

import argparse
import copy
import datetime
import glob
import http.client
import json
import os
import re
import subprocess
import sys
import time
import urllib.error
import urllib.request
import uuid

WF_ID = "qMRPSFT9OAScVUP4"
NOME_FLUXO = "Crystal · compra e reembolso da Assiny"
CAMINHO = "assiny-compras"
# Em produção o caminho do webhook tem um sufixo secreto (assiny-compras-<aleatório>, 14/10): o script acha o
# fluxo pelo começo do caminho, guarda o caminho real só em memória e nunca o imprime nem grava fora do n8n.
CAMINHO_REAL = CAMINHO
WEBHOOK_BASE = os.environ.get("N8N_COMPRAS_BASE", "https://webhook.crystalnowpp.com.br/webhook/")
FILTRO_CAMINHO = f"(n#>>'{{parameters,path}}' = '{CAMINHO}' or n#>>'{{parameters,path}}' like '{CAMINHO}-%')"
API_IMAGENS = os.environ.get("API_IMAGENS_URL", "https://api.crystalnowpp.com.br/webhooks/imagens")
COPIAS = os.environ.get("CRYSTAL_N8N_COPIAS", "/root/crystal/n8n-copias")
BANCO = os.environ.get("N8N_BANCO", "n8n_queue")
EDITOR = "n8n_editor_n8n_editor"
POSTGRES = "n8n_postgres_n8n_postgres"
SERVICOS = ("n8n_editor_n8n_editor", "n8n_webhook_n8n_webhook", "n8n_worker_n8n_worker")
ARQ_NO_CONTAINER = "/tmp/crystal-compras-imagens.json"

RESPONDER = "Responder à Assiny"
REEMBOLSO = "Desligar no app (reembolso)"
SE = "Produto fora da lista?"
REPASSE = "Repassar ao app (pacote de imagens)"
TOTAL_NOS = 10

NO_SE = {
    "parameters": {
        "conditions": {
            "options": {"caseSensitive": True, "leftValue": "", "typeValidation": "loose", "version": 2},
            "conditions": [
                {"id": "5b0f3c1e-8d2a-4e6b-9f47-2c1a7d3e9b10", "leftValue": "={{ $json.acao }}",
                 "rightValue": "ignorado", "operator": {"type": "string", "operation": "equals"}},
                {"id": "a7c94e02-3f5d-4b8e-8e21-6d0b4f9c2a37", "leftValue": "={{ $json.motivo }}",
                 "rightValue": "produto", "operator": {"type": "string", "operation": "equals"}},
            ],
            "combinator": "and",
        },
        "looseTypeValidation": True,
        "options": {},
    },
    "id": "e4b2a9d1-6c3f-4f0a-b8d5-1e7c2a9f4b63",
    "name": SE,
    "type": "n8n-nodes-base.if",
    "typeVersion": 2.2,
    "position": [720, 640],
}

NO_REPASSE = {
    "parameters": {
        "method": "POST",
        "url": API_IMAGENS,
        "authentication": "genericCredentialType",
        "genericAuthType": "httpHeaderAuth",
        "sendBody": True,
        "specifyBody": "json",
        "jsonBody": "={{ JSON.stringify($('Assiny').item.json.body) }}",
        "options": {},
    },
    "id": "f1d8c3b7-2a6e-4d9c-a4f0-8b3e5c7d1a92",
    "name": REPASSE,
    "type": "n8n-nodes-base.httpRequest",
    "typeVersion": 4.2,
    "position": [960, 620],
    "retryOnFail": True,
    "maxTries": 3,
    "waitBetweenTries": 2000,
}


class Falha(Exception):
    pass


def ok(msg):
    print(f"  ok  {msg}")


def rodar(cmd, entrada=None):
    r = subprocess.run(cmd, input=entrada, capture_output=True)
    if r.returncode != 0:
        fim = (r.stderr.decode(errors="replace").strip().splitlines() or [""])[-1][:200]
        raise Falha(f"comando '{' '.join(cmd[:4])}...' falhou (código {r.returncode}): {fim}")
    return r.stdout.decode(errors="replace").strip()


def container(nome):
    ids = rodar(["docker", "ps", "-q", "-f", f"name={nome}"]).split()
    if not ids:
        raise Falha(f"{nome} não está rodando (docker service ls)")
    return ids[0]


def sql(pg, consulta):
    return rodar(["docker", "exec", "-i", pg, "psql", "-U", "postgres", "-d", BANCO,
                  "-v", "ON_ERROR_STOP=1", "-tAq"], entrada=consulta.encode())


def achar_fluxo(pg):
    """Id do fluxo que tem o webhook POST assiny-compras. Precisa ser exatamente um."""
    global CAMINHO_REAL
    bruto = sql(pg, f"""select coalesce(json_agg(json_build_object('id', w.id, 'nome', w.name, 'ativo', w.active,
        'caminho', (select n#>>'{{parameters,path}}' from jsonb_array_elements(w.nodes::jsonb) n
                     where n->>'type' = 'n8n-nodes-base.webhook' and {FILTRO_CAMINHO} limit 1))), '[]')
      from workflow_entity w
     where exists (select 1 from jsonb_array_elements(w.nodes::jsonb) n
                    where n->>'type' = 'n8n-nodes-base.webhook' and {FILTRO_CAMINHO})
       and coalesce((to_jsonb(w)->>'isArchived')::boolean, false) = false;""")
    achados = json.loads(bruto or "[]")
    if not achados:
        raise Falha(f"nenhum fluxo com o webhook '{CAMINHO}' neste n8n: importar compra-assiny.json antes")
    if len(achados) > 1:
        nomes = ", ".join(f"{a['id']} ({a['nome']})" for a in achados)
        raise Falha(f"mais de um fluxo usa o webhook '{CAMINHO}': {nomes}. Arquivar os que sobram no editor")
    f = achados[0]
    CAMINHO_REAL = f["caminho"]
    if f["id"] != WF_ID:
        print(f"  aviso: o fluxo do webhook tem id {f['id']} (o esperado era {WF_ID}); sigo com {f['id']}")
    if f["nome"] != NOME_FLUXO:
        print(f"  aviso: o nome do fluxo é '{f['nome']}' (o esperado era '{NOME_FLUXO}')")
    return f["id"]


def estado(pg, wid):
    """Fluxo salvo (workflow_entity) e a versão publicada (workflow_history no activeVersionId)."""
    bruto = sql(pg, f"""with w as (select * from workflow_entity where id = '{wid}')
select json_build_object(
  'ativo', w.active, 'versao', w."versionId", 'publicada', to_jsonb(w)->>'activeVersionId',
  'nos', w.nodes::jsonb, 'ligacoes', w.connections::jsonb,
  'pub_nos', (select h.nodes::jsonb from workflow_history h where h."versionId" = to_jsonb(w)->>'activeVersionId'),
  'pub_ligacoes', (select h.connections::jsonb from workflow_history h where h."versionId" = to_jsonb(w)->>'activeVersionId'),
  'webhook', exists (select 1 from webhook_entity e where e."workflowId" = w.id and e."webhookPath" = '{CAMINHO_REAL}'))
from w;""")
    if not bruto:
        raise Falha(f"o fluxo {wid} sumiu do banco do n8n")
    return json.loads(bruto)


def por_nome(nos):
    return {n.get("name"): n for n in nos or []}


def ligado(ligacoes, de, para):
    saidas = ((ligacoes or {}).get(de) or {}).get("main") or []
    return bool(saidas) and any(l.get("node") == para for l in (saidas[0] or []))


def cred_reembolso(nos):
    c = ((por_nome(nos).get(REEMBOLSO) or {}).get("credentials") or {}).get("httpHeaderAuth") or {}
    if not re.fullmatch(r"[A-Za-z0-9]{1,64}", c.get("id") or ""):
        raise Falha(f'o nó "{REEMBOLSO}" está sem credencial Header Auth: escolher "API reembolso" nele no editor, '
                    "publicar e rodar de novo")
    return {"id": c["id"], "name": c.get("name") or "API reembolso"}


def falta_o_que(nos, ligacoes):
    n = por_nome(nos)
    return {"se": SE not in n, "repasse": REPASSE not in n,
            "liga_se": not ligado(ligacoes, RESPONDER, SE), "liga_repasse": not ligado(ligacoes, SE, REPASSE)}


def conferir(pg, wid, publico=True):
    """Leitura apenas. Devolve a lista de problemas (vazia = tudo certo)."""
    e = estado(pg, wid)
    nos, lig = e.get("pub_nos") or e["nos"], e.get("pub_ligacoes") or e["ligacoes"]
    problemas = []
    if not e["ativo"]:
        problemas.append("o fluxo está desativado")
    if e.get("publicada") and e["publicada"] != e["versao"]:
        problemas.append("a versão publicada não é a salva (o editor tem rascunho não publicado)")
    elif e.get("pub_nos") is not None and (e["pub_nos"] != e["nos"] or e["pub_ligacoes"] != e["ligacoes"]):
        print("  aviso: o rascunho do editor difere da versão publicada (confiro a publicada, que é a que roda)")
    if len(nos) != TOTAL_NOS:
        problemas.append(f"a versão que roda tem {len(nos)} nós (esperado {TOTAL_NOS})")
    falta = falta_o_que(nos, lig)
    for chave, texto in (("se", f'falta o nó "{SE}"'), ("repasse", f'falta o nó "{REPASSE}"'),
                         ("liga_se", f'"{RESPONDER}" não liga em "{SE}"'),
                         ("liga_repasse", f'o "sim" de "{SE}" não liga em "{REPASSE}"')):
        if falta[chave]:
            problemas.append(texto)
    n = por_nome(nos)
    if REPASSE in n:
        rep = n[REPASSE]
        if (rep.get("parameters") or {}).get("url") != API_IMAGENS:
            problemas.append(f'"{REPASSE}" não aponta para {API_IMAGENS}')
        try:
            c = cred_reembolso(nos)
            cr = ((rep.get("credentials") or {}).get("httpHeaderAuth") or {}).get("id")
            if cr != c["id"]:
                problemas.append(f'"{REPASSE}" não usa a mesma credencial do "{REEMBOLSO}"')
        except Falha as erro:
            problemas.append(str(erro))
    se = n.get(SE)
    if se:
        conds = (((se.get("parameters") or {}).get("conditions") or {}).get("conditions")) or []
        pares = {(c.get("leftValue"), c.get("rightValue")) for c in conds}
        if pares != {("={{ $json.acao }}", "ignorado"), ("={{ $json.motivo }}", "produto")}:
            problemas.append(f'"{SE}" não tem as condições acao == ignorado e motivo == produto')
    if not e["webhook"]:
        problemas.append(f"o webhook '{CAMINHO}' não está registrado (reiniciar o n8n)")
    gancho = next((n for n in nos if n.get("type") == "n8n-nodes-base.webhook"), {}) or {}
    com_token = bool((gancho.get("parameters") or {}).get("authentication") not in (None, "", "none"))
    if publico and not com_token:
        # Produção (14/10): o webhook não pede token no cabeçalho; quem protege é o sufixo secreto do caminho.
        # Sem token o fluxo roda, o Supabase recusa o corpo vazio e a resposta é 500, sem compra nenhuma.
        print("  aviso: o webhook não pede token no cabeçalho (protegido só pelo caminho secreto); não testo o 403")
        publico = False
    if publico:
        st = status_publico()
        if st != 403:
            problemas.append(f"pelo endereço público, sem token, esperava 403 e veio {st or 'sem resposta'}")
    if not problemas:
        ok(f"ativo, versão publicada = salva, {len(nos)} nós, ligação e condições certas")
        ok(f'"{REPASSE}" -> {API_IMAGENS} com a credencial do "{REEMBOLSO}"')
        ok(f"webhook '{CAMINHO}' registrado" + ("; sem token o endereço público dá 403" if publico else ""))
    return problemas


def status_publico():
    """POST sem token: o n8n recusa (403) antes de executar; não dispara compra."""
    req = urllib.request.Request(WEBHOOK_BASE + CAMINHO_REAL, data=b"{}", method="POST", headers={
        "content-type": "application/json", "user-agent": "crystal-n8n-imagens/1.0"})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return r.status
    except urllib.error.HTTPError as e:
        return e.code
    except (urllib.error.URLError, OSError, http.client.HTTPException):
        return 0


def exportar(editor, wid):
    rodar(["docker", "exec", editor, "n8n", "export:workflow", f"--id={wid}", f"--output={ARQ_NO_CONTAINER}"])
    try:
        bruto = rodar(["docker", "exec", editor, "cat", ARQ_NO_CONTAINER])
    finally:
        subprocess.run(["docker", "exec", editor, "rm", "-f", ARQ_NO_CONTAINER], capture_output=True)
    dados = json.loads(bruto)
    wf = dados[0] if isinstance(dados, list) and len(dados) == 1 else dados
    if not isinstance(wf, dict) or wf.get("id") != wid or not isinstance(wf.get("nodes"), list):
        raise Falha("a exportação do n8n não veio no formato esperado")
    return wf


def guardar_copia(wf):
    os.umask(0o077)
    os.makedirs(COPIAS, mode=0o700, exist_ok=True)
    os.chmod(COPIAS, 0o700)
    caminho = os.path.join(COPIAS, "compra-assiny-" + datetime.datetime.now().strftime("%Y%m%d-%H%M%S") + ".json")
    with open(caminho, "w") as f:
        json.dump(wf, f, ensure_ascii=False, indent=1)
    os.chmod(caminho, 0o600)
    return caminho


def importar_e_ativar(editor, pg, wf):
    wid = wf["id"]
    corpo = json.dumps(wf, ensure_ascii=False).encode()
    rodar(["docker", "exec", "-i", editor, "sh", "-c", f"umask 077; cat > {ARQ_NO_CONTAINER}"], entrada=corpo)
    try:
        rodar(["docker", "exec", editor, "n8n", "import:workflow", f"--input={ARQ_NO_CONTAINER}"])
    finally:
        subprocess.run(["docker", "exec", editor, "rm", "-f", ARQ_NO_CONTAINER], capture_output=True)
    # O n8n 1.123 só ativa uma versão que exista no histórico, e o import pela linha de comando
    # não cria essa versão (o mesmo truque do crystal_provisoria no bootstrap-vps.sh).
    sql(pg, f"""INSERT INTO workflow_history ("versionId", "workflowId", nodes, connections, authors, name, "createdAt", "updatedAt")
SELECT "versionId", id, nodes, connections, 'compra-assiny-imagens', name, now(), now()
  FROM workflow_entity WHERE id = '{wid}'
ON CONFLICT ("versionId") DO UPDATE
  SET nodes = EXCLUDED.nodes, connections = EXCLUDED.connections, name = EXCLUDED.name, "updatedAt" = now();""")
    rodar(["docker", "exec", editor, "n8n", "update:workflow", f"--id={wid}", "--active=true"])
    if sql(pg, f"select active::text from workflow_entity where id = '{wid}';") != "true":
        raise Falha("o fluxo não ficou ativo no banco do n8n")
    ok(f"fluxo {wid} importado com o mesmo id e ativado")


def reiniciar_n8n(pg, wid):
    for s in SERVICOS:
        if subprocess.run(["docker", "service", "inspect", s], capture_output=True).returncode != 0:
            continue
        print(f"  reiniciando {s} (até 2 min)")
        r = subprocess.run(["docker", "service", "update", "--force", "--detach=false", s], capture_output=True)
        if r.returncode != 0:
            print(f"  aviso: {s} não confirmou a reinicialização; conferir com: docker service ls")
    for _ in range(60):
        try:
            if sql(pg, f"""select count(*) from webhook_entity where "workflowId" = '{wid}'
                           and "webhookPath" = '{CAMINHO_REAL}';""") == "1":
                ok(f"n8n de volta, webhook '{CAMINHO}' registrado")
                return
        except Falha:
            pass
        time.sleep(3)
    raise Falha(f"o webhook '{CAMINHO}' não voltou a ser registrado em 3 min: ver docker service ls e o log do editor")


def ligar(editor, pg, wid):
    e = estado(pg, wid)
    if e.get("pub_nos") is not None and (e["pub_nos"] != e["nos"] or e["pub_ligacoes"] != e["ligacoes"]):
        raise Falha("o rascunho do editor tem mudanças não publicadas: publicar ou descartar no editor e rodar de novo "
                    "(senão este script publicaria o rascunho junto)")
    falta = falta_o_que(e["nos"], e["ligacoes"])
    if not any(falta.values()):
        if e["ativo"] and e["webhook"]:
            ok("os 2 nós e a ligação já existem e o fluxo está ativo: nada a mudar")
            return False
        print("  os nós já existem, mas o fluxo não está ativo/registrado: reimporto e reativo")

    wf = exportar(editor, wid)
    copia = guardar_copia(wf)
    ok(f"cópia de antes guardada em {copia} (para --voltar)")

    novo = copy.deepcopy(wf)
    nos, lig = novo["nodes"], novo.setdefault("connections", {})
    cred = cred_reembolso(nos)
    nomes = por_nome(nos)
    if RESPONDER not in nomes:
        raise Falha(f'o fluxo não tem o nó "{RESPONDER}": não é o fluxo esperado')
    if falta["se"]:
        nos.append(copy.deepcopy(NO_SE))
    if falta["repasse"]:
        no = copy.deepcopy(NO_REPASSE)
        no["credentials"] = {"httpHeaderAuth": cred}
        nos.append(no)
    if falta["liga_se"]:
        saidas = lig.setdefault(RESPONDER, {}).setdefault("main", [])
        if not saidas:
            saidas.append([])
        saidas[0].append({"node": SE, "type": "main", "index": 0})
    if falta["liga_repasse"]:
        saidas = lig.setdefault(SE, {}).setdefault("main", [[], []])
        while len(saidas) < 2:
            saidas.append([])
        saidas[0] = (saidas[0] or []) + [{"node": REPASSE, "type": "main", "index": 0}]
    if len(nos) != TOTAL_NOS:
        raise Falha(f"depois de acrescentar, o fluxo teria {len(nos)} nós (esperado {TOTAL_NOS}): nada foi importado")
    novo["versionId"] = str(uuid.uuid4())
    novo["active"] = False
    for campo in ("activeVersionId", "shared", "createdAt", "updatedAt", "versionCounter"):
        novo.pop(campo, None)
    importar_e_ativar(editor, pg, novo)
    return True


def voltar(editor, pg, wid, arquivo):
    if not arquivo:
        copias = sorted(glob.glob(os.path.join(COPIAS, "compra-assiny-*.json")))
        if not copias:
            raise Falha(f"nenhuma cópia em {COPIAS}")
        arquivo = copias[-1]
    with open(arquivo) as f:
        wf = json.load(f)
    if not isinstance(wf, dict) or wf.get("id") != wid or not isinstance(wf.get("nodes"), list):
        raise Falha(f"{arquivo} não é uma cópia do fluxo {wid}")
    wf = copy.deepcopy(wf)
    wf["active"] = False
    for campo in ("activeVersionId", "shared", "createdAt", "updatedAt", "versionCounter"):
        wf.pop(campo, None)
    print(f"  voltando para {arquivo} ({len(wf['nodes'])} nós)")
    importar_e_ativar(editor, pg, wf)


def main():
    p = argparse.ArgumentParser(description="Repasse do pacote de imagens no fluxo de compra da Assiny (n8n)")
    g = p.add_mutually_exclusive_group()
    g.add_argument("--testar", action="store_true", help="só confere, sem mudar nada e sem disparar compra")
    g.add_argument("--voltar", nargs="?", const="", metavar="ARQUIVO",
                   help="reimporta a cópia mais recente (ou a indicada) e reativa")
    a = p.parse_args()

    editor, pg = container(EDITOR), container(POSTGRES)
    print("== fluxo")
    wid = achar_fluxo(pg)
    ok(f"fluxo {wid} (webhook '{CAMINHO}')")
    if "Conferir e enxugar" in por_nome(estado(pg, wid)["nos"]):
        raise Falha("este é o fluxo de 24/10 (nó 'Conferir e enxugar'): este script é só para a versão de 13/10. "
                    "Use conferir-fluxos.py e compra-assiny-credenciais.py")

    if a.testar:
        print("== conferência (só leitura)")
        problemas = conferir(pg, wid)
    elif a.voltar is not None:
        print("== volta")
        voltar(editor, pg, wid, a.voltar)
        reiniciar_n8n(pg, wid)
        e = estado(pg, wid)
        nos = e.get("pub_nos") or e["nos"]
        if not e["ativo"]:
            raise Falha("depois da volta o fluxo não ficou ativo")
        ok(f"de volta: ativo, {len(nos)} nós")
        return
    else:
        print("== mudança")
        mudou = ligar(editor, pg, wid)
        if mudou:
            reiniciar_n8n(pg, wid)
        print("== conferência")
        problemas = conferir(pg, wid)

    if problemas:
        for pr in problemas:
            print(f"  PROBLEMA: {pr}")
        raise Falha("a conferência não passou" + ("" if a.testar else ": para voltar, --voltar"))
    print("\nPronto. Compra de produto fora de crystal_compras_produtos vai para a API em "
          f"{API_IMAGENS};\na API credita/estorna se o produto estiver em Configurações > pacotes de imagens.")
    print("Lembrete: com crystal_compras_produtos VAZIA, todo produto libera o app e nada é repassado.")


if __name__ == "__main__":
    try:
        main()
    except Falha as e:
        print(f"ERRO: {e}")
        sys.exit(1)
    except (KeyboardInterrupt, EOFError):
        print("\nInterrompido.")
        sys.exit(130)
