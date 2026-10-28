# Onda 2 de UX: o que conferir no iPhone logo depois de subir

Para o Luiz, no iPhone dele, logo depois de `app-subir` da onda 2 de UX (itens U24 a U47 e U59 do
`docs/ux/PRD-ux-ui-2026-10-25.md`, mais as pendências da onda 1). A onda 2 é o painel da equipe: quase tudo
aqui é em `/equipe`. Cada linha diz onde ir, o que fazer e o que tem de aparecer. Se uma linha der errado, a
volta é na hora: `bash bootstrap-vps.sh app-subir <tag anterior>` (a tag anterior fica anotada antes de subir).
Esta onda não tem migração de banco: a volta da imagem não precisa de volta de banco.

## Antes de começar

- A cobrança do GitHub tem de estar em dia: em 28/10 os runs do CI nem começaram ("recent account payments have
  failed or your spending limit needs to be increased"), e sem ela o `imagens-vps` também não gera as imagens.
  Depois de acertar, esperar o CI da branch ficar verde antes de disparar o `imagens-vps`.
- API, web e Crystal sobem na **mesma tag** (o contrato entre eles mudou). Conferir em
  `bash bootstrap-vps.sh app-status` que as três estão na tag nova.
- Conferir nos dois jeitos: no **Safari** e no **app instalado** (ícone na tela de início). E nos dois temas
  do iPhone: **claro** e **escuro** (Ajustes › Tela e Brilho).
- Usar uma **conta de teste** para Desligar, Religar e Registrar atendimento. Nunca uma cliente de verdade.
- **Nunca em produção:** trocar o modelo das respostas "só para ver" sem voltar logo depois (cada mensagem de
  toda cliente passa a usar o modelo novo), nem mandar mensagem para "Todas as clientes ativas".
- Onde a linha diz "(computador)", é para a Bia conferir no computador dela.

## 1. Entrar e sair da área da equipe

- `/login/equipe`, passo do código: o título diz "Confirme com o código do e-mail" (não "Te mandei") e o rodapé
  diz "Área da equipe · Privacidade · Termos de Uso" (não "Conversa protegida").
- No painel, tocar no botão redondo com a inicial do nome (em cima, à direita): abre a folha "Sua conta" com o
  nome e o papel. Tocar em "Sair": a sessão acaba e abre o `/login/equipe`. Depois disso, abrir `/equipe` leva
  ao login.
- Sessão vencida: na tela Equipe, encerrar as sessões da própria conta de teste (ou esperar vencer) e abrir
  `/equipe/alunos` no iPhone. Tem de cair em `/login/equipe` com a faixa "Sua sessão da área da equipe
  expirou. Entre de novo com e-mail e senha.".
- Abrir `/equipe/nao-existe`: aparece "Não encontrei essa tela." dentro do painel (com o menu), e "Voltar
  para o Início" funciona.
- Com uma conta de suporte, abrir `/equipe/auditoria`: aparece o mesmo "Não encontrei essa tela." e a barra de
  cima diz "Área da equipe" (não "Auditoria").

## 2. Moldura do painel (todas as telas)

- O cabeçalho cabe numa linha só, abaixo do relógio e da ilha do iPhone, sem uma segunda linha de botões.
- Na folha "Sua conta", trocar o tema (Claro, Escuro, Sistema): o painel inteiro muda na hora.
- Rolar Crystal, Configurações e Métricas: a barra fina de cima continua mostrando o nome da tela.
- Recarregar `/equipe/alunos` no app instalado: aparece a marca da Crystal pulsando e "Um instante…", nunca a
  tela branca. Sem internet (modo avião), aos 8 s aparece o aviso amarelo com "Tentar de novo".
- Ao abrir uma tela, o que ainda vai chegar aparece como blocos cinza pulsando (com "Reduzir movimento"
  ligado, param de pulsar), nunca "Carregando…" ou "Buscando…" escrito no meio da tela.
- Com teclado externo ou Controle Assistido: o campo ou botão que recebe o foco nunca fica escondido atrás da
  barra de cima.

## 3. Clientes (lista e busca)

- O menu, a barra de baixo e o título dizem "Clientes" (nunca "Alunos").
- Buscar um e-mail que não existe no app: aparece "Não achei "…" entre os clientes do app." com "Buscar na base
  de clientes" e "Liberar acesso manual". "Buscar na base de clientes" troca para a aba Base com o e-mail no
  campo e já mostra o resultado da base de verdade. O e-mail nunca aparece no endereço.
- Buscar só números de um CPF: o vazio diz "esse CPF", nunca o número.
- Um cartão da base de quem já tem conta mostra "Abrir a ficha no app" e abre a ficha certa.
- O número do apoio da aba ("N clientes. Toque em um para ver a ficha.") é o mesmo da lista.
- Marcar um cartão: a barra "1 selecionado" com "Mensagem" e "Limpar" fica numa linha, acima da barra de baixo.
  No iPhone SE (375 px), também numa linha.

## 4. Ficha da cliente

- O primeiro bloco do Resumo é "Entrada no app", com as 3 últimas tentativas e, embaixo, o que fazer (por
  exemplo "Corrigir e-mail" quando o código saiu e a pessoa não entrou).
- Tocar em "Ações": a folha sobe com os grupos Cadastro, Conta, Equipe e Dados da cliente, e cabe na tela.
  "Desligar" e "Excluir conta manual" ficam em vermelho, com a linha de apoio; "Pedidos e dados da cliente" não.
- A barra de abas mostra um degradê na ponta direita (há mais abas); arrastar de lado mostra o resto.
  "Aparelhos" aparece curto. Ações › Pedidos e dados da cliente deixa a aba Dados inteira à vista.
- Recarregar com `?aba=historico` no fim do endereço: abre direto em Histórico.
- A barra de cima mostra o nome da cliente e "← Clientes".
- Na conta de teste: Ações › Desligar. A lista "Motivo" abre com "Escolha…" em cinza (nunca uma linha em
  branco) e, sem motivo, o botão travado diz "Falta: motivo". Desligar; o aviso de baixo tem "Desfazer": um
  toque religa. Tocar no aviso segura ele na tela; ele volta a contar um pouco depois de tirar o dedo. O X
  fecha. A cor do "Desfazer" é legível nos dois temas.
- "Crystal e WhatsApp" tem título e aparece logo depois de Conta; Silenciar WhatsApp avisa com "Desfazer".

## 5. Diálogo do código (reautenticação)

- Ficha da conta de teste › Recomeçar conversa (ou outra ação que pede código): com o teclado numérico aberto
  no campo Código, "Sim, recomeçar" e "Cancelar" continuam visíveis e tocáveis, e a folha não pula para o topo.
- O texto diz quanto tempo o código vale e "Código 1 de 4".
- Pedir o código 5 vezes em 15 minutos: no 5.º, no lugar do botão aparece "Dá para pedir outro em mm:ss",
  contando para baixo, sem travar o diálogo. Quando zera, o botão volta.
- Nas folhas "Nova conta local" e "Liberar acesso manual", com o teclado aberto, a folha fica acima do teclado
  e o corpo rola até o botão.

## 6. Mensagens

- Como suporte, a partir da ficha da conta de teste: Ações › Enviar mensagem › escrever › Continuar › Enviar ›
  confirmar. São 2 passos ("Passo 1 de 2 · Conteúdo", "Passo 2 de 2 · Revisar"), com o chip "Para: {nome}" e
  "Trocar". Com o teclado aberto no texto, o rodapé não cobre o campo.
- Como admin, Nova mensagem a 390 px, passo 3: o rodapé tem uma linha só ("Voltar" e "Continuar"), logo acima
  da barra de baixo, sem ficar atrás dela.
- "Enviar teste para mim": o aviso "Teste enviado" aparece no topo, sem ficar sob a ilha do iPhone e sem cobrir
  os botões.
- Envio para várias clientes sem teste: tocar no "Enviar" apagado mostra o aviso acima do rodapé.
- Cartão agendado: o botão diz "Cancelar envio"; o diálogo tem "Manter agendado" já em foco.
- (computador) Como suporte, pela ficha: ao lado da prévia aparecem "Para:", a contagem e "Quando: agora".

## 7. Suporte

- Os três cartões (Abertos, Aguardando, Meus) cabem sem palavra partida; o contador amarelo da barra de baixo é
  legível nos dois temas.
- Ficha da conta de teste › Ações › "Registrar atendimento": com o teclado aberto, os campos não dão zoom, os
  chips "Chegou por" são tocáveis, "Cancelar" e "Registrar" ficam acima do teclado. Ao registrar, aparece
  "Atendimento registrado." e a aba Suporte da ficha mostra o pedido; na caixa do Suporte, "Abertos" sobe 1.
- Pela caixa, "Registrar atendimento" acha a cliente pelo nome; escolhida, o cursor vai para o Assunto.
- Num pedido: trocar a categoria mostra o aviso com o valor; "Encerrar" pede confirmação e o aviso
  "Encerrado." tem "Desfazer". Com o VoiceOver, depois de encerrar, o foco fica em "Reabrir".

## 8. Equipe

- A tela se chama "Equipe". Criar uma conta de teste **sem CPF**: o "Definir senha" abre sozinho em seguida;
  com o teclado aberto, "Salvar senha" fica visível e o aviso "Conta criada…" não cobre a folha. Depois, a
  pessoa entra por `/login/equipe`.
- O papel não oferece "Cliente"; a linha embaixo do papel diz o que ele vê.
- Quem publica a alma aparece com o selo "Publica a alma"; no cabeçalho dessa pessoa, "Admin · publica a alma"
  cabe sem cortar o nome.
- A folha "Mais" tem os grupos Operar, Crystal, Entender e Ajustar, e rola bem.
- "Encerrar as sessões desta pessoa" fica em "Zona de risco", vermelho legível no tema escuro.

## 9. Crystal

- `/equipe/crystal`: o menu da área (Painel, Alma, Base, Acompanhar, Laboratório), o Status com "Atualizado às
  hh:mm" e as abas (Modelo, Comportamento, Fichas, Saúde) cabem na primeira tela. O menu rola de lado.
- Tocar no cartão Crystal do Início: para em Comportamento › Pausa, abaixo da barra de cima.
- Deixar o app em segundo plano por mais de 1 minuto e voltar: o "Atualizado às" muda.
- "Buscar modelo" filtra a lista; os campos de Memória e Ritmo abrem o teclado numérico sem zoom; "Salvo. Vale
  a partir da próxima resposta." não fica atrás da barra de baixo.
- Trocar o modelo das respostas para um bem mais caro (e **voltar logo em seguida**): a frase do custo aparece
  em vermelho; o diálogo mostra "De:" e "Para:" e pede a palavra TROCAR com o teclado aberto. Depois de
  trocar, "Em uso" diz quem trocou e quando, e "Voltar para {anterior}" volta em um toque.
- Foto: "Remover a foto da Crystal?" fica acima do teclado e da barra (se for testar, ter a foto à mão para
  subir de novo).
- Fichas e Base com a base de conhecimento fora: a primeira linha diz o que fazer; "Detalhe técnico" abre e
  fecha com o toque. (Só se acontecer de verdade: não dá para provocar sem mexer no Supabase.)

## 10. Laboratório

- A 390 px: "Conversas (N)" ao lado de "Nova conversa" abre a lista numa folha.
- Com o teclado aberto no campo "Mensagem da cliente", o campo e o "Enviar" ficam acima do teclado, sem pulo.
  Rolar até o fim: nada de vão em branco.
- Na mensagem da Crystal: "Boa", "Ruim" e "Mais". "Mais" abre "Esta mensagem" com a ajuda de cada ação.
- Quando a trava barra uma resposta, o selo vira botão e abre "Por que a trava barrou".

## 11. Configurações

- No celular: a faixa de busca e os chips (Produto, Crystal, Retenção, Contatos, Técnico, Ambiente) gruda logo
  abaixo da barra de cima; os grupos começam fechados; tocar num chip abre só aquele grupo e para logo abaixo
  da faixa. Os cartões não mostram mais "Chave: …" (ela fica na folha do histórico).
- O "Topo" aparece depois de rolar e não fica atrás da barra de baixo.
- Com "Reduzir movimento" ligado: o chip, o "Topo", o botão de descer da conversa e os pontinhos do carrossel
  pulam direto, sem animação.

## 12. Métricas, Financeiro e Auditoria

- Métricas: tocar e arrastar de lado na curva "Acessos por dia" escreve o valor do dia embaixo; o dedo que sobe e
  desce sobre o gráfico continua rolando a página. As datas do eixo não se sobrepõem; o eixo de contagem mostra
  0, 1, 2, nunca "0,5". "Ver como tabela" abre sem rolagem de lado. Os minutos de áudio aparecem com vírgula
  ("0,1 min").
- Financeiro: cartões com nome e CPF mascarado, valor e pílulas; nada rola de lado. A folha "Filtros" tem os
  rótulos à vista e "Só vencidos" como interruptor. Da ficha › aba Financeiro › "Ver no Financeiro": aparece o
  chip "Cliente: {nome}", e o "×" tira o filtro.
- Auditoria no celular: depois de filtrar por data e pessoa, o botão diz "Filtros (2)" e os chips "De dd/mm" e
  "Pessoa: …" aparecem; uma busca longa quebra dentro do chip.

## 13. Início e Banners

- Início: os atalhos do papel cabem e têm o tamanho do dedo. Como suporte, "Buscar cliente" com Ir/Enter cai
  na lista já buscada, sem o termo no endereço. "R$ 1.297,00" fica inteiro (a letra diminui se precisar).
- Banners: na lista, "Desligar", "Editar" e "Mais" numa linha; "Mais" abre Subir, Descer e Ver inscritos.
  Criar um banner de teste com imagem e "Ligar assim que criar": aparece "Banner criado e no ar." e o banner
  aparece no início do app (desligar e apagar o de teste depois).

## 14. O app da cliente (só conferir que nada mudou)

- Nenhum texto do app diz "aluno" ou "aluna". Uma mensagem da equipe com `{nome}` para uma conta sem nome chega
  como "Oi!" (não "Oi, Aluno!").
- O login da cliente continua sem link para a área da equipe.

## 15. Android (quando houver um com Chrome)

- Configurações: os chips deslizam e o "Topo" aparece.
- Laboratório: o campo fixo com o teclado aberto e a rolagem até o fim.
- Banners: a linha de um banner a 360 px.

## Decisões do dono aplicadas com o padrão

Nenhuma resposta chegou antes da onda; valeu o padrão escrito no PRD, registrado no commit de cada item. Para
mudar alguma, é só dizer: cada uma é pequena.

| Pergunta | Padrão aplicado | Onde |
|---|---|---|
| 8. A lista de clientes exclui as contas de revisão da loja por padrão? | Exclui (lista, busca e CSV em "Todos"); os números batem | U28 |
| 9. O código de confirmação num segundo passo da mesma folha? | Não faz: o teclado já não esconde os botões | U33 |
| 10. Esconder a barra de baixo durante a Nova mensagem? | Não: a barra continua, e o rodapé fica acima dela | U34 |
| 11. Barra de baixo por papel (Crystal para admin, Suporte para o suporte)? | Não: a barra é a mesma para todos; só a folha "Mais" foi reagrupada | U45 |
| 12. A Bia religa cliente (pendência 20)? | Continua como hoje; o "Desfazer" do Desligar segue a mesma permissão | U27 |

Decisões do dono de 27/10, aplicadas em toda a onda: "cliente", nunca "aluna", em todo texto (U59); e o erro da
conversa só com a frase neutra e o código, a causa só para a equipe (P1 separa crédito e chave em C02 e o prazo
em C03).

Ficam para o dono responder quando puder (nada disso trava a subida):

- Crédito zerado e chave recusada (C02) continuam acendendo a faixa "fora do ar" para as clientes. Se preferir
  que o C02 nunca acenda, é uma linha (`CRYSTAL_DOWN_CODES`).
- Conta que entrou sem nome na base fica com o nome provisório "Aluno" no banco (a equipe vê na lista e na
  ficha; a cliente não). Trocar para "Cliente" pede decidir o que fazer com as contas antigas.
- O mapa de calor das coortes (Métricas › Clientes) rola de lado no celular. Sem item no PRD: vira cartões no
  celular ou fica assim?
- Os arquivos CSV mudaram de nome e de cabeçalho (`clientes.csv`, coluna "cliente"). Se alguma planilha ou
  automação lê esses arquivos pela coluna, precisa saber.
- Da onda 1, ainda sem resposta: o tom do toque no botão rosa (`#c20857`).
