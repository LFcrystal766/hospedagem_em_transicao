# Publicar: /reset limpa a tela + formulário depois da compra (19/11/2026)

- **Versão:** branch `painel/reset-poscompra`, commit `6180988b752dc82f687d8777f49c6ddf5f74612f`, tag `sha-6180988`.
- **Base:** `sha-2e2e745` (no ar desde 15/11), mais dois pedidos do dono de 19/11.
- **Junto, se o dono quiser (recomendado):**
  - `marketing@leticiafelisberto.com` como superadmin;
  - fechar a entrada por CPF (revisão de segurança de 16/11, item 2).

## O que muda

### /reset limpa a conversa na tela do cliente

- **Quando dá certo:** o cliente digita `#reset` (ou `/reset`), ou usa "Recomeçar a conversa" no menu. A tela fica só
  com a mensagem de recomeço; o que ele mandar logo depois continua.
- **Ao recarregar:** a conversa abre limpa.
- **Limite do dia ou falha:** nada some da tela.
- **Pelo botão da ficha (equipe):** a tela do cliente aparece limpa na próxima vez que ele abrir o app.
- **Nada é apagado do banco:** a ficha, os Dossiês, o arquivo de conversas e a exportação de dados continuam vendo tudo.
- **Textos novos:**
  - no app: "As mensagens antigas saem da tela.";
  - na ficha: "A tela do cliente fica só com a mensagem de recomeço; aqui na ficha a conversa continua."

### Formulário depois da compra

- **Onde fica:** Configurações › grupo Produto, abaixo de "Texto do aviso".
  - **"Formulário depois da compra":** interruptor **desligado de fábrica**. Ligar pede LIGAR e o código.
  - **"Mensagem do formulário":** até 500 caracteres. Vem com o texto do dono e o link `https://forms.gle/SD9tjGTEXpsjhX7S6`.
  - **"Horas depois da compra":** de 1 a 72; padrão 2.
- **Quem recebe:** a cada 10 minutos, o app procura as compras ativas dos últimos 7 dias que já passaram das horas
  configuradas. A Crystal manda a mensagem no chat do app, **uma vez por conta**.
  - Quem ainda não entrou no app recebe quando entrar, se for dentro dos 7 dias.
  - Cliente antigo que comprou de novo também recebe, uma vez.
  - Conta desligada, de equipe ou de revisão não recebe.
- **O link vira um botão "Abrir o formulário".** O chat não deixa endereço clicável no texto da Crystal. O texto
  aparece como foi escrito e o primeiro link vira o botão.
- **A Crystal fica sabendo que mandou:** se o cliente responder "respondi", ela entende. É o mesmo caminho das
  mensagens da equipe.
- **Notificação no celular:** vai também, como numa resposta da Crystal, e não respeita o horário de silêncio. Uma
  compra às 23h gera mensagem à 1h. Dá para mudar, se o dono quiser.

**Antes de ligar:**

1. **Escolher o link certo.** O dono mandou dois: `…SD9tjGTEXpsjhX7S6`, que está dentro da mensagem e é o padrão, e
   `…qxwcYC9vhESFkeb58`. Se o certo for o segundo, trocar no texto e salvar.
2. **Saber que, ao ligar, quem comprou nos últimos 7 dias recebe de uma vez**, em até 10 minutos. Em 19/11 eram 233
   compras na janela. Só recebe quem já tem conta no app.

## Banco

- **Supabase:** a função `app_compras_recentes` já está aplicada desde 19/11 (só leitura, só o servidor do app).
  Arquivo: `crystal-em-casa/supabase/app_compras_recentes.sql`.
- **App:** uma migração nova, só aditiva, aplicada sozinha na subida.
  - `xpc1_01_pos_compra`: coluna `users.pos_compra_enviada_em`.
  - Desiste se a tabela estiver presa (`lock_timeout`).
- **Volta de banco:** não precisa. A versão antiga ignora a coluna nova.

## Antes (técnica)

- **Portão local da junção:**
  - tipos e lint verdes;
  - testes de shared, API e web verdes;
  - Crystal: um teste de velocidade falhou com a máquina carregada e passou sozinho. `apps/crystal` não mudou;
  - e2e do reset, do formulário, da jornada e de erros: 23 de 23.
- **Portão completo local** (o mesmo que o CI, 1,1 h): **pode subir.**
  - Tipos, lint, as quatro suítes (484 + 2.965 testes), build do web, Safari, audit e e2e do e-mail: verdes.
  - E2e inteiro: 457 passaram e 4 falharam, todos em `mobile-audit.spec.ts`:
    - "Conversa" a 1,6 px da curva da pílula com letra grande (o mínimo é 2);
    - `/equipe/mensagens` a 360 px com conteúdo fora da tela (admin, suporte e técnico).
  - **As mesmas 4 falham na versão no ar** (`sha-2e2e745`): a spec rodou nas duas, com o mesmo resultado (24 passaram
    e 4 falharam). Não é da versão nova. Ficam para uma correção à parte.
- **GitHub Actions bloqueado em 19/11:** o CI e o build das imagens falham em 1 segundo, sem log. É o mesmo sintoma
  do bloqueio de cobrança de 28/10.
  - **Caminho A:** o dono resolve a cobrança no GitHub (Settings › Billing and plans) e o Claude dispara as imagens.
  - **Caminho B:** monta as imagens na VPS (abaixo).

## Imagens

**Caminho A (GitHub de volta):** o Claude dispara `imagens-vps` e avisa quando `sha-6180988` estiver pronta. Na VPS, só a
subida.

**Caminho B (sem o GitHub):** na VPS, uma vez:

```bash
cd /root
bash bootstrap-vps.sh app-construir painel/reset-poscompra 6180988b752dc82f687d8777f49c6ddf5f74612f
```

- **Tentado de novo pelo GitHub em 20/11 (~12:48 UTC):** os 3 trabalhos falharam em 1 segundo, sem log
  (run 44738769365). O motivo aparece na página do run, no GitHub.
- **Pede um token do GitHub só de leitura.** Para criar: github.com › Settings › Developer settings › Personal access
  tokens › Fine-grained tokens › Generate new token:
  - Repository access: Only select repositories › `crystal-web-chat`;
  - Permissions › Contents: Read-only;
  - Expiration: 7 dias.
  - O script não mostra o token na tela nem o guarda. Depois de montar, apagar o token no GitHub.
- **Leva de 15 a 30 minutos e pesa na CPU** (o build do web). Melhor num horário de pouco movimento.
- **No fim deve mostrar** "código em 6180988 (tag sha-6180988)", as 3 imagens e "imagens prontas nesta VPS".
- **Depois, antes de subir:** `bash bootstrap-vps.sh backup`, como o próprio script sugere.
- **O `app-subir` aceita imagem montada na VPS** (rótulo `crystal.construida-na-vps`). Foi o mesmo caminho dos Dossiês
  da outra sessão.
- Anotar no diário que foi montada na VPS.

## Subir (no terminal da VPS, um por vez)

Horário de pouco movimento. O app fica alguns segundos sem responder enquanto troca.

```bash
cd /root
bash bootstrap-vps.sh app-status          # anote as tags atuais: são a volta (deve ser sha-2e2e745)
```

**1. Superadmin (opcional, pedido de 19/11).** A pessoa precisa ter conta de administrador no painel.

```bash
docker exec $(docker ps -qf name=crystal_app_app_postgres | head -1) psql -U crystal -d crystal_web_chat -c "select role, status from users where lower(email) = 'marketing@leticiafelisberto.com';"
grep '^SUPERADMIN_EMAILS=' /root/crystal/app/.externos
bash bootstrap-vps.sh app-definir SUPERADMIN_EMAILS
```

- **Na primeira linha tem de aparecer `admin | active`.** Sem linha, ou com outro papel: no painel, em Equipe,
  incluir ou promover a pessoa a administrador antes.
- **No `app-definir`, digite a lista inteira:** o que o `grep` mostrou, uma vírgula e
  `marketing@leticiafelisberto.com`. O valor novo substitui o antigo; se esquecer o e-mail atual, ele perde o acesso.

**2. Fechar a entrada por CPF (recomendado, revisão de 16/11).**

```bash
cp -p /root/crystal/app/.externos /root/crystal/app/.externos.antes-1119
sed -i '/^LOGIN_CPF=/d' /root/crystal/app/.externos && echo 'LOGIN_CPF=desligado' >> /root/crystal/app/.externos
```

**3. Subir a versão e o passo da memória.**

```bash
REF=97b5ad29d2b998163bc31654cbc2c00aa8017d7e bash bootstrap-vps.sh app-subir sha-6180988
docker service update --limit-cpu 1 --limit-memory 2560M --env-add NODE_OPTIONS=--max-old-space-size=2048 crystal_app_app_crystal
docker service update --limit-memory 2048M --env-add NODE_OPTIONS=--max-old-space-size=1536 crystal_app_app_api
bash bootstrap-vps.sh app-status
curl -s https://api.crystalnowpp.com.br/auth/modo
```

- **Certo:** os três serviços em `sha-6180988`, HTTPS ok e, se fez o passo 2, `"cpf":false` na última linha.

## Conferir depois (no celular)

1. **Login:** entrar com e-mail e senha, como hoje.
2. **/reset:** no chat, mandar `#reset`. A tela fica só com a mensagem de recomeço; recarregar abre limpa.
3. **Formulário:** no painel, em Configurações › Produto, aparecem os três campos novos e o interruptor desligado.
4. **Superadmin:** `marketing@` entra no painel e consegue editar a área da Crystal.

## Volta

- **Versão:** `REF=97b5ad2… bash bootstrap-vps.sh app-subir sha-2e2e745`, mais o passo da memória.
  - Se as imagens antigas forem as montadas na VPS: `docker service update --no-resolve-image --image …`.
  - Sem volta de banco.
- **Só o formulário:** desligar "Formulário depois da compra" no painel. Nada mais sai.
- **Entrada por CPF:** `cp -p /root/crystal/app/.externos.antes-1119 /root/crystal/app/.externos` e subir de novo.
