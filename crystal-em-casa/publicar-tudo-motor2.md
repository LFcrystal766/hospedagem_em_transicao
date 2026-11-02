# Publicar tudo de uma vez: segurança de 24/10 + UX (ondas 1, 2 e 3) + Motor 2.0 só para admins

Escrito em 02/11/2026 a pedido do dono ("tudo junto, numa janela"). Quem roda é o Luiz, na VPS, como root.
Claude não publica nada.

Branch `painel/motor2` do app, em **`20da7ee`**. Ela contém, em cima uma da outra:

- a revisão de segurança de 24/10 (era a `sha-3c343df`);
- as ondas 1, 2 e 3 de UX, inclusive "cliente, nunca aluna" (era a `466886d`);
- o Motor 2.0, fases 1, 2 e 3 (M01–M09, M12, M13 e A01):
  - só contas **admin** marcadas recebem o 2.0;
  - cliente, WhatsApp, suporte e técnico ficam sempre no motor atual;
  - tornar o 2.0 padrão está travado no servidor.
- a decisão de 02/11: o Lado a lado conta pelo literal do PRD (pelo menos 20 comparações e 12 vitórias).

M10 e M11 (a nota diária de qualidade e a tela dela) **não** estão aqui.

## O que muda para os clientes

O pedido dos clientes à Crystal sai igual ao de hoje, byte a byte, com teste. Só duas mudanças chegam a eles:

1. **As telas novas das ondas de UX.** São as três listas do iPhone, abaixo.
2. **O teto de gasto por cliente: US$ 1,00 por dia (M12).** Vale nos dois motores.
   - Quem passa do teto recebe uma frase fixa até a meia-noite de Brasília.
   - Mensagem de risco à vida ignora o teto e leva os contatos de ajuda.
   - A equipe recebe um aviso por cliente por dia.
   - O cartão "Clientes no teto hoje" fica na aba Saúde.
   - Só o admin muda o valor, entre 0,20 e 10,00.

## Antes (técnica, já feito)

- GitHub Actions voltou: o CI de `2826c7d` passou em 01/11.
- Imagens **`sha-20da7ee`** (API, web e Crystal) geradas pelo `imagens-vps` em 02/11.
- Portão local:
  - `completo` verde, com e2e 302 passaram e 0 falhas, Safari e audit;
  - só cai o teste de tempo conhecido da Crystal, que também falha na versão de antes.
- Revisão de segurança e revisão holística feitas, todos os achados corrigidos, segunda leitura de segurança APROVADO.

## Banco, variáveis e volta

**Migrações.** Todas só acrescentam e rodam sozinhas na subida:

- **No banco do app** (Prisma, no `app-subir`):
  - `pa23_01_sessoes_rotacao_refresh` (segurança);
  - `ux1_01_messages_neutra` (onda 1);
  - `vm2_07_laboratorio_motor` (Laboratório 2.0);
  - `vm2_09_crystal_motor` (`users.crystal_motor`, `messages.crystal_motor` e `crystal_nivel`).
- **No banco da Crystal** (ela mesma confere ao subir, tudo `if not exists`):
  - colunas novas em `uso_turnos`: `motor`, `nivel`, `trechos_a`, `regras_versao`, `trechos_b`, `exemplos_ms`, `cortada`;
  - `resumos.fatos_hash`;
  - dois índices, entre eles o da soma do dia do teto;
  - a regra de `busca` aceita os valores novos.
  - A imagem antiga não refaz essa regra (só cria se não existir), então a volta sobe limpa.

**Variáveis.** Nenhuma nova é obrigatória: todas as novas têm padrão.

- **Não** ponha `MOTOR2_PROMOCAO_LIBERADA` no `api.env`. Sem ela, o 2.0 não vira padrão.
- API, web e Crystal sobem na mesma tag, porque o contrato entre eles mudou.

**Volta.** Para a tag no ar hoje:

```bash
REF=97b5ad29d2b998163bc31654cbc2c00aa8017d7e bash bootstrap-vps.sh app-subir sha-088d07d
```

- A imagem antiga sobe com as colunas novas no lugar, então não há volta de banco.
- Se o `bootstrap-vps.sh` da VPS já for o da madrugada da segurança (sha256 `5fcf467…`), rode **sem** o `REF=…`.

## Antes de subir (dono, uma vez)

1. **Toda conta da equipe tem senha.** Depois da segurança, a porta da cliente não abre mais o painel. Este comando tem
   de voltar `(0 rows)`:

   ```bash
   docker exec -i $(docker ps -q -f name=crystal_app_app_postgres) psql -U crystal -d crystal_web_chat -c "select id, role, status from users where role in ('support','tech','admin') and password_hash is null;"
   ```

   Se voltar alguma linha, essa pessoa define a senha antes da subida.
2. `bash bootstrap-vps.sh app-status`: anote a tag no ar (deve ser `sha-088d07d`) e confira que o canal é `crystal`.
3. `bash bootstrap-vps.sh backup`.

## Subir

Escolha um horário de pouco movimento. O app fica alguns segundos sem responder enquanto troca. Não precisa ser a
janela de madrugada: essa é só para o laranja do Cloudflare e para a infraestrutura.

```bash
REF=97b5ad29d2b998163bc31654cbc2c00aa8017d7e bash bootstrap-vps.sh app-subir sha-20da7ee
bash bootstrap-vps.sh app-status
bash bootstrap-vps.sh crystal-conferir
```

Tem de aparecer:

- os três serviços em `sha-20da7ee`;
- as migrações aplicadas;
- o `crystal-conferir` sem erro.

Se algo falhar, rode a volta.

## Conferir logo depois (10 minutos)

1. **Como cliente** (uma conta comum, no iPhone):
   - abra o app uma vez e feche, para o cache trocar;
   - mande um texto, uma foto e um áudio;
   - as respostas devem vir como antes, e no menu **não** deve aparecer "Motor 2.0 (teste)".
2. **No painel, como admin:**
   - Crystal › Saúde: o cartão "Clientes no teto hoje" mostra 0 e o teto US$ 1,00.
   - Integrações › Canal: o "Modo backup" aparece **Desligado**.
3. **Ligar o Motor 2.0 na sua conta admin.** Na aba Crystal › Motor 2.0:
   - **Modelos do Motor 2.0:** deixe vazio para usar os do motor atual, ou escolha outro (o painel pergunta ao modelo
     antes de gravar).
   - **Contas no Motor 2.0:** marque a sua conta admin. Vale a partir da próxima mensagem.
   - O botão "Tornar o Motor 2.0 o padrão" aparece **travado**, como decidido.
   - "Voltar ao motor atual" funciona sem senha.
4. **Na sua conta admin, no app:**
   - o menu mostra "Motor 2.0 (teste)";
   - mande texto, foto e áudio;
   - no painel, essas respostas aparecem como 2.0.

Se o 2.0 der problema: desmarque a sua conta em "Contas no Motor 2.0". Isso vale na mensagem seguinte e não afeta
nenhum cliente.

## Conferir no iPhone, com calma

1. Ondas de UX, nesta ordem, em `auditorias/2026-10-25/ux/execucao/`:
   - `onda-1-conferir-em-aparelho.md`
   - `onda-2-conferir-em-aparelho.md`
   - `onda-3-conferir-em-aparelho.md`
2. **Motor 2.0:**
   - Laboratório 2.0 no Safari (M07): o interruptor Motor, o selo de cada resposta e a folha "Por que esta resposta
     custou isso";
   - Lado a lado (M08): duas respostas e "Prefiro esta";
   - aba Motor 2.0 a 390 px (M13).
3. **Teto (M12), só admin:**
   - grave o teto em 0,20 e converse com uma conta de teste até passar dele;
   - confira a frase no app, o aviso no aparelho da equipe e o cartão (link "Ficha 1");
   - mande uma mensagem de risco e confira que a resposta vem com os contatos;
   - **volte o teto a 1,00**.

## Ainda com o dono (não travam a subida)

- **Letícia:** aprovar a frase do teto, os textos de sistema do 2.0 e "Ficha n".
- **Antes de pensar em promoção** (que continua travada):
  - pelo menos 3 contas admin marcadas;
  - 150 respostas do 2.0 em 7 dias;
  - o M10 e o M11 feitos.
- **Madrugada da infraestrutura da segurança** (Traefik, n8n e SSH): é separada desta subida, com o roteiro em
  `crystal-em-casa/README.md` › "Revisão de segurança de 24/10".
