# Fluxos do n8n

## webhook-crystal-app.json

Webhook para o canal "app" da Crystal, pedido pelo Tuan em 28/09. Versão
inicial, sem depender da especificação da agência: recebe qualquer JSON,
autentica por header, responde 200 e guarda cada chamada nas execuções do n8n
(14 dias, pela limpeza automática). Quando a agência mandar o formato e o que
fazer com cada evento, é só encaixar nós depois de "Valida e normaliza".

| Endereço | Método | Auth | Responde |
|---|---|---|---|
| `https://webhook.crystalnowpp.com.br/webhook/crystal-app` | POST | header `X-Webhook-Secret` | `{ok, id, recebido_em}` 200, ou 400 se o corpo não for objeto JSON, ou 403 sem o header |
| `https://webhook.crystalnowpp.com.br/webhook/crystal-app/health` | GET | nenhuma | `{status:"ok"}` (teste de alcance) |

### Importar (2 minutos)

1. No `editor.crystalnowpp.com.br`: Credentials > Add credential > **Header Auth**.
   Name `Crystal app · X-Webhook-Secret`, Header Name `X-Webhook-Secret`,
   Value = um segredo novo (`openssl rand -hex 24` na VPS). Guardar no Bitwarden.
2. Workflows > menu **...** > **Import from URL** com a URL raw deste arquivo
   no GitHub (ou Import from File, baixando o JSON).
3. Abrir o nó "Recebe do app (POST)" e escolher a credencial criada no passo 1.
4. Salvar e **Activate** (o botão no topo). Sem ativar, só a URL de teste responde.

### Testar

```bash
curl -s https://webhook.crystalnowpp.com.br/webhook/crystal-app/health
curl -s -X POST https://webhook.crystalnowpp.com.br/webhook/crystal-app \
  -H 'X-Webhook-Secret: SEGREDO' -H 'Content-Type: application/json' \
  -d '{"type":"teste","mensagem":"oi"}'
curl -s -o /dev/null -w '%{http_code}\n' -X POST https://webhook.crystalnowpp.com.br/webhook/crystal-app \
  -H 'Content-Type: application/json' -d '{}'     # sem o header: 403
```

O que passar para a agência: a URL do POST, o nome do header e o segredo (por
canal seguro, nunca no grupo).
