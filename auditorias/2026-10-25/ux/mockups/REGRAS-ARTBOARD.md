# Como escrever um artboard do canvas de mockups da Crystal

Cada tela "antes → depois" é UM arquivo `.dc.html` em
`/tmp/claude-0/-home-user-hospedagem-em-transicao/a2a2bc38-c612-550a-a226-1af1e7b739be/scratchpad/ux/canvas/project/`.
Escreva cada arquivo inteiro com a ferramenta Write (um Write por arquivo). Nunca gere arquivos por script.
Não leia de volta, não renderize, não tire print, não rode verificação: escreva certo da primeira vez.

## Regras que quebram em silêncio se forem esquecidas

- Nome do arquivo: `<grupo>-<tela>.dc.html`, só letras minúsculas, dígitos e `-` (ex.: `aluna-login-codigo.dc.html`).
- A linha `<script src="./support.js"></script>` no `<head>` EXATAMENTE assim.
- Feche todo elemento que não é vazio; aspas em todo atributo. `<img>`, `<input>`, `<br>` não fecham.
- Tudo com estilo inline (`style="…"`). O `<helmet><style>` só tem `body{margin:0}` e as cores de `a`/`a:hover`.
- Nunca escreva duas chaves seguidas `{` `{` em lugar nenhum do texto (o formato lê como variável).
- Sempre o bloco `<script type="text/x-dc" data-dc-script …>` do fim, com `$preview` igual ao tamanho do artboard.
- Sem `<style>` fora do helmet, sem `<script>` além dos dois do modelo, sem `<iframe>`, sem emoji, sem imagem externa.
- A captura "antes" entra como `<img src="/_blob/<id>">` com a URL EXATA do mapa `canvas/assets.json` (chave = nome do PNG).
  Captura sem URL no mapa: no lugar do `<img>`, um quadro cinza 390×844 com o nome da captura escrito.
- Ícones: `<svg>` inline com stroke, `aria-hidden="true"`. Botões são `<button>`, campos são `<input>` com `<label>`,
  tabelas são `<table>`, links são `<a href="#">`. Nunca `onClick` nem `role` em `<div>`/`<span>`.
- Contraste de texto ≥ 4,5:1 (rótulos cinza pequenos também). Alvos de toque ≥ 44 px. Campos com fonte 16 px.
- Textos em pt-BR, tirados do PRD (`/home/user/cw-ux/docs/ux/PRD-ux-ui-2026-10-25.md`, seção "Textos palavra por
  palavra" do item que atende o achado). Nomes fictícios (Ana, Bia, Ana Souza), e-mails fictícios (ana@exemplo.com).
  Nunca dado pessoal real, nunca segredo, nunca nome ou identificador de modelo de IA ("modelo atual", "modelo econômico").
- `lang="pt-BR"` no `<html>`; `<title>` com o nome da tela.

## Modelo 1: tela de celular (artboard 1320 × 1060)

```html
<!doctype html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<title>Login · passo do código</title>
<script src="./support.js"></script>
</head>
<body>
<x-dc>
<helmet>
<style>
body{margin:0}
a{color:#0F5C4A}a:hover{color:#0A4236}
</style>
</helmet>
<div style="width: 1320px; height: 1060px; box-sizing: border-box; padding: 40px; background: #F1F5F9; font-family: system-ui, -apple-system, 'Segoe UI', Roboto, sans-serif; color: #0F172A; display: flex; flex-direction: column; gap: 24px">
  <div style="display: flex; flex-direction: column; gap: 6px">
    <h1 style="margin: 0; font-size: 28px; line-height: 1.2">Login · passo do código</h1>
    <p style="margin: 0; font-size: 15px; color: #475569">Achados UX-01, UX-05 · PRD U10 · U-onda 1</p>
  </div>
  <div style="display: flex; gap: 40px; align-items: flex-start">
    <figure style="margin: 0; display: flex; flex-direction: column; gap: 8px">
      <figcaption style="font-size: 13px; font-weight: 700; letter-spacing: 0.04em; text-transform: uppercase; color: #475569">Antes · hoje</figcaption>
      <img src="/_blob/ID_DA_CAPTURA" alt="Tela atual do passo do código" style="display: block; width: 390px; height: 844px; object-fit: cover; object-position: top; border-radius: 28px; border: 1px solid #CBD5E1">
    </figure>
    <figure style="margin: 0; display: flex; flex-direction: column; gap: 8px">
      <figcaption style="font-size: 13px; font-weight: 700; letter-spacing: 0.04em; text-transform: uppercase; color: #0F5C4A">Depois · proposta</figcaption>
      <div style="width: 390px; height: 844px; overflow: hidden; position: relative; box-sizing: border-box; border-radius: 28px; border: 1px solid #CBD5E1; background: #FFFFFF">
        <!-- a tela redesenhada, fiel ao app de hoje, só com as mudanças dos achados -->
      </div>
    </figure>
    <div style="width: 380px; display: flex; flex-direction: column; gap: 12px; padding-top: 28px">
      <h2 style="margin: 0; font-size: 18px">O que mudou</h2>
      <ul style="margin: 0; padding-left: 20px; display: flex; flex-direction: column; gap: 10px; font-size: 15px; line-height: 1.45">
        <li><b>UX-01</b> · uma frase sobre a mudança.</li>
      </ul>
    </div>
  </div>
</div>
</x-dc>
<script type="text/x-dc" data-dc-script data-props='{"$preview":{"width":1320,"height":1060}}'>
class Component extends DCLogic {
  renderVals() { return {}; }
}
</script>
</body>
</html>
```

## Modelo 2: tela de computador do painel (artboard 1760 × 1900)

Mesmo esqueleto, com o root `width: 1760px; height: 1900px` e `$preview` `{"width":1760,"height":1900}`. Dentro:

1. o mesmo cabeçalho (h1 + linha de achados);
2. uma linha com o "Depois" (`<figure>` com a moldura `width: 1280px; height: 800px; overflow: hidden; border-radius: 12px`)
   e, à direita, o bloco "O que mudou" (`width: 380px`);
3. embaixo, o "Antes" (`<img>` com `width: 1280px; height: 800px; object-fit: cover; object-position: top; border-radius: 12px`).

## Tokens reais (confira e complete em `ux/mapa-design.md`)

Use os valores hex do app que estão no `mapa-design.md` (marca, fundo do chat, bolhas, textos, bordas, erro, aviso,
sucesso, painel). Quando o PRD trocar uma cor por contraste (item U01 e a seção "Tokens e componentes"), use a cor NOVA
do PRD no "Depois" e diga isso no "O que mudou".
