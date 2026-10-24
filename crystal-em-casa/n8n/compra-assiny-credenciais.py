#!/usr/bin/env python3
"""Grava as credenciais dos fluxos de compra da Assiny no nosso n8n e testa de ponta a ponta (v2, 24/10/2026).

Uso, na VPS, como root (sempre com -I):
    python3 -I compra-assiny-credenciais.py                       # grava e testa tudo; pede o que faltar, sem eco
    python3 -I compra-assiny-credenciais.py --so-conferir         # só leitura: fluxos, credenciais, 403/400 públicos
    python3 -I compra-assiny-credenciais.py --fluxo <id>          # grava no fluxo de compras indicado (ex.: o novo, ainda
                                                                  # inativo); sem testes públicos até ele ser ativado
    python3 -I compra-assiny-credenciais.py --sem-teste-completo  # grava e testa as chaves, sem compra de teste
    python3 -I compra-assiny-credenciais.py --produto <id>        # id de crystal_compras_produtos para a compra de teste
    python3 -I compra-assiny-credenciais.py --novo-token          # troca o token da Assiny (depois, trocar lá)
    python3 -I compra-assiny-credenciais.py --mostrar-token       # mostra o token atual (para colar na Assiny)
    python3 -I compra-assiny-credenciais.py --supabase-chave      # (re)pede uma secret key (sb_secret_) só do n8n
    python3 -I compra-assiny-credenciais.py --supabase-papel      # papel n8n_compras: pede a chave publicável e o segredo
                                                                  # JWT do projeto, gera o JWT do papel (recomendado)
    python3 -I compra-assiny-credenciais.py --resend-chave        # (re)pede uma chave do Resend só do n8n
    python3 -I compra-assiny-credenciais.py --reaproveitar-do-app # chaves do app (.externos), como até 24/10 (evitar)

Fluxos que ele atende (crystal-em-casa/n8n/): "Crystal · compra e reembolso da Assiny" (obrigatório; achado pelo
webhook assiny-compras*), "Crystal · conciliação de compras" e "Crystal · aviso de erro do n8n" (se importados).
Credenciais, pelo nome sugerido no JSON (o que vale é a credencial escolhida em cada nó):
  Assiny · x-crystal-token   Header Auth   x-crystal-token: <token>   (nó "Assiny"; opcional se o webhook for só
                                                                       pelo caminho secreto, mas recomendado)
  Supabase · n8n compras     Custom Auth   {"headers": {"apikey": ..., "Authorization": "Bearer ..."}}
  Resend · n8n               Header Auth   Authorization: Bearer <chave do Resend só do n8n>
  API reembolso              Header Auth   Authorization: Bearer <REFUND_WEBHOOK_SECRET do app>
  API imagens                Header Auth   Authorization: Bearer <IMAGENS_WEBHOOK_SECRET do app; sem ele, o do reembolso>

De onde vêm os valores (INT-07, menor privilégio):
- Supabase: por padrão uma chave SÓ DO n8n, guardada em /root/crystal/n8n-compras.segredos (0600). Dois modos:
  "chave" (uma secret key sb_secret_ criada em Settings > API Keys só para o n8n; ainda é service_role, mas revogável
  sozinha) ou "papel" (recomendado): o papel n8n_compras de app_compras_seguranca_n8n.sql, que só executa as duas
  funções do fluxo. No modo papel o script gera um JWT HS256 {"role": "n8n_compras"} com o segredo JWT do projeto
  (Settings > JWT Keys > Legacy JWT secret), usa o segredo uma vez e NÃO o guarda; guarda só o JWT e a chave
  publicável (que é pública) para o cabeçalho apikey.
- Resend: uma chave só do n8n (criar no Resend com permissão "Sending access" e domínio crystalnowpp.com.br).
- Reembolso e imagens: os segredos do app em /root/crystal/app/.externos (são compartilhados com a API, por natureza).
- Assiny: token de 64 hex gerado aqui, guardado no mesmo arquivo de segredos do n8n.

Testes, nesta ordem: cada chave direto no serviço (Supabase com evento de teste, que a função registra como
"ignorado_evento" sem dado pessoal; a função de conciliação, que prova que o SQL de 24/10 foi aplicado; Resend para
a caixa de teste; as duas rotas da API com evento de teste); grava no n8n; endereço público (403 sem token, 400 com
corpo inválido, 200 "ignorado" com evento de teste); teste completo (com --produto): compra de teste libera, reembolso
bloqueia, reembolso FORJADO de outro e-mail é ignorado (sem_compra_conhecida), reenvio do reembolso vem "repetido"
com anterior = bloquear, pacote fora da lista vai à rota de imagens; e nenhuma execução com erro no n8n.

Nunca imprime chave nem segredo; o token da Assiny só aparece quando é novo ou com --mostrar-token. Só biblioteca padrão.
"""

import argparse
import base64
import datetime
import getpass
import hashlib
import hmac
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
WEBHOOK_BASE = os.environ.get("N8N_COMPRAS_BASE", "https://webhook.crystalnowpp.com.br/webhook/")
SUPABASE_DO_FLUXO = os.environ.get("SUPABASE_DO_FLUXO", "https://hwbllqepvhddakszqdbk.supabase.co")
RESEND = os.environ.get("RESEND_URL", "https://api.resend.com").rstrip("/")
API = os.environ.get("API_APP_URL", "https://api.crystalnowpp.com.br").rstrip("/")
REMETENTE = "Crystal <acesso@crystalnowpp.com.br>"  # o mesmo dos nós de e-mail
EDITOR = "n8n_editor_n8n_editor"
POSTGRES = "n8n_postgres_n8n_postgres"
BANCO = os.environ.get("N8N_BANCO", "n8n_queue")
ARQ_NO_CONTAINER = "/tmp/crystal-compras-cred.json"
CAMINHO = "assiny-compras"
FILTRO_CAMINHO = f"(n#>>'{{parameters,path}}' = '{CAMINHO}' or n#>>'{{parameters,path}}' like '{CAMINHO}-%')"
NOME_CONCILIACAO = "Crystal · conciliação de compras"
NOME_ERRO = "Crystal · aviso de erro do n8n"

# nó → papel da credencial; tipo da credencial por papel; cabeçalho que ela manda
PAPEL_DO_NO = {
    "Assiny": "assiny",
    "Registrar no Supabase": "supabase",
    "Ler resumo e bloqueios (Supabase)": "supabase",
    "E-mail de boas-vindas (Resend)": "resend",
    "E-mail à equipe (Resend)": "resend",
    "Desligar no app (reembolso)": "reembolso",
    "Reenviar bloqueio ao app": "reembolso",
    "Repassar ao app (pacote de imagens)": "imagens",
}
TIPO_DO_PAPEL = {"assiny": "httpHeaderAuth", "supabase": "httpCustomAuth", "resend": "httpHeaderAuth",
                 "reembolso": "httpHeaderAuth", "imagens": "httpHeaderAuth"}
OBRIGATORIOS_COMPRAS = ("Registrar no Supabase", "E-mail de boas-vindas (Resend)", "Desligar no app (reembolso)",
                        "Repassar ao app (pacote de imagens)")


class Falha(Exception):
    pass


def ok(msg):
    print(f"  ok  {msg}")


def aviso(msg):
    print(f"  aviso: {msg}")


def chamar(metodo, url, cab=None, corpo=None, tempo=60):
    """Devolve (status, corpo). Status 0 quando nem chegou resposta. Nunca levanta HTTPError."""
    dados = json.dumps(corpo).encode() if corpo is not None else None
    # User-Agent próprio: o Cloudflare na frente do Resend barra o "Python-urllib" padrão (erro 1010).
    req = urllib.request.Request(url, data=dados, method=metodo, headers={
        "accept": "application/json", "content-type": "application/json",
        "user-agent": "crystal-n8n-credenciais/2.0", **(cab or {})})
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
    if not os.path.exists(caminho):
        return valores
    with open(caminho) as f:
        for linha in f:
            nome, _, valor = linha.strip().partition("=")
            if nome and not nome.startswith("#"):
                valores[nome.strip()] = valor.strip().strip('"').strip("'")
    return valores


def gravar_kv(caminho, **pares):
    antes = []
    if os.path.exists(caminho):
        with open(caminho) as f:
            antes = [l for l in f.read().splitlines() if l.partition("=")[0] not in pares]
    os.umask(0o077)
    tmp = caminho + ".tmp"
    with open(tmp, "w") as f:
        f.write("\n".join(antes + [f"{k}={v}" for k, v in pares.items() if v is not None]) + "\n")
    os.chmod(tmp, 0o600)
    os.replace(tmp, caminho)


def limpo(nome, valor, origem):
    valor = (valor or "").strip()
    if not valor:
        raise Falha(f"{nome} vazio ou ausente em {origem}")
    if not re.fullmatch(r"[\x21-\x7e]+", valor):
        raise Falha(f"{nome} tem espaço ou caractere invisível (o que derrubou o teste do n8n): corrigir em {origem}")
    return valor


def pedir(rotulo, padrao=None):
    v = getpass.getpass(f"{rotulo} (não aparece na tela): ").strip()
    if padrao and not re.fullmatch(padrao, v):
        raise Falha(f"isso não parece {rotulo.lower()}. Nada foi gravado")
    return limpo(rotulo, v, "o que foi digitado")


def jwt_do_papel(segredo_jwt, papel="n8n_compras", anos=5):
    """JWT HS256 com a claim role, do jeito que o PostgREST do Supabase lê. Só biblioteca padrão."""
    def b64(d):
        return base64.urlsafe_b64encode(d).rstrip(b"=").decode()
    agora = int(time.time())
    cab = b64(json.dumps({"alg": "HS256", "typ": "JWT"}, separators=(",", ":")).encode())
    corpo = b64(json.dumps({"role": papel, "iss": "supabase", "iat": agora, "exp": agora + anos * 365 * 86400},
                           separators=(",", ":")).encode())
    ass = b64(hmac.new(segredo_jwt.encode(), f"{cab}.{corpo}".encode(), hashlib.sha256).digest())
    return f"{cab}.{corpo}.{ass}"


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


# ---------------------------------------------------------------------------------------------------------------
# chaves
# ---------------------------------------------------------------------------------------------------------------
def cabecalhos_supabase(seg, a):
    """Devolve (modo, headers) da credencial do Supabase; pede e guarda o que faltar."""
    modo = seg.get("N8N_SUPABASE_MODO")
    if a.reaproveitar_do_app:
        ext = ler_kv(EXTERNOS)
        chave = limpo("SUPABASE_SERVICE_ROLE_KEY", ext.get("SUPABASE_SERVICE_ROLE_KEY"), EXTERNOS)
        aviso("Supabase com a chave do app (service_role): o n8n fica com poder sobre a base inteira. "
              "Prefira --supabase-papel")
        return "app", {"apikey": chave}
    if a.supabase_papel or (modo == "papel" and not a.supabase_chave):
        if a.supabase_papel or not seg.get("N8N_SUPABASE_CHAVE"):
            print("  Papel n8n_compras: rodar antes app_compras_seguranca_n8n.sql no SQL Editor.")
            publicavel = pedir("Chave publicável do Supabase (sb_publishable_ ou anon eyJ...)", r"(sb_publishable_|eyJ)\S+")
            segredo_jwt = pedir("Segredo JWT do projeto (Settings > JWT Keys > Legacy JWT secret)", r"\S{32,}")
            jwt = jwt_do_papel(segredo_jwt)
            segredo_jwt = None
            gravar_kv(SEGREDOS, N8N_SUPABASE_MODO="papel", N8N_SUPABASE_CHAVE=jwt, N8N_SUPABASE_APIKEY=publicavel)
            ok(f"JWT do papel n8n_compras gerado (5 anos) e guardado em {SEGREDOS}; o segredo JWT não foi guardado")
            seg.update(ler_kv(SEGREDOS))
        return "papel", {"apikey": seg["N8N_SUPABASE_APIKEY"], "Authorization": "Bearer " + seg["N8N_SUPABASE_CHAVE"]}
    if a.supabase_chave or not seg.get("N8N_SUPABASE_CHAVE") or modo != "chave":
        print("  Secret key só do n8n: Supabase > Settings > API Keys > Create new secret key (nome: n8n-compras).")
        chave = pedir("Secret key do Supabase (sb_secret_...)", r"sb_secret_\S+")
        gravar_kv(SEGREDOS, N8N_SUPABASE_MODO="chave", N8N_SUPABASE_CHAVE=chave, N8N_SUPABASE_APIKEY=None)
        ok(f"secret key do n8n guardada em {SEGREDOS}")
        seg.update(ler_kv(SEGREDOS))
    return "chave", {"apikey": seg["N8N_SUPABASE_CHAVE"]}


def chave_resend(seg, a):
    if a.reaproveitar_do_app:
        ext = ler_kv(EXTERNOS)
        aviso("Resend com a chave do app: vazou uma, vazaram os e-mails da API e do n8n. Prefira --resend-chave")
        return limpo("RESEND_API_KEY", ext.get("RESEND_API_KEY"), EXTERNOS)
    if a.resend_chave or not seg.get("N8N_RESEND_CHAVE"):
        print("  Chave do Resend só do n8n: resend.com > API Keys > Create (Sending access, domínio crystalnowpp.com.br).")
        chave = pedir("Chave do Resend (re_...)", r"re_\S+")
        gravar_kv(SEGREDOS, N8N_RESEND_CHAVE=chave)
        ok(f"chave do Resend do n8n guardada em {SEGREDOS}")
        seg.update(ler_kv(SEGREDOS))
    return seg["N8N_RESEND_CHAVE"]


def token_assiny(seg, a):
    token = None if a.novo_token else seg.get("ASSINY_N8N_TOKEN")
    if not re.fullmatch(r"[0-9a-f]{64}", token or ""):
        token = secrets.token_hex(32)
        gravar_kv(SEGREDOS, ASSINY_N8N_TOKEN=token)
        ok(f"token novo da Assiny gerado e guardado em {SEGREDOS}")
        return token, True
    ok(f"token da Assiny reaproveitado de {SEGREDOS}")
    return token, False


# ---------------------------------------------------------------------------------------------------------------
# testes diretos nos serviços
# ---------------------------------------------------------------------------------------------------------------
def testar_supabase(url, cab, modo):
    st, r = chamar("POST", f"{url}/rest/v1/rpc/app_compra_evento", cab, {"p_evento": {"event": "teste_credenciais"}})
    if st in (401, 403):
        raise Falha(f"o Supabase recusou a credencial (HTTP {st})" + (
            ": o papel n8n_compras existe? rodar app_compras_seguranca_n8n.sql; o segredo JWT era o do projeto certo?"
            if modo == "papel" else ""))
    if st == 404:
        raise Falha("app_compra_evento não existe no Supabase: rodar app_compras.sql e app_compras_seguranca_n8n.sql")
    if not (st == 200 and isinstance(r, dict) and r.get("acao") == "ignorado"):
        raise Falha(f"Supabase respondeu HTTP {st} no teste: {str(r)[:160]}")
    ok("Supabase aceitou a credencial (evento de teste registrado como ignorado_evento, sem dado pessoal)")
    st, r = chamar("POST", f"{url}/rest/v1/rpc/app_compras_conciliacao", cab, {"p_horas": 1})
    if st == 404:
        raise Falha("app_compras_conciliacao não existe: o SQL de 24/10 (app_compras_seguranca_n8n.sql) não foi aplicado")
    if not (st == 200 and isinstance(r, dict) and "bloqueios" in r):
        raise Falha(f"app_compras_conciliacao respondeu HTTP {st}: {str(r)[:160]}")
    ok("SQL de 24/10 aplicado (app_compras_conciliacao responde)")
    if modo == "papel":
        st, _ = chamar("GET", f"{url}/rest/v1/crystal_compras?select=id&limit=1", cab)
        if st == 200:
            raise Falha("o papel n8n_compras CONSEGUE ler crystal_compras: não é o esperado. Conferir os grants")
        ok(f"papel n8n_compras não lê tabela (HTTP {st} em crystal_compras)")


def testar_resend(chave):
    st, r = chamar("POST", f"{RESEND}/emails",
                   {"authorization": f"Bearer {chave}", "idempotency-key": f"teste-cred-{secrets.token_hex(8)}"},
                   {"from": REMETENTE, "to": ["delivered@resend.dev"], "subject": "Teste da credencial do n8n",
                    "text": "Teste automático da credencial do n8n. Pode ignorar."})
    if st == 200 and isinstance(r, dict) and r.get("id"):
        return ok(f"Resend aceitou a chave e o remetente {REMETENTE} (e-mail para a caixa de teste)")
    msg = r.get("message", "") if isinstance(r, dict) else (r or "")
    raise Falha(f"o Resend recusou (HTTP {st}): {str(msg).strip()[:160]}")


def testar_api(rota, segredo, nome):
    st, r = chamar("POST", f"{API}{rota}", {"authorization": f"Bearer {segredo}"}, {"event": "teste_credenciais"})
    if st == 200 and isinstance(r, dict) and r.get("ignored"):
        return ok(f"API do app aceitou o segredo de {nome} (evento de teste ignorado)")
    if st == 401:
        raise Falha(f"a API do app recusou o segredo de {nome} que está em .externos: a API no ar usa outro. "
                    "Rodar 'bash bootstrap-vps.sh app-subir <tag atual>' e este script de novo")
    if st == 404:
        raise Falha(f"a rota {rota} está desligada na API (o segredo não chegou ao app): "
                    "'bash bootstrap-vps.sh app-subir <tag atual>' e este script de novo")
    if st == 429:
        raise Falha("a API bloqueou por excesso de tentativas com segredo errado: esperar uns minutos")
    raise Falha(f"API do app respondeu HTTP {st} no teste de {nome}")


# ---------------------------------------------------------------------------------------------------------------
# fluxos e credenciais no banco do n8n
# ---------------------------------------------------------------------------------------------------------------
def achar_fluxos(pg, fluxo_id=None):
    """Devolve {'compras': {id, nome, caminho, ativo, nos, header_auth, novo}, 'conciliacao': {...}|None, 'erro': {...}|None}.
    Sem fluxo_id, o fluxo de compras é o único ativo com o webhook; com fluxo_id, é esse (pode estar inativo)."""
    bruto = sql(pg, f"""select coalesce(json_agg(json_build_object('id', w.id, 'nome', w.name, 'ativo', w.active,
        'nos', (select coalesce(json_agg(json_build_object('nome', n->>'name', 'tipo', n->>'type',
                        'caminho', n#>>'{{parameters,path}}', 'auth', n#>>'{{parameters,authentication}}',
                        'creds', n->'credentials')), '[]') from jsonb_array_elements(w.nodes::jsonb) n))), '[]')
      from workflow_entity w
     where coalesce((to_jsonb(w)->>'isArchived')::boolean, false) = false
       and (w.name in ('{NOME_CONCILIACAO}', '{NOME_ERRO}')
            or exists (select 1 from jsonb_array_elements(w.nodes::jsonb) n
                        where n->>'type' = 'n8n-nodes-base.webhook' and {FILTRO_CAMINHO}));""")
    achados = json.loads(bruto or "[]")
    compras = [f for f in achados if any(n.get("tipo") == "n8n-nodes-base.webhook" and str(n.get("caminho") or "").startswith(CAMINHO)
                                         for n in f["nos"])]
    if not compras:
        raise Falha(f"nenhum fluxo com o webhook '{CAMINHO}' neste n8n: importar compra-assiny.json antes")
    if fluxo_id:
        f = next((x for x in compras if x["id"] == fluxo_id), None)
        if not f:
            raise Falha(f"o fluxo {fluxo_id} não existe ou não tem o webhook '{CAMINHO}'")
        compras = [f]
    ativos = [f for f in compras if f["ativo"]]
    if len(compras) > 1 and len(ativos) != 1:
        nomes = ", ".join(f"{f['id']} ({f['nome']}, {'ativo' if f['ativo'] else 'inativo'})" for f in compras)
        raise Falha(f"mais de um fluxo usa o webhook '{CAMINHO}' e não há exatamente um ativo: {nomes}. "
                    "Desativar ou arquivar os que sobram no editor")
    f = ativos[0] if ativos else compras[0]
    if len(compras) > 1:
        aviso(f"há {len(compras)} fluxos com o webhook '{CAMINHO}'; sigo com o ativo ({f['id']}, {f['nome']})")
    gancho = next(n for n in f["nos"] if n.get("tipo") == "n8n-nodes-base.webhook" and str(n.get("caminho") or "").startswith(CAMINHO))
    f["caminho"] = gancho["caminho"]
    f["header_auth"] = (gancho.get("auth") or "none") != "none"
    f["novo"] = any(n.get("nome") == "Conferir e enxugar" for n in f["nos"])
    outros = {"conciliacao": next((x for x in achados if x["nome"] == NOME_CONCILIACAO), None),
              "erro": next((x for x in achados if x["nome"] == NOME_ERRO), None)}
    return {"compras": f, **outros}


def credenciais_dos_fluxos(fluxos):
    """{papel: {id_credencial: tipo}} juntando os nós dos três fluxos; confere tipo e presença."""
    por_papel = {}
    for chave, f in fluxos.items():
        if not f:
            continue
        for n in f["nos"]:
            papel = PAPEL_DO_NO.get(n.get("nome"))
            if not papel:
                continue
            creds = n.get("creds") or {}
            tipo_esperado = TIPO_DO_PAPEL[papel]
            cid = ((creds.get(tipo_esperado) or {}).get("id")) if isinstance(creds, dict) else None
            if not cid:
                if chave == "compras" and n["nome"] in OBRIGATORIOS_COMPRAS:
                    rotulo = "Custom Auth" if tipo_esperado == "httpCustomAuth" else "Header Auth"
                    raise Falha(f'o nó "{n["nome"]}" do fluxo de compras está sem credencial {rotulo}: '
                                "escolher (ou criar) uma no editor, salvar/publicar e rodar de novo")
                if n["nome"] == "Assiny":
                    continue
                aviso(f'o nó "{n["nome"]}" de "{f["nome"]}" está sem credencial; este fluxo não vai rodar até escolher uma')
                continue
            if not re.fullmatch(r"[A-Za-z0-9]{1,64}", cid):
                raise Falha(f'credencial com id estranho no nó "{n["nome"]}"')
            por_papel.setdefault(papel, {})[cid] = tipo_esperado
    return por_papel


def gravar_no_n8n(editor, pg, por_papel, dados_por_papel):
    """dados_por_papel: papel -> dict com o "data" da credencial. Grava com n8n import:credentials."""
    ids_tipo = {}
    for papel, creds in por_papel.items():
        for cid, tipo in creds.items():
            if cid in ids_tipo and ids_tipo[cid] != (papel, tipo):
                raise Falha(f"a mesma credencial está em nós de papéis diferentes ({ids_tipo[cid][0]} e {papel}): "
                            "no editor, uma credencial para cada papel, e rodar de novo")
            ids_tipo[cid] = (papel, tipo)
    lista = "', '".join(sorted(ids_tipo))
    nomes = json.loads(sql(pg, f"select coalesce(json_object_agg(id, json_build_object('nome', name, 'tipo', type)), '{{}}') "
                               f"from credentials_entity where id in ('{lista}');"))
    falta = sorted(set(ids_tipo) - set(nomes))
    if falta:
        raise Falha("algum nó aponta para credencial apagada: no editor, escolher uma credencial em cada nó")
    for cid, (papel, tipo) in ids_tipo.items():
        if nomes[cid]["tipo"] != tipo:
            rotulo = "Custom Auth" if tipo == "httpCustomAuth" else "Header Auth"
            raise Falha(f'a credencial "{nomes[cid]["nome"]}" ({papel}) não é do tipo {rotulo}: criar uma desse tipo no editor')
    corpo = json.dumps([{"id": cid, "name": nomes[cid]["nome"], "type": tipo, "data": dados_por_papel[papel]}
                        for cid, (papel, tipo) in ids_tipo.items()])
    rodar(["docker", "exec", "-i", editor, "sh", "-c", f"umask 077; cat > {ARQ_NO_CONTAINER}"], entrada=corpo.encode())
    corpo = None
    try:
        rodar(["docker", "exec", editor, "n8n", "import:credentials", f"--input={ARQ_NO_CONTAINER}"])
    finally:
        subprocess.run(["docker", "exec", editor, "rm", "-f", ARQ_NO_CONTAINER], capture_output=True)
    novas = int(sql(pg, f"""select count(*) from credentials_entity where id in ('{lista}')
                            and "updatedAt" > now() - interval '5 minutes';""") or 0)
    if novas != len(ids_tipo):
        raise Falha(f"o n8n só atualizou {novas} de {len(ids_tipo)} credenciais")
    for cid, (papel, _) in sorted(ids_tipo.items(), key=lambda x: x[1][0]):
        ok(f'credencial "{nomes[cid]["nome"]}" ({papel}) gravada, cifrada pela chave do n8n')


def agora_no_banco(pg):
    return sql(pg, "select now()::text;")


def execucoes_com_erro(pg, wid, desde, espera=15):
    """Quantas execuções do fluxo terminaram com erro desde 'desde'. As com sucesso não ficam guardadas (INT-08)."""
    time.sleep(3)
    fim = time.time() + espera
    while True:
        rodando = int(sql(pg, f"""select count(*) from execution_entity where "workflowId" = '{wid}'
            and "createdAt" >= '{desde}'::timestamptz and status in ('new', 'running', 'waiting');""") or 0)
        if rodando == 0 or time.time() > fim:
            break
        time.sleep(1)
    return int(sql(pg, f"""select count(*) from execution_entity where "workflowId" = '{wid}'
        and "createdAt" >= '{desde}'::timestamptz and status in ('error', 'crashed');""") or 0)


# ---------------------------------------------------------------------------------------------------------------
# testes pelo endereço público
# ---------------------------------------------------------------------------------------------------------------
def corpo_assiny(evento, email, tx, produto, status):
    agora = datetime.datetime.now(datetime.timezone.utc).isoformat()
    return {"event": evento, "data": {
        "client": {"id": "teste-n8n-cliente", "email": email, "full_name": "Teste do n8n", "first_name": "Teste"},
        "transaction": {"id": tx, "status": status, "created_at": agora, "updated_at": agora},
        "offer": {"id": "teste-n8n-oferta", "name": "Teste do n8n",
                  "product": {"id": produto, "name": "Teste do n8n"}}}}


def esperar(st, r, status, acao=None, motivo=None, anterior=None, erro=None, rotulo=""):
    d = r if isinstance(r, dict) else {}
    certo = st == status and (acao is None or d.get("acao") == acao) and (motivo is None or d.get("motivo") == motivo) \
        and (anterior is None or d.get("anterior") == anterior) and (erro is None or d.get("erro") == erro)
    if not certo:
        raise Falha(f"{rotulo}: esperava HTTP {status} {acao or erro or ''} {motivo or anterior or ''}".rstrip()
                    + f", veio HTTP {st} {json.dumps(d, ensure_ascii=False)[:160] if d else r}")


def teste_publico(url, token, header_auth):
    if header_auth:
        st, _ = chamar("POST", url, {}, {"event": "teste_credenciais"})
        if st != 403:
            raise Falha(f"sem token o webhook deveria dar 403 e deu {st}")
        ok("sem token: 403 (o n8n recusa antes de executar)")
    else:
        aviso("o webhook não pede cabeçalho: só o caminho secreto protege. Ligue Header Auth no nó Assiny e o "
              "cabeçalho x-crystal-token na Assiny (Avançado > Headers personalizados)")
    cab = {"x-crystal-token": token} if header_auth else {}
    st, r = chamar("POST", url, cab, {"event": "approved_purchase", "data": {}})
    esperar(st, r, 400, erro="corpo_invalido", rotulo="corpo inválido")
    ok("corpo inválido: 400 corpo_invalido (nada chega ao Supabase)")
    st, r = chamar("POST", url, cab, {"event": "teste_credenciais"})
    esperar(st, r, 200, acao="ignorado", rotulo="evento de teste")
    ok("evento de teste: 200 ignorado (passou pelo Supabase)")
    return cab


def teste_completo(pg, wid, url, cab, produto):
    tx = "teste-n8n-" + datetime.datetime.now().strftime("%Y%m%d%H%M%S")
    email = f"delivered+{tx}@resend.dev"
    desde = agora_no_banco(pg)

    st, r = chamar("POST", url, cab, corpo_assiny("approved_purchase", email, tx, produto, "paid"))
    if st == 200 and isinstance(r, dict) and r.get("acao") == "ignorado" and r.get("motivo") == "produto":
        raise Falha(f"o produto {produto} não está em crystal_compras_produtos: passe --produto com um id da lista")
    esperar(st, r, 200, acao="liberado", rotulo="compra de teste")
    if not (isinstance(r, dict) and r.get("novo")):
        raise Falha("compra de teste: liberou mas não veio novo=true (sobra de teste anterior com o mesmo e-mail?)")
    ok("compra de teste: 200 liberado, novo (e-mail de boas-vindas para a caixa de teste do Resend)")

    st, r = chamar("POST", url, cab, corpo_assiny("refunded_purchase", f"delivered+{tx}-vitima@resend.dev",
                                                   f"{tx}-forjada", produto, "refunded"))
    if st == 200 and isinstance(r, dict) and r.get("acao") == "bloqueado":
        raise Falha("reembolso FORJADO bloqueou: a função do Supabase ainda é a antiga. Rodar app_compras_seguranca_n8n.sql")
    esperar(st, r, 200, acao="ignorado", motivo="sem_compra_conhecida", rotulo="reembolso forjado")
    ok("reembolso forjado (e-mail sem compra conhecida): 200 ignorado sem_compra_conhecida, ninguém bloqueado")

    st, r = chamar("POST", url, cab, corpo_assiny("refunded_purchase", email, tx, produto, "refunded"))
    esperar(st, r, 200, acao="bloqueado", rotulo="reembolso de teste")
    ok("reembolso de teste: 200 bloqueado (repassado à API do app, que não tem essa conta: not_found)")

    st, r = chamar("POST", url, cab, corpo_assiny("refunded_purchase", email, tx, produto, "refunded"))
    esperar(st, r, 200, acao="repetido", anterior="bloquear", rotulo="reenvio do reembolso")
    ok("reenvio do reembolso: 200 repetido, anterior=bloquear (a API recebeu de novo e dispensou como duplicado)")

    st, r = chamar("POST", url, cab, corpo_assiny("approved_purchase", email, f"{tx}-pacote", "teste-n8n-pacote", "paid"))
    esperar(st, r, 200, acao="ignorado", motivo="produto", rotulo="produto fora da lista")
    ok("produto fora da lista: 200 ignorado produto (foi à rota de imagens da API, que não o reconhece como pacote)")

    erros = execucoes_com_erro(pg, wid, desde)
    if erros:
        raise Falha(f"{erros} execução(ões) do fluxo terminaram com erro durante o teste: abrir Executions no editor")
    ok("nenhuma execução com erro no n8n durante o teste")
    print("  (sobram linhas de teste: delete from crystal_compras_eventos where transacao like 'teste-n8n-%'; "
          "delete from crystal_compras where email like 'delivered+teste-n8n-%@resend.dev';)")


# ---------------------------------------------------------------------------------------------------------------
def main():
    p = argparse.ArgumentParser(description="Credenciais dos fluxos de compra da Assiny no nosso n8n")
    p.add_argument("--so-conferir", action="store_true")
    p.add_argument("--fluxo", metavar="ID", help="id do fluxo de compras (o novo, ainda inativo, antes da troca)")
    p.add_argument("--sem-teste-completo", action="store_true")
    p.add_argument("--produto", metavar="ID", help="id de crystal_compras_produtos para a compra de teste (fica guardado)")
    p.add_argument("--novo-token", action="store_true")
    p.add_argument("--mostrar-token", action="store_true")
    p.add_argument("--supabase-chave", action="store_true")
    p.add_argument("--supabase-papel", action="store_true")
    p.add_argument("--resend-chave", action="store_true")
    p.add_argument("--reaproveitar-do-app", action="store_true")
    a = p.parse_args()
    if a.supabase_chave and a.supabase_papel:
        raise Falha("escolha --supabase-chave ou --supabase-papel")

    print("== fluxos no n8n")
    editor, pg = container(EDITOR), container(POSTGRES)
    fluxos = achar_fluxos(pg, a.fluxo)
    compras = fluxos["compras"]
    url = WEBHOOK_BASE + compras["caminho"]
    ok(f"compras: {compras['id']} ({compras['nome']}), {'ativo' if compras['ativo'] else 'INATIVO'}, "
       f"{'cabeçalho + caminho' if compras['header_auth'] else 'só caminho secreto'}")
    if not compras["novo"]:
        raise Falha("o fluxo de compras no ar é a versão antiga (sem o nó 'Conferir e enxugar'): importar o "
                    "compra-assiny.json de 24/10 (README) antes de rodar este script")
    for chave, rotulo in (("conciliacao", NOME_CONCILIACAO), ("erro", NOME_ERRO)):
        f = fluxos[chave]
        if f:
            ok(f"{rotulo}: {f['id']}, {'ativo' if f['ativo'] else 'INATIVO'}")
        else:
            aviso(f"'{rotulo}' não está importado (opcional, recomendado)")
    por_papel = credenciais_dos_fluxos(fluxos)

    seg = ler_kv(SEGREDOS)
    if a.so_conferir:
        print("== conferência pública (só leitura)")
        token = seg.get("ASSINY_N8N_TOKEN") or ""
        if compras["header_auth"] and not token:
            raise Falha(f"o webhook pede cabeçalho e não há token em {SEGREDOS}: rodar sem --so-conferir")
        teste_publico(url, token, compras["header_auth"])
        print("Pronto: só leitura, nada gravado.")
        return

    print("== chaves")
    ext = ler_kv(EXTERNOS)
    if limpo("SUPABASE_URL", ext.get("SUPABASE_URL"), EXTERNOS).rstrip("/") != SUPABASE_DO_FLUXO:
        raise Falha(f"SUPABASE_URL de .externos não é o projeto do fluxo ({SUPABASE_DO_FLUXO})")
    reembolso = limpo("REFUND_WEBHOOK_SECRET", ext.get("REFUND_WEBHOOK_SECRET"), EXTERNOS)
    imagens = (ext.get("IMAGENS_WEBHOOK_SECRET") or "").strip()
    if imagens:
        imagens = limpo("IMAGENS_WEBHOOK_SECRET", imagens, EXTERNOS)
        ok("IMAGENS_WEBHOOK_SECRET próprio para a rota de imagens")
    else:
        imagens = reembolso
        aviso("sem IMAGENS_WEBHOOK_SECRET em .externos: a rota de imagens usa o segredo do reembolso (INT-01). "
              "Definir um (openssl rand -hex 32) e subir a API de novo quando o bootstrap aceitar o nome")
    ext = None
    modo, cab_supabase = cabecalhos_supabase(seg, a)
    resend = chave_resend(seg, a)
    token, novo = token_assiny(seg, a)
    if a.produto:
        if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._:-]{0,79}", a.produto):
            raise Falha("--produto fora do formato")
        gravar_kv(SEGREDOS, N8N_PRODUTO_TESTE=a.produto)
    produto = a.produto or ler_kv(SEGREDOS).get("N8N_PRODUTO_TESTE")

    print("== teste de cada chave direto no serviço (antes de mexer no n8n)")
    testar_supabase(SUPABASE_DO_FLUXO, cab_supabase, modo)
    testar_resend(resend)
    testar_api("/webhooks/reembolso", reembolso, "reembolso")
    testar_api("/webhooks/imagens", imagens, "imagens")

    print("== credenciais no n8n")
    dados = {
        "assiny": {"name": "x-crystal-token", "value": token},
        "supabase": {"json": json.dumps({"headers": cab_supabase})},
        "resend": {"name": "Authorization", "value": f"Bearer {resend}"},
        "reembolso": {"name": "Authorization", "value": f"Bearer {reembolso}"},
        "imagens": {"name": "Authorization", "value": f"Bearer {imagens}"},
    }
    gravar_no_n8n(editor, pg, por_papel, dados)
    dados = cab_supabase = resend = reembolso = imagens = None

    if not compras["ativo"]:
        aviso("o fluxo de compras escolhido está INATIVO: credenciais gravadas, testes públicos pulados. Configure o "
              "cabeçalho na Assiny, desative o antigo, ative este e rode o script de novo (sem --fluxo)")
        print("\nNa Assiny (Integrações > Webhooks > o webhook da Crystal > Avançado > Headers personalizados): x-crystal-token")
        if novo or a.mostrar_token:
            print(f"  Valor:     {token}")
            print("  (copiar para a Assiny e para o Bitwarden; nunca para o chat)")
        else:
            print("  Valor: o mesmo de antes (para ver: --mostrar-token)")
        return

    print("== teste pelo endereço público")
    cab = teste_publico(url, token, compras["header_auth"])

    if a.sem_teste_completo:
        pass
    elif not produto:
        aviso("teste completo pulado: passe --produto <id de crystal_compras_produtos> (uma vez; fica guardado)")
    else:
        print("== teste completo (caixa de teste do Resend)")
        teste_completo(pg, compras["id"], url, cab, produto)

    print("\nPronto. Na Assiny (Integrações > Webhooks > o webhook da Crystal):")
    print(f"  URL: {WEBHOOK_BASE}{CAMINHO}-<sufixo secreto, o mesmo de hoje>")
    print("  Avançado > Headers personalizados: x-crystal-token")
    if novo or a.mostrar_token:
        print(f"  Valor:     {token}")
        print("  (copiar para a Assiny e para o Bitwarden; nunca para o chat)")
    else:
        print("  Valor: o mesmo de antes (para ver: --mostrar-token)")
    print("  Eventos: compra aprovada, compra reembolsada, chargeback (e os de assinatura, se houver).")


if __name__ == "__main__":
    try:
        main()
    except Falha as e:
        print(f"ERRO: {e}")
        sys.exit(1)
    except (KeyboardInterrupt, EOFError):
        print("\nInterrompido.")
        sys.exit(130)
