# Ícones do kit (U53)

Grade 24 px, traço 1,75, cantos redondos, `currentColor`, estilo Lucide. Os do menu da equipe são os
15 que o app já tem (`components/equipe/icons.tsx`, mesmo traço); os demais são paths do Lucide (ISC)
copiados para cá, como o PRD manda (sem dependência, sem CDN). Emoji nunca é ícone.

Como usar numa tela de mock:

- Cole o trecho. A classe `icon` dá 20 px; `icon icon-16` e `icon icon-24` trocam o tamanho.
- A cor vem do texto em volta (`currentColor`): dentro de `.btn-primary` fica branco, dentro de
  `.notice-danger` fica na tinta do erro, numa `.staff-link` segue o item.
- Decorativo (com rótulo ao lado): deixe `aria-hidden="true"`. Botão só de ícone: o nome vai no botão
  (`<button class="icon-btn" aria-label="Fechar">…</button>`), nunca no SVG.
- Exceções do PRD: os tiques da bolha (12 px, traço 1,5, trecho no `KIT.md`) e o `CrystalMark` (marca,
  não ícone). No tocador de áudio, o `play` vai preenchido (`.audio-play svg { fill: currentColor }`).
- Nomes do PRD que mudam aqui: `tres-pontos` = `menu-tres-pontos`; `seta-voltar`/`chevron-esquerda` =
  `voltar`; `seta-circular` = `recomecar`; `cadeado-fechado` = `cadeado`; `tique` = `check`;
  `tique-duplo` = `check-duplo`; `aviso` = `alerta`.

## Lista pedida

| Nome | Para que | Origem |
|---|---|---|
| `menu-tres-pontos` | Três pontinhos do menu (AppMenu, cabeçalho do início e da conversa) | Lucide ellipsis-vertical (PRD: tres-pontos) |
| `voltar` | Seta de voltar (SetaVoltar, barra de título do painel) | Lucide chevron-left (PRD: seta-voltar / chevron-esquerda) |
| `fechar` | Fechar folha, prévia da imagem, toast | Lucide x |
| `enviar` | Enviar mensagem (substitui o avião copiado 3 vezes) | Lucide send-horizontal |
| `microfone` | Gravar áudio | Lucide mic |
| `clipe` | Anexar imagem ou print | Lucide paperclip |
| `camera` | Selo da foto do início (U58), trocar foto | Lucide camera |
| `telefone` | Telefones de ajuda tocáveis (U08), cartão WhatsApp do suporte | Lucide phone |
| `suporte` | Suporte (menu da equipe e cartões do suporte) | app: StaffIcon suporte |
| `recomecar` | Recomeçar a conversa (U04), Tentar de novo (PRD: seta-circular) | Lucide rotate-ccw |
| `texto-tamanho` | Tamanho da letra (U58) | Lucide a-large-small |
| `sino` | Notificações (folha e aviso) | Lucide bell |
| `sair` | Sair da conta | Lucide log-out |
| `lixeira` | Apagar gravação, Excluir conta (U20) | Lucide trash-2 |
| `usuario` | Pessoa (avatar sem nome, Minha conta) | Lucide user |
| `usuarios` | Alunos (menu da equipe) | app: StaffIcon alunos |
| `busca` | Buscar (Alunos, Auditoria) | Lucide search |
| `filtro` | Filtros (n) (U47) | Lucide funnel |
| `cadeado` | Conversa travada, conversa protegida (PRD: cadeado-fechado) | Lucide lock |
| `check` | Opção ativa do menu (substitui o caractere de visto), sucesso (PRD: tique) | Lucide check |
| `check-duplo` | Entregue/lida fora da bolha (na bolha ficam os tiques de 12 px, traço 1,5) (PRD: tique-duplo) | Lucide check-check |
| `alerta` | Aviso e erro (Notice warning/danger, erro de campo) (PRD: aviso) | Lucide triangle-alert |
| `info` | Notice info, detalhe técnico | Lucide info |
| `relogio` | Validade do código (U10, U33), agendado | Lucide clock |
| `grafico` | Métricas (menu da equipe) | app: StaffIcon metricas |
| `configuracoes` | Configurações (menu da equipe) | app: StaffIcon configuracoes |
| `laboratorio` | Laboratório (menu da equipe) | app: StaffIcon laboratorio |
| `crystal` | Crystal (menu da equipe; a marca é o CrystalMark) | app: StaffIcon crystal |
| `mensagens` | Mensagens (menu da equipe) | app: StaffIcon mensagens |
| `inicio` | Início (menu da equipe) | app: StaffIcon inicio |
| `mais` | Mais (barra inferior do painel) | Lucide ellipsis (no lugar do traço 3 de hoje) |
| `copiar` | Copiar (e-mail do suporte, código) | Lucide copy |
| `link` | Link de aula, copiar link | Lucide link |
| `olho` | Mostrar senha, prévia | Lucide eye |
| `desfazer` | Desfazer (toast, U27) | Lucide undo-2 |

## Extras do painel e do tocador

| Nome | Para que | Origem |
|---|---|---|
| `banners` | Banners (menu da equipe) | app: StaffIcon banners |
| `auditoria` | Auditoria (menu da equipe) | app: StaffIcon auditoria |
| `integracoes` | Integrações (menu da equipe) | app: StaffIcon integracoes |
| `financeiro` | Financeiro (menu da equipe) | app: StaffIcon financeiro |
| `equipe` | Equipe (menu da equipe) | app: StaffIcon equipe |
| `play` | Tocar áudio (no tocador, preenchido: .audio-play svg { fill: currentColor }) | Lucide play |
| `pause` | Pausar áudio | Lucide pause |
| `seta-cima` | Deslize para cima para travar a gravação | Lucide arrow-up |
| `chevron-direita` | Linha de lista que leva a outra tela | Lucide chevron-right |
| `chevron-baixo` | Abrir grupo, ir para a última mensagem | Lucide chevron-down |

## Trechos prontos para colar

### menu-tres-pontos

```html
<svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="12" cy="5" r="1"/><circle cx="12" cy="12" r="1"/><circle cx="12" cy="19" r="1"/></svg>
```

### voltar

```html
<svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="m15 18-6-6 6-6"/></svg>
```

### fechar

```html
<svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M18 6 6 18"/><path d="m6 6 12 12"/></svg>
```

### enviar

```html
<svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M3.71 3.05a.5.5 0 0 0-.68.63l2.84 7.62a2 2 0 0 1 0 1.4l-2.84 7.62a.5.5 0 0 0 .68.63l18-8.5a.5.5 0 0 0 0-.9z"/><path d="M6 12h16"/></svg>
```

### microfone

```html
<svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="9" y="2" width="6" height="13" rx="3"/><path d="M19 10v2a7 7 0 0 1-14 0v-2"/><path d="M12 19v3"/></svg>
```

### clipe

```html
<svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="m21.44 11.05-9.19 9.19a6 6 0 0 1-8.49-8.49l8.57-8.57A4 4 0 1 1 18 8.84l-8.59 8.57a2 2 0 0 1-2.83-2.83l8.49-8.48"/></svg>
```

### camera

```html
<svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M14.5 4h-5L7 7H4a2 2 0 0 0-2 2v9a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2V9a2 2 0 0 0-2-2h-3z"/><circle cx="12" cy="13" r="3"/></svg>
```

### telefone

```html
<svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.8 19.8 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.8 19.8 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72c.13.96.36 1.9.7 2.81a2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45c.91.34 1.85.57 2.81.7A2 2 0 0 1 22 16.92z"/></svg>
```

### suporte

```html
<svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18Zm0-5a4 4 0 1 0 0-8 4 4 0 0 0 0 8ZM5.6 5.6l3.6 3.6m5.6 5.6 3.6 3.6m0-12.8-3.6 3.6m-5.6 5.6-3.6 3.6"/></svg>
```

### recomecar

```html
<svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8"/><path d="M3 3v5h5"/></svg>
```

### texto-tamanho

```html
<svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M21 14h-5"/><path d="M16 16v-3.5a2.5 2.5 0 0 1 5 0V16"/><path d="M4.5 13h6"/><path d="m3 16 4.5-9 4.5 9"/></svg>
```

### sino

```html
<svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9"/><path d="M10.3 21a1.94 1.94 0 0 0 3.4 0"/></svg>
```

### sair

```html
<svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/><path d="m16 17 5-5-5-5"/><path d="M21 12H9"/></svg>
```

### lixeira

```html
<svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M3 6h18"/><path d="M19 6v14c0 1-1 2-2 2H7c-1 0-2-1-2-2V6"/><path d="M8 6V4c0-1 1-2 2-2h4c1 0 2 1 2 2v2"/><path d="M10 11v6"/><path d="M14 11v6"/></svg>
```

### usuario

```html
<svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>
```

### usuarios

```html
<svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M8 11a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7Zm-5.5 9a5.5 5.5 0 0 1 11 0M16 4.3a3.5 3.5 0 0 1 0 6.4M17.5 14.5a5.5 5.5 0 0 1 4 5.5"/></svg>
```

### busca

```html
<svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="11" cy="11" r="8"/><path d="m21 21-4.3-4.3"/></svg>
```

### filtro

```html
<svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M22 3H2l8 9.46V19l4 2v-8.54z"/></svg>
```

### cadeado

```html
<svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>
```

### check

```html
<svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M20 6 9 17l-5-5"/></svg>
```

### check-duplo

```html
<svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M18 6 7 17l-5-5"/><path d="m22 10-7.5 7.5L13 16"/></svg>
```

### alerta

```html
<svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3"/><path d="M12 9v4"/><path d="M12 17h.01"/></svg>
```

### info

```html
<svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="12" cy="12" r="10"/><path d="M12 16v-4"/><path d="M12 8h.01"/></svg>
```

### relogio

```html
<svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="12" cy="12" r="10"/><path d="M12 6v6l4 2"/></svg>
```

### grafico

```html
<svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M4 20V10m6 10V4m6 16v-7m4 7H3"/></svg>
```

### configuracoes

```html
<svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M4 7h10m4 0h2M4 17h4m4 0h8M14 5v4m-4 6v4"/></svg>
```

### laboratorio

```html
<svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M9 3h6M10 3v6l-5 9a2 2 0 0 0 1.8 3h10.4a2 2 0 0 0 1.8-3l-5-9V3M7.5 15h9"/></svg>
```

### crystal

```html
<svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 3 6 9l6 12 6-12-6-6ZM6 9h12M9.5 9 12 21m2.5-12L12 21"/></svg>
```

### mensagens

```html
<svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M4 5h16v11H8l-4 4V5Zm4 4.5h8M8 12.5h5"/></svg>
```

### inicio

```html
<svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M3 11.5 12 4l9 7.5M5.5 9.5V20h5v-5h3v5h5V9.5"/></svg>
```

### mais

```html
<svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="5" cy="12" r="1"/><circle cx="12" cy="12" r="1"/><circle cx="19" cy="12" r="1"/></svg>
```

### copiar

```html
<svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="8" y="8" width="14" height="14" rx="2"/><path d="M4 16c-1.1 0-2-.9-2-2V4c0-1.1.9-2 2-2h10c1.1 0 2 .9 2 2"/></svg>
```

### link

```html
<svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71"/><path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71"/></svg>
```

### olho

```html
<svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M2.06 12.35a1 1 0 0 1 0-.7 10.75 10.75 0 0 1 19.88 0 1 1 0 0 1 0 .7 10.75 10.75 0 0 1-19.88 0"/><circle cx="12" cy="12" r="3"/></svg>
```

### desfazer

```html
<svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M9 14 4 9l5-5"/><path d="M4 9h10.5a5.5 5.5 0 0 1 5.5 5.5 5.5 5.5 0 0 1-5.5 5.5H11"/></svg>
```

### banners

```html
<svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M3 6h18v12H3V6Zm0 9 5-4 4 3 3-2 6 4M8.5 10a1 1 0 1 0 0-2 1 1 0 0 0 0 2Z"/></svg>
```

### auditoria

```html
<svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 3 4.5 6v5.5c0 4.5 3.2 8.2 7.5 9.5 4.3-1.3 7.5-5 7.5-9.5V6L12 3Zm-3 9 2 2 4-4"/></svg>
```

### integracoes

```html
<svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M9 7V3m6 4V3M7 7h10v4a5 5 0 0 1-10 0V7Zm5 9v5"/></svg>
```

### financeiro

```html
<svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M3 7h18v12H3V7Zm0 4h18M16 15h2M6 7V5h12v2"/></svg>
```

### equipe

```html
<svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M4 5h16v14H4V5Zm4 9.5a2.5 2.5 0 0 1 5 0M10.5 11a1.5 1.5 0 1 0 0-3 1.5 1.5 0 0 0 0 3ZM15 9h2m-2 3h2"/></svg>
```

### play

```html
<svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M6 3.5v17a.5.5 0 0 0 .76.43l14-8.5a.5.5 0 0 0 0-.86l-14-8.5A.5.5 0 0 0 6 3.5z"/></svg>
```

### pause

```html
<svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="6" y="4" width="4" height="16" rx="1"/><rect x="14" y="4" width="4" height="16" rx="1"/></svg>
```

### seta-cima

```html
<svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="m5 12 7-7 7 7"/><path d="M12 19V5"/></svg>
```

### chevron-direita

```html
<svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="m9 18 6-6-6-6"/></svg>
```

### chevron-baixo

```html
<svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="m6 9 6 6 6-6"/></svg>
```
