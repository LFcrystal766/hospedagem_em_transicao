# Correções do lado da VPS (revisão de 05/10)

Achados do repositório "vps" da tabela de `RELATORIO.md`. Tudo foi feito e testado
fora da VPS: sem acesso à VPS nem ao Cloudflare, cada função alterada rodou isolada,
com `docker`, `curl`, `tar`, `age` e a API do Cloudflare de mentira num diretório
temporário fora do repositório. Cada teste rodou duas vezes, contra o script de antes
(commit `2296192`) e o de depois, e mostra o caso que falhava e agora passa.

Nos arquivos tocados, `shellcheck -S warning` e `bash -n` passam sem aviso
(`bootstrap-vps.sh`, `cloudflare-degrau2.sh` e `auditoria-so-leitura.sh`). Os YAML
abrem no `yaml.safe_load`.

## Achado por achado

| # | Situação | Teste (antes → depois) |
|---|---|---|
| 7 | Corrigido | `app-aluno` e `app-admin` contra um contêiner que, como a imagem real, recusa gravar em `/app/apps/api` sem root: antes, "Permission denied" e saída 1 sem mensagem; depois, conta criada, `.ts` apagado e o CPF fora da linha de comando do docker |
| 4 | Corrigido | `app_conferir_troca` com o Swarm em `rollback_completed` e a MESMA tag: antes "ok os três serviços"; depois falha com o erro da tarefa e o log do contêiner que morreu. Rollback antigo (antes do deploy, caso do `app-subir TAG_ANTERIOR`) e troca normal: ok nos dois. `app-subir` inteiro com stubs: ok, rollback (sai 2), `api.env` recusado pelo `loadEnv` da imagem (sai 2 SEM chamar o `docker stack deploy`) e Supabase 404 (sai 1 com aviso). O `--eval` do preflight foi rodado no `env.ts` real do app: mostra `SUPABASE_URL: Invalid url` sem o valor |
| 6 | Corrigido | O trecho do `cw_ruby` no `sh` e no `mktemp` do BusyBox 1.36: antes "mktemp: Invalid argument" e caminho vazio; depois o código chega ao `rails runner` |
| 9 | Corrigido | 17 casos do `app-definir`: URL com `/rest/v1/` (antes gravava; depois corta e avisa), URL http, chave `sb_publishable_`, JWT anon (recusados), JWT service_role e `sb_secret_` (aceitos), RPC com maiúscula, VAPID sem `mailto:`, DSN sem chave, alerta http, timeout de 1000 ms (recusados). `app-supabase-teste`: 200, 404, 401 e sem resposta com a mensagem certa e a chave só na entrada padrão do curl |
| 21 | Corrigido | `backup` com o banco `crystal_agente`: dump, envio ao R2 e `backup-link crystal_agente` (antes, tipo recusado) |
| 22 | Corrigido | `backup` com o n8n fora do ar e o `tar` saindo 1: antes, abortava na primeira linha sem dump do app e sem R2; depois, app e memória salvos e enviados, uploads salvos com aviso, resumo e saída 1 |
| 23 | Corrigido | `backup-fora-config` com o teste recusado (403) e uma configuração boa antes: antes, a boa era APAGADA; depois, continua valendo |
| 24 | Corrigido | Cópia do cron com a versão de 29/09: antes ficava; depois é trocada por `mv` (inode novo) e o `status` mostra se é igual |
| 25 | Corrigido (era P) | Segunda rodada gera `-diferencial`; o `backup-link` devolve o completo e o diferencial mais novo; o par restaura com o `tar` de verdade |
| 27 | Lado da stack corrigido | `logging` json-file 3 x 10 MB em todos os serviços do app e do Chatwoot. IP truncado e polling fora do log ficam no app |
| 28 | Corrigido | O `command` da API (com `$$` trocado como o Swarm faz) contra um pnpm que falha 2 vezes: antes, sai 1 na primeira; depois, tenta de novo e sobe. `max_attempts` removido |
| 29 | Corrigido | `app-recomecar` com o Postgres fora do ar e com o `psql` sem resposta: antes, APAGAVA os três volumes; depois, nada apagado. Banco vazio comprovado: copia antes e só então apaga |
| 30 | Corrigido | Chave antiga no `.externos` e `CRYSTAL_AGENTE_KEY` nova: antes o `api.env` levava a antiga (401 em todo chat); depois leva a atual |
| 31 | Corrigido | `recomecar-n8n` com 2 fluxos e o serviço `n8n_editor_n8n_editor`: antes APAGAVA o banco; depois recusa |
| 32 | Corrigido | `app_tag_atual`, DNS do atendimento, log do contêiner morto e resumo da vigia com `\|\| true` (coberto nos testes do 4 e da vigia) |
| 33 | Corrigido | `CHATWOOT_BOT_*` sem `CRYSTAL_API_*`: antes passava; depois falha com a saída. Teste horário da vigia contra um servidor que exige `x-api-key`: antes 403 (falso alarme); depois 200 |
| 34 | Corrigido | `portainer` com lista de IPs e o yaml aberto: antes subia o painel aberto; depois recusa |
| 35 | Corrigido | `preparar` com a leitura dos managed headers falhando: antes "ok add_security_headers desligado" e saída 0; depois saída 2 |
| 36 | Corrigido | `laranja --aplicar` com `server.` laranja e o PATCH recusado: antes saía 0 com o apex E o `server.` laranja; depois para com 2 antes de tocar no apex |
| 37 | Corrigido (era P) | `regras` com erro de autenticação na fase: antes simulava um PUT só com a regra nova (apagaria as do painel); depois para. Com 10003 segue e cria |
| 38 | Corrigido | `laranja --aplicar` com `ftp.` CNAME do apex: antes ficava CNAME (resolveria para o Cloudflare); depois vira A no IP da AZAN, cinza, ANTES do apex |
| 47 | Corrigido | `publicar-prd.md` com `sha-398e46e` como versão no ar, sem o serviço `migrate`, roteiro do Supabase e comandos novos; README com os seis nomes de DNS; help do bootstrap diz para NÃO definir `CHATWOOT_API_TOKEN` |
| 69 | Corrigido | `backup-testar-trava` com DELETE 503: antes "a trava está valendo"; depois inconclusivo (saída 1). Com 403 e HEAD 200: ok |
| 70 | Corrigido | Chave `gsk_` no lugar do nome e `sb_secret_` no `app-remover`: antes o `app-remover` repetia a chave na tela; depois nenhum dos dois repete e os dois mandam trocar a chave. `segredos` e `app-segredos` fora de terminal recusam |
| 71 | Corrigido | `app-definir EQUIPE_EMAIL`: antes recusado; depois gravado |
| 72 | Corrigido (C/P) | Passo "Versão" do workflow: antes aceitava `latest` e executava o que viesse na tag manual (um `touch` injetado rodou); depois só `vX.Y.Z`, por variável de ambiente, e a imagem em minúsculas |
| 73 | Corrigido | `portas_docker_conferir` aponta o agente do Portainer publicado em 9001 e uma porta 8080 em `0.0.0.0`/`::` |
| 74 | Corrigido (era P) | `priority=1` removido do router do Portainer |
| 75 | Corrigido | `cinza` e `laranja` em simulação: antes saíam 1; depois 0 |
| 76 | Corrigido (era P) | Linha do certificado num PATH sem `timeout` (como no Mac): antes "timeout: command not found"; depois roda. O array vazio com `set -u` do bash 3.2 não dá para reproduzir aqui (bash 5): corrigido por construção |
| 13 | Já estava corrigido | Nada a fazer |

## O que não deu para testar aqui

- O `docker service inspect` real: a conferência lê `UpdatedAt` e
  `UpdateStatus.{State,StartedAt}` do JSON da API (nomes da documentação do Docker),
  não de template, e o teste usou esse mesmo formato. A primeira `app-subir` na VPS é
  a prova de verdade.
- O Cloudflare aceitar trocar o tipo do `ftp.` (CNAME para A) num PATCH. Se recusar, o
  script para antes de qualquer laranja e manda trocar à mão no painel.
- O código exato que o R2 devolve ao apagar com a trava. O teste aceita só 403 seguido
  de HEAD 200; outro código fica inconclusivo e mostra o número.
