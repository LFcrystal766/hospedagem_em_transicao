# Publicar a versão `sha-8562647` (login do cliente com e-mail + senha): PODE SUBIR

Escrito em 13/11/2026. Quem roda é o Luiz, na VPS, como root. Claude não publica nada.

## O que é

A **`sha-8562647`** (branch **`painel/login-senha`**, commit `8562647f`) é a versão integrada `sha-8c4510c` (mídia,
visualização única, suporte Rafa; ver `publicar-integrado.md`) mais o login com e-mail + senha, pedido em 13/11:

- "Vamos colocar e-mail e senha, nem CPF tá dando certo";
- "para entrar a primeira vez fazemos um check com o e-mail, e o esqueci a senha manda um e-mail";
- "o botão de primeiro acesso";
- "e ter a opção de código por e-mail para quem quiser".

Ela substitui a `sha-8c4510c`: não é preciso subir a outra antes.

## Como fica a tela de entrada do cliente

1. **"Oi! Entre com o e-mail da compra e a sua senha."**: campo de e-mail, campo de senha (com "Mostrar") e o botão
   **"Entrar"**.
2. Embaixo, um botão grande: **"Primeiro acesso: criar senha"**.
   - Pede só o e-mail.
   - O código vai para o e-mail. É o "check" de que o e-mail é da pessoa.
   - Depois do código vem a tela **"Crie a sua senha"** (senha + "Repita a senha", pelo menos 8 caracteres) e o cliente
     já entra.
3. **"Esqueci a senha"**: o mesmo caminho. Com o código do e-mail, o cliente cria uma senha nova.
4. **"Entrar com código por e-mail"**: só o código, como era antes, para quem preferir. Não pede senha.
5. O CPF sai da tela nesse modo.
6. A equipe continua entrando por `/login/equipe`, sem mudança.

## Segurança

- **Mesma resposta para tudo o que não deu certo.** Senha errada, e-mail que não existe, conta sem senha e conta da
  equipe recebem a mesma frase: "E-mail ou senha incorretos. Confere e tenta de novo.". Ninguém descobre pela tela
  quem é cliente.
- **A senha nunca fica guardada.** Fica só o resumo dela (scrypt), no mesmo campo que a equipe já usa. Por isso não
  há migração.
- **Limites de tentativa**, por IP e por e-mail.
- **Criar ou trocar a senha derruba as outras sessões** do cliente (outro celular, outro navegador).
- **Trocar a senha sem código:**
  - nos 15 minutos depois de entrar pelo código, não pede a senha atual;
  - depois disso, pede a senha atual.
- **Compra, reembolso e acesso desligado continuam valendo.** Com a senha certa, a conta ainda passa pela base de
  clientes, pelo acesso desligado e pelo aceite, como no código.

## Quem já está dentro

- **Quem está logado continua logado.** A senha só aparece no próximo login.
- **Na próxima vez**, o cliente toca em "Primeiro acesso: criar senha", recebe o código uma vez e cria a senha.
- **"Pegar código de acesso" na ficha** continua servindo para o suporte. O cliente usa esse código em "Primeiro
  acesso", "Esqueci a senha" ou "Entrar com código por e-mail".

## Banco, variáveis e volta

- **Nenhuma migração.**
- **Nenhuma variável nova obrigatória.** O padrão é `LOGIN_SENHA=ligado`.
- **Volta da versão:** `sha-8c4510c`, com o passo da memória. Sem volta de banco. As senhas criadas ficam guardadas e
  voltam a valer se a `sha-8562647` subir de novo.

### Desligar só a senha, sem voltar a versão

A tela volta a ser a da `sha-8c4510c`: e-mail + CPF opcional, e código por e-mail.

O `app-definir` só aceita nomes de uma lista fixa, e `LOGIN_SENHA` não está nela. Por isso a chave vai direto no
`.externos`. O `app-subir` confere o `api.env` na própria imagem antes de trocar: um valor errado para tudo antes de
mexer no ar.

```bash
sed -i '/^LOGIN_SENHA=/d' /root/crystal/app/.externos
echo 'LOGIN_SENHA=desligado' >> /root/crystal/app/.externos
REF=97b5ad29d2b998163bc31654cbc2c00aa8017d7e bash bootstrap-vps.sh app-subir sha-8562647
docker service update --limit-cpu 1 --limit-memory 2560M --env-add NODE_OPTIONS=--max-old-space-size=2048 crystal_app_app_crystal
docker service update --limit-memory 2048M --env-add NODE_OPTIONS=--max-old-space-size=1536 crystal_app_app_api
```

**Religar:** apague a linha com `sed -i '/^LOGIN_SENHA=/d' /root/crystal/app/.externos`. O padrão já é ligado. Depois
rode o mesmo `app-subir` e o passo da memória.

## Antes (técnica)

- **Portão local verde:** tipos, lint, testes de shared, API (com 9 testes novos da senha) e web (2.860 testes).
- **1º CI (`3e1d7a98`, run 43503819492):**
  - verdes: audit e **e2e do login só com e-mail**, que já roda o roteiro novo da senha (primeiro acesso → criar
    senha → entrar com a senha, senha errada, entrar com código);
  - imagens `sha-3e1d7a9` prontas;
  - o gate caiu em 1 teste da visualização única, da outra sessão (`VisualizacaoUnica.test.tsx`).
- **Causa da queda do gate:** corrida de tempo.
  - Os ouvintes de "app em segundo plano" eram ligados num efeito que, com a máquina carregada, rodava depois de o
    visor já estar na tela.
  - Sonda sob carga: 1 em 120 vezes sem o ouvinte.
  - Corrigido no `8562647f` (ouvintes no mesmo commit que mostra o visor): 0 em 200.
- **CI do `8562647f`** (run 43514432464), conferido em 13/11 ~22:31 UTC:
  - verdes: **gate inteiro** (tipos, lint, as 4 suítes, build do web e bundle do Safari), audit e **e2e do login só com
    e-mail**, com o roteiro da senha;
  - **imagens `sha-8562647` prontas** (run 43514441747);
  - e2e completo (terminou 23:20 UTC): 441 passaram, 18 falharam, 52 pulados. São os mesmos números da
    `sha-8c4510c`, e as 18 são as mesmas falhas de mídia (14 em `mensagens-midia.spec.ts`) e de `mobile-audit.spec.ts`
    (4) da outra sessão. Nenhuma falha de login ou de senha.
- **PODE SUBIR.**
- **e2e completo:** as 18 falhas de mídia (`mensagens-midia.spec.ts` e `mobile-audit.spec.ts`) já existiam na versão
  da outra sessão. Ver `publicar-integrado.md`.

## Subir (no terminal da VPS, um por vez)

Horário de pouco movimento. O app fica alguns segundos sem responder enquanto troca.

```bash
cd /root
bash bootstrap-vps.sh app-status          # anote as tags atuais: são a volta
bash bootstrap-vps.sh backup
REF=97b5ad29d2b998163bc31654cbc2c00aa8017d7e bash bootstrap-vps.sh app-subir sha-8562647
docker service update --limit-cpu 1 --limit-memory 2560M --env-add NODE_OPTIONS=--max-old-space-size=2048 crystal_app_app_crystal
docker service update --limit-memory 2048M --env-add NODE_OPTIONS=--max-old-space-size=1536 crystal_app_app_api
bash bootstrap-vps.sh app-status
```

Os dois `docker service update` são o passo da memória, obrigatório depois de todo `app-subir`. Os três serviços têm
de aparecer em `sha-8562647`.

## Conferir (10 minutos, no iPhone, numa janela anônima ou depois de sair do app)

1. **Tela de entrada:** aparece "Oi! Entre com o e-mail da compra e a sua senha.", com "Primeiro acesso: criar
   senha", "Esqueci a senha" e "Entrar com código por e-mail". Não tem campo de CPF.
2. **Primeiro acesso:** use uma conta de teste.
   - Toque em "Primeiro acesso: criar senha", digite o e-mail e use o código que chegar.
   - Tem de aparecer "Crie a sua senha". Crie uma senha de 8+ caracteres e salve: o app abre.
3. **Entrar com a senha:** saia (menu ⋮ › Sair) e entre com o e-mail e a senha criada. Tem de entrar direto, sem
   código.
4. **Senha errada:** saia e tente uma senha errada. Tem de aparecer "E-mail ou senha incorretos. Confere e tenta de
   novo.".
5. **Esqueci a senha:** toque em "Esqueci a senha", use o código e crie uma senha nova. A antiga deixa de valer.
6. **Código por e-mail:** toque em "Entrar com código por e-mail". Tem de entrar só com o código, sem criar senha.
7. **Equipe:** `/login/equipe` continua igual.
8. **O resto da integrada:**
   - "Fale com Rafa, do nosso suporte." no menu ⋮ › Suporte;
   - Mensagens › Nova mensagem com os três cartões e o anexo;
   - a notificação abre a conversa.
9. Se algo falhar: desligue só a senha (acima) ou volte a versão (abaixo).

## Volta da versão

```bash
REF=97b5ad29d2b998163bc31654cbc2c00aa8017d7e bash bootstrap-vps.sh app-subir sha-8c4510c
docker service update --limit-cpu 1 --limit-memory 2560M --env-add NODE_OPTIONS=--max-old-space-size=2048 crystal_app_app_crystal
docker service update --limit-memory 2048M --env-add NODE_OPTIONS=--max-old-space-size=1536 crystal_app_app_api
```

Se o que está no ar antes de subir ainda forem as três tags antigas (API `sha-b5eb55c`, Crystal `sha-b3d02f1`, web
`sha-44f4dcd`), a volta são elas, com os comandos do fim de `publicar-integrado.md`.
