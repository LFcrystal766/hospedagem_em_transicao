# Publicar o Pacote 1 do login (código que chega atrasado no Hotmail e no Outlook)

Escrito em 06/11/2026, a pedido do dono ("pode fazer o pacote 1"). Quem roda é o Luiz, na VPS, como root.
Claude não publica nada.

Branch `painel/login-codigo` do app, em **`d8f6dfc`**. Ela é a versão que está no ar (`sha-20da7ee`, branch
`painel/motor2`) mais dois commits só de login (o código e o ajuste de dois testes de ponta a ponta).

## O que muda para os clientes

1. **"Reenviar código" manda o MESMO código.**
   - Antes, cada reenvio gerava um código novo e matava o anterior. O e-mail atrasado do Hotmail chegava com um
     código que já não entrava.
   - Agora qualquer um dos e-mails serve.
   - As 5 tentativas são por código: reenviar não dá mais chances a quem tenta adivinhar.
2. **O código vem no assunto:** "482913 é o seu código de acesso à Crystal". Aparece na notificação do celular e
   na lista do Hotmail, até na aba "Outros".
3. **O código vale 15 minutos** (antes, 5). O texto do e-mail diz "15 minutos" sozinho.
4. **Na tela do código:**
   - o aviso para Hotmail e Outlook explica que, se reenviar, o código é o mesmo;
   - o "Reenviado!" diz o mesmo;
   - o "Não chegou?" manda procurar por "código de acesso à Crystal".

Vale também para o login da equipe (o código do painel passa a valer 15 minutos e vem no assunto).

## Banco, variáveis e volta

- **Sem migração.** Nada muda no banco do app nem no da Crystal.
- **Sem variável nova.** O padrão de `OTP_TTL_S` passou a ser 900 no código.
  - Se o dono rodou antes o `docker service update --env-add OTP_TTL_S=900`, o `app-subir` tira essa variável.
  - Não faz diferença: o padrão novo já é 900.
- **Volta:** `REF=97b5ad29d2b998163bc31654cbc2c00aa8017d7e bash bootstrap-vps.sh app-subir sha-20da7ee` e, de novo, o
  passo da memória (abaixo).
  - Sem volta de banco.
  - Um código pedido na versão nova continua entrando na antiga: o campo novo é só ignorado.

## Antes (técnica)

- CI do `d8f6dfc` verde. O do `60a2487` pegou dois testes de ponta a ponta do "login só com e-mail" que ainda
  contavam com 5 minutos. Foram ajustados no `d8f6dfc`, sem mudar o app. O portão local agora roda essa
  configuração também (`gate.sh`, etapa `e2e-email`).
- Imagens **`sha-d8f6dfc`** (API, web e Crystal) geradas pelo `imagens-vps`.
- Portão local:
  - rápido verde (tipos, lint, testes da API e do web);
  - e2e `otp` e `login-email` verdes, inclusive no modo "login só com e-mail" (10 de 10);
  - 6 testes novos no reenvio, 5 deles falham no código antigo.

## Subir (no terminal da VPS, um por vez)

Horário de pouco movimento. O app fica alguns segundos sem responder enquanto troca.

```bash
cd /root
bash bootstrap-vps.sh app-status
bash bootstrap-vps.sh backup
REF=97b5ad29d2b998163bc31654cbc2c00aa8017d7e bash bootstrap-vps.sh app-subir sha-d8f6dfc
```

**Logo em seguida, a folga de memória.** É o mesmo passo 4b de `publicar-tudo-motor2.md`, e é obrigatório depois de
todo `app-subir`:

```bash
docker service update --limit-cpu 1 --limit-memory 2560M --env-add NODE_OPTIONS=--max-old-space-size=2048 crystal_app_app_crystal
docker service update --limit-memory 2048M --env-add NODE_OPTIONS=--max-old-space-size=1536 crystal_app_app_api
```

Depois:

```bash
bash bootstrap-vps.sh app-status
bash bootstrap-vps.sh crystal-conferir
```

Tem de aparecer os três serviços em `sha-d8f6dfc`. Os "!" do `crystal-conferir` no `/healthz` são o alarme falso já
conhecido.

## Conferir (5 minutos, no iPhone)

1. Saia do app numa conta de teste com **Hotmail ou Outlook** e peça o código.
2. **O assunto do e-mail começa pelo código.** Na notificação, já dá para ver os 6 números.
3. Na tela do código, espere o "Reenviar código" liberar (1 minuto) e toque nele.
   - Aparece "Reenviado! É o mesmo código…".
4. Quando os dois e-mails chegarem, **os dois têm o mesmo código.** Digite e entre.
5. Se algo falhar, rode a volta.

## Depois de publicar

- Medir de novo, com a consulta por domínio do item 102 do `CONTINUAR-EM-OUTRA-CONTA.md` (quantos entram em até 30
  minutos depois de pedir o código, Microsoft × Gmail).
- O Pacote 2 (código pelo WhatsApp, "Entrar com Microsoft/Google", Face ID) continua só proposto.
- O botão do suporte gerar um código de acesso não foi feito: era opcional e ficou de fora.
