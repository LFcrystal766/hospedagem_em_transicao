# Próximos passos — atualizado em 28/09/2026

Tudo que dá pra fazer por API é da sessão do Claude. Abaixo, só o que depende
de você, na ordem, com o tempo estimado.

## Agora (uns 15 minutos)

1. **Cloudflare, 5 min.**
   - Apague o token antigo que vazou: Manage Account > Account API Tokens >
     id `856e07e65b984fe5ffb01451bfa3e49e` > Delete.
   - Ligue o 2FA: My Profile > Authentication.
2. **Variáveis do ambiente, 5 min.** Em claude.ai/code, no menu do ambiente
   deste repositório, clique em Edit e cole:
   - `CLOUDFLARE_API_TOKEN` = valor do token `claude-crystal-migracao`
   - `CLOUDFLARE_ACCOUNT_ID` = `a938d629ec1d8ac1f21e77e8723ac514`
3. **Sessão nova, 2 min.** Abra uma sessão nova deste repositório e escreva
   "segue o CLAUDE.md". Na primeira chamada ao Cloudflare, aprove. Para não
   ser perguntado de novo, libere em /permissions a regra
   `Bash(scripts/cloudflare-degrau2.sh:*)`.
4. **Registro.br: fica em aberto por decisão do dono (28/09).** Não bloqueia o
   degrau 2. Precisa ser resolvido antes de cancelar a AZAN: o e-mail do
   contato LFMPI73 ainda é admin@leticiafelisberto.com.

## Quando puder (uns 10 minutos)

5. **Mais três credenciais no ambiente**, do mesmo jeito do passo 2:
   - cPanel da AZAN > Segurança > Gerenciar tokens da API > `claude-migracao`,
     90 dias: `CPANEL_AZAN_HOST=jupiter.servidor.net.br`, `CPANEL_AZAN_USER`,
     `CPANEL_AZAN_TOKEN`
   - Stape > Account settings > API Keys > `claude-migracao-leitura`:
     `STAPE_ACCOUNT_API_KEY`
   - wp-admin > Usuários > Perfil (admin) > Senhas de aplicativo >
     `claude-migracao`: `WP_APP_USER=admin`, `WP_APP_PASSWORD`. Troque também
     a senha do admin
6. **MacBook**, quando ligar: enviar para o GitHub as pastas
   `hospedagem-crystal-dns` e `crystal-web-chat`.

## Decisões suas

7. **Resposta da AZAN ao chamado #RAI-374885**: encaminhe para a sessão.
8. **Data do degrau 2**: uma madrugada, às 02:00, depois da resposta da AZAN.
9. **TikTok**: terminar o que falta antes da linha de base, ou congelar até a
   migração acabar.
10. **Aviso ao time**, 48h antes do degrau 2. Texto pronto em
    `pedidos/aviso-time-degrau2.md`.

## Frente paralela: a VPS da Crystal (o app)

Independe dos degraus do site. Detalhes em `crystal-em-casa/README.md`.

11. **VPS contratada em 28/09**: Hostinger KVM 4, Ubuntu 24.04, Boston, IP
    `177.7.61.136`. Falta tudo o que vem depois.
12. **DNS dos três nomes: feito em 29/09** (`painel`, `editor`, `webhook` →
    `177.7.61.136`, cinza, pelo painel). Conferido de fora: os três respondem
    o IP da VPS. Reconferir a qualquer hora com
    `scripts/cloudflare-crystal-vps-dns.sh conferir`.
13. **Três respostas da agência** antes de contratar o Supabase: compute size
    do projeto da Crystal, dono da conta OpenRouter, quem monta a fase 1.
14. **Docker, Swarm e as stacks: feito em 29/09.** Traefik, Portainer, Postgres,
    Redis e os três serviços do n8n em 1/1, HTTPS válido nos três nomes, admin
    do Portainer e dono do n8n criados. Detalhe que custou uma hora: o Docker 29
    recusa a API 1.24 do Traefik v2 da agência; `bootstrap-vps.sh docker-api`
    baixa o piso do daemon. Segredos trocados depois de vazarem no chat.
15. **Contas**: Supabase Pro + convite Owner para `agencia@academialendaria.ai`,
    GitHub (repo privado, e-mail, token `write:packages`), Netlify, Telegram.
16. **Avisar a agência** quando os 16 pontos de "Base pronta" do guia estiverem
    verdadeiros. A fase 2 (código, transferência do Supabase, imagem, corte) é deles.

## O que a sessão do Claude faz sozinha depois do passo 3

- Foto completa da zona e preparação das configurações, ainda com tudo cinza.
  Não muda nada para o visitante.
- Conferência do certificado de borda e da regra "server. sempre cinza".
- Na madrugada combinada: laranja, validação pela borda, Always HTTPS, bloqueio
  do xmlrpc, rewrite do /crystal-teste. Rollback em segundos se algo sair do padrão.
- Com as credenciais do passo 5: backup da AZAN, zona real, caixas de e-mail,
  prova venda a venda pelo Stape, e a cópia na Hostinger.

## PRD de Otimização: squad em paralelo (03/10)

O Luiz pediu para pôr o "PRD de Otimização Crystal" (26 itens, 3 etapas) para rodar
com vários terminais e deu autorização total. Análise do PRD e desenho do squad em
`crystal-em-casa/squad-otimizacao.md`; relatório de cada integração em
`crystal-web-chat/docs/otimizacao/andamento.md`.

Situação em 03/10, fim do dia (branches do `crystal-web-chat`):

| Etapa | Branch | Commit | Testes | Estado |
|---|---|---|---|---|
| 1 (8 itens + blindagem) | `otimizacao/etapa-1` → build `claude/gracious-shannon-6x9l5j` | `79ba6b7` | 944 + e2e 20/20, CI verde | Imagens `sha-79ba6b7` prontas. **Falta publicar** (portão 1) |
| 2 (11 itens) | `otimizacao/etapa-2` | `3b06150` | 1113 + e2e 27/27 | Integrada; migrações `e2_14…e2_18`, fontes locais. Imagem `sha-69ef26c`. Publica depois do portão 1 |
| 3 (7 itens) | `otimizacao/etapa-3` | `ede085b` | 1224 + e2e 33/33 | Integrada; contém a 2. Zero conflitos. Fase 3 do P12 ligada, com chave de desligar |

Custo das 10 sessões de código: cerca de US$ 200. **As três etapas publicadas em 05/10**: etapa 1 (`sha-79ba6b7`), etapas 2+3 num release só (`sha-da617ac`) e os ajustes pós-QA (`sha-8ed9ce8`, versão atual). QA no iPhone aprovado nas três etapas, segurar para gravar incluído. Faltam o QA em Android e o teste do reembolso com o JSON da Assiny.

Ordem de publicação combinada (roteiro completo, com as listas de conferência em
aparelho, em `crystal-em-casa/publicar-prd.md`), cada passo com `backup` antes:

1. **Portão 1**: `app-definir REFUND_WEBHOOK_SECRET` e `TRANSCRIPTION_API_KEY` (Groq),
   `backup`, `app-subir sha-79ba6b7`. Testar áudio (transcrição), foto e reembolso.
2. **Etapa 2** como um só release: merge de `otimizacao/etapa-2` na branch de build, imagem
   nova, `app-subir`. Antes, garantir que `CRYSTAL_ONBOARDING_URL` não está no `.externos`.
3. **Etapa 3** idem. QA em aparelho da fase 3 do P12 (segurar para gravar) decide se ela
   fica: `SEGURAR_PARA_GRAVAR = false` em `Composer.tsx` desliga numa linha.

Pendências do Luiz para o squad (lista completa em `andamento.md`):

- Exemplo de JSON do webhook de reembolso da **Assiny** (mascarado), para fechar o Q07.
- Chave do **Groq** (`TRANSCRIPTION_API_KEY`).
- **Android** com Chrome para os testes.
- Conferir no iPhone, nos dois temas, as cores do WhatsApp (P16), o papel de parede (P08)
  e `statusBarStyle`; textos "0:07" do gravador; nomes "Tema"/"Sistema".
- Decisões: excluir contato no Chatwoot junto com a conversa do WhatsApp; encaminhar erro
  da Crystal em turno de risco; reembolso quando só o e-mail bate.

## Revisão geral do código (02/10)

Pedida pelo Luiz em 02/10 e feita no mesmo dia: ~48 mil linhas lidas por seis
revisores, 770 testes + 20 e2e verdes, smoke real contra o Postgres. Consolidado em
`auditorias/2026-10-02/revisao-geral/00-RELATORIO.md`. Resultado: 0 críticos, 13
altos reais (3 não procederam, 2 já mitigados), 71 médios. Decisões pendentes do
Luiz: DPO, enquadramento da cópia anônima, quando migrar para Docker secrets, quem
atende no Chatwoot. Ordem de correção em três rodadas está no relatório.

## Nosso Chatwoot no lugar do LendChat (02/10)

Decisão do Luiz: o LendChat vai sair. O app vai para o nosso Chatwoot
(`atendimento.crystalnowpp.com.br`), com a nossa Crystal como robô e a equipe
podendo assumir a conversa. Passo a passo em `crystal-em-casa/README.md`, seção
"Ligar o nosso Chatwoot":

1. DNS `atendimento.` cinza no Cloudflare.
2. `atendimento-subir`, `atendimento-segredos` (Bitwarden), `atendimento-configurar TAG`
   (o teste no fim tem que mostrar a resposta da Crystal), 2FA no primeiro login.
3. `app-canal chatwoot` e conversa de teste no app; conferir que ela aparece no Chatwoot.

Depois, sem pressa:
- WhatsApp no nosso Chatwoot: precisa de quem controla o app da Meta e a BM do
  número, um número de teste antes e o corte combinado com a agência (reversível).
- Atendentes da equipe: convidar pelo Chatwoot (Configurações > Agentes), cada um
  com 2FA.
- Exclusão de conta também apagar o contato no Chatwoot (hoje a memória da Crystal
  é apagada; a conversa fica no nosso Chatwoot, não mais num terceiro).

## Esperando o Tuan (agência), em 02/10

Decisão do Luiz em 02/10: a "alma" da Crystal do app espera o material da
agência. Nada de improvisar método ou base de conhecimento até lá.

1. **Prompt completo** do agente em produção (texto de instruções). Vai para
   `crystal-web-chat/apps/crystal/prompt/crystal.md` e tira o RASCUNHO.
2. **Base de conhecimento** (aulas e materiais da Letícia) e onde está guardada.
   Se estiver no Supabase a transferir, quais tabelas. Vai para
   `apps/crystal/conhecimento/` (até 60 mil caracteres; acima disso, busca por trechos).
3. ~~Conserto do LendChat~~: consertado em 02/10 (conferido daqui), mas o app
   não volta para lá: o LendChat vai sair. Pedir ao Tuan para apagar o contato
   de teste `diagnostico-crystal-app-3`.
4. **Transferência do Supabase** (base de alunos e, talvez, a base de conhecimento).
5. **Código do agente** no repositório `crystal-ia`, ainda vazio.

Pronto para quando decidirem: a Crystal do app usar o perfil, as metas e o
progresso da aluna (com consentimento de dados sensíveis) nas respostas.
