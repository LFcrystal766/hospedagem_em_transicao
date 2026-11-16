"""Monta a cópia estática do crystalnowpp.com.br.

Uso: python3 -I montar.py <todas.txt> <coleta.json> <pasta_saida>

- Páginas: o HTML como o servidor entrega (cache do LiteSpeed), em <caminho>/index.html.
- Arquivos do próprio domínio (wp-content, wp-includes): os pedidos pelas páginas na coleta, mais os achados
  dentro do HTML, do CSS e do JS (inclusive os endereços escapados do Elementor), até não sobrar nenhum novo.
- Endereços absolutos dos arquivos viram relativos à raiz (/wp-content/...), para a cópia usar os próprios arquivos.
  Os links entre páginas, o canonical e o rastreio não mudam.
"""
import concurrent.futures as cf
import json
import os
import re
import subprocess
import sys
import urllib.parse

ORIGEM = "crystalnowpp.com.br"
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36"
arq_urls, arq_coleta, SAIDA = sys.argv[1:4]
SAIDA = os.path.abspath(SAIDA)
os.makedirs(SAIDA, exist_ok=True)


def local(caminho_url: str, pagina: bool = False) -> str:
    p = urllib.parse.unquote(caminho_url.split("?")[0].split("#")[0])
    if pagina:
        p = p.rstrip("/") + "/index.html" if p not in ("", "/") else "/index.html"
    destino = os.path.abspath(os.path.join(SAIDA, p.lstrip("/")))
    if not destino.startswith(SAIDA + os.sep):
        raise ValueError(f"caminho fora da pasta: {caminho_url}")
    return destino


def baixar(url: str, destino: str) -> int:
    if os.path.isdir(destino):
        return -1  # endereço de pasta (base de um plugin), não de arquivo
    os.makedirs(os.path.dirname(destino), exist_ok=True)
    r = subprocess.run(["curl", "-sS", "-L", "--max-time", "120", "-A", UA, "-o", destino, "-w", "%{http_code}", url],
                       capture_output=True, text=True)
    codigo = int(r.stdout or 0)
    if codigo != 200 and os.path.isfile(destino):
        os.remove(destino)
    return codigo


# Endereços de arquivos do domínio: absolutos, sem protocolo, escapados (\/) e relativos à raiz.
RE_ABS = re.compile(r"(?:https?:)?(?:\\?/){2}(?:www\.)?crystalnowpp\.com\.br((?:\\?/)(?:wp-content|wp-includes)(?:\\?/)[^\s\"'()<>,]+)")
RE_RAIZ = re.compile(r"[\"'(\s,=]((?:\\?/)(?:wp-content|wp-includes)(?:\\?/)[^\s\"'()<>,]+)")
RE_CSS_URL = re.compile(r"url\(\s*['\"]?([^'\")]+)['\"]?\s*\)")
RE_IMPORT = re.compile(r"@import\s+['\"]([^'\"]+)['\"]")


def limpar(caminho: str) -> str:
    c = caminho.replace("\\/", "/").replace("&amp;", "&")
    c = re.sub(r"[\\;]+$", "", c)
    return c.split("?")[0].split("#")[0]


def achar_refs(texto: str, url_base: str, css: bool):
    refs = set()
    for m in RE_ABS.finditer(texto):
        refs.add(limpar(m.group(1)))
    for m in RE_RAIZ.finditer(texto):
        refs.add(limpar(m.group(1)))
    if css:
        for m in list(RE_CSS_URL.finditer(texto)) + list(RE_IMPORT.finditer(texto)):
            alvo = m.group(1).strip()
            if alvo.startswith(("data:", "#")):
                continue
            u = urllib.parse.urlparse(urllib.parse.urljoin(url_base, alvo))
            if u.hostname in (ORIGEM, "www." + ORIGEM):
                refs.add(u.path)
    return {r for r in refs if re.match(r"^/wp-(content|includes)/", r) and re.search(r"/[^/]+\.[A-Za-z0-9]{1,6}$", r)}


def reescrever(texto: str) -> str:
    texto = re.sub(r"(?:https?:)?//(?:www\.)?crystalnowpp\.com\.br/(wp-content|wp-includes)/", r"/\1/", texto)
    texto = re.sub(r"(?:https?:)?\\/\\/(?:www\.)?crystalnowpp\.com\.br\\/(wp-content|wp-includes)\\/", r"\\/\1\\/", texto)
    return texto


TEXTO = (".html", ".css", ".js", ".json", ".svg", ".xml", ".txt")

# 1. Páginas.
paginas = [u.strip() for u in open(arq_urls) if u.strip()]
relatorio = {"paginas": {}, "arquivos_ok": 0, "arquivos_falha": {}}
for u in paginas:
    d = local(urllib.parse.urlparse(u).path, pagina=True)
    relatorio["paginas"][u] = baixar(u, d)

# 2. Arquivos: os da coleta, depois os achados nos textos, até acabar.
coleta = json.load(open(arq_coleta))
pendentes = set()
for r in coleta:
    for a in r["arquivos"]:
        p = urllib.parse.urlparse(a)
        if p.path.startswith(("/wp-content/", "/wp-includes/")):
            pendentes.add(p.path)
feitos = set()
lidos = set()
rodada = 0
while True:
    rodada += 1
    # Lê os textos ainda não lidos (páginas e arquivos já baixados) atrás de novos endereços.
    for raiz, _, nomes in os.walk(SAIDA):
        for n in nomes:
            f = os.path.join(raiz, n)
            if f in lidos or not n.endswith(TEXTO):
                continue
            lidos.add(f)
            rel = "/" + os.path.relpath(f, SAIDA).replace(os.sep, "/")
            base = f"https://{ORIGEM}{rel}"
            with open(f, encoding="utf-8", errors="replace") as h:
                pendentes |= achar_refs(h.read(), base, css=n.endswith(".css"))
    novos = sorted(pendentes - feitos)
    if not novos:
        break
    print(f"rodada {rodada}: {len(novos)} arquivos", flush=True)
    with cf.ThreadPoolExecutor(8) as ex:
        futuros = {}
        for c in novos:
            try:
                futuros[ex.submit(baixar, f"https://{ORIGEM}{urllib.parse.quote(urllib.parse.unquote(c))}", local(c))] = c
            except ValueError as e:
                relatorio["arquivos_falha"][c] = str(e)
        for fu in cf.as_completed(futuros):
            c = futuros[fu]
            codigo = fu.result()
            if codigo == 200:
                relatorio["arquivos_ok"] += 1
            elif codigo == -1:
                pass
            else:
                relatorio["arquivos_falha"][c] = codigo
    feitos |= set(novos)

# 2b. Pedaços do Elementor que só carregam quando precisam (lightbox, pop-up...): a lista sai do mapa do webpack
#     dentro dos JS juntados pelo LiteSpeed; o runtime do Pro é o que cita "paypal-button".
lsjs = os.path.join(SAIDA, "wp-content", "litespeed", "js")
for n in (os.listdir(lsjs) if os.path.isdir(lsjs) else []):
    with open(os.path.join(lsjs, n), encoding="utf-8", errors="replace") as h:
        t = h.read()
    if "__webpack_require__.u=" not in t or ".bundle.min.js" not in t:
        continue
    plugin = "elementor-pro" if "paypal-button" in t else "elementor"
    for nome in sorted(set(re.findall(r'"([A-Za-z0-9._-]+\.bundle\.min\.js)"', t))):
        caminho = f"/wp-content/plugins/{plugin}/assets/js/{nome}"
        if not os.path.isfile(local(caminho)):
            codigo = baixar(f"https://{ORIGEM}{caminho}", local(caminho))
            if codigo == 200:
                relatorio["arquivos_ok"] += 1
            else:
                relatorio["arquivos_falha"][caminho] = codigo

# 2c. Página "não encontrada", sitemaps do Rank Math, robots.txt e o noindex do endereço provisório.
baixar(f"https://{ORIGEM}/esta-pagina-nao-existe-copia-estatica/", os.path.join(SAIDA, "404.html"))
if not os.path.isfile(os.path.join(SAIDA, "404.html")):  # o servidor responde 404: o curl só guarda com 200
    subprocess.run(["curl", "-sS", "-A", UA, "-o", os.path.join(SAIDA, "404.html"),
                    f"https://{ORIGEM}/esta-pagina-nao-existe-copia-estatica/"], check=False)
for n in ("sitemap_index.xml", "page-sitemap.xml", "post-sitemap.xml", "category-sitemap.xml", "main-sitemap.xsl"):
    baixar(f"https://{ORIGEM}/{n}", os.path.join(SAIDA, n))
with open(os.path.join(SAIDA, "robots.txt"), "w") as h:
    h.write("User-agent: *\nAllow: /\n\nSitemap: https://crystalnowpp.com.br/sitemap_index.xml\n")
with open(os.path.join(SAIDA, "_headers"), "w") as h:  # tirar na virada para o domínio
    h.write("/*\n  X-Robots-Tag: noindex, nofollow\n")

# 3. Endereços absolutos dos arquivos viram relativos à raiz.
trocados = 0
for raiz, _, nomes in os.walk(SAIDA):
    for n in nomes:
        if not n.endswith((".html", ".css", ".js", ".json")):
            continue
        f = os.path.join(raiz, n)
        with open(f, encoding="utf-8", errors="surrogateescape") as h:
            antes = h.read()
        depois = reescrever(antes)
        if depois != antes:
            trocados += 1
            with open(f, "w", encoding="utf-8", errors="surrogateescape") as h:
                h.write(depois)
relatorio["arquivos_reescritos"] = trocados
json.dump(relatorio, open(os.path.join(os.path.dirname(SAIDA), "montagem.json"), "w"), indent=1)
print(json.dumps({"paginas": len(paginas), "paginas_ok": sum(1 for v in relatorio["paginas"].values() if v == 200),
                  "arquivos_ok": relatorio["arquivos_ok"], "falhas": relatorio["arquivos_falha"],
                  "reescritos": trocados}, indent=1))
