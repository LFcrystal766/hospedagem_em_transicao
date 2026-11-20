# Publicar: Enquetes de volta + /reset + formulário (20/11/2026)

- **Versão:** branch `painel/enquete-reset`, imagem **`sha-2b645e9`** (commit `2b645e9ec0d3cfc102f97df834b5ce2dcd2cb83a`).
  - O commit seguinte, `280a1d75`, só acerta um teste. O código que roda é o mesmo, então a imagem continua a `sha-2b645e9`.
- **Por que existe:** em 20/11 a `sha-7e9de25` subiu por cima da versão que estava no ar, da branch
  `painel/disparo-sem-codigo` (18/11, outra sessão). Com isso saíram do ar:
  - as Enquetes;
  - enviar e agendar Mensagem sem o código por e-mail (vale a palavra ENVIAR ou AGENDAR);
  - o horário de silêncio pelo horário de Brasília.
- **O que tem:** as duas branches juntas.
  - `7d6dbed0`: Enquetes, envio sem código, silêncio.
  - `7e9de250`: /reset limpa a tela, formulário depois da compra, Next.js 15.5.29 e `effect` 3.22.4.
- **Conflitos da junção:** três, resolvidos mantendo os dois lados:
  - `memory-chat.ts` e `prisma-chat.ts`: o voto da enquete e a lista de mensagens depois do recomeço;
  - `use-chat.test.ts`: os testes das duas branches.

## Banco

- **Nada novo.** As duas migrações já estão aplicadas: `wen1_01_aviso_enquete` (subiu com a `7d6dbed`) e
  `xpc1_01_pos_compra` (subiu com a `7e9de25`).
- **Os dados das enquetes ficaram no banco** enquanto a `7e9de25` estava no ar. Voltam a aparecer com esta versão.

## Antes (técnica)

- **Imagens prontas:** `imagens-vps` run 44751955524 (20/11, 14:21 UTC), com audit, build e push das 3 imagens.
- **CI da junção** (run 44751944846):
  - audit, tipos, lint, testes de shared e e2e do login só com e-mail: verdes;
  - testes da API: 2.796 passaram e 1 falhou, o A9 de `seguranca-autorizacao.test.ts`.
    - **A falha já existia na versão da outra sessão.** O A9 ainda pedia o código ao enviar uma Mensagem com link de
      fora, que o dono tirou em 18/11. O teste foi acertado (`280a1d75`): o link de fora segue só para o admin.
- **Aqui:**
  - os 25 testes de segurança e os 3.001 testes do web passaram;
  - os e2e de enquete (aluno e painel), mensagens, mensagens da onda 4, reset, formulário, login com senha, jornada
    e erros: **42 passaram, 1 pulado, nenhuma falha** (7,5 min). **Pode subir.**

## Subir (no terminal da VPS, um por vez)

**0. Conferir o que está no ar.** Têm de aparecer os três serviços em `sha-7e9de25`. Se aparecer outra tag em
qualquer um deles, **pare** e mande a saída para o Claude:

```bash
cd /root
bash bootstrap-vps.sh app-status
```

**1. Superadmin com a lista inteira.** Em 20/11 a lista ficou só com a `marketing@`. Grave os três e-mails, separados
por vírgula e sem espaço: o da Letícia, o de equipe do Luiz e o da `marketing@`. O e-mail de equipe do Luiz não fica
neste repositório, que é público: está na conversa com o Claude.

```bash
bash bootstrap-vps.sh app-definir SUPERADMIN_EMAILS
grep '^SUPERADMIN_EMAILS=' /root/crystal/app/.externos
```

- Tem de aparecer a linha com os três.

**2. Backup e subida.**

```bash
bash bootstrap-vps.sh backup
REF=97b5ad29d2b998163bc31654cbc2c00aa8017d7e bash bootstrap-vps.sh app-subir sha-2b645e9
```

**3. Passo da memória (sempre, depois de cada `app-subir`).**

```bash
docker service update --limit-cpu 1 --limit-memory 2560M --env-add NODE_OPTIONS=--max-old-space-size=2048 crystal_app_app_crystal
docker service update --limit-memory 2048M --env-add NODE_OPTIONS=--max-old-space-size=1536 crystal_app_app_api
docker service inspect crystal_app_app_crystal crystal_app_app_api --format '{{.Spec.Name}} {{.Spec.TaskTemplate.Resources.Limits.MemoryBytes}}'
```

- **Certo:** `crystal_app_app_crystal 2684354560` e `crystal_app_app_api 2147483648`.

**4. Conferir.**

```bash
bash bootstrap-vps.sh app-status
grep -c '^SUPERADMIN_EMAILS=.*marketing@leticiafelisberto.com' /root/crystal/app/api.env
curl -s https://api.crystalnowpp.com.br/auth/modo
```

- **Certo:**
  - os três serviços em `sha-2b645e9`;
  - `1` no `grep`;
  - `"cpf":false` na última linha.

## Conferir depois (no celular)

1. **Painel › Mensagens:** a seção Enquetes aparece, com as enquetes antigas e o placar.
2. **Mandar uma Mensagem:** pede só a palavra ENVIAR, sem código por e-mail.
3. **App, `#reset`:** a tela fica só com a mensagem de recomeço.
4. **Configurações › Produto:** os campos do formulário depois da compra.

## Volta

- **Para a `sha-7e9de25`** (fica sem as Enquetes): `REF=97b5ad2… bash bootstrap-vps.sh app-subir sha-7e9de25` e o passo
  da memória.
- **Para o que estava antes de 20/11** (fica sem /reset novo e sem o formulário):

  ```bash
  docker service update --with-registry-auth --image ghcr.io/lfcrystal766/crystal-web-chat-api:sha-7d6dbed crystal_app_app_api
  docker service update --with-registry-auth --image ghcr.io/lfcrystal766/crystal-web-chat-web:sha-0856897 crystal_app_app_web
  ```

  Depois, o passo da memória.
- **Sem volta de banco** em nenhum dos dois casos.
