# Publicar a versão `sha-2e2e745` (Dossiês + login com senha)

Escrito em 15/11/2026. Quem roda é o Luiz, na VPS, como root. Claude não publica nada.

## Por que esta versão existe

Em 15/11 o dono pediu para conferir se a imagem `sha-8562647` (login com senha) estava de acordo com a última
atualização, sem perder design nem funcionalidade.

### O que a conferência achou

1. **Tudo o que já esteve no ar está dentro da `sha-8562647`.** Nada se perde em relação ao que está no ar hoje. Isso
   vale para qualquer uma destas versões:
   - as 3 tags antigas da outra sessão (API `sha-b5eb55c`, Crystal `sha-b3d02f1`, web `sha-44f4dcd`);
   - a integrada `sha-8c4510c`;
   - a `sha-8ed06f8`;
   - e todas as anteriores, de `sha-20da7ee` em diante.
2. **Outra sessão fez trabalho novo em 13 e 14/11, a partir da mesma base (`8c4510c`):**
   - branch `painel/dossies`: a seção **Dossiês** do painel (K03 a K08);
   - branch `painel/arquivo-conversas`: o **arquivo de conversas antigas do WhatsApp** (K09);
   - branch `painel/dossies-aviso-desativado`: o **recado de desativado**.
3. **Esse trabalho nunca subiu:** não havia imagem dele.
4. **As duas versões se completavam, mas cada uma tinha um buraco:**
   - a `sha-8562647` não tinha os Dossiês;
   - a branch dos Dossiês não tinha a senha.

   Subir qualquer uma das duas sozinha deixaria a outra parte de fora.

A **`sha-2e2e745`** (branch **`painel/dossies-senha`**, commit `2e2e745f`) junta as duas. Ela substitui a
`sha-8562647`.

## O que entra

1. **Tudo da `sha-8562647`** (ver `publicar-login-senha.md`):
   - login do cliente com e-mail + senha;
   - "Primeiro acesso: criar senha", "Esqueci a senha" e "Entrar com código por e-mail";
   - mídia, visualização única, suporte Rafa, painel no masculino e o resto da integrada.
2. **Dossiês, no painel da equipe:**
   - busca, filtros e cartões;
   - página do dossiê de cada cliente, com disparos e eventos;
   - aba Panorama, com rankings e insights da semana.
3. **Arquivo de conversas antigas do WhatsApp:** a conversa antiga aparece na página do dossiê, e a exclusão segue a
   LGPD.
4. **Dossiês desligados de fábrica** (`op_dossie` desligado):
   - a seção mostra "Os dossiês estão desativados no momento. A estrutura está pronta e funcionando: para ativar, é só
     pedir ao Claude.";
   - desligados, não gastam tokens;
   - o importador do arquivo antigo (`arquivo:importar`) é um comando à mão: não roda sozinho.

## Banco, variáveis e volta

- **Duas migrações novas, só de criação.** Nenhuma muda ou apaga o que existe. O `app-subir` aplica as duas.
  - `wdc1_01_dossies`: 8 tabelas dos dossiês e os índices;
  - `wdc2_01_conversa_arquivo`: 3 tabelas do arquivo de conversas.
- **Nenhuma variável nova obrigatória.** A única nova é a `LOGIN_SENHA` (padrão ligado), da senha. Para desligar só a
  senha, ver `publicar-login-senha.md`.
- **Volta da versão:** `sha-8c4510c`, com o passo da memória. As tabelas novas ficam no banco, vazias e sem uso, e não
  atrapalham a versão anterior.

## Antes (técnica)

- **Junção** de `painel/login-senha` (`8562647f`) com `painel/dossies-aviso-desativado` (`bcfca1f1`): sem conflito.
  - Os dois lados mexeram em `auth.ts`, `microcopy.ts` e nos ajudantes de teste.
  - O lado dos Dossiês só tira o telefone antigo do dossiê quando o número muda. Não toca na senha.
- **Portão local verde:**
  - tipos (shared, API, web, Crystal) e lint;
  - testes: shared 478, Crystal 1.290, web 2.958, API 2.731.
- **CI da branch dos Dossiês sozinha** (run 43655268860): gate, audit e e2e do login verdes. O e2e completo teve 480
  passaram e as mesmas 18 falhas de mídia/`mobile-audit` de antes, mais 1 teste que passou na segunda tentativa.
- **CI do `2e2e745f`** e imagens `sha-2e2e745`: disparados em 15/11. O resultado fica no `CONTINUAR-EM-OUTRA-CONTA.md`
  (item 145). **Só subir depois de o CONTINUAR dizer PODE SUBIR.**

## Subir (no terminal da VPS, um por vez)

Horário de pouco movimento. O app fica alguns segundos sem responder enquanto troca.

```bash
cd /root
bash bootstrap-vps.sh app-status          # anote as tags atuais: são a volta
bash bootstrap-vps.sh backup
REF=97b5ad29d2b998163bc31654cbc2c00aa8017d7e bash bootstrap-vps.sh app-subir sha-2e2e745
docker service update --limit-cpu 1 --limit-memory 2560M --env-add NODE_OPTIONS=--max-old-space-size=2048 crystal_app_app_crystal
docker service update --limit-memory 2048M --env-add NODE_OPTIONS=--max-old-space-size=1536 crystal_app_app_api
bash bootstrap-vps.sh app-status
```

Os dois `docker service update` são o passo da memória, obrigatório depois de todo `app-subir`. Os três serviços têm
de aparecer em `sha-2e2e745`.

## Conferir (15 minutos, no iPhone)

1. **Login com senha:** os passos 1 a 7 de `publicar-login-senha.md`:
   - primeiro acesso → criar senha;
   - entrar com a senha;
   - senha errada;
   - esqueci a senha;
   - código por e-mail;
   - equipe.
2. **Dossiês:** no painel, abra a seção Dossiês. Tem de aparecer o recado "Os dossiês estão desativados no momento…".
3. **O resto:**
   - "Fale com Rafa, do nosso suporte." no menu ⋮ › Suporte;
   - Mensagens › Nova mensagem com os três cartões e o anexo;
   - a notificação abre a conversa;
   - o painel diz "o cliente".
4. Se algo falhar: volte a versão (abaixo).

## Volta da versão

```bash
REF=97b5ad29d2b998163bc31654cbc2c00aa8017d7e bash bootstrap-vps.sh app-subir sha-8c4510c
docker service update --limit-cpu 1 --limit-memory 2560M --env-add NODE_OPTIONS=--max-old-space-size=2048 crystal_app_app_crystal
docker service update --limit-memory 2048M --env-add NODE_OPTIONS=--max-old-space-size=1536 crystal_app_app_api
```

Para manter a senha e tirar só os Dossiês, a volta é a `sha-8562647`, com o mesmo passo da memória.
