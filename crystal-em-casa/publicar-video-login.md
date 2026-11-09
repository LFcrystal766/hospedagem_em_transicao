# Publicar o vídeo nas mensagens junto com o login (versão `painel/video-login`)

Escrito em 09/11/2026. Quem roda é o Luiz, na VPS, como root. Claude não publica nada.

## O que entra

A versão a publicar é a **`sha-e3e75c5`** (branch **`painel/video-login`**, commit `e3e75c58`). Ela junta tudo numa
versão só:

| Parte | De onde vem | O que muda para os clientes e a equipe |
|---|---|---|
| Dores | `1db2e16` (05/11) | Análise, leituras da IA, disparo por dor |
| Login, Pacote 1 | `painel/dores-login` (`cd2705a`, 06/11) | O mesmo código no reenvio, o código no assunto do e-mail, 15 minutos |
| Pacote de imagens | `painel/pacote-imagens` (07/11, outra sessão) | Página Imagens no painel (textos, pacotes, compras paradas, funil), oferta do pacote na mensagem do limite |
| Memória do WhatsApp | `fix/memoria-whatsapp` (08/11, outra sessão) | A memória que veio do WhatsApp volta a entrar na resposta |
| Vídeo nas mensagens | `painel/video-disparos` (09/11, outra sessão) | A "Mensagem da Crystal" pode levar um vídeo, que toca dentro da conversa |
| Vídeo por 48 horas | este pedido (09/11) | O vídeo e a capa saem do disco 48 horas depois do fim do envio |

**A versão `painel/video-disparos` sozinha NÃO deve subir.** Ela não tem o login novo: subir ela tiraria o
"mesmo código no reenvio", o código no assunto e os 15 minutos.

## Onde fica o vídeo e por quanto tempo

- Na VPS, no volume `app_uploads` (`/app/uploads` da API), junto das fotos e áudios dos clientes. Nada vai para o
  Drive nem para o YouTube. Sobrevive ao `app-subir` e entra no `backup`.
- Só MP4, até 50 MB. O `.mov` do iPhone é recusado.
- **48 horas depois do fim do envio**, a rodada de hora em hora apaga o vídeo e a capa.
  - A mensagem continua na conversa do cliente, só com o texto.
  - Os números continuam no painel: enviadas, entregues, abertas, cliques e "Tocaram para ouvir".
  - O detalhe do envio diz até quando o vídeo fica, e depois quando ele saiu.
  - "Reenviar para quem não abriu" dentro das 48 horas leva o vídeo, com prazo próprio; depois, sai só com o texto.
- Rascunho, agendado e enviando não vencem.
- Vídeo enviado que não virou mensagem some em 48 horas (já era assim).

## Banco, variáveis e volta

- **Duas migrações novas, só aditivas**, aplicadas sozinhas na subida:
  - `wim1_01_imagem_ofertas`: tabela `imagem_ofertas` e coluna `messages.oferta_id`;
  - `wvd1_01_aviso_video`: colunas do vídeo em `notices` e `notice_deliveries.listened_at`.
  - Cada uma desiste em 5 segundos se a tabela estiver presa (não trava o app).
- **Nenhuma variável nova.** O padrão de `OTP_TTL_S` é 900 (15 minutos).
- **Volta:** a tag que o `app-status` mostrar antes da subida, com o passo da memória. Sem volta de banco: a versão
  antiga ignora a tabela e as colunas novas.
- Depois de subir, as configurações de imagens ficam na página **Imagens** do painel (saem de Configurações).

## Antes (técnica)

- **CI do `e3e75c58` inteiro verde** (run 42688668221): gate, audit, e2e completo (Chromium e WebKit, 362 passaram,
  nenhum instável) e e2e do login só com e-mail.
- **Imagens `sha-e3e75c5` prontas** (run 42688677237: API, web e Crystal).
- Portão local: rápido verde (2.350 testes do web, mais API, shared e Crystal); e2e de vídeo, login, equipe e imagens
  com 58 de 58; login só com e-mail com 10 de 10.

## Subir (no terminal da VPS, um por vez)

Horário de pouco movimento. O app fica alguns segundos sem responder enquanto troca.

```bash
cd /root
bash bootstrap-vps.sh app-status          # anote a tag atual: é a volta
bash bootstrap-vps.sh backup
REF=97b5ad29d2b998163bc31654cbc2c00aa8017d7e bash bootstrap-vps.sh app-subir sha-e3e75c5
docker service update --limit-cpu 1 --limit-memory 2560M --env-add NODE_OPTIONS=--max-old-space-size=2048 crystal_app_app_crystal
docker service update --limit-memory 2048M --env-add NODE_OPTIONS=--max-old-space-size=1536 crystal_app_app_api
bash bootstrap-vps.sh app-status
bash bootstrap-vps.sh crystal-conferir
```

Os dois `docker service update` são o passo da memória, obrigatório depois de todo `app-subir`. Tem de aparecer os
três serviços em `sha-e3e75c5`. Os "!" do `crystal-conferir` no `/healthz` são o alarme falso já conhecido.

## Conferir (10 minutos, no iPhone)

1. **Login:** saia do app numa conta de teste com Hotmail. O assunto do e-mail começa pelo código; "Reenviar código"
   manda o mesmo código.
2. **Vídeo:** no painel, Mensagens › Nova mensagem › "Mensagem da Crystal" › Vídeo (opcional): escolha um MP4 curto.
   - A ajuda do campo fala das 48 horas.
   - "Enviar teste para mim": na conversa, o vídeo começa sem som e o toque liga o som.
3. **Dores:** a página Análise abre e a ficha de um cliente mostra o bloco "Dores".
4. **Imagens:** a página Imagens abre no painel, com os pacotes e o link de compra.
5. Se algo falhar, rode a volta.
