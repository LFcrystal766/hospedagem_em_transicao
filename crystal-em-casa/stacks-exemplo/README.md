# Stacks de exemplo

Arquivos prontos para subir a infraestrutura base e o n8n em uma VPS com Docker
Swarm. São exemplos comentados: cada arquivo diz, no topo, o que ele faz, o que
precisa ser trocado e como subir.

Nenhum arquivo contém senha, endereço ou chave de verdade. Tudo que precisa do
seu valor está escrito em MAIÚSCULAS ou como `seudominio.com.br`.

---

## Ordem de instalação

A ordem importa: cada serviço depende do anterior estar no ar.

| # | Arquivo | O que é | Obrigatório |
|---|---|---|---|
| 00 | `00-traefik.yaml` | Proxy reverso e certificados HTTPS | Sim |
| 01 | `01-portainer.yaml` | Painel visual para operar o Swarm | Não, mas recomendado |
| 02 | `02-n8n-postgres.yaml` | Banco interno do n8n | Sim |
| 03 | `03-n8n-redis.yaml` | Fila do n8n | Sim |
| 04 | `04-n8n-editor.yaml` | Interface do n8n | Sim |
| 05 | `05-n8n-webhook.yaml` | Recebe as chamadas externas | Sim |
| 06 | `06-n8n-worker.yaml` | Executa os fluxos | Sim |
| 07 | `07-n8n-mcp.yaml` | Servidor MCP | Não. Só se for usar |

---

## Antes de começar

### 1. Preparar a VPS

Com o Docker instalado, iniciar o modo Swarm:

```
docker swarm init
```

### 2. Criar a rede

Uma única rede compartilhada, em que o Traefik enxerga todos os serviços:

```
docker network create --driver=overlay network_swarm_public
```

### 3. Criar os volumes

São onde os dados sobrevivem a um reinício ou a uma atualização de contêiner:

```
docker volume create volume_swarm_certificates
docker volume create portainer_data
docker volume create n8n_postgres_data
docker volume create n8n_redis_data
```

### 4. Marcar o nó que vai receber o n8n

Os serviços do n8n são presos a um nó específico, porque usam volumes locais.
Descubra o nome do nó e aplique o rótulo:

```
docker node ls
docker node update --label-add app=n8n NOME_DO_NO
```

Em uma VPS única, o nome do nó costuma ser o próprio hostname da máquina.

### 5. Apontar o DNS

Antes de subir qualquer coisa com endereço público, os nomes precisam já estar
apontando para o IP da VPS. Se o DNS não estiver pronto, o certificado HTTPS
falha e o serviço sobe inacessível.

| Nome | Aponta para | Usado por |
|---|---|---|
| `painel.seudominio.com.br` | IP da VPS | Portainer |
| `editor.seudominio.com.br` | IP da VPS | Editor do n8n |
| `webhook.seudominio.com.br` | IP da VPS | Webhooks do n8n |

Você pode usar os nomes que quiser. Só precisa trocar nos arquivos.

---

## O que trocar nos arquivos

| Valor a trocar | Onde aparece | O que colocar |
|---|---|---|
| `SEU_EMAIL_AQUI` | 00 | Um e-mail seu, válido. Recebe avisos de certificado |
| `SUBSTITUA_PELA_SENHA_DO_BANCO` | 02, 04, 05, 06, 07 | Uma senha forte. **A mesma nos cinco arquivos** |
| `SUBSTITUA_PELA_CHAVE_DE_CRIPTOGRAFIA` | 04, 05, 06, 07 | 32 caracteres aleatórios. **A mesma nos quatro** |
| `painel.seudominio.com.br` | 01 | Endereço do painel |
| `editor.seudominio.com.br` | 04, 05, 06, 07 | Endereço do editor |
| `webhook.seudominio.com.br` | 04, 05, 06, 07 | Endereço dos webhooks |
| `SUBSTITUA_PELO_USUARIO_SMTP` e afins | 04 | Só se for ativar envio de e-mail |

### Duas coisas que precisam ser idênticas entre arquivos

**A senha do banco.** Se divergir, o serviço não conecta e reinicia em looping.

**A chave de criptografia.** Se divergir, os serviços não conseguem ler as
credenciais salvos uns pelos outros, e o sintoma é confuso: o fluxo funciona no
editor e falha no worker.

---

## Subindo

Um comando por arquivo, na ordem:

```
docker stack deploy -c 00-traefik.yaml        traefik
docker stack deploy -c 01-portainer.yaml      portainer
docker stack deploy -c 02-n8n-postgres.yaml   n8n_postgres
docker stack deploy -c 03-n8n-redis.yaml      n8n_redis
docker stack deploy -c 04-n8n-editor.yaml     n8n_editor
docker stack deploy -c 05-n8n-webhook.yaml    n8n_webhook
docker stack deploy -c 06-n8n-worker.yaml     n8n_worker
```

O último nome de cada linha é o nome da stack. **Ele importa**: os serviços se
encontram na rede por esse nome. Se você mudar `n8n_postgres` para outra coisa,
precisa mudar também o `DB_POSTGRESDB_HOST` nos arquivos do n8n.

Depois de cada comando, acompanhe até o serviço ficar saudável:

```
docker service ls
```

---

## Guardar em cofre de senhas

Três coisas, e a segunda é a mais importante:

1. **Senha do banco**
2. **Chave de criptografia do n8n**, separada do backup do banco. Um backup sem
   a chave não restaura as credenciais.
3. **Senha do administrador do Portainer**

---

## Consumo de recursos

Os limites de CPU e memória em cada arquivo são **teto, não reserva**: cada
serviço consome só o que precisa. Somando os tetos dos sete serviços, o total
cabe dentro de uma máquina de 16 GB, com folga para o sistema.

| Serviço | CPU | Memória | Heap do Node |
|---|---|---|---|
| Traefik | sem limite | sem limite | |
| Portainer | sem limite | sem limite | |
| Postgres do n8n | 2 | 2 GB | |
| Redis do n8n | 1 | 1 GB | |
| Editor | 2 | 3 GB | 2304 MB |
| Webhook | 2 | 2 GB | 1536 MB |
| Worker | 2 | 4 GB | 3072 MB |
| **Soma** | | **12 GB** | |

Os tamanhos são diferentes porque o trabalho é diferente. O worker é o maior
porque executa 50 fluxos ao mesmo tempo. O webhook é o menor porque só recebe a
chamada e enfileira. O editor fica no meio, porque abrir um fluxo grande na
interface consome memória.

Se a mesma máquina também hospedar o agente da Crystal, some cerca de 2,5 GB de
teto, chegando a **14,5 GB**, o que cabe em uma máquina de 16 GB com folga para
o sistema.

### A regra da memória do n8n

Em cada serviço do n8n, o `NODE_OPTIONS` fica em torno de **75%** do limite de
memória do contêiner, como na tabela acima. Essa diferença é proposital.

O Node.js consome mais que o limite configurado ali, porque além da memória de
trabalho ele carrega o código, os buffers e os dados em trânsito. Se os dois
números forem iguais, o sistema encerra o processo antes que o Node.js tenha
chance de liberar memória, e o serviço passa a reiniciar sozinho de tempos em
tempos, sem erro claro no registro.

**Ao mudar um, mude o outro.** Mantenha o `NODE_OPTIONS` em torno de 75% do
limite do contêiner.

---

## Crescer a capacidade

O único serviço que precisa crescer é o **worker**, e a ordem importa.

**Primeiro, aumente a concorrência** no `06-n8n-worker.yaml`, na linha
`command: worker --concurrency=50`. Custa apenas a memória das execuções extras,
dentro do processo que já existe.

**Só depois suba réplica**, e ao subir, **reduza a concorrência na mesma
proporção**. A carga simultânea real é réplicas multiplicadas pela concorrência:

| Configuração | Execuções ao mesmo tempo |
|---|---|
| 1 worker × 50 | 50 |
| 2 workers × 50 | 100, o dobro sem ninguém ter mexido no número |
| 2 workers × 25 | 50, a mesma carga distribuída |

Quem aperta primeiro quando esse número cresce demais não é a CPU nem a memória
da máquina: é o **limite de conexões do banco**. E o sintoma aparece como falha
intermitente de fluxo, não como servidor cheio.
