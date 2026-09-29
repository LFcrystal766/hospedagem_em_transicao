# O app da Crystal: onde está e quanto falta (29/09/2026)

O app é o `LFcrystal766/crystal-web-chat`, transferido da conta do Igor
(`o-igor-andrade`) em 29/09. O Igor segue como colaborador com escrita. É um
monorepo pnpm: PWA em Next.js 15, BFF em Fastify com Prisma e Redis, pacote de
tipos compartilhados, empacotamento para as lojas (TWA Android e Capacitor iOS).

Esta avaliação foi feita lendo o código e a documentação das três branches. Não
rodei a suíte de testes nesta sessão: os números de teste abaixo são os que o
próprio repositório registra.

## As três branches

| Branch | O que tem | Estado |
|---|---|---|
| `main` | O app em si: 64 commits de 02 a 07/09 | Produto maduro, CI com typecheck, lint, vitest, build e e2e |
| `lfchat/g0-discovery` | LFChat: Chatwoot próprio + Bridge para substituir o LendChat e falar direto com o WhatsApp. Cerca de 200 commits de 16 a 18/09 | **Parado desde 18/09** por ordem do tech lead, "até a migração de DNS terminar" |
| `legacy/mvp-original` | O MVP de 23/08 | Só referência |

`main` e `lfchat/g0-discovery` têm **históricos separados**: a `main` foi achatada
em 07/09 e a outra linha continuou a partir do histórico antigo. Não dá para
fazer merge direto. Antes de retomar, é preciso escolher qual das duas é a base.

## O que o app já faz (`main`)

- Login por CPF + e-mail conferidos na base de clientes, com código de 6 dígitos por e-mail (OTP) como segundo fator
- Chat com a Crystal com resposta em streaming, histórico paginado, rate limit
- Imagem e áudio pelo navegador, PWA instalável, push web e push nativo (FCM e APNs)
- Painel da equipe: suporte, técnico, financeiro manual, alertas de integração
- Modo backup: sonda de saúde da Meta, que liga o app como canal de reserva
- LGPD: consentimento, exportação, exclusão, cifra por campo, retenção
- Onboarding do perfil e sugestões dirigidos pela Crystal (metas, progressos)
- Revisão de segurança de 04/09 com os três achados tratados
- Textos das lojas (listagem, Data Safety, App Privacy, termos) e screenshots

## O que falta para o app atender aluno de verdade

Caminho mais curto: o app como está na `main`, em que o BFF chama a Crystal
direto, sem Chatwoot nem Bridge. Na `main` esse é o único modo; o transporte
`lfchat` só existe na outra branch.

| Falta | Depende de |
|---|---|
| Saber como o agente da agência atende um canal que não é o LendChat | Código do agente no `crystal-ia` ou resposta do Tuan |
| `CRYSTAL_API_URL`: endereço que recebe a mensagem do app e devolve a resposta | Item acima. Pode ser um fluxo no nosso n8n na frente do agente |
| `DIRECTORY_API_URL`: consulta de CPF + e-mail na base de clientes | Saber onde está essa base, provavelmente no Supabase da Crystal |
| Entrada das mensagens proativas em `POST /webhooks/crystal`, assinada | Formato da agência. O webhook `crystal-app` do n8n segura o endereço enquanto isso |
| Conta no Resend e remetente de e-mail para o OTP | Luiz ou Igor |
| Endereço do app e registro DNS cinza apontando para a VPS | Decisão. O D-024 do app previa `app.crystalnowpp.com`, sem `.br`, e foi suspenso pelo D-029 |
| Stack do app na VPS: BFF, PWA, Postgres e Redis próprios, atrás do Traefik | **Pronta em 29/09** (`stacks-app/`, `bootstrap-vps.sh app-*`). Falta rodar na VPS |
| Segredos de produção (`JWT_SECRET`, `ENCRYPTION_KEY`, `CPF_SALT`, `WEBHOOK_SECRET`, VAPID) | **Automático**: o `app-subir` gera na VPS, uma vez só |
| Apps nas lojas | Contas Apple e Google, chaves de push nativo. Pode ficar para depois da PWA |

### Achados ao montar a stack (29/09)

- Os Dockerfiles da `main` não construíam: a API rodava `prisma generate`
  antes de copiar o schema, e o web não tinha o `tsconfig.base.json` nem o
  `package.json` da raiz. Corrigido na branch `claude/gracious-shannon-6x9l5j`
  do app, junto com o workflow `imagens-vps`. Falta levar para a `main`.
- O `docker-compose.prod.yml` do app monta os uploads em `/app/uploads`, mas a
  API grava em `apps/api/uploads` porque roda de dentro do pacote. A stack da
  VPS fixa `UPLOAD_DIR=/app/uploads`.
- O CI da `main` (`ci.yml`) está vermelho desde 07/09, nas três execuções, e
  nenhum teste chega a rodar: o `setup-node` pede cache do pnpm antes de o
  pnpm existir no runner ("Unable to locate executable file: pnpm"). Falta um
  passo `pnpm/action-setup` antes dele.
- A sonda da Meta usa a Graph API v21.0, que deve expirar por volta de
  outubro de 2026.

## LFChat: por que não retomar agora

- O plano da agência mantém o LendChat e o corte é reapontar o webhook dele. O
  LFChat troca o LendChat por um Chatwoot próprio. São dois planos para a mesma
  peça, e só um deles tem o código do agente por trás.
- O agente da agência fala o formato do LendChat. O LFChat espera que a Crystal
  fale o contrato da Bridge (`POST /v1/turns` assinado, com callback). Ninguém
  combinou isso com a agência.
- Nunca rodou com Chatwoot real nem com a Crystal real. A WABA tem zero
  templates. Nenhum artefato do fornecedor chegou (`ARTIFACTS.md`).
- Na pausa havia 3 achados críticos e 2 altos abertos na exclusão e exportação
  de dados do titular (L-286, L-287). As rodadas de revisão reabriam críticos a
  cada entrega.
- O roteiro previa produção em 20/10, condicionado ao material do fornecedor
  até 25/09. O material não veio, então essa data já não vale.

Recomendação: terminar a fase 2 da agência, colocar o app no ar no modo simples
como canal de reserva, e só então decidir se o LFChat volta, já com o código do
agente em mãos.

## Estimativa

| Frente | Estado | Quanto falta |
|---|---|---|
| Base na VPS (fase 1) | Pronta e conferida | Nada |
| Agente na VPS (fase 2) | Não começou. `crystal-ia` vazio | 1 a 2 semanas depois que o código chegar |
| App no modo simples | Código pronto | Cerca de 1 semana de trabalho depois de saber o formato do agente. Dá para adiantar a stack na VPS antes |
| LFChat | Parado, com críticos abertos | Várias semanas, se retomado |
