# Publicar o login com e-mail + CPF (versão `sha-a860e69`)

Escrito em 11/11/2026. Quem roda é o Luiz, na VPS, como root. Claude não publica nada.

## O que entra

A versão é a **`sha-a860e69`** (branch **`painel/login-cpf`**, commit `a860e695`). Ela é a `sha-92e785f`, que está
no ar desde 10/11, mais duas coisas:

1. **O painel no masculino** (a `sha-28dbd23`, roteiro `publicar-masculino.md`): "o cliente", "os clientes",
   "Clientes ativos". Se a `sha-28dbd23` ainda não subiu, ela vem junto agora.
2. **O login com e-mail + CPF** (pedido do dono de 11/11): "quem tem CPF vem com CPF; os novos usuários têm que vir com
   CPF; os que não têm vêm com código e, quando entrar, cadastra o CPF".

### Como fica o login do cliente

- A tela pede o **e-mail da compra** e, embaixo, o **CPF**.
- **CPF guardado e certo:** entra direto, sem código. O e-mail da conta recebe o aviso de novo acesso.
- **Sem CPF guardado, ou CPF errado:** vem o código por e-mail, como hoje. A tela é igual nos dois casos (ninguém
  descobre o CPF de ninguém).
- **Entrou com o código e ninguém tinha CPF para esse e-mail:** o CPF digitado fica na conta. Da próxima vez, entra
  direto.
- Um CPF que já está guardado nunca é trocado pelo login. Quem digitou errado fala com o suporte, que corrige na
  ficha.
- **Onde o CPF fica guardado:**
  - na conta do app: só a marca cifrada e os 4 últimos dígitos;
  - na base antiga do Supabase: como sempre esteve;
  - nas compras novas: só a marca (`crystal_compras.cpf_marca`).
- **Equipe e conta de revisão das lojas não mudam:** a equipe entra por `/login/equipe`; a revisão, com o código fixo.

### Quem já tem CPF guardado (11/11)

- **Base antiga (até 12/10):** 9.428 de 11.149 cadastros têm CPF e entram direto.
- **Compradores desde 10/10 (775) e os 1.721 da base antiga sem CPF:** entram uma vez com o código. O CPF digitado
  fica cadastrado e, daí em diante, entram direto.
- **Compras novas:** a partir de 11/11, o Supabase guarda a marca do CPF que a Assiny manda, e esses clientes entram
  direto já no primeiro acesso. O fluxo do n8n no ar (de 13/10) manda o corpo inteiro da Assiny, então o CPF deve
  chegar sem mudar nada. Para conferir depois da próxima compra, no SQL do Supabase:
  `select count(*) from crystal_compras where cpf_marca is not null;` tem de passar de 0.

## Banco, variáveis e volta

- **Supabase: já está pronto** (aplicado em 11/11, `crystal-em-casa/supabase/app_login_cpf.sql`). Não há nada a rodar.
- **Banco do app: nenhuma migração nova.**
- **Nenhuma variável nova obrigatória.** O padrão é `LOGIN_CPF=ligado`.
- **Desligar só o CPF**, sem voltar a versão:
  1. `bash bootstrap-vps.sh app-definir LOGIN_CPF` e digitar `desligado`;
  2. `app-subir` com a mesma tag;
  3. o passo da memória.
- **Volta da versão:** `sha-92e785f`, com o passo da memória. Sem volta de banco. As colunas e funções novas do
  Supabase não atrapalham a versão antiga.

## Antes (técnica)

- Portão local rápido verde: tipos, lint e testes de shared, API, web e Crystal.
- CI do `a860e695` e imagens `sha-a860e69`: ver o item 131 do `CONTINUAR-EM-OUTRA-CONTA.md`. Só subir com os dois
  verdes.

## Subir (no terminal da VPS, um por vez)

Horário de pouco movimento. O app fica alguns segundos sem responder enquanto troca.

```bash
cd /root
bash bootstrap-vps.sh app-status          # anote a tag atual: é a volta (hoje, sha-92e785f)
bash bootstrap-vps.sh backup
REF=97b5ad29d2b998163bc31654cbc2c00aa8017d7e bash bootstrap-vps.sh app-subir sha-a860e69
docker service update --limit-cpu 1 --limit-memory 2560M --env-add NODE_OPTIONS=--max-old-space-size=2048 crystal_app_app_crystal
docker service update --limit-memory 2048M --env-add NODE_OPTIONS=--max-old-space-size=1536 crystal_app_app_api
bash bootstrap-vps.sh app-status
```

Os dois `docker service update` são o passo da memória, obrigatório depois de todo `app-subir`. Tem de aparecer os
três serviços em `sha-a860e69`.

## Conferir (10 minutos, no iPhone)

1. **Tela:** saia do app. O login pede "E-mail da compra" e, embaixo, "CPF", com o botão "Entrar".
2. **CPF certo:** com uma conta de teste que tem CPF na base, digite o e-mail e o CPF certos.
   - Tem de entrar direto, sem a tela do código.
   - O e-mail da conta recebe o aviso de novo acesso.
3. **CPF errado:** saia e entre com um CPF errado.
   - Vem a tela do código, igual a antes.
   - Entre com o código.
4. **Sem CPF guardado:** com uma conta sem CPF (por exemplo, uma compra feita depois de 10/10), entre com o e-mail, o
   CPF e o código. Saia e entre de novo com o mesmo CPF: tem de entrar direto.
5. **Painel:** o Início diz "Clientes ativos". A equipe entra por `/login/equipe`, como sempre.
6. Se algo falhar, rode a volta (`sha-92e785f` + passo da memória) ou desligue só o CPF (acima).
