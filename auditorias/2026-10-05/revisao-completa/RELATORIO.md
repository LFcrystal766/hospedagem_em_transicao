# Revisão de código completa: app da Crystal (sha-398e46e) e infra da VPS

Depois de juntar os duplicados, sobram **76 achados reais**: 59 confirmados e 17 plausíveis. **Nenhum é crítico.** Os céticos rebaixaram os que vieram como críticos. **Seis são altos**, e dois deles só aparecem quando o Chatwoot for ligado.

Hoje, quatro coisas ameaçam mais a produção:

1. **Exclusão LGPD falha para todas as alunas.** "Apagar conversas" e "Excluir conta" não apagam a memória que a Crystal guarda delas. Isso vale para 100% das contas de hoje.
2. **A rede de segurança do risco tem buracos.** A detecção não reconhece frases comuns de crise. Quando a Crystal cai ou demora, a aluna fica sem o CVV 188 e o Ligue 180, e a equipe não recebe o e-mail.
3. **Criar aluna à mão está quebrado.** O `app-aluno`, hoje o único jeito de dar acesso, falha desde a etapa 1 porque a API passou a rodar sem root.
4. **Ligar o Supabase tem as mesmas armadilhas do bug de hoje.** O `app-definir` não valida nada, o `app-subir` diz "ok" mesmo quando o Swarm desfez a troca, nenhuma sonda percebe a base fora do ar, e as contas atuais perdem a memória da Crystal.

## 1. O que corrigir primeiro

Status: C = confirmado, P = plausível. "app" é /home/user/crystal-prod. "vps" é /home/user/hospedagem_em_transicao.

| # | Sev. | Onde | Problema | O que acontece | Correção | Status |
|---|---|---|---|---|---|---|
| 1 | Alta | app `apps/api/src/services/crystal.ts:246`, `apps/crystal/src/app.ts:164,222` | A detecção de risco só existe dentro da Crystal | Com a API desistindo aos 60 s, a Crystal fora do ar ou barrando por limite (429), a aluna em risco fica sem CVV e 180 e a equipe não recebe o e-mail | Detectar risco também na API em qualquer falha, rodar a detecção antes do 429 e dar à Crystal um prazo total menor que o da API | C |
| 2 | Alta | app `apps/crystal/src/seguranca.ts:15` | As regex de risco deixam passar frases comuns | "ameaçando me matar", "não aguento mais viver", "vou me enforcar", "ele me estrangulou" e outras devolvem [] | Acrescentar os padrões e um teste para cada frase | C |
| 3 | Alta | app `apps/api/src/routes/me.ts:47`, `services/crystal.ts:206-217` | O forget só manda `contact_id`, que hoje é null em todas as contas, e ignora o status HTTP | Exclusão de conta ou de conversas responde 204, mas o histórico e o resumo ficam até 180 dias no `crystal_agente` | Ler o id da conversa antes do purge, mandar `conversation_id` e conferir `res.ok` | C |
| 4 | Alta | vps `crystal-em-casa/bootstrap-vps.sh:1220-1244` (também 269-283, 1806, 300) | A conferência depois do deploy só olha a tag da imagem | Mudar só o `.externos` com a mesma tag: o Swarm faz rollback e o script imprime "ok os três serviços estão em sha-…" | Falhar quando `UpdateStatus.State` for `rollback_*`, ou validar o api.env com `loadEnv` dentro da imagem antes do deploy | C |
| 5 | Alta (latente) | app `apps/api/src/services/chatwoot-bot.ts:79` | A regex `pedeAtendente` é larga demais | "quero me matar, não consigo falar com alguém" vai para a equipe sem passar pela Crystal, sem CVV e sem e-mail | Rodar a detecção de risco antes do desvio e aceitar só pedidos explícitos de atendente | C |
| 6 | Alta (latente) | vps `bootstrap-vps.sh:1694` | `mktemp /tmp/cw-XXXXXX.rb` é recusado pelo BusyBox da imagem do Chatwoot | `atendimento-configurar` e `app-canal` nunca terminam | Usar `mktemp /tmp/cw.XXXXXX`, ou `rails runner -` lendo da entrada padrão | C |
| 7 | Média | vps `bootstrap-vps.sh:1279,1325` | `docker exec` sem `-u` roda como `node`, e `/app/apps/api` pertence ao root | `app-aluno` e `app-admin` dão "Permission denied" e ninguém novo entra | Usar `docker exec -u 0` só para gravar e apagar o `.ts` | C |
| 8 | Média | app `apps/api/src/routes/auth.ts:133` | Com o Supabase, o login grava `crystalContactId` | As contas atuais passam de `v:<conversa>` para `c:<id>`: a Crystal as esquece e a memória antiga fica órfã | Antes de ligar, migrar a chave ou usar `user.id` como chave estável. No mínimo, registrar no roteiro | C |
| 9 | Média | vps `bootstrap-vps.sh:958-986` | `app-definir` não valida SUPABASE_URL/RPC/chave, VAPID_SUBJECT, SENTRY_DSN, ALERT_WEBHOOK_URL nem CHANNEL_REPLY_TIMEOUT_MS | URL sem https derruba o boot. URL terminada em `/rest/v1` ou a chave anon dão 503 em todo login. O bootstrap diz "ok base de alunos: Supabase" | Validar o formato de cada valor, recusar a chave anon e criar um `app-supabase-teste` que chama o RPC de verdade | C |
| 10 | Média | app `apps/api/src/server.ts:346`, `integration-probes.ts:221-224`, `integrations.ts:104` | A sonda do Supabase não é agendada, aceita 401/404 como ok e o painel mostra "null" | O Supabase cai ou recusa a chave, todo login dá 503 e ninguém é avisado | Agendar a sonda com SUPABASE_*, chamar o RPC com um CPF fictício e logar `DIRECTORY_UNAVAILABLE` num padrão que a vigia procure | C |
| 11 | Média | app `apps/api/src/routes/auth.ts:51`, `auth-otp.ts:29` | Limite de 5 tentativas por IP em 15 min no login, no código e no reenvio, que não dá para mudar na VPS | Com CGNAT ou Wi-Fi de evento, a 3ª aluna no mesmo IP recebe 429 | Subir o limite por IP para 50 a 100 e pôr RATE_AUTH_* em APP_EXTERNOS | C |
| 12 | Média | app `docs/supabase/app_verificar_login.sql:54` | `limit 1` sem `order by` | Com linhas repetidas, o contact_id e o telefone alternam de um login para outro e a memória se perde | Conferir duplicatas e ordenar por `created_at asc, id asc` | P |
| 13 | Média | vps `crystal-em-casa/README.md:351` | O README aponta para o SQL-modelo do repositório do app | Rodar o modelo falha, ou, se alguém "conserta" os nomes, perde o filtro de acesso ativo | Apontar para `crystal-em-casa/supabase/app_verificar_login.sql` | C |
| 14 | Média | app `apps/api/src/services/aviso-risco.ts:139` | A trava de 30 min é gravada antes do envio pelo Resend | Se o Resend falha, os avisos de risco seguintes daquela conversa ficam mudos por 30 min | Apagar a chave no catch e incluir "risco: aviso à equipe falhou" no grep da vigia | C |
| 15 | Média | app `aviso-risco.ts:148` | O aviso não leva o e-mail da aluna | Sem telefone cadastrado, a equipe recebe só o nome | Incluir o e-mail, sem o CPF | C |
| 16 | Média | app `seguranca.ts:15` | "ele vai me matar" cai como risco à própria vida | A aluna ameaçada recebe CVV e SAMU, sem garantia do 180 e do 190 | Classificar a frase também como violência | C |
| 17 | Média | app `apps/crystal/src/app.ts:284`, `memoria.ts:154` | Um turno em andamento ou o resumidor regravam depois do forget | Com contact_id estável (depois do Supabase), o que foi apagado volta ao prompt | Guardar uma lápide por chave ou cancelar a geração antes do forget | P |
| 18 | Média | app `apps/crystal/prompt/crystal.md:34` | A base de conhecimento está vazia e o prompt manda dizer "vou verificar com a equipe" | Promessa que nunca se cumpre | Encaminhar para a tela Suporte ou para o WhatsApp do suporte | C |
| 19 | Média | app `apps/api/src/services/messages.ts:427` | Falha do Groq (limite de gasto, 401, 5xx) vira "não entendi o áudio" | Todo áudio falha sem alerta, e a vigia não vê | Separar falha do serviço de áudio ruim e pôr "transcrição: falhou" no grep da vigia | C |
| 20 | Média | app `apps/api/src/services/otp-login.ts:62` | `catch {}` engole o erro do Resend | Falha de envio sem causa no log, e cada nova tentativa consome o limite | Logar o status, tentar de novo em 429/5xx e não contar o 503 no limite | C |
| 21 | Média | vps `bootstrap-vps.sh:341` | O backup não inclui o banco `crystal_agente` | Se o volume se perder, a Crystal esquece todas as alunas | Acrescentar o `pg_dump` dele, a limpeza de 14 dias, o envio ao R2 e o tipo no `backup_link` | C |
| 22 | Média | vps `bootstrap-vps.sh:329,353,370` | O backup aborta inteiro em qualquer falha parcial (n8n fora, `tar` com saída 1 por arquivo alterado) | A noite fica sem dump do app e sem envio ao R2, em silêncio | Tratar cada parte como independente, aceitar a saída 1 do tar e alertar na vigia se o backup tiver mais de 26 h | C |
| 23 | Média | vps `bootstrap-vps.sh:503,377` | `backup-fora-config` apaga a configuração boa antes do teste, e o backup pula o R2 com saída 0 | A cópia fora da VPS para sem alerta | Só trocar a configuração depois do teste e alertar quando `.fora-ultimo` passar de 26 h | C |
| 24 | Média | vps `bootstrap-vps.sh:385,1589` | O cron roda uma cópia congelada do bootstrap em /root/crystal | As mudanças do Chatwoot no backup e na vigia não entram | Atualizar a cópia, sem silenciar erro, no `app-subir` e no `atendimento-subir`, e conferir o hash no status | C |
| 25 | Média | vps `bootstrap-vps.sh:350,374` | `tar` completo dos uploads todo dia, com 14 cópias guardadas | O disco enche com o uso, e o PUT único ao R2 trava acima de cerca de 5 GiB | Cópia incremental e alerta de disco na vigia | P |
| 26 | Média | app `apps/api/src/routes/uploads.ts:95-137`, `services/retention.ts:34` | Upload sem cota, sem conferir o conteúdo e sem limpeza de órfãos | Uma conta enche o disco em horas | Cota diária por usuário, limpeza de órfãos com mais de 24 h e conferência dos bytes iniciais do arquivo | C |
| 27 | Média | vps `stacks-app/10-crystal-app.yaml:87`, app `apps/api/src/app.ts:70` | Logs do Docker sem rotação, com o IP de cada requisição | O IP fica guardado sem prazo, contra a política de privacidade, e o disco cresce | `log-opts` no daemon.json, IP truncado e polling fora do log | C |
| 28 | Média | vps `10-crystal-app.yaml:118,156,185` | `max_attempts: 5` em 300 s | Postgres lento na subida deixa a API em 0/1 até alguém agir | Tirar `max_attempts` e esperar o `pg_isready` antes da migração | C |
| 29 | Média | vps `bootstrap-vps.sh:1380-1395` | A trava "banco vazio" do `app-recomecar` falha aberta (contêiner ausente ou `n="?"`) | Apaga os volumes e os segredos de um banco com dados | Exigir `n=0` comprovado, abortar se algum `volume rm` falhar e copiar o `.segredos` antes | C |
| 30 | Média | vps `bootstrap-vps.sh:1044,1114,1120` | `app-recomecar` gera uma CRYSTAL_AGENTE_KEY nova, mas o api.env mantém a CRYSTAL_API_KEY antiga | Todo chat dá 401 e o script diz "ok" | Derivar a CRYSTAL_API_KEY do `.segredos`, ou rodar `crystal-nossa` no recomecar | C |
| 31 | Média | vps `bootstrap-vps.sh:863,873-875` | A guarda do `recomecar_n8n` procura o serviço `^n8n_editor$`, mas o nome real é `n8n_editor_n8n_editor` | Apaga fluxos ativos (a crystal-provisoria) | Corrigir o nome e esperar a liberação do volume com `docker ps -a` | C |
| 32 | Média | vps `bootstrap-vps.sh:1773,2045,1236,1615` | Falha dentro de `$(...)` ou de pipeline mata o script antes da mensagem de erro | `atendimento.` sem DNS, `app_tag_atual` sem API ou log vazio saem sem explicação. A vigia pode ficar muda | `|| true` nesses pontos | C |
| 33 | Média | vps `bootstrap-vps.sh:1071-1074,1624` | api.env com CHATWOOT_BOT_* e sem CRYSTAL_API_* passa no bootstrap. O teste da vigia usa Bearer fixo | A API não sobe depois de `crystal-provisoria-desligar`. Falso alarme de hora em hora no modo provisório | Exigir CRYSTAL_API_* quando houver robô e montar o header a partir de CRYSTAL_API_AUTH_HEADER | C |
| 34 | Média | vps `bootstrap-vps.sh:259,824` | `preparar` regrava o Portainer aberto, e a falha vira só aviso | O painel pode subir sem a lista de IPs, e o status diz que está restrito | Falhar fechado e conferir o `ipallowlist` no deploy | C |
| 35 | Média | vps `scripts/cloudflare-degrau2.sh:276,287,302-306` | Leitura que falha dentro de `$(...)` ou de `api GET` vira "ok" | Managed Headers, Bot Fight Mode, Page Rules e Cache Rules aparecem conferidos sem terem sido | `|| exit 2` depois de cada leitura e usar `ler` nas regras | C |
| 36 | Média | vps `cloudflare-degrau2.sh:139-141` | O `while` em pipe engole a falha do PATCH de volta para cinza | `laranja --aplicar` sai 0 com `server.` ainda laranja | Ler com `< <(...)` e propagar o erro | C |
| 37 | Média | vps `cloudflare-degrau2.sh:192-198` | Qualquer erro no GET do entrypoint vira "fase vazia" | O PUT pode apagar regras criadas no painel | Tratar como vazia só o código 10003 | P |
| 38 | Média | vps `cloudflare-degrau2.sh:133` | `ftp.` é CNAME do apex, e a guarda só olha o próprio registro | Com o apex laranja, o FTP pelo nome para e o script diz que está cinza | Trocar `ftp.` por um registro A direto, ou checar o alvo do CNAME | C |
| 39 | Média | app `apps/api/src/routes/refund-webhook.ts:60`, `packages/shared/src/refund.ts:9` | O webhook de reembolso não olha o produto, e o roteiro manda assinar "todos os produtos" | Reembolso de um order bump corta a Crystal de quem segue pagando | Lista de produtos permitidos e "ignored" para o resto | P |
| 40 | Média | app `packages/shared/src/refund.ts:11` | CPF inválido ou corpo aninhado reprova o evento inteiro (400), sem log | Reembolsos não cortam o acesso e ninguém percebe | Documento como texto livre, event_id em texto ou número, e log com alerta | P |
| 41 | Média | app `apps/web/components/AppMenu.tsx:103` | "Sair" não cancela a inscrição Web Push | O aparelho continua recebendo trechos de mensagens (hoje, as respostas do suporte) | `DELETE /push/subscribe` e `unsubscribe()` no logout | P |
| 42 | Média | app `apps/web/lib/api.ts:107` | `/staff/*` responde 404 com a sessão vencida, e o web só renova em 401 | O painel da equipe quebra depois de 15 min | Em 404 nessas rotas, renovar a sessão uma vez, ou renovar periodicamente | C |
| 43 | Média | app `apps/web/components/chat/Composer.tsx:775`, `lib/use-chat.ts:343` | Sem limite de 4.000 caracteres (legenda 1.000) no cliente | Bolha vermelha eterna, que volta da fila offline a cada abertura | `maxLength` com contador e 400 VALIDATION tratado como recusa definitiva | C |
| 44 | Média | app `apps/web/lib/use-chat.ts:322` | POST /messages sem chave de idempotência | Uma resposta perdida no 4G duplica a mensagem e a geração | `client_message_id` com índice único | C |
| 45 | Média | app `Composer.tsx:297` | Pausa por app em segundo plano no modo gesto não volta para o painel | O composer trava e o áudio se perde | `setMode('panel')` na pausa | C |
| 46 | Média | app `apps/web/components/notificacoes/AvisoNotificacoes.tsx:55` | O aviso confere o tutorial uma vez só, antes de ele montar | Dois modais juntos no primeiro acesso | Considerar o tutorial pendente sem `tutorial_home` e conferir de novo antes de abrir | C |
| 47 | Média | vps `crystal-em-casa/publicar-prd.md:93,97,122,25`, `README.md:385`, `bootstrap-vps.sh:98` | O roteiro manda `app-subir sha-da617ac`, cita o serviço `migrate` (não existe), diz "três nomes" (são seis) e o help sugere CHATWOOT_API_TOKEN | Quem segue o roteiro volta a produção para uma versão anterior e contraria a decisão de 05/10 | Atualizar os documentos e o help | C |
| 48 | Baixa | app `apps/api/src/routes/auth-otp.ts:179-201` | O reenvio não zera o contador nem desfaz em falha do Resend | Uma tentativa só depois do reenvio, e o código antigo perde a validade | `kv.del` no reenvio e desfazer quando o envio falhar | C |
| 49 | Baixa | app `apps/api/src/plugins/rate-limit.ts:46` | Chave do limite por CPF é SHA-256 sem sal, gravada no AOF do Redis | CPF reversível por quem lê o volume | HMAC com CPF_SALT | P |
| 50 | Baixa | app `messages.ts:232`, `stream-hub.ts:94` | Erro de banco no meio da geração deixa a resposta em "streaming" | Sem "Tentar de novo" até um restart | Marcar como erro e logar no catch, e aceitar o retry de "streaming" órfão | C |
| 51 | Baixa | app `messages.ts:426` | Abort no deploy vira "não entendi o áudio" com status "done" | Resposta enganosa e sem retry | Propagar o abort como `fail` | C |
| 52 | Baixa | app `refund-webhook.ts:77` | CPF desconhecido cai na busca por e-mail | Desliga a conta de outro CPF e não pré-bloqueia o CPF do evento | Com CPF válido, usar só o CPF (decisão pendente) | C |
| 53 | Baixa (latente) | app `apps/api/src/routes/chatwoot-bot.ts:241` | Fila do robô só em memória | Mensagem perdida num deploy, e a conversa fica pendente | Drenar no SIGTERM ou repassar à equipe ao subir | P |
| 54 | Baixa (latente) | app `chatwoot-bot.ts:237` | O robô não confere o usuário | No WhatsApp, quem foi reembolsada continua sendo atendida | Conferir por `phoneE164` e `disabled` | P |
| 55 | Baixa | app `retention.ts:30` | `health_events` sem limpeza | Cerca de 1 milhão de linhas por ano, contra os 30 dias da política | `deleteOlderThan(30d)` | C |
| 56 | Baixa | app `auth.ts:146` | Corrida no unique de `cpf_hash` | 500 numa das abas | Capturar P2002 e ler de novo | P |
| 57 | Baixa | app `apps/web/components/chat/MessageList.tsx:77` | Contador do botão de descer errado | Conta mensagens antigas e não conta a 1ª bolha | Contar só o que entra depois da última | C |
| 58 | Baixa | app `use-chat.ts:474` | O retry não liga o "digitando…" | Tela vazia por 10 a 40 s | `setTyping(true)` depois do POST | C |
| 59 | Baixa | app `use-chat.ts:638`, `lib/api.ts:32` | fetch sem timeout | Bolha presa no relógio e sync parado | `AbortSignal.timeout` | P |
| 60 | Baixa | app `use-chat.ts:641` | Corrida no syncLatest | Mensagem duplicada e chave React repetida | Conferir de novo dentro do updater | P |
| 61 | Baixa | app `apps/web/app/(equipe)/equipe/suporte/[id]/page.tsx:55` | Responder um ticket fechado mantém "Fechado" na tela | Status errado até recarregar | Usar `waiting_user` ou recarregar | C |
| 62 | Baixa | app `apps/web/components/prontuario/PerfilForm.tsx:133` | O /me tardio zera o formulário | Rascunho e foto perdidos | Repor só o campo intocado | P |
| 63 | Baixa | app `apps/web/app/(chat)/perfil/page.tsx:52` | Falha no consentimento não mostra nada | A aluna não sabe se deu certo | Estado de erro com "Tentar de novo" | C |
| 64 | Baixa | app `apps/web/lib/voltar.ts:35` | `history.length` não diminui | Seta morta ou que sai do app | Profundidade em `history.state` | C |
| 65 | Baixa | app `apps/web/lib/staff-password.ts:24` | Senha errada dispara refresh e repete o pedido | Bloqueio na 3ª tentativa | `skipRefresh: true` | C |
| 66 | Baixa | app `apps/crystal/src/server.ts:22` | Pool sem timeout de conexão nem de consulta | Postgres travado segura a Crystal e o healthz | `connectionTimeoutMillis` e `query_timeout` | P |
| 67 | Baixa | app `seguranca.ts:81` | `includes("180")` | "virada de 180 graus" impede o acréscimo do Ligue 180 | Regex com fronteira de palavra ou o texto exato | C |
| 68 | Baixa | app `apps/web/components/equipe/financeiro/NewEntryDialog.tsx:37` | Data sugerida em UTC | Lançamento no dia seguinte depois das 21h | Data em America/Sao_Paulo | C |
| 69 | Baixa | vps `bootstrap-vps.sh:575` | `backup-testar-trava` aceita qualquer código HTTP | Um 5xx ou 429 "prova" a trava | Só aceitar 403 de retenção, e HEAD depois | C |
| 70 | Baixa | vps `bootstrap-vps.sh:945,1003,843,2177` | O detector não reconhece `gsk_` nem `sb_secret_`. `app-remover` repete o argumento. `segredos` fora de TTY imprime sem aviso | Chave colada sem a ordem de trocar, ou chave impressa no erro | Ampliar o padrão e nunca repetir o argumento | C |
| 71 | Baixa | vps `bootstrap-vps.sh:898` | EQUIPE_EMAIL fora de APP_EXTERNOS | Não dá para definir o e-mail da equipe | Incluir na lista | C |
| 72 | Baixa | vps `crystal-em-casa/ci/build-image.yml:34,49,68` | Nome da imagem com maiúsculas, e tag do disparo manual sem validação | O build aborta, ou publica `latest` | Converter para minúsculas e validar `^v\d+\.\d+\.\d+$` | C/P |
| 73 | Baixa | vps `bootstrap-vps.sh:614-618,666` | ufw não filtra portas publicadas pelo Docker | A mensagem "só 22, 80 e 443" não é garantida | Regras em DOCKER-USER, ou conferir as portas dos serviços | C |
| 74 | Baixa | vps `stacks-app/01-portainer-restrito.yaml:67` | Portainer com `priority=1` | Um router sem Host passaria por cima da lista de IPs | Remover a linha | P |
| 75 | Baixa | vps `cloudflare-degrau2.sh:164,334,340` | `laranja` e `cinza` em simulação saem com 1 | Falso erro se forem encadeados | Terminar as funções com `return 0` | C |
| 76 | Baixa | vps `scripts/auditoria-so-leitura.sh:139` | Array vazio com `set -u` no bash 3.2 | Seção de certificados vazia | `${arr[@]+"${arr[@]}"}` e um substituto para `timeout` | P |

## 2. Detalhes dos altos

**1. Contatos de risco dependem da Crystal estar de pé.**
- **Prazos que não batem.** A API corta em 60 s (`api/src/env.ts:38`, que vale também para o stream). Cada tentativa da Crystal tem 55 s próprios (`openrouter.ts:78`), e uma falha `indisponivel` ou `vazio` ganha nova tentativa (`app.ts:218-229`).
- **Limite antes da detecção.** O 429 da Crystal sai em `app.ts:164`, antes do `detectarRiscos` em `:177`. A API aceita 30 mensagens por minuto, a Crystal 20.
- **Deploy.** O `app_crystal` usa stop-first, com limite de 384M (`10-crystal-app.yaml:146-156`).
- **Efeito.** Em todos esses casos a API gera um erro sem `risco`, e `messages.ts:262` cai no `fail()` genérico: sem CVV e sem e-mail. A API não tem detecção própria; o grep não acha nada.
- **Gatilho mais realista hoje:** a Crystal fora do ar.

**2. Detecção de risco incompleta.**
- **Frases que passam.** Os dois céticos rodaram uma cópia de `seguranca.ts`, e 14 frases devolveram []. O caso "ameaçando me matar" é um buraco da própria regra: o lookbehind da `:15` exclui a forma, mas o padrão de violência da `:33` só aceita `ameac(ou|a)`.
- **O que atenua.** O prompt fixo pede o 188 e o 180 no caminho normal.
- **O que fica sem cobertura.** Quando o modelo falha, essa é a única camada, e não há reserva.

**3. LGPD: o forget não acontece.**
- **Como a memória é gravada.** Todas as contas nascem com `crystalContactId: null` (`bootstrap-vps.sh:1354`, `auth.ts:78`, `staff-users.ts:118`). A Crystal guarda a memória em `v:<conversationId>` (`apps/crystal/src/app.ts:64-67`).
- **Por que a exclusão falha.** `esquecerNaCrystal(null)` retorna na hora (`me.ts:47-48`). O forget só sabe mandar `contact_id` (`crystal.ts:212`), embora a rota da Crystal aceite `conversation_id` (`app.ts:53-58`). Um 401 ou 500 não gera log (`crystal.ts:206-217`).
- **Efeito.** Contraria a página de privacidade (`privacidade/page.tsx:115-119`). Atenuantes: o texto é cifrado e a retenção apaga em até 180 dias.

**4. Rollback silencioso no `app-subir` com a mesma tag.**
- **Mecanismo.** O api.env entra no spec do serviço por `env_file`. Se o boot falha, o `failure_action: rollback` volta o serviço ao spec anterior, que tem a mesma tag. `rollback_completed` não está entre os estados pendentes (`:1220`, `:280`), então a comparação de tag passa.
- **Falso "ok" duplo.** O `app_gerar_env` também imprime "ok base de alunos: Supabase" (`:1142`) olhando o arquivo, não o serviço no ar.
- **Onde mais acontece.** Na mesma classe estão `atendimento_subir` (`:1806`) e `deploy()` (`:300`). Também valem `app-canal`, `crystal-nossa` e `crystal-provisoria-desligar`; este último desativa o fluxo do n8n depois do falso "ok".
- **Peso hoje.** É exatamente o passo de hoje: `app-definir SUPABASE_*` seguido de `app-subir sha-398e46e`.

**5. Regex de atendente (latente).**
- **O que acontece.** `pedeAtendente` dá verdadeiro para frases de crise (testado em node). A rota responde com o aviso de passagem e retorna antes do `streamReply` (`routes/chatwoot-bot.ts:135-139`), então a Crystal nunca vê a mensagem.
- **Quando passa a valer.** Só existe com CHATWOOT_BOT_* configurado, ou seja, no dia em que o Chatwoot for ligado.

**6. mktemp no Chatwoot (latente).**
- **O que acontece.** A imagem `v4.18.0-ce` é Alpine com BusyBox 1.37. `busybox mktemp ./cw-XXXXXX.rb` responde "Invalid argument" (testado). O `f` fica vazio e `CW_OUT OK=1` nunca aparece (`:1928`).
- **Efeito.** Bloqueia todo o caminho do Chatwoot.

## 3. Base de alunos do Supabase

**Situação.** O código em produção já tem a integração, feita por uma função RPC (`POST {SUPABASE_URL}/rest/v1/rpc/app_verificar_login`, com `p_cpf` e `p_email`). Faltam três coisas: criar a função no Supabase, gravar 2 valores na VPS e rodar `app-subir`. A base é autoritativa: toda aluna é conferida a cada login, sem cache. Equipe e contas de revisão nunca são consultadas.

**SQL certo:** `crystal-em-casa/supabase/app_verificar_login.sql` (commit 3544bc4). Não use o do repositório do app (achado 13). Ajustes antes de rodar:
- conferir se a coluna `cpf` é numérica, porque o zero à esquerda some;
- criar um índice na expressão de dígitos do CPF;
- pôr `order by c.created_at asc, c.id asc` no `limit 1` (achado 12);
- se o PostgREST não enxergar a função, rodar `notify pgrst, 'reload schema'`.

**Passos na VPS:**
```bash
bash bootstrap-vps.sh app-definir SUPABASE_URL               # exatamente https://<ref>.supabase.co, sem /rest/v1, sem barra final
bash bootstrap-vps.sh app-definir SUPABASE_SERVICE_ROLE_KEY  # colar no prompt, nunca na linha de comando
# teste antes de subir (não imprime a chave): espera [] e HTTP 200
K=$(grep '^SUPABASE_SERVICE_ROLE_KEY=' /root/crystal/app/.externos | cut -d= -f2-)
U=$(grep '^SUPABASE_URL=' /root/crystal/app/.externos | cut -d= -f2-)
curl -sS -w '\nHTTP %{http_code}\n' -X POST "$U/rest/v1/rpc/app_verificar_login" \
  -H "apikey: $K" -H "Authorization: Bearer $K" -H 'content-type: application/json' \
  -d '{"p_cpf":"52998224725","p_email":"teste@exemplo.invalid"}'; unset K U
bash bootstrap-vps.sh app-subir sha-398e46e
```

**Depois do `app-subir`, não confie no "ok".** Confira com `docker service inspect crystal_app_app_api -f '{{.UpdateStatus.State}}'` (achado 4) e faça um login de teste com uma conta de aluna.

**Riscos, em resumo:**
- **Memória das contas atuais.** Elas perdem a memória da Crystal (achado 8).
- **Falhas sem aviso.** Se o Supabase cair, ou a chave e a URL estiverem erradas, todo login dá 503 e nada avisa (achados 9 e 10).
- **Pico de entrada.** O limite por IP vai bloquear alunas na abertura (achado 11).
- **Alcance da service_role.** Ela ignora RLS, e a agência, que é Owner, enxerga a chave.
- **Tabela exposta.** Se `leticia_crystal_customers` estiver sem RLS, a chave anon, que é pública, lê a base com CPF.
- **Alunas sem CPF.** São 1.708 cadastros, que não entram.
- **Cancelamento sem reembolso.** Só barra no próximo login; uma sessão aberta dura até 90 dias.
- **Consentimento.** Nome, telefone e e-mail são gravados antes do consentimento (`auth.ts:146` vem antes de `:159`).

**O que pedir ao Luiz ou à agência (nenhum segredo pelo chat):**
1. Confirmar que a transferência do projeto terminou e qual é o papel da agência. Depois disso, rotacionar a service_role.
2. Rodar no SQL Editor só contagens e tipos: tipo da coluna `cpf`, CPFs sem 11 dígitos, RLS nas tabelas `leticia_crystal_*`, quantas alunas têm acesso e não têm CPF, e se há duplicatas.
3. Decidir se `pending` entra, se abre para todas ou só para `is_in_rollout`, e o que fazer com quem não tem CPF.
4. Dizer quantas contas de aluna o app já tem e se são só de teste. Isso decide entre migrar a memória ou aceitar a perda (achado 8).
5. Gravar a URL e a chave direto na VPS e guardar a chave no Bitwarden.
6. Dizer se as chaves são legadas (`eyJ…`) ou novas (`sb_secret_…`).
7. Confirmar se a Assiny avisa cancelamento e inadimplência, e não só reembolso.
8. Autorizar as correções 8, 9, 10, 12 e 13 antes de abrir.

## 4. Contestados e refutados

Nenhum achado ficou "contestado". Refutados:
- A chave `sb_secret_` mandada também em `Authorization: Bearer` derrubaria todo login: refutado. O teste com `curl` da seção 3 confirma na prática.
- Automatic HTTPS Rewrites ligado depois do `preparar`: foi decisão do plano, que diz que ele pode ficar ligado.
- Deploy restrito do Portainer desfeito pelo Swarm: o padrão do Swarm é `pause`, e o script trata `paused` como pendente.
- Volume de uploads com dono errado: o Docker copia o dono da imagem (`node`) quando o volume nasce.
- Partes de outros achados que não se sustentaram:
  - o `mail.` não é afetado pelo laranja no apex (só o `ftp.`);
  - a consequência "respostas simuladas" do achado 33 está errada: o efeito real é a API não subir;
  - o script de auditoria não aborta antes das etapas 6 e 7: só a seção de certificados sai vazia.

## 5. Plano de correção

**Leva 1: app, uma tag nova, antes de ligar o Supabase**
- Risco: achados 1, 2, 16 e 67. Isso cobre a detecção ampliada, "vai me matar" contado como violência, a detecção também na API, o 429 só depois da detecção, o prazo total da Crystal menor que 60 s e a conferência do 180 com fronteira de palavra.
- Aviso de risco: achados 14 e 15, com `kv.del` no catch e o e-mail da aluna no aviso.
- LGPD: achado 3 (`conversation_id` e `res.ok`) e achado 17 (lápide por chave).
- Supabase: achado 10 (sonda real e painel correto) e achado 11 (limite por IP mais alto).
- Alertas: achados 19 e 20.
- Uploads: achado 26 (cota e limpeza de órfãos).
- Pequenos do servidor: 48, 50, 51, 55, 56, 65 e 66.

**Leva 2: bootstrap e stacks (vps), um commit**
- Já, porque bloqueia acesso: achado 7 (`-u 0` no `app-aluno` e no `app-admin`).
- Conferências antes de ligar o Supabase: achados 4 e 9, com o `app-supabase-teste` no fim do `app-subir` e o api.env validado com `loadEnv` antes do deploy.
- Backup: achados 21, 22, 23, 24 e 25, mais o alerta de idade do backup e de disco na vigia.
- Comandos destrutivos: achados 29, 30, 31 e 34.
- Robustez: achados 28 e 27, mais 32 e 33.
- Chatwoot, antes de ligar: achado 6, mais 5, 53 e 54 do lado do app.
- Pequenos: 69, 70, 71, 72, 73 e 74.

**Leva 3: `cloudflare-degrau2.sh`, antes da madrugada do degrau 2**
- Achados 35, 36, 37, 38 e 75.

**Leva 4: web (UX)**
- Achados 42, 43, 44, 45, 46 e 41, depois 57 a 64 e 68.

**Precisa de decisão do Luiz**
- Memória das contas atuais: migrar a chave ou aceitar a perda (achado 8). Escolher a chave estável da memória (`user.id`?).
- Supabase: `pending` entra? Rollout? Alunas sem CPF? Rotacionar a service_role? Papel dedicado em vez da service_role?
- Reembolso: filtro de produto (achado 39), CPF que não bate (achado 52) e formato real da Assiny (achado 40).
- Prompt: para onde a Crystal encaminha quando não sabe (achado 18).
- Retenção de mídia: definir `message_retention_days`.
- Reafirmar que CHATWOOT_API_TOKEN não deve ser definido (achado 47).

**Só documentação**
- README aponta para o SQL certo (achado 13).
- `publicar-prd.md` com as tags atuais, sem o serviço `migrate`, com seis nomes de DNS e o help do CHATWOOT_API_TOKEN corrigido (achado 47).
- Registrar no roteiro do Supabase o efeito do achado 8 e a conferência do `UpdateStatus` depois do `app-subir`.