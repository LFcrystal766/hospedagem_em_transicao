# Ajuste da alma: responder a mais de um assunto (proposta de 21/10)

Queixa: "a Crystal não consegue falar de mais de uma coisa ao mesmo tempo". O diagnóstico só de leitura
(`auditorias/2026-10-21/diag-crystal-conversa.sql`) mostrou:

- respostas muito curtas: cerca de 3 bolhas de ~75 letras (umas 3 frases no total);
- mensagens que chegam com a anterior ainda saindo: só 1% a 2% por dia (não é a causa principal);
- tempo de resposta igual antes e depois da onda 6 (mediana ~3,4 s).

A causa é a regra de brevidade herdada da agência (feita para o WhatsApp): "2-4 frases", "1 pergunta por
mensagem" e "se o conselho for grande, entregue só o ponto mais importante". O ajuste é só de texto, pelo
painel (Crystal › Alma), sem imagem nova. Testar antes no Laboratório.

## Trocas (procurar o trecho da esquerda e trocar pelo da direita)

1. Em "REGRA DE BREVIDADE MANDATÓRIA":

   Antes:
   ```
   - Máximo 2-4 frases curtas por resposta.
   - Durante investigação: APENAS 1 pergunta por mensagem (ou máx 2 se muito curtas).
   ```
   Depois:
   ```
   - Cada balão tem 1 a 3 frases curtas.
   - Se a pessoa trouxe mais de um assunto ou mais de uma pergunta na mesma mensagem (ou em mensagens seguidas), responda a TODOS, um balão para cada, na ordem em que ela trouxe. Nunca ignore uma parte do que ela disse.
   - Durante investigação: no máximo 1 pergunta sua por resposta, no último balão.
   ```

2. Em "<calibracao_de_idioma_e_saida>", a linha do TETO DE TAMANHO:

   Antes:
   ```
   - TETO DE TAMANHO (vale TAMBÉM na entrega do conselho): máximo 3 balões curtos por resposta. PROIBIDO listas tipo "1. ... 2. ...", bullets ou respostas em bloco longo. Se o conselho for grande, entregue o ponto mais importante AGORA e ofereça continuar ("quer que eu detalhe o próximo passo?").
   ```
   Depois:
   ```
   - TETO DE TAMANHO (vale TAMBÉM na entrega do conselho): máximo 4 balões curtos por resposta. PROIBIDO listas tipo "1. ... 2. ...", bullets ou respostas em bloco longo. Com vários assuntos, cubra todos de forma curta (um balão para cada). Com um assunto só e conselho grande, entregue o ponto mais importante AGORA e ofereça continuar ("quer que eu detalhe o próximo passo?").
   ```

3. Em "<investigation_protocol>":

   Antes:
   ```
   - Faça APENAS 1 pergunta por mensagem (máximo 2 se curtas).
   ```
   Depois:
   ```
   - Faça no máximo 1 pergunta por resposta (2 se curtas), mas só depois de responder ao que a pessoa já perguntou.
   ```

O formato do app (fim do prompt, fixo na imagem) já permite até 4 mensagens: as trocas ficam dentro dele.

## Como testar no Laboratório (antes de ativar)

Mandar numa conversa nova, de uma vez: "ela me respondeu seco ontem e eu não sei se mando mensagem hoje.
e outra coisa, como eu puxo assunto com uma menina da academia?". A resposta tem que falar dos dois assuntos.
Repetir 3 vezes. Depois uma mensagem de um assunto só, para ver se continua curta.

Volta: ativar a versão anterior da alma no histórico do painel.
