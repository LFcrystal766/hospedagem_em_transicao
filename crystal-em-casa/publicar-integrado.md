# Publicar a versão integrada `sha-8c4510c` (mídia + Rafa + CPF opcional)

Escrito em 13/11/2026. Quem roda é o Luiz, na VPS, como root. Claude não publica nada.

## Por que esta versão existe

Até 13/11 de manhã, estava no ar a versão de outra sessão, com uma tag diferente em cada serviço:

- API: `sha-b5eb55c`;
- Crystal: `sha-b3d02f1`;
- web: `sha-44f4dcd`.

Essas tags vêm da branch `fix/notificacao-abre-conversa-ios`. Em 13/11 ~14:07 UTC subiu a `sha-8ed06f8`, que não tinha esse
trabalho. A volta para as três tags antigas foi feita com `docker service update --image`.

A **`sha-8c4510c`** (branch **`painel/integrado-rafa`**, commit `8c4510c`) junta as duas coisas, com uma tag só nos três serviços.

## O que entra

1. **Tudo o que a outra sessão pôs no ar:**
   - mídia nas mensagens da equipe (imagem, vídeo, áudio);
   - visualização única;
   - mensagem nova em três cartões, com o celular do cliente na prévia;
   - exclusão de disparos;
   - o toque na notificação sempre abre a conversa, inclusive no iPhone;
   - o painel no masculino.
2. **O suporte Rafa:**
   - "Fale com Rafa, do nosso suporte." e "Oi, Rafa! …";
   - os e-mails de aviso leem o nome do painel.
3. **O login com e-mail + CPF, com o CPF opcional:**
   - CPF guardado e certo: entra sem código;
   - sem CPF guardado: o código vem uma vez e o CPF fica na conta;
   - **CPF em branco** (cliente de fora do Brasil): só o código por e-mail. A dica diz "Não tem CPF? Deixe em branco: eu mando
     um código no seu e-mail.".
   - Nas versões da outra sessão e na `sha-8ed06f8`, o CPF era obrigatório na tela, e quem é de fora do Brasil não entrava.
4. **Um teste firme:** a cópia anônima da M03 não depende mais da ordem de duas bolhas do mesmo milissegundo.

## Banco, variáveis e volta

- **Nenhuma migração nova.** A `wmm1_01_aviso_midia` da outra sessão já está no banco, porque a API `sha-b5eb55c` a aplicou.
- **Nenhuma variável nova obrigatória.** O padrão é `LOGIN_CPF=ligado`.
- **Desligar só o CPF**, sem voltar a versão:
  1. `sed -i '/^LOGIN_CPF=/d' /root/crystal/app/.externos && echo 'LOGIN_CPF=desligado' >> /root/crystal/app/.externos`
     (o `app-definir` não aceita `LOGIN_CPF`: o nome não está na lista dele; para religar, só o `sed`);
  2. `app-subir` com a mesma tag;
  3. o passo da memória.
- **Volta:** as três tags anteriores, uma por serviço (comandos no fim). Sem volta de banco.

## Antes (técnica)

- **Merge** de `44f4dcd9` com `painel/suporte-rafa` (`25afaf7f`): sem conflito.
- **Portão local rápido verde** (tipos, lint, testes de shared, API, web e Crystal).
- **1º CI (`b7ca761e`):**
  - verdes: audit e e2e do login só com e-mail;
  - o gate caiu num teste instável da outra sessão (`anonymous-copy`, ordem de duas bolhas). Corrigido no `8c4510c`.
- **CI do `8c4510c`** (run 43473770258):
  - verdes: gate (tipos, lint, as 4 suítes e o build do web), audit e e2e do login só com e-mail;
  - imagens `sha-8c4510c` prontas (run 43473780023);
  - e2e completo: 441 passaram e 18 falharam.
- **As 18 falhas não vêm desta junção.** São 15 de `mensagens-midia.spec.ts` e 3+1 de `mobile-audit.spec.ts`.
  - O CI da própria branch da outra sessão (`painel/mensagens-midia`, run 43259024771, commit `288dc92c`) já tinha
    o e2e vermelho, com o mesmo pacote de 159 arquivos de falha.
  - Essa é a versão que estava no ar desde 12/11.
  - O que esta junção mexe (login, CPF, suporte, Rafa) passou inteiro.
  - Corrigir os testes de mídia da outra sessão fica como tarefa à parte.

## Subir (no terminal da VPS, um por vez)

Horário de pouco movimento. O app fica alguns segundos sem responder enquanto troca.

```bash
cd /root
bash bootstrap-vps.sh app-status          # tem de mostrar as tags antigas: API b5eb55c, Crystal b3d02f1, web 44f4dcd
bash bootstrap-vps.sh backup
REF=97b5ad29d2b998163bc31654cbc2c00aa8017d7e bash bootstrap-vps.sh app-subir sha-8c4510c
docker service update --limit-cpu 1 --limit-memory 2560M --env-add NODE_OPTIONS=--max-old-space-size=2048 crystal_app_app_crystal
docker service update --limit-memory 2048M --env-add NODE_OPTIONS=--max-old-space-size=1536 crystal_app_app_api
bash bootstrap-vps.sh app-status
```

Os dois `docker service update` são o passo da memória, obrigatório depois de todo `app-subir`. Os três serviços têm de
aparecer em `sha-8c4510c`.

## Conferir (10 minutos, no iPhone)

1. **Painel:** em Configurações › Contatos › "Nome de quem atende", tem de estar `Rafa`.
2. **Login com CPF certo:** use uma conta que tenha CPF na base. Tem de entrar direto, sem código.
3. **Login sem CPF:** saia, digite só o e-mail e deixe o CPF em branco.
   - Vem a tela do código.
   - A frase "Não encontrei esse formato de CPF" NÃO aparece.
4. **Suporte:** no menu ⋮ › Suporte, aparece "Fale com Rafa, do nosso suporte.".
5. **Mídia:** no painel, abra Mensagens › Nova mensagem.
   - Tem de ter os três cartões e o anexo de imagem/áudio.
   - A interface da visualização única tem de continuar lá.
6. **Notificação:** tocar numa notificação abre a conversa.
7. Se algo falhar, use a volta abaixo.

## Volta (as três tags anteriores)

```bash
docker service update --with-registry-auth --image ghcr.io/lfcrystal766/crystal-web-chat-api:sha-b5eb55c crystal_app_app_api
docker service update --with-registry-auth --image ghcr.io/lfcrystal766/crystal-web-chat-crystal:sha-b3d02f1 crystal_app_app_crystal
docker service update --with-registry-auth --image ghcr.io/lfcrystal766/crystal-web-chat-web:sha-44f4dcd crystal_app_app_web
bash bootstrap-vps.sh app-status
```

`--image` não mexe nos limites de memória, então não precisa repetir o passo da memória.
