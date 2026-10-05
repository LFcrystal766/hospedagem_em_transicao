# Publicar o PRD de Otimização na VPS

Três releases, nesta ordem, cada um com `backup` antes e teste em aparelho depois.
Tudo que não é comando na VPS já está feito: código integrado, testes verdes,
imagens construídas. Este roteiro é só o que o Luiz roda e confere.

| Release | Branch | Commit no `crystal-web-chat` | Tag da imagem |
|---|---|---|---|
| 1 · Base e segurança | `otimizacao/etapa-1` | `79ba6b7` (hotfix do guard https sobre `cdc45f5`) | `sha-79ba6b7` |
| 2 · Início e perfil | `otimizacao/etapa-2` | `69ef26c` | `sha-69ef26c` |
| 3 · Conversa e visual | `otimizacao/etapa-3` | `8ed9ce8` (`da617ac` + ajustes pós-QA) | `sha-8ed9ce8` |

Aprendido em 05/10, na primeira tentativa da etapa 1: a API nova recusou
`CRYSTAL_API_URL=http://app_crystal:8080` (guard de https em produção), morreu na
subida e o Swarm voltou sozinho para a imagem anterior, deixando web novo com API
velha. O guard passou a aceitar http só para host interno do Docker (sem ponto), e o
`app-subir` agora confere a tag de cada serviço e mostra o log do contêiner que
morreu. Se isso acontecer de novo: `app-subir <tag anterior>` e mandar o log.

Regras que valem nos três:

- **Um comando por vez**, no console web da Hostinger, e esperar o `ok`.
- `<commit>` nas URLs é o commit **deste** repositório (`git log -1` na branch
  `claude/gracious-shannon-6x9l5j`). Nunca `curl | bash`: baixar, depois rodar.
- Migrações do banco rodam sozinhas na subida da API (serviço `migrate` da stack). São
  aditivas; a volta de imagem não precisa de volta de banco. A exceção é a etapa 2, que
  apaga a tabela `onboarding_states` (vazia no nosso uso): o `backup` antes cobre.
- Volta de qualquer release: `bash bootstrap-vps.sh app-subir <tag anterior>`.
- Segredos só pelo `app-definir`, que pergunta sem eco. Nunca na linha de comando.

## Antes do release 1 (uma vez)

Fora da VPS:

1. **Groq**: criar a chave em console.groq.com (conta com 2FA), limite de gasto baixo.
   Guardar no Bitwarden.
2. **Segredo do reembolso**: `openssl rand -hex 32` no Mac. Guardar no Bitwarden.
3. **Assiny**: webhook com URL `https://api.crystalnowpp.com.br/webhooks/reembolso`,
   cabeçalho `Authorization: Bearer <segredo do passo 2>`, eventos de reembolso,
   chargeback e cancelamento, todos os produtos. Pedir à Assiny um exemplo do JSON
   (mascarado) e mandar para a sessão: o parser ainda é suposição até isso chegar.
4. Dois aparelhos à mão: iPhone (Safari e app instalado) e Android (Chrome).

Na VPS:

```bash
curl -fsSL https://raw.githubusercontent.com/LFcrystal766/hospedagem_em_transicao/<commit>/crystal-em-casa/bootstrap-vps.sh -o bootstrap-vps.sh
bash bootstrap-vps.sh app-definir REFUND_WEBHOOK_SECRET   # cola o segredo do passo 2
bash bootstrap-vps.sh app-definir TRANSCRIPTION_API_KEY   # cola a chave da Groq
bash bootstrap-vps.sh app-status                          # anotar a tag atual (volta)
```

## Release 1 · etapa 1 (`sha-79ba6b7`)

```bash
bash bootstrap-vps.sh backup
bash bootstrap-vps.sh app-subir sha-79ba6b7
bash bootstrap-vps.sh app-status
```

Conferir em aparelho (iPhone e Android):

- [ ] Entrar: código por e-mail chega, sessão fica depois de fechar e abrir o app.
- [ ] Modo avião: tela "sem conexão" aparece; volta sozinha com rede.
- [ ] Áudio: gravar 5 s e enviar; a bolha mostra a transcrição em alguns segundos.
- [ ] Foto: enviar uma foto; a Crystal comenta o conteúdo.
- [ ] Termos: o nome do DPO e o e-mail aparecem na política.
- [ ] Equipe: `/equipe/crystal` abre com a foto da Crystal.
- [ ] Reembolso (só com o JSON da Assiny): evento de teste bloqueia a conta certa.

Se a transcrição falhar, a vigia mostra `transcricao` nos logs da API; a resposta
fixa "não consegui ouvir" aparece para o aluno e o resto do app segue.

## Release 2 · etapa 2 (`sha-69ef26c`)

```bash
bash bootstrap-vps.sh app-remover CRYSTAL_ONBOARDING_URL   # a etapa 2 não usa mais
bash bootstrap-vps.sh backup
bash bootstrap-vps.sh app-subir sha-69ef26c
bash bootstrap-vps.sh app-status
```

Conferir em aparelho:

- [ ] Tela inicial `/` com os cards; contato da Crystal na lista.
- [ ] Aluno novo: o chat fica travado até o perfil completo; depois libera na hora.
- [ ] Foto do aluno: trocar e ver no menu.
- [ ] Menu: tutorial roda uma vez só; "Excluir conta" pede `EXCLUIR` e apaga.
- [ ] Banner "instalar": aparece no Android, soma no iPhone (orientação de "Adicionar à tela").
- [ ] Equipe: `/equipe/avisos` manda um aviso de teste; chega no aparelho.
- [ ] Cards de suporte abrem o WhatsApp e o e-mail certos.

## Release 3 · etapa 3 (`sha-da617ac`)

```bash
bash bootstrap-vps.sh backup
bash bootstrap-vps.sh app-subir sha-da617ac
bash bootstrap-vps.sh app-status
```

Conferir em aparelho (roteiros completos em `docs/otimizacao/pedidos-e3-*.md` do
`crystal-web-chat`):

- [ ] Visual: papel de parede só atrás das bolhas; tema claro/escuro/sistema troca na
  hora; comparar lado a lado com o WhatsApp no iPhone, nos dois modos.
- [ ] Topo: foto da Crystal, "online", sem CPF; deitado também.
- [ ] Conversa: relógio, um tique, dois cinza, dois azuis; resposta em 2 a 4 bolhas com
  "digitando…"; derrubar a rede no meio mostra "Tentar de novo" sem repetir a pergunta.
- [ ] Áudio: tocador com onda; áudio antigo toca sem "NaN"; gravar por toque com onda ao
  vivo; iPhone logo depois de gravar toca no alto-falante.
- [ ] **Segurar para gravar** (decide se fica): segurar 3 s e soltar envia; arrastar para a
  esquerda cancela; tela não rola nem seleciona texto; toque curto abre o painel.
  Reprovou em um dos dois aparelhos: `SEGURAR_PARA_GRAVAR = false` em
  `apps/web/components/chat/Composer.tsx`, imagem nova, `app-subir`. O resto fica.
- [ ] Equipe: `/equipe/crystal` ajusta o ritmo das bolhas e vale na próxima resposta.

## Ajustes pós-QA (05/10, depois do iPhone aprovar)

Dois pedidos do Luiz entraram na imagem `sha-8ed9ce8`: a pílula "Manda o print" saiu
(imagem só pelo ícone de clipe à direita do campo, como no WhatsApp) e a folha de
notificações fecha sozinha 1,5 s depois do "Pronto!", com botão Fechar. Subida:
`backup` e `app-subir sha-8ed9ce8`. Conferir: ícone de clipe no lugar da pílula;
ativar notificações no menu e ver a folha sumir.

## Depois dos três (sem pressa, qualquer ordem)

- **Nosso Chatwoot**: `crystal-em-casa/README.md`, seção "Ligar o nosso Chatwoot".
  Precisa antes do DNS `atendimento` cinza. `app-canal chatwoot` só depois do teste da
  Crystal respondendo lá. Quem atende é a equipe de suporte (decisão de 05/10). Não
  definir `CHATWOOT_API_TOKEN`: excluir conta não apaga o contato no Chatwoot.
- **Vigia**: `bash bootstrap-vps.sh vigia-config` se ainda não estiver ligada.
- **Alma da Crystal**: prompt e base de conhecimento da agência, quando chegarem.
