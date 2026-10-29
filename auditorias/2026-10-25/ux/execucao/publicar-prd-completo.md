# Publicar o PRD de UX/UI inteiro (ondas 1, 2 e 3) na VPS

Branch: `painel/ux-onda-3` do app, em **`466886d`** (29/10). Ela contém, em cima uma da outra:

- a revisão de segurança de 24/10 (`sha-3c343df`);
- a onda 1 (U01–U23, `sha-c71b41c`);
- a onda 2 (U24–U47 e U59 "cliente, nunca aluna", `bad27a7`);
- a onda 3 (U48–U58).

Publicar esta tag publica tudo de uma vez. A onda 1 sozinha continua possível (`publicar-onda-1.md`, a imagem
`sha-c71b41c` existe); as ondas 2 e 3 ainda não têm imagem.

## O que falta antes (técnica)

1. **GitHub Actions desbloqueado** (cobrança, desde 28/10 02:54 UTC): GitHub › Settings › Billing & plans.
2. CI de `466886d` verde no GitHub. O portão local já passou: o modo `ci` (Chromium e WebKit juntos, como o
   GitHub) deu 301 passaram, 7 pulados e nenhum instável.
3. `imagens-vps` disparado em `painel/ux-onda-3`, que gera as três imagens **`sha-466886d`**.

## Banco, variáveis e volta

- **Duas migrações, as duas só acrescentam**, e rodam sozinhas no `app-subir`:
  - `pa23_01_sessoes_rotacao_refresh` (segurança);
  - `ux1_01_messages_neutra` (onda 1: coluna `messages.neutra`, padrão falso).

  As ondas 2 e 3 não têm migração. A imagem anterior sobe com as colunas novas no lugar, então a volta não precisa
  de volta de banco.
- **Nenhuma variável nova** em produção. API, web e Crystal sobem na mesma tag, porque o contrato do shared mudou
  na onda 2.
- **Volta:** `REF=97b5ad29d2b998163bc31654cbc2c00aa8017d7e bash bootstrap-vps.sh app-subir sha-088d07d`. É a tag no
  ar hoje; o `REF` está explicado em `publicar-onda-1.md`.

## Antes de subir (dono, uma vez)

1. **Toda conta da equipe tem senha** (a porta da cliente não abre mais o painel): o `psql` do item 48 do
   `CONTINUAR-EM-OUTRA-CONTA.md` tem de voltar `(0 rows)`.
2. `bash bootstrap-vps.sh app-status`: anote a tag no ar e confira que o canal é `crystal`.
3. `bash bootstrap-vps.sh backup`.

## Subir

Com o script antigo na VPS, todo comando que sobe stack leva o `REF`; depois da madrugada da segurança, não leva mais.

```bash
REF=97b5ad29d2b998163bc31654cbc2c00aa8017d7e bash bootstrap-vps.sh app-subir sha-466886d
bash bootstrap-vps.sh app-status
bash bootstrap-vps.sh crystal-conferir
```

## Conferir no iPhone

Abra o app uma vez e feche (o cache passa de v4 para v5). Depois siga as três listas desta pasta, nesta ordem:

1. `onda-1-conferir-em-aparelho.md`
2. `onda-2-conferir-em-aparelho.md`
3. `onda-3-conferir-em-aparelho.md`

No painel, em Integrações › Canal, o "Modo backup" deve aparecer **Desligado**.

## Decisões do dono que ficaram no padrão (mudar é pequeno)

- Perguntas 1 a 14 do PRD: as tabelas estão no fim de cada lista do iPhone.
- O tom novo do toque no rosa (`#c20857`).
- `MICROFONE_IPHONE_INSTALADO_USA_RESERVA`, depois do teste do microfone no app instalado.
- Se o C02 (crédito zerado ou chave recusada) acende a faixa "fora do ar".
- O nome provisório "Aluno" gravado no banco.
- Os CSVs renomeados (`clientes.csv`).
