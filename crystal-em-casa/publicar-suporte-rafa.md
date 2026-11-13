# Publicar a versão `sha-25afaf7` (login com CPF opcional + painel no masculino + suporte Rafa)

Escrito em 12/11/2026, revisto em 13/11 (CPF opcional). Quem roda é o Luiz, na VPS, como root. Claude não publica nada.

## O que entra

A versão é a **`sha-25afaf7`** (branch **`painel/suporte-rafa`**, commit `25afaf7f`). Ela é a `sha-92e785f`, que está
no ar desde 10/11, mais três coisas. Ela substitui a `sha-28dbd23`, a `sha-a860e69` e a `sha-8ed06f8`: não é preciso
subir nenhuma delas antes.

**Não suba a `sha-8ed06f8` nem a `sha-a860e69`:** nelas o CPF é obrigatório na tela, e cliente de fora do Brasil não
entra (achado de 13/11, cliente de Portugal).

1. **O painel no masculino** ("o cliente", "Clientes ativos"). Detalhes em `publicar-masculino.md`.
2. **O login com e-mail + CPF.**
   - Quem tem CPF guardado entra sem código.
   - Quem não tem CPF guardado recebe o código uma vez, e o CPF digitado fica na conta.
   - **CPF em branco** (cliente de fora do Brasil) recebe o código por e-mail, como hoje. Dica na tela: "Não tem CPF?
     Deixe em branco: eu mando um código no seu e-mail."
   - Detalhes em `publicar-login-cpf.md`; o Supabase já está pronto.
3. **O suporte passa a ser Rafa** (pedido do dono de 11/11):
   - o app diz "Fale com Rafa, do nosso suporte." e as mensagens prontas do WhatsApp começam com "Oi, Rafa!";
   - os e-mails de aviso (novo acesso, e-mail trocado, código pego pela equipe) dizem "Rafa atende pelo WhatsApp …";
   - o nome vem do painel: Configurações › Contatos › "Nome de quem atende". Trocar ali muda tudo, sem versão nova;
   - os textos não põem "a" nem "o" antes do nome.

## Banco, variáveis e volta

- **Nenhuma migração nova** no banco do app. O Supabase do login com CPF já foi aplicado em 11/11.
- **Nenhuma variável nova obrigatória.** O padrão é `LOGIN_CPF=ligado`.
- **Desligar só o CPF**, sem voltar a versão:
  1. `bash bootstrap-vps.sh app-definir LOGIN_CPF` e digitar `desligado`;
  2. `app-subir` com a mesma tag;
  3. o passo da memória.
- **Volta da versão:** `sha-92e785f`, com o passo da memória. Sem volta de banco.

## Antes (técnica)

- **CI do `25afaf7f`** (run 43440954158) e imagens `sha-25afaf7` disparados em 13/11 ~14:15 UTC. A conferência final
  fica no `CONTINUAR-EM-OUTRA-CONTA.md` (item 136).
- **O commit anterior (`8ed06f8f`) teve CI inteiro verde** (run 43304841756; e2e completo com 362 passaram).
- **Portão local do `25afaf7f`:**
  - rápido verde;
  - formulário com 53 testes e API do CPF com 14;
  - e2e do login: 13 de 13 no modo e-mail com CPF (com o novo "(g) sem CPF") e 11 de 11 no modo antigo.

## Subir (no terminal da VPS, um por vez)

Horário de pouco movimento. O app fica alguns segundos sem responder enquanto troca.

```bash
cd /root
bash bootstrap-vps.sh app-status          # anote a tag atual: é a volta (hoje, sha-92e785f)
bash bootstrap-vps.sh backup
REF=97b5ad29d2b998163bc31654cbc2c00aa8017d7e bash bootstrap-vps.sh app-subir sha-25afaf7
docker service update --limit-cpu 1 --limit-memory 2560M --env-add NODE_OPTIONS=--max-old-space-size=2048 crystal_app_app_crystal
docker service update --limit-memory 2048M --env-add NODE_OPTIONS=--max-old-space-size=1536 crystal_app_app_api
bash bootstrap-vps.sh app-status
```

Os dois `docker service update` são o passo da memória, obrigatório depois de todo `app-subir`. Os três serviços têm de
aparecer em `sha-25afaf7`.

## Conferir (10 minutos, no iPhone)

1. **Painel:** em Configurações › Contatos › "Nome de quem atende", tem de estar `Rafa`. Se estiver `Bia`, troque e salve.
2. **Tela de login:** saia do app. O login pede "E-mail da compra" e, embaixo, "CPF", com o botão "Entrar".
3. **CPF certo:** use uma conta de teste que tenha CPF na base.
   - Tem de entrar direto, sem a tela do código.
   - O e-mail da conta recebe o aviso de novo acesso, com "Rafa atende pelo WhatsApp".
4. **CPF errado:** vem a tela do código, igual a antes.
5. **Suporte:** no menu ⋮ › Suporte, tem de aparecer "Fale com Rafa, do nosso suporte.". "Abrir o WhatsApp" abre com
   "Oi, Rafa! …".
6. **Painel:** o Início diz "Clientes ativos". A equipe entra por `/login/equipe`, como sempre.
7. Se algo falhar, use a volta:

```bash
REF=97b5ad29d2b998163bc31654cbc2c00aa8017d7e bash bootstrap-vps.sh app-subir sha-92e785f
docker service update --limit-cpu 1 --limit-memory 2560M --env-add NODE_OPTIONS=--max-old-space-size=2048 crystal_app_app_crystal
docker service update --limit-memory 2048M --env-add NODE_OPTIONS=--max-old-space-size=1536 crystal_app_app_api
```
