# Cópia estática do crystalnowpp.com.br (Cloudflare Pages)

Feita em 16/11/2026 a pedido do dono: "faça essas cópias no Cloudflare, mas não ponha no ar ainda".

- **O site de verdade continua na AZAN.** O domínio não aponta para esta cópia.
- **Esta pasta é o site inteiro:**
  - 53 páginas publicadas, mais a home, um post e uma categoria;
  - os arquivos que elas usam: imagens, fontes, CSS e JS do Elementor e do LiteSpeed;
  - sem WordPress, sem PHP e sem banco.

## O que tem aqui

| Caminho | O que é |
|---|---|
| `publicar/` | O que vai para o Cloudflare Pages: uma pasta por página (`<página>/index.html`) e `wp-content/`, `wp-includes/` |
| `publicar/_headers` | `X-Robots-Tag: noindex` em tudo, para o endereço provisório (`*.pages.dev`) não entrar no Google. **Tirar na virada** |
| `publicar/robots.txt` | Aponta para o `sitemap_index.xml`, o sitemap real do Rank Math (ver "Achado" abaixo) |
| `publicar/404.html` | A página "não encontrada" do site |
| `ferramentas/paginas.txt` | A lista de endereços copiados |
| `ferramentas/coletar.js` | Abre cada página (computador e celular) e anota os arquivos que ela pede |
| `ferramentas/montar.py` | Baixa páginas e arquivos e troca o endereço absoluto dos arquivos (`https://crystalnowpp.com.br/wp-content/…`) por `/wp-content/…` |
| `ferramentas/comparar.js` | Abre cada página no original e na cópia e compara o que cada uma chama, o que falta e a foto |

Nas duas ferramentas que abrem páginas, tudo o que é de fora fica bloqueado: Stape, GTM, Meta, TikTok, o player de
vídeo e o rastreador da Assiny. Assim a cópia não gera visita falsa no rastreio.

## O que mudou em relação ao original (e o que não mudou)

- **Mudou só o endereço dos arquivos do próprio site** (imagens, CSS, JS, fontes): de absoluto para relativo à raiz.
  - No endereço provisório, a cópia usa os próprios arquivos, e não os da AZAN.
  - No domínio, dá no mesmo.
- **Não mudou:**
  - o rastreio;
  - os links entre páginas;
  - o `canonical`;
  - os botões de compra.
- **Elementor:** além dos arquivos que as páginas pediram, vieram os 69 pedaços de JS (23 do Elementor e 46 do Pro)
  que ele só carrega quando precisa, como a lightbox e o pop-up.

## Conferência de 16/11 (antes de subir para o Cloudflare)

A cópia foi servida aqui, como o Cloudflare Pages serve, e comparada com o original. Foram 56 páginas, cada uma como
computador e como celular, num total de 112 aberturas:

- 112 de 112 com HTTP 200 nos dois lados.
- **Os mesmos endereços de fora nas 112** (rastreio, vídeo, compra):
  - `server.crystalnowpp.com.br` (loader do Stape + GTM): 112;
  - `scripts.converteai.net` (player): 84;
  - `www.youtube.com`: 40;
  - `tracker.assiny.com.br`: 34;
  - `connect.facebook.net`: 2.
- **Nenhum arquivo faltando na cópia** e nenhum pedido ao site antigo.
- **Foto do alto da página:** 105 de 112 iguais.
  - As 7 diferentes têm partes que se mexem sozinhas: o contador regressivo, o carrossel de depoimentos e as
    animações. Conferido a olho em `/teste/`, que tinha a maior diferença: o carrossel parou em outro slide.

## Achado: `robots.txt` do site atual

O `robots.txt` da AZAN lista 5 sitemaps que **não existem**: `sitemap613.xml`, `sitemap592.xml`, `sitemap669.xml`,
`sitemap690.xml` e `sitemap712.xml`, todos com 404.

- Linhas assim costumam ser rastro de invasão que injeta spam no WordPress, ou de plugin removido pela metade.
- A cópia usa o sitemap real.
- **Conferir no WordPress** (precisa do acesso):
  - de onde vêm essas linhas;
  - se há usuário, plugin ou trecho no Code Snippets que ninguém reconhece.

## Ainda não conferido (precisa do acesso ao WordPress)

- **Redirecionamentos do Rank Math.** Os que existirem precisam virar um `_redirects` aqui.
- **O que o Code Snippets faz.** Se algum trecho roda no servidor (PHP), a cópia não faz.
- **A regra do LiteSpeed que tira `fbclid`/`utm`/`gclid`.** No Cloudflare isso vira regra da zona. Lembrete: URL que
  responde 301 nunca recebe `fbclid`.

## Atualizar a cópia (o WordPress continua sendo editado até a virada)

```bash
SP=<pasta temporária>
node ferramentas/coletar.js ferramentas/paginas.txt $SP/coleta.json
python3 -I ferramentas/montar.py ferramentas/paginas.txt $SP/coleta.json $SP/copia
node ferramentas/comparar.js $SP/copia ferramentas/paginas.txt $SP/comparacao
```

Antes da virada, rodar de novo e conferir de novo. Em 16/11, a última página editada no WordPress era de 14/11
(`/crystal-yt/`).
