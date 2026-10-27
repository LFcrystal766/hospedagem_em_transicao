# Onda 1 de UX: o que conferir no iPhone logo depois de subir

Para o Luiz, no iPhone dele, logo depois de `app-subir` da onda 1 de UX (itens U01 a U23 do
`docs/ux/PRD-ux-ui-2026-10-25.md`). Cada linha diz onde ir, o que fazer e o que tem de aparecer. Se uma
linha der errado, a volta é na hora: `bash bootstrap-vps.sh app-subir <tag anterior>` (a tag anterior
fica anotada antes de subir). A migração desta onda (`messages.neutra`) é só uma coluna nova com padrão
"falso": a volta da imagem não precisa de volta de banco.

## Antes de começar

- Conferir em `bash bootstrap-vps.sh app-status` que o canal do app é `crystal` (`CHAT_TRANSPORT`). O
  "digitando…" na hora, a fila de mensagens, o "Tentar de novo" da resposta barrada e os códigos de erro
  foram feitos para esse modo. Se aparecer `chatwoot`, avisar antes de seguir: nesse modo parte da
  conversa não muda.
- Abrir o app uma vez e fechar: o service worker troca o cache velho (`crystal-shell-v4`) pelo novo
  (`v5`). Sem isso, a tela sem internet e as páginas públicas podem vir na versão anterior.
- Conferir nos dois jeitos: no **Safari** e no **app instalado** (ícone na tela de início). E nos dois
  temas do iPhone: **claro** e **escuro** (Ajustes › Tela e Brilho).
- **Nunca em produção:** ligar o modo reserva manual (manda push para toda a base), nem os gatilhos de
  teste (`#erro`, `#fora`, `#neutra`): eles só existem no modo demo local. As linhas marcadas "(local)"
  são conferidas pela técnica no computador, não no app no ar.

## 1. Entrar (tela de login)

- O botão verde "Receber o código" está legível, inclusive ao sol: é um verde mais escuro que o de antes.
- Tocar em "Receber o código" com o campo vazio: aparece "Digite o e-mail que você usou na compra." e o
  teclado abre no campo.
- Digitar "ana@exemplo" (sem o ponto), com o teclado aberto, e tocar no ALTO do botão: aparece "Esse
  e-mail parece incompleto. Confere se tem o @ e o ponto, como nome@gmail.com.", o cursor volta ao campo
  e o toque não se perde. Enquanto digita, a borda não fica vermelha.
- Tocar no campo do e-mail não dá zoom na página.
- Os links do rodapé ("Privacidade", "Termos de Uso") são fáceis de tocar.
- Passo 2 (depois de pedir o código): título "Agora olha o seu e-mail". Com o teclado numérico aberto,
  "Reenviar em N s" e "Trocar o e-mail" são tocáveis e não se confundem. Não há relógio até o último
  minuto; aí aparece "Esse código vence em 0:45" (contando para baixo), um relógio só. Ao zerar: "Esse
  código venceu." e "Pedir outro código", que volta ao passo 1 com o e-mail já preenchido.
- Esperar 60 s sem digitar o código: aparece "Não chegou?" com a linha de procurar em Spam, Lixo
  Eletrônico ou "Outros", "Trocar o e-mail", "Falar com o suporte" e "ou pela tela de Suporte".
  - "Falar com o suporte" abre o WhatsApp com "…Pedi o código no app da Crystal e ele não chegou no meu
    e-mail." e **sem** o e-mail.
  - "ou pela tela de Suporte" abre a tela Suporte sem pedir login.
- Com um e-mail do Hotmail ou do Outlook, o aviso "No Hotmail e no Outlook o código às vezes demora…"
  aparece desde o começo do passo 2.
- Pedir o código de novo dentro de 5 minutos: a tela diz "Use o código que já está no seu e-mail" e
  quanto tempo ele ainda vale.
- Se houver uma conta que nunca entrou (compra de teste): depois do código certo, o campo some, o
  teclado fecha, aparece "Código certo! Falta só o seu OK:" com uma caixa grande e "Concordar e entrar"
  entra sem redigitar o código. No tema escuro, o visto verde do "Código certo!" aparece.

## 2. Instalar pelo Safari

- Na folha de instalar pelo Safari, o aviso "Depois de instalar, o app pede seu e-mail e o código mais
  uma vez. É só nessa primeira vez." vem antes dos passos.
- Abrir pelo ícone novo: o login diz "Pronto, o app está instalado! Entra de novo com o e-mail da
  compra, só desta vez."
- Sair e entrar de novo dentro do app instalado: a frase volta ao normal.
- No app instalado, a folha "Pronto!" do Android não aparece.

## 3. Início

- A faixa "Instale o app da Crystal" (no Safari) tem a mesma altura de antes; o botão "Instalar" é
  verde escuro sobre branco e fácil de tocar.
- Com o perfil incompleto, a linha da Crystal travada tem o texto nítido; só a foto fica esmaecida.
- Tocar e segurar "Conversa" escurece o botão enquanto o dedo está nele. Tocar num botão não acende
  nenhum anel rosa (o anel é só para teclado).
- Menu de três pontinhos: tem "Suporte" (fácil de tocar) entre "Notificações" e "Política de
  privacidade". "Suporte" abre a tela que fala do curso, das aulas, do acesso, do pagamento e do app.

## 4. Conversa

- Mandar uma mensagem: os tiques ficam azuis e os três pontinhos aparecem em menos de 1 s, antes da
  resposta.
- Mandar duas mensagens seguidas: as respostas chegam na ordem, sem bolhas misturadas, e os pontinhos
  continuam enquanto a segunda resposta é escrita. A segunda mensagem fica com um tique até a primeira
  resposta chegar.
- Áudio já transcrito: a transcrição está legível na bolha rosa, com uma linha fina acima.
- Tocar no play e no "1x" do áudio sem errar. O botão de descer a conversa e os pontinhos do carrossel
  do início acertam com o dedo.
- Uma foto pequena ou estreita na conversa abre em tela cheia com um toque.
- Menu da conversa: "Suporte" e "Recomeçar a conversa". "Recomeçar a conversa" abre a folha
  "Recomeçar a conversa do zero?": "Cancelar" fecha sem mandar nada; "Recomeçar" manda o `#reset` e a
  bolha fixa do recomeço responde (conta no limite de 3 por dia).
- Manutenção (se for ligada no painel em algum momento): faixa "Estou em manutenção por alguns minutos.
  Já volto para a gente continuar." e o topo "em manutenção". Pausa: o topo diz "em pausa", em
  minúscula.
- (local) Crystal fora (`#fora`, ou pausar o serviço da Crystal na VPS fora do pico): a bolha "Não
  consegui te responder agora." com "Código C01" e **sem** "Tentar de novo"; a faixa "Não estou
  conseguindo responder agora. Tenta de novo daqui a alguns minutos. Código C01."; o topo "fora do ar
  agora"; o campo continua aberto; recarregar mantém o código. Nenhuma frase diz a causa.
- (local) Resposta que cai (`#erro`): "Código C05" com "Tentar de novo". Transcritor fora: "Código C07"
  com "Tentar de novo".
- (local) Resposta barrada pela trava (`#neutra`): a pílula "Tentar de novo" (com a seta) aparece
  embaixo de "Desculpa, me perdi aqui. Pode repetir?"; o toque traz o "digitando…" e a resposta nova
  sem repetir a mensagem da cliente.
- (local) Resposta de risco: tocar no 188 (e no 192, 180, 190) abre o discador com o número; tocar em
  cvv.org.br abre o Safari, também no app instalado. O dedo no 188 não cai no cvv.org.br da linha de
  baixo.

## 5. Áudio

- Gravar até 2:00, pelo toque e pelo gesto de segurar: a gravação para em "2:00" com "Chegou no limite
  de 2 minutos. Envia esse áudio ou apaga e grava outro."; soltar o dedo não envia (o enviar aparece onde
  estava o microfone, sem clique fantasma); enviar e lixeira funcionam.
- Recusar o microfone:
  - no Safari, o aviso fala do ícone ao lado do endereço e de "Ajustes do Site";
  - no app instalado, o aviso fala de "Ajustes do iPhone › Crystal › Microfone". **Conferir se esse
    caminho existe no iPhone.** Se não existir, avisar a técnica para ligar
    `MICROFONE_IPHONE_INSTALADO_USA_RESERVA` (o texto vira "Feche o app da Crystal, abra de novo e toque
    em Permitir quando o iPhone perguntar.").
- "Já liberei" pede o microfone de novo; o X fecha o aviso e fica na mesma linha do "Já liberei".

## 6. Sem internet

- Em modo avião (ou rede ruim), mandar uma foto com legenda e um áudio, fechar o app e abrir de novo: as
  duas bolhas voltam com "Não consegui enviar. Tentar de novo" e saem sozinhas quando a internet volta,
  sem ficarem duas vezes na conversa. A pílula é legível na bolha rosa.
- Depois de "Sair" e entrar de novo: nada do que estava guardado volta.
- Modo avião ao abrir o app: a tela "Você está sem internet", "Eu continuo por aqui. Confere a internet e
  tenta abrir de novo." e o botão "Tentar de novo" em branco sobre rosa, legível.

## 7. Perfil e conta

- Perfil vazio: os textos de exemplo dos campos estão legíveis. Tocar e segurar "Salvar" escurece o
  botão.
- No fim do perfil: "Ver o tutorial de novo" é um botão de borda; depois de uma linha, "Excluir minha
  conta" sozinho, com a lixeira.
- Tocar em "Excluir minha conta" (sem ir até o fim): o botão de excluir só acende depois de marcar a
  caixa "Entendi que não dá para desfazer.", que é fácil de tocar. Fechar com "Cancelar". **Não excluir
  a conta de verdade.**
- Menu › "Sair": abre "Sair do app?" com "Ficar" e "Sair". "Ficar" fecha e a sessão continua.
- Menu › "Política de privacidade": abre com a seta de voltar no topo, abaixo do relógio e do recorte
  da tela; a seta volta para o início. O mesmo em Termos e em Excluir conta, abertos direto por link: a
  seta leva ao início (ou ao login) sem fechar o app. O "Voltar" do fim de Termos e Política é fácil de
  tocar.

## 8. Acessibilidade

- Ajustes › Acessibilidade › Movimento › **Reduzir movimento** ligado: os três pontinhos do "digitando…"
  ficam parados, num tom só; a marca da Crystal nas telas de carga para; o spinner do "Entrar" continua
  girando, mais devagar; a bolinha de gravação para e continua vermelha; a seta e o brilho da faixa de
  instalar param. Com o ajuste desligado, tudo volta a se mexer.
- Com o **VoiceOver**: uma resposta de 3 bolhas é lida uma vez, sem repetir "digitando"; a falha de envio
  é anunciada, e de novo depois de um "Tentar de novo" que falha outra vez; "Transcrevendo…" e o aviso
  das imagens não falam no meio da resposta; ao excluir a conta, "Pode levar até um minuto. Não feche o
  app." é lido.

## 9. Painel da equipe no iPhone

- Tocar nestes campos não dá zoom: "Buscar por nome, e-mail ou CPF" em Alunos; "Motivo" de "Desligar";
  "Código" do diálogo de recomeço e de reautenticação; o seletor de tema; o e-mail e a senha de
  `/login/equipe`; o editor da alma em Crystal › Alma (como superadmin).
- No computador: os campos do painel continuam em 14 px (o editor da alma em 12 px); com a tecla Tab, o
  anel rosa aparece em botões, links, itens de menu e linhas de tabela, e inteiro nas abas da ficha com
  a janela estreita.

## 10. Erro crítico (local ou simulador)

- Só em local, com um erro forçado no layout, no simulador de iOS 15 e no iPhone: a tela "Algo deu
  errado do meu lado." tem o fundo e as cores da Crystal (nada de roxo), letra no tamanho certo, fonte do
  sistema, "Tentar de novo" mais escuro no toque, e "Falar com o suporte" abre o WhatsApp com "Oi, Bia!
  O app da Crystal deu um erro ao abrir.". Claro e escuro.

## 11. Android (quando houver um com Chrome)

- O toque no "Receber o código" com o e-mail incompleto (como no item 1).
- O voltar do sistema fecha as folhas de recomeçar e de sair sem sair da conversa; depois de abrir
  Termos ou Excluir conta por link, o voltar leva ao início.
- A faixa de instalar e a conversa com áudio e foto; o aviso do microfone recusado com os textos de
  Android.

## Decisões do dono aplicadas com o padrão

Nenhuma resposta chegou antes da onda; valeu o padrão escrito no PRD, registrado no commit de cada
item. Para mudar alguma, é só dizer: cada uma é pequena.

| Pergunta | Padrão aplicado | Onde |
|---|---|---|
| 1. O botão de entrar continua verde (mais escuro) ou vira rosa? | Continua verde, mais escuro para ficar legível | U01 |
| 2. "Recomeçar a conversa" entra no menu da conversa? | Entra, com diálogo, o mesmo `#reset` e o limite de 3 por dia | U04 |
| 3. Ritmo mais curto em Crystal › Ritmo (20 ms por letra, pausa máxima de 1.500 ms)? | Nada muda até o dono mexer no painel | U07 |
| 4. Botão "Falar com o suporte" no "Não chegou?" do passo do código? | Entra | U10 |
| 5. Aos 2:00 o áudio para e espera, em vez de sair sozinho? | Para e espera | U13 |
| 6. As frases de `/termos` e `/privacidade` entram agora? | Não: só `/excluir-conta`, painel e API; as páginas legais ficam como estão até a Gisele e o Luiz validarem | U18 |
| 7. Microcopy do perfil e do suporte em forma neutra de gênero? | Neutra | U18 |

Decisões do dono de 27/10, já aplicadas: "cliente", nunca "aluna", em todo texto novo ou alterado (a
varredura do resto é o U59, na onda 2); e o erro da conversa só com a frase neutra e o código (C01 a C09),
a causa só para a equipe (U05).

Ficam para o dono responder quando puder (nada disso trava a subida):

- O tom novo do toque no botão rosa, `#c20857`, veio do kit das telas finais para o branco passar de
  4,5:1 no escuro. Precisa do OK.
- O rótulo de voz do link do CVV é "Abrir o site do CVV"; quem usa comando de voz e diz "cvv.org.br" não
  acha o link. Sugestão: "Abrir o site do CVV, cvv.org.br".
- O texto de "limite de recomeços" (`resetLimite`) não mudou; a sugestão do PRD fica para quando o dono
  quiser: "Você já recomeçou a conversa algumas vezes hoje. Amanhã dá para recomeçar de novo. Se precisar
  de ajuda agora, toca nos três pontinhos, em Suporte."
- Depois do teste do microfone no iPhone instalado: ligar ou não `MICROFONE_IPHONE_INSTALADO_USA_RESERVA`.
- Para a técnica: hoje crédito zerado, chave recusada e prazo do modelo chegam todos como C01. Separar
  pede mapear `NO_CREDIT` e `TIMEOUT` no cliente da API (com cuidado, porque só alguns códigos ligam a
  faixa de "fora do ar").

E um passo para a sessão da hospedagem, antes de encerrar o WhatsApp: Integrações › Canal →
**Desligado**, e conferir Configurações › Produto › "Aviso do modo reserva" (se tiver a frase antiga do
WhatsApp gravada, trocar). Entra em `PROXIMOS-PASSOS.md` › "Ordem", antes de tirar o webhook do LendChat.
