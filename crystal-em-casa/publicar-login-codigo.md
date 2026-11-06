# Publicar o Pacote 1 do login (código que chega atrasado no Hotmail e no Outlook)

Escrito em 06/11/2026, a pedido do dono ("pode fazer o pacote 1"). Quem roda é o Luiz, na VPS, como root.
Claude não publica nada.

**Atualizado em 06/11 ~17:30 UTC.**

- A versão a publicar é a **`sha-cd2705a`**, da branch **`painel/dores-login`** do app.
- Ela parte da versão que estava de fato no ar, a **`sha-1db2e16`** (a "Dores", branch `painel/dores-fase-2`).
- Por cima, vêm três commits:
  - o login (`7460351`);
  - o ajuste de dois testes do login (`2172ea9`);
  - a correção do CI vermelho da própria Dores (`cd2705a`): o filtro "Dor" com alvo de 44 px e dois testes da equipe.
- A `sha-d8f6dfc` (login sobre a `20da7ee`) **não deve subir**: ela tira a Dores do ar. Aconteceu às ~16:50 UTC de
  06/11.

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
- **Volta:** `REF=97b5ad29d2b998163bc31654cbc2c00aa8017d7e bash bootstrap-vps.sh app-subir sha-1db2e16` e, de novo, o
  passo da memória (abaixo).
  - Sem volta de banco.
  - Um código pedido na versão nova continua entrando na antiga: o campo novo é só ignorado.

## Antes (técnica)

- CI do `cd2705a` verde: conferir antes de subir.
- Imagens **`sha-cd2705a`** (API, web e Crystal) geradas pelo `imagens-vps`.
- Portão local da `painel/dores-login`:
  - rápido verde;
  - e2e do login (`otp` e `login-email`, nos dois modos) verde;
  - `equipe.spec` e `mobile-audit.spec` com 47 de 47.
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
REF=97b5ad29d2b998163bc31654cbc2c00aa8017d7e bash bootstrap-vps.sh app-subir sha-cd2705a
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

Tem de aparecer os três serviços em `sha-cd2705a`. Os "!" do `crystal-conferir` no `/healthz` são o alarme falso já
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
