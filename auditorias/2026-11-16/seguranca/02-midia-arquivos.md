# Revisão de segurança 16/11/2026 · 02 · Mídia, arquivos, avisos e notificações

**Alvo:** `crystal-web-chat`, branch `painel/dossies-senha`, commit `2e2e745f` (o que está no ar), em `/home/user/cw-junta`.
**Recorte:** o que mudou depois de `3c343df` (revisão de 24/10) em mídia dos avisos, visualização única, ffmpeg, upload
do cliente, vídeo de 48 h, pacote de imagens e o webhook dele, exclusão de público, push e service worker.
**Como foi feito:** leitura do código e do `git diff 3c343df..HEAD` dos arquivos da frente; três testes existentes
rodados isolados (`notices-unica`, `notices-midia`, `aviso-audio`: 62 testes, todos passam); um arquivo de prova
temporário com 3 testes (trechos no fim), apagado depois. Nada de produção foi tocado. Nenhum segredo nem dado de cliente aqui.

## Resultado em uma linha

**Nada crítico nem alto.** O controle de acesso da mídia e a visualização única estão bem feitos e bem testados.
Achei 1 ponto médio (o vídeo sai como chegou, com os metadados de quem gravou) e 6 baixos (sobras de arquivo,
cache, endurecimento do ffmpeg, webhook de imagens, texto na tela bloqueada).

Contagem: crítico 0 · alto 0 · médio 1 · baixo 6.

## Tabela de achados

| ID | Gravidade | Risco em uma frase | Evidência | Como explorar | Correção proposta | Confiança |
|---|---|---|---|---|---|---|
| **M-01** | **médio** | O vídeo do aviso é aceito só pelos 12 primeiros bytes e servido como chegou: a localização e o aparelho de quem gravou vão dentro do arquivo para todo cliente que recebe, e qualquer conteúdo com `ftyp` passa por "vídeo". | `apps/api/src/routes/notices-video.ts:163-175` (só `ftyp`; capa só pelos primeiros bytes e `rename`); `routes/uploads.ts:84-87`; `notices-video.ts:254` (serve o arquivo do disco); `routes/staff-notices.ts:261-268` (ffprobe só na visualização única, e só mede a duração); `apps/web/lib/video-aviso.ts:191-198` (o painel manda o original). Comparar: imagem refeita em `services/aviso-imagem.ts:22-33`, áudio sem metadados em `services/aviso-audio.ts:122-129`. O teste da casa aceita 88 bytes de zeros com `ftyp`: `notices-video.test.ts:87,148`. | 1) Alguém da equipe grava no Android com a localização ligada e anexa o MP4. 2) O envio sai para N clientes. 3) Qualquer cliente pede `GET /me/notices/<id>/video` com a própria sessão e lê coordenadas e modelo do aparelho (`ffprobe` ou `strings`). Variante: conta de suporte tomada manda a um cliente um arquivo qualquer com cabeçalho `ftyp`. | No upload, na mesma fila do áudio: `ffprobe` com formato forçado (uma faixa de vídeo H.264, no máximo uma de áudio AAC; duração e medidas lidas no servidor) e remux sem recodificar: `ffmpeg -f mp4 -protocol_whitelist file -i <entrada> -map 0:v:0 -map 0:a:0? -c copy -map_metadata -1 -map_chapters -1 -movflags +faststart -f mp4 <saída>`. Guardar só a saída. Capa: passar pelo `tratarImagem` (sharp), como a imagem. | Confirmado por teste (prova A) |
| **M-02** | baixo | A mídia comum do aviso sai com cache de 1 ano e `immutable`: o vídeo "de 48 h" e as fotos continuam no navegador, e sair da conta ou perder o acesso não tira. | `notices-video.ts:40-43,254`; `notices-video.test.ts:755`. Comparar: a mídia do próprio cliente fica 1 h (`routes/uploads.ts:240`). | 1) A cliente abre a conversa e o vídeo toca. 2) Passam as 48 h, ou ela sai da conta, ou o acesso é cortado. 3) No mesmo navegador, o endereço `…/me/notices/<id>/video?v=<id>` devolve o arquivo do cache, sem pedido ao servidor (`immutable` não revalida). | `Cache-Control: private, no-cache` com `ETag` (o navegador revalida, a API confere sessão e validade e responde 304), ou no máximo `private, max-age=3600`. Nunca um prazo de cache maior que a validade do arquivo. | Confirmado lendo o código; cabeçalho conferido na prova A. O efeito no navegador é o comportamento padrão do `immutable` (não testei em aparelho) |
| **M-03** | baixo | Rascunho com mídia nunca vence: a cópia do "Reenviar para quem não abriu" que ficou em rascunho segura o vídeo "de 48 h" (ou a visualização única) no disco para sempre; rascunho descartado guarda a imagem por 90 dias. | `services/aviso-midia.ts:141-146` (rascunho: sem validade) e `:175-181` (arquivo usado por aviso "vigente" não sai); `services/retention.ts:190-193` (órfão é só o que nenhum aviso usa); `routes/staff-notices.ts:1166-1193` (a cópia leva o mesmo arquivo); descarte: `staff-notices.ts:1129` + `aviso-midia.ts:143-144`. Não há limpeza de rascunho em `retention.ts`. | Não é ataque, é sobra: 1) admin envia vídeo ou visualização única; 2) clica "Reenviar para quem não abriu" e não envia a cópia; 3) meses depois o arquivo continua em `/app/uploads` e abre em `/staff/notices/<rascunho>/video` para quem criou. | Rascunho com mídia vence (ex.: 30 dias sem edição: perde a mídia ou é descartado); rascunho descartado (`canceled` sem `started_at`) libera o arquivo na hora; o detalhe do envio avisa quando um rascunho segura o arquivo. | Confirmado por teste (prova B) |
| **M-04** | baixo | O que "saiu" do app (vídeo depois de 48 h, visualização única já aberta, mídia de conta excluída) continua nas cópias de segurança do volume: 14 dias na VPS e 30 dias ou mais no R2. | `crystal-em-casa/bootstrap-vps.sh:1189-1195` (tar de `app_uploads`, nas rodadas completas), `:1234-1236` (14 dias), `:1335` (trava de 30 dias); `crystal-em-casa/publicar-video-login.md:39-42` ("entra no backup" e "48 horas depois… apaga"). | Quem tem root na VPS, ou a chave `age` e o R2, extrai o tar e lê o arquivo que o painel diz que saiu. | Decidir e escrever: ou os `aviso__*` ficam fora do tar (`--exclude='aviso__*'`; a equipe pode reenviar), ou o painel e o roteiro dizem "até 30 dias nas cópias de segurança". Registrar esse prazo no procedimento de exclusão LGPD. | Suspeita a confirmar na VPS (não acessei produção; o `CLAUDE.md` diz que o backup à mão hoje é só dos bancos) |
| **M-05** | baixo | O ffmpeg/ffprobe lê arquivo de fora com o ambiente inteiro da API (banco, chave de cifra, sal do CPF), sem teto de memória, com versão solta na imagem. | `services/aviso-audio.ts:43-47,91-95,131` (`execFile` sem `env`); `apps/api/Dockerfile:9` (`apk add ffmpeg` sem versão); `routes/staff-notices.ts:262` (`sondarVideo` fora da fila); `routes/notices-midia.ts:42` (qualquer papel da área Mensagens aciona). | 1) Conta de suporte ou técnico (ou tomada) envia um áudio feito para explorar uma falha conhecida do ffmpeg da imagem. 2) O processo filho já tem os segredos no ambiente, lê `/app/uploads` e alcança a rede interna. 3) Lê e manda para fora. | `env: { PATH: process.env.PATH }` nas três chamadas; `-max_alloc` (ex.: 256 MB) e `-threads 1` também no ffprobe e nos picos; `sondarVideo` dentro da `filaDeMidia`; gravar a versão do ffmpeg em cada build (ou prender). Depois: serviço só de mídia, sem segredos e sem rede. | Ambiente herdado: confirmado por teste (prova D). A exploração depende de uma falha do ffmpeg: não demonstrada |
| **M-06** | baixo | O webhook de imagens não tem teto para pedidos com o segredo certo (o de reembolso tem): com o token vazado, alguém credita pacotes a qualquer e-mail sem freio e põe bolhas "da Crystal" na conversa. | `routes/imagens-webhook.ts:35-44` (só o balde do segredo errado) × `routes/refund-webhook.ts:152,160`; `app.ts:208-209` (sem `IMAGENS_WEBHOOK_SECRET`, vale o do reembolso); `refund-webhook.ts:45-48` (evento sem data é aceito); `services/imagens-compra.ts:100-140`. | 1) Obter o Bearer (n8n, `.externos`, log). 2) Repetir `approved_purchase` de um produto de pacote com `transaction.id` inventado e o e-mail de um cliente. 3) Cada chamada soma N imagens (custo de leitura) e grava uma bolha na conversa; e-mail sem conta cria linha pendente, sem teto. | O mesmo `validLimit` por IP do reembolso e um teto diário de créditos com alerta; exigir o segredo próprio (não cair no do reembolso). A correção de fundo continua sendo a INT-01 (HMAC com data). | Confirmado lendo o código |
| **M-07** | baixo | Texto pessoal na tela bloqueada: o push do ticket leva o assunto que a cliente escreveu; e a visualização única leva título e legenda se o admin não marcar "sensível". | `services/tickets.ts:312-316`; `packages/shared/src/notices.ts:798-802`; `services/notices.ts:555`. | 1) A cliente abre um ticket com assunto pessoal. 2) O suporte responde. 3) O assunto aparece na tela bloqueada (e passa legível pelo FCM/APNs no app nativo). | Push do ticket com texto fixo ("O suporte respondeu. Toque para ver."), como já é na conversa (`AVISO_NATIVO_PRIVADO`, `services/push.ts:8,128`); `view_once` força o push genérico. | Confirmado lendo o código. O do ticket já existia em 24/10 e não foi apontado; o da visualização única é novo |

## Respostas às perguntas

**1. Um cliente vê mídia ou aviso de outro trocando o id? E a equipe?** Não.
- Cliente: `/me/notices/:id/video|capa|midia` exige a entrega `sent` do próprio (`notices-video.ts:250-252`); `/unica`
  exige a entrega e a janela (`:276-278`); `abrir`, `fechar`, `opened`, `ouviu`, `clicked` idem
  (`routes/me-notices.ts:28-29,38-39,58-68,80-83,90-91`); oferta de imagens só do dono
  (`routes/me-imagens-ofertas.ts:31,55,64`); `/uploads/:name` pelo prefixo do dono (`uploads.ts:209-216`).
  Toda recusa é 404.
- Equipe (`services/aviso-video.ts:20-29`): área Mensagens; rascunho só do autor; lembrete e disparo por dor só admin;
  visualização única só admin, com auditoria (`notices-video.ts:246-248`). Quem não é admin recebe o DTO sem
  endereço nem medidas (`staff-notices.ts:409-410`). Na ficha, só o aviso que a pessoa lê ganha endereço
  (`staff-alunos-ficha.ts:432-435`).
- Observação (não é achado): a mídia comum de qualquer envio já saído, inclusive para um cliente só, abre para
  suporte e técnico. É a matriz atual, igual à do texto.

**2. Visualização única abre mais de uma vez?** Não, fora da janela.
- A abertura é gravada uma vez, num comando só com `FOR UPDATE` (`db/prisma-notices.ts:394-417`). A janela é decidida no
  servidor: 2 min para foto; duração + 2 min para áudio e vídeo, vídeo com teto de 15 min (`services/aviso-midia.ts:184-210`).
  A duração do vídeo é medida pelo ffprobe, não a que o navegador informa (`staff-notices.ts:261-268`).
- Depois de `fechar` ou do fim da janela: 404 em `/unica` e em `abrir` (`me-notices.ts:64-68`, `notices-video.ts:278`).
- Segundo aparelho: só dentro da mesma janela (recebe o mesmo `fecha_em`). Outro `?v=`: não entra na busca. Range: aceito,
  só dentro da janela.
- Cache: `no-store` (`notices-video.ts:43`). O service worker não toca em nada da API (`apps/web/public/sw.js:62-72`).
- Sem sessão não abre; não há pasta servida de forma estática. `/me/.../video|capa|midia` de visualização única dá 404
  ao cliente (`notices-video.ts:246-247`). O mesmo arquivo não serve a um aviso comum (`staff-notices.ts:233-237`).
- Dentro da janela a cliente pode baixar o arquivo com a própria sessão quantas vezes quiser (120 por minuto). É o
  esperado. O painel não promete mais do que entrega: "Print da tela não dá para travar: não mande o que não pode vazar"
  (`apps/web/lib/microcopy-equipe.ts:582`). O que o texto não diz: M-03 (rascunho) e M-04 (backup).

**3. Upload: tipo pelo conteúdo? HTML/SVG executável? Traversal? Memória?**
- Tipo pelos primeiros bytes em todas as rotas (`uploads.ts:62-91,180`; `notices-midia.ts:102,117`). Imagem e áudio do
  aviso são refeitos (sharp, ffmpeg). **O vídeo não** (M-01). O MP3 do cliente tem assinatura fraca (2 bytes), sem efeito
  prático.
- HTML e SVG não entram: lista fechada de tipos, extensão dada pelo servidor. Toda resposta leva `nosniff` e
  `Content-Security-Policy: default-src 'none'` (`app.ts:134-143`; `nosniff` conferido na prova A). Não há
  `Content-Disposition` (a mídia é embutida pelo app); com os dois cabeçalhos acima, não vejo risco.
- Nome do arquivo sempre do servidor (`<id>__<uuid>.<ext>` e `aviso__<uuid>.<ext>`), conferido por regex antes do `join`
  (`uploads.ts:51,201-203`; `aviso-midia.ts:27`; `aviso-video.ts:13`; `packages/shared/src/schemas.ts:203-205`).
- Memória: o upload do cliente lê até 10 MB na memória antes de recusar (`app.ts:144`, `uploads.ts:169`), com 10 por
  minuto por sessão e 200 por dia. Os da equipe gravam em partes no disco e cortam no teto
  (`notices-video.ts:109-133`, `notices-midia.ts:61-84`).

**4. ffmpeg.** Só a equipe aciona (área Mensagens: admin, suporte e técnico; 10 por hora e 30 por dia por pessoa,
`notices-video.ts:31-35`). O cliente nunca.
- Caminho dado pelo servidor; argumentos fixos; `-f <formato>` forçado pelos primeiros bytes e `-protocol_whitelist file`
  (`aviso-audio.ts:45,93,123`). Com o formato forçado, concat e HLS não são escolhidos; a referência externa do MP4
  (`enable_drefs`) é desligada por padrão no ffmpeg.
- Tempo: 20 s na sonda e 60 s em cada etapa, com `SIGKILL` (`aviso-audio.ts:13-14,46,94,131`). Um arquivo por vez
  (`services/fila-midia.ts`). Corte em 301 s e duração conferida pelas amostras decodificadas.
- Temporários: o bruto sai sempre (`aviso-audio.ts:138-140`), a saída sai em falha, e o que sobrar de uma queda sai em
  48 h (`retention.ts:26-30,190-193`).
- Falta: ambiente limpo, teto de memória e versão anotada (M-05).

**5. Webhook de imagens.** Sem mudança desde 24/10.
- Segredo comparado em tempo constante (`routes/refund-webhook.ts:61-66`, `lib/crypto.ts:48-50`).
- Repetição: `compra:<transação>` e `estorno:<transação>` são únicos no banco (`imagens-compra.ts:74-85,100-104`);
  evento com data de mais de 24 h é recusado, mas a data vem no corpo, que não é assinado, e evento sem data passa.
- Token vazado: ver M-06. A INT-01 e a INT-13 seguem abertas por decisão.

**6. Push.**
- Registrar o aparelho para receber de outra conta: não. A inscrição e o token são sempre gravados na conta da sessão
  (`routes/push.ts:22,60-66`). Registrar o token de outra pessoa na própria conta só tira o aviso dela, e exige conhecer
  o token (a API só mostra os 6 últimos caracteres).
- Conteúdo: a resposta da Crystal vai com texto genérico (`services/push.ts:128-134`). O aviso da equipe leva título e
  140 caracteres, ou o genérico se "sensível". Ver M-07.
- URL do toque: vem do payload, que só o nosso servidor consegue enviar. Hoje todos os chamadores mandam caminho do app
  (`/chat`, `/suporte/<id>`, `/ir/<id>`: `services/notices.ts:196-199`). A página só aceita caminho do app
  (`apps/web/lib/native-push.ts:66-69,81-94,102-114`), inclusive o pedido guardado no Cache Storage (vale 2 minutos).
  O service worker ainda abriria um `https://` externo se o servidor mandasse (desenho do S27); nenhum chamador manda.

**7. Exclusão e retenção.**
- "Exclusão" aqui é a exclusão de público (quem não recebe), só admin: `staff-notices.ts:158-167,489-506`. Não existe
  rota que apague um envio.
- Vídeo: 48 h depois do fim do envio a rota dá 404 mesmo que o arquivo exista (`notices-video.ts:245`) e a rodada de
  hora em hora apaga vídeo e capa (`retention.ts:97-99,205-221`). Visualização única: 14 dias, ou assim que todas
  abriram e a última janela fechou (`aviso-midia.ts:164-168`).
- Sobras: M-02 (cache do navegador), M-03 (rascunho) e M-04 (backup).

**8. SSRF.** Nenhuma busca nova de URL fornecida por usuário ou equipe nesta frente. Upload só por multipart. O link do
checkout e o link do botão só são devolvidos ao app, nunca acessados pela API. Push só para os serviços conhecidos
(`packages/shared/src/push-endpoints.ts:33-46`). O robô do Chatwoot não baixa anexos.

## Conferido e ok

- Isolamento entre clientes em todas as rotas de mídia e de aviso (pergunta 1), coberto por testes da casa
  (`notices-video.test.ts:824,868`; `notices-unica.test.ts:256-365`).
- Visualização única no servidor (pergunta 2), inclusive a troca do mesmo arquivo entre aviso comum e único e o
  rebaixamento de papel de quem criou.
- Imagem do aviso: refeita pelo sharp, sem EXIF, teto de 50 milhões de pontos (`aviso-imagem.ts`), uma por vez.
- Áudio do aviso: formato forçado, uma faixa só, sem metadados, capítulos nem capa.
- Envio de arquivo pela equipe: preso a quem enviou no KV por 24 h (`aviso-midia.ts:92-93`, `aviso-video.ts:102-103`);
  suporte não usa o arquivo do admin.
- Cabeçalhos: `nosniff` e CSP em tudo; `no-store` na visualização única, na mídia aberta pela equipe e nas rotas de
  imagens.
- Service worker: só guarda a casca do app; nada da API nem de mídia. `self.__crystalTratarToque` (`sw.js:212`) é um
  gancho de teste que ficou em produção: inofensivo, pode sair.
- Fila sem internet do app (`apps/web/lib/offline-media.ts`): só a mídia que a própria cliente tentou enviar, por conta,
  apagada ao sair.
- Pacote de imagens: oferta só do dono; link do checkout só `https://` e só admin edita
  (`packages/shared/src/settings.ts:570-583`); compras paradas e funil só admin; entrega manual auditada.
- Exclusão de público: só admin; quem não é admin vê só a contagem (`staff-notices.ts:400-404`). Observação: a rota
  da lista devolve os índices reconhecidos (`services/notices.ts:310-329`), então é uma conferência em lote de "este
  CPF, telefone ou e-mail é cliente?" para o admin (20 por hora, 20.000 valores cada), auditada só com contagens. Aceitável
  para o papel; fica o registro.
- Laboratório: print só admin, 5 MB, primeiros bytes conferidos, nunca gravado em disco (`staff-laboratorio.ts:519-537`).
- Links tocáveis na bolha: lista fechada (telefones de ajuda e cvv.org.br), `href` montado pelo app
  (`apps/web/lib/linkificar.tsx`).

## Regressões da revisão de 24/10

**Nenhuma** nesta frente. Continuam no lugar: primeiros bytes e cota diária no upload (achado 26); regex do nome antes do
disco; auditoria `upload.view`; lista de serviços do push; segredo em tempo constante, recusa de evento com mais de 24 h e
segredo próprio opcional no webhook de imagens; estorno antes da compra (INT-05, `imagens-compra.ts:103-104`); senha de
novo para link de fora (02-A9, `staff-notices.ts:919`). Seguem abertas, por decisão registrada em 24/10: INT-01 e INT-13.

## Trechos da prova (arquivo temporário, já apagado)

Rodado com `cd apps/api && PROVA_MP4=<mp4 com localização> npx vitest run src/routes/zz-prova-seg-1116.test.ts`: 3 de 3 passaram.
O MP4 foi feito com `ffmpeg … -metadata location="-23.5505-046.6333/" -metadata model="SM-PROVA" -movflags use_metadata_tags`.

```ts
// A · M-01 e M-02: suporte sobe o vídeo; a cliente recebe o mesmo arquivo, com a localização dentro
const up = await ctx.app.inject({ method: "POST", url: "/staff/notices/video", headers: { ...headers, cookie: cookieSup }, payload });
expect(up.statusCode).toBe(201);
expect(readFileSync(join(dir, `aviso__${id}.mp4`)).includes("-23.5505-046.6333")).toBe(true);
// … aviso enviado com esse vídeo e entrega `sent` para a cliente …
const res = await ctx.app.inject({ method: "GET", url: `/me/notices/${n.id}/video`, headers: { cookie: cookieAluna } });
expect(res.headers["cache-control"]).toBe("private, max-age=31536000, immutable");
expect(res.headers["x-content-type-options"]).toBe("nosniff");
expect(res.rawPayload.includes("-23.5505-046.6333")).toBe(true);
expect(res.rawPayload.includes("SM-PROVA")).toBe(true);

// B · M-03: original enviado há 400 dias + a cópia em rascunho com o mesmo arquivo
const job = new RetentionJob(ctx.repos, { intervalMs: 60_000, uploadDir: dir });
expect(await job.apagarMidiasVencidas(new Date())).toBe(0);
expect(await job.pruneOrphanUploads(new Date())).toBe(0);
expect(existsSync(join(dir, `aviso__${u}.mp4`))).toBe(true);

// D · M-05: um `ffprobe` falso no PATH grava o que recebeu no ambiente
process.env.SEGREDO_DE_PROVA = "valor-que-so-a-api-devia-ver";
await sondarVideo(join(dir, "nao-importa.mp4"));
expect(readFileSync(saida, "utf8").trim()).toBe("valor-que-so-a-api-devia-ver");
```
