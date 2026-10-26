# KIT visual da Crystal depois do PRD de UX/UI (25/10/2026)

Kit para desenhar as telas finais do app da aluna e do painel da equipe como ficam depois das três
U-ondas do PRD (`docs/ux/PRD-ux-ui-2026-10-25.md`, itens U01 a U58). O PRD corrige e unifica: a marca,
o rosa `#e60a68`, os temas tirados do WhatsApp no iPhone, o papel de parede, as bolhas, os tiques e o
"digitando…" não mudam. Tudo aqui foi copiado do código real (`apps/web/app/globals.css` e
`components/` em `3c343df`) com os valores finais do PRD.

| Arquivo | O que é |
|---|---|
| `ds.css` | Fontes, tokens claro e escuro, reset, todos os componentes e as duas molduras |
| `icones.md` | 45 ícones em SVG (grade 24, traço 1,75) com o trecho pronto |
| `assets/` | Imagens reais do app (lista no fim) |
| `fonts/` | Inter Tight variável e Blinker 400/600/700 (as mesmas do app) |
| `render.js` | Gera `png/<tela>.png` a partir de `telas/<tela>.html` |

Regras de conteúdo: português do Brasil; nomes e e-mails fictícios (Ana Souza, Bia, Rui Ferreira,
Carla Mendes, `ana@exemplo.com`); nenhum nome ou identificador de modelo de IA (escreva "modelo atual",
"modelo econômico"); sem emoji; sem lorem ipsum. As falas da Crystal vêm do modo de demonstração das
capturas ("Oi! Que bom te ver por aqui.", "Me conta: em que posso te ajudar hoje?") ou são frases curtas
no tom dela; nunca uma regra nova de comportamento.

---

## 1. Estrutura de uma tela

### Celular 390 × 844 (o iPhone do dono)

```html
<!doctype html>
<html lang="pt-BR">                      <!-- escuro: <html lang="pt-BR" class="tema-escuro"> -->
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="viewport-mock" content="390x844">
<title>Início da aluna</title>
<link rel="stylesheet" href="../ds.css">
</head>
<body>
<div class="tela">
  <!-- moldura da aluna (.app ou .chat) ou do painel (.staff) -->
</div>
</body>
</html>
```

### Computador 1280 × 800

Mesma coisa com `<meta name="viewport-mock" content="1280x800">`. As media queries do kit fazem o
resto: acima de 768 px a barra lateral do painel aparece, a barra inferior e a barra de título somem,
a `.sheet` vira painel lateral, o `.dialog` fica centrado e os campos do painel voltam a 14 px.

- Imagens: `../assets/crystal-foto.jpg`, `../assets/papel-de-parede-claro.png` etc.
- Renderizar: `cd <pasta visual> && NODE_PATH=/opt/node22/lib/node_modules node render.js <prefixo>`.
  Celular sai em 2x; o `render.js` avisa se algo vazar da largura.
- `.tela` tem a altura exata da viewport e corta o que passar (o PNG é só a parte visível). Véu, toast e
  barra inferior se posicionam dentro da `.tela`.
- O render usa `prefers-reduced-motion: reduce`: esqueleto, spinner e "digitando…" saem parados.

### Tema, tamanho da letra e estados

- Claro é o padrão do kit; escuro é `class="tema-escuro"` no `<html>`.
- Tamanho da letra (U58): `data-text="lg"` (Grande, 1,15) ou `data-text="xl"` (Muito grande, 1,3) no `<html>`.
- Estados desenháveis em qualquer componente: `.is-focus` (anel de foco do teclado, U02), `.is-hover`,
  `.is-active` (dedo em cima), `.is-disabled` ou `disabled`, `.is-busy`, `.is-invalido`, `.is-ativo` /
  `.is-ativa`, `.is-ligado`.
- Foco (U02): contorno de 2 px em `--brand-ink`, 2 px de folga, em tudo. Sobre fundo rosa ou verde
  (dentro da bolha da aluna, na faixa de instalar) envolva com `.sobre-cor` e o anel fica branco.
  Campos: borda rosa + anel de 2 px `--brand-ink`.

---

## 2. Cores finais

| Token | Claro | Escuro | Uso |
|---|---|---|---|
| `--bg-app` | `#ffffff` | `#0b141a` | fundo da página e do conteúdo do painel |
| `--surface` | `#f0f2f5` | `#202c33` | coluna da aluna, cabeçalhos, cartões, barra lateral, diálogos |
| `--surface-2` | `#e9edef` | `#2a3942` | campos, caminhos do início, item tocado |
| `--ink` | `#111b21` | `#e9edef` | texto |
| `--ink-muted` | `#54656f` | `#9aa8b2` | texto de apoio (5,1 e 4,9:1 sobre `surface-2`) |
| `--brand` | `#e60a68` | `#e60a68` | rosa da marca: bolha da aluna, botão primário, item ativo |
| `--brand-ink` | `#b8004f` | `#ff7aac` | texto rosa, links, aba ativa, anel de foco |
| `--brand-press` | `#c20857` | `#c20857` | hover e toque do botão rosa (branco a 6,1:1) |
| `--on-brand` | `#ffffff` | `#ffffff` | texto sobre rosa e sobre o verde |
| `--cta-gradient` | `#0b8900 → #0a7500` | igual | botão de entrar (U01 decisão A; branco a 4,57 e 5,9:1) |
| `--success` | `#0ba900` | `#0ba900` | bolinha "online" |
| `--success-ink` | `#097200` | `#6fe05f` | texto do aviso de sucesso |
| `--success-strong` | `#067a00` | `#067a00` | texto verde sobre branco fixo (botão da faixa de instalar) |
| `--warning` / `--warning-ink` | `#b77f00` / `#6b4a00` | `#f5b301` / `#ffd166` | aviso amarelo (o antigo `accent`) |
| `--danger` | `#d40003` | `#ff0004` | borda, ícone, bolinha de gravação |
| `--danger-ink` | `#b80003` | `#ff8a8d` | todo texto de erro (5,2 a 8,2:1) |
| `--danger-solid` | `#d40003` | `#d40003` | botão de perigo (branco a 5,5:1) |
| `--border` / `--border-strong` | `#e9edef` / `#d1d7db` | `#2a3942` / `#3b4a54` | linhas / contorno de botão secundário e chip |
| `--control-off` | `#76858e` | `#76868f` | trilho do interruptor desligado, borda da caixa de marcar (3:1) |
| `--scrim` | `rgba(17,27,33,.45)` | `rgba(11,20,26,.8)` | véu de diálogo e folha |
| `--bubble-bot` | `#ffffff` | `#202c33` | bolha da Crystal |
| `--chat-bg` | `#efeae2` | `#0b141a` | base do papel de parede |
| `--tick-read` | `#bfe9ff` | `#bfe9ff` | tiques azuis "lida" |
| `--toast-bg` / `--toast-acao` | `#111b21` / `#ff7aac` | `#e9edef` / `#b8004f` | toast e o "Desfazer" |

Ajustes feitos no kit para fechar o AA (o PRD manda ajustar o tom sem trocar a matiz): `--success-ink`
claro `#0a7500 → #097200` (4,49 → 4,67:1 no aviso de sucesso); `--brand-press` no lugar do
`--brand-strong` no hover (o `#ff1f7a` do escuro dá 3,67:1); `--toast-acao` no lugar de `text-brand`
(3,83:1 sobre o toast); `--control-off` para o interruptor; `.contador` amarelo com tinta escura (o
`SupportBadge` de hoje dá 2,32 e 1,29:1).

Tipografia: corpo em Inter Tight 15 px (`--fs-body`), títulos em Blinker 600. Escala: `--fs-xs` 12,
`--fs-sm` 14, `--fs-base` 16, `--fs-lg` 18, `--fs-xl` 20, `--fs-2xl` 24. A hora da bolha (`--fs-2xs`)
fica em 12 px (o `max(0.75rem, …)` do U58). Raios: 6, 8, 10 (botão e campo), 12 (cartão e bolha), 20
(diálogo, folha, cartão do login, caixa de escrever). Nenhum campo abaixo de 16 px no celular (U03).

---

## 3. Componentes

### Botão (U48): sempre `rounded-lg`, `font-medium`

```html
<button class="btn btn-primary btn-lg btn-full">Salvar</button>      <!-- aluna: lg (48 px, 16 px) -->
<button class="btn btn-primary">Salvar</button>                      <!-- painel: md (44 px, 14 px) -->
<button class="btn btn-secondary">Cancelar</button>
<button class="btn btn-danger">Excluir minha conta</button>
<button class="btn btn-text">Tentar de novo</button>                 <!-- sublinhado; .is-marca = rosa -->
<button class="btn btn-cta btn-lg btn-full">Receber o código</button> <!-- só no login -->
<button class="btn btn-primary is-busy" disabled><span class="spinner"></span>Salvando…</button>
<button class="btn btn-primary is-focus">Salvar</button>             <!-- foco de teclado -->
<button class="btn btn-secondary"><svg class="icon" …>…</svg>Copiar e-mail</button>
```

Botão redondo só de ícone (pílula só aqui, em chip, badge e avatar):

```html
<button class="icon-btn" aria-label="Abrir menu"><!-- ícone menu-tres-pontos --></button>
<button class="icon-btn is-tinta" aria-label="Voltar ao início"><!-- voltar, class="icon icon-24" --></button>
<button class="icon-btn icon-btn-marca" aria-label="Enviar mensagem"><!-- enviar --></button>
```

### Campo (U49, U03, U31)

```html
<div class="field field-lg">                          <!-- aluna: rótulo 16 semibold, ajuda 14 -->
  <label class="field-label" for="email">E-mail da compra</label>
  <input class="field-input" id="email" type="email" placeholder="voce@exemplo.com">
  <p class="field-hint">O mesmo e-mail que você usou para comprar o curso.</p>
</div>

<div class="field">                                   <!-- painel: rótulo 14, 16 px no celular, 14 no computador -->
  <label class="field-label" for="motivo">Motivo <span class="field-label-aside">0 de 200</span></label>
  <input class="field-input is-focus" id="motivo" value="Pediu para sair do curso">
</div>

<div class="field">
  <label class="field-label" for="idade">Idade</label>
  <input class="field-input is-invalido" id="idade" value="17" aria-invalid="true">
  <p class="field-error"><!-- ícone alerta -->Confere a idade: o curso é para maiores de 18 anos.</p>
</div>

<div class="field">
  <label class="field-label" for="papel">Papel</label>
  <select class="select is-placeholder" id="papel"><option>Escolha…</option></select>
</div>

<textarea class="field-input" rows="3"></textarea>
<input class="field-input field-codigo" value="482913" inputmode="numeric">   <!-- código do login -->
<label class="checkbox-linha"><input type="checkbox" class="checkbox" checked> Li e concordo com a Política de Privacidade.</label>
```

### Aviso (U50): amarelo é aviso, vermelho é erro

```html
<div class="notice notice-info"><!-- ícone info -->
  <div class="notice-corpo"><p class="notice-titulo">Falta pouco!</p><p>Seu acesso é liberado assim que a compra for confirmada.</p></div>
</div>
<div class="notice notice-warning" role="alert"><!-- ícone alerta -->
  <div class="notice-corpo"><p>Não consegui carregar a Equipe agora.</p>
    <div class="notice-acoes"><button class="btn btn-secondary">Tentar de novo</button></div></div>
</div>
<div class="notice notice-danger" role="alert"><!-- ícone alerta --><div class="notice-corpo"><p>Código incorreto. Confere os 6 números e tenta de novo.</p></div></div>
<div class="notice notice-success" role="status"><!-- ícone check --><div class="notice-corpo"><p>Perfil salvo.</p></div></div>
```

Detalhe técnico recolhido (U41): `<details><summary>Detalhe técnico</summary><p class="mono">…</p></details>`
dentro do `.notice-corpo`. Faixa no topo, uma por vez (U22): `<div class="faixa faixa-aviso">…</div>`
ou `faixa-info`.

### Diálogo e folha (U51)

No celular os dois saem de baixo; no computador o diálogo fica centrado e a folha vira painel lateral.

```html
<div class="veu">
  <div class="dialog" role="alertdialog" aria-labelledby="t1">
    <h2 class="dialog-titulo" id="t1">Recomeçar a conversa do zero?</h2>
    <div class="dialog-corpo"><p>Eu esqueço o que a gente conversou até aqui e começo de novo. As mensagens continuam na tela. Dá para recomeçar até 3 vezes por dia.</p></div>
    <div class="dialog-rodape">                                   <!-- no celular: empilhado, o primeiro do HTML fica embaixo -->
      <button class="btn btn-secondary btn-lg btn-full is-focus">Cancelar</button>
      <button class="btn btn-primary btn-lg btn-full">Recomeçar</button>
    </div>
  </div>
</div>
```

Com cabeçalho e "Fechar": `<div class="dialog-cabecalho"><h2 class="dialog-titulo">…</h2><button class="dialog-fechar">Fechar</button></div>`.
No painel use `btn` sem `btn-lg`/`btn-full`. Outros textos prontos do PRD: sair (U20) "Sair do app?" ·
"Para entrar de novo, você vai precisar de um código novo no seu e-mail." · "Ficar" · "Sair".

```html
<div class="veu">
  <div class="sheet" role="dialog" aria-labelledby="t2">          <!-- .sheet-md = 448 px no computador -->
    <span class="sheet-alca"></span>
    <div class="sheet-cabecalho"><h2 class="sheet-titulo" id="t2">Notificações</h2><button class="sheet-fechar">Fechar</button></div>
    <div class="sheet-corpo com-folga">…</div>                    <!-- sem com-folga: lista de itens de menu -->
  </div>
</div>
```

### Interruptor (U52)

```html
<div class="switch">
  <div class="switch-texto"><p class="switch-rotulo">Avisos de aulas e ofertas</p><p class="switch-apoio">Neste aparelho.</p></div>
  <button class="switch-controle" role="switch" aria-checked="true"><span class="switch-trilho"></span><span class="switch-estado">Ligado</span></button>
</div>
```

`aria-checked="false"` + "Desligado" para o desligado. Sem texto de estado (`mostrarEstado=false`): tire o `.switch-estado`.

### Toast com Desfazer (U27)

```html
<div class="toast-area">                      <!-- 80 px do fundo no celular (acima da barra), 24 px no computador -->
  <div class="toast" role="status">
    <span class="toast-texto">Desligado. As sessões foram encerradas.</span>
    <button class="toast-acao">Desfazer</button>
    <button class="toast-fechar" aria-label="Fechar aviso"><!-- ícone fechar --></button>
  </div>
</div>
```

Sem ação: `<div class="toast so-texto">Salvo.</div>`.

### Abas roláveis (U30)

```html
<div class="tabs tem-mais-dir" role="tablist" aria-label="Ficha">
  <button class="tab is-ativa" role="tab" aria-selected="true">Resumo</button>
  <button class="tab" role="tab">Conversa</button> <button class="tab" role="tab">Mensagens</button>
  <button class="tab" role="tab">Aparelhos</button> <button class="tab" role="tab">Suporte</button>
</div>
```

`tem-mais-dir` / `tem-mais-esq` (ou as duas) pintam o degradê na ponta que tem mais. Abaixo de 640 px,
"Aparelhos e sessões" vira "Aparelhos".

### Pílula, contador, chip

```html
<span class="badge badge-good">Ativo</span>          <!-- rosa claro -->
<span class="badge badge-warn">Aguardando aluno</span>
<span class="badge badge-bad">Desligado</span>
<span class="badge badge-muted">Encerrado</span>
<span class="badge badge-neutral">Suporte</span>
<span class="badge badge-outline">Acesso</span>       <!-- categoria (U52) -->
<span class="badge badge-good badge-xs">Admin</span>
<span class="contador">2</span>                       <!-- pendentes do suporte (amarelo) -->
<span class="contador contador-marca">12</span>       <!-- não lidas -->
<div class="chips rolavel"><button class="chip is-ativo">Todos</button><button class="chip">Ativos</button></div>
```

### Cartão, número, lista, vazio, esqueleto

```html
<div class="card"><p class="card-titulo">Precisa de atenção</p>
  <div class="lista"><a class="lista-item" href="#">As notificações no celular não estão configuradas.<!-- chevron-direita --></a></div>
</div>
<div class="card card-alt card-lg">…</div>          <!-- cartão da aluna (suporte): surface-2, raio 20 -->

<a class="stat" href="#"><p class="stat-rotulo">Alunos ativos</p><p class="stat-valor">14</p><p class="stat-sub is-subiu">+3 nesta semana</p></a>
<a class="stat" href="#"><p class="stat-rotulo">Mensagens</p><p class="stat-valor">2<span class="stat-unidade">agendadas hoje</span></p><p class="stat-sub">1 enviada ontem</p></a>
<!-- .stat-grande = valor 24 px; .is-caiu = vermelho; grade: <div class="grade-stats"> (2 colunas no celular, 3 no computador) -->

<div class="empty"><!-- ícone 24 --><p class="empty-texto">Nenhum envio ainda.</p><button class="btn btn-secondary">Nova mensagem</button></div>

<div role="status" aria-busy="true" class="pilha-sm"><span class="sr-only">Carregando…</span>
  <span class="skeleton" style="height:96px"></span><span class="skeleton" style="height:96px"></span></div>
```

Três estados de espera (U26): abrir o app = `.crystal-mark.is-pulsando` + "Um instante…"; carregar
conteúdo = `.skeleton` com a forma do conteúdo; ação = `.spinner` dentro do botão e rótulo no gerúndio.

### Título e marca (U54)

```html
<div class="page-header"><div><h1 class="page-titulo">Alunos</h1><p class="page-apoio">Quem comprou e como está usando o app.</p></div><button class="btn btn-primary">Nova conta local</button></div>
<h2 class="secao-titulo">Conversas</h2>

<span class="crystal-mark"><svg viewBox="0 0 48 48" aria-hidden="true"><path class="cm-faceta" d="M24 9 36 24 24 39 12 24Z"/><path class="cm-faceta cm-topo" d="M24 9 36 24H12Z"/><path class="cm-linha" d="M24 9v30M12 24h24"/></svg></span>

<span class="crystal-lockup"><!-- crystal-mark --><span class="crystal-lockup-nome">Crystal</span></span>          <!-- início: 32 + 24 -->
<span class="crystal-lockup crystal-lockup-md"><!-- crystal-mark --><span><span class="crystal-lockup-nome">Crystal</span><span class="crystal-lockup-apoio">Área da equipe</span></span></span>
<div class="crystal-lockup crystal-lockup-lg"><!-- crystal-mark --><span class="crystal-lockup-nome">Crystal</span></div> <!-- login: 64 + 24, empilhado -->
```

O `.crystal-mark` segue o tema sozinho (degradê `--brand-strong → --brand`). Para `<img>`, há
`assets/crystal-simbolo-claro.svg` e `-escuro.svg`.

### Avatar

```html
<img class="avatar avatar-40" src="../assets/crystal-foto.jpg" alt="">
<span class="avatar-wrap"><img class="avatar avatar-48" src="../assets/crystal-foto.jpg" alt=""><span class="ponto-online"></span></span>
<span class="avatar avatar-96 avatar-iniciais">A</span>
<button class="avatar-wrap" aria-label="Trocar sua foto"><span class="avatar avatar-96 avatar-iniciais">A</span><span class="avatar-selo"><!-- camera --></span></button>  <!-- U58: só com perfil completo -->
```

---

## 4. Moldura da aluna

### Início (U54, U58, U04)

```html
<div class="tela"><div class="app">
  <header class="app-header">
    <span class="crystal-lockup"><!-- crystal-mark --><span class="crystal-lockup-nome">Crystal</span></span>
    <div class="menu-ancora"><button class="icon-btn" aria-label="Abrir menu" aria-haspopup="menu"><!-- menu-tres-pontos --></button><!-- .menu aqui quando aberto --></div>
  </header>
  <main class="app-main">
    <section class="pilha-sm" style="align-items:center;text-align:center"><!-- avatar 96 com selo --><p class="forte texto-base">Ana</p><p class="texto-apoio">Perfil completo</p></section>
    <nav class="caminhos"><a class="caminho" href="#">Perfil</a><a class="caminho" href="#">Conversa</a><a class="caminho" href="#">Suporte</a></nav>
    <section class="pilha-sm"><h2 class="secao-titulo">Conversas</h2>
      <a class="contato" href="#"><span class="avatar-wrap"><img class="avatar avatar-48" src="../assets/crystal-foto.jpg" alt=""><span class="ponto-online"></span></span>
        <span class="contato-texto"><span class="contato-nome">Crystal</span><span class="contato-previa">Me conta: em que posso te ajudar hoje?</span></span><span class="contato-hora">14:46</span></a>
    </section>
  </main>
</div></div>
```

Conversa travada: `<a class="caminho is-travado"><!-- cadeado 16 -->Conversa</a>` e
`<button class="contato is-travada">…<!-- cadeado --></button>` (foto esmaecida, texto em AA).

Tela interna (Perfil, Suporte): `<header class="app-header com-voltar"><button class="icon-btn is-tinta" aria-label="Voltar"><!-- voltar 24 --></button></header>`
e, no corpo, o `.page-header` com o h1 em Blinker (U54).

### Menu de três pontinhos: ordem final (U04, U58, U20)

```html
<div class="menu" role="menu" aria-label="Menu do chat">
  <p class="menu-titulo">Tema</p>
  <button class="menu-item" role="menuitemradio" aria-checked="false">Claro</button>
  <button class="menu-item" role="menuitemradio" aria-checked="false">Escuro</button>
  <button class="menu-item" role="menuitemradio" aria-checked="true">Sistema<!-- check, class="icon menu-check" --></button>
  <p class="menu-apoio">Sistema segue o claro ou o escuro do celular.</p>
  <hr class="menu-sep">
  <p class="menu-titulo">Tamanho da letra</p>
  <button class="menu-item" role="menuitemradio" aria-checked="true">Normal<!-- check --></button>
  <button class="menu-item" role="menuitemradio" aria-checked="false">Grande</button>
  <button class="menu-item" role="menuitemradio" aria-checked="false">Muito grande</button>
  <p class="menu-apoio">Vale para todo o app neste aparelho.</p>
  <hr class="menu-sep">
  <button class="menu-item" role="menuitem">Notificações</button>
  <a class="menu-item" role="menuitem" href="#">Suporte</a>
  <button class="menu-item" role="menuitem">Recomeçar a conversa</button>   <!-- só no menu da conversa -->
  <a class="menu-item" role="menuitem" href="#">Política de privacidade</a>
  <a class="menu-item" role="menuitem" href="#">Área da equipe</a>          <!-- só para quem é da equipe -->
  <hr class="menu-sep">
  <button class="menu-item" role="menuitem">Sair</button>                   <!-- abre "Sair do app?" (U20) -->
</div>
```

O menu fica sem ícones, como hoje e como no WhatsApp; o ✓ da opção ativa passa a ser o ícone `check`.
Na tela de início não há "Recomeçar a conversa". Com o menu inteiro aberto ele tem cerca de 650 px: no
mock da conversa ele cobre as bolhas, como no aparelho.

### Login (U01, U09, U10)

```html
<div class="tela"><main class="auth">
  <div class="crystal-lockup crystal-lockup-lg"><!-- crystal-mark --><span class="crystal-lockup-nome">Crystal</span></div>
  <div class="auth-cartao">
    <p class="texto-apoio">…</p>
    <div class="field field-lg">…</div>
    <button class="btn btn-cta btn-lg btn-full">Receber o código</button>
  </div>
  <p class="auth-rodape"><!-- cadeado 16 -->Conversa protegida · <a href="#">Privacidade</a> · <a href="#">Termos de Uso</a></p>
</main></div>
```

### Conversa (a cara de WhatsApp fica)

```html
<div class="tela"><div class="chat">
  <header class="chat-header">
    <button class="icon-btn is-tinta" aria-label="Voltar ao início"><!-- voltar 24 --></button>
    <button class="chat-header-foto" aria-label="Ver perfil da Crystal"><img class="avatar avatar-40" src="../assets/crystal-foto.jpg" alt=""><span class="ponto-online"></span></button>
    <div class="chat-header-texto"><h1 class="chat-header-nome">Crystal</h1><p class="chat-header-status">online</p></div>
    <div class="menu-ancora"><button class="icon-btn" aria-label="Abrir menu"><!-- menu-tres-pontos --></button></div>
  </header>
  <div class="chat-lista no-fim">                       <!-- no-fim: as bolhas encostam na barra de escrever -->
    <span class="chat-divisor chat-pill">Hoje</span>
    <div class="bolha-aluna bolha-primeira"><p class="bolha-texto">Oi Crystal, conheci alguém na academia e não sei como puxar assunto</p>
      <div class="bolha-meta"><time>14:46</time><!-- tiques lida --></div></div>
    <div class="bolha-crystal bolha-primeira"><p class="bolha-texto">Oi! Que bom te ver por aqui.</p><div class="bolha-meta"><time>14:46</time></div></div>
    <div class="bolha-crystal"><p class="bolha-texto">Me conta: em que posso te ajudar hoje?</p><div class="bolha-meta"><time>14:46</time></div></div>
    <div class="digitando bolha-primeira" role="status" aria-label="Crystal está digitando"><span></span><span></span><span></span></div>
  </div>
  <div class="compositor"><div class="compositor-linha">
    <textarea class="compositor-campo" rows="1" placeholder="Mensagem" aria-label="Escreva sua mensagem"></textarea>
    <button class="icon-btn" aria-label="Enviar imagem ou print"><!-- clipe --></button>
    <button class="icon-btn icon-btn-marca" aria-label="Gravar áudio"><!-- microfone; com texto: enviar --></button>
  </div></div>
</div></div>
```

- `bolha-primeira` = primeira de uma sequência do mesmo lado (rabinho + 8 px acima); as seguintes sem.
- Tiques (exceção do U53, 12 px, traço 1,5):

```html
<svg class="tiques is-lida" viewBox="0 0 18 12" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" role="img" aria-label="Lida"><path d="M1 6.5 4 9.5 9.5 3"/><path d="M7.5 6.5 10.5 9.5 16 3"/></svg>
```

  Sem `is-lida` = brancos (entregue); só o primeiro `path` = enviada.
- Áudio com transcrição (U01, U17):

```html
<div class="bolha-aluna bolha-primeira">
  <div class="audio"><button class="audio-play" aria-label="Tocar áudio"><!-- play --></button>
    <div class="audio-centro"><div class="audio-onda"><span class="tocada" style="height:60%"></span><span style="height:35%"></span><!-- ~36 barras --></div><span class="audio-tempo">0:07</span></div>
    <button class="audio-velocidade">1x</button></div>
  <p class="bolha-transcricao">E se ela estiver com fone de ouvido?</p>
  <div class="bolha-meta"><time>14:47</time><!-- tiques --></div>
</div>
```

- Erro com causa e "Tentar de novo" (U05, U06): `<p class="bolha-aviso">…</p><button class="bolha-tentar"><!-- recomecar -->Tentar de novo</button>` dentro da `.bolha-crystal`.
- Telefones de ajuda e `cvv.org.br` tocáveis (U08): `<a href="tel:188">188</a>` dentro da `.bolha-crystal` (rosa sublinhado).
- Botão dentro da bolha (convite, aula): `<a class="bolha-acao" href="#"><!-- link 16 -->Ver a aula</a>` no fim da `.bolha-crystal`.
- Foco no campo de escrever: `.compositor-campo.is-focus` (borda rosa, como no app); teclado: `.is-focus-teclado`.

---

## 5. Moldura do painel

```html
<div class="tela"><div class="staff">
  <aside class="staff-sidebar">                                 <!-- só a partir de 768 px -->
    <div class="staff-sidebar-topo"><span class="crystal-lockup crystal-lockup-md"><!-- crystal-mark --><span><span class="crystal-lockup-nome">Crystal</span><span class="crystal-lockup-apoio">Área da equipe</span></span></span></div>
    <nav class="staff-nav" aria-label="Menu principal">
      <div class="staff-grupo"><p class="staff-grupo-titulo">Operar</p>
        <a class="staff-link is-ativo" href="#"><!-- inicio --><span class="rotulo">Início</span></a>
        <a class="staff-link" href="#"><!-- suporte --><span class="rotulo">Suporte</span><span class="contador">2</span></a> …</div>
      …
    </nav>
  </aside>
  <div class="staff-corpo">
    <header class="staff-header">                               <!-- U25: uma linha -->
      <!-- crystal-mark (some sozinho no computador) -->
      <div class="staff-header-quem"><p class="staff-header-nome">Rui Ferreira</p><p class="staff-header-papel">Admin</p></div>
      <button class="staff-conta-btn" aria-label="Sua conta" aria-haspopup="dialog">R</button>
    </header>
    <div class="staff-barra">                                   <!-- só no celular, fixa no topo ao rolar -->
      <a class="staff-barra-voltar" href="#"><!-- voltar -->Alunos</a><p class="staff-barra-titulo">Ana Souza</p><span></span>
    </div>                                                      <!-- sem voltar: <span></span> no lugar do link -->
    <main class="staff-main pilha"> <div class="page-header">…</div> … </main>
    <nav class="staff-bottombar" aria-label="Menu principal">  <!-- só no celular -->
      <a class="staff-tab is-ativo" href="#"><span class="staff-tab-icone"><!-- inicio --></span>Início</a>
      …
      <button class="staff-tab" aria-haspopup="dialog"><span class="staff-tab-icone"><!-- mais --><span class="contador">2</span></span>Mais</button>
    </nav>
  </div>
</div></div>
```

No computador, o "← Alunos" do topo da ficha é `<a class="voltar-para so-desktop">` acima do cabeçalho.

### Grupos da barra lateral e da folha Mais (U45)

| Grupo | Itens (ícone) |
|---|---|
| Operar | Início (`inicio`), Alunos (`usuarios`), Mensagens (`mensagens`), Suporte (`suporte`), Banners (`banners`), Financeiro (`financeiro`) |
| Crystal | Crystal (`crystal`), Laboratório (`laboratorio`) |
| Entender | Métricas (`grafico`), Auditoria (`auditoria`) |
| Ajustar | Configurações (`configuracoes`), Integrações (`integracoes`), Equipe (`equipe`) |

Cada papel vê só o que pode: Laboratório, Banners e Financeiro só admin; Crystal admin e técnico.

### Barra inferior por papel (U45, decisão A) e folha "Mais"

| Papel | Barra (4 + Mais) | Folha "Mais" (mesmos grupos, sem o que já está na barra) |
|---|---|---|
| Admin (Rui Ferreira, Carla Mendes) | Início, Alunos, Mensagens, Crystal, Mais | Operar: Suporte, Banners, Financeiro · Crystal: Laboratório · Entender: Métricas, Auditoria · Ajustar: Configurações, Integrações, Equipe |
| Suporte (Bia) | Início, Alunos, Mensagens, Suporte, Mais | Ajustar: Equipe |
| Técnico | Início, Alunos, Mensagens, Suporte, Mais | Crystal: Crystal · Entender: Métricas, Auditoria · Ajustar: Configurações, Integrações, Equipe |

Para o admin, o contador amarelo do Suporte aparece sobre o "Mais" e ao lado de "Suporte" na folha.
Padrão se o dono não responder: a barra fica Início, Alunos, Mensagens, Suporte para todos e só a folha
é reagrupada (o desenho é o mesmo). A folha:

```html
<div class="veu"><div class="sheet staff-sheet-mais" role="dialog" aria-labelledby="mt">
  <span class="sheet-alca"></span>
  <div class="sheet-cabecalho"><h2 class="sheet-titulo" id="mt">Mais</h2><button class="sheet-fechar">Fechar</button></div>
  <div class="sheet-corpo"><nav class="staff-nav">
    <div class="staff-grupo"><p class="staff-grupo-titulo">Operar</p><a class="staff-link" href="#"><!-- suporte --><span class="rotulo">Suporte</span><span class="contador">2</span></a>…</div>
    …
  </nav></div>
</div></div>
```

### Folha "Sua conta" (U25)

```html
<div class="veu"><div class="sheet" role="dialog" aria-labelledby="ct">
  <span class="sheet-alca"></span>
  <div class="sheet-cabecalho"><h2 class="sheet-titulo" id="ct">Sua conta</h2><button class="sheet-fechar">Fechar</button></div>
  <div class="sheet-corpo">
    <div class="staff-conta-quem"><span class="staff-conta-btn">R</span><div><p class="staff-header-nome">Rui Ferreira</p><p class="staff-header-papel">Admin</p></div></div>
    <p class="menu-titulo">Tema</p>
    <button class="menu-item" role="menuitemradio" aria-checked="false">Claro</button>
    <button class="menu-item" role="menuitemradio" aria-checked="false">Escuro</button>
    <button class="menu-item" role="menuitemradio" aria-checked="true">Sistema<!-- check menu-check --></button>
    <p class="menu-apoio">Sistema segue o claro ou o escuro do celular.</p>
    <hr class="menu-sep">
    <a class="menu-item" href="#">Minha senha</a>
    <a class="menu-item" href="#">Abrir o app</a>
    <hr class="menu-sep">
    <button class="menu-item">Sair</button>
  </div>
</div></div>
```

No computador a mesma folha abre na lateral direita (384 px).

---

## 6. Imagens em `assets/`

| Arquivo | Origem | Uso |
|---|---|---|
| `crystal-foto.jpg` | `apps/web/public/crystal/foto.jpg` (512 × 512) | foto padrão da Crystal: cabeçalho da conversa, linha do início, perfil da Crystal |
| `papel-de-parede-claro.png`, `papel-de-parede-escuro.png` | `public/papel-de-parede/` (540 × 981) | já aplicados pelo `.chat-lista` (desenho em 412 px) |
| `icone-app-192.png`, `icone-app-512.png`, `icone-app-apple-180.png` | `public/icons/` | ícone do app (tela inicial do celular, faixa de instalar, splash) |
| `crystal-simbolo-claro.svg`, `crystal-simbolo-escuro.svg` | redesenhados do `components/CrystalMark.tsx` (no app ele é SVG em código, não arquivo) | símbolo como `<img>`; nas telas prefira o `.crystal-mark` inline, que segue o tema |

Não há logotipo em arquivo no app: a marca é o `CrystalMark` + "Crystal" em Blinker.
