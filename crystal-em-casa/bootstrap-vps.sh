#!/usr/bin/env bash
# Sobe a fundação da Crystal na VPS (Hostinger KVM 4): Traefik, Portainer e o
# n8n em modo fila, a partir dos stacks-exemplo da agência, já com o domínio
# crystalnowpp.com.br e os segredos gerados na própria máquina.
#
# Roda NA VPS, como root. Uso:
#   bash bootstrap-vps.sh preparar SEU_EMAIL   baixa os yaml (commit fixo STACKS_COMMIT, sha256 conferido),
#                                              gera os segredos (uma vez só) e grava os arquivos
#                                              prontos em /root/crystal/stacks
#   bash bootstrap-vps.sh arquivos-hash        NO REPOSITÓRIO, não na VPS: imprime STACKS_COMMIT e a tabela
#                                              ARQ_SHA256 para colar no topo depois de mudar um yaml
#   bash bootstrap-vps.sh docker-api           Docker 29 recusa o Traefik v2 (API 1.24): grava
#                                              min-api-version=1.24 no daemon.json e reinicia o Docker
#   bash bootstrap-vps.sh docker-daemon [--confirmo]
#                                              (24/10, INF-28) o piso acima mais no-new-privileges e log
#                                              json-file 10 MB x 3 por padrão. Sem --confirmo mostra o que
#                                              mudaria; com ele reinicia o Docker (tudo cai por 1 a 2 min)
#   bash bootstrap-vps.sh traefik              sobe 00, espera ficar 1/1, mostra a versão no ar e, com o
#                                              Chatwoot no ar, testa a trava do /super_admin (403 até com /../)
#   bash bootstrap-vps.sh portainer            sobe 01
#   bash bootstrap-vps.sh bancos               sobe 02 e 03 (se o n8n estiver na rede antiga, sobe 04 a 06 junto)
#   bash bootstrap-vps.sh n8n                  sobe 04, 05 e 06
#   bash bootstrap-vps.sh tudo                 os quatro acima, na ordem
#   bash bootstrap-vps.sh status               serviços + HTTPS dos três nomes
#   bash bootstrap-vps.sh redes-conferir       só leitura (24/10, INF-06): em que rede está cada serviço e a prova,
#                                              de dentro dos contêineres, de que um vizinho não alcança o outro
#   bash bootstrap-vps.sh redes-voltar --confirmo
#                                              volta de uma vez: n8n, painel, app e Chatwoot de novo na rede única
#                                              network_swarm_public (o Traefik fica em todas). redes-separar desfaz
#   bash bootstrap-vps.sh segredos             mostra a senha do banco, a chave do n8n e a senha do
#                                              Redis, pra copiar pro cofre (Bitwarden). Não colar em chat
#   O Redis do n8n sobe COM senha (N8N_REDIS_SENHA, gerada no preparar; o original da agência não tem).
#   Trocá-la exige redeploy de 03, 04, 05 e 06: bash bootstrap-vps.sh preparar EMAIL && bash bootstrap-vps.sh bancos && bash bootstrap-vps.sh n8n
#   bash bootstrap-vps.sh backup [--completo]  pg_dump dos bancos (n8n, app, memória da Crystal, Chatwoot)
#                                              e tar incremental dos uploads em /root/crystal/backups
#                                              (14 dias). Parte que falha não para as outras nem o R2;
#                                              no fim, resumo e saída 1. A chave do n8n NÃO vai junto.
#                                              Rodado à mão (no terminal) faz só os bancos, em segundos:
#                                              as fotos e os anexos ficam para o cron das 03:30 (23/10: o
#                                              tar de ~3 GB de fotos travava a VPS). --completo inclui agora
#   bash bootstrap-vps.sh backup-cron          agenda o backup todo dia às 03:30 (hora da VPS)
#   bash bootstrap-vps.sh backup-chave         gera a chave dos backups: a privada aparece só no
#                                              less (vai pro Bitwarden), a pública fica na VPS
#   bash bootstrap-vps.sh backup-fora-config   dados do R2 (segredo sem aparecer), testa e agenda:
#                                              cada backup sobe cifrado para o Cloudflare R2
#   bash bootstrap-vps.sh backup-conferir      lista o que está no R2 e há quanto tempo foi o último
#   bash bootstrap-vps.sh backup-testar-trava  tenta apagar um arquivo de teste no R2: tem que ser recusado
#   bash bootstrap-vps.sh backup-link [TIPO]   link de 10 min para baixar o backup mais novo (teste de
#                                              restauração no Mac). TIPO: n8n_queue (padrão), crystal_web_chat,
#                                              crystal_agente, crystal_uploads, chatwoot, chatwoot_storage
#   bash bootstrap-vps.sh seguranca            atualização de segurança automática, fail2ban no SSH
#                                              e relatório (senha no SSH, root, portas, pendências).
#                                              Com chave de root instalada, trava o SSH em só chave e root
#                                              só com chave; volta sozinha em 10 min sem confirmação
#   bash bootstrap-vps.sh ssh-confirmar        de OUTRA janela, depois de entrar: mantém a trava do SSH
#   bash bootstrap-vps.sh ssh-voltar           tira a trava do SSH (volta a valer o sshd_config)
#   bash bootstrap-vps.sh firewall             ufw: só 22, 80 e 443 de fora. As portas do Swarm
#                                              (2377, 7946, 4789) deixam de ficar públicas
#   bash bootstrap-vps.sh painel-restringir IP [IP ...]
#                                              painel. (Portainer) só para esses IPs; o resto
#                                              leva 403. Agente numa rede interna e imagens
#                                              presas na versão que roda. Sem IP: mostra a lista
#   bash bootstrap-vps.sh painel-desligar      tira o Portainer do ar (painel-ligar volta)
#   bash bootstrap-vps.sh recomecar-n8n EMAIL --confirmo
#                                              só com o n8n SEM fluxo nem credencial (conferido no
#                                              banco): pede APAGAR, copia o banco, apaga e refaz
#                                              com segredos novos
#
# App da Crystal (crystal-web-chat), em app. e api.crystalnowpp.com.br:
#   bash bootstrap-vps.sh app-ghcr             docker login no ghcr.io (token read:packages,
#                                              digitado sem aparecer). As imagens são privadas
#   bash bootstrap-vps.sh app-construir REF [SHA7]  monta as 3 imagens do app NA VPS, sem o GitHub
#                                              Actions (autorizado pelo dono em 21/10, provisorio ate a
#                                              cobranca do GitHub voltar). Pede um token so de leitura
#                                              do codigo, sem aparecer. SHA7 confere o commit
#   bash bootstrap-vps.sh app-resend           pergunta a chave do Resend (sem aparecer) e o
#                                              remetente. Nada vai na linha de comando
#   bash bootstrap-vps.sh app-definir NOME     grava um valor externo (RESEND_API_KEY, EMAIL_FROM,
#                                              CRYSTAL_API_URL, REFUND_WEBHOOK_SECRET, TRANSCRIPTION_*,
#                                              SUPABASE_*, ROLLOUT_GATE, LOGIN_MODO, LOGIN_CODIGO, EQUIPE_EMAIL, RATE_AUTH_*, ...). Confere o
#                                              formato antes de gravar. Sem NOME, lista os aceitos
#                                              ROLLOUT_GATE, LOGIN_CODIGO, REFUND_EVENTS, REFUND_PRODUCT_IDS,
#                                              RATE_AUTH_IP_MAX e TRANSCRIPTION_PRICE_PER_HOUR_USD são só o
#                                              valor padrão; o painel /equipe/operacao sobrepõe ao vivo
#   bash bootstrap-vps.sh app-remover NOME     apaga um valor externo que o app não usa mais
#                                              (ex.: CRYSTAL_ONBOARDING_URL depois da etapa 2)
#   bash bootstrap-vps.sh app-subir TAG        gera segredos (uma vez só), monta api.env, confere o
#                                              api.env no boot da imagem, sobe a stack crystal_app com
#                                              a tag (ex.: sha-398e46e) e falha se o Swarm desfizer a
#                                              troca (rollback), mesmo com a tag igual
#   bash bootstrap-vps.sh app-supabase-teste   chama a função de login do Supabase com dados fictícios
#                                              (só e-mail com LOGIN_MODO=email, o padrão; CPF + e-mail com
#                                              cpf_email): 200 ok, 404 função não existe, 401 chave errada
#   bash bootstrap-vps.sh app-status           serviços do app + HTTPS de app. e api.
#   bash bootstrap-vps.sh app-custo [HORAS]    custo da Crystal no OpenRouter: soma o log de uso
#                                              (tokens e US$ por turno e por resumo, só números),
#                                              projeção mensal e saldo da conta. Padrão: 24 h
#   bash bootstrap-vps.sh fichas-ensaio [N]    piloto das fichas do WhatsApp (10/10): para as N últimas
#                                              fichas prontas (padrão 20), a mesma mensagem respondida
#                                              sem memória, só com as anotações e com a ficha. O texto
#                                              vai SÓ para um arquivo 600 em $BASE (ler com less e apagar)
#   bash bootstrap-vps.sh app-admin            cria o primeiro admin (CPF digitado sem aparecer,
#                                              não fica em spec, log nem histórico)
#   bash bootstrap-vps.sh app-aluno            cria uma conta LOCAL de aluno, que não passa pela base de
#                                              alunas do Supabase (testadores, equipe; CPF opcional, sem
#                                              aparecer, Enter pula; pergunta e-mail, nome e WhatsApp)
#   bash bootstrap-vps.sh vigia-config         liga a vigia do app (a cada 5 min, avisa no Telegram;
#                                              pede o token do bot sem aparecer)
#   bash bootstrap-vps.sh app-segredos         mostra os segredos do app pra copiar pro cofre
#   bash bootstrap-vps.sh ia-encerrar --confirmo
#                                              (24/10, INF-30) depois do corte para o app: tira a Crystal do
#                                              WhatsApp da agência (stack crystal_ia) do ar e apaga o .env dela;
#                                              lista o que revogar fora da VPS
#   bash bootstrap-vps.sh app-telefone EMAIL   grava o WhatsApp de uma conta criada aqui (canal da inbox)
#   bash bootstrap-vps.sh app-db-papel [--confirmo|--voltar]
#                                              TESTAR PRIMEIRO. A API deixa de entrar no Postgres como
#                                              superusuário: papel crystal_api dono do banco do app. Sem
#                                              nada simula (transação desfeita); --confirmo faz e marca;
#                                              depois app-subir TAG. --voltar desfaz a marca (e app-subir)
#   bash bootstrap-vps.sh app-revisao          cria (uma vez) e mostra a conta de revisão das lojas;
#                                              --nova troca CPF e código
#   bash bootstrap-vps.sh crystal-nossa TAG    a NOSSA Crystal (serviço app_crystal, sem endereço
#                                              público): pede a chave do OpenRouter sem aparecer,
#                                              aponta o app para ela e testa. Volta: crystal-provisoria
#   bash bootstrap-vps.sh crystal-nossa-teste  uma pergunta de teste à nossa Crystal
#   bash bootstrap-vps.sh painel-diagnostico [HORAS]  só leitura: reinícios, memória, rotas lentas ou com erro na
#                                              API (sem dado de aluno), volume e índice das mensagens (13/10)
#   bash bootstrap-vps.sh crystal-conferir     confere a corrente inteira, sem mudar nada: serviços, o que o
#                                              painel (Operação) mandou, API -> nossa Crystal -> OpenRouter
#                                              (chave, saldo, modelo e reserva existem e respondem de verdade),
#                                              base de conhecimento, base de alunos e memória única no Supabase
#                                              e o caminho do aluno pelo Chatwoot. Duas perguntas de teste ao
#                                              modelo e uma pela inbox (uns centavos de dólar). --sem-chatwoot pula a inbox
#   bash bootstrap-vps.sh app-api-parar --confirmo
#                                              tira a API do ar (0 réplicas) para a publicação do painel
#                                              novo (onda 4); app-subir TAG volta a 1 réplica
#   bash bootstrap-vps.sh app-auditoria-backfill TAG
#                                              com a API PARADA: aplica as migrações e calcula a cadeia de
#                                              hash da auditoria com a imagem TAG, num serviço temporário.
#                                              Trava contra rodar duas vezes; só contagens na tela
#   bash bootstrap-vps.sh app-painel-conferir  depois de publicar o painel novo: migrate status limpo,
#                                              cadeia da auditoria conferida pelo app, telas e rotas novas
#   bash bootstrap-vps.sh crystal-provisoria   Crystal provisória no n8n com o OpenRouter (pede a
#                                              chave sem aparecer) e o app apontando pra ela
#   bash bootstrap-vps.sh crystal-provisoria-teste      uma pergunta de teste, pela API do app
#   bash bootstrap-vps.sh crystal-provisoria-desligar   volta o app à Crystal simulada
#
# Atendimento (o nosso Chatwoot, no lugar do LendChat), em atendimento.crystalnowpp.com.br:
#   bash bootstrap-vps.sh atendimento-subir    gera segredos (uma vez só) e sobe o Chatwoot
#                                              (DNS atendimento. cinza antes)
#   bash bootstrap-vps.sh atendimento-configurar TAG
#                                              conta, admin (senha no less), inbox do app e a
#                                              Crystal como robô; grava no app e testa
#   bash bootstrap-vps.sh atendimento-teste    mensagem de teste na inbox; a Crystal responde
#   bash bootstrap-vps.sh atendimento-status   serviços + HTTPS de atendimento.
#   bash bootstrap-vps.sh atendimento-segredos mostra os segredos do Chatwoot pra copiar pro cofre
#   bash bootstrap-vps.sh app-canal chatwoot   o app passa a conversar pelo nosso Chatwoot
#                                              (app-canal crystal volta para a Crystal direto)
#   bash bootstrap-vps.sh app-recomecar TAG --confirmo
#                                              só com o banco do app VAZIO (comprovado): pede
#                                              APAGAR, copia bancos e segredos, apaga o banco e
#                                              troca todos os segredos do app (vazaram?)
#
# Publicar a etapa 1 do PRD de Otimização (API sem root, mídia e transcrição, reembolso):
#   curl -fsSL https://raw.githubusercontent.com/LFcrystal766/hospedagem_em_transicao/<commit>/crystal-em-casa/bootstrap-vps.sh -o bootstrap-vps.sh
#   bash bootstrap-vps.sh app-definir REFUND_WEBHOOK_SECRET   gerado com: openssl rand -hex 32 (guardar no Bitwarden)
#   REFUND_EVENTS e REFUND_PRODUCT_IDS (opcionais, vírgulas): eventos da Assiny que cortam o acesso
#                                              (padrão no código) e ids de produto que cortam (vazio = todos)
#   bash bootstrap-vps.sh app-definir TRANSCRIPTION_API_KEY   chave da Groq; URL e modelo já têm padrão no código
#                                              (https://api.groq.com/openai/v1/audio/transcriptions, whisper-large-v3-turbo)
#   CHATWOOT_API_TOKEN: NÃO definir (decisão de 05/10: excluir conta não apaga o contato no Chatwoot)
#   bash bootstrap-vps.sh app-status           anotar a tag atual, para poder voltar
#   bash bootstrap-vps.sh backup               os bancos antes de trocar a imagem (as fotos vão no cron)
#   bash bootstrap-vps.sh app-subir sha-XXXXXXX    a tag nova (ajusta o dono do volume de uploads antes)
#   Volta: bash bootstrap-vps.sh app-subir TAG_ANTERIOR
#   Conferir no OpenRouter que CRYSTAL_MODEL (anthropic/claude-haiku-4.5) e CRYSTAL_MODEL_RESERVA
#   (openai/gpt-4.1-mini) leem imagem (os dois leem). Na Assiny, webhook em
#   https://api.crystalnowpp.com.br/webhooks/reembolso, cabeçalho "Authorization: Bearer <segredo>",
#   eventos de reembolso, chargeback e cancelamento, todos os produtos.
#
# Onde ficam as coisas:
#   /root/crystal/.segredos      senha do banco e chave de criptografia (chmod 600).
#                                NUNCA apagar nem regenerar: a chave do n8n não
#                                pode mudar depois de em uso
#   /root/crystal/stacks/*.yaml  arquivos prontos, com segredo dentro (chmod 600)
#   /root/crystal/originais/     os yaml da agência, sem alteração
#   /root/crystal/.painel-ips    IPs que entram no painel. (um por linha)
#   /root/crystal/app/.segredos  segredos do app (chmod 600). ENCRYPTION_KEY e CPF_SALT
#                                nunca podem mudar: sem eles o banco do app fica ilegível
#   /root/crystal/app/.externos  valores de fora (Resend, Crystal, base de clientes)
#   /root/crystal/app/*.env      o que a API e o Postgres do app leem (regerados a cada subida)
#   /root/crystal/atendimento/   segredos (.segredos, chmod 600) e .env do Chatwoot.
#                                SECRET_KEY_BASE e ACTIVE_RECORD_ENCRYPTION_* nunca mudam
#
# O que ele NÃO faz: não instala Docker, não inicia o Swarm, não cria rede nem
# volumes. Isso já foi feito à mão em 29/09 e o script só confere.

set -euo pipefail

DOMINIO=crystalnowpp.com.br
# Arquivos que o script sobe (stacks e o fluxo do n8n). Na VPS ele roda sozinho, fora do
# repositório, e baixa cada um do GitHub por COMMIT FIXO, só aceitando se o sha256 bater com
# a tabela abaixo (INF-04, 24/10/2026): gravar na branch não muda o que a VPS sobe, e como
# o próprio script é conferido pelo sha256 ao baixar, a tabela vem junto conferida.
# Atualize os dois ao mudar os yamls (ou o fluxo): 1) commit e push dos arquivos novos;
# 2) no repositório, 'bash crystal-em-casa/bootstrap-vps.sh arquivos-hash' imprime o bloco
# com o commit atual; 3) colar aqui e commitar o script. REF=<commit de 40 letras> troca o
# commit (o sha256 continua valendo); branch não é aceita. Rodando de dentro de um clone do
# repositório, usa a cópia local (o git garante a origem) e só avisa se divergir da tabela.
STACKS_COMMIT=91e7971058d91929c93b5421791def4b5ba9ba22
declare -A ARQ_SHA256=(
  [n8n/crystal-provisoria.json]=6ba9a2183c94c4fcff07207e7fc29b9b510907d013a51cffea6d32d84e0d7387
  [stacks-app/01-portainer-restrito.yaml]=d646706f7e52b36d7bdd632ab0096e5bcdb597c3f7ecd5dda0925e230b312639
  [stacks-app/10-crystal-app.yaml]=476867fa6b86b2a36d23258108d4f5b3620f8badb7cf533cb21b0f34569a22e7
  [stacks-app/20-atendimento.yaml]=edf37f34d97d046b7adaaa34468a8a95137a6ce6874321a01f93ad12b06dd58c
  [stacks-exemplo/00-traefik.yaml]=b8bbd7ffd93a69976223f7677ad70600d7188c0bc49b7e64671c7a0381de405d
  [stacks-exemplo/01-portainer.yaml]=a3c3b94eb42cb8f433cf14387cc47cdc060e159baaffa0a9e418fc5f7ee80943
  [stacks-exemplo/02-n8n-postgres.yaml]=9efd884653d814488eca7eab47416ae5f238433c2316e57218615b76e0a6b6c6
  [stacks-exemplo/03-n8n-redis.yaml]=d3d53f2773626ac10d160aeae1ff317d49319590232d6f5de0ba71eadc41c6f5
  [stacks-exemplo/04-n8n-editor.yaml]=215f474cb20515e615772016f7bb8d09114a6d889ac209afcf85acdf611d303e
  [stacks-exemplo/05-n8n-webhook.yaml]=cfbd56ac26977d4963964acc57fd1a10438a66273bacf35ebc8d9ca32befa769
  [stacks-exemplo/06-n8n-worker.yaml]=093c8fd28483daf13712f759059777e7ee7aae60e7b87727c55ee0619402927a
)
STACKS_REF="${REF:-$STACKS_COMMIT}"
RAW_BASE="https://raw.githubusercontent.com/LFcrystal766/hospedagem_em_transicao/$STACKS_REF/crystal-em-casa"
BASE="${CRYSTAL_DIR:-/root/crystal}"
ORIG="$BASE/originais"
STACKS="$BASE/stacks"
SEGREDOS="$BASE/.segredos"
PAINEL_IPS_ARQ="$BASE/.painel-ips"
ARQUIVOS=(00-traefik.yaml 01-portainer.yaml 02-n8n-postgres.yaml 03-n8n-redis.yaml 04-n8n-editor.yaml 05-n8n-webhook.yaml 06-n8n-worker.yaml)
AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CMD="${1:-}"
falha() { echo "ERRO: $*" >&2; exit 2; }
ok() { echo "  ok $*"; }
aviso() { echo "  ! $*"; }

# baixar_conferido CAMINHO DESTINO   (CAMINHO relativo a crystal-em-casa/, chave de ARQ_SHA256)
# Com o repositório ao lado, copia a versão local; senão baixa do commit fixo e só grava em
# DESTINO se o sha256 bater. Devolve 1 com o motivo, sem sair: quem chama decide.
baixar_conferido() {
  local rel="$1" dest="$2" esperado tmp h
  esperado="${ARQ_SHA256[$rel]:-}"
  [ -n "$esperado" ] || { aviso "$rel não está na tabela ARQ_SHA256 do script"; return 1; }
  if [ -f "$AQUI/$rel" ]; then
    cp "$AQUI/$rel" "$dest" || return 1
    h=$(sha256sum "$dest" | cut -d' ' -f1)
    [ "$h" = "$esperado" ] || aviso "$rel local (sha256 ${h:0:12}) difere da tabela do script (${esperado:0:12}): mudou e falta rodar arquivos-hash?"
    return 0
  fi
  printf '%s' "$STACKS_REF" | grep -Eq '^[0-9a-f]{40}$' \
    || { aviso "REF tem de ser um commit de 40 letras 0-9a-f (branch não vale)"; return 1; }
  tmp=$(mktemp "$dest.XXXXXX") || return 1
  if ! curl -fsSL -m 60 "$RAW_BASE/$rel" -o "$tmp"; then
    rm -f "$tmp"; aviso "não baixou $rel do commit ${STACKS_REF:0:12}"; return 1
  fi
  h=$(sha256sum "$tmp" | cut -d' ' -f1)
  if [ "$h" != "$esperado" ]; then
    rm -f "$tmp"
    aviso "$rel do commit ${STACKS_REF:0:12} veio com sha256 ${h:0:12}, esperado ${esperado:0:12}: NÃO usado"
    return 1
  fi
  mv -f "$tmp" "$dest"
}

# No repositório, depois de mudar um arquivo da tabela (e do commit com ele): imprime o
# STACKS_COMMIT e a tabela ARQ_SHA256 para colar no topo. Roda em qualquer máquina, sem docker.
arquivos_hash() {
  local c rel h marca mudou=0
  c=$(git -C "$AQUI" rev-parse HEAD 2>/dev/null) || falha "rode de dentro do repositório (git clone)"
  if [ -n "$(git -C "$AQUI" status --porcelain -- "${!ARQ_SHA256[@]}" 2>/dev/null)" ]; then
    aviso "há arquivo da tabela com mudança fora de commit: commit e push antes, senão o hash não existe no GitHub"
  fi
  echo "STACKS_COMMIT=$c"
  echo "declare -A ARQ_SHA256=("
  while IFS= read -r rel; do
    h=$(git -C "$AQUI" show "HEAD:crystal-em-casa/$rel" 2>/dev/null | sha256sum | cut -d' ' -f1)
    [ "$h" = "${ARQ_SHA256[$rel]}" ] && marca="" || { marca="   # MUDOU"; mudou=1; }
    echo "  [$rel]=$h$marca"
  done < <(printf '%s\n' "${!ARQ_SHA256[@]}" | sort)
  echo ")"
  [ "$mudou" = 1 ] || echo "# nenhum arquivo mudou: basta trocar o STACKS_COMMIT se quiser"
}

[ -n "$CMD" ] || { awk 'NR==1{next} /^#/{print; next} {exit}' "$0" | sed 's/^# \{0,1\}//'; exit 1; }

# ------------------------------------------------------------------ fundação
conferir_fundacao() {
  command -v docker >/dev/null || falha "docker não está instalado"
  [ "$(docker info --format '{{.Swarm.LocalNodeState}}')" = "active" ] || falha "Swarm não está ativo (docker swarm init)"
  [ "$(docker info --format '{{.Swarm.ControlAvailable}}')" = "true" ] || falha "este nó não é manager"
  docker network inspect network_swarm_public --format '{{.Driver}}' 2>/dev/null | grep -q overlay \
    || falha "rede network_swarm_public (overlay) não existe"
  for v in volume_swarm_certificates portainer_data n8n_postgres_data n8n_redis_data; do
    docker volume inspect "$v" >/dev/null 2>&1 || falha "volume $v não existe"
  done
  local no; no=$(docker node ls --format '{{.Hostname}}' | head -1)
  if ! docker node inspect "$no" --format '{{.Spec.Labels}}' | grep -q 'app:n8n'; then
    aviso "nó $no sem o rótulo app=n8n; aplicando"
    docker node update --label-add app=n8n "$no" >/dev/null
  fi
  ok "Swarm ativo, rede overlay, 4 volumes e rótulo app=n8n em $no"
  local min; min=$(docker version --format '{{.Server.MinAPIVersion}}' 2>/dev/null || echo "?")
  [ "$min" = "1.24" ] || aviso "o daemon exige API $min e o Traefik v2 usa 1.24: rode 'bash $0 docker-api' antes de subir o Traefik"
}

# ------------------------------------------------------------------ docker-api / docker-daemon
# O Traefik v2.11 da agência fala com o Docker pela API 1.24. O Docker 29 exige
# 1.44 por padrão e recusa o Traefik ("client version 1.24 is too old"): sem
# isso o Traefik não descobre serviço nenhum e não pede certificado. A saída
# documentada é baixar o piso do daemon em /etc/docker/daemon.json.
# docker-daemon (revisão de 24/10, INF-28) grava, além do piso:
#   "no-new-privileges": true   nenhum processo de contêiner ganha privilégio por binário
#                               setuid (as imagens oficiais trocam de usuário com gosu/su-exec,
#                               o que continua valendo; nenhuma das nossas usa sudo/su);
#   log json-file 10 MB x 3     para todo contêiner novo que não disser outra coisa.
# Reinicia o Docker: TODOS os serviços caem e voltam em até 1 a 2 minutos. Por isso pede
# --confirmo e é para a janela da madrugada. Cópia do daemon.json anterior ao lado.
DAEMON_JSON="${DOCKER_DAEMON_JSON:-/etc/docker/daemon.json}"   # trocável só para teste

# Grava $DAEMON_JSON.novo com o que falta e mostra o que muda. 0 = há mudança, 1 = já estava.
docker_daemon_novo() { # docker_daemon_novo api|completo
  python3 - "$DAEMON_JSON" "$1" <<'PY'
import json, os, sys
p, modo = sys.argv[1], sys.argv[2]
d = {}
if os.path.exists(p) and os.path.getsize(p) > 0:
    d = json.load(open(p))
novo = json.loads(json.dumps(d))
novo["min-api-version"] = "1.24"
if modo == "completo":
    novo["no-new-privileges"] = True
    novo.setdefault("log-driver", "json-file")
    if novo["log-driver"] == "json-file":
        lo = dict(novo.get("log-opts") or {})
        lo.setdefault("max-size", "10m")
        lo.setdefault("max-file", "3")
        novo["log-opts"] = lo
if novo == d:
    sys.exit(1)
for k in sorted(set(novo) | set(d)):
    if novo.get(k) != d.get(k):
        print(f"  {k}: {json.dumps(d.get(k))} -> {json.dumps(novo.get(k))}")
json.dump(novo, open(p + ".novo", "w"), indent=2)
PY
}

docker_daemon_aplicar() { # valida o .novo, guarda o anterior, troca e reinicia o Docker
  local t=0
  dockerd --validate --config-file="$DAEMON_JSON.novo" >/dev/null || { rm -f "$DAEMON_JSON.novo"; falha "daemon.json novo inválido: nada mudou"; }
  if [ -f "$DAEMON_JSON" ]; then cp -p "$DAEMON_JSON" "$DAEMON_JSON.antes-$(date -u +%Y%m%dT%H%M%SZ)"; fi
  mv -f "$DAEMON_JSON.novo" "$DAEMON_JSON"
  systemctl restart docker
  until docker info >/dev/null 2>&1 || [ $t -ge 60 ]; do sleep 3; t=$((t+3)); done
  docker info >/dev/null 2>&1 || falha "o Docker não voltou em 60 s: journalctl -u docker -n 50 (o daemon.json anterior está ao lado, .antes-*)"
}

docker_api() {
  local min; min=$(docker version --format '{{.Server.MinAPIVersion}}' 2>/dev/null || echo "?")
  if [ "$min" = "1.24" ]; then ok "daemon já aceita API 1.24"; return 0; fi
  echo "  piso atual do daemon: $min. Gravando min-api-version=1.24 em $DAEMON_JSON"
  rm -f "$DAEMON_JSON.novo"
  docker_daemon_novo api >/dev/null || true
  [ -f "$DAEMON_JSON.novo" ] || falha "não montei o daemon.json novo"
  docker_daemon_aplicar
  min=$(docker version --format '{{.Server.MinAPIVersion}}' 2>/dev/null || echo "?")
  [ "$min" = "1.24" ] && ok "daemon reiniciado, piso da API = 1.24" || falha "piso continua $min"
  echo "  os serviços do Swarm voltam sozinhos em até 1 min. Depois: bash $0 status"
}

docker_daemon() {
  local nnp
  rm -f "$DAEMON_JSON.novo"
  echo "== $DAEMON_JSON"
  if ! docker_daemon_novo completo; then
    ok "já tem o piso da API, no-new-privileges e a rotação de log"
  else
    if [ "${2:-}" != --confirmo ]; then
      rm -f "$DAEMON_JSON.novo"
      echo "  (acima, o que mudaria) Isto reinicia o Docker: todos os serviços caem e voltam em 1 a 2 min."
      falha "de madrugada, depois de um backup: bash $0 docker-daemon --confirmo"
    fi
    docker_daemon_aplicar
    ok "Docker reiniciado com o daemon.json novo (o anterior ficou em $DAEMON_JSON.antes-*)"
    echo "  os serviços voltam sozinhos; a rotação e o no-new-privileges valem para cada contêiner"
    echo "  recriado (todo deploy recria). Conferir em 2 min: bash $0 status"
  fi
  # Prova num contêiner descartável: o kernel marca NoNewPrivs=1.
  nnp=$(docker run --rm --network none "$ALPINE_IMG" grep -E '^NoNewPrivs:' /proc/self/status 2>/dev/null | awk '{print $2}' || true)
  if [ "$nnp" = 1 ]; then ok "contêiner novo nasce com no-new-privileges (NoNewPrivs: 1)"
  else aviso "não confirmei o no-new-privileges num contêiner de teste (NoNewPrivs: ${nnp:-?})"; fi
}

# ------------------------------------------------------------------ preparar
preparar() {
  local email="${2:-}"
  [ -n "$email" ] || falha "informe o e-mail do Let's Encrypt: bash bootstrap-vps.sh preparar voce@exemplo.com"
  echo "$email" | grep -Eq '^[^@ ]+@[^@ ]+\.[^@ ]+$' || falha "e-mail inválido: $email"
  conferir_fundacao
  redes_criar
  mkdir -p "$ORIG" "$STACKS"
  chmod 700 "$BASE" "$STACKS"

  # 1. Originais: da pasta local se o script estiver dentro do repositório, senão do GitHub
  # pelo commit fixo, com o sha256 conferido (baixar_conferido)
  for a in "${ARQUIVOS[@]}"; do
    baixar_conferido "stacks-exemplo/$a" "$ORIG/$a" || falha "sem $a conferido: nada foi regravado em $STACKS"
    grep -q '^services:' "$ORIG/$a" || falha "$a não parece um compose (baixou uma página de erro?)"
  done
  ok "${#ARQUIVOS[@]} originais em $ORIG"

  # 2. Segredos: gerados uma vez, nunca regenerados
  if [ -f "$SEGREDOS" ]; then
    ok "segredos já existem em $SEGREDOS (mantidos)"
  else
    umask 077
    {
      echo "DB_SENHA=$(openssl rand -hex 24)"
      echo "N8N_CHAVE=$(openssl rand -hex 16)"
      echo "CRIADO_EM=$(date -u +%FT%TZ)"
    } > "$SEGREDOS"
    ok "segredos gerados em $SEGREDOS. Copie pro cofre: bash $0 segredos"
  fi
  # Senha do Redis do n8n (revisão de 02/10, A2): o original da agência sobe sem
  # senha numa rede que o app e o Chatwoot também usam. Acrescentada uma vez a
  # segredos antigos; trocar exige redeploy de 03, 04, 05 e 06.
  if ! grep -q '^N8N_REDIS_SENHA=' "$SEGREDOS"; then
    umask 077
    echo "N8N_REDIS_SENHA=$(openssl rand -hex 24)" >> "$SEGREDOS"
    chmod 600 "$SEGREDOS"
    ok "N8N_REDIS_SENHA gerada em $SEGREDOS. Copie pro cofre: bash $0 segredos"
  fi
  # shellcheck disable=SC1090
  . "$SEGREDOS"
  [ "${#N8N_CHAVE}" -eq 32 ] || falha "chave do n8n em $SEGREDOS não tem 32 caracteres"
  printf '%s' "$N8N_REDIS_SENHA" | grep -Eq '^[0-9a-f]{48}$' || falha "N8N_REDIS_SENHA em $SEGREDOS não é hex de 48 caracteres"

  # 3. Arquivos prontos. O 03 ganha --requirepass e o 04/05/06 a senha da fila:
  # a agência não prevê senha no Redis, então entra aqui, não no original.
  umask 077
  for a in "${ARQUIVOS[@]}"; do
    sed -e "s|seudominio\.com\.br|$DOMINIO|g" \
        -e "s|SEU_EMAIL_AQUI|$email|g" \
        -e "s|SUBSTITUA_PELA_SENHA_DO_BANCO|$DB_SENHA|g" \
        -e "s|SUBSTITUA_PELA_CHAVE_DE_CRIPTOGRAFIA|$N8N_CHAVE|g" \
        -e "s|^\( *command: redis-server .*--port 6379\)$|\1 --requirepass $N8N_REDIS_SENHA|" \
        -e "/^ *- QUEUE_BULL_REDIS_PORT=6379$/a\\      - QUEUE_BULL_REDIS_PASSWORD=$N8N_REDIS_SENHA" \
        "$ORIG/$a" > "$STACKS/$a"
    case "$a" in
      03-*) grep -q -- "--requirepass " "$STACKS/$a" || falha "$a: o command do redis não recebeu --requirepass (o original mudou?)" ;;
      04-*|05-*|06-*) grep -q '^ *- QUEUE_BULL_REDIS_PASSWORD=' "$STACKS/$a" || falha "$a: QUEUE_BULL_REDIS_PASSWORD não entrou (o original mudou?)" ;;
    esac
    if grep -nE 'SUBSTITUA|SEU_EMAIL|seudominio' "$STACKS/$a" | grep -vE '^\s*[0-9]+:\s*#' | grep -q .; then
      falha "$a ainda tem placeholder fora de comentário"
    fi
    redes_ajustar "$STACKS/$a"   # só depois do redes-voltar: rede única
    somente_leitura_ajustar "$STACKS/$a"
  done
  ok "${#ARQUIVOS[@]} arquivos prontos em $STACKS (chmod 600)"
  # O 01 acima saiu do original, aberto. Se o painel já estava restrito, refaz a trava.
  # Se não conseguir, falha fechado (achado 34): o 01 aberto sai de $STACKS e o
  # 'portainer' se recusa a subir sem a lista.
  if [ -s "$PAINEL_IPS_ARQ" ] && ! painel_gerar; then
    mv -f "$STACKS/01-portainer.yaml" "$STACKS/01-portainer.yaml.aberto"
    echo "  !! não refiz a trava do painel: 01-portainer.yaml (aberto) foi tirado de $STACKS. O Portainer no ar"
    echo "  !! continua como está. Para regravar com a lista: bash $0 painel-restringir $(paste -sd' ' "$PAINEL_IPS_ARQ")"
  fi
  echo
  echo "Conferência do que mudou (só linhas com o domínio e o e-mail):"
  grep -hE "Host\(|N8N_HOST=|WEBHOOK_URL=|acme.email=" "$STACKS"/*.yaml | sed 's/^ *//' | sort -u
  echo
  echo "Próximo: bash $0 tudo   (ou traefik, portainer, bancos, n8n, um de cada vez)"
}

# ------------------------------------------------------------------ subir
esperar_stack() { # esperar_stack NOME_DA_STACK [SEGUNDOS]
  local stack=$1 limite=${2:-240} t=0 linhas pendentes
  while :; do
    linhas=$(docker service ls --filter "label=com.docker.stack.namespace=$stack" --format '{{.Name}} {{.Replicas}}')
    [ -n "$linhas" ] || falha "stack $stack não tem serviço nenhum"
    pendentes=$(echo "$linhas" | awk '{split($2,r,"/"); if (r[1]!=r[2] || r[2]=="0") print}')
    # 1/1 não basta logo depois de um deploy: a tarefa antiga ainda conta. Espera
    # também as atualizações em andamento terminarem.
    local s st
    for s in $(echo "$linhas" | awk '{print $1}'); do
      st=$(docker service inspect -f '{{if .UpdateStatus}}{{.UpdateStatus.State}}{{end}}' "$s" 2>/dev/null || true)
      case "$st" in updating|rollback_started|paused) pendentes="$pendentes"$'\n'"$s atualizando" ;; esac
    done
    pendentes=$(echo "$pendentes" | sed '/^$/d')
    if [ -z "$pendentes" ]; then
      echo "$linhas" | sed 's/^/  ok /'
      return 0
    fi
    if [ "$t" -ge "$limite" ]; then
      aviso "passaram ${limite}s e ainda não está 1/1:"
      echo "$pendentes" | sed 's/^/     /'
      echo "  Diagnóstico:"
      echo "$pendentes" | awk '{print $1}' | while read -r s; do
        docker service ps "$s" --no-trunc --format '     {{.Name}} {{.CurrentState}} {{.Error}}' | head -5
      done
      return 1
    fi
    sleep 5; t=$((t+5))
  done
}

# Estado da última atualização de um serviço, lido do JSON do docker service inspect
# (nomes de campo da API, sem depender de método em template). Saída:
# "ATUALIZADO_EM ESTADO INICIO" (epoch UTC; ESTADO "-" se nunca houve atualização,
# "ausente" se o serviço não existe).
svc_estado() { # svc_estado SERVIÇO
  { docker service inspect "$1" 2>/dev/null || true; } | python3 -c '
import datetime, json, re, sys
def ep(s):
    if not s:
        return 0
    s = re.sub(r"\.\d+", "", s).replace("Z", "+00:00")
    try:
        return int(datetime.datetime.fromisoformat(s).timestamp())
    except ValueError:
        return 0
try:
    d = json.load(sys.stdin)[0]
except Exception:
    print("0 ausente 0"); sys.exit(0)
u = d.get("UpdateStatus") or {}
print(ep(d.get("UpdatedAt")), u.get("State") or "-", ep(u.get("StartedAt")))' 2>/dev/null || echo "0 ausente 0"
}

# Tira de um log o que tiver cara de segredo antes de ir para a tela, e daí para o chat
# (revisão de 24/10, INF-26): senha em URL (postgres://u:SENHA@, redis://:SENHA@), Bearer,
# chaves com prefixo conhecido, JWT, chave privada do age e hex/base64 longos (as chaves que o
# bootstrap gera). Caminho de arquivo e texto comum passam.
redigir() {
  python3 -c '
import re, sys
R = [
    (re.compile(r"(://[^:/@\s]*:)[^@/\s]+@"), r"\1***@"),
    (re.compile(r"([Bb]earer\s+)[A-Za-z0-9._~+/=-]+"), r"\1***"),
    (re.compile(r"\b(sk-or-v1-|sk-or-|sb_secret_|sb_publishable_|re_|gsk_|ghp_|github_pat_)[A-Za-z0-9_-]{8,}"), r"\1***"),
    (re.compile(r"\beyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]*"), "eyJ***"),
    (re.compile(r"AGE-SECRET-KEY-1[0-9A-Z]+"), "AGE-SECRET-KEY-***"),
    (re.compile(r"\b[0-9a-fA-F]{48,}\b"), "<hex>"),
]
B64 = re.compile(r"[A-Za-z0-9+/]{40,}={0,2}")
def b64(m):
    t = m.group(0)
    if ("+" not in t and "=" not in t and t.count("/") > 1) or sum(c.isdigit() for c in t) < 4:
        return t
    return "<b64>"
for linha in sys.stdin:
    for r, novo in R:
        linha = r.sub(novo, linha)
    sys.stdout.write(B64.sub(b64, linha))
'
}

# Últimas linhas do contêiner mais novo que morreu num serviço, sem as linhas de
# requisição, e o erro das últimas tarefas.
servico_log_morto() { # servico_log_morto SERVIÇO
  local cid
  docker service ps "$1" --no-trunc --format '{{.Name}} {{.CurrentState}} {{.Error}}' 2>/dev/null | head -4 | sed 's/^/     /' || true
  cid=$(docker ps -a -q --filter "label=com.docker.swarm.service.name=$1" --filter status=exited 2>/dev/null | head -1 || true)
  if [ -n "$cid" ]; then
    echo "  -- últimas linhas do contêiner que morreu ($1):"
    docker logs --tail 40 "$cid" 2>&1 | grep -vE '"request completed"|"incoming request"' | redigir | sed 's/^/     /' | tail -25 || true
  fi
}

# Depois de QUALQUER deploy: "1/1" e a tag certa não bastam. Se a tarefa nova morre na
# subida, o Swarm volta sozinho ao spec anterior (failure_action: rollback). Com a
# mesma tag (mudança só no .env) a imagem nem muda, e só o UpdateStatus mostra a volta
# (achado 4 da revisão de 05/10). Espera a atualização terminar e falha quando:
#   - o estado é rollback_started/rollback_paused/rollback_completed ou paused, numa
#     atualização que começou depois do deploy (T0). Estado antigo, de um deploy
#     anterior que já voltou, não conta: é o caso do "app-subir TAG_ANTERIOR";
#   - a atualização não termina em 7 min;
#   - com TAG, a imagem do serviço não está nessa tag.
# Mostra o log do contêiner que morreu. Volta 1 se algo falhou (quem chama decide).
conferir_atualizacao() { # conferir_atualizacao T0 TAG|- SERVIÇO...
  local t0=$1 tag=$2 svc upd estado ini pendente agora fim problema img falhou=0
  shift 2
  fim=$(( $(date +%s) + 420 ))
  while :; do
    pendente=0; agora=$(date +%s)
    for svc in "$@"; do
      read -r upd estado ini <<<"$(svc_estado "$svc")"
      case "$estado" in
        updating|rollback_started) pendente=1 ;;
        *) # Spec regravado agora e a atualização ainda não começou: dá até 30 s.
           if [ "$upd" -ge "$t0" ] && [ "$ini" -lt "$t0" ] && [ "$agora" -lt $((t0 + 30)) ]; then pendente=1; fi ;;
      esac
    done
    [ "$pendente" = 0 ] && break
    [ "$agora" -lt "$fim" ] || break
    sleep 5
  done
  for svc in "$@"; do
    read -r upd estado ini <<<"$(svc_estado "$svc")"
    problema=""
    case "$estado" in
      rollback_*|paused) [ "$ini" -lt "$t0" ] || problema="o Swarm desfez a troca (UpdateStatus=$estado): a tarefa nova morreu na subida" ;;
      updating) problema="a atualização não terminou em 7 min" ;;
      ausente) problema="o serviço não existe" ;;
    esac
    if [ -z "$problema" ] && [ "$tag" != "-" ]; then
      img=$(docker service inspect -f '{{.Spec.TaskTemplate.ContainerSpec.Image}}' "$svc" 2>/dev/null || true)
      case "$img" in
        *":$tag"|*":$tag@"*) ;;
        *) problema="NÃO está em $tag (está em ${img##*:}): o Swarm desfez a troca" ;;
      esac
    fi
    [ -n "$problema" ] || continue
    falhou=1
    echo "  !! $svc: $problema"
    servico_log_morto "$svc"
  done
  return "$falhou"
}

deploy() { # deploy ARQUIVO STACK
  [ -f "$STACKS/$1" ] || falha "$STACKS/$1 não existe: rode 'preparar' antes"
  echo "== $2 ($1)"
  local t0 svcs
  t0=$(date +%s)
  docker stack deploy -c "$STACKS/$1" "$2" --detach=true >/dev/null
  sleep 3   # deixa o Swarm registrar a atualização antes de conferir
  esperar_stack "$2"
  svcs=$(docker service ls --filter "label=com.docker.stack.namespace=$2" --format '{{.Name}}' 2>/dev/null || true)
  # shellcheck disable=SC2086
  conferir_atualizacao "$t0" - $svcs || falha "a stack $2 não ficou de pé (log acima)"
}

# ------------------------------------------------------------------ redes (INF-06)
# Revisão de segurança de 24/10 (INF-06). Antes, tudo numa rede só, a network_swarm_public:
# Traefik, Portainer, n8n (com o Postgres e o Redis dele), API, web e Chatwoot. Um contêiner
# comprometido falava direto com qualquer outro, por fora do Traefik, e o banco do n8n (com as
# credenciais cifradas) ficava ao alcance de todos. Agora:
#   borda_api, borda_web, borda_atendimento, borda_n8n, borda_painel   uma borda por stack: só
#       o Traefik e o que ele publica (no n8n, o editor e o webhook);
#   n8n_interno   Postgres, Redis, editor, webhook e worker do n8n (externa: o n8n são 5 stacks);
#   app_interno, cw_interno, portainer_agentes   internas de cada stack, como já eram.
# O Traefik fica em todas as bordas e também na network_swarm_public (a da volta e a da
# Crystal do WhatsApp da agência), e em nenhuma rede de banco. Os nomes que os apps usam
# (app_postgres, app_redis, app_crystal, cw_postgres, cw_redis, n8n_postgres, n8n_redis) não
# mudam: quem os usa está na mesma rede interna. API, Chatwoot e n8n só se falam pelos
# endereços públicos (https://api., https://atendimento., https://webhook.), pelo Traefik.
# Corte, uma stack por vez e conferindo cada uma: preparar, traefik, painel, bancos (que já
# sobe o n8n), app-subir, atendimento-subir e redes-conferir. Volta: redes-voltar --confirmo.
REDES_MODO_ARQ="$BASE/.redes"   # "unica" depois de redes-voltar: o que subir vai para a network_swarm_public
REDES_EXTERNAS=(borda_api borda_web borda_atendimento borda_n8n borda_painel n8n_interno)

redes_unica() { [ "$(cat "$REDES_MODO_ARQ" 2>/dev/null || true)" = unica ]; }

# Cria as redes que faltam, uma vez só (idempotente). Sem --attachable: só serviço do Swarm
# entra; um 'docker run --network' avulso não.
redes_criar() {
  local r d novas=()
  for r in "${REDES_EXTERNAS[@]}"; do
    if d=$(docker network inspect "$r" --format '{{.Driver}}/{{.Scope}}' 2>/dev/null); then
      [ "$d" = "overlay/swarm" ] || falha "já existe uma rede $r que não é overlay do Swarm ($d): renomeie ou apague antes"
      continue
    fi
    docker network create --driver overlay --label crystal.revisao=2026-10-24 "$r" >/dev/null || falha "não criou a rede $r"
    novas+=("$r")
  done
  if [ ${#novas[@]} -eq 0 ]; then ok "redes separadas já existem (${REDES_EXTERNAS[*]})"
  else ok "rede(s) criada(s): ${novas[*]}"; fi
}

# Redes de um serviço, pelo nome (o spec guarda o id), uma por linha. Nada se não existe.
svc_redes() { # svc_redes SERVIÇO
  local ids id
  ids=$(docker service inspect "$1" --format '{{range .Spec.TaskTemplate.Networks}}{{.Target}} {{end}}' 2>/dev/null) || return 0
  for id in $ids; do docker network inspect "$id" --format '{{.Name}}' 2>/dev/null || echo "$id"; done
}
svc_na_rede() { svc_redes "$1" | grep -qx "$2"; }   # svc_na_rede SERVIÇO REDE

# Antes de pôr uma stack na borda nova, o Traefik tem de estar nela: senão o endereço sai do
# ar (o Traefik não alcança o serviço). Depois do redes-voltar não confere (rede única).
redes_exigir_traefik() { # redes_exigir_traefik REDE...
  redes_unica && return 0
  docker service inspect traefik_traefik >/dev/null 2>&1 || { aviso "Traefik não encontrado: sem ele nada responde"; return 0; }
  local r faltam=()
  for r in "$@"; do svc_na_rede traefik_traefik "$r" || faltam+=("$r"); done
  [ ${#faltam[@]} -eq 0 ] && return 0
  falha "o Traefik no ar ainda não está em ${faltam[*]}: subir agora tiraria esta stack do ar. Antes: bash $0 preparar EMAIL && bash $0 traefik"
}

# Depois do redes-voltar, cada arquivo gerado passa por aqui: as redes novas viram a
# network_swarm_public de antes, sem item repetido (no n8n, borda_n8n e n8n_interno viram
# uma só). Sem a marca não muda nada. O 00 (Traefik) não passa: ele fica em todas as redes,
# e é isso que deixa cada stack voltar sozinha, sem tocar no Traefik.
redes_ajustar() { # redes_ajustar ARQUIVO
  redes_unica || return 0
  case "$(basename "$1")" in 00-*) return 0 ;; esac
  python3 - "$1" <<'PY' || falha "não ajustei as redes de $1 para a rede única"
import re, sys
NOVAS = re.compile(r"\b(borda_api|borda_web|borda_atendimento|borda_n8n|borda_painel|n8n_interno)\b")
p = sys.argv[1]
txt = open(p, encoding="utf-8").read()
fim = "\n" if txt.endswith("\n") else ""
saida, lista, vistos, topo, chaves, pular = [], None, set(), False, set(), False
def recuo(l):
    return len(l) - len(l.lstrip(" "))
for l in txt[: len(txt) - len(fim)].split("\n"):
    vazia = l.strip() == "" or l.lstrip().startswith("#")
    if not vazia:
        l = NOVAS.sub("network_swarm_public", l)
    if topo and not vazia and recuo(l) == 0:
        topo = False
    if lista is not None and not vazia and recuo(l) <= lista:
        lista = None
    if re.match(r"^networks:\s*$", l):
        topo, chaves, pular = True, set(), False
        saida.append(l); continue
    if topo:   # bloco networks: do fim do arquivo: chave repetida sai com as linhas dela
        m = re.match(r"^  ([A-Za-z0-9_.-]+):\s*$", l)
        if m:
            pular = m.group(1) in chaves
            chaves.add(m.group(1))
        if pular and (m or (not vazia and recuo(l) > 2)):
            continue
        saida.append(l); continue
    m = re.match(r"^( +)networks:\s*$", l)
    if m:      # lista de redes de um serviço: item repetido sai
        lista, vistos = len(m.group(1)), set()
        saida.append(l); continue
    if lista is not None:
        m = re.match(r"^ +- *([A-Za-z0-9_.-]+)\s*$", l)
        if m:
            if m.group(1) in vistos:
                continue
            vistos.add(m.group(1))
    saida.append(l)
open(p, "w", encoding="utf-8").write("\n".join(saida) + fim)
PY
}

# Escape do sistema de arquivos só de leitura (INF-15, 24/10): o Traefik e a Crystal sobem com
# read_only: true. Se um deles não subir assim numa versão nova, 'touch $BASE/.sem-somente-leitura'
# e preparar/traefik ou app-subir de novo: o arquivo gerado sai sem a trava, com aviso.
somente_leitura_ajustar() { # somente_leitura_ajustar ARQUIVO
  [ -f "$BASE/.sem-somente-leitura" ] || return 0
  grep -qE '^ *read_only: true *$' "$1" || return 0
  sed -i -E '/^ *read_only: true *$/d' "$1"
  aviso "$(basename "$1") sem read_only ($BASE/.sem-somente-leitura existe): apague o arquivo assim que der"
}

# Conexão TCP de dentro de um contêiner com node (n8n, API, web, Crystal). 0 se conectou.
tcp_de() { # tcp_de CID HOST PORTA
  docker exec "$1" node -e 'const s=require("net").connect(Number(process.argv[2]),process.argv[1]);s.on("connect",()=>process.exit(0));s.on("error",()=>process.exit(1));setTimeout(()=>process.exit(1),4000)' "$2" "$3" >/dev/null 2>&1
}
# IP de um contêiner numa rede (pelo nome da rede). Vazio se não está nela.
ip_na_rede() { # ip_na_rede CID REDE
  docker inspect "$1" --format '{{range $n, $v := .NetworkSettings.Networks}}{{$n}}={{$v.IPAddress}} {{end}}' 2>/dev/null \
    | tr ' ' '\n' | sed -n "s/^$2=//p" | head -1
}
cid_de() { docker ps -q -f "name=$1" 2>/dev/null | head -1; }   # cid_de SERVIÇO

# Só leitura: em que rede está cada serviço, comparado com o desenho, e a prova de que um
# vizinho não alcança o outro (tentativas de conexão de 4 s, por IP, de dentro dos contêineres).
redes_conferir() {
  local modo=separadas s linhas="" falhou=0
  redes_unica && modo=unica
  echo "== redes dos serviços (INF-06; modo: $modo)"
  [ "$modo" = unica ] && aviso "modo de volta ($REDES_MODO_ARQ): tudo na network_swarm_public. Para separar de novo: bash $0 redes-separar"
  while read -r s; do
    [ -n "$s" ] && linhas+="$s $(svc_redes "$s" | paste -sd, -)"$'\n'
  done < <(docker service ls --format '{{.Name}}' 2>/dev/null)
  printf '%s' "$linhas" | python3 -c '
import sys
modo = sys.argv[1]
BORDAS = {"borda_api", "borda_web", "borda_atendimento", "borda_n8n", "borda_painel"}
INTERNAS = {"n8n_interno", "crystal_app_app_interno", "crystal_atendimento_cw_interno", "portainer_portainer_agentes"}
E = {
  "portainer_portainer": {"borda_painel", "portainer_portainer_agentes"},
  "portainer_agent": {"portainer_portainer_agentes"},
  "n8n_postgres_n8n_postgres": {"n8n_interno"}, "n8n_redis_n8n_redis": {"n8n_interno"},
  "n8n_editor_n8n_editor": {"borda_n8n", "n8n_interno"}, "n8n_webhook_n8n_webhook": {"borda_n8n", "n8n_interno"},
  "n8n_worker_n8n_worker": {"n8n_interno"}, "n8n_mcp_n8n_mcp": {"borda_n8n", "n8n_interno"},
  "crystal_app_app_api": {"crystal_app_app_interno", "borda_api"}, "crystal_app_app_web": {"borda_web"},
  "crystal_app_app_crystal": {"crystal_app_app_interno"}, "crystal_app_app_postgres": {"crystal_app_app_interno"},
  "crystal_app_app_redis": {"crystal_app_app_interno"},
  "crystal_atendimento_cw_rails": {"crystal_atendimento_cw_interno", "borda_atendimento"},
  "crystal_atendimento_cw_sidekiq": {"crystal_atendimento_cw_interno"},
  "crystal_atendimento_cw_postgres": {"crystal_atendimento_cw_interno"},
  "crystal_atendimento_cw_redis": {"crystal_atendimento_cw_interno"},
}
def unica(c):
    return {"network_swarm_public" if r in BORDAS or r == "n8n_interno" else r for r in c}
ruim = 0
for linha in sys.stdin:
    if not linha.strip():
        continue
    nome, _, r = linha.strip().partition(" ")
    tem = {x for x in r.split(",") if x}
    msg = ""
    if nome == "traefik_traefik":
        precisa = {"network_swarm_public"} | (set() if modo == "unica" else BORDAS)
        if not precisa <= tem:
            msg = "faltam " + ", ".join(sorted(precisa - tem))
        if tem & INTERNAS:
            msg += (" e " if msg else "") + "está em rede de banco: " + ", ".join(sorted(tem & INTERNAS))
    elif nome in E:
        quer = unica(E[nome]) if modo == "unica" else E[nome]
        if tem != quer:
            msg = "esperado " + ", ".join(sorted(quer))
    elif "network_swarm_public" in tem and modo != "unica":
        print(f"  ! {nome}: {r} (fora do desenho, na rede pública com o Traefik; a Crystal do WhatsApp da agência, enquanto existir)")
        continue
    if msg:
        ruim = 1
        print(f"  !! {nome}: {r} ({msg})")
    else:
        print(f"  ok {nome}: {r}")
sys.exit(ruim)
' "$modo" || falhou=1
  [ "$modo" = unica ] && { [ "$falhou" = 0 ] || aviso "algum serviço fora do desenho (acima)"; return 0; }

  echo "== vizinhos que NÃO podem se alcançar (por IP, de dentro dos contêineres)"
  local -A C=()
  local de alvo rede porta ip
  C[n8n]=$(cid_de n8n_editor_n8n_editor); C[crystal]=$(cid_de "${APP_STACK}_app_crystal")
  C[web]=$(cid_de "${APP_STACK}_app_web"); C[api]=$(cid_de "${APP_STACK}_app_api")
  C[chatwoot]=$(cid_de "${CW_STACK}_cw_rails"); C[portainer]=$(cid_de portainer_portainer)
  C[pg_n8n]=$(cid_de n8n_postgres_n8n_postgres); C[pg_app]=$(cid_de "${APP_STACK}_app_postgres")
  # "origem destino rede porta": a origem tenta o IP que o destino tem naquela rede.
  while read -r de alvo rede porta; do
    [ -n "${C[$de]}" ] && [ -n "${C[$alvo]}" ] || continue
    ip=$(ip_na_rede "${C[$alvo]}" "$rede"); [ -n "$ip" ] || continue
    if tcp_de "${C[$de]}" "$ip" "$porta"; then
      falhou=1; echo "  !! $de alcança $alvo ($rede, porta $porta)"
    else
      ok "$de não alcança $alvo ($rede, porta $porta)"
    fi
  done <<'PARES'
n8n api borda_api 3001
n8n api crystal_app_app_interno 3001
n8n pg_app crystal_app_app_interno 5432
n8n chatwoot borda_atendimento 3000
n8n portainer borda_painel 9000
crystal pg_n8n n8n_interno 5432
crystal chatwoot borda_atendimento 3000
web api borda_api 3001
web pg_app crystal_app_app_interno 5432
PARES
  echo "== vizinhos que PRECISAM se alcançar (pelos nomes de sempre)"
  while read -r de alvo porta; do
    [ -n "${C[$de]}" ] || continue
    if tcp_de "${C[$de]}" "$alvo" "$porta"; then ok "$de -> $alvo:$porta"
    else falhou=1; echo "  !! $de NÃO alcança $alvo:$porta (o serviço caiu? a rede interna mudou?)"; fi
  done <<'PARES'
n8n n8n_postgres 5432
n8n n8n_redis 6379
api app_postgres 5432
api app_redis 6379
api app_crystal 8080
PARES
  app_ip_conferir || falhou=1
  if [ "$falhou" = 0 ]; then ok "redes como o desenho"
  else aviso "há diferença (acima). No meio do corte é o esperado: siga o roteiro. Algo quebrou depois dele? Volta de tudo: bash $0 redes-voltar --confirmo"; fi
  return 0
}

# O IP que a API registra (e usa no limite de tentativas) não pode ser escolhido por quem
# chama: um X-Forwarded-For forjado, de fora (pelo Traefik) ou de um vizinho de rede (direto
# na API), não pode aparecer no log. Usa rotas que não existem (404) para não mexer em nada.
app_ip_conferir() {
  local api cid_crystal n linha visto falhou=0 tp
  api=$(cid_de "${APP_STACK}_app_api"); [ -n "$api" ] || return 0
  tp=$(docker exec "$api" sh -c 'printf %s "$TRUST_PROXY"' 2>/dev/null || true)
  echo "== IP do cliente que a API registra (TRUST_PROXY=${tp:-?})"
  n="$(date +%s)$$"
  curl -s -o /dev/null -m 15 -H 'X-Forwarded-For: 198.51.100.77' "https://api.$DOMINIO/xff-teste-$n" || true
  cid_crystal=$(cid_de "${APP_STACK}_app_crystal")
  if [ -n "$cid_crystal" ]; then
    docker exec "$cid_crystal" node -e 'fetch("http://app_api:3001/xff-direto-"+process.argv[1],{headers:{"x-forwarded-for":"198.51.100.88"},signal:AbortSignal.timeout(8000)}).then(()=>{},()=>{})' "$n" >/dev/null 2>&1 || true
  fi
  sleep 3
  for linha in "xff-teste-$n de fora, pelo Traefik" "xff-direto-$n da Crystal, direto na API"; do
    visto=$(docker service logs --since 3m --raw "${APP_STACK}_app_api" 2>/dev/null | grep -F "/${linha%% *}" | grep -oE '"remoteAddress":"[^"]*"' | head -1 | cut -d'"' -f4 || true)
    if [ -z "$visto" ]; then
      [ -n "$cid_crystal" ] || [ "${linha#*direto}" = "$linha" ] || continue
      aviso "não achei no log da API o pedido ${linha#* } (log em outro nível?)"; continue
    fi
    case "$visto" in
      198.51.100.*) falhou=1; echo "  !! ${linha#* }: a API registrou o IP FORJADO ($visto)" ;;
      *) if python3 -c 'import ipaddress,sys; sys.exit(0 if ipaddress.ip_address(sys.argv[1]) in ipaddress.ip_network(sys.argv[2], strict=False) else 1)' "$visto" "$tp" 2>/dev/null; then
           falhou=1; echo "  !! ${linha#* }: a API registrou o IP do próprio Traefik ($visto): todo mundo dividiria o mesmo limite"
         else
           ok "${linha#* }: a API registrou $visto, não o forjado"
         fi ;;
    esac
  done
  return "$falhou"
}

# Volta de tudo de uma vez: grava a marca e sobe n8n, painel, app e Chatwoot de novo na
# network_swarm_public (com a mesma tag do app). O Traefik fica como está, em todas as redes.
redes_voltar() {
  [ "${2:-}" = --confirmo ] || falha "isto devolve n8n, painel, app e Chatwoot à rede única de antes (network_swarm_public), uma stack por vez; o Traefik fica como está. Se for isso: bash $0 redes-voltar --confirmo"
  docker network inspect network_swarm_public >/dev/null 2>&1 || falha "a rede network_swarm_public não existe: a volta precisa dela"
  svc_na_rede traefik_traefik network_swarm_public || falha "o Traefik não está na network_swarm_public: nada foi mudado"
  mkdir -p "$BASE"; umask 077; echo unica > "$REDES_MODO_ARQ"; chmod 600 "$REDES_MODO_ARQ"
  ok "marca gravada em $REDES_MODO_ARQ: o que subir daqui em diante vai para a network_swarm_public"
  local a
  for a in 01-portainer.yaml 02-n8n-postgres.yaml 03-n8n-redis.yaml 04-n8n-editor.yaml 05-n8n-webhook.yaml 06-n8n-worker.yaml; do
    if [ -f "$STACKS/$a" ]; then redes_ajustar "$STACKS/$a"; fi
  done
  if docker service inspect n8n_postgres_n8n_postgres >/dev/null 2>&1; then bancos; fi   # bancos já sobe o n8n junto
  if docker service inspect portainer_portainer >/dev/null 2>&1; then
    if [ -s "$PAINEL_IPS_ARQ" ]; then painel_gerar || falha "não regravei o painel restrito (acima)"; fi
    portainer
  fi
  if docker service inspect "${APP_STACK}_app_api" >/dev/null 2>&1; then app_subir app-subir "$(app_tag_atual)"; fi
  if docker service inspect "${CW_STACK}_cw_rails" >/dev/null 2>&1; then atendimento_subir; fi
  echo
  redes_conferir
}

redes_separar() {
  if ! redes_unica; then ok "as redes já estão separadas (não há $REDES_MODO_ARQ)"; return 0; fi
  rm -f "$REDES_MODO_ARQ"
  ok "marca da volta apagada. Para separar de novo, um passo por vez, conferindo cada um:"
  echo "  bash $0 preparar EMAIL      (regrava os arquivos com as redes separadas)"
  echo "  bash $0 painel-restringir IP...   (ou: bash $0 portainer)"
  echo "  bash $0 bancos              (já sobe o n8n junto)"
  echo "  bash $0 app-subir $(app_tag_atual)"
  echo "  bash $0 atendimento-subir"
  echo "  bash $0 redes-conferir"
}

traefik() {
  conferir_fundacao; redes_criar
  local t0 upd _e _i; t0=$(date +%s)
  deploy 00-traefik.yaml traefik
  # O Traefik lê as rotas pelo proxy só de leitura do docker.sock (INF-22). Se o novo não as
  # lê (permissão do proxy, rede), todo endereço daria 404: volta sozinho ao anterior, mas só
  # quando este deploy mudou mesmo o serviço (rollback sem mudança voltaria a algo antigo).
  if ! traefik_rotas_conferir; then
    aviso "nenhum endereço conhecido respondeu em 2 min: o Traefik novo não está lendo as rotas"
    docker service logs --since 5m traefik_traefik 2>&1 | grep -iE 'provider|docker|error' | tail -8 | sed 's/^/     /' || true
    docker service logs --since 5m traefik_docker_proxy 2>&1 | tail -5 | redigir | sed 's/^/     /' || true
    read -r upd _e _i <<<"$(svc_estado traefik_traefik)"
    if [ "$upd" -ge "$t0" ]; then
      echo "  voltando o Traefik à versão anterior (docker service rollback traefik_traefik)"
      docker service rollback --detach=false traefik_traefik >/dev/null 2>&1 || aviso "o rollback não confirmou: docker service ps traefik_traefik"
      falha "o Traefik novo não leu as rotas e foi desfeito. Mande o log acima para a sessão"
    fi
    falha "o Traefik não mudou neste deploy e mesmo assim nada responde: ver DNS, certificado e 'docker service logs traefik_traefik'"
  fi
  traefik_conferir
}

# Depois de subir o Traefik: ele tem de ter lido as rotas das stacks que existem. Basta um
# endereço conhecido responder (200, 30x, 401 ou 403); sem rota o Traefik dá 404. Até 2 min:
# o provedor consulta o Swarm a cada 15 s e tenta de novo se o proxy ainda não subiu.
traefik_rotas_conferir() {
  local u code t=0 urls=()
  docker service inspect "${APP_STACK}_app_api" >/dev/null 2>&1 && urls+=("https://api.$DOMINIO/healthz")
  docker service inspect "${CW_STACK}_cw_rails" >/dev/null 2>&1 && urls+=("https://$CW_HOST/api")
  docker service inspect n8n_editor_n8n_editor >/dev/null 2>&1 && urls+=("https://editor.$DOMINIO/")
  docker service inspect portainer_portainer >/dev/null 2>&1 && urls+=("https://painel.$DOMINIO/")
  [ ${#urls[@]} -gt 0 ] || return 0
  while :; do
    for u in "${urls[@]}"; do
      code=$(curl -s -o /dev/null -m 10 -w '%{http_code}' "$u" 2>/dev/null) || code=000
      case "$code" in 200|301|302|401|403) ok "Traefik lendo as rotas: $u -> $code"; return 0 ;; esac
    done
    [ $t -ge 120 ] && return 1
    sleep 10; t=$((t+10))
  done
}
# Depois de subir o Traefik: a versão que ficou no ar e, com o Chatwoot no ar, a prova de
# que a trava da área de administração pega também com /../ e %2e%2e (INF-01, 24/10).
traefik_conferir() {
  local img code t=0
  img=$(docker service inspect traefik_traefik --format '{{.Spec.TaskTemplate.ContainerSpec.Image}}' 2>/dev/null | sed 's/@sha256:.*//' || true)
  ok "Traefik no ar: ${img:-?}"
  docker service inspect "${CW_STACK}_cw_rails" >/dev/null 2>&1 || return 0
  # O Traefik recém-subido leva alguns segundos para ler as rotas das outras stacks.
  until { code=$(curl -s -o /dev/null -m 10 -w '%{http_code}' "https://$CW_HOST/api" 2>/dev/null) && [ "$code" = 200 ]; } || [ $t -ge 90 ]; do
    sleep 5; t=$((t+5))
  done
  admin_trava_conferir
}
portainer() {
  redes_exigir_traefik borda_painel
  # Com lista de IPs, nunca sobe o painel aberto (achado 34).
  if [ -s "$PAINEL_IPS_ARQ" ] && ! grep -q 'ipallowlist.sourcerange=' "$STACKS/01-portainer.yaml" 2>/dev/null; then
    falha "o painel. é restrito ($PAINEL_IPS_ARQ) e $STACKS/01-portainer.yaml está sem a lista. Rode: bash $0 painel-restringir $(paste -sd' ' "$PAINEL_IPS_ARQ")"
  fi
  deploy 01-portainer.yaml portainer
  [ -s "$PAINEL_IPS_ARQ" ] || echo "  Abra https://painel.$DOMINIO AGORA e crie o admin: o Portainer tranca a criação se demorar"
}
# Rede do banco e da fila do n8n: n8n_interno; na volta (redes-voltar), a network_swarm_public.
n8n_rede_banco() { if redes_unica; then echo network_swarm_public; else echo n8n_interno; fi; }
bancos() {
  local rede; rede=$(n8n_rede_banco)
  # Se o n8n vai ter de subir junto (banco mudando de rede), confere ANTES de mexer no banco que
  # o Traefik já está na borda_n8n: senão o banco mudava e o n8n ficava parado sem ele.
  if docker service inspect n8n_editor_n8n_editor >/dev/null 2>&1 && ! svc_na_rede n8n_editor_n8n_editor "$rede"; then
    redes_exigir_traefik borda_n8n
  fi
  deploy 02-n8n-postgres.yaml n8n_postgres; deploy 03-n8n-redis.yaml n8n_redis
  # Banco e fila acabaram de mudar de rede (corte do INF-06 ou volta): o editor, o webhook e o
  # worker ficam sem banco até subirem na mesma rede. Sobe os três já: a parada do n8n dura só
  # a troca (1 a 2 minutos; a Assiny reenvia webhook que falhou).
  if docker service inspect n8n_editor_n8n_editor >/dev/null 2>&1 && ! svc_na_rede n8n_editor_n8n_editor "$rede"; then
    echo "  o n8n ainda está na rede antiga e acabou de perder o banco: subindo editor, webhook e worker agora"
    n8n
  fi
}
n8n() {
  local rede; rede=$(n8n_rede_banco)
  redes_exigir_traefik borda_n8n
  if docker service inspect n8n_postgres_n8n_postgres >/dev/null 2>&1 && ! svc_na_rede n8n_postgres_n8n_postgres "$rede"; then
    falha "o Postgres do n8n ainda não está na $rede: o n8n subiria sem banco. Rode: bash $0 bancos (ele já sobe o n8n junto)"
  fi
  deploy 04-n8n-editor.yaml n8n_editor; deploy 05-n8n-webhook.yaml n8n_webhook; deploy 06-n8n-worker.yaml n8n_worker
}
tudo()      { traefik; portainer; bancos; n8n; echo; status; }

# ------------------------------------------------------------------ backup
# O guia da agência pede backup do banco do n8n (fluxos e credenciais) e a
# chave de criptografia guardada SEPARADA. Aqui só o banco; a chave fica no
# cofre. Um dump sem a chave não restaura credenciais, e é por isso que os
# dois nunca andam juntos.
BACKUPS="$BASE/backups"
FORA_CONF="$BASE/.backup-fora"            # conta, bucket e chave do R2 (chmod 600)
FORA_DEST="$BASE/.backup-destinatario"    # chave PÚBLICA do age; a privada fica só no Bitwarden
FORA_PREFIXO=vps-crystal
# Revisão de 24/10 (INF-18): a chave PÚBLICA que cifra os backups mora na VPS, e quem mandar na
# VPS poderia trocá-la por uma dele: os backups seguiriam subindo, cifrados para o atacante, e o
# backup-conferir passaria. Defesas: (1) com a pública aqui (é pública, pode ir para o
# repositório: o 'age1...' que o status mostra e que está no Bitwarden), o backup se recusa a
# cifrar para outra; (2) o status, o backup-conferir e a vigia (todo dia 1º, ao meio-dia UTC)
# mostram o fim da chave para comparar com o Bitwarden; (3) a cada 3 meses a vigia lembra o
# teste de restauração (backup-link e abrir no Mac). Vazio: só (2) e (3).
FORA_DEST_ESPERADO=""

# "age1...XXXXXXXX" (os 8 últimos), para comparar com o Bitwarden sem copiar a chave inteira.
backup_destinatario_resumo() {
  local d; d=$(cat "$FORA_DEST" 2>/dev/null || true)
  [ -n "$d" ] && printf 'age1...%s' "${d: -8}"
}
# 0 se a chave pública da VPS é a esperada (ou não há esperada); 1, com aviso, se divergir.
backup_destinatario_conferir() {
  [ -n "$FORA_DEST_ESPERADO" ] || return 0
  [ "$(cat "$FORA_DEST" 2>/dev/null || true)" = "$FORA_DEST_ESPERADO" ] && return 0
  aviso "a chave pública dos backups na VPS ($(backup_destinatario_resumo)) NÃO é a esperada (age1...${FORA_DEST_ESPERADO: -8}): alguém trocou $FORA_DEST? Nada é cifrado para ela"
  return 1
}

# Revisão de 24/10 (INF-19): os dumps (.sql.gz) e as cópias de pastas (.tar.gz) ficavam 14 dias
# em claro na VPS. Agora cada backup cifra, com a chave pública, os das rodadas anteriores (mais
# de 20 h): em claro fica só o da última rodada, para uma volta rápida. Abrir um .age pede a
# chave privada do Bitwarden, que nunca fica na VPS (README, "Backup fora da VPS").
backup_cifrar_locais() { # backup_cifrar_locais PASTA
  local f n=0 falhou=0 dest
  if [ ! -s "$FORA_DEST" ] || ! command -v age >/dev/null; then
    aviso "backups antigos seguem em claro na VPS: falta a chave dos backups (bash $0 backup-chave)"; return 0
  fi
  backup_destinatario_conferir || return 1
  dest=$(cat "$FORA_DEST")
  while IFS= read -r -d '' f; do
    if devagar age -r "$dest" -o "$f.age.tmp" "$f" && mv -f "$f.age.tmp" "$f.age" && rm -f "$f"; then n=$((n+1))
    else rm -f "$f.age.tmp"; falhou=1; fi
  done < <(find "$1" -maxdepth 1 -type f \( -name '*.sql.gz' -o -name '*.tar.gz' \) -mmin +1200 -print0 2>/dev/null)
  [ "$n" = 0 ] || ok "$n backup(s) de rodadas anteriores cifrados na VPS (.age)"
  [ "$falhou" = 0 ] || { aviso "algum backup antigo não foi cifrado (fica em claro até a próxima rodada)"; return 1; }
}
VOLUMES="${DOCKER_VOLUMES:-/var/lib/docker/volumes}"   # trocável só para teste

# pg_dump de um banco para ARQ.gz. Falha (e apaga o arquivo) se o pg_dump falhar ou
# o dump vier vazio.
# Prioridade baixa de CPU e de disco (nice/ionice) em tudo que o backup faz na VPS, para o app e a
# Crystal seguirem respondendo enquanto ele roda (23/10). O pg_dump roda dentro do contêiner; o
# que pesa aqui é comprimir, cifrar e empacotar.
devagar() { nice -n 19 ionice -c3 "$@"; }

backup_pg() { # backup_pg CID USUÁRIO BANCO ARQ
  if docker exec "$1" pg_dump -U "$2" -d "$3" --no-owner | devagar gzip > "$4" \
     && [ "$(gzip -dc "$4" 2>/dev/null | head -c 1 | wc -c)" = 1 ]; then
    ok "$3 em $4 ($(du -h "$4" | cut -f1))"
    return 0
  fi
  rm -f "$4"
  aviso "pg_dump de $3 falhou"
  return 1
}

# Cópia de uma pasta (uploads do app, anexos do Chatwoot) em tar incremental: um
# completo por semana (domingo, ou quando o último completo passou de 6 dias) e, nos
# outros dias, um diferencial contra o último completo. O disco não enche com 14
# completos por dia e cada envio ao R2 fica pequeno (achado 25). Restaurar: extrair o
# -completo e depois o -diferencial mais novo, os dois com --listed-incremental=/dev/null.
# tar sai 1 quando um arquivo mudou durante a leitura (alguém mandando foto às 03:30):
# a cópia vale, com aviso; 2 ou mais é falha (achado 22). Ecoa o arquivo gerado.
backup_tar() { # backup_tar PASTA TIPO TS
  local orig=$1 tipo=$2 ts=$3 base="$BACKUPS/.$2.snar" novo="$BACKUPS/.$2.snar.novo" modo arq rc=0
  if [ ! -s "$base" ] || [ "$(date -u +%u)" = 7 ] || [ -n "$(find "$base" -mtime +6 2>/dev/null)" ]; then
    modo=completo; rm -f "$novo"
  else
    modo=diferencial; cp "$base" "$novo"
  fi
  arq="$BACKUPS/$tipo-$ts-$modo.tar.gz"
  # gzip -1: fotos e áudios já vêm comprimidos; o nível padrão (6) gastava CPU à toa (23/10).
  devagar tar -C "$orig" --listed-incremental="$novo" --use-compress-program='gzip -1' -cf "$arq" . 2>"$BACKUPS/.tar-erros" || rc=$?
  if [ "$rc" -le 1 ] && [ -s "$arq" ]; then
    [ "$rc" = 1 ] && aviso "$tipo: arquivo mudou durante a cópia (tar saiu 1); a cópia vale: $(head -c 200 "$BACKUPS/.tar-erros" | tr '\n' ' ')" >&2
    if [ "$modo" = completo ]; then mv "$novo" "$base"; else rm -f "$novo"; fi
    rm -f "$BACKUPS/.tar-erros"
    echo "$arq"
    return 0
  fi
  aviso "tar de $tipo falhou (saída $rc): $(head -c 300 "$BACKUPS/.tar-erros" | tr '\n' ' ')" >&2
  rm -f "$arq" "$novo" "$BACKUPS/.tar-erros"
  return 1
}

backup() {
  local dir="$BACKUPS" cid ts arq novos=() falhas=() up completo=1
  # 23/10: à mão (com terminal) o padrão é só os bancos; o cron (sem terminal) e --completo fazem tudo.
  case "${2:-}" in
    --completo) completo=1 ;;
    --bancos) completo=0 ;;
    "") [ -t 1 ] && completo=0 ;;
    *) falha "uso: bash $0 backup [--completo|--bancos]" ;;
  esac
  mkdir -p "$dir"; chmod 700 "$dir"
  umask 077
  ts=$(date -u +%Y%m%dT%H%M%SZ)
  backup_cifrar_locais "$dir" || falhas+=("VPS: backup antigo não cifrado (ou chave pública trocada)")
  if [ "$completo" = 1 ]; then echo "== backup $ts (completo: bancos, fotos e anexos)"
  else echo "== backup $ts (só os bancos; fotos e anexos vão no cron das 03:30. Para incluir agora: bash $0 backup --completo)"; fi
  # Cada parte é independente (achado 22): a que falha fica registrada e as outras
  # seguem, inclusive o envio ao R2. No fim, código de erro e resumo do que falhou,
  # que a vigia lê de $BACKUPS/.backup-falhas.

  # Banco do n8n. Só restaura credenciais com a N8N_CHAVE do cofre.
  cid=$(docker ps -q -f name=n8n_postgres_n8n_postgres 2>/dev/null | head -1 || true)
  if [ -z "$cid" ]; then
    aviso "contêiner do Postgres do n8n não está rodando"; falhas+=("n8n: Postgres fora do ar")
  else
    arq="$dir/n8n_queue-$ts.sql.gz"
    if backup_pg "$cid" postgres n8n_queue "$arq"; then novos+=("$arq"); else falhas+=("n8n: pg_dump falhou"); fi
  fi

  # Banco do app e a memória da nossa Crystal (crystal_agente, achado 21), se a stack
  # crystal_app estiver no ar. Campos cifrados e o hash do CPF só se leem com
  # ENCRYPTION_KEY e CPF_SALT; a memória, com CRYSTAL_CHAVE_CIFRA. Todas no cofre.
  cid=$(docker ps -q -f name=${APP_STACK}_app_postgres 2>/dev/null | head -1 || true)
  if [ -n "$cid" ]; then
    arq="$dir/crystal_web_chat-$ts.sql.gz"
    if backup_pg "$cid" crystal crystal_web_chat "$arq"; then novos+=("$arq"); else falhas+=("app: pg_dump do crystal_web_chat falhou"); fi
    if docker exec "$cid" psql -U crystal -d crystal_web_chat -tAc "select 1 from pg_database where datname = 'crystal_agente'" 2>/dev/null | grep -q 1; then
      arq="$dir/crystal_agente-$ts.sql.gz"
      if backup_pg "$cid" crystal crystal_agente "$arq"; then novos+=("$arq"); else falhas+=("app: pg_dump do crystal_agente (memória da Crystal) falhou"); fi
    fi
  elif docker service inspect "${APP_STACK}_app_postgres" >/dev/null 2>&1; then
    aviso "o serviço do Postgres do app existe mas não está rodando"; falhas+=("app: Postgres fora do ar")
  fi
  # Arquivos que os alunos mandam pelo app (imagem, áudio).
  up=$VOLUMES/${APP_STACK}_app_uploads/_data
  if [ "$completo" = 1 ] && [ -d "$up" ]; then
    if arq=$(backup_tar "$up" crystal_uploads "$ts"); then
      ok "uploads do app em $arq ($(du -h "$arq" | cut -f1))"; novos+=("$arq")
    else
      falhas+=("app: tar dos uploads falhou")
    fi
  fi
  # O nosso Chatwoot (conversas da equipe e anexos), se estiver no ar. Segredos
  # guardados no banco só se leem com as ACTIVE_RECORD_ENCRYPTION_* do cofre.
  cid=$(docker ps -q -f name=crystal_atendimento_cw_postgres 2>/dev/null | head -1 || true)
  if [ -n "$cid" ]; then
    arq="$dir/chatwoot-$ts.sql.gz"
    if backup_pg "$cid" chatwoot chatwoot "$arq"; then novos+=("$arq"); else falhas+=("Chatwoot: pg_dump falhou"); fi
  elif docker service inspect crystal_atendimento_cw_postgres >/dev/null 2>&1; then
    aviso "o serviço do Postgres do Chatwoot existe mas não está rodando"; falhas+=("Chatwoot: Postgres fora do ar")
  fi
  up=$VOLUMES/crystal_atendimento_cw_storage/_data
  if [ "$completo" = 1 ] && [ -d "$up" ]; then
    if arq=$(backup_tar "$up" chatwoot_storage "$ts"); then
      ok "anexos do Chatwoot em $arq ($(du -h "$arq" | cut -f1))"; novos+=("$arq")
    else
      falhas+=("Chatwoot: tar dos anexos falhou")
    fi
  fi
  find "$dir" -maxdepth 1 \( -name 'n8n_queue-*' -o -name 'crystal_web_chat-*' -o -name 'crystal_agente-*' -o -name 'crystal_uploads-*' \
    -o -name 'chatwoot-*' -o -name 'chatwoot_storage-*' \) -mtime +14 -delete || true   # pega também os .age
  echo "  $(find "$dir" -maxdepth 1 \( -name '*.gz' -o -name '*.gz.age' \) | wc -l) arquivo(s) na VPS (14 dias; em claro só a última rodada)"
  echo "  Restaurar banco: gunzip -c ARQ | docker exec -i CID psql -U USUÁRIO -d BANCO"
  echo "    (.age: read -rsp 'chave: ' k; printf '%s\\n' \"\$k\" | age -d -i - ARQ.age | gunzip | docker exec -i CID psql ...; k=)"
  echo "  Restaurar pasta: tar -xzf ...-completo.tar.gz --listed-incremental=/dev/null -C DESTINO, depois o -diferencial mais novo"

  if [ -s "$FORA_CONF" ] && [ -s "$FORA_DEST" ]; then
    if [ ${#novos[@]} -gt 0 ]; then
      backup_fora "${novos[@]}" || falhas+=("R2: nem tudo subiu (ficou só na VPS)")
    fi
  elif [ -s "$BACKUPS/.fora-ultimo" ]; then
    # Já mandava para o R2 e a configuração sumiu: não é "não configurado" (achado 23).
    falhas+=("R2: a cópia fora da VPS parou (falta $FORA_CONF ou $FORA_DEST)")
  else
    aviso "cópia fora da VPS não configurada (backup-chave e backup-fora-config)"
  fi

  if [ ${#falhas[@]} -eq 0 ] && [ "$completo" = 0 ]; then
    # Só os bancos: não conta como backup completo para a vigia nem apaga a falha de um completo anterior.
    date -u +%FT%TZ > "$BACKUPS/.backup-bancos-ultimo"
    ok "backup dos bancos completo (fotos e anexos: no cron das 03:30)"
    return 0
  fi
  if [ ${#falhas[@]} -eq 0 ]; then
    date -u +%FT%TZ > "$BACKUPS/.backup-ultimo"
    rm -f "$BACKUPS/.backup-falhas"
    ok "backup completo"
    return 0
  fi
  printf '%s\n' "${falhas[@]}" > "$BACKUPS/.backup-falhas"
  echo "== backup INCOMPLETO: ${#falhas[@]} parte(s) falharam (o resto foi salvo e enviado)"
  printf '  !! %s\n' "${falhas[@]}"
  exit 1
}

# O cron (backup e vigia) roda a cópia em $BASE/bootstrap-vps.sh. Ela é trocada a cada
# app-subir e atendimento-subir (e no backup-cron e no vigia-config), sem esconder
# erro (achado 24). Troca por mv: o bash lê o script aos poucos, e sobrescrever no
# lugar quebraria um backup ou uma vigia rodando naquele instante.
copia_cron_atualizar() { # copia_cron_atualizar [--criar]
  local origem destino="$BASE/bootstrap-vps.sh"
  origem="$AQUI/$(basename "$0")"
  [ -f "$origem" ] || { aviso "não achei $origem para atualizar a cópia do cron"; return 0; }
  [ "$origem" -ef "$destino" ] && return 0
  [ -f "$destino" ] || [ "${1:-}" = "--criar" ] || return 0
  if [ -f "$destino" ] && cmp -s "$origem" "$destino"; then return 0; fi
  if cp "$origem" "$destino.novo" && chmod 700 "$destino.novo" && mv "$destino.novo" "$destino"; then
    ok "cópia do cron atualizada ($destino, sha256 $(sha256sum "$destino" | cut -c1-12))"
  else
    rm -f "$destino.novo"
    aviso "NÃO atualizei $destino: o backup e a vigia seguem com a versão antiga"
  fi
}

copia_cron_conferir() {
  local origem destino="$BASE/bootstrap-vps.sh" h1 h2
  origem="$AQUI/$(basename "$0")"
  [ -f "$destino" ] || { aviso "cópia do cron ($destino) não existe: bash $0 backup-cron"; return 0; }
  if [ "$origem" -ef "$destino" ]; then ok "rodando a própria cópia do cron"; return 0; fi
  [ -f "$origem" ] || return 0
  h1=$(sha256sum "$origem" | cut -c1-12); h2=$(sha256sum "$destino" | cut -c1-12)
  if [ "$h1" = "$h2" ]; then ok "cópia do cron igual a este script ($h1)"
  else aviso "a cópia do cron ($h2) é diferente deste script ($h1): o backup e a vigia rodam a antiga. Atualize: bash $0 backup-cron"; fi
}

# Horas desde a data UTC gravada num arquivo (ou desde o arquivo .gz mais novo, para
# o primeiro dia depois desta versão). "nunca" se não houver nada.
horas_desde() { # horas_desde ARQUIVO_COM_DATA
  local t=""
  [ -s "$1" ] && t=$(date -d "$(cat "$1")" +%s 2>/dev/null || true)
  if [ -z "$t" ] && [ "$1" = "$BACKUPS/.backup-ultimo" ]; then
    t=$(find "$BACKUPS" -maxdepth 1 \( -name '*.gz' -o -name '*.gz.age' \) -printf '%T@\n' 2>/dev/null | sort -n | tail -1 | cut -d. -f1 || true)
  fi
  if [ -n "$t" ]; then echo $(( ($(date +%s) - t) / 3600 )); else echo nunca; fi
}

backup_cron() {
  local linha="30 3 * * * root PATH=/usr/sbin:/usr/bin:/sbin:/bin /usr/bin/bash $BASE/bootstrap-vps.sh backup --completo >> $BACKUPS/backup.log 2>&1"
  mkdir -p "$BACKUPS"; chmod 700 "$BACKUPS"
  copia_cron_atualizar --criar
  printf '%s\n' "$linha" > /etc/cron.d/crystal-backup-n8n
  chmod 644 /etc/cron.d/crystal-backup-n8n
  ok "cron instalado em /etc/cron.d/crystal-backup-n8n: todo dia 03:30, log em $BACKUPS/backup.log"
  if [ -s "$FORA_CONF" ]; then ok "cada backup também vai cifrado para o R2"
  else aviso "só na VPS por enquanto: falta backup-chave e backup-fora-config"; fi
}

# ------------------------------------------------------------------ backup fora da VPS
# Cada arquivo do backup é cifrado aqui com age, para a chave PÚBLICA, e sobe para
# um bucket do Cloudflare R2 com trava (bucket lock) de 30 dias. Quem invadir a
# VPS acha a chave do R2, mas:
#   - não lê os backups: a chave privada nunca fica na VPS;
#   - não apaga nem sobrescreve: a trava do bucket recusa, mesmo com a chave.
# Envio pelo curl (assinatura S3 v4), sem instalar cliente; a chave do R2 vai ao
# curl pela entrada padrão, nunca na linha de comando (que aparece no ps).
fora_ler_conf() { # fora_ler_conf [ARQUIVO] (padrão: a configuração gravada)
  local conf="${1:-$FORA_CONF}"
  [ -s "$conf" ] || falha "R2 não configurado: bash $0 backup-fora-config"
  R2_CONTA=$(app_valor "$conf" R2_CONTA); R2_BUCKET=$(app_valor "$conf" R2_BUCKET)
  R2_CHAVE_ID=$(app_valor "$conf" R2_CHAVE_ID); R2_SEGREDO=$(app_valor "$conf" R2_SEGREDO)
  R2_URL="${R2_ENDPOINT:-https://$R2_CONTA.r2.cloudflarestorage.com}/$R2_BUCKET"
}

fora_curl() { # fora_curl ARGS... (credenciais pela entrada padrão)
  printf 'user = "%s:%s"\n' "$R2_CHAVE_ID" "$R2_SEGREDO" \
    | curl -K - -s -m 300 --aws-sigv4 "aws:amz:${R2_REGIAO:-auto}:s3" "$@"
}

fora_enviar() { # fora_enviar ARQUIVO CHAVE_NO_BUCKET -> 0 se o R2 confirmou
  local sha code resp tam
  # Envio num PUT só: o R2 recusa acima de 5 GiB. Avisa antes de travar (achado 25).
  tam=$(stat -c %s "$1" 2>/dev/null || echo 0)
  if [ "$tam" -gt 4900000000 ]; then
    aviso "$2 tem $(du -h "$1" | cut -f1): grande demais para um envio só ao R2 (limite 5 GiB). Ficou só na VPS"
    return 1
  fi
  sha=$(sha256sum "$1" | cut -d' ' -f1)
  resp=$(mktemp)
  code=$(fora_curl -o "$resp" -w '%{http_code}' -T "$1" -H "x-amz-content-sha256: $sha" "$R2_URL/$2") || code=000
  if [ "$code" = 200 ]; then rm -f "$resp"; return 0; fi
  aviso "R2 respondeu $code para $2: $(head -c 300 "$resp" | tr -d '\n')"
  rm -f "$resp"; return 1
}

backup_fora() { # backup_fora ARQUIVO... cifra e envia; volta 1 se algum não subiu
  command -v age >/dev/null || { aviso "age não instalado: bash $0 backup-chave"; return 1; }
  fora_ler_conf
  local dest a obj tmp erros=0
  backup_destinatario_conferir || return 1
  dest=$(cat "$FORA_DEST")
  echo "== fora da VPS (R2, bucket $R2_BUCKET)"
  for a in "$@"; do
    obj="$FORA_PREFIXO/$(basename "$a" | sed -E 's/-[0-9]{8}T.*//')/$(date -u +%Y/%m)/$(basename "$a").age"
    tmp=$(mktemp "$BACKUPS/.envio.XXXXXX")
    if devagar age -r "$dest" -o "$tmp" "$a" && fora_enviar "$tmp" "$obj"; then
      ok "$obj ($(du -h "$tmp" | cut -f1), cifrado)"
    else
      erros=$((erros+1))
    fi
    rm -f "$tmp"
  done
  if [ "$erros" -gt 0 ]; then
    aviso "$erros arquivo(s) não subiram para o R2. Ficaram só na VPS"
    return 1
  fi
  date -u +%FT%TZ > "$BACKUPS/.fora-ultimo"
}

backup_chave() {
  if [ -s "$FORA_DEST" ] && [ "${1:-}" != "--nova" ]; then
    ok "já existe chave: $(cat "$FORA_DEST")"
    echo "  Trocar só se a privada se perdeu ou vazou: bash $0 backup-chave --nova"
    echo "  (os backups antigos continuam abrindo só com a chave antiga)"
    return 0
  fi
  [ -t 0 ] && [ -t 1 ] || falha "rode num terminal (a chave aparece só no less)"
  command -v age-keygen >/dev/null || { apt-get -qq update >/dev/null; DEBIAN_FRONTEND=noninteractive apt-get -y -qq install age >/dev/null || falha "não instalou o age"; }
  local pub priv fim tent
  # Só em variável: a chave privada nunca é gravada em arquivo na VPS.
  priv=$(age-keygen 2>/dev/null | grep -E '^AGE-SECRET-KEY-1[0-9A-Z]+$' || true)
  pub=$(printf '%s\n' "$priv" | age-keygen -y 2>/dev/null || true)
  [ -n "$priv" ] && echo "$pub" | grep -Eq '^age1[0-9a-z]+$' || falha "age-keygen não gerou a chave"
  for tent in 1 2 3; do
    {
      echo "CHAVE PRIVADA DOS BACKUPS. Copie a linha AGE-SECRET-KEY-... inteira para um item"
      echo "novo no Bitwarden (\"Crystal backup age\"). Sem ela, NENHUM backup abre."
      echo "Ela não fica na VPS: ao fechar (q), some. Não cole em chat nem em e-mail."
      echo
      echo "$priv"
      echo
      echo "(chave pública, que fica na VPS: $pub)"
    } | less -K
    read -rp "Digite os 6 ÚLTIMOS caracteres da chave, lendo do Bitwarden: " fim
    fim=$(echo "$fim" | tr -d ' ' | tr '[:lower:]' '[:upper:]')
    if [ "${#fim}" -eq 6 ] && [ "${priv: -6}" = "$fim" ]; then
      umask 077; echo "$pub" > "$FORA_DEST"; chmod 600 "$FORA_DEST"
      priv=""
      ok "chave pública gravada em $FORA_DEST; a privada só no Bitwarden"
      echo "  Guarde também a PÚBLICA no mesmo item do Bitwarden (é ela que o status mostra, $(backup_destinatario_resumo)):"
      echo "  $pub"
      echo "  Para a VPS se recusar a cifrar para outra (INF-18): FORA_DEST_ESPERADO=\"$pub\" no topo do script (é pública)."
      echo "Próximo: bash $0 backup-fora-config"
      return 0
    fi
    aviso "não confere. Mostrando de novo ($tent de 3)"
  done
  priv=""
  falha "nada gravado. Rode de novo quando der para salvar no Bitwarden"
}

backup_fora_config() {
  [ -s "$FORA_DEST" ] || falha "primeiro: bash $0 backup-chave"
  [ -t 0 ] || falha "rode num terminal"
  local conta bucket id seg t
  echo "Dados do R2 (Cloudflare > R2). O segredo não aparece enquanto você digita."
  read -rp "Account ID (32 caracteres, na página inicial do R2): " conta
  echo "$conta" | grep -Eq '^[0-9a-f]{32}$' || falha "Account ID inválido"
  read -rp "Nome do bucket [crystal-backups]: " bucket; bucket=${bucket:-crystal-backups}
  echo "$bucket" | grep -Eq '^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$' || falha "nome de bucket inválido"
  read -rp "Access Key ID (32 caracteres): " id
  echo "$id" | grep -Eq '^[0-9a-f]{32}$' || falha "Access Key ID inválido (é o de 32 caracteres, não o token de 40)"
  read -rsp "Secret Access Key (64 caracteres, não aparece): " seg; echo
  echo "$seg" | grep -Eq '^[0-9a-f]{64}$' || { seg=""; falha "Secret Access Key inválida (64 caracteres hexadecimais)"; }
  mkdir -p "$BACKUPS"; chmod 700 "$BACKUPS"
  umask 077
  printf 'R2_CONTA=%s\nR2_BUCKET=%s\nR2_CHAVE_ID=%s\nR2_SEGREDO=%s\n' "$conta" "$bucket" "$id" "$seg" > "$FORA_CONF.novo"
  chmod 600 "$FORA_CONF.novo"
  seg=""
  echo "== teste de envio (com os dados novos; a configuração atual segue valendo até o teste passar)"
  local conf_ok=0
  fora_ler_conf "$FORA_CONF.novo"
  t=$(mktemp "$BACKUPS/.teste.XXXXXX")
  echo "teste $(date -u +%FT%TZ)" | age -r "$(cat "$FORA_DEST")" -o "$t"
  fora_enviar "$t" "$FORA_PREFIXO/teste/$(date -u +%Y%m%dT%H%M%SZ).age" && conf_ok=1
  rm -f "$t"
  if [ "$conf_ok" -ne 1 ]; then
    rm -f "$FORA_CONF.novo"
    # Antes, a configuração boa era apagada aqui e o backup parava de ir ao R2 em
    # silêncio (achado 23). Agora ela fica como estava.
    if [ -s "$FORA_CONF" ]; then
      falha "o envio de teste falhou (Account ID, bucket ou chave?). A configuração anterior continua valendo; rode de novo"
    fi
    falha "o envio de teste falhou (Account ID, bucket ou chave?). Nada gravado; rode de novo"
  fi
  mv "$FORA_CONF.novo" "$FORA_CONF"; chmod 600 "$FORA_CONF"
  ok "R2 aceitou o envio; dados gravados em $FORA_CONF"
  backup_cron
  echo "Próximo: bash $0 backup   (faz um backup agora e manda pro R2)"
}

# Link temporário (10 min) para baixar o backup mais novo de um tipo, para o teste
# de restauração no Mac sem passar pelo painel. O link só baixa aquele arquivo, que
# está cifrado; mesmo assim, não colar em chat.
backup_link() {
  local tipo="${1:-n8n_queue}" xml code
  echo "$tipo" | grep -Eq '^(n8n_queue|crystal_web_chat|crystal_agente|crystal_uploads|chatwoot|chatwoot_storage)$' \
    || falha "tipo: n8n_queue, crystal_web_chat, crystal_agente, crystal_uploads, chatwoot ou chatwoot_storage"
  fora_ler_conf
  xml=$(mktemp)
  code=$(fora_curl -o "$xml" -w '%{http_code}' "$R2_URL?list-type=2&prefix=$FORA_PREFIXO") || code=000
  if [ "$code" != 200 ]; then aviso "listagem do R2 respondeu $code"; rm -f "$xml"; exit 1; fi
  R2_URL="$R2_URL" R2_CHAVE_ID="$R2_CHAVE_ID" R2_SEGREDO="$R2_SEGREDO" R2_REGIAO="${R2_REGIAO:-auto}" \
    python3 - "$xml" "$FORA_PREFIXO/$tipo/" <<'PY'
import datetime, hashlib, hmac, os, sys, urllib.parse, xml.etree.ElementTree as ET
ns = {'s': 'http://s3.amazonaws.com/doc/2006-03-01/'}
chaves = sorted(c.find('s:Key', ns).text for c in ET.parse(sys.argv[1]).getroot().findall('s:Contents', ns)
                if c.find('s:Key', ns).text.startswith(sys.argv[2]))
if not chaves:
    sys.exit("ERRO: nenhum backup desse tipo no R2")
# Pastas (uploads, anexos) vêm em tar incremental: restaurar pede o último completo
# (ou um antigo, sem sufixo) e o diferencial mais novo depois dele.
if sys.argv[2].rstrip('/').endswith(('crystal_uploads', 'chatwoot_storage')):
    completos = [i for i, c in enumerate(chaves) if '-diferencial' not in c]
    if not completos:
        sys.exit("ERRO: nenhum backup completo desse tipo no R2")
    escolhidas = [chaves[completos[-1]]]
    dif = [c for c in chaves[completos[-1] + 1:] if '-diferencial' in c]
    if dif:
        escolhidas.append(dif[-1])
else:
    escolhidas = [chaves[-1]]
base = urllib.parse.urlsplit(os.environ['R2_URL'])
agora = datetime.datetime.now(datetime.timezone.utc)
data, carimbo = agora.strftime('%Y%m%d'), agora.strftime('%Y%m%dT%H%M%SZ')
escopo = f"{data}/{os.environ['R2_REGIAO']}/s3/aws4_request"
k = ('AWS4' + os.environ['R2_SEGREDO']).encode()
for parte in (data, os.environ['R2_REGIAO'], 's3', 'aws4_request'):
    k = hmac.new(k, parte.encode(), hashlib.sha256).digest()
print("Link válido por 10 minutos. No Terminal do Mac, cole cada linha curl INTEIRA (não cole em chat):")
for chave in escolhidas:
    host, caminho = base.netloc, base.path + '/' + urllib.parse.quote(chave, safe='/')
    q = {'X-Amz-Algorithm': 'AWS4-HMAC-SHA256', 'X-Amz-Credential': f"{os.environ['R2_CHAVE_ID']}/{escopo}",
         'X-Amz-Date': carimbo, 'X-Amz-Expires': '600', 'X-Amz-SignedHeaders': 'host'}
    qs = '&'.join(f"{urllib.parse.quote(kk, safe='')}={urllib.parse.quote(v, safe='')}" for kk, v in sorted(q.items()))
    canon = '\n'.join(['GET', caminho, qs, f'host:{host}', '', 'host', 'UNSIGNED-PAYLOAD'])
    assinar = '\n'.join(['AWS4-HMAC-SHA256', carimbo, escopo, hashlib.sha256(canon.encode()).hexdigest()])
    sig = hmac.new(k, assinar.encode(), hashlib.sha256).hexdigest()
    nome = chave.rsplit('/', 1)[-1]
    print()
    print(f"Backup: {chave}")
    print(f"curl -fo ~/Downloads/{nome} '{base.scheme}://{host}{caminho}?{qs}&X-Amz-Signature={sig}'")
if len(escolhidas) > 1:
    print()
    print("Restaurar: extrair o -completo e depois o -diferencial, os dois com tar --listed-incremental=/dev/null")
PY
  rm -f "$xml"
}

# Prova a trava do bucket: sobe um arquivo de teste e tenta apagá-lo com a própria
# chave da VPS (que tem permissão de apagar). Com a trava, o R2 recusa.
backup_testar_trava() {
  fora_ler_conf
  local t obj code
  t=$(mktemp "$BACKUPS/.teste.XXXXXX")
  echo "teste da trava $(date -u +%FT%TZ)" | age -r "$(cat "$FORA_DEST")" -o "$t"
  obj="$FORA_PREFIXO/teste/trava-$(date -u +%Y%m%dT%H%M%SZ).age"
  fora_enviar "$t" "$obj" || { rm -f "$t"; falha "não subiu o arquivo de teste"; }
  rm -f "$t"
  code=$(fora_curl -o /dev/null -w '%{http_code}' -X DELETE "$R2_URL/$obj") || code=000
  # Só a recusa da retenção (403) seguida do arquivo ainda lá (HEAD 200) prova a
  # trava. 5xx, 429 e outros códigos são inconclusivos (achado 69).
  case "$code" in
    200|204) aviso "o R2 APAGOU o arquivo (resposta $code): a trava NÃO está valendo. Conferir Settings > Bucket lock rules (prefixo vazio, 30 dias)"; exit 1 ;;
    000) aviso "sem resposta do R2; rode de novo" ; exit 1 ;;
    403)
      local h
      h=$(fora_curl -o /dev/null -w '%{http_code}' -I "$R2_URL/$obj") || h=000
      if [ "$h" = 200 ]; then
        ok "o R2 recusou apagar (403) e o arquivo continua lá (HEAD 200): a trava está valendo. Quem invadir a VPS não apaga os backups"
      else
        aviso "o R2 recusou apagar (403), mas o HEAD respondeu $h: inconclusivo. Rode de novo"; exit 1
      fi ;;
    *) aviso "o R2 respondeu $code ao apagar: não é a recusa da trava (403). Inconclusivo: rode de novo e, se repetir, conferir Settings > Bucket lock rules"; exit 1 ;;
  esac
}

backup_conferir() {
  fora_ler_conf
  local xml code
  if [ -s "$FORA_DEST" ]; then
    if backup_destinatario_conferir; then
      ok "chave pública dos backups: $(backup_destinatario_resumo) (compare com o Bitwarden$([ -n "$FORA_DEST_ESPERADO" ] && echo '; igual à esperada do script'))"
    fi
  fi
  xml=$(mktemp)
  code=$(fora_curl -o "$xml" -w '%{http_code}' "$R2_URL?list-type=2&prefix=$FORA_PREFIXO") || code=000
  if [ "$code" != 200 ]; then aviso "listagem do R2 respondeu $code: $(head -c 300 "$xml")"; rm -f "$xml"; exit 1; fi
  python3 - "$xml" <<'PY'
import sys, datetime, xml.etree.ElementTree as ET
ns = {'s': 'http://s3.amazonaws.com/doc/2006-03-01/'}
itens = [(c.find('s:Key', ns).text, int(c.find('s:Size', ns).text), c.find('s:LastModified', ns).text)
         for c in ET.parse(sys.argv[1]).getroot().findall('s:Contents', ns)]
itens.sort(key=lambda i: i[2])
print(f"  {len(itens)} objeto(s) no R2 (a listagem mostra até 1000)")
for k, t, m in itens[-9:]:
    print(f"  {m[:19].replace('T', ' ')}  {t/1024:9.1f} KB  {k}")
reais = [i for i in itens if '/teste/' not in i[0]]
if reais:
    ult = datetime.datetime.fromisoformat(reais[-1][2].replace('Z', '+00:00'))
    h = (datetime.datetime.now(datetime.timezone.utc) - ult).total_seconds() / 3600
    print(("  ok" if h < 26 else "  !") + f" último backup no R2 há {h:.0f} h")
else:
    print("  ! nenhum backup de verdade no R2 ainda")
PY
  rm -f "$xml"
}

# ------------------------------------------------------------------ portas do Docker
# O Docker publica porta por iptables próprio, por cima do ufw: o "só 22, 80 e 443"
# do ufw não vale para o que um serviço publicar (achado 73). Confere o que está
# publicado em todas as interfaces e aponta o que não for 80 ou 443.
portas_docker_conferir() {
  local extras
  extras=$( { docker service ls --format '{{.Name}} {{.Ports}}' 2>/dev/null; docker ps --format '{{.Names}} {{.Ports}}' 2>/dev/null; } \
    | awk '{ n=$1; $1=""; s=$0
             while (match(s, /(\*|0\.0\.0\.0|::|\[::\]):[0-9]+->/)) {
               p=substr(s, RSTART, RLENGTH); sub(/->$/, "", p); sub(/.*:/, "", p)
               if (p != "80" && p != "443") print n " publica a porta " p
               s=substr(s, RSTART + RLENGTH) } }' | sort -u || true)
  if [ -z "$extras" ]; then
    ok "o Docker só publica 80 e 443 (o resto o ufw fecha)"
  else
    printf '%s\n' "$extras" | while read -r l; do aviso "PORTA ABERTA PARA A INTERNET pelo Docker, por cima do ufw: $l"; done
  fi
}

# ------------------------------------------------------------------ firewall
# Nó único: ninguém de fora precisa falar com o Swarm. O Docker publica 80 e
# 443 por conta própria (passa por cima do ufw), então o que o ufw realmente
# fecha são as portas do Swarm e qualquer coisa que subir por engano. O Web
# console da Hostinger continua funcionando mesmo se o SSH for bloqueado.
firewall() {
  command -v ufw >/dev/null || { apt-get -qq update >/dev/null; DEBIAN_FRONTEND=noninteractive apt-get -y -qq install ufw >/dev/null; }
  ufw default deny incoming >/dev/null
  ufw default allow outgoing >/dev/null
  ufw allow 22/tcp comment 'ssh' >/dev/null
  ufw allow 80/tcp comment 'traefik http' >/dev/null
  ufw allow 443/tcp comment 'traefik https' >/dev/null
  ufw --force enable >/dev/null
  ok "ufw ativo: entrada só 22, 80 e 443 (o que o Docker publica passa por cima: conferido abaixo)"
  ufw status | sed 's/^/  /'
  portas_docker_conferir
  echo "  Conferir de fora: as três URLs em HTTPS continuam respondendo (bash $0 status)."
}

# ------------------------------------------------------------------ seguranca
# Proteções da máquina contra ataque e malware que não mexem em nenhum serviço:
#   - atualização de segurança automática do Ubuntu (sem reiniciar sozinho);
#   - fail2ban no SSH: 5 tentativas erradas em 10 min bloqueiam o IP por 1 hora;
#   - SSH só com chave quando já há chave de root (ssh_travar, com volta automática);
#   - relatório do que ainda depende de decisão: portas abertas, pendências.
# O Web console da Hostinger continua funcionando mesmo com um IP bloqueado.
seguranca() {
  export DEBIAN_FRONTEND=noninteractive
  echo "== pacotes"
  apt-get -qq update >/dev/null
  apt-get -y -qq install unattended-upgrades fail2ban python3-systemd >/dev/null || falha "não instalou os pacotes"
  cat > /etc/apt/apt.conf.d/20auto-upgrades <<'CFG'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
CFG
  ok "atualização de segurança automática ligada (sem reinício automático)"

  cat > /etc/fail2ban/jail.d/crystal.local <<'CFG'
[sshd]
enabled  = true
backend  = systemd
maxretry = 5
findtime = 10m
bantime  = 1h
CFG
  systemctl enable fail2ban >/dev/null 2>&1 || true
  systemctl restart fail2ban || falha "fail2ban não subiu: journalctl -u fail2ban"
  sleep 2
  fail2ban-client status sshd >/dev/null 2>&1 && ok "fail2ban protegendo o SSH" || aviso "fail2ban no ar, mas a regra do SSH não respondeu: fail2ban-client status sshd"

  echo "== SSH"
  ssh_travar
  echo "== quem fala com o Docker (lê os segredos do spec dos serviços)"
  docker_acesso_conferir
  echo "== o que ainda depende de decisão"
  ufw status 2>/dev/null | grep -q "Status: active" && ok "ufw ativo" || aviso "ufw desligado: bash $0 firewall"
  portas_docker_conferir
  echo "  Portas escutando (o ufw deixa 22, 80 e 443; as do Swarm, 2377, 7946 e 4789, ele fecha; porta publicada pelo Docker passa por cima, conferida acima):"
  ss -Htlnp 2>/dev/null | awk '{print $4}' | grep -vE '^(127\.|\[::1\])' | sed -E 's/.*:([0-9]+)$/\1/' | sort -un | tr '\n' ' ' | sed 's/^/    /'; echo
  local up; up=$(apt list --upgradable 2>/dev/null | grep -c -- '-security' || true)
  [ "${up:-0}" -gt 0 ] && aviso "$up pacote(s) de segurança pendentes; a atualização automática aplica hoje à noite" || ok "sem atualização de segurança pendente"
  [ -f /var/run/reboot-required ] && aviso "o Ubuntu pede reinício para aplicar atualização do kernel: agende na madrugada" || true
}

# ------------------------------------------------------------------ SSH só com chave
# Revisão de 24/10 (INF-11): com chave de root já instalada, o seguranca trava o SSH em só
# chave (PasswordAuthentication no, KbdInteractiveAuthentication no) e root só com chave
# (PermitRootLogin prohibit-password), num arquivo próprio em sshd_config.d, conferido com
# sshd -t antes de recarregar. Sem chave, só avisa, como antes. Conta só linha de chave
# sem opções (uma chave com command= ou from= não garante entrada).
# Rede de segurança contra ficar trancado do lado de fora: quando a trava é nova, ela se
# desfaz sozinha em 10 minutos (systemd-run), a menos que o dono entre por OUTRA janela e
# rode 'bash bootstrap-vps.sh ssh-confirmar'. A sessão aberta não cai com o reload.
# Volta a qualquer hora: bash bootstrap-vps.sh ssh-voltar
SSH_TRAVA=/etc/ssh/sshd_config.d/00-crystal.conf
SSH_VOLTA_UNIT=crystal-ssh-volta

ssh_recarregar() { systemctl reload-or-restart ssh 2>/dev/null || systemctl reload-or-restart sshd; }

ssh_efetivo() { # ssh_efetivo -> "senha root" como o sshd entende agora (ex.: "no without-password")
  mkdir -p /run/sshd
  sshd -T 2>/dev/null | awk '/^passwordauthentication /{p=$2} /^permitrootlogin /{r=$2} END{print p" "r}'
}

ssh_travar() {
  local chaves novo mudou=0 pw root
  chaves=$(grep -cE '^[[:space:]]*(ssh-(ed25519|rsa)|ecdsa-sha2-nistp(256|384|521)|sk-(ssh-ed25519|ecdsa-sha2-nistp256)@openssh\.com)[[:space:]]+[A-Za-z0-9+/]{40,}={0,3}([[:space:]]|$)' \
    /root/.ssh/authorized_keys 2>/dev/null || true)
  if [ "${chaves:-0}" -eq 0 ]; then
    read -r pw root <<<"$(ssh_efetivo)"
    if [ "$pw" = "yes" ]; then
      aviso "SSH aceita senha e não há chave de root em /root/.ssh/authorized_keys: a trava NÃO foi aplicada."
      aviso "Ponha a sua chave (hPanel > VPS > Chaves SSH, ou ssh-copy-id root@IP), confira que entra com ela e rode 'seguranca' de novo."
    else
      ok "SSH não aceita senha"
    fi
    [ "$root" = "yes" ] && aviso "root entra por SSH com senha (sem chave instalada, a trava espera)" || ok "root: $root"
    return 0
  fi
  ok "$chaves chave(s) de root em /root/.ssh/authorized_keys"
  novo=$(mktemp)
  cat > "$novo" <<'CFG'
# Gravado por bootstrap-vps.sh seguranca (revisão de segurança de 24/10, INF-11).
# Só chave; root só com chave. Volta: bash bootstrap-vps.sh ssh-voltar
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin prohibit-password
CFG
  if [ -f "$SSH_TRAVA" ] && cmp -s "$novo" "$SSH_TRAVA"; then
    rm -f "$novo"
  else
    mudou=1
    # A volta automática é agendada ANTES de a trava existir: nunca há trava nova sem ela.
    systemctl stop "$SSH_VOLTA_UNIT.timer" >/dev/null 2>&1 || true
    systemctl reset-failed "$SSH_VOLTA_UNIT.service" "$SSH_VOLTA_UNIT.timer" >/dev/null 2>&1 || true
    if ! systemd-run --quiet --unit="$SSH_VOLTA_UNIT" --on-active=10min /bin/sh -c \
         "rm -f $SSH_TRAVA; systemctl reload-or-restart ssh || systemctl reload-or-restart sshd"; then
      rm -f "$novo"
      aviso "não consegui agendar a volta automática (systemd-run): trava NÃO aplicada, por segurança"
      return 0
    fi
    install -m 644 "$novo" "$SSH_TRAVA"; rm -f "$novo"
  fi
  mkdir -p /run/sshd
  if ! sshd -t; then
    rm -f "$SSH_TRAVA"; systemctl stop "$SSH_VOLTA_UNIT.timer" >/dev/null 2>&1 || true
    aviso "sshd -t recusou a configuração (acima): $SSH_TRAVA tirado e nada recarregado"
    return 0
  fi
  if [ "$mudou" = 1 ] && ! ssh_recarregar; then
    rm -f "$SSH_TRAVA"; systemctl stop "$SSH_VOLTA_UNIT.timer" >/dev/null 2>&1 || true
    aviso "o ssh não recarregou: trava tirada, SSH como estava"
    return 0
  fi
  read -r pw root <<<"$(ssh_efetivo)"
  if [ "$pw" = no ] && { [ "$root" = prohibit-password ] || [ "$root" = without-password ]; }; then
    ok "SSH só com chave; root só com chave ($SSH_TRAVA)"
  else
    aviso "a trava está em $SSH_TRAVA, mas o sshd ainda diz senha=$pw root=$root: outro arquivo vence (ver as linhas antes do Include em /etc/ssh/sshd_config)"
  fi
  if [ "$mudou" = 1 ]; then
    echo "  !! AGORA, sem fechar esta janela: abra OUTRA (terminal do navegador da Hostinger ou ssh com a"
    echo "  !! chave) e entre como root. Entrou? Nela: bash $0 ssh-confirmar"
    echo "  !! Não entrou? Não faça nada: em 10 minutos a trava se desfaz sozinha (ou: bash $0 ssh-voltar aqui)."
  elif systemctl is-active --quiet "$SSH_VOLTA_UNIT.timer" 2>/dev/null; then
    aviso "a volta automática do SSH ainda está agendada: confirme de outra janela com bash $0 ssh-confirmar"
  fi
}

ssh_confirmar() {
  if systemctl is-active --quiet "$SSH_VOLTA_UNIT.timer" 2>/dev/null; then
    systemctl stop "$SSH_VOLTA_UNIT.timer" || falha "não cancelei a volta automática: systemctl stop $SSH_VOLTA_UNIT.timer"
    ok "volta automática cancelada: o SSH fica só com chave"
  else
    [ -f "$SSH_TRAVA" ] && ok "nada agendado: a trava do SSH já está firme" || aviso "não há trava do SSH (passou dos 10 minutos? rode seguranca de novo)"
  fi
}

ssh_voltar() {
  systemctl stop "$SSH_VOLTA_UNIT.timer" >/dev/null 2>&1 || true
  rm -f "$SSH_TRAVA"
  ssh_recarregar || falha "o ssh não recarregou: systemctl status ssh"
  ok "trava do SSH tirada: volta a valer o que o /etc/ssh/sshd_config diz"
}

# ------------------------------------------------------------------ painel (Portainer)
# O Portainer manda em todo o Docker da VPS e guarda o token do ghcr. Aberto na
# internet, só a senha o protege (o CE não tem 2FA). painel-restringir sobe o
# stacks-app/01-portainer-restrito.yaml: 403 do Traefik para quem não está na
# lista, agente numa rede interna e imagens presas no digest que já roda.
# IP mudou? Pelo Web console da Hostinger (que não depende de IP), rode de novo
# com o IP novo.
PAINEL_YAML=01-portainer-restrito.yaml

painel_validar() { # painel_validar IP... -> lista normalizada, uma por linha
  python3 - "$@" <<'PY'
import ipaddress, sys
saida = []
for a in sys.argv[1:]:
    try:
        n = ipaddress.ip_network(a.strip(), strict=False)
    except ValueError:
        sys.exit(f"ERRO: '{a}' não é IP nem faixa (ex.: 189.1.2.3 ou 189.1.2.0/24)")
    minimo = 16 if n.version == 4 else 48
    if n.prefixlen < minimo:
        sys.exit(f"ERRO: {n} é larga demais (mínimo /{minimo})")
    if not n.is_global:
        sys.exit(f"ERRO: {n} não é IP público. O seu aparece em https://1.1.1.1/cdn-cgi/trace, na linha ip=")
    if str(n) not in saida:
        saida.append(str(n))
print("\n".join(saida))
PY
}

painel_imagem() { # painel_imagem portainer|agent -> imagem@digest que está rodando
  local img
  img=$(docker service inspect "portainer_$1" --format '{{.Spec.TaskTemplate.ContainerSpec.Image}}' 2>/dev/null || true)
  echo "$img" | grep -Eq '^(docker\.io/)?portainer/(portainer-ce|agent):[A-Za-z0-9._-]+@sha256:[0-9a-f]{64}$' || return 1
  echo "$img"
}

painel_gerar() { # grava $STACKS/01-portainer.yaml restrito, a partir do modelo e da lista
  [ -s "$PAINEL_IPS_ARQ" ] || { aviso "sem lista de IPs em $PAINEL_IPS_ARQ"; return 1; }
  local pimg aimg ips
  pimg=$(painel_imagem portainer) || { aviso "serviço portainer_portainer não encontrado com imagem@digest: suba antes com 'bash $0 portainer'"; return 1; }
  aimg=$(painel_imagem agent) || { aviso "serviço portainer_agent não encontrado com imagem@digest"; return 1; }
  ips=$(paste -sd, "$PAINEL_IPS_ARQ")
  mkdir -p "$ORIG" "$STACKS"; chmod 700 "$BASE" "$STACKS"
  baixar_conferido "stacks-app/$PAINEL_YAML" "$ORIG/$PAINEL_YAML" || { aviso "sem $PAINEL_YAML conferido"; return 1; }
  grep -q 'ipallowlist.sourcerange=PAINEL_IPS' "$ORIG/$PAINEL_YAML" || { aviso "$PAINEL_YAML não é o modelo esperado"; return 1; }
  umask 077
  # Guarda a versão aberta uma vez, para voltar atrás se precisar.
  if [ -f "$STACKS/01-portainer.yaml" ] && ! grep -q ipallowlist "$STACKS/01-portainer.yaml"; then
    cp "$STACKS/01-portainer.yaml" "$STACKS/01-portainer.yaml.aberto"
  fi
  sed -e "s|PAINEL_IPS|$ips|g" -e "s|PORTAINER_IMG|$pimg|g" -e "s|AGENT_IMG|$aimg|g" \
    "$ORIG/$PAINEL_YAML" > "$STACKS/01-portainer.yaml"
  chmod 600 "$STACKS/01-portainer.yaml"
  redes_ajustar "$STACKS/01-portainer.yaml"
  if grep -nE 'PAINEL_IPS|PORTAINER_IMG|AGENT_IMG' "$STACKS/01-portainer.yaml" | grep -vE '^\s*[0-9]+:\s*#' | grep -q .; then
    aviso "marcador sobrando em $STACKS/01-portainer.yaml"; return 1
  fi
  ok "01-portainer.yaml restrito: $(paste -sd' ' "$PAINEL_IPS_ARQ")"
  ok "imagens presas: $pimg e $aimg"
}

painel_restringir() {
  if [ $# -eq 0 ]; then
    if [ -s "$PAINEL_IPS_ARQ" ]; then
      echo "painel. liberado só para:"; sed 's/^/  /' "$PAINEL_IPS_ARQ"
    else
      echo "painel. está aberto para qualquer IP."
    fi
    echo
    echo "Para liberar: no computador de quem vai usar o painel, abra https://1.1.1.1/cdn-cgi/trace"
    echo "e copie o número da linha ip=. Depois: bash $0 painel-restringir ESSE_IP [OUTRO_IP ...]"
    echo "A lista nova SUBSTITUI a anterior (ponha todos de uma vez)."
    return 0
  fi
  local lista
  lista=$(painel_validar "$@") || exit 2
  umask 077
  printf '%s\n' "$lista" > "$PAINEL_IPS_ARQ.novo"
  mv "$PAINEL_IPS_ARQ.novo" "$PAINEL_IPS_ARQ"
  painel_gerar || exit 2
  redes_exigir_traefik borda_painel
  echo "== portainer (o painel fica fora do ar por uns segundos)"
  local t0; t0=$(date +%s)
  docker stack deploy -c "$STACKS/01-portainer.yaml" portainer --detach=true >/dev/null
  sleep 8   # deixa o Swarm registrar a atualização antes de conferir
  esperar_stack portainer 240 || exit 1
  conferir_atualizacao "$t0" - portainer_portainer portainer_agent || falha "o Portainer não ficou de pé com a lista nova (log acima)"
  painel_conferir
}

painel_conferir() {
  echo "== conferindo (o Traefik leva até 30 s para ler a regra nova)"
  local code="" t=0 cid
  while :; do
    code=$(curl -s -o /dev/null -m 10 -w '%{http_code}' "https://painel.$DOMINIO/" 2>/dev/null) || true
    [ "$code" = "403" ] || [ $t -ge 60 ] && break
    sleep 5; t=$((t+5))
  done
  if [ "$code" = "403" ]; then
    ok "https://painel.$DOMINIO -> 403 para quem não está na lista (a própria VPS é um deles)"
  else
    aviso "https://painel.$DOMINIO -> ${code:-000} vindo da VPS; o esperado era 403. Ver: docker service logs --tail 50 traefik_traefik"
  fi
  # Um contêiner da rede pública (o n8n) não pode mais chegar ao agente.
  cid=$(docker ps -q -f name=n8n_editor_n8n_editor | head -1)
  if [ -n "$cid" ]; then
    if docker exec "$cid" node -e "const s=require('net').connect(9001,'portainer_agent');s.on('connect',()=>process.exit(0));s.on('error',()=>process.exit(1));setTimeout(()=>process.exit(1),4000)" >/dev/null 2>&1; then
      aviso "o n8n ainda alcança o agente do Portainer (porta 9001)"
    else
      ok "o n8n não alcança mais o agente do Portainer"
    fi
    # Desde 24/10 (INF-06) a tela do Portainer está na borda_painel: o n8n também não chega à
    # porta 9000 (por fora do Traefik e da lista de IPs).
    if ! redes_unica && tcp_de "$cid" portainer 9000; then
      aviso "o n8n alcança a tela do Portainer (porta 9000) por fora do Traefik: bash $0 redes-conferir"
    elif ! redes_unica; then
      ok "o n8n não alcança a tela do Portainer (9000)"
    fi
  fi
  echo "  Agora, de um IP liberado: abra https://painel.$DOMINIO, entre, e confira que o ambiente"
  echo "  'primary' aparece como up. Se não aparecer: docker service logs --tail 50 portainer_portainer"
  echo "  Voltar ao aberto (só em emergência): docker stack deploy -c $STACKS/01-portainer.yaml.aberto portainer"
}

# A lista do arquivo não basta: confere a trava no serviço que está no ar (achado 34).
# Ela é também a defesa dos segredos do app e do Chatwoot: no Swarm o env_file é lido no
# deploy e os valores vão para o spec do serviço (ContainerSpec.Env), que o Portainer
# mostra a quem entrar nele e 'docker service inspect' imprime (INF-05, 24/10). Docker
# secrets ficam para a onda de infra. Devolve 1 quando o painel não está restrito.
painel_trava_conferir() {
  local trava
  trava=$(docker service inspect portainer_portainer --format '{{index .Spec.Labels "traefik.http.middlewares.portainer-ips.ipallowlist.sourcerange"}}' 2>/dev/null || true)
  if [ -s "$PAINEL_IPS_ARQ" ] && [ -n "$trava" ] && [ "$trava" != "<no value>" ]; then
    ok "painel. liberado só para: $trava (conferido no serviço no ar)"
    return 0
  elif [ -s "$PAINEL_IPS_ARQ" ]; then
    aviso "a lista de IPs existe, mas o Portainer no ar está SEM a trava: bash $0 painel-restringir $(paste -sd' ' "$PAINEL_IPS_ARQ")"
  else
    aviso "painel. (Portainer) aberto para qualquer IP: bash $0 painel-restringir"
  fi
  return 1
}

# Depois de subir uma stack com segredo em env_file (app, Chatwoot).
painel_trava_segredos() {
  painel_trava_conferir \
    || aviso "com o painel aberto, quem entrar no Portainer lê os segredos desta stack no spec dos serviços (env_file). Restrinja o painel antes de seguir"
}

painel_desligar() {
  docker service scale portainer_portainer=0 --detach=false >/dev/null || falha "não desligou"
  ok "Portainer fora do ar (o agente segue, na rede interna). Religar: bash $0 painel-ligar"
}

painel_ligar() {
  docker service scale portainer_portainer=1 --detach=false >/dev/null || falha "não ligou"
  ok "Portainer no ar"
  [ -s "$PAINEL_IPS_ARQ" ] || aviso "painel. aberto para qualquer IP: bash $0 painel-restringir"
}

# ------------------------------------------------------------------ quem fala com o Docker
# Revisão de 24/10 (INF-05, INF-29). Os valores dos env_file do app e do Chatwoot vão para o spec
# dos serviços no Swarm (docker service inspect, tela do Portainer). Docker secrets não servem
# aqui: as imagens do app e do Chatwoot leem só variável de ambiente (nenhuma lê NOME_FILE), e um
# command que exportasse /run/secrets/* mudaria o boot dos quatro serviços sem ensaio. Então a
# defesa é deixar o spec ao alcance só do root: ninguém no grupo docker, docker.sock só do root e
# do grupo docker, nada da API do Docker em TCP, o Portainer só para IPs liberados
# (painel-restringir) e o Traefik pelo proxy só de leitura (INF-22). Também confere a credencial
# do ghcr.io guardada pelo docker login (/root/.docker/config.json, base64): 600 e com idade.
GHCR_DESDE="$BASE/.ghcr-desde"
docker_acesso_conferir() {
  local membros modo dias
  membros=$(getent group docker 2>/dev/null | cut -d: -f4 || true)
  if [ -n "$membros" ]; then
    aviso "no grupo docker (equivale a root e lê os segredos do spec dos serviços): $membros. Tirar: gpasswd -d USUÁRIO docker"
  else
    ok "ninguém no grupo docker: só o root lê o spec dos serviços (docker service inspect)"
  fi
  modo=$(stat -c '%a %U:%G' /var/run/docker.sock 2>/dev/null || true)
  case "$modo" in
    "660 root:docker"|"660 root:root"|"600 root:root") ok "docker.sock $modo" ;;
    "") aviso "não achei /var/run/docker.sock" ;;
    *) aviso "docker.sock com permissão $modo (esperado 660 root:docker): chmod 660 /var/run/docker.sock" ;;
  esac
  if ss -Htln 2>/dev/null | awk '{print $4}' | grep -Eq ':(2375|2376)$'; then
    aviso "a API do Docker escuta em TCP (2375/2376): tirar o -H tcp:// do dockerd (systemctl cat docker)"
  fi
  if [ -f /root/.docker/config.json ]; then
    modo=$(stat -c '%a' /root/.docker/config.json)
    if [ "$modo" != 600 ]; then
      chmod 600 /root/.docker/config.json && ok "/root/.docker/config.json estava $modo: agora 600 (token do ghcr.io)"
    else
      ok "/root/.docker/config.json 600 (token do ghcr.io)"
    fi
    if [ -s "$GHCR_DESDE" ]; then
      dias=$(( ($(date +%s) - $(date -d "$(cat "$GHCR_DESDE")" +%s 2>/dev/null || date +%s)) / 86400 ))
      if [ "$dias" -ge 80 ]; then aviso "o token do ghcr.io foi gravado há $dias dias: gere outro (só read:packages, 90 dias) e rode app-ghcr"
      else ok "token do ghcr.io gravado há $dias dia(s) (trocar antes de 90)"; fi
    else
      aviso "não sei a idade do token do ghcr.io: na próxima troca (só read:packages, validade de 90 dias), rode app-ghcr"
    fi
  fi
}

# Cron (achado 24 e revisão de 24/10): o cron roda como root a cópia em $BASE/bootstrap-vps.sh.
# Se ela, a pasta ou o arquivo do cron ficassem graváveis por outro usuário, quem escrevesse ali
# viraria root às 03:30. Confere dono e permissão.
cron_conferir() {
  local f m
  for f in /etc/cron.d/crystal-backup-n8n /etc/cron.d/crystal-vigia; do
    [ -f "$f" ] || continue
    m=$(stat -c '%a %U' "$f")
    [ "$m" = "644 root" ] || aviso "$f com $m (esperado 644 root): chown root:root $f && chmod 644 $f"
    grep -q ' PATH=/usr/sbin:/usr/bin:/sbin:/bin ' "$f" || aviso "$f sem PATH fixo (de antes de 24/10): bash $0 backup-cron (ou vigia-config) regrava"
  done
  if [ -f "$BASE/bootstrap-vps.sh" ]; then
    m=$(stat -c '%a %U' "$BASE/bootstrap-vps.sh")
    [ "$m" = "700 root" ] || aviso "$BASE/bootstrap-vps.sh com $m (esperado 700 root): chmod 700 e chown root"
  fi
  m=$(stat -c '%a %U' "$BASE" 2>/dev/null || true)
  [ -z "$m" ] || [ "$m" = "700 root" ] || aviso "$BASE com $m (esperado 700 root): chmod 700 $BASE"
}

# ------------------------------------------------------------------ status
status() {
  echo "== Serviços"
  docker service ls --format '{{.Name}} {{.Replicas}} {{.Image}}' | awk '{printf "  %-28s %-5s %s\n",$1,$2,$3}'
  echo
  echo "== HTTPS pelos nomes públicos (certificado tem que ser válido, sem -k)"
  for h in painel editor webhook; do
    local code
    code=$(curl -s -o /dev/null -m 20 -w '%{http_code}' "https://$h.$DOMINIO/" 2>/dev/null) || true
    code=${code:-000}
    case "$h:$code" in
      painel:403) ok "https://$h.$DOMINIO -> 403 (restrito por IP; a VPS não está na lista)" ;;
      *:200|*:301|*:302|*:401|*:404) ok "https://$h.$DOMINIO -> $code" ;;
      *:000) aviso "https://$h.$DOMINIO sem resposta ou certificado inválido (Traefik ainda emitindo? DNS? porta 443 fechada?)" ;;
      *) aviso "https://$h.$DOMINIO -> $code" ;;
    esac
  done
  local h
  h=$(horas_desde "$BACKUPS/.backup-ultimo")
  if [ "$h" != nunca ] && [ "$h" -lt 26 ]; then ok "último backup completo na VPS há ${h} h"; else aviso "último backup completo na VPS: há ${h} h (ver $BACKUPS/backup.log)"; fi
  [ -s "$BACKUPS/.backup-falhas" ] && aviso "último backup com falha: $(paste -sd';' "$BACKUPS/.backup-falhas")"
  if [ -s "$FORA_CONF" ] && [ -s "$BACKUPS/.fora-ultimo" ]; then
    h=$(horas_desde "$BACKUPS/.fora-ultimo")
    if [ "$h" -lt 26 ]; then ok "último backup no R2 há ${h} h"; else aviso "último backup no R2 há ${h} h: ver $BACKUPS/backup.log"; fi
  else
    aviso "backup fora da VPS não configurado (backup-chave, backup-fora-config)"
  fi
  if [ -s "$FORA_DEST" ] && backup_destinatario_conferir; then
    ok "chave pública dos backups: $(backup_destinatario_resumo) (compare com o Bitwarden)"
  fi
  copia_cron_conferir
  cron_conferir
  painel_trava_conferir || true
  portas_docker_conferir
  docker_acesso_conferir
  if redes_unica; then aviso "redes: modo de volta, tudo na network_swarm_public (bash $0 redes-separar desfaz)"
  elif svc_na_rede traefik_traefik borda_api; then ok "redes separadas por stack (detalhe e prova: bash $0 redes-conferir)"
  else aviso "redes: ainda a rede única de antes; corte do INF-06 por fazer (README, revisão de 24/10)"; fi
  echo
  echo "== Últimas linhas do Traefik sobre certificado (desde 24/10 o log vai para a saída do contêiner, INF-20)"
  if docker service inspect traefik_traefik >/dev/null 2>&1; then
    # Sem as linhas do log de acesso (começam pelo IP de quem acessou): só as do próprio Traefik.
    docker service logs --since 24h --raw traefik_traefik 2>&1 | grep -vE '^[0-9a-fA-F.:]+ - ' | grep -iE 'acme|certif|level=error' \
      | grep -v 'port is missing' | tail -8 | grep . || echo "  (nada sobre certificado nas últimas 24 h)"
  else
    aviso "serviço do Traefik não encontrado"
  fi
}

segredos() {
  [ -f "$SEGREDOS" ] || falha "ainda não há segredos: rode 'preparar'"
  # Abre no less (tela alternativa): ao apertar q, os valores somem da tela e
  # não ficam no histórico do terminal. É pra copiar direto pro cofre.
  if [ -t 1 ] && command -v less >/dev/null; then
    {
      echo "Copie DB_SENHA, N8N_CHAVE e N8N_REDIS_SENHA pro Bitwarden, em itens separados."
      echo "Aperte q pra fechar: os valores somem da tela e não vão pro histórico."
      echo "A chave N8N_CHAVE nunca pode mudar depois de o n8n ter fluxo salvo."
      echo
      grep -E '^(DB_SENHA|N8N_CHAVE|N8N_REDIS_SENHA)=' "$SEGREDOS"
    } | less -K
  else
    # Fora de terminal (cron, pipe, log) os valores iriam parar num arquivo (achado 70).
    falha "rode num terminal: os segredos abrem no less e não ficam em log nem no histórico"
  fi
}

# Só serve ANTES de o n8n ter qualquer fluxo ou credencial salva. Apaga o banco
# do n8n, os segredos e refaz tudo com segredos novos. Uso:
#   bash bootstrap-vps.sh recomecar-n8n SEU_EMAIL --confirmo
recomecar_n8n() {
  local email="${2:-}" conf="${3:-}" pg n tem v ts t=0
  [ "$conf" = "--confirmo" ] || falha "isto apaga o banco do n8n. Se for isso mesmo: bash $0 recomecar-n8n SEU_EMAIL --confirmo"
  [ -n "$email" ] || falha "informe o e-mail do Let's Encrypt"
  # Trava real (achado 31). A guarda antiga procurava o serviço "n8n_editor", mas o
  # nome é n8n_editor_n8n_editor: nunca conferia nada e apagaria a crystal-provisoria.
  # Agora confere direto no banco e falha fechado: sem o Postgres no ar, ou sem
  # resposta, não dá para provar que está vazio, e nada é apagado.
  pg=$(docker ps -q -f name=n8n_postgres_n8n_postgres 2>/dev/null | head -1 || true)
  [ -n "$pg" ] || falha "o Postgres do n8n não está rodando: não dá para provar que o n8n está sem fluxo. Nada apagado"
  tem=$(docker exec "$pg" psql -U postgres -d n8n_queue -tAc "select to_regclass('public.workflow_entity') is not null" 2>/dev/null | tr -d '[:space:]' || true)
  case "$tem" in
    f) n=0 ;;   # o n8n nunca criou as tabelas
    t) n=$(docker exec "$pg" psql -U postgres -d n8n_queue -tAc 'select (select count(*) from workflow_entity) + (select count(*) from credentials_entity)' 2>/dev/null | tr -d '[:space:]' || true) ;;
    *) n="" ;;
  esac
  [ -n "$n" ] || falha "o banco do n8n não respondeu: não dá para provar que está sem fluxo. Nada apagado"
  [ "$n" = "0" ] || falha "o n8n tem $n fluxo(s)/credencial(is) salvos. Trocar a chave agora os tornaria ilegíveis. Não recomece"
  [ -t 0 ] || falha "rode num terminal: este comando pede confirmação digitada"
  read -rp "Digite APAGAR para apagar o banco do n8n e trocar os segredos dele: " v
  [ "$v" = APAGAR ] || falha "nada apagado"
  # Cópia antes de apagar: o dump e os segredos antigos (a chave abre o dump).
  ts=$(date -u +%Y%m%dT%H%M%SZ)
  mkdir -p "$BACKUPS"; chmod 700 "$BACKUPS"; umask 077
  backup_pg "$pg" postgres n8n_queue "$BACKUPS/n8n_queue-antes-recomecar-$ts.sql.gz" || falha "não copiei o banco do n8n antes de apagar. Nada apagado"
  cp -p "$SEGREDOS" "$BASE/.segredos.antes-recomecar-$ts" || falha "não copiei $SEGREDOS. Nada apagado"
  echo "== removendo stacks do n8n"
  docker stack rm n8n_worker n8n_webhook n8n_editor n8n_redis n8n_postgres 2>/dev/null || true
  # O volume só solta quando nenhum contêiner (nem parado) o usa.
  while docker ps -a -q --filter volume=n8n_postgres_data --filter volume=n8n_redis_data 2>/dev/null | grep -q . && [ $t -lt 120 ]; do sleep 3; t=$((t+3)); done
  echo "== recriando os volumes do n8n (banco antigo apagado; cópia em $BACKUPS)"
  for v in n8n_postgres_data n8n_redis_data; do
    if docker volume inspect "$v" >/dev/null 2>&1; then
      docker volume rm "$v" >/dev/null || falha "não apagou o volume $v (ainda em uso?). Os segredos não foram trocados; rode de novo em 1 min"
    fi
  done
  docker volume create n8n_postgres_data >/dev/null
  docker volume create n8n_redis_data >/dev/null
  rm -f "$SEGREDOS"
  preparar preparar "$email"
  # O Traefik também é regravado (e-mail do ACME). Se a conta ACME já existe no
  # acme.json, o e-mail antigo fica; não importa: o Let's Encrypt não manda mais
  # aviso de vencimento por e-mail desde 2025 e o Traefik renova sozinho.
  docker stack deploy -c "$STACKS/00-traefik.yaml" traefik --detach=true >/dev/null
  bancos; n8n; echo; status
}

# ================================================================== APP
# crystal-web-chat: PWA em app., API em api., Postgres e Redis próprios.
# Imagens privadas no ghcr.io, construídas pelo GitHub Actions do repositório
# do app. Segredos gerados aqui, uma vez só, e nunca impressos fora do less.
APP_DIR="$BASE/app"
APP_SEG="$APP_DIR/.segredos"
APP_EXT="$APP_DIR/.externos"
APP_DB_PAPEL_ARQ="$APP_DIR/.db-papel"   # "crystal_api" depois do app-db-papel --confirmo
APP_YAML=10-crystal-app.yaml
APP_IMG=ghcr.io/lfcrystal766/crystal-web-chat
APP_STACK=crystal_app
# Nomes que o app-definir aceita. Os marcados com * são segredo (não ecoam).
APP_EXTERNOS=(RESEND_API_KEY* EMAIL_FROM CRYSTAL_API_URL CRYSTAL_API_KEY* CRYSTAL_API_PATH
  CRYSTAL_API_AUTH_HEADER CRYSTAL_API_REPLY_FIELD CRYSTAL_ONBOARDING_URL DIRECTORY_API_URL
  DIRECTORY_API_KEY* DIRECTORY_API_PATH DIRECTORY_API_AUTH_HEADER META_ACCESS_TOKEN*
  META_PHONE_NUMBER_ID ALERT_WEBHOOK_URL* SENTRY_DSN VAPID_SUBJECT
  CHAT_TRANSPORT CHATWOOT_BASE_URL CHATWOOT_INBOX_IDENTIFIER CHATWOOT_INBOX_HMAC_TOKEN*
  CHATWOOT_WEBHOOK_SECRET* CHANNEL_REPLY_TIMEOUT_MS CHATWOOT_ACCOUNT_ID CHATWOOT_BOT_TOKEN* CHATWOOT_BOT_SECRET*
  SUPABASE_URL SUPABASE_SERVICE_ROLE_KEY* SUPABASE_LOGIN_RPC SUPABASE_LOGIN_EMAIL_RPC ROLLOUT_GATE LOGIN_MODO LOGIN_CODIGO
  REVIEW_ACCOUNTS* OPENROUTER_API_KEY* CRYSTAL_MODEL CRYSTAL_MODEL_RESERVA CRYSTAL_MODEL_RESUMO
  CONHECIMENTO_MATCH_COUNT CONHECIMENTO_TIMEOUT_MS
  ANDROID_CERT_SHA256 APPLE_TEAM_ID FCM_PROJECT_ID FCM_SERVICE_ACCOUNT_JSON*
  REFUND_WEBHOOK_SECRET* REFUND_EVENTS REFUND_PRODUCT_IDS TRANSCRIPTION_API_URL TRANSCRIPTION_API_KEY* TRANSCRIPTION_MODEL
  TRANSCRIPTION_TIMEOUT_MS TRANSCRIPTION_PRICE_PER_HOUR_USD CHATWOOT_API_TOKEN* EQUIPE_EMAIL SUPERADMIN_EMAILS
  RATE_AUTH_MAX RATE_AUTH_WINDOW_S OTP_MAX_ATTEMPTS OTP_RESEND_COOLDOWN_S OTP_RESEND_MAX
  RATE_AUTH_IP_MAX UPLOAD_DAILY_MAX CRYSTAL_PRAZO_TOTAL_MS CRYSTAL_TIMEOUT_MS)

# Nome de variável: maiúsculas, números e _. Qualquer outra coisa no lugar do nome
# pode ser uma chave colada errado, e aí nunca é repetida na tela (achado 70).
parece_nome() { printf '%s' "$1" | grep -Eq '^[A-Z][A-Z0-9_]{1,40}$'; }
recusar_nao_nome() { # recusar_nao_nome COMANDO
  falha "isso não é um NOME da lista e pode ser uma CHAVE colada no lugar (re_, gsk_, sb_secret_, sk-or-, eyJ...). Não repito o que foi digitado. A chave nunca vai na linha de comando: rode só 'bash $0 $1 NOME' e cole quando ele perguntar. Se era uma chave, troque-a no painel de origem: ela ficou no histórico do terminal (limpe com: history -c && history -w)"
}
inteiro_entre() { # inteiro_entre VALOR MIN MAX
  printf '%s' "$1" | grep -Eq '^[0-9]{1,9}$' && [ "$1" -ge "$2" ] && [ "$1" -le "$3" ]
}

app_valor() { # app_valor ARQUIVO NOME -> valor (sem imprimir nada se não houver)
  [ -f "$1" ] || return 0
  grep -E "^$2=" "$1" | tail -1 | cut -d= -f2- || true
}

app_ghcr() {
  local u t
  read -rp "Usuário do GitHub dono das imagens [LFcrystal766]: " u; u=${u:-LFcrystal766}
  echo "Token do GitHub com read:packages, de preferência um só para a VPS (sem write:packages), com validade de 90 dias."
  read -rsp "Cole e dê Enter (não aparece na tela): " t; echo
  [ -n "$t" ] || falha "token vazio"
  printf '%s' "$t" | docker login ghcr.io -u "$u" --password-stdin >/dev/null || falha "login no ghcr.io recusado"
  unset t
  chmod 600 /root/.docker/config.json 2>/dev/null || true
  mkdir -p "$BASE"; umask 077; date -u +%FT%TZ > "$GHCR_DESDE"
  ok "docker login ghcr.io como $u"
  echo "  O Docker guarda a credencial em /root/.docker/config.json (base64, chmod 600). Use um token clássico"
  echo "  SÓ com read:packages e validade de 90 dias (INF-29); o status avisa a partir de 80 dias. Venceu: rode de novo."
}

app_definir() {
  local nome="${2:-}" item secreto=0 aceito=0 v
  if [ -z "$nome" ]; then
    echo "Nomes aceitos (* = segredo, digitado sem aparecer):"
    printf '  %s\n' "${APP_EXTERNOS[@]}"
    echo "Já definidos: $( [ -f "$APP_EXT" ] && cut -d= -f1 "$APP_EXT" | tr '\n' ' ')"
    return 0
  fi
  for item in "${APP_EXTERNOS[@]}"; do
    if [ "${item%\*}" = "$nome" ]; then
      aceito=1
      if [ "$item" != "$nome" ]; then secreto=1; fi
    fi
  done
  if [ "$aceito" -ne 1 ]; then
    # Nunca repetir o que foi digitado: quase sempre é um segredo colado no
    # lugar do nome, e aí ele iria pra tela e pra captura do terminal.
    parece_nome "$nome" || recusar_nao_nome app-definir
    falha "$nome não está na lista de nomes aceitos. Rode 'bash $0 app-definir' pra ver a lista"
  fi
  if [ "$secreto" -eq 1 ]; then
    read -rsp "$nome (não aparece na tela): " v; echo
  else
    read -rp "$nome: " v
  fi
  case "$v" in *$'\r'*) v=${v//$'\r'/} ;; esac   # colado do Windows/Mac com CR no fim
  # Espaço ou tab nas pontas (colar do painel costuma trazer) sai; no meio, fica.
  v="${v#"${v%%[![:space:]]*}"}"; v="${v%"${v##*[![:space:]]}"}"
  [ -n "$v" ] || falha "valor vazio; nada gravado"
  case "$v" in *$'\n'*) falha "valor com quebra de linha" ;; esac
  local base papel
  case "$nome" in
    SUPABASE_URL)
      # Em 05/10 colaram a URL com /rest/v1/ e todo login daria 503: o app acrescenta
      # /rest/v1/rpc/... sozinho. Corta o caminho e avisa (achado 9).
      case "$v" in https://*) ;; *) falha "a URL do Supabase começa com https:// (ex.: https://abcdefghijklmnopqrst.supabase.co). Nada gravado" ;; esac
      base=$(printf '%s' "$v" | sed -E 's;^(https://[^/?#]+).*;\1;')
      if [ "$base" != "$v" ]; then
        aviso "cortei '${v#"$base"}' do fim: vale só https://<ref>.supabase.co (o app acrescenta /rest/v1/rpc/... sozinho)"
        v=$base
      fi
      v=$(printf '%s' "$v" | tr 'A-Z' 'a-z')
      printf '%s' "$v" | grep -Eq '^https://[a-z0-9]{20}\.supabase\.co$' \
        || falha "formato: https://<ref de 20 letras e números>.supabase.co (Supabase > Settings > API > Project URL). Nada gravado" ;;
    SUPABASE_SERVICE_ROLE_KEY)
      # A chave anon/publicável é pública e não passa pelo RLS da base: com ela todo
      # login de aluna daria 503. Recusa sem mostrar nada.
      case "$v" in
        sb_publishable_*) v=""; falha "essa é a chave PUBLICÁVEL (sb_publishable_...), que é pública. Aqui vai a SECRETA (sb_secret_...) ou a service_role legada (eyJ...). Nada gravado" ;;
        sb_secret_*) printf '%s' "$v" | grep -Eq '^sb_secret_[A-Za-z0-9_-]{20,}$' || { v=""; falha "chave sb_secret_ incompleta ou com caractere estranho. Nada gravado"; } ;;
        eyJ*)
          papel=$(printf '%s' "$v" | python3 -c 'import base64,json,sys
p=sys.stdin.read().strip().split(".")
try:
    print(json.loads(base64.urlsafe_b64decode(p[1]+"="*(-len(p[1])%4))).get("role",""))
except Exception:
    print("")' 2>/dev/null || true)
          case "$papel" in
            service_role) ;;
            anon) v=""; falha "essa é a chave ANON (pública). Aqui vai a service_role (Settings > API > service_role, ou a nova sb_secret_). Nada gravado" ;;
            *) v=""; falha "JWT sem role service_role (incompleto?). Nada gravado" ;;
          esac ;;
        *) v=""; falha "formato inesperado: a chave começa com sb_secret_ (nova) ou eyJ (service_role legada). Nada gravado" ;;
      esac ;;
    SUPABASE_LOGIN_RPC)
      printf '%s' "$v" | grep -Eq '^[a-z_][a-z0-9_]{0,62}$' || falha "nome da função em minúsculas, números e _ (padrão: app_verificar_login). Nada gravado" ;;
    SUPABASE_LOGIN_EMAIL_RPC)
      # Login só com e-mail (07/10): a função de crystal-em-casa/supabase/app_verificar_login_email.sql.
      printf '%s' "$v" | grep -Eq '^[a-z_][a-z0-9_]{0,62}$' || falha "nome da função em minúsculas, números e _ (padrão: app_verificar_login_email). Nada gravado" ;;
    VAPID_SUBJECT)
      printf '%s' "$v" | grep -Eq '^(mailto:[^@ ]+@[^@ ]+\.[^@ ]+|https://[^ ]+)$' || falha "formato: mailto:alguem@dominio.com ou https://... Nada gravado" ;;
    SENTRY_DSN)
      printf '%s' "$v" | grep -Eq '^https://[A-Za-z0-9]+@[A-Za-z0-9.-]+(:[0-9]+)?/[0-9]+$' \
        || falha "formato do DSN: https://CHAVE@oNNN.ingest.sentry.io/NNN (Sentry > Settings > Client Keys). Nada gravado" ;;
    ALERT_WEBHOOK_URL)
      printf '%s' "$v" | grep -Eq '^https://[A-Za-z0-9.-]+(:[0-9]+)?(/[^ ]*)?$' || { v=""; falha "a URL do alerta tem que ser https://, sem espaço. Nada gravado"; } ;;
    CHANNEL_REPLY_TIMEOUT_MS)
      inteiro_entre "$v" 5000 600000 || falha "só inteiro entre 5000 e 600000 (milissegundos; padrão 180000). Nada gravado" ;;
    RATE_AUTH_MAX)
      inteiro_entre "$v" 1 10000 || falha "só inteiro entre 1 e 10000 (tentativas por janela; padrão 5). Nada gravado" ;;
    RATE_AUTH_IP_MAX)
      inteiro_entre "$v" 1 100000 || falha "só inteiro entre 1 e 100000 (tentativas por IP na janela; padrão 50). Nada gravado" ;;
    UPLOAD_DAILY_MAX)
      inteiro_entre "$v" 1 100000 || falha "só inteiro entre 1 e 100000 (uploads por aluna por dia; padrão 200). Nada gravado" ;;
    CRYSTAL_PRAZO_TOTAL_MS|CRYSTAL_TIMEOUT_MS)
      inteiro_entre "$v" 5000 600000 || falha "só inteiro entre 5000 e 600000 (milissegundos; padrões 50000 e 45000; o prazo total da Crystal tem de ficar abaixo dos 60 s da API). Nada gravado" ;;
    RATE_AUTH_WINDOW_S)
      inteiro_entre "$v" 10 86400 || falha "só inteiro entre 10 e 86400 (segundos; padrão 900). Nada gravado" ;;
    ROLLOUT_GATE)
      # Liberação do app em lotes (06/10): on barra quem está fora do lote (is_in_rollout)
      # com 403 LOGIN_NOT_RELEASED; off abre para todas. Vai para o api.env.
      v=$(printf '%s' "$v" | tr 'A-Z' 'a-z' | tr -d ' ')
      case "$v" in on|off) ;; *) falha "digite só on (login em lotes: só aluna com is_in_rollout entra; é o padrão do app) ou off (abre para todas). Nada gravado" ;; esac ;;
    LOGIN_MODO)
      # Login só com o e-mail da compra (decisão do dono em 07/10): email = a aluna digita só o
      # e-mail, a base é consultada por app_verificar_login_email e o CÓDIGO POR E-MAIL É SEMPRE
      # EXIGIDO (LOGIN_CODIGO não vale neste modo); é o padrão do app. cpf_email = o fluxo
      # anterior, CPF + e-mail (aí LOGIN_CODIGO volta a valer). Vai para o api.env.
      v=$(printf '%s' "$v" | tr 'A-Z' 'a-z' | tr -d ' ')
      case "$v" in email|cpf_email) ;; *) falha "digite só email (só o e-mail da compra, sempre com código; é o padrão do app) ou cpf_email (CPF + e-mail, o fluxo anterior). Nada gravado" ;; esac ;;
    LOGIN_CODIGO)
      # Login sem código (decisão do dono em 06/10, modo de lançamento): nenhum = a aluna que
      # passa pela base entra SEM o código do e-mail (com limite por CPF e e-mail, aviso
      # "Alguém entrou na sua conta" e auditoria); email = código de uso único (padrão do app).
      # Vai para o api.env. Quem souber CPF e e-mail entra como a aluna: voltar a email depois.
      # Só vale com LOGIN_MODO=cpf_email: no modo email (padrão) o código é sempre exigido.
      v=$(printf '%s' "$v" | tr 'A-Z' 'a-z' | tr -d ' ')
      case "$v" in email|nenhum) ;; *) falha "digite só email (código de uso único por e-mail; é o padrão do app) ou nenhum (entra sem o código, modo de lançamento). Nada gravado" ;; esac ;;
    CONHECIMENTO_MATCH_COUNT)
      inteiro_entre "$v" 1 20 || falha "só inteiro entre 1 e 20 (trechos da base por mensagem; padrão 6). Nada gravado" ;;
    CONHECIMENTO_TIMEOUT_MS)
      inteiro_entre "$v" 1000 15000 || falha "só inteiro entre 1000 e 15000 (milissegundos da busca na base; padrão 5000). Nada gravado" ;;
    OTP_MAX_ATTEMPTS|OTP_RESEND_MAX)
      inteiro_entre "$v" 1 20 || falha "só inteiro entre 1 e 20. Nada gravado" ;;
    OTP_RESEND_COOLDOWN_S)
      inteiro_entre "$v" 10 3600 || falha "só inteiro entre 10 e 3600 (segundos; padrão 60). Nada gravado" ;;
    EQUIPE_EMAIL)
      v=$(printf '%s' "$v" | tr 'A-Z' 'a-z')
      printf '%s' "$v" | grep -Eq '^[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}$' || falha "e-mail inválido. Nada gravado" ;;
    CHAT_TRANSPORT)
      v=$(printf '%s' "$v" | tr 'A-Z' 'a-z' | tr -d ' ')
      case "$v" in crystal|chatwoot) ;; *) falha "digite só crystal (a nossa Crystal direto) ou chatwoot (pelo nosso Chatwoot; prefira: app-canal chatwoot). Nada gravado" ;; esac ;;
    ANDROID_CERT_SHA256)
      v=$(printf '%s' "$v" | tr 'a-f' 'A-F' | tr -d ' ')
      printf '%s' "$v" | grep -Eq '^([0-9A-F]{2}(:[0-9A-F]{2}){31})(,[0-9A-F]{2}(:[0-9A-F]{2}){31})*$' \
        || falha "formato: AA:BB:...(32 pares), várias separadas por vírgula (Play Console > Integridade do app)" ;;
    APPLE_TEAM_ID)
      v=$(printf '%s' "$v" | tr 'a-z' 'A-Z')
      printf '%s' "$v" | grep -Eq '^[A-Z0-9]{10}$' || falha "o Team ID tem 10 letras/números (developer.apple.com > Membership)" ;;
    FCM_PROJECT_ID)
      printf '%s' "$v" | grep -Eq '^[a-z][a-z0-9-]{4,28}[a-z0-9]$' || falha "ID do projeto do Firebase (ex.: crystal-app-1a2b3), não o nome" ;;
    FCM_SERVICE_ACCOUNT_JSON)
      # Base64 do JSON da conta de serviço. Confere o formato sem mostrar nada.
      printf '%s' "$v" | python3 -c 'import base64,json,sys
d=json.loads(base64.b64decode(sys.stdin.read().strip(), validate=True))
assert d.get("type")=="service_account" and d.get("client_email") and "PRIVATE KEY" in d.get("private_key","")' 2>/dev/null \
        || falha "esperado o JSON da conta de serviço em base64, numa linha só (no Mac: base64 -i chave.json | tr -d '\\n' | pbcopy). Nada gravado" ;;
    SUPERADMIN_EMAILS)
      # Onda 5 (13/10): quem edita a alma da Crystal. Só e-mails, separados por vírgula; o papel admin continua
      # exigido pela API. Vazio = ninguém edita (o painel só mostra).
      v=$(printf '%s' "$v" | tr 'A-Z' 'a-z' | tr -d ' ')
      printf '%s' "$v" | grep -Eq '^([a-z0-9._%+-]+@[a-z0-9-]+(\.[a-z0-9-]+)+)(,[a-z0-9._%+-]+@[a-z0-9-]+(\.[a-z0-9-]+)+){0,9}$' \
        || falha "lista de e-mails separados por vírgula (até 10), ex.: dono@empresa.com.br. Nada gravado" ;;
    REFUND_WEBHOOK_SECRET)
      # Assina o webhook de reembolso: tem que ser longo e variado, nunca uma palavra.
      [ "$(printf '%s' "$v" | wc -c)" -ge 32 ] && [ "$(printf '%s' "$v" | fold -w1 | sort -u | wc -l)" -ge 10 ] \
        || falha "segredo fraco (mínimo 32 bytes e 10 caracteres diferentes). Gere com: openssl rand -hex 32  e cole o resultado. Nada gravado" ;;
    TRANSCRIPTION_API_URL)
      case "$v" in https://?*) ;; *) falha "a URL da transcrição tem que começar com https://. Nada gravado" ;; esac ;;
    TRANSCRIPTION_TIMEOUT_MS)
      printf '%s' "$v" | grep -Eq '^[0-9]{4,6}$' && [ "$v" -ge 1000 ] && [ "$v" -le 120000 ] \
        || falha "só inteiro entre 1000 e 120000 (milissegundos). Nada gravado" ;;
  esac
  mkdir -p "$APP_DIR"; chmod 700 "$APP_DIR"
  umask 077
  touch "$APP_EXT"
  grep -vE "^$nome=" "$APP_EXT" > "$APP_EXT.tmp" || true
  printf '%s=%s\n' "$nome" "$v" >> "$APP_EXT.tmp"
  mv "$APP_EXT.tmp" "$APP_EXT"; chmod 600 "$APP_EXT"
  unset v
  ok "$nome gravado em $APP_EXT. Vale na próxima 'app-subir'"
  case "$nome" in
    ROLLOUT_GATE|LOGIN_CODIGO|REFUND_EVENTS|REFUND_PRODUCT_IDS|RATE_AUTH_IP_MAX|TRANSCRIPTION_PRICE_PER_HOUR_USD)
      # Operação pelo painel (07/10): este valor é só o PADRÃO; a chave op_* gravada em
      # system_settings pelo /equipe/operacao vale na frente dele, sem app-subir.
      aviso "valor padrão; o painel /equipe/operacao sobrepõe ao vivo" ;;
  esac
}

# Apaga um valor do .externos (ex.: CRYSTAL_ONBOARDING_URL, que a etapa 2 do PRD
# deixou de usar). Só nomes da lista; nunca segredo gerado pelo app-subir.
app_remover() {
  local nome="${2:-}"   # $1 é o próprio "app-remover" (o dispatch passa "$@")
  [ -n "$nome" ] || falha "uso: bash $0 app-remover NOME"
  parece_nome "$nome" || recusar_nao_nome app-remover   # nunca repete o argumento (achado 70)
  printf '%s\n' "${APP_EXTERNOS[@]}" | sed 's/\*$//' | grep -qx "$nome" \
    || falha "$nome não é um valor externo (bash $0 app-definir lista os aceitos)"
  [ -s "$APP_EXT" ] || { aviso "$APP_EXT não existe; nada a apagar"; return 0; }
  if ! grep -qE "^$nome=" "$APP_EXT"; then aviso "$nome não estava em $APP_EXT"; return 0; fi
  umask 077
  grep -vE "^$nome=" "$APP_EXT" > "$APP_EXT.tmp" || true
  mv "$APP_EXT.tmp" "$APP_EXT"; chmod 600 "$APP_EXT"
  ok "$nome apagado de $APP_EXT. Vale na próxima 'app-subir'"
}

# Guiado, sem argumento nenhum: pergunta a chave do Resend (sem eco) e o
# remetente. Existe pra ninguém precisar escrever valor na linha de comando.
app_resend() {
  echo "Chave de API do Resend: cole quando aparecer o pedido abaixo e dê Enter."
  app_definir app-definir RESEND_API_KEY
  echo
  echo "Remetente, com domínio verificado no Resend. Sugestão: Crystal <acesso@$DOMINIO>"
  app_definir app-definir EMAIL_FROM
  echo
  echo "Já definidos: $(cut -d= -f1 "$APP_EXT" | tr '\n' ' ')"
}

app_gerar_segredos() { # app_gerar_segredos TAG
  mkdir -p "$APP_DIR"; chmod 700 "$APP_DIR"
  umask 077
  if [ ! -f "$APP_SEG" ]; then
    {
      echo "APP_DB_SENHA=$(openssl rand -hex 24)"
      echo "ENCRYPTION_KEY=$(openssl rand -hex 32)"
      for k in JWT_SECRET WEBHOOK_SECRET CPF_SALT OTP_PEPPER; do
        echo "$k=$(openssl rand -base64 48 | tr -d '\n')"
      done
      echo "CRIADO_EM=$(date -u +%FT%TZ)"
    } > "$APP_SEG"
    ok "segredos do app gerados em $APP_SEG. Copie pro cofre: bash $0 app-segredos"
  else
    ok "segredos do app já existem em $APP_SEG (mantidos)"
  fi
  # Nossa Crystal: chave entre app e Crystal, cifra da memória (NUNCA muda depois
  # de a Crystal ter guardado conversa) e senha do papel crystal_agente no Postgres.
  if [ -z "$(app_valor "$APP_SEG" CRYSTAL_CHAVE_CIFRA)" ]; then
    {
      echo "CRYSTAL_AGENTE_KEY=$(openssl rand -hex 32)"
      echo "CRYSTAL_CHAVE_CIFRA=$(openssl rand -hex 32)"
      echo "CRYSTAL_DB_SENHA=$(openssl rand -hex 24)"
    } >> "$APP_SEG"
    ok "segredos da nossa Crystal gerados (copie pro cofre: bash $0 app-segredos)"
  fi
  # Senha do Redis do app (INF-12, 24/10): acrescentada uma vez a segredos antigos. Pode ser
  # trocada (apagar a linha e app-subir): o Redis só guarda sessões curtas e contadores.
  if [ -z "$(app_valor "$APP_SEG" APP_REDIS_SENHA)" ]; then
    echo "APP_REDIS_SENHA=$(openssl rand -hex 24)" >> "$APP_SEG"
    ok "APP_REDIS_SENHA gerada para o Redis do app (copie pro cofre: bash $0 app-segredos)"
  fi
  # VAPID (push web): gerado com a própria biblioteca do app, dentro da imagem.
  if [ -z "$(app_valor "$APP_SEG" VAPID_PUBLIC_KEY)" ]; then
    local chaves
    chaves=$(docker run --rm -w /app/apps/api --entrypoint node "$APP_IMG-api:$1" -e \
      'const k=require("web-push").generateVAPIDKeys();console.log("VAPID_PUBLIC_KEY="+k.publicKey+"\nVAPID_PRIVATE_KEY="+k.privateKey)') \
      || falha "não gerou as chaves VAPID com a imagem $APP_IMG-api:$1"
    echo "$chaves" | grep -qE '^VAPID_PRIVATE_KEY=.{20,}' || falha "chaves VAPID vieram vazias"
    echo "$chaves" >> "$APP_SEG"
    unset chaves
    ok "chaves VAPID do push web geradas"
  fi
  chmod 600 "$APP_SEG"
}

# Em quem a API confia para ler o IP do cliente no X-Forwarded-For (limite de tentativas por
# IP, auditoria). Com as redes separadas (INF-06): a faixa da borda_api, onde só o Traefik
# está; o Traefik apaga o X-Forwarded-For que vem de fora e escreve o IP real. Antes era "1"
# (o primeiro salto, fosse quem fosse): um vizinho de rede falando direto com a API (a Crystal,
# um contêiner comprometido) escolhia o IP registrado. Na volta (rede única), ou sem a rede,
# fica "1", como era.
app_trust_proxy() {
  local sub
  redes_unica && { echo 1; return 0; }
  sub=$(docker network inspect borda_api --format '{{range .IPAM.Config}}{{.Subnet}} {{end}}' 2>/dev/null | awk '{print $1}' || true)
  if printf '%s' "$sub" | grep -Eq '^([0-9]{1,3}\.){3}[0-9]{1,3}/(1[6-9]|2[0-9])$'; then echo "$sub"; else echo 1; fi
}

app_gerar_env() {
  local senha mock=0 k dburl tp redis
  senha=$(app_valor "$APP_SEG" APP_DB_SENHA)
  [ -n "$senha" ] || falha "APP_DB_SENHA ausente em $APP_SEG"
  redis=$(app_valor "$APP_SEG" APP_REDIS_SENHA)
  printf '%s' "$redis" | grep -Eq '^[0-9a-f]{48}$' || falha "APP_REDIS_SENHA em $APP_SEG não é hex de 48 caracteres"
  # Papel da API no Postgres (INF-07): crystal_api, sem superusuário, depois do
  # app-db-papel --confirmo; senão o crystal de sempre (superusuário da imagem).
  if [ "$(cat "$APP_DB_PAPEL_ARQ" 2>/dev/null || true)" = crystal_api ]; then
    [ -n "$(app_valor "$APP_SEG" APP_DB_API_SENHA)" ] || falha "$APP_DB_PAPEL_ARQ pede crystal_api, mas falta APP_DB_API_SENHA em $APP_SEG. Rode: bash $0 app-db-papel --confirmo (ou --voltar)"
    dburl="postgresql://crystal_api:$(app_valor "$APP_SEG" APP_DB_API_SENHA)@app_postgres:5432/crystal_web_chat"
  else
    dburl="postgresql://crystal:$senha@app_postgres:5432/crystal_web_chat"
  fi
  for k in RESEND_API_KEY EMAIL_FROM; do
    [ -n "$(app_valor "$APP_EXT" $k)" ] || falha "$k não definido. Em produção o app manda o código de login por e-mail (Resend). Rode: bash $0 app-definir $k"
  done
  # Com o canal da inbox (CHAT_TRANSPORT=chatwoot) a Crystal não usa CRYSTAL_API_*.
  local chaves="CRYSTAL_API_URL CRYSTAL_API_KEY DIRECTORY_API_URL DIRECTORY_API_KEY"
  if [ "$(app_valor "$APP_EXT" CHAT_TRANSPORT)" = "chatwoot" ]; then
    chaves="DIRECTORY_API_URL DIRECTORY_API_KEY"
    for k in CHATWOOT_BASE_URL CHATWOOT_INBOX_IDENTIFIER CHATWOOT_WEBHOOK_SECRET; do
      [ -n "$(app_valor "$APP_EXT" $k)" ] || falha "CHAT_TRANSPORT=chatwoot sem $k. Rode: bash $0 app-definir $k"
    done
  fi
  # O robô do Chatwoot pergunta à Crystal pela CRYSTAL_API_*: sem ela a API não sobe
  # (achado 33; aconteceria depois de um crystal-provisoria-desligar).
  if [ -n "$(app_valor "$APP_EXT" CHATWOOT_BOT_TOKEN)$(app_valor "$APP_EXT" CHATWOOT_BOT_SECRET)$(app_valor "$APP_EXT" CHATWOOT_ACCOUNT_ID)" ]; then
    for k in CRYSTAL_API_URL CRYSTAL_API_KEY; do
      [ -n "$(app_valor "$APP_EXT" $k)" ] || falha "o robô do Chatwoot (CHATWOOT_BOT_*) precisa de $k e ela não está definida. Rode: bash $0 crystal-nossa TAG"
    done
  fi
  # Base de alunos no Supabase dispensa a DIRECTORY_API_*.
  if [ -n "$(app_valor "$APP_EXT" SUPABASE_URL)" ] && [ -n "$(app_valor "$APP_EXT" SUPABASE_SERVICE_ROLE_KEY)" ]; then
    chaves=$(echo "$chaves" | sed 's/DIRECTORY_API_URL//; s/DIRECTORY_API_KEY//')
  fi
  for k in $chaves; do
    [ -n "$(app_valor "$APP_EXT" $k)" ] || mock=1
  done
  tp=$(app_trust_proxy)
  umask 077
  {
    echo "POSTGRES_DB=crystal_web_chat"
    echo "POSTGRES_USER=crystal"
    echo "POSTGRES_PASSWORD=$senha"
    echo "POSTGRES_INITDB_ARGS=--auth-host=scram-sha-256"
  } > "$APP_DIR/postgres.env"
  echo "REDIS_PASSWORD=$redis" > "$APP_DIR/redis.env"
  {
    echo "# Gerado por bootstrap-vps.sh em $(date -u +%FT%TZ). Não editar: é regravado a cada app-subir."
    echo "NODE_ENV=production"
    echo "HOST=0.0.0.0"
    echo "PORT=3001"
    # Traefik publica 80/443 em modo host, apaga o X-Forwarded-For de fora e escreve o IP real.
    # A API confia nele só vindo da borda_api (app_trust_proxy, INF-06).
    echo "TRUST_PROXY=$tp"
    echo "WEB_ORIGIN=https://app.$DOMINIO"
    echo "DATABASE_URL=$dburl"
    echo "REDIS_URL=redis://:$redis@app_redis:6379"
    echo "UPLOAD_DIR=/app/uploads"
    echo "DEMO_SEED=0"
    echo "ALLOW_MOCK_INTEGRATIONS=$mock"
    echo "OTP_MODE=email"
    echo "SUGGESTIONS_MODE=shadow"
    echo "WEBHOOK_AUTH_MODE=hmac"
    echo "SENTRY_ENVIRONMENT=production"
    [ -n "$(app_valor "$APP_EXT" VAPID_SUBJECT)" ] || echo "VAPID_SUBJECT=mailto:crystal@leticiafelisberto.com"
    grep -E '^(ENCRYPTION_KEY|JWT_SECRET|WEBHOOK_SECRET|CPF_SALT|OTP_PEPPER|VAPID_PUBLIC_KEY|VAPID_PRIVATE_KEY)=' "$APP_SEG"
    # Menor privilégio: a chave do OpenRouter e o modelo são só da Crystal;
    # o vínculo com as lojas é só do web.
    grep -vE '^(OPENROUTER_API_KEY|CRYSTAL_MODEL|CRYSTAL_MODEL_RESERVA|CRYSTAL_MODEL_RESUMO|CONHECIMENTO_MATCH_COUNT|CONHECIMENTO_TIMEOUT_MS|ANDROID_CERT_SHA256|APPLE_TEAM_ID)=' "$APP_EXT" || true
  } > "$APP_DIR/api.env"
  {
    echo "# Gerado por bootstrap-vps.sh em $(date -u +%FT%TZ). Não editar: é regravado a cada app-subir."
    echo "NODE_ENV=production"
    echo "DATABASE_URL=postgresql://crystal_agente:$(app_valor "$APP_SEG" CRYSTAL_DB_SENHA)@app_postgres:5432/crystal_agente"
    grep -E '^(CRYSTAL_AGENTE_KEY|CRYSTAL_CHAVE_CIFRA)=' "$APP_SEG"
    grep -E '^(OPENROUTER_API_KEY|CRYSTAL_MODEL|CRYSTAL_MODEL_RESERVA|CRYSTAL_MODEL_RESUMO|CONHECIMENTO_MATCH_COUNT|CONHECIMENTO_TIMEOUT_MS)=' "$APP_EXT" || true
    # Base de conhecimento da Letícia: a Crystal busca trechos na Edge Function
    # crystal_hybrid_search do mesmo projeto Supabase da base de alunos (imagem com a
    # alma da agência, branch otimizacao/alma). A URL já vem sem /rest/v1 (app-definir).
    grep -E '^(SUPABASE_URL|SUPABASE_SERVICE_ROLE_KEY)=' "$APP_EXT" || true
  } > "$APP_DIR/crystal.env"
  {
    echo "# Gerado por bootstrap-vps.sh em $(date -u +%FT%TZ). Não editar: é regravado a cada app-subir."
    # Públicos (vão no /.well-known do app): impressões do certificado Android e Team ID da Apple.
    grep -E '^(ANDROID_CERT_SHA256|APPLE_TEAM_ID)=' "$APP_EXT" || true
  } > "$APP_DIR/web.env"
  chmod 600 "$APP_DIR/postgres.env" "$APP_DIR/redis.env" "$APP_DIR/api.env" "$APP_DIR/crystal.env" "$APP_DIR/web.env"
  unset senha dburl redis
  if [ "$tp" != 1 ]; then ok "API lê o IP do cliente só do Traefik (TRUST_PROXY=$tp, a borda_api)"
  elif ! redes_unica; then aviso "não li a faixa da borda_api: TRUST_PROXY=1, como era (bash $0 redes-conferir)"; fi
  if [ "$(cat "$APP_DB_PAPEL_ARQ" 2>/dev/null || true)" = crystal_api ]; then
    ok "API no Postgres como crystal_api (sem superusuário)"
  fi
  # Diz qual das duas pontas falta, em vez de um aviso só que confundia.
  if [ "$(app_valor "$APP_EXT" CHAT_TRANSPORT)" = "chatwoot" ]; then
    ok "Crystal: canal da inbox (CHAT_TRANSPORT=chatwoot)"
  elif [ -n "$(app_valor "$APP_EXT" CRYSTAL_API_URL)" ] && [ -n "$(app_valor "$APP_EXT" CRYSTAL_API_KEY)" ]; then
    case "$(app_valor "$APP_EXT" CRYSTAL_API_URL)" in
      http://app_crystal:*) ok "Crystal: a nossa (app_crystal)" ;;
      *webhook.$DOMINIO*) ok "Crystal: a provisória do n8n" ;;
      *) ok "Crystal: $(app_valor "$APP_EXT" CRYSTAL_API_URL | sed -E 's#^(https?://[^/]+).*#\1#')" ;;
    esac
  else
    aviso "Crystal SIMULADA (sem endereço): bash $0 crystal-nossa TAG"
  fi
  if [ -n "$(app_valor "$APP_EXT" SUPABASE_URL)" ] && [ -n "$(app_valor "$APP_EXT" SUPABASE_SERVICE_ROLE_KEY)" ]; then
    ok "base de alunos: Supabase configurada (a confirmação vem depois do deploy, no app-supabase-teste)"
  elif [ -n "$(app_valor "$APP_EXT" DIRECTORY_API_URL)" ] && [ -n "$(app_valor "$APP_EXT" DIRECTORY_API_KEY)" ]; then
    ok "base de alunos: DIRECTORY_API configurada"
  else
    aviso "base de alunos ainda não ligada: só entra quem foi criado aqui (app-admin, contas de revisão)"
  fi
}

# A API roda sem root desde a etapa 1 do PRD de Otimização (USER node, uid 1000,
# no Dockerfile de apps/api). O volume app_uploads nasceu com dono root: sem isto a
# API nova não grava a mídia dos alunos em /app/uploads. Idempotente e calado
# quando o dono já é 1000:1000; sem a imagem alpine, avisa e segue.
# Versão fixa (24/10, INF-14): era alpine:3.20 (fora de suporte desde 04/2026).
ALPINE_IMG=alpine:3.24.3
app_uploads_dono() {
  local vol="${APP_STACK}_app_uploads" dono
  docker volume inspect "$vol" >/dev/null 2>&1 || return 0
  if ! docker image inspect "$ALPINE_IMG" >/dev/null 2>&1 && ! docker pull -q "$ALPINE_IMG" >/dev/null 2>&1; then
    aviso "não baixou $ALPINE_IMG: dono de $vol não conferido (a API, sem root, pode não gravar em /app/uploads)"
    return 0
  fi
  dono=$(docker run --rm -v "$vol:/u" "$ALPINE_IMG" stat -c '%u:%g' /u 2>/dev/null) || dono=
  [ "$dono" = "1000:1000" ] && return 0
  if docker run --rm -v "$vol:/u" "$ALPINE_IMG" chown -R 1000:1000 /u; then
    ok "volume $vol entregue ao uid 1000 (API sem root)"
  else
    aviso "não ajustou o dono de $vol: a API pode não gravar em /app/uploads"
  fi
}

# Provisório (autorizado pelo dono em 21/10, enquanto a cobrança do GitHub Actions está bloqueada):
# baixa o código do app com um token só de leitura e monta as três imagens aqui, com os mesmos
# Dockerfiles e argumentos do imagens-vps.yml. O token vai por variável de ambiente do git (nunca na
# linha de comando, no .git/config nem em log) e some no fim. As imagens ganham o rótulo
# crystal.construida-na-vps=1, que o app-subir aceita quando a tag não existe no ghcr.io. Rodar de
# madrugada: o build do web pesa na CPU. Voltar ao GitHub assim que a cobrança normalizar.
app_construir() {
  local ref="${2:-}" esperado="${3:-}" t dir sha tag app livre url cab
  echo "$ref" | grep -Eq '^[A-Za-z0-9._/-]{1,100}$' || falha "informe a branch ou o commit: bash $0 app-construir painel/onda6 c45a71a"
  [ -z "$esperado" ] || echo "$esperado" | grep -Eq '^[0-9a-f]{7,40}$' || falha "SHA esperado inválido: use 7 a 40 letras de 0-9a-f"
  command -v git >/dev/null || falha "falta o git: apt-get install -y git"
  livre=$(df -Pk /var/lib/docker 2>/dev/null | awk 'NR==2{print int($4/1048576)}')
  [ "${livre:-0}" -ge 8 ] || falha "pouco disco para montar as imagens (${livre:-?} GB livres em /var/lib/docker; precisa de 8). Rode: docker image prune -f"
  url="https://github.com/LFcrystal766/crystal-web-chat.git"
  echo "Token do GitHub SÓ DE LEITURA do código do crystal-web-chat (fine-grained: Contents = Read-only)."
  read -rsp "Cole e dê Enter (não aparece na tela): " t; echo
  [ -n "$t" ] || falha "token vazio"
  cab="AUTHORIZATION: basic $(printf 'x-access-token:%s' "$t" | base64 -w0)"
  unset t
  dir=$(mktemp -d /root/crystal-construir.XXXXXX); chmod 700 "$dir"
  echo "== código ($ref)"
  if ! GIT_TERMINAL_PROMPT=0 GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=http.https://github.com/.extraheader GIT_CONFIG_VALUE_0="$cab" \
       git -C "$dir" clone -q --filter=blob:none --no-checkout "$url" src >/dev/null 2>&1; then
    unset cab; rm -rf "$dir"; falha "o GitHub recusou o token (vencido, sem acesso ao crystal-web-chat ou sem Contents: Read)"
  fi
  if ! GIT_TERMINAL_PROMPT=0 GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=http.https://github.com/.extraheader GIT_CONFIG_VALUE_0="$cab" \
       git -C "$dir/src" fetch -q origin "$ref" >/dev/null 2>&1; then
    unset cab; rm -rf "$dir"; falha "não achei '$ref' no crystal-web-chat"
  fi
  unset cab
  git -C "$dir/src" checkout -q FETCH_HEAD || { rm -rf "$dir"; falha "checkout de $ref falhou"; }
  sha=$(git -C "$dir/src" rev-parse HEAD)
  if [ -n "$esperado" ] && [ "${sha#"$esperado"}" = "$sha" ]; then
    rm -rf "$dir"; falha "o código de '$ref' está em ${sha:0:7}, não em $esperado: confira antes de montar"
  fi
  tag="sha-${sha:0:7}"
  ok "código em ${sha:0:7} (tag $tag)"
  for app in api web crystal; do
    echo "== imagem $app ($tag): pode levar de 3 a 15 minutos"
    if ! DOCKER_BUILDKIT=1 nice -n 10 docker build -q \
        -f "$dir/src/apps/$app/Dockerfile" \
        --build-arg NEXT_PUBLIC_API_URL=https://api.crystalnowpp.com.br \
        --build-arg APP_VERSION="$tag" \
        --label crystal.construida-na-vps=1 \
        --label org.opencontainers.image.revision="$sha" \
        --label org.opencontainers.image.version="$tag" \
        -t "$APP_IMG-$app:$tag" "$dir/src" >/dev/null; then
      rm -rf "$dir"
      falha "a imagem $app não montou. Rode de novo e mande a saída (sem o -q do docker build dá para ver o erro)"
    fi
    ok "$APP_IMG-$app:$tag"
  done
  rm -rf "$dir"
  echo
  ok "imagens prontas nesta VPS. Próximo passo: bash $0 backup && bash $0 app-subir $tag"
}

app_subir() {
  local tag="${2:-}"
  echo "$tag" | grep -Eq '^(sha-[0-9a-f]{7}|v[0-9][0-9A-Za-z.-]*)$' \
    || falha "informe a tag das imagens: bash $0 app-subir sha-XXXXXXX (veja em GitHub > crystal-web-chat > Actions > imagens-vps)"
  [ "$(docker info --format '{{.Swarm.ControlAvailable}}')" = "true" ] || falha "este nó não é manager do Swarm"
  docker network inspect network_swarm_public >/dev/null 2>&1 || falha "rede network_swarm_public não existe"
  docker service ls --format '{{.Name}}' | grep -q '^traefik_traefik$' || aviso "Traefik não encontrado: sem ele app. e api. não respondem"
  # INF-06: a API e o web vão para borda_api e borda_web; o Traefik tem de estar nelas antes.
  redes_unica || redes_criar
  redes_exigir_traefik borda_api borda_web

  echo "== imagens $tag"
  local img locais=0
  local -A dig=([api]="" [web]="" [crystal]="")
  for img in api web crystal; do
    if docker pull -q "$APP_IMG-$img:$tag" >/dev/null 2>&1; then
      # O digest do que veio do ghcr.io vai junto da tag no yaml (INF-17): o spec diz exatamente
      # qual imagem roda, e ele aparece aqui para comparar com o resumo do imagens-vps no GitHub.
      dig[$img]=$(docker image inspect -f '{{range .RepoDigests}}{{println .}}{{end}}' "$APP_IMG-$img:$tag" 2>/dev/null \
        | grep -m1 -E "^$APP_IMG-$img@sha256:[0-9a-f]{64}\$" | sed 's/.*@/@/' || true)
      continue
    elif [ "$(docker image inspect -f '{{index .Config.Labels "crystal.construida-na-vps"}}' "$APP_IMG-$img:$tag" 2>/dev/null)" = "1" ]; then
      locais=$((locais + 1))   # montada aqui por app-construir: não existe no ghcr.io
    else
      falha "não baixou $APP_IMG-$img:$tag. Rodou 'bash $0 app-ghcr'? O build terminou no GitHub? (sem o GitHub: bash $0 app-construir)"
    fi
  done
  if [ "$locais" -gt 0 ]; then ok "imagens $tag: $locais montada(s) nesta VPS (app-construir), o resto baixado"; else ok "$APP_IMG-api, -web e -crystal:$tag baixadas"; fi
  for img in api web crystal; do
    [ -n "${dig[$img]}" ] && ok "  $img presa no digest ${dig[$img]#@}"
  done

  echo "== segredos e ambiente"
  app_gerar_segredos "$tag"
  crystal_chave_sincronizar
  app_gerar_env
  app_env_preflight "$tag"

  echo "== stack"
  mkdir -p "$ORIG" "$STACKS"; chmod 700 "$BASE" "$STACKS"
  baixar_conferido "stacks-app/$APP_YAML" "$ORIG/$APP_YAML" || falha "sem $APP_YAML conferido: a stack no ar não foi trocada"
  grep -q '^services:' "$ORIG/$APP_YAML" || falha "$APP_YAML não parece um compose"
  umask 077
  sed -e "s|crystal-web-chat-api:APP_TAG|crystal-web-chat-api:$tag${dig[api]}|" \
      -e "s|crystal-web-chat-web:APP_TAG|crystal-web-chat-web:$tag${dig[web]}|" \
      -e "s|crystal-web-chat-crystal:APP_TAG|crystal-web-chat-crystal:$tag${dig[crystal]}|" \
      -e "s|APP_TAG|$tag|g" -e "s|APP_ENV_DIR|$APP_DIR|g" "$ORIG/$APP_YAML" > "$STACKS/$APP_YAML"
  grep -nE 'APP_TAG|APP_ENV_DIR' "$STACKS/$APP_YAML" | grep -vE '^\s*[0-9]+:\s*#' | grep -q . && falha "marcador sobrando em $APP_YAML"
  redes_ajustar "$STACKS/$APP_YAML"
  somente_leitura_ajustar "$STACKS/$APP_YAML"
  app_uploads_dono   # a API sem root (etapa 1) precisa do volume com dono 1000:1000
  local t0; t0=$(date +%s)
  docker stack deploy --with-registry-auth -c "$STACKS/$APP_YAML" "$APP_STACK" --detach=true >/dev/null
  sleep 8   # deixa o Swarm registrar a atualização antes de conferir
  esperar_stack "$APP_STACK" 420 || { servico_log_morto "${APP_STACK}_app_api"; echo "  Logs da API: docker service logs --tail 80 ${APP_STACK}_app_api"; exit 1; }
  app_conferir_troca "$t0" "$tag"
  crystal_banco
  copia_cron_atualizar
  echo
  app_status
  painel_trava_segredos
  if [ -n "$(app_valor "$APP_EXT" SUPABASE_URL)" ] && [ -n "$(app_valor "$APP_EXT" SUPABASE_SERVICE_ROLE_KEY)" ]; then
    echo
    if ! app_supabase_teste; then
      SUPABASE_FALHOU=1
      echo "  !! a base de alunos NÃO respondeu como devia: todo login de aluna da base vai dar 503 até corrigir (acima)"
    fi
  fi
}

# "1/1" não basta: se a tarefa nova morrer na subida, o Swarm volta sozinho para o
# spec anterior e o serviço fica 1/1 (aconteceu em 05/10 com a API da etapa 1). Com
# tag nova, a imagem denuncia; com a MESMA tag (só o .externos mudou), só o
# UpdateStatus mostra (achado 4). Ver conferir_atualizacao.
app_conferir_troca() { # app_conferir_troca T0 TAG
  local t0="$1" tag="$2" falhou=0
  conferir_atualizacao "$t0" "$tag" "${APP_STACK}_app_api" "${APP_STACK}_app_web" "${APP_STACK}_app_crystal" || falhou=1
  conferir_atualizacao "$t0" - "${APP_STACK}_app_postgres" "${APP_STACK}_app_redis" || falhou=1
  if [ "$falhou" = 1 ]; then
    echo
    falha "a subida de $tag não ficou de pé (log acima). Se só o .externos mudou, desfaça a mudança (app-definir/app-remover) e rode app-subir de novo; se a tag mudou, volte com 'bash $0 app-subir TAG_ANTERIOR'. Mande o log acima para a sessão"
  fi
  ok "os três serviços estão em $tag e nenhum voltou (UpdateStatus sem rollback)"
}

# Antes do deploy: o api.env novo passa pelo loadEnv da própria imagem, num contêiner
# sem rede que some em seguida. Valor errado aparece aqui, com a API atual ainda no ar,
# em vez de virar rollback depois. Só nomes e motivos aparecem, nunca valores.
app_env_preflight() { # app_env_preflight TAG
  local saida
  # shellcheck disable=SC2016
  saida=$(timeout 120 docker run --rm --network none --env-file "$APP_DIR/api.env" -w /app/apps/api \
    --entrypoint ./node_modules/.bin/tsx "$APP_IMG-api:$1" --eval \
    'import("./src/env.ts").then(m=>{m.loadEnv();console.log("CRYSTAL_ENV_OK")}).catch(e=>{console.log("CRYSTAL_ENV_ERRO");const i=e&&e.issues;console.log(i?i.map(x=>x.path.join(".")+": "+x.message).join("\n"):String(e&&e.message));process.exit(3)})' \
    2>&1) || true
  case "$saida" in
    *CRYSTAL_ENV_OK*) ok "api.env aceito pelo boot da API $1 (conferido antes do deploy)" ;;
    *CRYSTAL_ENV_ERRO*)
      printf '%s\n' "$saida" | sed -n '/CRYSTAL_ENV_ERRO/,$p' | sed '1d; s/^/     /' | head -25
      falha "o api.env não passa no boot da API $1 (motivos acima). Nada foi trocado: a API atual segue no ar. Corrija com app-definir/app-remover e rode de novo" ;;
    *) aviso "não deu para conferir o api.env antes do deploy; a conferência depois do deploy continua valendo" ;;
  esac
}

# Chama a função de login do Supabase como a API chama, com um CPF fictício (dígitos
# válidos, de ninguém) e e-mail .invalid. Mostra só o código HTTP e o que ele quer
# dizer: nunca a chave nem a resposta. A chave vai ao curl pela entrada padrão.
app_supabase_teste() {
  local url chave rpc code modo corpo sql
  url=$(app_valor "$APP_EXT" SUPABASE_URL); chave=$(app_valor "$APP_EXT" SUPABASE_SERVICE_ROLE_KEY)
  # Testa a função que o modo de login usa (07/10): só e-mail (padrão) ou CPF + e-mail.
  modo=$(app_valor "$APP_EXT" LOGIN_MODO); modo=${modo:-email}
  if [ "$modo" = "cpf_email" ]; then
    rpc=$(app_valor "$APP_EXT" SUPABASE_LOGIN_RPC); rpc=${rpc:-app_verificar_login}
    corpo='{"p_cpf":"52998224725","p_email":"teste@exemplo.invalid"}'; sql=app_verificar_login.sql
    echo "== base de alunos: POST $url/rest/v1/rpc/$rpc com CPF fictício (LOGIN_MODO=cpf_email)"
  else
    rpc=$(app_valor "$APP_EXT" SUPABASE_LOGIN_EMAIL_RPC); rpc=${rpc:-app_verificar_login_email}
    corpo='{"p_email":"teste@exemplo.invalid"}'; sql=app_verificar_login_email.sql
    echo "== base de alunos: POST $url/rest/v1/rpc/$rpc com e-mail fictício (LOGIN_MODO=email)"
  fi
  [ -n "$url" ] && [ -n "$chave" ] || falha "SUPABASE_URL e SUPABASE_SERVICE_ROLE_KEY não estão definidos: bash $0 app-definir SUPABASE_URL"
  code=$(printf 'header = "apikey: %s"\nheader = "Authorization: Bearer %s"\n' "$chave" "$chave" \
    | curl -s -o /dev/null -m 20 -w '%{http_code}' -K - -X POST "$url/rest/v1/rpc/$rpc" \
        -H 'content-type: application/json' -d "$corpo") || code=000
  chave=""
  case "$code" in
    200) ok "HTTP 200: a função $rpc existe e a chave vale (base de alunos no ar)" ;;
    404) aviso "HTTP 404: a função $rpc não existe no Supabase. Rodar crystal-em-casa/supabase/$sql no SQL Editor; se acabou de criar: notify pgrst, 'reload schema'"; return 1 ;;
    401) aviso "HTTP 401: chave recusada. É a service_role (sb_secret_ ou JWT service_role), inteira e do mesmo projeto da URL?"; return 1 ;;
    403) aviso "HTTP 403: a chave entrou mas não pode executar $rpc (grant execute para service_role)"; return 1 ;;
    000) aviso "sem resposta: URL errada, DNS ou a VPS sem saída para o Supabase"; return 1 ;;
    *) aviso "HTTP $code: resposta inesperada do Supabase"; return 1 ;;
  esac
}

# Custo da Crystal no OpenRouter, a partir do log de uso que a nossa Crystal escreve
# a cada turno e a cada resumo ("modelo: uso do turno" / "modelo: uso do resumo",
# só números: nunca texto da conversa). Soma por tipo e modelo, média por pedido,
# parte da entrada que veio do cache, projeção para 30 dias e, no fim, o saldo da
# conta e o uso da chave (consultados de dentro do contêiner; a chave não sai).
app_custo() {
  local horas="${1:-24}" cid
  printf '%s' "$horas" | grep -Eq '^[0-9]{1,4}$' || falha "uso: app-custo [HORAS] (padrão 24)"
  [ "$horas" -ge 1 ] || falha "HORAS precisa ser 1 ou mais"
  echo "== custo da Crystal nas últimas ${horas} h (log de uso)"
  # O script vai por -c: um heredoc na entrada padrão engoliria as linhas do log.
  local somador
  somador=$(cat <<'PY'
import json, sys
horas = int(sys.argv[1])
grupos = {}
for linha in sys.stdin:
    try:
        d = json.loads(linha)
    except ValueError:
        continue
    msg = str(d.get("msg", ""))
    if not (msg.startswith("modelo: uso do") or msg == "modelo: uso da ficha"):
        continue
    tipo = "turno" if msg.endswith("turno") else "ficha" if msg.endswith("ficha") else "resumo"
    g = grupos.setdefault((tipo, str(d.get("modelo", "?"))), dict(n=0, ent=0, cache=0, sai=0, rac=0, usd=0.0, ms=0))
    g["n"] += 1
    g["ent"] += int(d.get("tokens_entrada") or 0)
    g["cache"] += int(d.get("tokens_cache") or 0)
    g["sai"] += int(d.get("tokens_saida") or 0)
    g["rac"] += int(d.get("tokens_raciocinio") or 0)
    g["usd"] += float(d.get("custo_usd") or 0)
    g["ms"] += int(d.get("ms") or 0)
if not grupos:
    print("  nenhuma linha de uso no período (imagem antiga, sem conversa, ou a Crystal não respondeu)")
    sys.exit(0)
print(f"  {'tipo':7} {'modelo':34} {'pedidos':>7} {'entrada':>9} {'cache%':>6} {'saída':>7} {'racioc.':>7} {'US$':>9} {'US$/pedido':>10} {'ms méd':>6}")
total = 0.0
turnos = 0
for (tipo, modelo), g in sorted(grupos.items()):
    pc = 100 * g["cache"] / g["ent"] if g["ent"] else 0
    print(f"  {tipo:7} {modelo[:34]:34} {g['n']:7d} {g['ent']:9d} {pc:5.0f}% {g['sai']:7d} {g['rac']:7d} {g['usd']:9.4f} {g['usd']/g['n']:10.5f} {g['ms']//g['n']:6d}")
    total += g["usd"]
    if tipo == "turno":
        turnos += g["n"]
print(f"  total: US$ {total:.4f} em {horas} h; {turnos} turno(s)")
if turnos:
    print(f"  custo por turno, resumo incluído: US$ {total/turnos:.5f}")
print(f"  projeção para 30 dias neste ritmo: US$ {total/horas*24*30:.2f}")
PY
)
  docker service logs --since "${horas}h" "${APP_STACK}_app_crystal" 2>/dev/null \
    | grep -E '"msg":"modelo: uso d(o|a ficha)' | sed 's/^[^{]*//' \
    | python3 -I -c "$somador" "$horas"
  echo "== conta do OpenRouter (consultada de dentro do contêiner; a chave não aparece)"
  cid=$(docker ps -q -f name=${APP_STACK}_app_crystal | head -1)
  [ -n "$cid" ] || { aviso "serviço app_crystal não está rodando"; return 0; }
  docker exec "$cid" node -e '
    const h = { authorization: "Bearer " + (process.env.OPENROUTER_API_KEY || "") };
    const g = async (p) => { const r = await fetch("https://openrouter.ai/api/v1" + p, { headers: h, signal: AbortSignal.timeout(15000) }); return [r.status, await r.json().catch(() => ({}))]; };
    (async () => {
      const [s1, k] = await g("/key"); const d = k.data || {};
      console.log(`  chave da Crystal (${s1}): hoje US$ ${d.usage_daily ?? "?"}, semana US$ ${d.usage_weekly ?? "?"}, mês US$ ${d.usage_monthly ?? "?"}, limite ${d.limit == null ? "NENHUM (pôr um limite mensal em openrouter.ai/settings/keys)" : "US$ " + d.limit}`);
      const [s2, c] = await g("/credits"); const cd = c.data || {};
      if (typeof cd.total_credits === "number") {
        const saldo = cd.total_credits - cd.total_usage;
        console.log(`  conta (${s2}): comprados US$ ${cd.total_credits.toFixed(2)}, usados US$ ${cd.total_usage.toFixed(2)}, saldo US$ ${saldo.toFixed(2)}${saldo < 20 ? "  <- BAIXO: recarregar, senão a Crystal para com 402" : ""}`);
      } else console.log(`  conta (${s2}): sem dados de crédito`);
    })().catch((e) => console.log("  OpenRouter não respondeu:", e.name));' 2>/dev/null || aviso "não consultou o OpenRouter"
}

app_status() {
  echo "== Serviços do app"
  docker service ls --filter "label=com.docker.stack.namespace=$APP_STACK" --format '{{.Name}} {{.Replicas}} {{.Image}}' \
    | awk '{printf "  %-26s %-5s %s\n",$1,$2,$3}'
  echo
  echo "== HTTPS (certificado tem que ser válido, sem -k)"
  local u code
  for u in "https://app.$DOMINIO/" "https://api.$DOMINIO/healthz"; do
    code=$(curl -s -o /dev/null -m 20 -w '%{http_code}' "$u" 2>/dev/null) || true
    code=${code:-000}
    case "$code" in
      200) ok "$u -> 200" ;;
      000) aviso "$u sem resposta ou certificado inválido (DNS do nome existe e está cinza? Traefik ainda emitindo?)" ;;
      *) aviso "$u -> $code" ;;
    esac
  done
}

# Script temporário em /app/apps/api, ao lado do src/ que ele importa. Desde a etapa 1
# a API roda sem root (USER node) e essa pasta é do root: sem -u 0 o 'cat >' dá
# "Permission denied" (achado 7 da revisão de 05/10). Só gravar e apagar usam root; o
# tsx roda como node. O arquivo não tem dado pessoal (o CPF vai pelo ambiente do
# docker exec) e fica 644 para o node ler.
app_api_ts_gravar() { # app_api_ts_gravar CID NOME < código
  docker exec -i -u 0 -w /app/apps/api "$1" sh -c 'umask 022; cat > "$1"' sh "$2"
}
app_api_ts_apagar() { # app_api_ts_apagar CID NOME
  docker exec -u 0 "$1" rm -f "/app/apps/api/$2" >/dev/null 2>&1 \
    || aviso "não apagou /app/apps/api/$2 no contêiner (não tem dado pessoal; some no próximo app-subir)"
}

# O CPF passa só pelo ambiente de um 'docker exec' que termina em seguida: não
# entra no spec do serviço (que o Swarm guarda com histórico), nem em log,
# nem no histórico do shell.
app_admin() {
  local cid cpf email nome
  cid=$(docker ps -q -f name=${APP_STACK}_app_api | head -1)
  [ -n "$cid" ] || falha "a API do app não está rodando: bash $0 app-subir TAG"
  read -rsp "CPF do primeiro admin, só números (não aparece): " cpf; echo
  cpf=$(printf '%s' "$cpf" | tr -cd '0-9')
  [ "${#cpf}" -eq 11 ] || falha "CPF precisa de 11 dígitos"
  read -rp "E-mail do admin (recebe o código de login): " email
  echo "$email" | grep -Eq '^[^@ :]+@[^@ :]+\.[^@ :]+$' || falha "e-mail inválido"
  read -rp "Nome do admin: " nome
  [ -n "$nome" ] && [ "${nome#*:}" = "$nome" ] || falha "nome vazio ou com ':'"
  app_api_ts_gravar "$cid" .admin-bootstrap.ts <<'TS' || { unset cpf; falha "não gravou o script temporário na API (contêiner $cid)"; }
import { PrismaClient } from "@prisma/client";
import { createPrismaRepos } from "./src/db/prisma";
import { loadEnv } from "./src/env";
import { bootstrapAdmin } from "./src/seed";

const env = loadEnv();
const prisma = new PrismaClient();
try {
  const r = await bootstrapAdmin(createPrismaRepos(prisma), env);
  if (!r) console.log("ADMIN_BOOTSTRAP vazio, nada feito");
  else if (r.created) console.log(`admin criado (CPF terminado em ${r.cpfLast4})`);
  else console.log("já existe admin ativo; nada feito");
} finally {
  await prisma.$disconnect();
}
TS
  # tsx roda como o usuário da imagem (node): só a gravação e a remoção usam root.
  if ! ADMIN_BOOTSTRAP="$cpf:$email:$nome" docker exec -e ADMIN_BOOTSTRAP -w /app/apps/api "$cid" \
    ./node_modules/.bin/tsx .admin-bootstrap.ts; then
    app_api_ts_apagar "$cid" .admin-bootstrap.ts; unset cpf; falha "bootstrap do admin falhou"
  fi
  app_api_ts_apagar "$cid" .admin-bootstrap.ts
  unset cpf
  echo "  Próximo: entrar em https://app.$DOMINIO com esse CPF e e-mail (o código chega pelo Resend)."
}

# Conta de aluno criada à mão (equipe, testes, quem ainda não está na base de
# alunos). CPF digitado sem eco e validado pelos dígitos; nada na linha de comando.
# Quando a base do Supabase entrar (autoritativa), o login confere lá também:
# quem não for aluno ativo na base deixa de entrar.
app_aluno() {
  local cid cpf email nome tel
  cid=$(docker ps -q -f name=${APP_STACK}_app_api | head -1)
  [ -n "$cid" ] || falha "a API do app não está rodando: bash $0 app-subir TAG"
  # CPF opcional desde 07/10 (login só com e-mail): Enter pula e a identidade da conta é o e-mail.
  read -rsp "CPF, só números (opcional, Enter pula; não aparece): " cpf; echo
  cpf=$(printf '%s' "$cpf" | tr -cd '0-9')
  [ -z "$cpf" ] || [ "${#cpf}" -eq 11 ] || falha "CPF precisa de 11 dígitos (ou Enter para pular)"
  read -rp "E-mail (é como a aluna entra; recebe o código de login): " email
  echo "$email" | grep -Eq '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' || falha "e-mail inválido"
  read -rp "Nome: " nome
  [ -n "$nome" ] || falha "nome vazio"
  read -rp "WhatsApp com DDD (Enter para pular): " tel
  tel=$(printf '%s' "$tel" | tr -cd '0-9')
  if [ -n "$tel" ]; then
    case "${#tel}" in 10|11) tel="55$tel" ;; 12|13) ;; *) falha "telefone inválido" ;; esac
    echo "$tel" | grep -Eq '^55[1-9][0-9]9?[0-9]{8}$' || falha "telefone inválido (Brasil, com DDD)"
    tel="+$tel"
  fi
  app_api_ts_gravar "$cid" .aluno.ts <<'TS' || { unset cpf; falha "não gravou o script temporário na API (contêiner $cid)"; }
import { PrismaClient } from "@prisma/client";
import { cpfLast4, cpfSchema, emailSchema } from "@crystal/shared";
import { createPrismaRepos } from "./src/db/prisma";
import { loadEnv } from "./src/env";
import { hashCpf } from "./src/lib/crypto";

const env = loadEnv();
// CPF opcional (07/10, login só com e-mail): vazio = conta sem CPF, identificada pelo e-mail.
const cpfBruto = (process.env.ALUNO_CPF ?? "").trim();
let cpf: string | null = null;
if (cpfBruto) {
  const parsed = cpfSchema.safeParse(cpfBruto);
  if (!parsed.success) {
    console.log("CPF inválido (dígitos verificadores não batem)");
    process.exit(2);
  }
  cpf = parsed.data;
}
const email = emailSchema.parse((process.env.ALUNO_EMAIL ?? "").trim().toLowerCase());
const prisma = new PrismaClient();
try {
  const repos = createPrismaRepos(prisma);
  const cpfHash = cpf ? hashCpf(cpf, env.CPF_SALT) : null;
  const existente = cpfHash ? await repos.users.findByCpfHash(cpfHash) : null;
  if (existente) {
    console.log(`já existe conta com esse CPF (final ${existente.cpfLast4 ?? "?"}, papel ${existente.role}); nada feito`);
  } else if (await repos.users.findByEmail(email)) {
    console.log("já existe conta com esse e-mail; nada feito");
  } else {
    await repos.users.create({
      cpfHash,
      cpfLast4: cpf ? cpfLast4(cpf) : null,
      name: (process.env.ALUNO_NOME ?? "").trim(),
      role: "user",
      crystalContactId: null,
      phoneE164: process.env.ALUNO_TEL || null,
      email,
      // Conta local: não passa pela base de alunas (Supabase) no login. Para testadores
      // e equipe usando como aluna. Precisa da API com o campo (imagens a partir de 05/10).
      localAccount: true,
    });
    console.log(`conta local de aluno criada (${cpf ? `CPF final ${cpfLast4(cpf)}` : "sem CPF"}): entra sem passar pela base de alunas`);
  }
} finally {
  await prisma.$disconnect();
}
TS
  if ! ALUNO_CPF="$cpf" ALUNO_EMAIL="$email" ALUNO_NOME="$nome" ALUNO_TEL="$tel" \
    docker exec -e ALUNO_CPF -e ALUNO_EMAIL -e ALUNO_NOME -e ALUNO_TEL -w /app/apps/api "$cid" \
    ./node_modules/.bin/tsx .aluno.ts; then
    app_api_ts_apagar "$cid" .aluno.ts; unset cpf; falha "não criou a conta"
  fi
  app_api_ts_apagar "$cid" .aluno.ts
  unset cpf
  echo "  Entrar em https://app.$DOMINIO com esse e-mail (o código chega por e-mail; com LOGIN_MODO=cpf_email, também o CPF)."
  echo "  É uma conta LOCAL: não passa pela base de alunas. Quem está na base com acesso ativo não precisa disto."
}

# Troca TODOS os segredos do app recriando o banco dele do zero. Só enquanto o
# banco não tem ninguém cadastrado: com usuário dentro, ENCRYPTION_KEY e
# CPF_SALT novos deixariam os dados ilegíveis. Mantém .externos (Resend etc.).
#   bash bootstrap-vps.sh app-recomecar TAG --confirmo
app_recomecar() {
  local tag="${2:-}" conf="${3:-}" cid n v ts up
  [ "$conf" = "--confirmo" ] || falha "isto apaga o banco do app e troca os segredos. Se for isso: bash $0 app-recomecar TAG --confirmo"
  echo "$tag" | grep -Eq '^(sha-[0-9a-f]{7}|v[0-9][0-9A-Za-z.-]*)$' || falha "informe a tag: bash $0 app-recomecar sha-XXXXXXX --confirmo"
  # Trava real (achado 29): antes, contêiner ausente ou resposta "?" deixava passar e
  # apagava um banco com alunas. Agora só segue com n=0 comprovado.
  cid=$(docker ps -q -f name=${APP_STACK}_app_postgres 2>/dev/null | head -1 || true)
  [ -n "$cid" ] || falha "o Postgres do app não está rodando: não dá para provar que o banco está vazio. Nada apagado"
  n=$(docker exec "$cid" psql -U crystal -d crystal_web_chat -tAc 'select count(*) from users' 2>/dev/null | tr -d '[:space:]' || true)
  [ -n "$n" ] || falha "o banco do app não respondeu: não dá para provar que está vazio. Nada apagado"
  [ "$n" = "0" ] || falha "o banco do app tem $n usuário(s). Trocar ENCRYPTION_KEY e CPF_SALT agora os tornaria ilegíveis. Não recomece"
  [ -t 0 ] || falha "rode num terminal: este comando pede confirmação digitada"
  read -rp "Digite APAGAR para apagar o banco do app e trocar TODOS os segredos dele: " v
  [ "$v" = APAGAR ] || falha "nada apagado"
  # Cópia antes de apagar: bancos (app e memória da Crystal), uploads e os segredos
  # antigos, que abrem esses dumps. Sem a cópia, nada é apagado.
  ts=$(date -u +%Y%m%dT%H%M%SZ)
  mkdir -p "$BACKUPS"; chmod 700 "$BACKUPS"; umask 077
  backup_pg "$cid" crystal crystal_web_chat "$BACKUPS/crystal_web_chat-antes-recomecar-$ts.sql.gz" || falha "não copiei o banco do app antes de apagar. Nada apagado"
  if docker exec "$cid" psql -U crystal -d crystal_web_chat -tAc "select 1 from pg_database where datname = 'crystal_agente'" 2>/dev/null | grep -q 1; then
    backup_pg "$cid" crystal crystal_agente "$BACKUPS/crystal_agente-antes-recomecar-$ts.sql.gz" || falha "não copiei a memória da Crystal antes de apagar. Nada apagado"
  fi
  up=$VOLUMES/${APP_STACK}_app_uploads/_data
  if [ -d "$up" ] && [ -n "$(ls -A "$up" 2>/dev/null)" ]; then
    tar -C "$up" -czf "$BACKUPS/crystal_uploads-antes-recomecar-$ts.tar.gz" . || falha "não copiei os uploads antes de apagar. Nada apagado"
  fi
  [ ! -f "$APP_SEG" ] || cp -p "$APP_SEG" "$APP_DIR/.segredos.antes-recomecar-$ts" || falha "não copiei $APP_SEG. Nada apagado"
  ok "cópia em $BACKUPS (*-antes-recomecar-$ts) e $APP_DIR/.segredos.antes-recomecar-$ts"
  echo "== removendo a stack $APP_STACK"
  docker stack rm "$APP_STACK" >/dev/null 2>&1 || true
  local t=0
  while docker ps -aq -f "label=com.docker.stack.namespace=$APP_STACK" 2>/dev/null | grep -q . && [ $t -lt 120 ]; do sleep 3; t=$((t+3)); done
  sleep 5
  echo "== apagando os volumes do app (banco vazio)"
  for v in app_postgres_data app_redis_data app_uploads; do
    if docker volume inspect "${APP_STACK}_$v" >/dev/null 2>&1; then
      docker volume rm "${APP_STACK}_$v" >/dev/null || falha "não apagou o volume ${APP_STACK}_$v (ainda em uso?). Os segredos NÃO foram trocados; rode de novo em 1 min"
    fi
  done
  rm -f "$APP_SEG" "$APP_DIR/api.env" "$APP_DIR/postgres.env" "$APP_DB_PAPEL_ARQ"
  ok "segredos antigos apagados (cópia guardada); $APP_EXT mantido"
  app_subir app-subir "$tag"
}

# ------------------------------------------------------------------ nossa Crystal
# Com o app apontando para a nossa Crystal, a chave que o app manda TEM que ser a
# CRYSTAL_AGENTE_KEY que a Crystal confere. Depois de um app-recomecar (segredos novos)
# o .externos ficava com a chave antiga e todo chat dava 401 (achado 30).
crystal_chave_sincronizar() {
  local nova
  case "$(app_valor "$APP_EXT" CRYSTAL_API_URL)" in http://app_crystal:*) ;; *) return 0 ;; esac
  nova=$(app_valor "$APP_SEG" CRYSTAL_AGENTE_KEY)
  [ -n "$nova" ] || falha "CRYSTAL_AGENTE_KEY ausente em $APP_SEG"
  if [ "$(app_valor "$APP_EXT" CRYSTAL_API_KEY)" != "$nova" ]; then
    app_gravar CRYSTAL_API_KEY "$nova"
    ok "CRYSTAL_API_KEY do app igualada à CRYSTAL_AGENTE_KEY da nossa Crystal"
  fi
  nova=""
}

# Banco e papel próprios dentro do app_postgres. O papel crystal_agente só entra no
# banco crystal_agente; o banco do app deixa de aceitar conexão de quem não é dono.
# Idempotente: roda a cada app-subir e mantém a senha igual à do .segredos.
crystal_banco() {
  local pg senha t=0
  senha=$(app_valor "$APP_SEG" CRYSTAL_DB_SENHA)
  [ -n "$senha" ] || { aviso "sem CRYSTAL_DB_SENHA: banco da Crystal não criado"; return 0; }
  until pg=$(docker ps -q -f name=${APP_STACK}_app_postgres | head -1) && [ -n "$pg" ] \
        && docker exec "$pg" pg_isready -U crystal -d crystal_web_chat >/dev/null 2>&1; do
    [ $t -ge 120 ] && { aviso "Postgres do app não respondeu: banco da Crystal não criado"; return 0; }
    sleep 3; t=$((t+3))
  done
  # A senha vai pela entrada padrão (heredoc), não pela linha de comando.
  # Revisão de 24/10 (INF-27): se uma instrução falhar, o Postgres não a grava no log (com a
  # senha dentro), nem como STATEMENT nem como CONTEXT. crystal é superusuário: pode mudar isso.
  docker exec -i "$pg" psql -X -v ON_ERROR_STOP=1 -q -U crystal -d crystal_web_chat >/dev/null <<SQL || falha "não criou o banco da Crystal"
set log_statement = 'none';
set log_min_error_statement = 'panic';
set log_error_verbosity = 'terse';
do \$\$ begin
  if not exists (select from pg_roles where rolname = 'crystal_agente') then
    create role crystal_agente login password '$senha';
  else
    alter role crystal_agente login password '$senha';
  end if;
end \$\$;
select 'create database crystal_agente owner crystal_agente'
 where not exists (select from pg_database where datname = 'crystal_agente')\\gexec
revoke all on database crystal_agente from public;
revoke connect on database crystal_web_chat from public;
SQL
  unset senha
  ok "banco crystal_agente pronto (papel próprio, sem acesso ao banco do app)"
}

# ------------------------------------------------------------------ app-db-papel
# TESTAR PRIMEIRO (INF-07, 24/10/2026). A API e a migração do Prisma entram no Postgres do
# app como crystal, o superusuário de bootstrap da imagem (POSTGRES_USER): uma falha na API
# viraria COPY ... TO PROGRAM no contêiner do Postgres e leitura do banco da Crystal. O
# Postgres 16 não deixa tirar o superusuário do papel de bootstrap, então o caminho é um
# papel novo, crystal_api, sem superusuário, dono do banco crystal_web_chat e de tudo no
# schema public (tabelas, sequências, tipos, funções): é o que o prisma migrate deploy
# precisa. crystal continua superusuário para backup, crystal_banco e diagnóstico, e deixa
# de entrar pela API. Senha nova (APP_DB_API_SENHA) no .segredos; marca em .db-papel.
# Roteiro, um de cada vez:
#   bash bootstrap-vps.sh backup
#   bash bootstrap-vps.sh app-db-papel                simulação: faz tudo numa transação e desfaz
#   bash bootstrap-vps.sh app-db-papel --confirmo     passo 1: papel e donos de verdade (a API segue
#                                                     no ar como crystal: superusuário passa por cima)
#   bash bootstrap-vps.sh app-subir TAG_ATUAL         passo 2: api.env com crystal_api; migra e sobe com ele
# Volta: bash bootstrap-vps.sh app-db-papel --voltar && bash bootstrap-vps.sh app-subir TAG_ATUAL
#   (a API volta a entrar como crystal; os donos ficam com crystal_api, sem efeito para o superusuário).
# Idempotente: depois de uma migração feita como crystal ou de uma restauração (o backup é
# --no-owner), rodar --confirmo de novo devolve os donos ao crystal_api.
app_db_papel() {
  local modo="${2:-}" pg senha fim saida n
  case "$modo" in
    "") fim=rollback ;;
    --confirmo) fim=commit ;;
    --voltar)
      rm -f "$APP_DB_PAPEL_ARQ"
      ok "marca apagada: no próximo app-subir a API volta a entrar como crystal"
      echo "Agora: bash $0 app-subir $(app_tag_atual)"
      return 0 ;;
    *) falha "uso: bash $0 app-db-papel [--confirmo | --voltar]   (sem nada: simulação, não muda nada)" ;;
  esac
  [ -f "$APP_SEG" ] || falha "o app ainda não subiu: bash $0 app-subir TAG"
  pg=$(docker ps -q -f name=${APP_STACK}_app_postgres | head -1); [ -n "$pg" ] || falha "Postgres do app não está rodando"
  docker exec "$pg" pg_isready -U crystal -d crystal_web_chat >/dev/null 2>&1 || falha "Postgres do app não responde"
  if [ "$fim" = commit ]; then
    if [ -z "$(app_valor "$APP_SEG" APP_DB_API_SENHA)" ]; then
      umask 077
      echo "APP_DB_API_SENHA=$(openssl rand -hex 24)" >> "$APP_SEG"
      chmod 600 "$APP_SEG"
      ok "APP_DB_API_SENHA gerada em $APP_SEG. Copie pro cofre: bash $0 app-segredos"
    fi
    senha=$(app_valor "$APP_SEG" APP_DB_API_SENHA)
    echo "== papel crystal_api e donos do banco do app (de verdade)"
  else
    senha=$(openssl rand -hex 24)   # só para a simulação: some com o ROLLBACK
    echo "== simulação: tudo numa transação, desfeita no fim (nada muda)"
  fi
  printf '%s' "$senha" | grep -Eq '^[0-9a-f]{48}$' || falha "APP_DB_API_SENHA em $APP_SEG não é hex de 48 caracteres"
  # A senha vai pela entrada padrão, nunca na linha de comando; com log_min_error_statement
  # em panic e log_error_verbosity terse, uma instrução que falhe não vai para o log do
  # Postgres com a senha, nem como STATEMENT nem como CONTEXT (INF-27).
  # Da saída só passam as linhas nome=valor e a primeira linha de um erro.
  saida=$(docker exec -i "$pg" psql -X -v ON_ERROR_STOP=1 -q -tA -U crystal -d crystal_web_chat 2>&1 <<SQL
set log_statement = 'none';
set log_min_error_statement = 'panic';
set log_error_verbosity = 'terse';
set lock_timeout = '5s';
begin;
do \$\$ begin
  if not exists (select from pg_roles where rolname = 'crystal_api') then
    create role crystal_api login nosuperuser nocreatedb nocreaterole noreplication nobypassrls noinherit password '$senha';
  else
    alter role crystal_api login nosuperuser nocreatedb nocreaterole noreplication nobypassrls noinherit password '$senha';
  end if;
end \$\$;
alter database crystal_web_chat owner to crystal_api;
do \$\$ declare r record; begin
  if (select nspowner from pg_namespace where nspname = 'public') not in ('pg_database_owner'::regrole, 'crystal_api'::regrole) then
    alter schema public owner to crystal_api;
  end if;
  -- tabelas, visões e sequências soltas (a de coluna serial/identity acompanha a tabela)
  for r in
    select c.oid::regclass as nome, c.relkind
      from pg_class c join pg_namespace s on s.oid = c.relnamespace
     where s.nspname = 'public' and c.relkind in ('r','p','v','m','f','S')
       and c.relowner <> 'crystal_api'::regrole
       and not exists (select 1 from pg_depend d
                        where d.classid = 'pg_class'::regclass and d.objid = c.oid
                          and (d.deptype = 'e' or (c.relkind = 'S' and d.deptype in ('a','i'))))
     order by c.relkind = 'S'
  loop
    execute format('alter %s %s owner to crystal_api',
      case r.relkind when 'v' then 'view' when 'm' then 'materialized view' when 'f' then 'foreign table'
                     when 'S' then 'sequence' else 'table' end, r.nome);
  end loop;
  -- enums, domínios, ranges e tipos compostos avulsos
  for r in
    select t.oid::regtype as nome, t.typtype
      from pg_type t join pg_namespace s on s.oid = t.typnamespace
     where s.nspname = 'public' and t.typtype in ('e','d','r','c')
       and (t.typtype <> 'c' or (select c.relkind from pg_class c where c.oid = t.typrelid) = 'c')
       and t.typowner <> 'crystal_api'::regrole
       and not exists (select 1 from pg_depend d where d.classid = 'pg_type'::regclass and d.objid = t.oid and d.deptype = 'e')
  loop
    execute format('alter %s %s owner to crystal_api', case r.typtype when 'd' then 'domain' else 'type' end, r.nome);
  end loop;
  -- funções e procedimentos (os de extensão ficam com quem instalou)
  for r in
    select p.oid::regprocedure as nome, p.prokind
      from pg_proc p join pg_namespace s on s.oid = p.pronamespace
     where s.nspname = 'public' and p.proowner <> 'crystal_api'::regrole
       and not exists (select 1 from pg_depend d where d.classid = 'pg_proc'::regclass and d.objid = p.oid and d.deptype = 'e')
  loop
    execute format('alter %s %s owner to crystal_api', case r.prokind when 'a' then 'aggregate' else 'routine' end, r.nome);
  end loop;
end \$\$;
revoke connect on database crystal_web_chat from public;
select 'superusuario=' || rolsuper from pg_roles where rolname = 'crystal_api';
select 'dono_banco=' || pg_get_userbyid(datdba) from pg_database where datname = 'crystal_web_chat';
select 'tabelas=' || count(*) from pg_class c join pg_namespace s on s.oid = c.relnamespace
 where s.nspname = 'public' and c.relkind in ('r','p');
select 'fora=' || count(*) from pg_class c join pg_namespace s on s.oid = c.relnamespace
 where s.nspname = 'public' and c.relkind in ('r','p','v','m','f') and c.relowner <> 'crystal_api'::regrole
   and not exists (select 1 from pg_depend d where d.classid = 'pg_class'::regclass and d.objid = c.oid and d.deptype = 'e');
$fim;
SQL
) || {
    printf '%s\n' "$saida" | grep -m1 'ERROR' | sed 's/^/     /'
    senha=""
    falha "o Postgres recusou (acima). Nada foi mudado: a transação foi desfeita"
  }
  printf '%s\n' "$saida" | grep -E '^(superusuario|dono_banco|tabelas|fora)=' | sed 's/^/  /'
  printf '%s\n' "$saida" | grep -qx 'superusuario=false' || { senha=""; falha "crystal_api ficaria superusuário: nada marcado"; }
  printf '%s\n' "$saida" | grep -qx 'fora=0' || { senha=""; falha "sobrou objeto do public sem crystal_api de dono (acima): nada marcado"; }
  if [ "$fim" = rollback ]; then
    senha=""
    ok "simulação limpa: crystal_api seria dono de tudo, sem superusuário. Nada mudou"
    echo "Passo 1 (de verdade): bash $0 app-db-papel --confirmo"
    return 0
  fi
  # Entra como crystal_api pela rede (scram), como a API vai entrar. A senha vai pelo
  # ambiente do docker exec (-e só com o nome), nunca na linha de comando.
  n=$(PGPASSWORD="$senha" docker exec -e PGPASSWORD "$pg" psql -X -h 127.0.0.1 -U crystal_api -d crystal_web_chat -tAc \
      "select count(*) from _prisma_migrations where finished_at is not null" 2>/dev/null | tr -d '[:space:]') || n=""
  senha=""
  printf '%s' "$n" | grep -Eq '^[0-9]+$' || falha "crystal_api não entrou pela rede com a senha do $APP_SEG. Nada marcado: a API segue como crystal. Volta dos donos não é necessária"
  umask 077
  echo crystal_api > "$APP_DB_PAPEL_ARQ"; chmod 600 "$APP_DB_PAPEL_ARQ"
  ok "crystal_api entra pela rede e lê as $n migrações do Prisma; marca gravada em $APP_DB_PAPEL_ARQ"
  echo "Passo 2: bash $0 app-subir $(app_tag_atual)   (a API passa a entrar como crystal_api; a migração roda com ele)"
  echo "Volta:   bash $0 app-db-papel --voltar && bash $0 app-subir $(app_tag_atual)"
}

# Telefone de uma conta do app (o canal da inbox identifica a pessoa pelo WhatsApp).
# Para contas criadas aqui (admin, equipe, revisão), que nascem sem telefone. Aluno
# vindo da base recebe o telefone de lá. Uso: bash bootstrap-vps.sh app-telefone EMAIL
app_telefone() {
  local email="${2:-}" tel pg n
  # Só caracteres de e-mail comum: sem aspas nem barra, o valor vai seguro para o psql.
  echo "$email" | grep -Eq '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' || falha "informe o e-mail da conta: bash $0 app-telefone voce@exemplo.com"
  read -rp "WhatsApp com DDD (ex.: 11 98888 7777): " tel
  tel=$(echo "$tel" | tr -cd '0-9')
  case "${#tel}" in 10|11) tel="55$tel" ;; 12|13) ;; *) falha "telefone inválido" ;; esac
  echo "$tel" | grep -Eq '^55[1-9][0-9]9?[0-9]{8}$' || falha "telefone inválido (Brasil, com DDD)"
  pg=$(docker ps -q -f name=${APP_STACK}_app_postgres | head -1); [ -n "$pg" ] || falha "Postgres do app não está rodando"
  # Valores pela entrada padrão, nunca na linha de comando.
  n=$(docker exec -i "$pg" psql -v ON_ERROR_STOP=1 -tA -U crystal -d crystal_web_chat <<SQL
\set tel '+$tel'
\set email '$email'
with u as (
  update users set phone_e164 = :'tel' where lower(email) = lower(:'email') returning id
), c as (
  update conversations set channel_source_id = null, channel_conversation_id = null where user_id in (select id from u)
)
select count(*) from u;
SQL
) || falha "não gravou"
  tel=""
  [ "$n" = "1" ] && ok "telefone gravado na conta $email (vínculo antigo com a inbox desfeito)" || falha "nenhuma conta com o e-mail $email"
}

# Conta de revisão das lojas (Apple e Google). CPF válido sorteado aqui (não é de
# ninguém do app), e-mail do nosso domínio e código fixo de 6 dígitos. Os dados
# só aparecem no less, para ir ao Bitwarden e às notas de revisão das lojas.
app_revisao() {
  local nova="${2:-}" v cpf codigo
  v=$(app_valor "$APP_EXT" REVIEW_ACCOUNTS)
  if [ -n "$v" ] && [ "$nova" != "--nova" ]; then
    ok "conta de revisão já existe (trocar: bash $0 app-revisao --nova)"
  else
    cpf=$(python3 - <<'PY'
import secrets
while True:
    d = [secrets.randbelow(10) for _ in range(9)]
    if len(set(d)) > 1:
        break
for n in (10, 11):
    s = sum(x * p for x, p in zip(d, range(n, 1, -1)))
    r = (s * 10) % 11
    d.append(0 if r == 10 else r)
print("".join(map(str, d)))
PY
)
    while :; do
      codigo=$(python3 -c 'import secrets; print(f"{secrets.randbelow(10**6):06d}")')
      case "$codigo" in 000000|123456|111111|222222|333333|444444|555555|666666|777777|888888|999999|654321) ;; *) break ;; esac
    done
    app_gravar REVIEW_ACCOUNTS "$cpf:revisao@$DOMINIO:Revisão das lojas:$codigo"
    cpf=""; codigo=""
    ok "conta de revisão gravada. Vale depois do próximo app-subir"
    v=$(app_valor "$APP_EXT" REVIEW_ACCOUNTS)
  fi
  [ -t 1 ] || { echo "rode num terminal para ver os dados"; return 0; }
  echo "$v" | awk -F: '{
    print "CONTA DE REVISÃO DAS LOJAS (Apple App Review e Google Play)";
    print "Guarde no Bitwarden e cole nas notas de revisão de cada loja. Não cole em chat.";
    print "";
    print "CPF:    " $1;
    print "E-mail: " $2;
    print "Código de acesso (sempre o mesmo, não chega por e-mail): " $4;
    print "";
    print "Texto para as notas de revisão:";
    print "  Login: open the app, enter CPF " $1 " and e-mail " $2 ", accept the terms,";
    print "  then type the 6-digit access code " $4 " (it is fixed for this review account;";
    print "  no e-mail is sent). Account deletion: menu > Excluir minha conta. The review";
    print "  account is recreated empty on the next login, so it can be tested repeatedly.";
    print "";
    print "Aperte q para fechar.";
  }' | less -K
  v=""
}

# Aponta o app para a nossa Crystal. Uso: bash bootstrap-vps.sh crystal-nossa sha-XXXXXXX
crystal_nossa() {
  local tag="${2:-}" api t=0
  [ -n "$tag" ] || tag=$(app_tag_atual)
  echo "$tag" | grep -Eq '^(sha-[0-9a-f]{7}|v[0-9][0-9A-Za-z.-]*)$' || falha "informe a tag: bash $0 crystal-nossa sha-XXXXXXX"
  [ -f "$APP_SEG" ] || falha "o app ainda não subiu: bash $0 app-subir $tag"
  if [ -z "$(app_valor "$APP_EXT" OPENROUTER_API_KEY)" ]; then
    echo "Chave do OpenRouter SÓ para a Crystal da VPS (crie uma nova em openrouter.ai > Keys, com limite de crédito)."
    local k; read -rsp "OPENROUTER_API_KEY (não aparece): " k; echo
    echo "$k" | grep -Eq '^sk-or-[A-Za-z0-9_-]{20,}$' || { k=""; falha "não parece uma chave do OpenRouter (sk-or-...)"; }
    app_gravar OPENROUTER_API_KEY "$k"; k=""
    ok "chave do OpenRouter gravada (só a Crystal recebe)"
  fi
  # Os segredos da Crystal têm que existir ANTES de gravar a chave do app: na
  # primeira vez eles nascem aqui (antes, a chave do app ficava vazia e dava 401).
  app_gerar_segredos "$tag"
  [ -n "$(app_valor "$APP_SEG" CRYSTAL_AGENTE_KEY)" ] || falha "CRYSTAL_AGENTE_KEY não foi gerada em $APP_SEG"
  echo "== app apontando para a nossa Crystal"
  app_gravar CRYSTAL_API_URL "http://app_crystal:8080"
  app_gravar CRYSTAL_API_PATH "/v1/messages"
  app_gravar CRYSTAL_API_AUTH_HEADER "authorization"
  app_gravar CRYSTAL_API_REPLY_FIELD "text"
  app_gravar CRYSTAL_API_KEY "$(app_valor "$APP_SEG" CRYSTAL_AGENTE_KEY)"
  app_subir app-subir "$tag"
  echo
  echo "== teste: a API do app pergunta à nossa Crystal"
  while :; do
    api=$(docker ps -q -f name=${APP_STACK}_app_api | head -1)
    [ -n "$api" ] && docker exec "$api" sh -c '[ "$CRYSTAL_API_URL" = "http://app_crystal:8080" ]' 2>/dev/null && break
    [ $t -ge 120 ] && break; sleep 5; t=$((t+5))
  done
  crystal_nossa_teste
}

crystal_nossa_teste() {
  local api; api=$(docker ps -q -f name=${APP_STACK}_app_api | head -1)
  [ -n "$api" ] || falha "API do app não está rodando"
  docker exec "$api" node -e '
    const u = process.env.CRYSTAL_API_URL + process.env.CRYSTAL_API_PATH;
    fetch(u, { method: "POST", headers: { authorization: "Bearer " + process.env.CRYSTAL_API_KEY, "content-type": "application/json" },
      body: JSON.stringify({ contact_id: null, conversation_id: "teste-bootstrap", message: { type: "text", text: "Oi, Crystal. Responda só: teste ok." } }) })
      .then(async r => { const t = await r.text(); console.log("  status", r.status, "->", t.slice(0, 160)); process.exit(r.ok ? 0 : 1); })
      .catch(e => { console.log("  falhou:", e.name); process.exit(1); });' \
    && ok "nossa Crystal respondendo. Teste no app: https://app.$DOMINIO" \
    || aviso "não respondeu. Ver: docker service logs --tail 60 ${APP_STACK}_app_crystal"
}

# Confere de ponta a ponta (10/10), sem gravar nada: o que o painel mandou (system_settings)
# chega à API, a API alcança a nossa Crystal, a Crystal alcança o OpenRouter com o modelo e a
# reserva do painel, a base de conhecimento entra no turno, o Supabase responde e, com o canal
# chatwoot, a pergunta que entra pela inbox volta respondida. Nenhum segredo na tela; nenhum
# dado de aluno (conversa de teste "teste-conferencia", sem memória).
crystal_conferir() {
  # Tudo com valor inicial: com set -u, `local x` sem valor quebra no primeiro "$x" (13/10: sem modelo no painel).
  local opcao="${2:-}" erros=0 svc="" r="" pg="" api="" linha="" modelo="" reserva="" imagem="" match="" memu="" canal="" re="" chave="" url="" code=""
  echo "== 1. serviços na VPS"
  for svc in ${APP_STACK}_app_api ${APP_STACK}_app_crystal ${APP_STACK}_app_web ${APP_STACK}_app_postgres ${APP_STACK}_app_redis \
           ${CW_STACK}_cw_rails ${CW_STACK}_cw_sidekiq; do
    r=$(docker service ls --filter "name=$svc" --format '{{.Name}} {{.Replicas}}' 2>/dev/null | awk -v n="$svc" '$1==n {print $2}' | head -1)
    if [ -n "$r" ] && [ "${r%%/*}" = "${r##*/}" ] && [ "${r%%/*}" != "0" ]; then ok "$svc $r"
    else aviso "$svc ${r:-não existe}"; erros=$((erros+1)); fi
  done

  echo "== 2. o que o painel mandou (Operação, valendo agora)"
  pg=$(docker ps -q -f name=${APP_STACK}_app_postgres | head -1)
  [ -n "$pg" ] || falha "Postgres do app não está rodando"
  while IFS='|' read -r chave linha; do
    [ -n "$chave" ] || continue
    case "$chave" in
      op_crystal_modelo) modelo=$linha ;;
      op_crystal_modelo_reserva) reserva=$linha ;;
      op_crystal_modelo_imagem) imagem=$linha ;;
      op_crystal_match_count) match=$linha ;;
      op_memoria_unica) memu=$linha ;;
    esac
    echo "  $chave = $linha"
  done < <(docker exec "$pg" psql -U crystal -d crystal_web_chat -tA -c \
    "select key, value from system_settings where key in ('op_crystal_modelo','op_crystal_modelo_reserva','op_crystal_modelo_imagem','op_crystal_match_count','op_memoria_unica','op_memoria_chegada','op_whatsapp_silencio','op_manutencao','crystal_history_messages') order by key" 2>/dev/null)
  [ -n "$modelo" ] || echo "  (sem modelo no painel: vale o padrão da imagem da Crystal)"
  # 23/10 (sha-088d07d): modelo separado que lê as imagens; vazio = a imagem vai ao modelo das respostas.
  [ -n "$imagem" ] || echo "  (op_crystal_modelo_imagem vazio: a imagem vai ao modelo das respostas, como antes)"
  # O valor sai do banco e vai para o teste: só no formato de modelo do OpenRouter.
  re='^~?[a-z0-9-]+/[a-z0-9.:-]+$'
  if [ -n "$modelo" ] && ! printf '%s' "$modelo" | grep -Eq "$re"; then aviso "modelo do painel fora do formato: $modelo"; modelo=""; erros=$((erros+1)); fi
  if [ -n "$reserva" ] && ! printf '%s' "$reserva" | grep -Eq "$re"; then aviso "reserva do painel fora do formato: $reserva"; reserva=""; erros=$((erros+1)); fi
  if [ -n "$imagem" ] && ! printf '%s' "$imagem" | grep -Eq "$re"; then aviso "modelo das imagens fora do formato: $imagem"; imagem=""; erros=$((erros+1)); fi
  printf '%s' "$match" | grep -Eq '^[0-9]{1,2}$' || match=""
  canal=$(app_valor "$APP_EXT" CHAT_TRANSPORT); canal=${canal:-crystal}
  echo "  canal do app (CHAT_TRANSPORT) = $canal"

  echo "== 3. API -> nossa Crystal -> OpenRouter (de dentro da API, como o app faz)"
  api=$(docker ps -q -f name=${APP_STACK}_app_api | head -1)
  [ -n "$api" ] || falha "API do app não está rodando"
  docker exec -e CONF_MODELO="$modelo" -e CONF_RESERVA="$reserva" -e CONF_MATCH="$match" "$api" node -e '
    const base = String(process.env.CRYSTAL_API_URL || "").replace(/\/$/, "");
    const rota = process.env.CRYSTAL_API_PATH || "/v1/messages";
    const auth = { authorization: "Bearer " + process.env.CRYSTAL_API_KEY };
    let falhas = 0;
    const ok = (m) => console.log("  ok " + m);
    const ruim = (m) => { console.log("  ! " + m); falhas++; };
    const pegar = async (u, o = {}) => {
      const r = await fetch(u, { ...o, signal: AbortSignal.timeout(o.prazo || 20000) });
      let j = null; try { j = await r.json(); } catch {}
      return { s: r.status, j };
    };
    (async () => {
      if (!base) { ruim("a API não tem CRYSTAL_API_URL: o app não fala com a nossa Crystal"); process.exit(1); }
      let hz;
      try { hz = await pegar(base + "/healthz"); } catch (e) { ruim("a API não alcança a Crystal (" + e.name + ")"); process.exit(1); }
      const h = hz.j || {};
      h.ok ? ok("API -> Crystal: no ar") : ruim("a Crystal respondeu HTTP " + hz.s);
      h.modelo_configurado ? ok("a Crystal tem a chave do OpenRouter") : ruim("a Crystal está SEM a chave do OpenRouter");
      h.prompt_rascunho ? ruim("prompt: é o RASCUNHO, não a alma da Crystal") : ok("prompt: a alma da Crystal (v2.2 da agência, adaptada)");
      h.conhecimento_busca ? ok("busca na base de conhecimento (Supabase) ligada") : ruim("busca na base de conhecimento DESLIGADA (faltam SUPABASE_URL/chave na Crystal)");
      h.memoria ? ok("memória das conversas (banco da Crystal) pronta") : ruim("memória das conversas sem banco");
      console.log("  padrão da imagem: modelo " + h.modelo + ", reserva " + h.modelo_reserva);
      const conta = await pegar(base + "/v1/uso/conta", { headers: auth }).catch((e) => ({ s: 0, j: null }));
      if (conta.s === 200 && conta.j && conta.j.conta) ok("Crystal -> OpenRouter: chave aceita; saldo US$ " + Number(conta.j.conta.saldo).toFixed(2) + (conta.j.chave && conta.j.chave.limite != null ? ", limite da chave US$ " + conta.j.chave.limite : ""));
      else ruim("o OpenRouter não confirmou a chave (HTTP " + conta.s + ")");
      const modelo = process.env.CONF_MODELO || h.modelo;
      const reserva = process.env.CONF_RESERVA || h.modelo_reserva;
      const lista = await pegar("https://openrouter.ai/api/v1/models").then((r) => (r.j && r.j.data) || []).catch(() => []);
      lista.length ? ok("lista do OpenRouter lida: " + lista.length + " modelos") : ruim("não deu para ler a lista de modelos do OpenRouter");
      const doCatalogo = (id) => lista.find((x) => x.id === id);
      for (const [nome, id] of [["modelo", modelo], ["reserva", reserva]]) {
        if (!id) continue;
        const x = doCatalogo(id);
        if (!x) { if (lista.length) ruim(nome + " " + id + " NÃO existe no OpenRouter"); continue; }
        const img = (x.architecture && x.architecture.input_modalities || []).includes("image");
        ok(nome + " " + id + " existe no OpenRouter" + (img ? " e lê imagens" : "") );
        if (!img) ruim(nome + " " + id + " não lê imagens: o print que o aluno manda falharia");
      }
      // Igual, o nome canônico do catálogo, ou o mesmo com sufixo de DATA (gpt-4.1 não é gpt-4.1-mini);
      // apelido ~fornecedor/...-latest vale para o mais novo do fornecedor.
      const mesmo = (pedido, veio) => {
        if (!veio) return false;
        if (veio === pedido || (doCatalogo(pedido) || {}).canonical_slug === veio) return true;
        if (pedido.startsWith("~")) return veio.split("/")[0] === pedido.slice(1).split("/")[0];
        const base = pedido.replace(/:[a-z0-9-]+$/, "");
        return veio.startsWith(base + "-") && /^-(\d{8}|\d{4}-\d{2}-\d{2})$/.test(veio.slice(base.length));
      };
      const turno = async (rotulo, texto, extra) => {
        const t0 = Date.now();
        try {
          const r = await pegar(base + rota, { method: "POST", prazo: 75000,
            headers: { ...auth, "content-type": "application/json", accept: "application/json" },
            body: JSON.stringify({ contact_id: null, conversation_id: "teste-conferencia", history_messages: 0, message: { type: "text", text: texto }, ...extra }) });
          if (r.s !== 200) { ruim(rotulo + ": a Crystal respondeu HTTP " + r.s + " (" + ((r.j && r.j.error && r.j.error.code) || "?") + ")"); return null; }
          const u = r.j.uso || {};
          console.log("  " + rotulo + ": respondeu " + (u.modelo || "?") + " em " + (Date.now() - t0) + " ms, " + (u.tokens_entrada ?? "?") + "+" + (u.tokens_saida ?? "?") + " tokens, US$ " + (u.custo_usd ?? "?"));
          console.log("    \"" + String(r.j.text || "").replace(/\s+/g, " ").slice(0, 150) + "\"");
          return u.modelo || null;
        } catch (e) { ruim(rotulo + ": sem resposta (" + e.name + ")"); return null; }
      };
      // Turno 1: exatamente como o aluno, com o modelo, a reserva e os trechos do painel.
      const extra1 = { modelo };
      if (reserva) extra1.modelo_reserva = reserva;
      if (process.env.CONF_MATCH) extra1.match_count = Number(process.env.CONF_MATCH);
      const veio = await turno("pergunta como aluno", "Oi, Crystal! Como eu faço para acessar as aulas gravadas?", extra1);
      if (veio) {
        if (mesmo(modelo, veio)) ok("quem respondeu foi o modelo do painel (" + modelo + ")");
        else if (reserva && mesmo(reserva, veio)) ruim("quem respondeu foi a RESERVA: o modelo do painel (" + modelo + ") falhou");
        else ruim("respondeu " + veio + ", que não é o modelo do painel (" + modelo + ")");
      }
      // Turno 2: a reserva sozinha (reserva = ela mesma: sem segunda opção), para saber que ela salva o dia.
      if (reserva && reserva !== modelo) {
        const r2 = await turno("reserva sozinha", "Responda só: teste ok.", { modelo: reserva, modelo_reserva: reserva });
        if (r2) mesmo(reserva, r2) ? ok("a reserva responde sozinha") : ruim("a reserva respondeu como " + r2);
      }
      process.exit(falhas ? 1 : 0);
    })();' || erros=$((erros+1))

  # Quantos trechos da base de conhecimento entraram no turno de teste (log da Crystal: só números).
  sleep 2
  linha=$(docker service logs --since 3m --raw ${APP_STACK}_app_crystal 2>/dev/null | grep '"modelo: uso do turno"' | grep -o '"trechos":[0-9]*' | tail -2 | head -1 | cut -d: -f2)
  if [ -n "$linha" ] && [ "$linha" -gt 0 ] 2>/dev/null; then ok "base de conhecimento entrou no turno: $linha trecho(s)"
  elif [ -n "$linha" ]; then aviso "o turno saiu SEM trechos da base de conhecimento (0)"; erros=$((erros+1))
  else aviso "não achei no log da Crystal a linha de uso do turno (log em outro formato?)"; fi

  echo "== 4. Supabase"
  app_supabase_teste || erros=$((erros+1))
  url=$(app_valor "$APP_EXT" SUPABASE_URL); chave=$(app_valor "$APP_EXT" SUPABASE_SERVICE_ROLE_KEY)
  if [ -n "$url" ] && [ -n "$chave" ]; then
    code=$(printf 'header = "apikey: %s"\nheader = "Authorization: Bearer %s"\n' "$chave" "$chave" \
      | curl -s -o /dev/null -m 20 -w '%{http_code}' -K - -X POST "$url/rest/v1/rpc/app_memoria_ler" \
          -H 'content-type: application/json' -d '{"p_customer_id":"00000000-0000-0000-0000-000000000000"}') || code=000
    chave=""
    if [ "$code" = "200" ]; then ok "memória única: a função app_memoria_ler responde (chave op_memoria_unica = ${memu:-off})"
    else aviso "memória única: app_memoria_ler respondeu HTTP $code"; [ "$memu" = "on" ] && erros=$((erros+1)); fi
  fi

  echo "== 5. caminho do aluno pelo app"
  if [ "$canal" = "chatwoot" ] && [ "$opcao" != "--sem-chatwoot" ]; then
    echo "  (pergunta pela inbox do Chatwoot: app -> Chatwoot -> API -> Crystal -> OpenRouter -> Chatwoot)"
    atendimento_teste || erros=$((erros+1))
  elif [ "$canal" = "chatwoot" ]; then
    echo "  pulado (--sem-chatwoot)"
  else
    ok "canal direto: a pergunta do item 3 é o caminho do aluno"
  fi

  echo
  if [ "$erros" -eq 0 ]; then
    ok "TUDO LIGADO: painel -> API -> Crystal -> OpenRouter, base de conhecimento, Supabase e o caminho do aluno responderam"
  else
    aviso "$erros ponto(s) com problema, marcados com ! acima"
    return 1
  fi
}

# Piloto das fichas do WhatsApp (10/10): compara a resposta da Crystal sem memória, só com
# as anotações da Crystal do WhatsApp e com a ficha, para as últimas N fichas prontas. Roda
# de dentro do contêiner da API (as chaves não saem dele). O texto das conversas vai SÓ para
# um arquivo 600 em $BASE; na tela, só contagens. Ler com less e apagar depois.
fichas_ensaio() {
  local n="${1:-20}" api arq
  printf '%s' "$n" | grep -Eq '^[0-9]{1,3}$' && [ "$n" -ge 1 ] && [ "$n" -le 100 ] || falha "uso: fichas-ensaio [N] (1 a 100, padrão 20)"
  api=$(docker ps -q -f name=${APP_STACK}_app_api | head -1)
  [ -n "$api" ] || falha "API do app não está rodando"
  arq="$BASE/fichas-ensaio-$(date +%Y%m%d-%H%M).md"
  ( umask 077; : > "$arq" )
  echo "== ensaio de $n fichas (cada uma: 3 respostas da Crystal, uns US\$ 0,003)"
  docker exec -e N="$n" "$api" node -e '
    const sb = process.env.SUPABASE_URL.replace(/\/+$/, "");
    const k = process.env.SUPABASE_SERVICE_ROLE_KEY;
    const cr = process.env.CRYSTAL_API_URL.replace(/\/+$/, "");
    const ck = process.env.CRYSTAL_API_KEY;
    const MSG = "Oi Crystal! Lembra de mim? Tô precisando de ajuda de novo.";
    const rpc = async (nome, corpo) => {
      const r = await fetch(sb + "/rest/v1/rpc/" + nome, { method: "POST", headers: { apikey: k, authorization: "Bearer " + k, "content-type": "application/json" }, body: JSON.stringify(corpo), signal: AbortSignal.timeout(20000) });
      if (!r.ok) throw new Error("Supabase " + nome + " HTTP " + r.status);
      return r.json();
    };
    (async () => {
      const ids = (await rpc("app_ficha_amostra", { p_qtd: Number(process.env.N) })).map((x) => x.customer_id);
      const linhas = ["# Ensaio das fichas do WhatsApp", "", "Mensagem do aluno em todos: \"" + MSG + "\"", ""];
      let ok = 0, falhas = 0;
      for (const [i, id] of ids.entries()) {
        const r = await fetch(cr + "/v1/fichas/ensaio", { method: "POST", headers: { authorization: "Bearer " + ck, "content-type": "application/json" }, body: JSON.stringify({ pessoa_id: id, mensagem: MSG }), signal: AbortSignal.timeout(120000) }).catch(() => null);
        if (!r || !r.ok) { falhas++; linhas.push("## Aluno " + (i + 1), "", "(o ensaio falhou: " + (r ? "HTTP " + r.status : "rede") + ")", ""); continue; }
        const d = await r.json(); ok++;
        linhas.push("## Aluno " + (i + 1), "", "### Ficha", "", d.ficha || "(sem ficha)", "",
          "### Resposta SEM memória do WhatsApp", "", d.sem?.texto || "", "",
          "### Resposta só com as ANOTAÇÕES (como era até 10/10)", "", d.anotacoes?.texto || "(o aluno não tinha anotações)", "",
          "### Resposta COM a ficha", "", d.com_ficha?.texto || "", "", "---", "");
      }
      process.stdout.write(linhas.join("\n"));
      process.stderr.write("  " + ids.length + " fichas na amostra; " + ok + " ensaios ok; " + falhas + " falhas\n");
    })().catch((e) => { process.stderr.write("  falhou: " + e.message + "\n"); process.exit(1); });' >> "$arq" \
    || { rm -f "$arq"; falha "o ensaio não rodou (imagem antiga, sem ficha ainda ou Supabase sem app_ficha_amostra)"; }
  ok "comparativo em $arq (só root lê). Ler: less $arq  ·  depois: rm $arq"
}

# ------------------------------------------------------------------ vigia do app
# A cada 5 minutos (cron), confere o app e avisa no Telegram (grupo Crystal ·
# Alertas). Só manda de novo o mesmo problema depois de 1 hora e avisa quando
# normaliza. O token do bot fica em $VIGIA_CONF (600), nunca na tela nem no log.
VIGIA_CONF="$BASE/.vigia"
VIGIA_ESTADO="$BASE/.vigia-estado"
VIGIA_LOG="$BASE/vigia.log"

# ---------------------------------------------------------------------------
# Painel novo da equipe (onda 4, 12/10): a migração pa13_01 numera a auditoria e o
# audit:backfill calcula a cadeia de hash das linhas antigas. A ORDEM é obrigatória:
# API parada -> migração + backfill (imagem nova, serviço temporário) -> app-subir.
# Se a API nova gravar uma linha antes do backfill, a cadeia nasce quebrada e o
# backfill não conserta (ensaiado em 12/10: crystal-em-casa/painel-novo/README.md).
app_api_parar() { # app_api_parar --confirmo
  [ "${2:-}" = "--confirmo" ] || falha "isto tira a API do ar: o app para de responder aos alunos até o próximo app-subir. Se é isso mesmo (janela 02:00-05:00): bash $0 app-api-parar --confirmo"
  docker service inspect "${APP_STACK}_app_api" >/dev/null 2>&1 || falha "o serviço ${APP_STACK}_app_api não existe"
  echo "== parando a API (0 réplicas). web e Chatwoot continuam; só o app fica sem resposta"
  docker service scale "${APP_STACK}_app_api=0" --detach=false >/dev/null || falha "não parou a API"
  local t=0 n
  while :; do
    n=$(docker ps -q --filter "label=com.docker.swarm.service.name=${APP_STACK}_app_api" | wc -l)
    [ "$n" -eq 0 ] && break
    [ "$t" -lt 120 ] || falha "a API ainda tem contêiner rodando depois de 2 min: docker service ps ${APP_STACK}_app_api"
    sleep 3; t=$((t+3))
  done
  ok "API parada (nenhuma tarefa rodando)"
  echo "  Próximo: bash $0 app-auditoria-backfill TAG   e depois   bash $0 app-subir TAG (volta a 1 réplica)"
  echo "  Desistiu? bash $0 app-subir $(app_tag_atual) sobe a versão de hoje de novo"
}

# Migração + backfill da auditoria com a IMAGEM NOVA, num serviço temporário do Swarm na
# rede interna do app (a rede não é "attachable": docker run não entra nela). Trava em
# arquivo (flock) para não rodar duas vezes ao mesmo tempo; o próprio backfill ainda usa um
# pg_advisory_xact_lock. Só contagens na tela: nenhum conteúdo da trilha.
app_auditoria_backfill() { # app_auditoria_backfill TAG
  local tag="${2:-}" svc="${APP_STACK}_backfill" estado="" t=0 saida rodando
  echo "$tag" | grep -Eq '^(sha-[0-9a-f]{7}|v[0-9][0-9A-Za-z.-]*)$' \
    || falha "informe a tag da imagem NOVA: bash $0 app-auditoria-backfill sha-XXXXXXX"
  [ -f "$APP_DIR/api.env" ] || falha "não existe $APP_DIR/api.env (o app nunca subiu aqui?)"
  command -v flock >/dev/null || falha "flock não está instalado (apt-get install util-linux)"
  mkdir -p "$APP_DIR"; chmod 700 "$APP_DIR"
  exec 9>"$APP_DIR/.auditoria-backfill.lock"
  flock -n 9 || falha "já tem um app-auditoria-backfill rodando (trava $APP_DIR/.auditoria-backfill.lock). Espere ele acabar"
  rodando=$(docker service ps "${APP_STACK}_app_api" --filter desired-state=running -q 2>/dev/null | wc -l)
  [ "$rodando" -eq 0 ] || falha "a API ainda está no ar ($rodando tarefa). O backfill só vale com a API parada: bash $0 app-api-parar --confirmo"
  docker network inspect "${APP_STACK}_app_interno" >/dev/null 2>&1 || falha "rede ${APP_STACK}_app_interno não existe (a stack do app nunca subiu?)"
  docker pull -q "$APP_IMG-api:$tag" >/dev/null || falha "não baixou $APP_IMG-api:$tag. Rodou 'bash $0 app-ghcr'? A imagem saiu no GitHub (imagens-vps)?"
  docker service rm "$svc" >/dev/null 2>&1 || true
  echo "== migração + backfill da auditoria com $tag (serviço temporário $svc, some no fim)"
  # shellcheck disable=SC2016
  docker service create --quiet --detach --name "$svc" --with-registry-auth --restart-condition none \
    --network "${APP_STACK}_app_interno" --env-file "$APP_DIR/api.env" \
    --constraint node.role==manager --limit-memory 1024M --limit-cpu 1 -w /app \
    "$APP_IMG-api:$tag" sh -c 'pnpm --filter @crystal/api db:migrate:deploy && pnpm --filter @crystal/api audit:backfill' >/dev/null \
    || falha "não criou o serviço temporário $svc"
  while :; do
    estado=$(docker service ps "$svc" --format '{{.CurrentState}}' 2>/dev/null | head -1)
    case "$estado" in Complete*|Failed*|Rejected*|Shutdown*) break ;; esac
    if [ "$t" -ge 900 ]; then aviso "15 min e o backfill não terminou (trilha enorme?). Log parcial abaixo; o serviço continua"; break; fi
    sleep 5; t=$((t+5))
  done
  saida=$(docker service logs --raw "$svc" 2>&1 | grep -vE 'Lifecycle|postinstall|prisma generate|^\s*$' || true)
  printf '%s\n' "$saida" | tail -25 | redigir | sed 's/^/     /'
  case "$estado" in
    Complete*) docker service rm "$svc" >/dev/null 2>&1 || true ;;
    *) falha "a migração ou o backfill NÃO terminou bem ($estado). A API continua parada e o banco como estava antes do passo que falhou. Mande o log acima para a sessão; para voltar ao ar: bash $0 app-subir $(app_tag_atual)" ;;
  esac
  printf '%s' "$saida" | grep -q '"ok":true' || falha "o backfill terminou sem confirmar a cadeia ('ok':true não apareceu). Não subir a API nova: mande o log acima para a sessão"
  ok "migrações aplicadas e cadeia da auditoria fechada ($(printf '%s' "$saida" | grep -o '"conferidas":[0-9]*' | tail -1 | cut -d: -f2) linhas conferidas), em ${t}s"
  echo "  Próximo: bash $0 app-subir $tag"
}

# Painel intermitente (13/10), só leitura: reinícios (Exit 137 = memória estourou), memória agora,
# chamadas da API lentas (> 5 s) ou com erro nas últimas HORAS (só método, caminho sem query, status
# e tempo: nada de corpo, cookie, IP ou e-mail), erros do log por tipo e o volume que o painel lê.
painel_diagnostico() {
  local horas="${2:-6}" svc="" api="" pg=""
  printf '%s' "$horas" | grep -Eq '^[0-9]{1,3}$' || falha "uso: bash $0 painel-diagnostico [HORAS]  (padrão 6)"
  echo "== 1. reinícios (Exit 137 ou OOM = memória estourou; 'Shutdown' de uma publicação é normal)"
  for svc in ${APP_STACK}_app_api ${APP_STACK}_app_web ${APP_STACK}_app_crystal ${APP_STACK}_app_postgres; do
    docker service ps "$svc" --no-trunc --format '{{.Name}}|{{.Image}}|{{.CurrentState}}|{{.Error}}' 2>/dev/null \
      | head -5 | awk -F'|' '{ sub(/.*:/, "", $2); printf "  %s %s %s %s\n", $1, $2, $3, $4 }' || true
  done
  echo "== 2. memória e CPU agora"
  docker stats --no-stream --format '{{.Name}}|{{.MemUsage}}|{{.CPUPerc}}' 2>/dev/null | grep -E "^(${APP_STACK}|${CW_STACK})_" \
    | awk -F'|' '{ sub(/\.[0-9]+\.[a-z0-9]+$/, "", $1); printf "  %-34s %s  CPU %s\n", $1, $2, $3 }' || true
  free -h | sed 's/^/  /'
  dmesg 2>/dev/null | grep -iE 'out of memory|oom-kill' | tail -5 | sed 's/^/  /' || true
  api=$(docker ps -q -f name=${APP_STACK}_app_api | head -1)
  [ -n "$api" ] || falha "API do app não está rodando"
  echo "== 3. API nas últimas ${horas}h: chamadas lentas ou com erro, por rota"
  docker service logs --since "${horas}h" --raw ${APP_STACK}_app_api 2>/dev/null | docker exec -i "$api" node -e '
    const rl = require("readline").createInterface({ input: process.stdin });
    const urls = new Map(), grupos = new Map(), erros = new Map(); let total = 0;
    const caminho = (u) => String(u || "?").split("?")[0].replace(/\/[0-9a-f-]{16,}|\/c[a-z0-9]{20,}/gi, "/:id").replace(/\/\d+(?=\/|$)/g, "/:n").slice(0, 70);
    rl.on("line", (l) => {
      let j; try { j = JSON.parse(l); } catch { return; }
      if (j.req && j.reqId !== undefined) { urls.set(j.reqId, (j.req.method || "?") + " " + caminho(j.req.url)); return; }
      if (j.res && j.reqId !== undefined && typeof j.responseTime === "number") {
        total++;
        const k = urls.get(j.reqId) || "? (início fora da janela)"; urls.delete(j.reqId);
        const g = grupos.get(k) || { n: 0, lentas: 0, s: {}, max: 0 };
        g.n++; g.max = Math.max(g.max, j.responseTime); if (j.responseTime > 5000) g.lentas++;
        const st = j.res.statusCode; if (st >= 500 || st === 429 || st === 408 || st === 503) g.s[st] = (g.s[st] || 0) + 1;
        grupos.set(k, g); return;
      }
      if (j.level >= 50) {
        const e = j.err || {};
        const k = String(e.code || e.type || "erro") + ": " + String(e.message || j.msg || "").replace(/\s+/g, " ").replace(/[\w.+-]+@[\w-]+\.[\w.]+/g, "<email>").slice(0, 90);
        erros.set(k, (erros.get(k) || 0) + 1);
      }
    });
    rl.on("close", () => {
      console.log("  " + total + " chamadas terminadas no período");
      const ruins = [...grupos].filter(([, g]) => g.lentas || Object.keys(g.s).length)
        .sort((a, b) => (b[1].lentas + Object.values(b[1].s).reduce((x, y) => x + y, 0)) - (a[1].lentas + Object.values(a[1].s).reduce((x, y) => x + y, 0)));
      if (!ruins.length) console.log("  nenhuma chamada lenta ou com erro");
      for (const [k, g] of ruins.slice(0, 20)) console.log("  ! " + k + ": " + g.n + " chamadas, " + g.lentas + " lentas, erros " + JSON.stringify(g.s) + ", pior " + Math.round(g.max) + " ms");
      console.log("  -- área da equipe (/staff), pior tempo:");
      for (const [k, g] of [...grupos].filter(([k]) => k.includes("/staff/")).sort((a, b) => b[1].max - a[1].max).slice(0, 15))
        console.log("  " + k + ": " + g.n + " chamadas, pior " + Math.round(g.max) + " ms");
      console.log("  -- erros no log, por tipo:");
      if (!erros.size) console.log("  nenhum");
      for (const [k, n] of [...erros].sort((a, b) => b[1] - a[1]).slice(0, 12)) console.log("  " + n + "x " + k);
    });' || aviso "não consegui ler o log da API"
  echo "== 4. o que o painel lê do banco do app (mensagens por período e tempo da leitura)"
  pg=$(docker ps -q -f name=${APP_STACK}_app_postgres | head -1)
  [ -n "$pg" ] || falha "Postgres do app não está rodando"
  docker exec "$pg" psql -U crystal -d crystal_web_chat -tA -F ' | ' -c "
    select 'mensagens 1 dia', count(*), coalesce(pg_size_pretty(sum(length(content))::bigint), '0') from messages where created_at >= now() - interval '1 day'
    union all select 'mensagens 7 dias', count(*), coalesce(pg_size_pretty(sum(length(content))::bigint), '0') from messages where created_at >= now() - interval '7 days'
    union all select 'mensagens 60 dias', count(*), coalesce(pg_size_pretty(sum(length(content))::bigint), '0') from messages where created_at >= now() - interval '60 days'
    union all select 'mensagens total', count(*), pg_size_pretty(pg_total_relation_size('messages')) from messages
    union all select 'conexões abertas no Postgres', count(*), '' from pg_stat_activity where datname = 'crystal_web_chat'" 2>&1 | sed 's/^/  /' || aviso "não li o volume de mensagens"
  docker exec "$pg" psql -U crystal -d crystal_web_chat -tA -c "select indexdef from pg_indexes where tablename = 'messages'" 2>&1 | sed 's/^/  índice: /' || true
  docker exec "$pg" psql -U crystal -d crystal_web_chat -tA -c "explain (analyze, format text) select m.direction, m.content_type, m.created_at, m.content, c.user_id from messages m join conversations c on c.id = m.conversation_id where m.created_at >= now() - interval '14 days'" 2>&1 \
    | grep -E 'Seq Scan|Index|Execution Time|Planning Time' | head -6 | sed 's/^/  /' || true
  echo "== 5. web (Next.js) nas últimas ${horas}h"
  docker service logs --since "${horas}h" --raw ${APP_STACK}_app_web 2>/dev/null | grep -ciE 'error|timeout|ECONNRESET|ECONNREFUSED' | sed 's/^/  linhas com erro: /' || true
  docker service logs --since "${horas}h" --raw ${APP_STACK}_app_web 2>/dev/null | grep -iE 'error|timeout|ECONNRESET|ECONNREFUSED' \
    | sed -E 's/[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+\.[A-Za-z.]+/<email>/g' | redigir | cut -c1-110 | sort | uniq -c | sort -rn | head -6 | sed 's/^/  /' || true
  echo "Cole tudo acima na sessão (não tem segredo nem dado de aluno)."
}

# Conferência depois de publicar o painel novo, sem mudar nada: migrações limpas de dentro
# da API, cadeia de hash conferida pelo código do próprio app, rotas e telas novas no ar.
app_painel_conferir() {
  local erros=0 api pg saida n sem code u esperado metodo destino="" corpo=""
  echo "== 1. serviços e tag"
  echo "  API em $(app_tag_atual)"
  app_status
  api=$(docker ps -q -f name="${APP_STACK}_app_api" | head -1)
  [ -n "$api" ] || falha "a API do app não está rodando: bash $0 app-subir TAG"
  pg=$(docker ps -q -f name="${APP_STACK}_app_postgres" | head -1)
  [ -n "$pg" ] || falha "Postgres do app não está rodando"

  echo "== 2. migrações do Prisma (vistas de dentro da API que está no ar)"
  saida=$(docker exec -w /app/apps/api "$api" ./node_modules/.bin/prisma migrate status 2>&1 || true)
  if printf '%s' "$saida" | grep -q 'Database schema is up to date'; then ok "migrate status: tudo aplicado, nada pendente"
  else aviso "migrate status não está limpo:"; printf '%s\n' "$saida" | tail -8 | sed 's/^/     /'; erros=$((erros+1)); fi
  if printf '%s' "$saida" | grep -q 'not found locally'; then
    aviso "há migração no banco que esta imagem não conhece (imagem antiga com banco novo?): $(printf '%s' "$saida" | sed -n '/not found locally/,$p' | tail -n +2 | tr '\n' ' ')"; erros=$((erros+1)); fi
  n=$(docker exec "$pg" psql -U crystal -d crystal_web_chat -tAc "select count(*) from _prisma_migrations where migration_name like 'pa%' and finished_at is not null" 2>/dev/null | tr -d '[:space:]')
  if [ "${n:-0}" -ge 9 ] 2>/dev/null; then ok "$n migrações pa* do painel novo aplicadas"
  else aviso "só ${n:-0} migrações pa* aplicadas (o painel novo tem 9)"; erros=$((erros+1)); fi
  n=$(docker exec "$pg" psql -U crystal -d crystal_web_chat -tAc "select to_regclass('public.scheduled_notices') is null" 2>/dev/null | tr -d '[:space:]')
  case "$n" in
    t) echo "  scheduled_notices (avisos programados de 10/10): apagada pela migração da onda 4" ;;
    f) echo "  scheduled_notices (avisos programados de 10/10): ainda existe nesta imagem" ;;
  esac

  echo "== 3. cadeia de hash da auditoria"
  read -r n sem <<<"$(docker exec "$pg" psql -U crystal -d crystal_web_chat -tAc "select count(*) || ' ' || count(*) filter (where hash is null) from audit_log" 2>/dev/null | tr -d '\r')"
  if [ -z "${n:-}" ]; then aviso "não li a tabela audit_log (coluna hash não existe? a migração pa13_01 não entrou)"; erros=$((erros+1))
  elif [ "${sem:-1}" -eq 0 ]; then ok "$n linhas na auditoria, todas com hash"
  else aviso "$sem de $n linhas SEM hash: o backfill não rodou ou a API nova gravou antes dele"; erros=$((erros+1)); fi
  app_api_ts_gravar "$api" .painel-conferir.ts <<'TS' || aviso "não gravou o script de conferência na API"
import { PrismaClient } from "@prisma/client";
import { createPrismaRepos } from "./src/db/prisma";
import { verificarCadeia } from "./src/services/audit-chain";
const prisma = new PrismaClient();
const repos = createPrismaRepos(prisma);
const v = await verificarCadeia(repos.audit, repos.settings);
console.log(JSON.stringify({ cadeia_ok: v.ok, conferidas: v.checked, quebra: v.broken ? { seq: v.broken.seq, motivo: v.broken.reason } : null }));
await prisma.$disconnect();
if (!v.ok) process.exit(1);
TS
  if saida=$(docker exec -w /app/apps/api "$api" ./node_modules/.bin/tsx .painel-conferir.ts 2>&1); then
    ok "conferência do app: $saida"
  else aviso "a conferência do app apontou problema: $(printf '%s' "$saida" | tail -3 | tr '\n' ' ')"; erros=$((erros+1)); fi
  app_api_ts_apagar "$api" .painel-conferir.ts

  echo "== 4. rotas e telas novas (sem sessão: só confere que existem; o conteúdo é no navegador)"
  # URL, método, código esperado. /me/notices sem sessão responde 401 (na imagem antiga, 404).
  # As telas da equipe respondem 200 e as antigas redirecionam (307) para o lugar novo.
  for u in \
    "https://api.$DOMINIO/healthz GET 200" \
    "https://api.$DOMINIO/me/notices/conferencia/opened POST 401" \
    "https://app.$DOMINIO/equipe/alunos GET 200" \
    "https://app.$DOMINIO/equipe/mensagens GET 200" \
    "https://app.$DOMINIO/equipe/metricas GET 200" \
    "https://app.$DOMINIO/equipe/auditoria GET 200" \
    "https://app.$DOMINIO/equipe/configuracoes GET 200" \
    "https://app.$DOMINIO/equipe/crystal GET 200" \
    "https://app.$DOMINIO/equipe/operacao GET 307 /equipe/alunos?aba=lotes" \
    "https://app.$DOMINIO/equipe/avisos GET 307 /equipe/mensagens" \
    "https://app.$DOMINIO/equipe/painel GET 307 /equipe/metricas"; do
    read -r u metodo esperado destino <<<"$u"
    if [ -n "${destino:-}" ]; then
      # Tela antiga: o layout da equipe é de cliente, então o Next manda 200 com NEXT_REDIRECT no corpo
      # (o navegador vai para o destino) em vez do 307 de cabeçalho. Os dois valem (14/10).
      corpo=$(curl -s -m 20 -w '\n%{http_code}' "$u" 2>/dev/null) || true
      code=${corpo##*$'\n'}
      if [ "$code" = "$esperado" ] || { [ "$code" = "200" ] && printf '%s' "$corpo" | grep -qF "NEXT_REDIRECT;replace;$destino;"; }; then
        ok "$metodo $u -> $code (vai para $destino)"
      else aviso "$metodo $u -> ${code:-000} (esperava ir para $destino)"; erros=$((erros+1)); fi
      continue
    fi
    code=$(curl -s -o /dev/null -m 20 -X "$metodo" -w '%{http_code}' "$u" 2>/dev/null) || true
    if [ "${code:-000}" = "$esperado" ]; then ok "$metodo $u -> $code"
    else aviso "$metodo $u -> ${code:-000} (esperava $esperado)"; erros=$((erros+1)); fi
  done

  echo
  if [ "$erros" -eq 0 ]; then ok "PAINEL NOVO NO AR: migrações limpas, cadeia da auditoria íntegra, telas e rotas novas respondendo"
  else aviso "$erros ponto(s) com problema, marcados com ! acima. Volta: ver crystal-em-casa/publicar-prd.md, onda 4 (app-subir da versão anterior)"; return 1; fi
}

vigia_telegram() { # vigia_telegram TEXTO -> 0 se o Telegram aceitou
  local token chat
  token=$(app_valor "$VIGIA_CONF" TOKEN); chat=$(app_valor "$VIGIA_CONF" CHAT)
  [ -n "$token" ] && [ -n "$chat" ] || return 1
  # URL com o token pela entrada padrão (-K -): fora da linha de comando e do ps.
  printf 'url = "https://api.telegram.org/bot%s/sendMessage"\n' "$token" \
    | curl -s -m 20 -K - --data-urlencode "chat_id=$chat" --data-urlencode "text=$1" \
    | grep -q '"ok":true'
}

vigia_config() {
  local token chat limite
  read -rsp "Token do bot do Telegram (Bitwarden, não aparece): " token; echo
  printf '%s' "$token" | grep -Eq '^[0-9]{6,12}:[A-Za-z0-9_-]{30,}$' || falha "token em formato inesperado (123456789:AA...). Nada gravado"
  read -rp "ID do grupo [-1003662546162]: " chat; chat=${chat:--1003662546162}
  printf '%s' "$chat" | grep -Eq '^-?[0-9]{5,20}$' || falha "ID do grupo inválido"
  read -rp "Avisar quando o crédito do OpenRouter ficar abaixo de US$ [5]: " limite; limite=${limite:-5}
  printf '%s' "$limite" | grep -Eq '^[0-9]+$' || falha "limite: só número inteiro"
  mkdir -p "$BASE"; chmod 700 "$BASE"; umask 077
  printf 'TOKEN=%s\nCHAT=%s\nLIMITE=%s\n' "$token" "$chat" "$limite" > "$VIGIA_CONF"; chmod 600 "$VIGIA_CONF"
  token=""
  vigia_telegram "✅ Vigia do app da Crystal ligada na VPS. Confere a cada 5 minutos e avisa aqui se algo cair." \
    || { rm -f "$VIGIA_CONF"; falha "o Telegram recusou (token, ID do grupo ou o bot fora do grupo). Nada gravado"; }
  ok "mensagem de teste enviada ao grupo"
  copia_cron_atualizar --criar
  printf '%s\n' "*/5 * * * * root PATH=/usr/sbin:/usr/bin:/sbin:/bin /usr/bin/bash $BASE/bootstrap-vps.sh vigia >> $VIGIA_LOG 2>&1" \
    > /etc/cron.d/crystal-vigia
  chmod 644 /etc/cron.d/crystal-vigia
  ok "vigia agendada (/etc/cron.d/crystal-vigia, a cada 5 min). Log: $VIGIA_LOG"
}

vigia() {
  [ -s "$VIGIA_CONF" ] || { echo "vigia sem configuração: bash $0 vigia-config"; return 0; }
  local problemas=() u code linha falhas resumo agora anterior quando cid saldo limite r
  agora=$(date +%s)
  for u in "https://app.$DOMINIO/login" "https://api.$DOMINIO/healthz"; do
    code=$(curl -s -o /dev/null -m 20 -w '%{http_code}' "$u" || true)
    [ "$code" = "200" ] || problemas+=("$u respondeu ${code:-sem resposta}")
  done
  while read -r linha; do
    set -- $linha
    [ "${2%%/*}" = "${2##*/}" ] || problemas+=("serviço $1 com $2 réplicas")
  done < <(docker service ls --filter "name=${APP_STACK}_" --filter "name=${CW_STACK}_" --format '{{.Name}} {{.Replicas}}' 2>/dev/null)
  # O nosso Chatwoot, se estiver no ar.
  if docker service inspect "${CW_STACK}_cw_rails" >/dev/null 2>&1; then
    code=$(curl -s -o /dev/null -m 20 -w '%{http_code}' "https://$CW_HOST/api" || true)
    [ "$code" = "200" ] || problemas+=("https://$CW_HOST/api respondeu ${code:-sem resposta}")
  fi
  # Backup (achados 22 a 25): o último completo, falha registrada pelo backup e a
  # cópia no R2, todos com 26 h de folga; e o disco do Docker.
  local h uso
  if [ -f /etc/cron.d/crystal-backup-n8n ]; then
    h=$(horas_desde "$BACKUPS/.backup-ultimo")
    if [ "$h" = nunca ] || [ "$h" -ge 26 ]; then problemas+=("último backup completo na VPS: há ${h} h (ver $BACKUPS/backup.log)"); fi
    [ -s "$BACKUPS/.backup-falhas" ] && problemas+=("último backup com falha: $(paste -sd';' "$BACKUPS/.backup-falhas" | cut -c1-200)")
  fi
  if [ -s "$FORA_CONF" ] || [ -s "$BACKUPS/.fora-ultimo" ]; then
    h=$(horas_desde "$BACKUPS/.fora-ultimo")
    if [ "$h" = nunca ] || [ "$h" -ge 26 ]; then problemas+=("última cópia no R2: há ${h} h"); fi
  fi
  # Chave pública dos backups (INF-18): com a esperada no script, divergir é alerta; e uma vez
  # por mês (dia 1º, 12:00 UTC) a vigia manda o fim dela para o dono comparar com o Bitwarden,
  # e a cada 3 meses lembra o teste de restauração.
  if [ -s "$FORA_DEST" ]; then
    backup_destinatario_conferir >/dev/null || problemas+=("chave pública dos backups na VPS ($(backup_destinatario_resumo)) diferente da esperada: os backups não sobem")
    if [ "$(date -u +%d%H)" = 0112 ] && [ $((10#$(date -u +%M))) -lt 5 ]; then
      local tri=""
      case "$(date -u +%m)" in 01|04|07|10) tri=$'\n'"Este mês também: teste de restauração (bash bootstrap-vps.sh backup-link crystal_web_chat e abrir no Mac com a chave do Bitwarden; README, Backup fora da VPS)." ;; esac
      vigia_telegram "🔑 Conferência mensal: a chave pública dos backups na VPS termina em $(backup_destinatario_resumo). Compare com o item 'Crystal backup age' do Bitwarden; se não bater, os backups novos não abrem com a sua chave.$tri" || true
    fi
  fi
  uso=$(df -P /var/lib/docker 2>/dev/null | awk 'NR==2{gsub("%","",$5); print $5}' || true)
  if printf '%s' "$uso" | grep -Eq '^[0-9]+$' && [ "$uso" -ge 85 ]; then
    problemas+=("disco da VPS em ${uso}% (/var/lib/docker): limpar ou ampliar antes que o banco pare")
  fi
  falhas=$(docker service logs --since 6m "${APP_STACK}_app_api" 2>&1 | grep -E 'crystal: resposta falhou|canal: envio para a inbox falhou|base de alunos: indisponível|transcrição: (falhou|indisponível)|e-mail: envio falhou|risco: aviso à equipe falhou|crystal: forget falhou|mensagem: (geração falhou|erro da resposta não gravado)|uploads: limpeza de órfãos falhou|atendimento: (fila repassada à equipe na saída|não conferiu o acesso)' || true)
  if [ -n "$falhas" ]; then
    resumo=$(printf '%s\n' "$falhas" | grep -oE '"code":"[A-Z_]+"(,"(status|motivo)":("[^"]*"|[0-9]+|null))?' | sort | uniq -c | sort -rn | head -3 | tr -s ' ' | tr '\n' ';' || true)
    problemas+=("$(printf '%s\n' "$falhas" | wc -l) resposta(s) falharam nos últimos 5 min: ${resumo%;}")
  fi
  # Uma vez por hora: a Crystal responde de verdade e o crédito do OpenRouter está ok.
  if [ $((10#$(date +%M))) -lt 5 ]; then
    cid=$(docker ps -q -f name=${APP_STACK}_app_api | head -1)
    # Pelo nosso Chatwoot a API também chama a Crystal (robô): o teste vale nos dois canais.
    if [ -n "$cid" ] && [ -n "$(app_valor "$APP_EXT" CRYSTAL_API_URL)" ]; then
      # Mesmo cabeçalho que a API usa: "authorization" leva Bearer; outro nome (o
      # x-api-key da provisória) leva a chave crua. Antes era Bearer fixo (achado 33).
      r=$(docker exec "$cid" node -e '
        const h = (process.env.CRYSTAL_API_AUTH_HEADER || "authorization").toLowerCase();
        const k = process.env.CRYSTAL_API_KEY || "";
        fetch(process.env.CRYSTAL_API_URL + (process.env.CRYSTAL_API_PATH ?? "/v1/messages"), { method: "POST",
          headers: { [h]: h === "authorization" ? "Bearer " + k : k, "content-type": "application/json" },
          body: JSON.stringify({ contact_id: null, conversation_id: "vigia", message: { type: "text", text: "Responda só: ok" } }),
          signal: AbortSignal.timeout(60000) }).then(r => console.log(r.status)).catch(e => console.log(e.name))' 2>/dev/null || echo erro)
      [ "$r" = "200" ] || problemas+=("teste da nossa Crystal: $r")
    fi
    cid=$(docker ps -q -f name=${APP_STACK}_app_crystal | head -1)
    limite=$(app_valor "$VIGIA_CONF" LIMITE)
    if [ -n "$cid" ] && [ -n "$limite" ]; then
      saldo=$(docker exec "$cid" node -e '
        fetch("https://openrouter.ai/api/v1/credits", { headers: { authorization: "Bearer " + process.env.OPENROUTER_API_KEY },
          signal: AbortSignal.timeout(20000) }).then(r => r.json())
          .then(j => console.log(Math.floor(j.data.total_credits - j.data.total_usage))).catch(() => console.log(""))' 2>/dev/null || true)
      if printf '%s' "$saldo" | grep -Eq '^-?[0-9]+$' && [ "$saldo" -lt "$limite" ]; then
        problemas+=("crédito do OpenRouter em US\$ $saldo (abaixo de $limite): recarregar")
      fi
    fi
  fi

  anterior=$(app_valor "$VIGIA_ESTADO" RESUMO); quando=$(app_valor "$VIGIA_ESTADO" QUANDO)
  if [ ${#problemas[@]} -gt 0 ]; then
    resumo=$(printf '%s | ' "${problemas[@]}"); resumo=${resumo% | }
    # Mesmo problema: repete só depois de 1 hora (as contagens mudam, por isso compara sem números).
    if [ "$(echo "$resumo" | tr -d '0-9')" = "$(echo "$anterior" | tr -d '0-9')" ] && [ $((agora - ${quando:-0})) -lt 3600 ]; then
      return 0
    fi
    echo "$(date -Is) ALERTA $resumo"
    if vigia_telegram "⚠️ App da Crystal: $(printf '\n- %s' "${problemas[@]}")
Na VPS: bash bootstrap-vps.sh crystal-nossa-teste"; then
      umask 077; printf 'RESUMO=%s\nQUANDO=%s\n' "$resumo" "$agora" > "$VIGIA_ESTADO"
    else
      echo "$(date -Is) Telegram recusou o aviso"
    fi
  elif [ -n "$anterior" ]; then
    echo "$(date -Is) normalizado"
    vigia_telegram "✅ App da Crystal normalizado." && rm -f "$VIGIA_ESTADO"
  fi
  # Log pequeno: só as últimas 500 linhas.
  if [ -f "$VIGIA_LOG" ] && [ "$(wc -l < "$VIGIA_LOG")" -gt 1000 ]; then
    tail -500 "$VIGIA_LOG" > "$VIGIA_LOG.tmp" && mv "$VIGIA_LOG.tmp" "$VIGIA_LOG"
  fi
}

# ================================================================== ATENDIMENTO
# O nosso Chatwoot CE (stacks-app/20-atendimento.yaml) em atendimento., no lugar
# do LendChat. A Crystal responde como robô (agent bot) pela API do app
# (/webhooks/chatwoot-bot). Segredos gerados aqui, uma vez só, em $CW_SEG.
# SECRET_KEY_BASE e as três chaves ACTIVE_RECORD_ENCRYPTION_* NUNCA mudam depois
# de o Chatwoot ter dado: sem elas, 2FA e segredos guardados ficam ilegíveis.
CW_DIR="$BASE/atendimento"
CW_SEG="$CW_DIR/.segredos"
CW_YAML=20-atendimento.yaml
CW_STACK=crystal_atendimento
CW_VERSAO=v4.18.0-ce
CW_HOST="atendimento.$DOMINIO"
CW_CONTA="Crystal"
CW_INBOX="App da Crystal"

cw_rails() { # id do contêiner do Rails do Chatwoot
  docker ps -q -f name=${CW_STACK}_cw_rails | head -1
}

# Roda Ruby no Chatwoot (rails runner). O código vai pela entrada padrão; valores,
# pelo ambiente do docker exec (-e NOME, sem valor na linha de comando). O mktemp da
# imagem é o do BusyBox, que só aceita o modelo terminado em XXXXXX: com sufixo .rb ele
# recusava e o atendimento-configurar nunca terminava (achado 6). O rails runner
# carrega o arquivo pelo caminho, sem precisar da extensão.
# Saída útil só nas linhas "CW_OUT NOME=valor".
cw_ruby() { # cw_ruby [NOME_DE_VARIAVEL...] < codigo.rb
  local cid args=() v
  cid=$(cw_rails); [ -n "$cid" ] || falha "o Chatwoot não está rodando: bash $0 atendimento-subir"
  for v in "$@"; do args+=(-e "$v"); done
  docker exec -i "${args[@]}" "$cid" sh -c \
    'f=$(mktemp /tmp/cw.XXXXXX) || exit 1; cat > "$f"; RAILS_LOG_TO_STDOUT= bundle exec rails runner "$f" 2>&1; r=$?; rm -f "$f"; exit $r'
}

cw_gerar_segredos() {
  mkdir -p "$CW_DIR"; chmod 700 "$CW_DIR"
  umask 077
  if [ -f "$CW_SEG" ]; then ok "segredos do atendimento já existem em $CW_SEG (mantidos)"; return 0; fi
  {
    echo "CW_DB_SENHA=$(openssl rand -hex 24)"
    echo "CW_REDIS_SENHA=$(openssl rand -hex 24)"
    echo "SECRET_KEY_BASE=$(openssl rand -hex 64)"
    echo "ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=$(openssl rand -hex 16)"
    echo "ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=$(openssl rand -hex 16)"
    echo "ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=$(openssl rand -hex 16)"
    echo "CRIADO_EM=$(date -u +%FT%TZ)"
  } > "$CW_SEG"
  chmod 600 "$CW_SEG"
  ok "segredos do atendimento gerados em $CW_SEG. Copie pro cofre: bash $0 atendimento-segredos"
}

cw_gerar_env() {
  local db redis
  db=$(app_valor "$CW_SEG" CW_DB_SENHA); redis=$(app_valor "$CW_SEG" CW_REDIS_SENHA)
  [ -n "$db" ] && [ -n "$redis" ] || falha "senhas ausentes em $CW_SEG"
  umask 077
  {
    echo "POSTGRES_DB=chatwoot"
    echo "POSTGRES_USER=chatwoot"
    echo "POSTGRES_PASSWORD=$db"
    echo "POSTGRES_INITDB_ARGS=--auth-host=scram-sha-256"
  } > "$CW_DIR/postgres.env"
  echo "REDIS_PASSWORD=$redis" > "$CW_DIR/redis.env"
  {
    echo "# Gerado por bootstrap-vps.sh em $(date -u +%FT%TZ). Não editar: é regravado a cada atendimento-subir."
    echo "FRONTEND_URL=https://$CW_HOST"
    echo "DEFAULT_LOCALE=pt_BR"
    # O Traefik termina o TLS; com FORCE_SSL o Rails redirecionaria em círculo.
    echo "FORCE_SSL=false"
    echo "ENABLE_ACCOUNT_SIGNUP=false"
    echo "POSTGRES_HOST=cw_postgres"
    echo "POSTGRES_PORT=5432"
    echo "POSTGRES_USERNAME=chatwoot"
    echo "POSTGRES_PASSWORD=$db"
    echo "POSTGRES_DATABASE=chatwoot"
    echo "REDIS_URL=redis://cw_redis:6379"
    echo "REDIS_PASSWORD=$redis"
    echo "RAILS_LOG_TO_STDOUT=true"
    echo "LOG_LEVEL=info"
    echo "ACTIVE_STORAGE_SERVICE=local"
    # Nada sai para os servidores do Chatwoot: sem telemetria e sem o relay do app deles.
    echo "DISABLE_TELEMETRY=true"
    echo "ENABLE_PUSH_RELAY_SERVER=false"
    grep -E '^(SECRET_KEY_BASE|ACTIVE_RECORD_ENCRYPTION_[A-Z_]+)=' "$CW_SEG"
    # E-mail (convite de atendente, troca de senha) pelo SMTP do Resend, com o
    # mesmo remetente do app. Sem a chave, o Chatwoot fica sem e-mail.
    local chave remetente
    chave=$(app_valor "$APP_EXT" RESEND_API_KEY); remetente=$(app_valor "$APP_EXT" EMAIL_FROM)
    if [ -n "$chave" ] && [ -n "$remetente" ]; then
      echo "MAILER_SENDER_EMAIL=$remetente"
      echo "SMTP_DOMAIN=$DOMINIO"
      echo "SMTP_ADDRESS=smtp.resend.com"
      echo "SMTP_PORT=587"
      echo "SMTP_USERNAME=resend"
      echo "SMTP_PASSWORD=$chave"
      echo "SMTP_AUTHENTICATION=login"
      echo "SMTP_ENABLE_STARTTLS_AUTO=true"
    fi
  } > "$CW_DIR/chatwoot.env"
  chmod 600 "$CW_DIR/postgres.env" "$CW_DIR/redis.env" "$CW_DIR/chatwoot.env"
  unset db redis
  grep -q '^SMTP_PASSWORD=' "$CW_DIR/chatwoot.env" && ok "e-mail do Chatwoot pelo Resend" \
    || aviso "Chatwoot sem e-mail (falta RESEND_API_KEY/EMAIL_FROM do app): convite de atendente não chega"
}

atendimento_subir() {
  [ "$(docker info --format '{{.Swarm.ControlAvailable}}')" = "true" ] || falha "este nó não é manager do Swarm"
  docker network inspect network_swarm_public >/dev/null 2>&1 || falha "rede network_swarm_public não existe"
  docker service ls --format '{{.Name}}' | grep -q '^traefik_traefik$' || aviso "Traefik não encontrado: sem ele $CW_HOST não responde"
  # INF-06: o Rails vai para a borda_atendimento; o Traefik tem de estar nela antes.
  redes_unica || redes_criar
  redes_exigir_traefik borda_atendimento
  local ip ips
  ip=$(getent ahostsv4 "$CW_HOST" 2>/dev/null | awk 'NR==1{print $1}' || true)
  [ -n "$ip" ] || falha "$CW_HOST ainda não existe no DNS. Crie no Cloudflare: tipo A, nome atendimento, IP desta VPS, nuvem CINZA (Somente DNS)"
  hostname -I | tr ' ' '\n' | grep -qxF "$ip" \
    || falha "$CW_HOST aponta para $ip, que não é esta VPS. Nuvem LARANJA? Deixe CINZA (Somente DNS): o certificado é emitido aqui"
  ok "$CW_HOST -> $ip"

  echo "== imagem chatwoot/chatwoot:$CW_VERSAO (uns 2 minutos na primeira vez)"
  docker pull -q "chatwoot/chatwoot:$CW_VERSAO" >/dev/null || falha "não baixou chatwoot/chatwoot:$CW_VERSAO"
  ok "imagem baixada"

  echo "== segredos e ambiente"
  cw_gerar_segredos
  cw_gerar_env

  echo "== stack"
  mkdir -p "$ORIG" "$STACKS"; chmod 700 "$BASE" "$STACKS"
  baixar_conferido "stacks-app/$CW_YAML" "$ORIG/$CW_YAML" || falha "sem $CW_YAML conferido: a stack no ar não foi trocada"
  grep -q '^services:' "$ORIG/$CW_YAML" || falha "$CW_YAML não parece um compose"
  # Console de super admin: só os IPs do painel. Sem lista, só a própria VPS (fechado).
  ips=127.0.0.1/32
  [ -s "$PAINEL_IPS_ARQ" ] && ips=$(paste -sd, "$PAINEL_IPS_ARQ")
  umask 077
  sed -e "s|CW_VERSAO|$CW_VERSAO|g" -e "s|CW_ENV_DIR|$CW_DIR|g" -e "s|CW_IPS_ADMIN|$ips|g" "$ORIG/$CW_YAML" > "$STACKS/$CW_YAML"
  grep -nE 'CW_VERSAO|CW_ENV_DIR|CW_IPS_ADMIN' "$STACKS/$CW_YAML" | grep -vE '^\s*[0-9]+:\s*#' | grep -q . && falha "marcador sobrando em $CW_YAML"
  redes_ajustar "$STACKS/$CW_YAML"
  local t0; t0=$(date +%s)
  docker stack deploy -c "$STACKS/$CW_YAML" "$CW_STACK" --detach=true >/dev/null
  sleep 8
  echo "  na primeira vez o Chatwoot cria o banco inteiro: até 10 minutos"
  esperar_stack "$CW_STACK" 600 || { servico_log_morto "${CW_STACK}_cw_rails"; echo "  Logs: docker service logs --tail 80 ${CW_STACK}_cw_rails"; exit 1; }
  conferir_atualizacao "$t0" "$CW_VERSAO" "${CW_STACK}_cw_rails" "${CW_STACK}_cw_sidekiq" \
    && conferir_atualizacao "$t0" - "${CW_STACK}_cw_postgres" "${CW_STACK}_cw_redis" \
    || falha "o Chatwoot não ficou de pé: o Swarm desfez a troca (log acima)"
  ok "Chatwoot em $CW_VERSAO, sem rollback"
  copia_cron_atualizar
  echo
  atendimento_status
  painel_trava_segredos
  echo
  if [ -z "$(app_valor "$APP_EXT" CHATWOOT_BOT_TOKEN)" ]; then
    echo "Próximo: bash $0 atendimento-configurar"
  fi
}

# Trava da área de administração do Chatwoot (/super_admin, /monitoring, /platform): daqui
# da VPS, que não está na lista de IPs do painel, cada variação tem de levar 403 do Traefik.
# Com o Traefik v2.11.3, /x/../super_admin passava (CVE-2025-32431). Só leitura.
admin_trava_conferir() {
  docker service inspect "${CW_STACK}_cw_rails" >/dev/null 2>&1 || return 0
  local p c falhou=0
  for p in /super_admin /x/../super_admin /x/%2e%2e/super_admin //super_admin /monitoring/sidekiq /platform/api/v1/users; do
    c=$(curl -s -o /dev/null -m 15 --path-as-is -w '%{http_code}' "https://$CW_HOST$p" 2>/dev/null) || c=000
    [ "$c" = 403 ] && continue
    falhou=1
    aviso "https://$CW_HOST$p -> $c (esperado 403 do Traefik). Traefik antigo no ar? IP desta VPS na lista do painel?"
  done
  if [ "$falhou" = 0 ]; then
    ok "área de administração do Chatwoot: 403 nas 6 variações (inclusive /../ e %2e%2e)"
  fi
  return 0
}

atendimento_status() {
  echo "== Serviços do atendimento"
  docker service ls --filter "label=com.docker.stack.namespace=$CW_STACK" --format '{{.Name}} {{.Replicas}} {{.Image}}' \
    | awk '{printf "  %-34s %-5s %s\n",$1,$2,$3}'
  local code t=0
  while :; do
    code=$(curl -s -o /dev/null -m 20 -w '%{http_code}' "https://$CW_HOST/api" 2>/dev/null) || true
    [ "$code" = "200" ] || [ $t -ge 120 ] && break
    sleep 10; t=$((t+10))
  done
  case "${code:-000}" in
    200) ok "https://$CW_HOST/api -> 200 (certificado válido)" ;;
    000) aviso "https://$CW_HOST sem resposta ou certificado inválido (DNS cinza? Traefik ainda emitindo? tente de novo em 2 min)" ;;
    *) aviso "https://$CW_HOST/api -> $code" ;;
  esac
  if [ "${code:-000}" = 200 ]; then admin_trava_conferir; fi
}

atendimento_segredos() {
  [ -f "$CW_SEG" ] || falha "ainda não há segredos: bash $0 atendimento-subir"
  if [ -t 1 ] && command -v less >/dev/null; then
    {
      echo "Segredos do Chatwoot (atendimento.). Copie pro Bitwarden, item 'Chatwoot VPS'."
      echo "SECRET_KEY_BASE e as três ACTIVE_RECORD_ENCRYPTION_* NUNCA podem mudar."
      echo "Aperte q pra fechar: os valores somem da tela e não vão pro histórico."
      echo
      grep -vE '^CRIADO_EM=' "$CW_SEG"
    } | less -K
  else
    echo "rode num terminal para ver os segredos"
  fi
}

# Conta, admin, inbox de API do app e o robô (a Crystal). Idempotente: rodar de
# novo confere e devolve os mesmos valores; a senha do admin só nasce na primeira
# vez (--nova-senha troca). Grava no app os valores do canal e do robô e sobe a API
# com a TAG (a imagem precisa ter a rota /webhooks/chatwoot-bot; sem TAG, a que roda).
# O app continua na nossa Crystal direta até: bash bootstrap-vps.sh app-canal chatwoot
atendimento_configurar() {
  local nova="" tag="" a email nome senha="" saida v
  shift
  for a in "$@"; do
    case "$a" in
      --nova-senha) nova=$a ;;
      sha-[0-9a-f]*|v[0-9]*) tag=$a ;;
      *) falha "uso: bash $0 atendimento-configurar [TAG_DO_APP] [--nova-senha]" ;;
    esac
  done
  [ -n "$tag" ] || tag=$(app_tag_atual)
  echo "$tag" | grep -Eq '^(sha-[0-9a-f]{7}|v[0-9][0-9A-Za-z.-]*)$' || falha "tag do app inválida: $tag"
  [ -n "$(cw_rails)" ] || falha "o Chatwoot não está rodando: bash $0 atendimento-subir"
  [ -f "$APP_SEG" ] || falha "o app ainda não subiu: bash $0 app-subir TAG"
  email=$(app_valor "$CW_SEG" ADMIN_EMAIL)
  if [ -z "$email" ]; then
    read -rp "E-mail do administrador do Chatwoot (você): " email
    echo "$email" | grep -Eq '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' || falha "e-mail inválido"
    read -rp "Nome que aparece para a equipe: " nome
    [ -n "$nome" ] || falha "nome vazio"
  else
    nome=""
    ok "administrador: $email"
  fi
  if [ -z "$(app_valor "$CW_SEG" ADMIN_EMAIL)" ] || [ "$nova" = "--nova-senha" ]; then
    # Maiúscula, minúscula, número e símbolo: o Chatwoot exige os quatro.
    senha=$(python3 -c 'import secrets,string; a=string.ascii_letters+string.digits; print("".join(secrets.choice(a) for _ in range(20))+"Aa7!")')
  fi

  echo "== conta, administrador, inbox do app e robô (leva uns 40 s)"
  saida=$(CW_EMAIL="$email" CW_NOME="$nome" CW_SENHA="$senha" CW_CONTA="$CW_CONTA" CW_INBOX="$CW_INBOX" \
    CW_WEBHOOK_APP="https://api.$DOMINIO/webhooks/chatwoot" CW_WEBHOOK_ROBO="https://api.$DOMINIO/webhooks/chatwoot-bot" \
    cw_ruby CW_EMAIL CW_NOME CW_SENHA CW_CONTA CW_INBOX CW_WEBHOOK_APP CW_WEBHOOK_ROBO <<'RUBY'
conta = Account.find_or_create_by!(name: ENV.fetch("CW_CONTA")) { |a| a.locale = "pt_BR" }

user = User.find_or_initialize_by(email: ENV.fetch("CW_EMAIL").downcase)
senha = ENV["CW_SENHA"].to_s
if user.new_record?
  user.name = ENV.fetch("CW_NOME")
  user.type = "SuperAdmin"
  user.confirmed_at = Time.current
end
unless senha.empty?
  user.password = senha
  user.password_confirmation = senha
end
user.save!
AccountUser.find_or_create_by!(account: conta, user: user) { |au| au.role = :administrator }

inbox = conta.inboxes.find_by(name: ENV.fetch("CW_INBOX"))
unless inbox
  canal = Channel::Api.create!(account: conta, webhook_url: ENV.fetch("CW_WEBHOOK_APP"), hmac_mandatory: true)
  inbox = conta.inboxes.create!(name: ENV.fetch("CW_INBOX"), channel: canal)
end
inbox.channel.update!(webhook_url: ENV.fetch("CW_WEBHOOK_APP"), hmac_mandatory: true)

robo = AgentBot.find_or_initialize_by(account_id: conta.id, name: "Crystal")
robo.description = "A Crystal responde pela API do app (webhooks/chatwoot-bot)"
robo.outgoing_url = ENV.fetch("CW_WEBHOOK_ROBO")
robo.save!
ligacao = AgentBotInbox.find_or_initialize_by(inbox_id: inbox.id)
ligacao.agent_bot = robo
ligacao.status = :active
ligacao.save!

canal = inbox.channel.reload
raise "inbox sem segredo de webhook" if canal.secret.blank?
raise "robô sem segredo" if robo.secret.blank?
raise "robô sem token" if robo.access_token&.token.blank?
puts "CW_OUT CHATWOOT_ACCOUNT_ID=#{conta.id}"
puts "CW_OUT CHATWOOT_INBOX_IDENTIFIER=#{canal.identifier}"
puts "CW_OUT CHATWOOT_INBOX_HMAC_TOKEN=#{canal.hmac_token}"
puts "CW_OUT CHATWOOT_WEBHOOK_SECRET=#{canal.secret}"
puts "CW_OUT CHATWOOT_BOT_TOKEN=#{robo.access_token.token}"
puts "CW_OUT CHATWOOT_BOT_SECRET=#{robo.secret}"
puts "CW_OUT OK=1"
RUBY
) || { saida=""; falha "a configuração no Chatwoot falhou. Ver: docker service logs --tail 80 ${CW_STACK}_cw_rails"; }
  printf '%s\n' "$saida" | grep -q '^CW_OUT OK=1$' || { saida=""; falha "o Chatwoot não confirmou a configuração"; }

  # Valores do LendChat guardados uma vez, para consulta (não voltam sozinhos).
  if [ -f "$APP_EXT" ] && [ ! -f "$APP_DIR/.externos.lendchat" ] && grep -q '^CHATWOOT_BASE_URL=' "$APP_EXT" \
     && ! grep -q "^CHATWOOT_BASE_URL=https://$CW_HOST\$" "$APP_EXT"; then
    umask 077; grep -E '^CHATWOOT_' "$APP_EXT" > "$APP_DIR/.externos.lendchat"
    ok "valores antigos do LendChat guardados em $APP_DIR/.externos.lendchat"
  fi
  app_gravar CHATWOOT_BASE_URL "https://$CW_HOST"
  for v in CHATWOOT_ACCOUNT_ID CHATWOOT_INBOX_IDENTIFIER CHATWOOT_INBOX_HMAC_TOKEN CHATWOOT_WEBHOOK_SECRET CHATWOOT_BOT_TOKEN CHATWOOT_BOT_SECRET; do
    app_gravar "$v" "$(printf '%s\n' "$saida" | sed -n "s/^CW_OUT $v=//p" | tail -1)"
  done
  saida=""
  ok "canal e robô gravados no app (sem aparecer na tela)"
  if [ -z "$(app_valor "$CW_SEG" ADMIN_EMAIL)" ]; then
    umask 077; echo "ADMIN_EMAIL=$email" >> "$CW_SEG"
  fi

  if [ -n "$senha" ]; then
    if [ -t 1 ] && command -v less >/dev/null; then
      {
        echo "LOGIN DO CHATWOOT (guarde no Bitwarden, item 'Chatwoot VPS'). Não cole em chat."
        echo
        echo "Endereço: https://$CW_HOST"
        echo "E-mail:   $email"
        echo "Senha:    $senha"
        echo
        echo "No primeiro login: Perfil > Senha e segurança > ligar a verificação em duas etapas (2FA)."
        echo "Aperte q para fechar."
      } | less -K
    else
      aviso "rode num terminal para ver a senha (ou: bash $0 atendimento-configurar --nova-senha)"
    fi
    senha=""
  fi

  echo "== API do app ($tag) com o robô ligado"
  app_subir app-subir "$tag"
  echo
  atendimento_teste
}

# Teste de ponta a ponta sem passar pelo app: um contato de teste escreve na inbox
# do app e a Crystal tem que responder como robô em até 90 s.
atendimento_teste() {
  [ -n "$(app_valor "$APP_EXT" CHATWOOT_INBOX_IDENTIFIER)" ] || falha "ainda não configurado: bash $0 atendimento-configurar"
  echo "== teste: mensagem na inbox do app, a Crystal responde como robô"
  python3 - "$APP_EXT" "$CW_HOST" <<'PY' && ok "a Crystal respondeu pelo Chatwoot" \
    || { aviso "não respondeu. Ver: docker service logs --since 5m ${APP_STACK}_app_api | grep -i chatwoot"; return 1; }
import hashlib, hmac, json, sys, time, urllib.request
conf = dict(l.rstrip("\n").split("=", 1) for l in open(sys.argv[1]) if "=" in l)
base = f"https://{sys.argv[2]}/public/api/v1/inboxes/{conf['CHATWOOT_INBOX_IDENTIFIER']}"
def chamar(metodo, caminho, corpo=None):
    req = urllib.request.Request(base + caminho, method=metodo, headers={"content-type": "application/json", "accept": "application/json"},
                                 data=None if corpo is None else json.dumps(corpo).encode())
    with urllib.request.urlopen(req, timeout=20) as r:
        return json.loads(r.read() or b"null")
ident = "teste-atendimento"
hash_ = hmac.new(conf["CHATWOOT_INBOX_HMAC_TOKEN"].encode(), ident.encode(), hashlib.sha256).hexdigest()
contato = chamar("POST", "/contacts", {"identifier": ident, "identifier_hash": hash_, "name": "Teste do bootstrap (ignorar)"})
src = contato["source_id"]
conversa = chamar("POST", f"/contacts/{src}/conversations", {})
cid = conversa["id"]
chamar("POST", f"/contacts/{src}/conversations/{cid}/messages", {"content": "Oi, Crystal. Responda só: teste ok."})
fim = time.time() + 90
while time.time() < fim:
    time.sleep(5)
    msgs = chamar("GET", f"/contacts/{src}/conversations/{cid}/messages")
    saida = [m for m in (msgs or []) if m.get("message_type") in (1, "outgoing")]
    if saida:
        print("  resposta:", (saida[-1].get("content") or "")[:160].replace("\n", " "))
        sys.exit(0)
print("  sem resposta em 90 s")
sys.exit(1)
PY
}

# Por onde o app conversa: crystal (a nossa Crystal direto, sem Chatwoot) ou
# chatwoot (pelo nosso Chatwoot, com a equipe vendo e podendo assumir). Volta é
# o mesmo comando com o outro valor.
app_canal() {
  local canal="${2:-}" pg
  case "$canal" in
    crystal) ;;
    chatwoot)
      [ -n "$(app_valor "$APP_EXT" CHATWOOT_BOT_TOKEN)" ] || falha "o nosso Chatwoot ainda não está configurado: bash $0 atendimento-configurar"
      [ "$(app_valor "$APP_EXT" CHATWOOT_BASE_URL)" = "https://$CW_HOST" ] || falha "CHATWOOT_BASE_URL não é o nosso Chatwoot: bash $0 atendimento-configurar" ;;
    *) falha "uso: bash $0 app-canal chatwoot   (ou crystal para voltar)" ;;
  esac
  app_gravar CHAT_TRANSPORT "$canal"
  if [ "$canal" = "chatwoot" ]; then
    # Vínculos antigos apontam para contatos do LendChat: o app refaz no nosso.
    pg=$(docker ps -q -f name=${APP_STACK}_app_postgres | head -1)
    [ -n "$pg" ] && docker exec -i "$pg" psql -q -U crystal -d crystal_web_chat \
      -c "update conversations set channel_source_id = null, channel_conversation_id = null where channel_source_id is not null" >/dev/null \
      && ok "vínculos antigos com a inbox desfeitos"
  fi
  app_subir app-subir "$(app_tag_atual)"
  echo
  ok "app conversando por: $canal. Teste no app: https://app.$DOMINIO"
  [ "$canal" = "chatwoot" ] && echo "  A conversa aparece em https://$CW_HOST (Conversas > Pendentes)."
  return 0
}

# ------------------------------------------------------------------ Crystal provisória
# Fluxo do n8n (n8n/crystal-provisoria.json) que responde no app usando o
# OpenRouter, até a agência entregar o agente. Importa credenciais e fluxo
# pela linha de comando do n8n, ativa, reinicia o n8n e aponta o app para ele.
# Não abre o app para alunos: a base de clientes continua simulada.
N8N_WF_ID=crystalProvisor1
app_gravar() { # app_gravar NOME VALOR (sem eco)
  umask 077; touch "$APP_EXT"
  grep -vE "^$1=" "$APP_EXT" > "$APP_EXT.tmp" || true
  printf '%s=%s\n' "$1" "$2" >> "$APP_EXT.tmp"
  mv "$APP_EXT.tmp" "$APP_EXT"; chmod 600 "$APP_EXT"
}

app_tag_atual() { # vazio quando a API não existe; nunca derruba o script (achado 32)
  { docker service inspect ${APP_STACK}_app_api --format '{{.Spec.TaskTemplate.ContainerSpec.Image}}' 2>/dev/null || true; } \
    | sed -E 's/@sha256:.*//; s/.*://'
}

n8n_reiniciar() {
  local s t0
  for s in n8n_editor_n8n_editor n8n_webhook_n8n_webhook n8n_worker_n8n_worker; do
    docker service inspect "$s" >/dev/null 2>&1 || continue
    echo "  reiniciando $s (até 2 min)"
    t0=$(date +%s)
    docker service update --force --detach=false "$s" >/dev/null 2>&1 || aviso "$s não confirmou a reinicialização; conferir com: docker service ls"
    conferir_atualizacao "$t0" - "$s" || falha "$s não voltou depois de reiniciar (log acima)"
  done
}

crystal_provisoria() {
  local cid wf chave orkey tag
  cid=$(docker ps -q -f name=n8n_editor_n8n_editor | head -1)
  [ -n "$cid" ] || falha "o editor do n8n não está rodando"
  tag=$(app_tag_atual); [ -n "$tag" ] || falha "o app não está no ar: rode 'app-subir TAG' antes"

  mkdir -p "$ORIG"; wf="$ORIG/crystal-provisoria.json"
  baixar_conferido "n8n/crystal-provisoria.json" "$wf" || falha "sem o fluxo crystal-provisoria.json conferido"
  grep -q "\"$N8N_WF_ID\"" "$wf" || falha "o fluxo baixado não é o esperado"

  echo "Use uma chave NOVA do OpenRouter, só pra isto: Keys > Create Key, nome 'Crystal provisória',"
  echo "com limite de crédito (ex.: 10 dólares). NUNCA a chave que o agente da agência usa hoje."
  read -rsp "Chave do OpenRouter (começa com sk-or-, não aparece na tela): " orkey; echo
  case "$orkey" in sk-or-*) ;; *) unset orkey; falha "isso não parece uma chave do OpenRouter (começa com sk-or-). Nada foi gravado" ;; esac
  chave=$(app_valor "$APP_EXT" CRYSTAL_API_KEY)
  [ -n "$chave" ] || chave=$(openssl rand -hex 32)
  local redis_senha
  redis_senha=$(app_valor "$SEGREDOS" N8N_REDIS_SENHA)
  [ -n "$redis_senha" ] || falha "N8N_REDIS_SENHA ausente em $SEGREDOS: rode 'preparar' (e redeploy de 03 a 06) antes"

  echo "== credenciais no n8n (webhook, OpenRouter, Redis banco 2)"
  CHAVE="$chave" ORKEY="$orkey" REDIS_SENHA="$redis_senha" python3 - <<'PY' | docker exec -i "$cid" sh -c 'umask 077; cat > /tmp/crystal-cred.json'
import json, os
print(json.dumps([
  {"id": "crystalProvKey01", "name": "Crystal provisória · chave do app", "type": "httpHeaderAuth",
   "data": {"name": "x-api-key", "value": os.environ["CHAVE"]}},
  {"id": "crystalProvORkey", "name": "OpenRouter · Crystal provisória", "type": "httpHeaderAuth",
   "data": {"name": "Authorization", "value": "Bearer " + os.environ["ORKEY"]}},
  {"id": "crystalProvRedis", "name": "Redis do n8n · banco 2 (Crystal provisória)", "type": "redis",
   "data": {"host": "n8n_redis", "port": 6379, "database": 2, "password": os.environ["REDIS_SENHA"]}},
]))
PY
  unset orkey redis_senha
  if ! docker exec "$cid" n8n import:credentials --input=/tmp/crystal-cred.json >/dev/null 2>&1; then
    docker exec "$cid" rm -f /tmp/crystal-cred.json; falha "o n8n recusou as credenciais"
  fi
  docker exec "$cid" rm -f /tmp/crystal-cred.json
  ok "3 credenciais gravadas (cifradas pela chave do n8n)"

  echo "== fluxo"
  docker exec -i "$cid" sh -c 'cat > /tmp/crystal-wf.json' < "$wf"
  docker exec "$cid" n8n import:workflow --input=/tmp/crystal-wf.json >/dev/null 2>&1 || falha "o n8n recusou o fluxo"
  docker exec "$cid" rm -f /tmp/crystal-wf.json
  # O n8n 1.123 só ativa uma versão que exista no histórico, e o import pela
  # linha de comando não cria essa versão. Grava (ou atualiza) a versão atual.
  local pg; pg=$(docker ps -q -f name=n8n_postgres_n8n_postgres | head -1)
  [ -n "$pg" ] || falha "o Postgres do n8n não está rodando"
  docker exec -i "$pg" psql -v ON_ERROR_STOP=1 -q -U postgres -d n8n_queue >/dev/null <<SQL || falha "não gravou a versão do fluxo no histórico do n8n"
INSERT INTO workflow_history ("versionId", "workflowId", nodes, connections, authors, name, "createdAt", "updatedAt")
SELECT "versionId", id, nodes, connections, 'bootstrap-vps', name, now(), now()
  FROM workflow_entity WHERE id = '$N8N_WF_ID'
ON CONFLICT ("versionId") DO UPDATE
  SET nodes = EXCLUDED.nodes, connections = EXCLUDED.connections, name = EXCLUDED.name, "updatedAt" = now();
SQL
  docker exec "$cid" n8n update:workflow --id="$N8N_WF_ID" --active=true >/dev/null 2>&1 || falha "não ativou o fluxo"
  docker exec "$pg" psql -U postgres -d n8n_queue -tAc "select active::text from workflow_entity where id='$N8N_WF_ID'" | grep -q true \
    || falha "o fluxo não ficou ativo no banco do n8n"
  ok "fluxo '$N8N_WF_ID' importado e ativo"
  n8n_reiniciar

  echo "== app apontando para a Crystal provisória"
  app_gravar CRYSTAL_API_URL "https://webhook.$DOMINIO/webhook"
  app_gravar CRYSTAL_API_PATH "/crystal-provisoria"
  app_gravar CRYSTAL_API_AUTH_HEADER "x-api-key"
  app_gravar CRYSTAL_API_REPLY_FIELD "text"
  app_gravar CRYSTAL_API_KEY "$chave"
  unset chave
  app_subir app-subir "$tag"

  echo
  echo "== teste: a API do app pergunta à Crystal provisória"
  local api t=0
  while :; do
    api=$(docker ps -q -f name=${APP_STACK}_app_api | head -1)
    [ -n "$api" ] && docker exec "$api" sh -c '[ -n "$CRYSTAL_API_URL" ]' 2>/dev/null && break
    [ $t -ge 120 ] && break; sleep 5; t=$((t+5))
  done
  docker exec "$api" node -e '
    const u = process.env.CRYSTAL_API_URL + process.env.CRYSTAL_API_PATH;
    fetch(u, { method: "POST", headers: { "x-api-key": process.env.CRYSTAL_API_KEY, "content-type": "application/json" },
      body: JSON.stringify({ contact_id: null, conversation_id: "teste-bootstrap", message: { type: "text", text: "Oi, Crystal. Responda só: teste ok." } }) })
      .then(async r => { const t = await r.text(); console.log("  status", r.status, "->", t.slice(0, 160)); process.exit(r.ok ? 0 : 1); })
      .catch(e => { console.log("  falhou:", e.name); process.exit(1); });' \
    && ok "Crystal provisória respondendo. Teste no app: https://app.$DOMINIO" \
    || aviso "não respondeu ainda. O n8n pode levar 1 min depois de reiniciar: rode 'bash $0 crystal-provisoria-teste'"
}

crystal_provisoria_teste() {
  local api; api=$(docker ps -q -f name=${APP_STACK}_app_api | head -1)
  [ -n "$api" ] || falha "a API do app não está rodando"
  docker exec "$api" node -e '
    const u = process.env.CRYSTAL_API_URL + process.env.CRYSTAL_API_PATH;
    fetch(u, { method: "POST", headers: { "x-api-key": process.env.CRYSTAL_API_KEY, "content-type": "application/json" },
      body: JSON.stringify({ contact_id: null, conversation_id: "teste-bootstrap", message: { type: "text", text: "Oi, Crystal. Responda só: teste ok." } }) })
      .then(async r => console.log("  status", r.status, "->", (await r.text()).slice(0, 160)))
      .catch(e => console.log("  falhou:", e.name));'
}

# Volta o app para a Crystal simulada e desativa o fluxo. Não apaga as credenciais.
crystal_provisoria_desligar() {
  local cid tag
  tag=$(app_tag_atual); [ -n "$tag" ] || falha "o app não está no ar"
  # Sem CRYSTAL_API_* a API com o robô do Chatwoot não sobe (achado 33).
  [ -z "$(app_valor "$APP_EXT" CHATWOOT_BOT_TOKEN)" ] \
    || falha "o robô do Chatwoot usa a Crystal pela CRYSTAL_API_*: desligar a provisória derrubaria a API. Para sair da provisória: bash $0 crystal-nossa $tag"
  grep -vE '^CRYSTAL_API_(URL|PATH|AUTH_HEADER|REPLY_FIELD|KEY)=' "$APP_EXT" > "$APP_EXT.tmp" || true
  mv "$APP_EXT.tmp" "$APP_EXT"; chmod 600 "$APP_EXT"
  app_subir app-subir "$tag"
  cid=$(docker ps -q -f name=n8n_editor_n8n_editor | head -1)
  if [ -n "$cid" ]; then
    docker exec "$cid" n8n update:workflow --id="$N8N_WF_ID" --active=false >/dev/null 2>&1 && n8n_reiniciar
  fi
  ok "app de volta à Crystal simulada; fluxo desativado"
}

# Crystal do WhatsApp (stack da agência, stacks-app/30-crystal-ia.yaml), quando o corte para o app
# terminar (PROXIMOS-PASSOS.md). Revisão de 24/10 (INF-30): enquanto ela ou o .env dela existem, é
# mais um lugar com a service_role do Supabase, a chave do OpenRouter e o token do LendChat. Tira a
# stack do ar e apaga o .env e o yaml gerado; as chaves têm de ser REVOGADAS na origem (INF-02).
ia_encerrar() {
  [ "${2:-}" = --confirmo ] || falha "isto tira a Crystal do WhatsApp (stack crystal_ia) do ar de vez. Só depois do corte para o app: bash $0 ia-encerrar --confirmo"
  local f
  if docker stack ls --format '{{.Name}}' 2>/dev/null | grep -qx crystal_ia; then
    docker stack rm crystal_ia >/dev/null || falha "não removi a stack crystal_ia"
    ok "stack crystal_ia removida (os contêineres somem em alguns segundos)"
  else
    ok "stack crystal_ia não está no ar"
  fi
  for f in "$APP_DIR/crystal-ia.env" "$STACKS/30-crystal-ia.yaml"; do
    [ -f "$f" ] || continue
    if command -v shred >/dev/null; then shred -u "$f"; else rm -f "$f"; fi
    ok "apagado: $f"
  done
  echo "Falta, fora da VPS (INF-02 e INF-30), nesta ordem:"
  echo "  1. Revogar as chaves que ela usava: a service_role do Supabase (depois de o app estar na nova:"
  echo "     app-definir SUPABASE_SERVICE_ROLE_KEY, app-subir, app-supabase-teste 200), a chave do OpenRouter"
  echo "     da agência e o token do LendChat."
  echo "  2. Cloudflare: apagar o registro ia. (cinza)."
  echo "  3. Quando nada mais usar: docker volume rm crystal_redis_data crystal_dlq_dumps"
  echo "  4. Anotar a data no CONTINUAR-EM-OUTRA-CONTA.md."
}

app_segredos() {
  [ -f "$APP_SEG" ] || falha "ainda não há segredos do app: rode 'app-subir'"
  if [ -t 1 ] && command -v less >/dev/null; then
    {
      echo "Segredos do app. Copie CADA LINHA direto pro Bitwarden. Aperte q pra fechar."
      echo "NÃO cole em chat, e-mail ou print: segredo que sai daqui tem que ser trocado."
      echo "ENCRYPTION_KEY e CPF_SALT nunca podem mudar: sem eles o banco do app fica ilegível."
      echo
      grep -vE '^CRIADO_EM=' "$APP_SEG"
    } | less -K
  else
    falha "rode num terminal: os segredos abrem no less e não ficam em log nem no histórico"
  fi
}

case "$CMD" in
  app-ghcr) app_ghcr ;;
  app-construir) app_construir "$@" ;;
  app-definir) app_definir "$@" ;;
  app-remover) app_remover "$@" ;;
  app-resend) app_resend ;;
  app-subir) app_subir "$@"; [ "${SUPABASE_FALHOU:-0}" = 0 ] || exit 1 ;;
  app-supabase-teste) app_supabase_teste ;;
  app-status) app_status ;;
  app-custo) shift; app_custo "$@" ;;
  app-admin) app_admin ;;
  vigia-config) vigia_config ;;
  atendimento-subir) atendimento_subir ;;
  atendimento-status) atendimento_status ;;
  atendimento-configurar) atendimento_configurar "$@" ;;
  atendimento-teste) atendimento_teste ;;
  atendimento-segredos) atendimento_segredos ;;
  app-canal) app_canal "$@" ;;
  vigia) vigia ;;
  app-aluno) app_aluno ;;
  app-segredos) app_segredos ;;
  ia-encerrar) ia_encerrar "$@" ;;
  app-recomecar) app_recomecar "$@" ;;
  crystal-nossa) crystal_nossa "$@" ;;
  app-revisao) app_revisao "$@" ;;
  app-telefone) app_telefone "$@" ;;
  app-db-papel) app_db_papel "$@" ;;
  crystal-nossa-teste) crystal_nossa_teste ;;
  crystal-conferir) crystal_conferir "$@" ;;
  app-api-parar) app_api_parar "$@" ;;
  app-auditoria-backfill) app_auditoria_backfill "$@" ;;
  app-painel-conferir) app_painel_conferir ;;
  painel-diagnostico) painel_diagnostico "$@" ;;
  fichas-ensaio) shift; fichas_ensaio "$@" ;;
  crystal-provisoria) crystal_provisoria ;;
  crystal-provisoria-teste) crystal_provisoria_teste ;;
  crystal-provisoria-desligar) crystal_provisoria_desligar ;;
  preparar) preparar "$@" ;;
  recomecar-n8n) recomecar_n8n "$@" ;;
  docker-api) docker_api ;;
  docker-daemon) docker_daemon "$@" ;;
  arquivos-hash) arquivos_hash ;;
  backup) backup "$@" ;;
  backup-cron) backup_cron ;;
  backup-chave) shift; backup_chave "$@" ;;
  backup-fora-config) backup_fora_config ;;
  backup-conferir) backup_conferir ;;
  backup-testar-trava) backup_testar_trava ;;
  backup-link) shift; backup_link "$@" ;;
  firewall) firewall ;;
  seguranca) seguranca ;;
  ssh-confirmar) ssh_confirmar ;;
  ssh-voltar) ssh_voltar ;;
  redes-conferir) redes_conferir ;;
  redes-voltar) redes_voltar "$@" ;;
  redes-separar) redes_separar ;;
  painel-restringir) shift; painel_restringir "$@" ;;
  painel-desligar) painel_desligar ;;
  painel-ligar) painel_ligar ;;
  traefik|portainer|bancos|n8n|tudo|status|segredos) "$CMD" ;;
  *) falha "comando desconhecido: $CMD" ;;
esac
