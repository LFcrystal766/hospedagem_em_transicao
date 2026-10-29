# Onda 3 de UX: o que conferir no iPhone logo depois de subir

Para o Luiz, no iPhone dele, logo depois de `app-subir` da onda 3 de UX (itens U48 a U58 do
`docs/ux/PRD-ux-ui-2026-10-25.md`). A onda 3 muda o desenho dos dois lados (botão, campo, aviso, diálogo,
interruptor, ícones e títulos iguais no app e no painel) e o primeiro acesso da cliente. Cada linha diz onde ir, o
que fazer e o que tem de aparecer. Se uma linha der errado, a volta é na hora: `bash bootstrap-vps.sh app-subir <tag
anterior>` (a tag anterior fica anotada antes de subir). Esta onda não tem migração de banco nem variável nova: a
volta da imagem não precisa de volta de banco.

## Antes de começar

- A cobrança do GitHub tem de estar em dia (desde 28/10 o CI e o `imagens-vps` não rodam sem ela). Depois de
  acertar, esperar o CI da branch ficar verde antes de disparar o `imagens-vps`.
- API, web e Crystal sobem na **mesma tag**, como sempre (a onda 3 só muda o web, mas a conferência é da tag
  inteira). Conferir em `bash bootstrap-vps.sh app-status` que as três estão na tag nova.
- Conferir nos dois jeitos: no **Safari** e no **app instalado** (ícone na tela de início). E nos dois temas do
  iPhone: **claro** e **escuro** (Ajustes › Tela e Brilho).
- Para o primeiro acesso (parte 2 abaixo) é preciso uma **conta nova de teste**, com um e-mail seu: no painel,
  Clientes › "Nova conta local". Nunca uma cliente de verdade. Para o resto, a sua conta de sempre.
- O service worker não mudou nesta onda (`crystal-shell-v5`): não precisa abrir e fechar o app antes.
- Onde a linha diz "(computador)", é para a Bia conferir no computador dela.

## 1. Entrar (login da cliente e da equipe)

- `/login`: a marca no topo é o símbolo da Crystal sobre a palavra "Crystal" em rosa. O botão verde "Receber o
  código" tem os cantos levemente arredondados (não é pílula) e a mesma altura dos botões do resto do app.
- Tocar no campo de e-mail: **não dá zoom**. O campo tem fundo cinza claro (no escuro, cinza escuro), cantos
  arredondados e, no foco, borda e anel rosa.
- E-mail incompleto: o aviso vermelho aparece logo abaixo e a borda do campo fica vermelha, também com o cursor
  nele. "Seu acesso está desligado" e "Falta pouco!" aparecem num quadro rosa claro (informação), não amarelo.
- Passo do código: o rodapé "Conversa protegida" tem um cadeado pequeno de traço fino. Com o código certo, o tique
  aparece dentro do círculo verde, nos dois temas.
- `/login/equipe`: campos e botão iguais aos da cliente; tocar nos campos não dá zoom.

## 2. Primeiro acesso, com a conta nova de teste

Fazer de uma vez, do login até a primeira mensagem, no **app instalado** e depois de novo no **Safari** (outra conta
nova, ou a mesma depois de apagar e recriar).

- Depois do login, a tela de início com o primeiro balão do tutorial (os passos de hoje: pergunta 13 no padrão).
  A foto (ou as iniciais) no topo **não** é botão e **não** tem o selo de câmera.
- No fim do tutorial, "Completar perfil" abre o perfil com o aceite: abaixo do título aparece "Primeiro o seu OK;
  depois, 5 perguntas rápidas." e, abaixo do cartão, "Depois do OK: seu nome, sua idade, o que você busca, seu
  jeito de conversar e seu momento de vida.". "Ver o tutorial de novo" e "Excluir minha conta" (com a lixeira)
  ficam no pé da tela, separados por uma linha, não colados ao cartão.
- "Pode guardar": aparecem as perguntas e o balão "Seu nome já veio da compra. Agora responde as outras perguntas,
  começando por aqui. No fim, toca em Salvar." apontando para a **idade** (não para o nome). Tocar em "Começar":
  o cursor vai para a idade e o teclado abre no mesmo toque.
- Os campos do perfil não dão zoom. Deixar uma resposta em branco e tocar em Salvar: a borda do campo fica vermelha.
- Responder tudo e Salvar: abre **direto a conversa**, com a pílula "Perfil salvo. Agora é só me contar o que
  está rolando." acima da área vazia, e o tutorial da conversa por cima (mensagem, microfone, clipe). Depois do
  tutorial, a pílula some em uns 4 segundos (ou na primeira mensagem) e não volta ao rolar nem ao reabrir: não é
  mensagem da Crystal.
- **Nenhuma** folha "Ative as notificações" nessa abertura, nem ao voltar ao início. Fechar o app de verdade
  (arrastar para cima) e abrir de novo: agora aparece o pedido. No app instalado, com o texto "Assim você sabe na
  hora quando a Crystal responde, mesmo com o app fechado, e fica por dentro das aulas ao vivo e das novidades. Os
  avisos de aulas dá para desligar no menu, em Notificações."; no Safari, o pedido para instalar ("No iPhone, as
  notificações só chegam com o app instalado na tela de início…").
- Recém-instalado: apagar o ícone do app, abrir o site no Safari, instalar de novo e abrir pelo ícone pela
  primeira vez. Nenhuma folha de notificações, nem ao ir do início à conversa. Na abertura seguinte, o pedido.
- Com o VoiceOver ligado, em cada balão do tutorial: lê o texto do balão e os botões; a pílula "Perfil salvo…" é
  lida uma vez.

## 3. Início (com o perfil completo, a sua conta)

- A marca no topo: o símbolo da Crystal ao lado de "Crystal" em rosa, logo abaixo do relógio e da ilha, com os
  três pontinhos à direita.
- A foto tem um selo redondo rosa com uma câmera no canto de baixo; tocar nela troca a foto.
- Abrir o perfil, mudar uma resposta e Salvar: volta ao início, e a linha cinza de estado diz "Perfil salvo." por
  uns 3 segundos.
- "Completar perfil" (na conta nova, antes de salvar), os botões do início e o "Entendi" da folha de instalar:
  cantos levemente arredondados, sem pílula.

## 4. Menu de três pontinhos

- O ícone dos três pontinhos é de traço fino, do mesmo jeito dos outros ícones.
- O menu tem dois blocos: "Tema" e, logo abaixo, "Tamanho da letra" (Normal, Grande, Muito grande, com o ✓ na
  escolhida e "Vale para todo o app neste aparelho.").
- Escolher **Muito grande**: as bolhas, a hora das mensagens e o campo de escrever crescem, sem linhas por cima uma
  da outra e sem a tela rolar de lado; os três caminhos do início continuam numa linha ou quebram limpos. Fechar o
  app de verdade e abrir: continua Muito grande, e o tema também. Voltar para Normal.
- Com o VoiceOver: o menu anuncia o grupo "Tema" e o grupo "Tamanho da letra", cada um com as suas três opções
  (não seis opções soltas).
- Na conversa, fazer a pinça (abrir dois dedos) para ampliar: a tela **não** encolhe nem pula para o topo.
- "Sair" e "Recomeçar a conversa": abrem por cima de um véu escuro, com os botões de cantos levemente arredondados;
  o "Ficar"/"Cancelar" tem o foco. Tocar fora (no véu) fecha.

## 5. Folha Notificações (menu › Notificações)

- No **Safari**: o título "NESTE APARELHO", a frase "No iPhone, as notificações só chegam com o app instalado." e
  o botão "Ver como instalar", que abre o passo a passo. Abaixo de uma linha, "NA SUA CONTA" com "Avisos de aulas
  e novidades", o interruptor desenhado (trilho com bolinha) e "Ligado"/"Desligado" escrito ao lado, e a frase
  "Aulas ao vivo, webinários e ofertas. Chegam na conversa com a Crystal e, se as notificações estiverem
  ativadas, também como aviso no celular." Nunca uma caixinha quadrada com ✓.
- No **app instalado**: "Neste aparelho" diz ativadas, desativadas ou bloqueadas, com o passo que resolve; o
  interruptor igual.
- Tocar no interruptor: muda e grava (fica meio apagado só enquanto grava). Fechar e reabrir a folha: a posição
  ficou. Deixar **ligado** no fim.
- Com o VoiceOver: lê "Avisos de aulas e novidades", interruptor, o estado e a frase de apoio (nunca só "Ligado"
  como nome). Depois de dar dois toques para alternar, o cursor do VoiceOver continua no interruptor, não pula para
  o topo da folha.
- No claro e no escuro: o trilho desligado (cinza) e a bolinha se veem bem sobre a folha.
- Na parte de baixo da folha, o espaço abaixo do conteúdo é o da barra de início do iPhone mais um pouco, não o
  dobro.

## 6. Conversa

- A barra de escrever: clipe, microfone e o enviar (avião de contorno sobre o botão rosa redondo) com o mesmo
  traço fino; o clipe do mesmo tamanho do microfone. A caixa de escrever continua bem arredondada (a do WhatsApp).
- Os tiques das mensagens continuam pequenos (como no WhatsApp).
- Tocar no nome da Crystal (cabeçalho): o perfil dela abre por cima do véu escuro, com "Fechar".
- Mandar uma foto: a prévia abre em fundo preto, com o X de traço fino e o enviar de contorno. Tocar numa foto da
  conversa: o visor abre em fundo preto; a pinça e o arrastar funcionam; "Fechar" fecha. Nada por trás recebe o toque
  enquanto o visor ou a prévia estão abertos.
- O botão de descer (seta para baixo) é de traço fino.

## 7. Perfil, Suporte e páginas públicas

- `/perfil`, `/suporte`, `/termos`, `/privacidade` e `/excluir-conta`: a seta de voltar numa linha e, logo abaixo,
  o título grande em Blinker (a mesma letra dos títulos do painel). A seta continua fácil de tocar.
- Com o iPhone **deitado**: o título não encosta no recorte da câmera.
- `/suporte`: os dois cartões de sempre e, abaixo da nota do fim, "Quer rever como usar o app? A tela de início e,
  na conversa, o áudio e o print." com o botão "Ver o tutorial de novo". Tocar: volta e mostra o tutorial do início;
  depois, ao entrar na conversa, o tutorial da conversa também. (Se o `/suporte` foi aberto pelo menu da
  conversa, o voltar leva à conversa primeiro: ver "Decisões", abaixo.)
- Perfil › "Excluir minha conta": o diálogo "Excluir sua conta?" abre por cima do véu escuro; o botão vermelho
  "Excluir minha conta" e o de cancelar com cantos levemente arredondados. Só abrir e cancelar.
- Endereço que não existe (`/nao-existe`) e a tela sem internet (modo avião, abrir o app): o título em 24 px e o
  botão com cantos levemente arredondados. No iPhone pequeno, o título pode quebrar em duas linhas, centralizado.

## 8. App da loja (Face ID), se estiver instalado

- A tela de bloqueio: o símbolo da Crystal grande sobre "Crystal", centralizados.
- No perfil, o interruptor do Face ID é o mesmo desenho da folha Notificações. Ligar e desligar funciona; durante
  a confirmação do Face ID, um segundo toque não abre outro pedido, e o foco (e o VoiceOver) volta ao interruptor.
- Abrir a foto no visor, sair do app e voltar: a trava fica por cima e responde; depois de destravar, o visor
  continua.

## 9. Painel da equipe (no iPhone)

- Botões e campos iguais aos do app da cliente: cantos levemente arredondados, campos sem zoom (Clientes › busca,
  Nova conta local, Liberar acesso manual).
- Aviso amarelo só para "não carregou, tenta de novo"; vermelho para erro (ex.: código incorreto num diálogo que
  pede código).
- Ficha da conta de teste, "Nova conta de equipe" (Equipe) e "Novo lançamento" (Financeiro): abrem como folha de
  baixo, com o véu escuro e o título em Blinker, iguais entre si. Com o teclado aberto, a folha fica acima dele e o
  rodapé (os botões) à vista. Embaixo, o espaço da barra de início uma vez só.
- No cabeçalho do painel no celular, só o símbolo da Crystal à esquerda do nome de quem entrou.
- O menu de baixo da equipe: ícones de traço fino, do mesmo peso da barra de escrever da conversa.
- Suporte: a pílula da situação (cheia) e a da categoria (só contorno). Integrações: o ambiente e as situações
  como pílulas iguais. Minha senha › "Seus aparelhos": "Este aparelho" como pílula.
- Métricas, numa aba sem dado: a caixa tracejada de vazio (a única do painel).
- Laboratório (a 390 px): em cada resposta, os botões "Boa" e "Ruim" com o polegar de traço fino e a palavra à
  vista, e "Mais"; nada quebra de linha feio. Crystal › Alma › Conversas reais: "Boa resposta" e "Resposta ruim"
  escritos ao lado do polegar.
- O "fechar" dos chips: Financeiro › "Cliente: {nome}" (vindo da ficha), a cliente escolhida no "Novo lançamento"
  e na Nova mensagem, e o "Remover lembrete" do evento de um banner: um X de traço fino (não mais o "×" de letra).
- Banners › "Mais" › "Ver inscritos": com o VoiceOver, lê "Ver inscritos do banner {nome}".
- Ficha da conta de teste › Recomeçar conversa (pede código): com o teclado numérico aberto, o campo do Código
  continua à vista acima de "Sim, recomeçar". Se o campo ficar escondido atrás do teclado, anotar (pendência da
  onda 2, U33).
- Pelo teclado (computador): num pedido do Suporte, tocar "Aguardando retorno", "Reabrir" e "Encerrar": o foco
  vai para o botão que entrou no lugar.
- (computador) A lateral do painel: "Crystal" em rosa com "Área da equipe" embaixo; os títulos das telas em Blinker.

## 10. Android (quando houver um com Chrome)

- O voltar do celular (botão ou gesto) fecha a folha, o diálogo, o visor e a prévia sem sair da conversa. Também
  depois de recarregar a página com uma folha aberta: reabrir a folha e voltar tem de fechá-la.
- Depois de Sair e de Excluir conta (conta de teste), o voltar não traz a conversa de volta.

## Decisões do dono aplicadas com o padrão

Nenhuma resposta chegou antes da onda; valeu o padrão escrito no PRD, registrado no commit de cada item. Para
mudar alguma, é só dizer: cada uma é pequena.

| Pergunta | Padrão aplicado | Onde |
|---|---|---|
| 13. Tutorial do início e da conversa com um balão só no primeiro acesso, e o contador "Faltam N respostas" no perfil? | Ficam como estão: o início com os passos de hoje, a conversa com 3 passos e o contador "N de 5 respondidas". O resto do item (Parte 2 na idade, notificações na abertura seguinte, "Perfil salvo", aceite, rever) entrou | U56 |
| 14. "Tamanho da letra" no menu de três pontinhos? | Entra (Normal, Grande, Muito grande), guardado no aparelho como o tema | U58 |

Decisões do dono de 27/10, aplicadas em toda a onda: "cliente", nunca "aluna", em todo texto novo; o erro da
conversa só com a frase neutra e o código (a onda 3 não mexe nisso).

Ficam para o dono responder quando puder (nada disso trava a subida):

- "Ver o tutorial de novo" no `/suporte`, quando o `/suporte` foi aberto pelo menu da conversa: o voltar leva à
  conversa, e a cliente vê primeiro o tutorial da conversa; o do início só quando ela voltar ao início. É o que o PRD
  manda; se preferir começar sempre pelo início, é uma linha.
- Na folha Notificações, o título "Neste aparelho" se repete na frase do estado ("Neste aparelho: ativadas."). Dá
  para tirar o começo da frase.
- Dois títulos do painel não seguem o título padrão: o assunto de um pedido do Suporte e o nome na ficha da
  cliente. Ficam assim ou passam ao padrão?
- Setas e marcas de texto ("›", "←", "✓") ainda servem de ícone ao lado de um texto em algumas telas do painel.
  Passam para os ícones de traço fino numa rodada seguinte?
- Das ondas anteriores, ainda sem resposta: C02 (crédito e chave) acendendo a faixa "fora do ar"; o nome provisório
  "Aluno" no banco; o mapa de calor das coortes que rola de lado; os CSVs com o nome novo; o tom `#c20857` do toque
  no botão rosa.
