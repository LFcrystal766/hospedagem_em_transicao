# Publicar o painel no masculino (versão `sha-28dbd23`)

Escrito em 10/11/2026. Quem roda é o Luiz, na VPS, como root. Claude não publica nada.

## O que entra

A versão é a **`sha-28dbd23`** (branch **`painel/masculino`**, commit `28dbd23c`): é a `sha-92e785f`, que está no ar
desde 10/11, mais só a troca de texto. Nada mais muda.

- O painel fala do cliente no masculino: "o cliente", "os clientes", "do cliente", "Clientes ativos",
  "Cliente removido", "Todos os clientes ativos". Quando "ela" ou "dela" era o cliente, agora é "ele" ou "dele".
- Continua no feminino o que é da Crystal ("ela"), da pessoa da equipe ("a pessoa… ela"), da conta ("contas de
  cliente ativas") e da lista.
- O e-mail de risco para a equipe também mudou ("Entre em contato com o cliente agora para saber se ele está bem").
- O guia da equipe (`docs/equipe.md`) foi junto.
- **Não muda:** a alma da Crystal, as telas do cliente, o banco, as rotas e as configurações.

## Banco, variáveis e volta

- **Nenhuma migração nova.** Nenhuma variável nova.
- **Volta:** `sha-92e785f`, com o passo da memória. Sem volta de banco.

## Antes (técnica)

- **CI do `28dbd23c` inteiro verde** (run 42875276332): gate, audit, e2e do login só com e-mail e e2e completo
  (Chromium e WebKit, 361 passaram).
  - Um teste ficou instável e passou na segunda tentativa: `onda6-banners` "sem banner". A primeira abertura da tela
    de início foi interrompida (`page.goto` ERR_ABORTED).
  - Não tem ligação com esta troca: nessa tela só mudaram comentários. Aqui ele passou 10 de 10.
- **Imagens `sha-28dbd23` prontas** (run 42875348214: API, web e Crystal).
- Portão local: rápido verde (tipos, lint e testes de shared, API, web e Crystal); e2e das 23 specs mexidas com 255
  passaram; login só com e-mail com 11 de 11.
- Guarda nova no CI: o teste reprova "a cliente", "das clientes", "clientes ativas" etc. em qualquer frase do painel.

## Subir (no terminal da VPS, um por vez)

Horário de pouco movimento. O app fica alguns segundos sem responder enquanto troca.

```bash
cd /root
bash bootstrap-vps.sh app-status          # tem de mostrar sha-92e785f: é a volta
bash bootstrap-vps.sh backup
REF=97b5ad29d2b998163bc31654cbc2c00aa8017d7e bash bootstrap-vps.sh app-subir sha-28dbd23
docker service update --limit-cpu 1 --limit-memory 2560M --env-add NODE_OPTIONS=--max-old-space-size=2048 crystal_app_app_crystal
docker service update --limit-memory 2048M --env-add NODE_OPTIONS=--max-old-space-size=1536 crystal_app_app_api
bash bootstrap-vps.sh app-status
```

Os dois `docker service update` são o passo da memória, obrigatório depois de todo `app-subir`. Tem de aparecer os
três serviços em `sha-28dbd23`.

## Conferir (5 minutos, no iPhone ou no computador)

1. **Início do painel:** o cartão diz "Clientes ativos".
2. **Mensagens › Nova mensagem › Público:** a opção diz "Todos os clientes ativos".
3. **Ficha de um cliente de teste › Ações:** o grupo diz "Dados do cliente". Em "Desligar", o texto diz "O cliente
   sai de todos os aparelhos agora…" (feche sem desligar).
4. O app do cliente continua igual (entrar e mandar uma mensagem de teste).
5. Se algo falhar, rode a volta:

```bash
REF=97b5ad29d2b998163bc31654cbc2c00aa8017d7e bash bootstrap-vps.sh app-subir sha-92e785f
docker service update --limit-cpu 1 --limit-memory 2560M --env-add NODE_OPTIONS=--max-old-space-size=2048 crystal_app_app_crystal
docker service update --limit-memory 2048M --env-add NODE_OPTIONS=--max-old-space-size=1536 crystal_app_app_api
```
