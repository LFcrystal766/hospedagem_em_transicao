#!/usr/bin/env python3
"""Grava as 4 credenciais do fluxo "Crystal · compra e reembolso da Assiny" no nosso n8n (09/10/2026).

Uso, na VPS, como root:
    python3 compra-assiny-credenciais.py                     # grava e testa de ponta a ponta
    python3 compra-assiny-credenciais.py --sem-teste-completo
    python3 compra-assiny-credenciais.py --novo-token        # troca o token da Assiny (depois, trocar lá)
    python3 compra-assiny-credenciais.py --mostrar-token     # mostra o token atual da Assiny
    python3 compra-assiny-credenciais.py --resend-proprio    # chave do Resend só do n8n (pedida sem eco)
    python3 compra-assiny-credenciais.py --supabase-proprio  # secret key do Supabase só do n8n (sem eco)

1. Lê as chaves que o app já usa em /root/crystal/app/.externos (SUPABASE_URL,
   SUPABASE_SERVICE_ROLE_KEY, RESEND_API_KEY, REFUND_WEBHOOK_SECRET) e gera, ou reaproveita, o
   token da Assiny em /root/crystal/n8n-compras.segredos (0600).
2. Testa cada chave direto no serviço, antes de mexer no n8n: Supabase (evento de teste, que a
   função ignora), Resend (e-mail para a caixa de teste do Resend) e API do app (evento de teste,
   ignorado). Se alguma falhar, para sem mexer no n8n.
3. Acha, no banco do n8n, as credenciais que os 4 nós do fluxo usam e grava os valores NELAS
   (n8n import:credentials, cifrado pela chave do n8n). O fluxo não muda.
4. Testa pelo endereço público: sem token dá 403; com token, o evento de teste dá 200.
5. Teste completo (padrão): compra aprovada e reembolso de delivered+teste-n8n-<hora>@resend.dev
   (caixa de teste do Resend) e confere no n8n que as duas execuções terminaram com sucesso
   (e-mail de boas-vindas e repasse do reembolso à API). Ficam 1 linha em crystal_compras
   (reembolsada) e 2 em crystal_compras_eventos com esse e-mail, fáceis de achar e apagar.
6. Mostra o que colar na Assiny.

Nunca imprime chave nem segredo; o token da Assiny só aparece quando é novo ou com
--mostrar-token (é para colar na Assiny e no Bitwarden, nunca no chat). Só biblioteca padrão.
"""

import argparse
import datetime
import getpass
import http.client
import json
import os
import re
import secrets
import subprocess
import sys
import time
import urllib.error
import urllib.request

EXTERNOS = os.environ.get("CRYSTAL_EXTERNOS", "/root/crystal/app/.externos")
SEGREDOS = os.environ.get("CRYSTAL_N8N_COMPRAS", "/root/crystal/n8n-compras.segredos")
WEBHOOK = os.environ.get("N8N_COMPRAS_URL", "https://webhook.crystalnowpp.com.br/webhook/assiny-compras")
SUPABASE_DO_FLUXO = os.environ.get("SUPABASE_DO_FLUXO", "https://hwbllqepvhddakszqdbk.supabase.co")
RESEND = os.environ.get("RESEND_URL", "https://api.resend.com").rstrip("/")
API_REEMBOLSO = os.environ.get("API_REEMBOLSO_URL", "https://api.crystalnowpp.com.br/webhooks/reembolso")
WF_ID = "qMRPSFT9OAScVUP4"
REMETENTE = "Crystal <acesso@crystalnowpp.com.br>"  # o mesmo do nó de boas-vindas
EDITOR = "n8n_editor_n8n_editor"
POSTGRES = "n8n_postgres_n8n_postgres"
ARQ_NO_CONTAINER = "/tmp/crystal-compras-cred.json"

# nó do fluxo -> cabeçalho que a credencial dele manda
NOS = {
    "Assiny": "x-crystal-token",
    "Registrar no Supabase": "apikey",
    "E-mail de boas-vindas (Resend)": "Authorization",
    "Desligar no app (reembolso)": "Authorization",
}


class Falha(Exception):
    pass


def ok(msg):
    print(f"  ok  {msg}")


def chamar(metodo, url, cab=None, corpo=None, tempo=40):
    """Devolve (status, corpo). Status 0 quando nem chegou resposta. Nunca levanta HTTPError."""
    dados = json.dumps(corpo).encode() if corpo is not None else None
    # User-Agent próprio: o Cloudflare na frente do Resend barra o "Python-urllib" padrão (erro 1010).
    req = urllib.request.Request(url, data=dados, method=metodo, headers={
        "accept": "application/json", "content-type": "application/json",
        "user-agent": "crystal-n8n-credenciais/1.0", **(cab or {})})
    try:
        with urllib.request.urlopen(req, timeout=tempo) as r:
            status, bruto = r.status, r.read()
    except urllib.error.HTTPError as e:
        status, bruto = e.code, e.read()
    except (urllib.error.URLError, OSError, http.client.HTTPException) as e:
        return 0, type(getattr(e, "reason", e)).__name__
    texto = bruto.decode(errors="replace")
    try:
        return status, json.loads(texto) if texto.strip() else None
    except ValueError:
        return status, texto[:200]


def ler_kv(caminho):
    valores = {}
    with open(caminho) as f:
        for linha in f:
            nome, _, valor = linha.strip().partition("=")
            if nome and not nome.startswith("#"):
                valores[nome.strip()] = valor.strip().strip('"').strip("'")
    return valores


def gravar_kv(caminho, nome, valor):
    antes = []
    if os.path.exists(caminho):
        with open(caminho) as f:
            antes = [l for l in f.read().splitlines() if not l.startswith(nome + "=")]
    os.umask(0o077)
    tmp = caminho + ".tmp"
    with open(tmp, "w") as f:
        f.write("\n".join(antes + [f"{nome}={valor}"]) + "\n")
    os.chmod(tmp, 0o600)
    os.replace(tmp, caminho)


def limpo(nome, valor, origem):
    valor = (valor or "").strip()
    if not valor:
        raise Falha(f"{nome} vazio ou ausente em {origem}")
    if not re.fullmatch(r"[\x21-\x7e]+", valor):
        raise Falha(f"{nome} tem espaço ou caractere invisível (o que derrubou o teste do n8n): corrigir em {origem}")
    return valor


def pedir_chave(rotulo, prefixo):
    v = getpass.getpass(f"{rotulo} (não aparece na tela): ").strip()
    if not v.startswith(prefixo):
        raise Falha(f"isso não parece {rotulo.lower()} (começa com {prefixo}). Nada foi gravado")
    return limpo(rotulo, v, "o que foi digitado")


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
    return rodar(["docker", "exec", "-i", pg, "psql", "-U", "postgres", "-d", "n8n_queue",
                  "-v", "ON_ERROR_STOP=1", "-tAq"], entrada=consulta.encode())


def testar_supabase(url, chave):
    st, r = chamar("POST", f"{url}/rest/v1/rpc/app_compra_evento", {"apikey": chave},
                   {"p_evento": {"event": "teste_credenciais"}})
    if st == 200 and isinstance(r, dict) and r.get("acao") == "ignorado":
        return ok("Supabase aceitou a chave (evento de teste ignorado, nada gravado)")
    if st in (401, 403):
        raise Falha(f"o Supabase recusou a chave (HTTP {st})")
    if st == 404:
        raise Falha("app_compra_evento não existe no Supabase: rodar app_compras.sql")
    raise Falha(f"Supabase respondeu HTTP {st} no teste")


def testar_resend(chave):
    st, r = chamar("POST", f"{RESEND}/emails",
                   {"authorization": f"Bearer {chave}", "idempotency-key": f"teste-cred-{secrets.token_hex(8)}"},
                   {"from": REMETENTE, "to": ["delivered@resend.dev"], "subject": "Teste da credencial do n8n",
                    "text": "Teste automático da credencial do n8n. Pode ignorar."})
    if st == 200 and isinstance(r, dict) and r.get("id"):
        return ok(f"Resend aceitou a chave e o remetente {REMETENTE} (e-mail para a caixa de teste)")
    msg = r.get("message", "") if isinstance(r, dict) else (r or "")
    raise Falha(f"o Resend recusou (HTTP {st}): {str(msg).strip()[:160]}")


def testar_reembolso(segredo):
    st, r = chamar("POST", API_REEMBOLSO, {"authorization": f"Bearer {segredo}"}, {"event": "teste_credenciais"})
    if st == 200 and isinstance(r, dict) and r.get("ignored"):
        return ok("API do app aceitou o segredo do reembolso (evento de teste ignorado)")
    if st == 401:
        raise Falha("a API do app recusou o REFUND_WEBHOOK_SECRET de .externos: a API no ar usa outro. "
                    "Rodar 'bash bootstrap-vps.sh app-subir <tag atual>' e este script de novo")
    if st == 404:
        raise Falha("a rota de reembolso está desligada na API (o segredo não chegou ao app): "
                    "'bash bootstrap-vps.sh app-subir <tag atual>' e este script de novo")
    if st == 429:
        raise Falha("a API bloqueou por excesso de tentativas com segredo errado: esperar uns minutos")
    raise Falha(f"API do app respondeu HTTP {st} no teste do reembolso")


def credenciais_do_fluxo(pg):
    consulta = f"""
with w as (select * from workflow_entity where id = '{WF_ID}'),
v as (select coalesce(to_jsonb(w)->>'activeVersionId', w."versionId") as vid from w),
fontes as (
  select 'salvo' as fonte, w.nodes::jsonb as nodes from w
  union all
  select 'publicado', h.nodes::jsonb from workflow_history h join v on h."versionId" = v.vid
)
select json_build_object(
  'ativo', (select active from w),
  'tem_publicado', exists (select 1 from fontes where fonte = 'publicado'),
  'creds', (select coalesce(json_agg(json_build_object('fonte', f.fonte, 'no', n->>'name', 'tipo', c.key,
                                                       'id', c.value->>'id')), '[]')
              from fontes f
              cross join lateral jsonb_array_elements(f.nodes) n
              cross join lateral jsonb_each(coalesce(n->'credentials', '{{}}'::jsonb)) c))
from w;"""
    bruto = sql(pg, consulta)
    if not bruto:
        raise Falha(f"o fluxo {WF_ID} não existe neste n8n: importar crystal-em-casa/n8n/compra-assiny.json")
    info = json.loads(bruto)
    if not info.get("ativo"):
        raise Falha("o fluxo está desativado: ativar no editor do n8n e rodar de novo")
    # Quem roda é a versão publicada (activeVersionId); sem histórico, a salva.
    roda = "publicado" if info.get("tem_publicado") else "salvo"
    por_fonte = {"publicado": {}, "salvo": {}}
    for c in info.get("creds") or []:
        if c.get("no") not in NOS:
            continue
        if c.get("tipo") != "httpHeaderAuth" or not re.fullmatch(r"[A-Za-z0-9]{1,64}", c.get("id") or ""):
            raise Falha(f'o nó "{c.get("no")}" usa uma credencial de outro tipo: escolher uma "Header Auth" no editor')
        por_fonte[c["fonte"]][c["no"]] = c["id"]
    ids = por_fonte[roda]
    for no in NOS:
        if no not in ids:
            raise Falha(f'o nó "{no}" está sem credencial na versão que roda: no editor, escolher uma '
                        '"Header Auth" nele, salvar, publicar e rodar de novo')
        outra = por_fonte["salvo"].get(no) if roda == "publicado" else None
        if outra and outra != ids[no]:
            print(f'  aviso: o rascunho do editor usa outra credencial em "{no}"; se publicar o rascunho, rodar de novo')
    return ids


def gravar_no_n8n(editor, pg, ids, valores):
    por_id = {}
    for no, cid in ids.items():
        par = (NOS[no], valores[no])
        if cid in por_id and por_id[cid] != par:
            raise Falha("a mesma credencial está em dois nós que precisam de valores diferentes: "
                        "no editor, criar uma credencial para cada nó e rodar de novo")
        por_id[cid] = par
    lista = "', '".join(sorted(por_id))
    nomes = json.loads(sql(pg, f"select coalesce(json_object_agg(id, json_build_object('nome', name, 'tipo', type)), '{{}}') "
                               f"from credentials_entity where id in ('{lista}');"))
    falta = sorted(set(por_id) - set(nomes))
    if falta:
        raise Falha("o fluxo aponta para credencial apagada: no editor, escolher uma credencial em cada nó")
    if any(n["tipo"] != "httpHeaderAuth" for n in nomes.values()):
        raise Falha('alguma credencial do fluxo não é "Header Auth"')
    corpo = json.dumps([{"id": cid, "name": nomes[cid]["nome"], "type": "httpHeaderAuth",
                         "data": {"name": cab, "value": val}} for cid, (cab, val) in por_id.items()])
    rodar(["docker", "exec", "-i", editor, "sh", "-c", f"umask 077; cat > {ARQ_NO_CONTAINER}"], entrada=corpo.encode())
    corpo = None
    try:
        rodar(["docker", "exec", editor, "n8n", "import:credentials", f"--input={ARQ_NO_CONTAINER}"])
    finally:
        subprocess.run(["docker", "exec", editor, "rm", "-f", ARQ_NO_CONTAINER], capture_output=True)
    novas = int(sql(pg, f"""select count(*) from credentials_entity where id in ('{lista}')
                            and "updatedAt" > now() - interval '5 minutes';""") or 0)
    if novas != len(por_id):
        raise Falha(f"o n8n só atualizou {novas} de {len(por_id)} credenciais")
    for cid, n in sorted(nomes.items(), key=lambda x: x[1]["nome"]):
        ok(f'credencial "{n["nome"]}" gravada (cifrada pela chave do n8n)')


def agora_no_banco(pg):
    return sql(pg, "select now()::text;")


def execucoes_desde(pg, desde, quantas, espera=90):
    linhas = []
    for _ in range(espera):
        linhas = json.loads(sql(pg, f"""select coalesce(json_agg(json_build_object('status', status) order by "createdAt"), '[]')
            from execution_entity where "workflowId" = '{WF_ID}' and "createdAt" >= '{desde}'::timestamptz;"""))
        if len(linhas) >= quantas and all(l["status"] not in ("new", "running", "waiting") for l in linhas):
            break
        time.sleep(1)
    return [l["status"] for l in linhas]


def teste_completo(pg, token):
    tx = "teste-n8n-" + datetime.datetime.now().strftime("%Y%m%d%H%M%S")
    email = f"delivered+{tx}@resend.dev"
    dados = {"client": {"email": email, "full_name": "Teste do n8n", "first_name": "Teste"},
             "transaction": {"id": tx}, "offer": {"name": "Teste do n8n",
                                                 "product": {"id": "teste-n8n", "name": "Teste do n8n"}}}
    # transaction.status é obrigatório na API do app (assinyTransactionSchema), como no envio real da Assiny.
    for evento, status_tx, espera_acao, o_que in (
            ("approved_purchase", "approved", "liberado", "e-mail de boas-vindas"),
            ("refunded_purchase", "refunded", "bloqueado", "repasse do reembolso à API")):
        dados["transaction"]["status"] = status_tx
        desde = agora_no_banco(pg)
        st, r = chamar("POST", WEBHOOK, {"x-crystal-token": token}, {"event": evento, "data": dados})
        acao = r.get("acao") if isinstance(r, dict) else None
        if st != 200 or acao != espera_acao:
            motivo = r.get("motivo") if isinstance(r, dict) else ""
            raise Falha(f"{evento}: esperava '{espera_acao}', veio HTTP {st} '{acao}' {motivo or ''}".strip())
        status = execucoes_desde(pg, desde, 1)
        if status != ["success"]:
            raise Falha(f"{evento}: a execução no n8n terminou {status or 'sem registro'} ({o_que}). "
                        "Abrir Executions no editor para ver o nó que falhou")
        ok(f"{evento}: {espera_acao} e {o_que} com sucesso")
    print(f"  (sobram linhas de teste com o e-mail {email}; apagar com: delete from "
          "crystal_compras_eventos where transacao like 'teste-n8n-%'; delete from crystal_compras "
          "where email like 'delivered+teste-n8n-%@resend.dev';)")


def main():
    p = argparse.ArgumentParser(description="Credenciais do fluxo de compra da Assiny no nosso n8n")
    p.add_argument("--novo-token", action="store_true")
    p.add_argument("--mostrar-token", action="store_true")
    p.add_argument("--resend-proprio", action="store_true")
    p.add_argument("--supabase-proprio", action="store_true")
    p.add_argument("--sem-teste-completo", action="store_true")
    a = p.parse_args()

    print("== chaves")
    ext = ler_kv(EXTERNOS)
    url = limpo("SUPABASE_URL", ext.get("SUPABASE_URL"), EXTERNOS).rstrip("/")
    if url != SUPABASE_DO_FLUXO:
        raise Falha(f"SUPABASE_URL de .externos não é o projeto do fluxo ({SUPABASE_DO_FLUXO})")
    supabase = (pedir_chave("Secret key do Supabase", "sb_secret_") if a.supabase_proprio
                else limpo("SUPABASE_SERVICE_ROLE_KEY", ext.get("SUPABASE_SERVICE_ROLE_KEY"), EXTERNOS))
    resend = (pedir_chave("Chave do Resend", "re_") if a.resend_proprio
              else limpo("RESEND_API_KEY", ext.get("RESEND_API_KEY"), EXTERNOS))
    reembolso = limpo("REFUND_WEBHOOK_SECRET", ext.get("REFUND_WEBHOOK_SECRET"), EXTERNOS)
    ext = None

    token, novo = None, False
    if not a.novo_token and os.path.exists(SEGREDOS):
        token = ler_kv(SEGREDOS).get("ASSINY_N8N_TOKEN")
        if not re.fullmatch(r"[0-9a-f]{64}", token or ""):
            token = None
    if token is None:
        token, novo = secrets.token_hex(32), True
        gravar_kv(SEGREDOS, "ASSINY_N8N_TOKEN", token)
        ok(f"token novo da Assiny gerado e guardado em {SEGREDOS}")
    else:
        ok(f"token da Assiny reaproveitado de {SEGREDOS}")

    print("== teste de cada chave direto no serviço (antes de mexer no n8n)")
    testar_supabase(url, supabase)
    testar_resend(resend)
    testar_reembolso(reembolso)

    print("== credenciais no n8n")
    editor, pg = container(EDITOR), container(POSTGRES)
    ids = credenciais_do_fluxo(pg)
    gravar_no_n8n(editor, pg, ids, {
        "Assiny": token,
        "Registrar no Supabase": supabase,
        "E-mail de boas-vindas (Resend)": f"Bearer {resend}",
        "Desligar no app (reembolso)": f"Bearer {reembolso}",
    })
    supabase = resend = reembolso = None

    print("== teste pelo endereço público")
    st, _ = chamar("POST", WEBHOOK, {}, {"event": "teste_credenciais"})
    if st != 403:
        raise Falha(f"sem token o webhook deveria dar 403 e deu {st}")
    ok("sem token: 403")
    st, r = chamar("POST", WEBHOOK, {"x-crystal-token": token}, {"event": "teste_credenciais"})
    if st != 200 or not isinstance(r, dict) or r.get("acao") != "ignorado":
        raise Falha(f"com token o evento de teste deveria dar 200 'ignorado' e deu HTTP {st}"
                    + (" (o n8n não chegou ao Supabase)" if st == 500 else ""))
    ok("com token: 200, passou pelo Supabase")

    if not a.sem_teste_completo:
        print("== teste completo (caixa de teste do Resend)")
        teste_completo(container(POSTGRES), token)

    print("\nPronto. Na Assiny (Integrações > Webhooks), um webhook novo:")
    print(f"  URL: {WEBHOOK}")
    print("  Cabeçalho: x-crystal-token")
    if novo or a.mostrar_token:
        print(f"  Valor:     {token}")
        print("  (copiar para a Assiny e para o Bitwarden; nunca para o chat)")
    else:
        print("  Valor: o mesmo de antes (para ver: --mostrar-token)")
    print("  Eventos: compra aprovada, assinatura renovada, reembolso, chargeback e assinatura cancelada.")
    print("Depois do primeiro teste real, tirar o webhook antigo da agência.")


if __name__ == "__main__":
    try:
        main()
    except Falha as e:
        print(f"ERRO: {e}")
        sys.exit(1)
    except (KeyboardInterrupt, EOFError):
        print("\nInterrompido.")
        sys.exit(130)
