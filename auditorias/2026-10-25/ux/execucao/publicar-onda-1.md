# Publicar a onda 1 de UX (U01 a U23) na VPS

Tag: **`sha-c71b41c`** (branch `painel/ux-onda-1` do app, CI verde em 27/10; imagens do `imagens-vps`).
Ela **já contém** a revisão de segurança de 24/10 (`sha-3c343df`), que ainda não subiu: publicar esta tag publica
as duas coisas de uma vez. Não é preciso subir a `sha-3c343df` antes.

Volta: `REF=97b5ad29d2b998163bc31654cbc2c00aa8017d7e bash bootstrap-vps.sh app-subir sha-088d07d` (a tag no ar hoje;
o `REF` está explicado em "Subir"). As duas migrações novas só acrescentam
(`pa23_01_sessoes_rotacao_refresh` e `ux1_01_messages_neutra`, uma coluna `messages.neutra` com padrão falso): a
imagem anterior sobe com elas no lugar, sem volta de banco. Não usar `sha-d5126c0`.

## Antes de subir (uma vez)

1. **Toda conta da equipe tem senha.** Da revisão de segurança: a porta de entrada da cliente não abre mais o
   painel. Na VPS, o `psql` do item 48 do `CONTINUAR-EM-OUTRA-CONTA.md` tem de voltar `(0 rows)`. Se listar
   alguém, definir a senha em Operação › Equipe antes.
2. Anotar a tag no ar: `bash bootstrap-vps.sh app-status` (tem de mostrar `sha-088d07d`; se for outra, essa é a
   volta) e conferir que o canal é `crystal` (`CHAT_TRANSPORT`).
3. `bash bootstrap-vps.sh backup` (bancos).

O SQL `app_compras_seguranca_n8n.sql` e a troca do fluxo do n8n (passos 3 e 4 do resumo de segurança,
`auditorias/2026-10-24/seguranca/00-resumo.md` › seção 4) não dependem desta tag: podem vir antes, junto ou
depois. A madrugada da VPS (passo 8 de lá) também é separada.

## Subir

**Atenção (27/10):** o `bootstrap-vps.sh` que está na VPS é o de antes da revisão de segurança (`97b5ad2`). Sem `REF`,
ele baixa o yaml do app da ponta da branch, que já é o da segurança (Redis com senha, redes novas) e pede o
`redis.env` que esse script antigo não cria: o deploy para em `open /root/crystal/app/redis.env: no such file or
directory`, antes de mexer em qualquer coisa (aconteceu em 27/10; nada mudou no ar). Até a madrugada da segurança
(que troca o script), **todo comando do script antigo que sobe stack leva o `REF` do commit dele**:

```bash
REF=97b5ad29d2b998163bc31654cbc2c00aa8017d7e bash bootstrap-vps.sh app-subir sha-c71b41c   # yaml igual ao que está no ar; migrações sozinhas
bash bootstrap-vps.sh app-status              # as três em sha-c71b41c, API e web respondendo
bash bootstrap-vps.sh crystal-conferir        # TUDO LIGADO
```

Quedas: a API e o web trocam em 1 a 2 minutos; a conversa volta sozinha. Hora calma, fora do pico.

## Conferir

- No iPhone, a lista `onda-1-conferir-em-aparelho.md` (mesma pasta). Primeiro abrir o app uma vez e fechar (o
  cache passa de v4 para v5). Nunca ligar em produção o modo reserva manual nem os gatilhos `#erro`, `#fora`,
  `#neutra`.
- No painel: o login da equipe pede a senha (`/login/equipe`); Integrações › Canal › "Modo backup" aparece
  **Desligado** se nunca foi gravado. O padrão mudou de "Automático" para "Desligado" (U22): com o WhatsApp a
  caminho do corte, o token da Meta morto ligaria o backup sozinho e mandaria a faixa e um push para toda a base.
  Se estiver gravado "Automático", passar para "Desligado".
- Uma conversa de verdade: tiques azuis e "digitando…" em menos de 1 segundo.

## Se algo der errado

`REF=97b5ad29d2b998163bc31654cbc2c00aa8017d7e bash bootstrap-vps.sh app-subir sha-088d07d` e avisar com o que
apareceu na tela (print). Nada de banco a desfazer.

Depois da madrugada da segurança (o script novo, do commit `fcd8955`, com `STACKS_COMMIT` fixo), o `REF` não é mais
usado: lá o passo 6 é `app-subir` da tag que estiver no ar.
