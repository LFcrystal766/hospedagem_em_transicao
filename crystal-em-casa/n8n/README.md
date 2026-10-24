# Fluxos do n8n

| Arquivo | O que é | Estado |
|---|---|---|
| `compra-assiny.json` | Compra e reembolso da Assiny → Supabase (`app_compra_evento`) → API do app e e-mail de boas-vindas. **Versão de 24/10** (revisão de segurança: INT-06, 08, 09, 16, 17) | para importar (abaixo); no ar está a de 13/10 |
| `compra-assiny-conciliacao.json` | Duas vezes por dia: resumo das compras para a equipe e reenvio à API dos bloqueios da janela (INT-09) | novo, para importar |
| `erro-n8n-aviso.json` | Error Workflow dos dois acima: e-mail à equipe quando uma execução falha | novo, para importar |
| `compra-assiny-credenciais.py` | Grava as credenciais dos três fluxos e testa de ponta a ponta (compra, reembolso, forjado, repetido, imagens) | v2 (24/10) |
| `conferir-fluxos.py` | Conferência estática dos JSON desta pasta (ligações, referências, nós travados, segredo, e-mail) | novo |
| `compra-assiny-imagens.py` | Acrescentava o repasse de imagens ao fluxo de 13/10. **Só para aquela versão**; recusa mexer no fluxo de 24/10 | legado |
| `webhook-crystal-app.json` | Webhook genérico do app (28/09), guarda cada chamada nas execuções. Nada legítimo bate nele desde que o canal é o Chatwoot | dormente: desativar no editor quando o dono decidir |
| `crystal-provisoria.json` | Crystal provisória (OpenRouter) para o `bootstrap-vps.sh crystal-provisoria` | reserva |

Antes de importar ou mudar qualquer JSON: `python3 -I conferir-fluxos.py` (sai 1 se achar problema).

## compra-assiny.json (24/10): o que mudou e por quê

A Assiny **não assina** os avisos e **não tem API** para consultar uma transação (conferido em 24/10 na documentação
oficial, `docs.assiny.com`: só webhooks; a única opção de segurança no painel é "Avançado > Headers personalizados",
até 3 cabeçalhos). A defesa é em camadas, e cada camada está no fluxo ou no SQL:

```
Assiny ──POST──▶ Assiny (webhook: caminho secreto + x-crystal-token; 403 antes de executar)
  └▶ Conferir e enxugar (Code): formato, tamanhos, e-mail; corta CPF/metadata/endereço/comissões do que vai ao
     Supabase; monta o corpo exato que a API espera (com as datas da transação); saudação só com letras
       ├─ inválido ──▶ Responder 400 à Assiny (nada chega ao Supabase)
       └▶ Registrar no Supabase (app_compra_evento v3, credencial Custom Auth do papel n8n_compras)
            ├─ erro ──▶ Responder erro à Assiny (500) ──▶ Registrar falha (execução com erro + Error Workflow)
            └▶ Destino (Switch)
                 ├ boas_vindas (liberado e novo) ──▶ E-mail de boas-vindas (Resend) ──▶ Responder à Assiny
                 ├ reembolso (bloqueado) ─────────────────────────────▶ Desligar no app (reembolso) ──┐
                 ├ reembolso_repetido (repetido, anterior=bloquear) ──▶ Desligar no app (reembolso) ──┤
                 ├ imagens (ignorado/produto) ──▶ Repassar ao app (pacote de imagens) ───────────────┤
                 │                                                                      API aceitou? (2xx ou 409)
                 │                                                           sim ──▶ Responder à Assiny (200)
                 │                                                           não ──▶ Responder erro (500) ──▶ Registrar falha
                 └ nada (repetido, ignorado por outro motivo) ──▶ Responder à Assiny
```

Em relação ao fluxo de 13/10 (`b449e66`):

- **Responde à Assiny só depois** de o Supabase, a API do app e o e-mail terem terminado (INT-09). Se a API estiver
  fora, a Assiny recebe 500 e a execução fica marcada com erro; quando a Assiny reenvia, o Supabase responde
  `repetido` com `anterior = bloquear` e o fluxo repassa o bloqueio à API de novo (ela dispensa o que já fez). A
  conciliação (abaixo) cobre o que a Assiny não reenviar.
- **Corpo conferido antes de qualquer coisa** (INT-06 item 4, INT-16): `event` em minúsculas, transação e ids até 80
  caracteres, e-mail com forma de e-mail, status presente; fora disso, 400 `corpo_invalido` sem tocar no Supabase.
- **Só o necessário segue adiante** (INT-08): ao Supabase vão e-mail, nome, telefone, transação (com datas) e
  oferta; à API vão e-mail, CPF (só quando são 11 dígitos), transação com `created_at`/`updated_at` (a API recusa
  evento com mais de 24 h) e oferta. `metadata` (IP, user agent, UTM), endereço e comissões morrem no primeiro nó.
  E o fluxo **não guarda execuções com sucesso** (Settings); só as com erro ficam, para diagnóstico.
- **E-mail de boas-vindas** (INT-17): saudação só com o primeiro nome se ele for só letras (até 60); o e-mail do
  comprador não aparece no texto; `Idempotency-Key` pela transação.
- **Pacote de imagens com credencial própria** ("API imagens", `IMAGENS_WEBHOOK_SECRET`; INT-01) e **Supabase com
  Custom Auth** para caber a `apikey` + o JWT do papel `n8n_compras` (INT-07).
- **409 da API não vira erro**: é a recusa proposital de evento antigo. 401/5xx/sem resposta viram 500 + erro.

**O que fica de limite (sem API nem assinatura da Assiny):** quem tiver o caminho secreto E o token consegue mandar
um `approved_purchase` forjado com o id de um produto da lista e liberar um e-mail (e disparar o e-mail de
boas-vindas, cujo texto é fixo: o atacante só controla o primeiro nome, e só com letras). O que esse atacante NÃO
consegue mais: bloquear alguém (o Supabase só bloqueia com transação/assinatura de compra conhecida), mandar texto
livre pelo remetente oficial, estourar tamanhos, deixar dado pessoal nas execuções. Mitigações que restam: dois
segredos (caminho + cabeçalho) que só existem na Assiny, no n8n e em `/root/crystal/n8n-compras.segredos`; o resumo
duas vezes por dia com alerta de volume (`liberacoes_acima_de_100`); e, se um dia a Assiny publicar os IPs de saída,
a lista de IPs no nó Assiny ("IP(s) Allowlist") ou no Traefik. Continuam valendo, como antes, a lista fechada
`crystal_compras_produtos` e a liberação manual pelo painel (`app_aluno_corrigir_cadastro`).

### Pré-requisitos

1. **SQL:** `crystal-em-casa/supabase/app_compras_seguranca_n8n.sql` inteiro no SQL Editor (substitui o
   `app_compras_bloqueio_restrito.sql`; não precisa dos dois). Sem ele o fluxo novo não funciona direito: `anterior`
   no repetido, `app_compras_conciliacao` e o papel `n8n_compras` vêm dele. O script de credenciais confere.
2. **API do app** no ar com `REFUND_WEBHOOK_SECRET` (já tem) e, opcional, `IMAGENS_WEBHOOK_SECRET` (INT-01): o
   `bootstrap-vps.sh app-definir IMAGENS_WEBHOOK_SECRET` aceita desde 24/10 (mesma régua do reembolso: 32 bytes, 10
   caracteres distintos, e recusa igual ao do reembolso). Gerar com `openssl rand -hex 32`, colar quando ele pedir
   (nunca na linha de comando), guardar no Bitwarden e rodar `app-subir` com uma imagem que o leia (onda 1 do app,
   `d5126c0` ou mais nova); com imagem antiga a variável é ignorada e a rota de imagens continua pedindo o do
   reembolso, e aí a credencial "API imagens" daria 401 (este script pega isso no teste, antes de gravar). Sem ele o
   script usa o do reembolso para as duas rotas e avisa.
3. No Supabase, para o papel: **Settings > API Keys**: a chave **publicável** (`sb_publishable_…` ou a `anon`
   legada; é pública) e **Settings > JWT Keys > Legacy JWT secret** (o script pede os dois sem eco e não guarda o
   segredo). Se o projeto já tiver desativado o segredo legado, usar `--supabase-chave` com uma secret key só do n8n.
4. No Resend: **API Keys > Create**, permissão *Sending access*, domínio `crystalnowpp.com.br`, nome `n8n`.

### Importar (editor.crystalnowpp.com.br), 20 minutos, em hora calma, sem janela de 403

1. **Credenciais** (Credentials > Add): cinco, com estes nomes e **valor qualquer** (o script regrava):
   `Assiny · x-crystal-token` (Header Auth, Name `x-crystal-token`), `Supabase · n8n compras` (**Custom Auth**, JSON
   `{"headers":{}}`), `Resend · n8n` (Header Auth, Name `Authorization`), `API reembolso` e `API imagens` (Header Auth,
   Name `Authorization`). Pode reaproveitar `API reembolso` e a do Resend do fluxo antigo se os nomes coincidirem;
   a do Supabase tem de ser nova (tipo diferente).
2. **Error Workflow:** Workflows > Import from File > `erro-n8n-aviso.json`. No nó "E-mail à equipe (Resend)" escolher
   `Resend · n8n`; no nó "Configuração" trocar `equipe_email` pelo e-mail da equipe. Salvar. Não precisa ativar.
3. **Fluxo de compras:** Import from File > `compra-assiny.json`. Ele entra como um fluxo NOVO, ao lado do antigo,
   **inativo**. Nele:
   - em cada nó com credencial, escolher a do passo 1 (Assiny, Registrar no Supabase, E-mail, Desligar, Repassar);
   - abrir o nó **Assiny** e colar em *Path* o caminho de produção do fluxo antigo (`assiny-compras-<sufixo>`), que
     nunca fica no repositório; manter *Authentication: Header Auth*;
   - Settings do fluxo (menu ⋯ > Settings): *Error workflow* = "Crystal · aviso de erro do n8n"; conferir *Save
     successful executions: Do not save* e *Timezone: America/Sao_Paulo* (já vêm no JSON);
   - salvar (e *Publish*, se o editor mostrar o botão). Anotar o id do fluxo (está na URL do editor).
4. **Credenciais no fluxo novo, ainda inativo**, na VPS como root (as três opções só na primeira vez):
   ```bash
   cd /root/hospedagem_em_transicao/crystal-em-casa/n8n   # ou onde o repositório estiver
   python3 -I compra-assiny-credenciais.py --fluxo <id do fluxo novo> --supabase-papel --resend-chave --produto <id de crystal_compras_produtos>
   ```
   Ele pede a chave publicável, o segredo JWT e a chave do Resend sem eco; testa cada uma direto no serviço (inclusive
   que o SQL de 24/10 está aplicado e que o papel não lê tabela); grava as cinco credenciais; como o fluxo está
   inativo, pula os testes públicos e imprime o token da Assiny. O id do produto é um dos 7 de
   `crystal_compras_produtos` (`select produto_id, nome from crystal_compras_produtos;`); fica guardado.
5. **Assiny:** Integrações > Webhooks > o webhook da Crystal > *Avançado > Headers personalizados*: `x-crystal-token`
   com o valor impresso (colar também no Bitwarden). A URL não muda. O fluxo antigo ignora o cabeçalho, então nada
   quebra. Eventos: Compra aprovada, Compra reembolsada, Chargeback (e os de assinatura, se o produto tiver).
6. **Troca:** no editor, desativar o fluxo antigo e ativar o novo (o mesmo caminho não pode estar ativo em dois).
   A Assiny já manda o cabeçalho; não há 403.
7. **Teste de ponta a ponta:** `python3 -I compra-assiny-credenciais.py` (sem opções). Faz: 403 sem token, 400 com
   corpo inválido, 200 com evento de teste, compra de teste (libera, e-mail para a caixa de teste do Resend),
   reembolso **forjado** (ignorado `sem_compra_conhecida`), reembolso de verdade (bloqueado), reenvio (repetido,
   `anterior = bloquear`), pacote fora da lista (rota de imagens), e confere que nenhuma execução deu erro.
   Se a Assiny não puder mandar o cabeçalho, trocar *Authentication* do nó Assiny para *None*: fica só o caminho
   secreto, como estava de 14 a 24/10 (o script avisa e pula o teste do 403).
8. **Conciliação:** Import from File > `compra-assiny-conciliacao.json`; credenciais `Supabase · n8n compras`,
   `API reembolso`, `Resend · n8n`; `equipe_email` no nó "Configuração"; Settings > Error workflow; ativar. Para ver
   o primeiro resumo sem esperar as 06:10, *Execute workflow* uma vez (só leitura no Supabase e reenvio idempotente
   à API). Rodar `python3 -I compra-assiny-credenciais.py` de novo: agora ele enxerga os três fluxos e grava as
   mesmas credenciais nos nós da conciliação.

### O que conferir em Executions na primeira hora

- **Fluxo de compras:** a lista só mostra execuções com **erro** (as com sucesso não são guardadas). O normal é
  **vazia**. Se aparecer: nó "Registrar falha" com "API do app: HTTP 401" = segredo do reembolso/imagens diferente
  do da API (rodar `bootstrap-vps.sh app-subir` e o script de credenciais); "HTTP 5xx"/"sem resposta" = API fora
  (a conciliação reenvia); "Supabase: …" = PostgREST recusou (401/403 = credencial ou papel; 400 EMAIL_INVALIDO /
  EVENTO_INVALIDO = corpo estranho que passou pelo Code: comparar com `docs.assiny.com/webhooks/estrutura-dos-dados`).
- **Na Assiny**, Webhooks > *Logs de requisições*: os disparos reais têm de estar em **200**. **400** = o formato
  mudou (ver `campos` na resposta); **403** = o cabeçalho não está chegando (passo 5); **500** = ver Executions.
- **Uma compra real:** a aluna aparece em `crystal_compras` (`select status, liberado_em from crystal_compras order
  by criado_em desc limit 5;`) e recebe o e-mail de boas-vindas (Resend > Emails, remetente `acesso@`).
- **O resumo das 06:10/18:10** chega ao `equipe_email`: contagens por ação/evento, eventos com nome desconhecido
  (o `teste_credenciais` do script aparece aqui nos dias de teste; é esperado), reenvios à API por resultado.
  `[ATENÇÃO]` no assunto = alerta de volume, ou algum reenvio que não deu 2xx, ou um que **só agora** cortou uma
  conta (o aviso original não tinha chegado à API).
- **Aviso de erro** por e-mail a cada execução que falhar (Error Workflow). Nenhum e-mail = nenhum erro.

### Volta

1. No editor: desativar "Crystal · compra e reembolso da Assiny" (novo) e ativar o antigo, que continua lá com as
   credenciais dele. Segundos de troca; a Assiny reenvia o que cair no meio (ou *Reenviar* nos Logs). O cabeçalho a
   mais na Assiny não atrapalha o antigo.
2. Se o antigo tiver sido apagado: o JSON de 13/10 está no git, `git show b449e66:crystal-em-casa/n8n/compra-assiny.json`
   (o script de credenciais daquela versão: `git show 9f669dd:crystal-em-casa/n8n/compra-assiny-credenciais.py`).
   Importar, colar o caminho secreto, escolher credenciais Header Auth (a do Supabase antiga é Header Auth com `apikey`).
3. O SQL de 24/10 pode ficar (o fluxo antigo ignora `anterior`); para voltar a função, o cabeçalho de
   `app_compras_seguranca_n8n.sql` diz como. Conciliação e aviso de erro podem ficar ativos com qualquer versão.

## Pendente para a infra

Coisas que esta pasta precisava e que moram em `bootstrap-vps.sh`, nas stacks ou na VPS (frente de infra). Situação em
24/10, depois da branch `seguranca/infra-pendencias-n8n`:

1. **FEITO: `EXECUTIONS_DATA_MAX_AGE=48` e `EXECUTIONS_DATA_PRUNE_MAX_COUNT=5000`** (eram 336 e 10000) em
   `stacks-exemplo/04`, `05` e `06` (INT-08), linhas antigas comentadas ao lado para a volta; `STACKS_COMMIT` e a tabela
   sha256 do script atualizados. Vale na VPS no passo 5 do roteiro da madrugada (`bancos`, que sobe o n8n), e aí o n8n
   apaga em minutos tudo em Executions com mais de 2 dias, inclusive execuções antigas com erro. O
   `EXECUTIONS_DATA_SAVE_ON_SUCCESS` fica por fluxo (Settings do JSON, já `none` nos três), não no yaml: um `none`
   global tiraria da equipe a execução de teste de um fluxo feito à mão no editor.
2. **FEITO: `IMAGENS_WEBHOOK_SECRET*`** em `APP_EXTERNOS`, com a mesma régua do `REFUND_WEBHOOK_SECRET` (32 bytes, 10
   caracteres distintos) e mais uma: recusa se for igual ao do reembolso (um segredo por rota é o objetivo do INT-01).
   Caminho igual ao do reembolso: `app-definir IMAGENS_WEBHOOK_SECRET` → `.externos` → `api.env` no `app-subir`.
   Como usar: pré-requisito 2, acima. Continua opcional: sem ele a API usa o do reembolso nas duas rotas.
3. **Não é daqui: `REFUND_EVENTS` / `op_refund_events` com `charged_back`.** O `bootstrap-vps.sh` só aceita o nome em
   `app-definir` (é o valor padrão; o painel /equipe/operacao sobrepõe) e não o define em lugar nenhum, conferido com
   `grep`; a lista padrão mora no código da API (outro agente). Quando a API trouxer `charged_back` no padrão, nada
   muda aqui; até lá, `app-definir REFUND_EVENTS` com a lista acrescida ou a chave em /equipe/operacao.
4. **FEITO: backup.** `/root/crystal/n8n-compras.segredos` entra em todo backup (`--bancos`, o padrão à mão, e
   `--completo`) como `segredos_integracoes-<data>.tar.gz`, que só existe cifrado: sobe ao R2 e na VPS vira `.age` na
   mesma rodada; `backup-link segredos_integracoes` baixa o mais novo. Correção do que este item supunha: o
   `.externos` **não** estava no backup, e os `.segredos` (chaves que abrem os dumps) também não, de propósito; os dois
   continuam fora (README de `crystal-em-casa`, "Backup fora da VPS", explica e diz como incluir o `.externos`).
5. **Ação do dono, depois da troca:** apagar no editor a credencial Header Auth antiga do Supabase (ela guarda a
   `service_role`) e fazer a rotação da `service_role` que o INF-02 já pede; o n8n não precisa mais dela.
6. **Opcional, ação do dono (INT-06 item 2):** uma semana de log de acesso do Traefik em `webhook.` para ver de quais
   IPs a Assiny dispara; se forem poucos e estáveis, restringir `/webhook/assiny-compras*` a eles (middleware
   `ipAllowList`) e/ou preencher "IP(s) Allowlist" no nó Assiny.

## webhook-crystal-app.json (28/09, dormente)

Webhook pedido pelo Tuan para o canal "app"; recebe qualquer JSON, autentica por header `X-Webhook-Secret`, responde
200 e guarda a chamada nas execuções. Desde que o canal do app é o Chatwoot, nada legítimo bate nele; desativar no
editor quando o dono decidir (quem tiver o segredo consegue encher as execuções do n8n com qualquer coisa).

| Endereço | Método | Auth | Responde |
|---|---|---|---|
| `https://webhook.crystalnowpp.com.br/webhook/crystal-app` | POST | header `X-Webhook-Secret` | `{ok, id, recebido_em}` 200, ou 400 se o corpo não for objeto JSON, ou 403 sem o header |
| `https://webhook.crystalnowpp.com.br/webhook/crystal-app/health` | GET | nenhuma | `{status:"ok"}` |
