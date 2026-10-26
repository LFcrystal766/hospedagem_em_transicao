# Telas finais da Crystal depois do PRD de UX/UI (26/10/2026)

108 telas do app da aluna e do painel da equipe como vão ficar depois das três ondas do PRD
(`../PRD-ux-ui-2026-10-25.md`), com os textos palavra por palavra, as cores e os componentes que ele fixa.
Dados fictícios. Nada disso está publicado no app.

| Caminho | O que é |
|---|---|
| `index.html` | Galeria (abra no navegador; filtros por área e onda, toque amplia). Mesma do artefato "Crystal depois do PRD" |
| `telas/` | As 108 imagens (celular 390×844 em escala 2, computador 1280×800) |
| `telas.json` | Título, viewport, itens do PRD, onda e descrição de cada tela |
| `fonte/telas/` | O HTML de cada tela |
| `fonte/ds.css`, `fonte/KIT.md`, `fonte/icones.md` | O kit visual do PRD (tokens, componentes, ícones) usado nas telas; desvios do PRD para fechar o contraste AA estão no topo do `ds.css` |
| `fonte/render.js` | Gera as imagens de novo: `NODE_PATH=<pasta global do node>/node_modules node render.js` dentro de `fonte/` (precisa do Playwright) |

Ajustes do kit em relação ao PRD (para passar no contraste AA): verde do aviso de sucesso `#097200` (o `#0a7500`
dá 4,49:1), toque no botão rosa `#c20857`, "Desfazer" do toast no rosa de texto do tema oposto, trilho do
interruptor desligado com 3:1, contador do suporte amarelo com texto escuro, anel de foco rosa por padrão e branco
só sobre cor. Vale levar ao PRD (U01, U27, U52) quando a onda for executada.
