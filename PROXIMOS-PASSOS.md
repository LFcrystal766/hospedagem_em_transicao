# Próximos passos — atualizado em 28/09/2026

Tudo que dá pra fazer por API é da sessão do Claude. Abaixo, só o que depende
de você, na ordem, com o tempo estimado.

## Agora (uns 15 minutos)

1. **Cloudflare, 5 min.**
   - Apague o token antigo que vazou: Manage Account > Account API Tokens >
     id `856e07e65b984fe5ffb01451bfa3e49e` > Delete.
   - Ligue o 2FA: My Profile > Authentication.
2. **Variáveis do ambiente, 5 min.** Em claude.ai/code, no menu do ambiente
   deste repositório, clique em Edit e cole:
   - `CLOUDFLARE_API_TOKEN` = valor do token `claude-crystal-migracao`
   - `CLOUDFLARE_ACCOUNT_ID` = `a938d629ec1d8ac1f21e77e8723ac514`
3. **Sessão nova, 2 min.** Abra uma sessão nova deste repositório e escreva
   "segue o CLAUDE.md". Na primeira chamada ao Cloudflare, aprove. Para não
   ser perguntado de novo, libere em /permissions a regra
   `Bash(scripts/cloudflare-degrau2.sh:*)`.
4. **Registro.br: fica em aberto por decisão do dono (28/09).** Não bloqueia o
   degrau 2. Precisa ser resolvido antes de cancelar a AZAN: o e-mail do
   contato LFMPI73 ainda é admin@leticiafelisberto.com.

## Quando puder (uns 10 minutos)

5. **Mais três credenciais no ambiente**, do mesmo jeito do passo 2:
   - cPanel da AZAN > Segurança > Gerenciar tokens da API > `claude-migracao`,
     90 dias: `CPANEL_AZAN_HOST=jupiter.servidor.net.br`, `CPANEL_AZAN_USER`,
     `CPANEL_AZAN_TOKEN`
   - Stape > Account settings > API Keys > `claude-migracao-leitura`:
     `STAPE_ACCOUNT_API_KEY`
   - wp-admin > Usuários > Perfil (admin) > Senhas de aplicativo >
     `claude-migracao`: `WP_APP_USER=admin`, `WP_APP_PASSWORD`. Troque também
     a senha do admin
6. **MacBook**, quando ligar: enviar para o GitHub as pastas
   `hospedagem-crystal-dns` e `crystal-web-chat`.

## Decisões suas

7. **Resposta da AZAN ao chamado #RAI-374885**: encaminhe para a sessão.
8. **Data do degrau 2**: uma madrugada, às 02:00, depois da resposta da AZAN.
9. **TikTok**: terminar o que falta antes da linha de base, ou congelar até a
   migração acabar.
10. **Aviso ao time**, 48h antes do degrau 2. Texto pronto em
    `pedidos/aviso-time-degrau2.md`.

## Frente paralela: a VPS da Crystal (o app)

Independe dos degraus do site. Detalhes em `crystal-em-casa/README.md`.

11. **VPS contratada em 28/09**: Hostinger KVM 4, Ubuntu 24.04, Boston, IP
    `177.7.61.136`. Falta tudo o que vem depois.
12. **DNS dos três nomes** (`painel`, `editor`, `webhook` → `177.7.61.136`,
    **nuvem cinza**). Dois caminhos:
    - Sessão do Claude, com `CLOUDFLARE_API_TOKEN` (DNS Edit) no ambiente:
      `scripts/cloudflare-crystal-vps-dns.sh criar --aplicar`
    - Painel do Cloudflare (DNS > Records > Add record), Proxy status = DNS only.
      Depois: `scripts/cloudflare-crystal-vps-dns.sh conferir` prova os três
    Não criar antes de o token novo existir nem na mesma madrugada do degrau 2.
13. **Três respostas da agência** antes de contratar o Supabase: compute size
    do projeto da Crystal, dono da conta OpenRouter, quem monta a fase 1.
14. **Docker + Swarm** pelo Web console da Hostinger, depois as stacks 00 a 06
    de `crystal-em-casa/stacks-exemplo/`, na ordem, com os segredos em cofre.
15. **Contas**: Supabase Pro + convite Owner para `agencia@academialendaria.ai`,
    GitHub (repo privado, e-mail, token `write:packages`), Netlify, Telegram.
16. **Avisar a agência** quando os 16 pontos de "Base pronta" do guia estiverem
    verdadeiros. A fase 2 (código, transferência do Supabase, imagem, corte) é deles.

## O que a sessão do Claude faz sozinha depois do passo 3

- Foto completa da zona e preparação das configurações, ainda com tudo cinza.
  Não muda nada para o visitante.
- Conferência do certificado de borda e da regra "server. sempre cinza".
- Na madrugada combinada: laranja, validação pela borda, Always HTTPS, bloqueio
  do xmlrpc, rewrite do /crystal-teste. Rollback em segundos se algo sair do padrão.
- Com as credenciais do passo 5: backup da AZAN, zona real, caixas de e-mail,
  prova venda a venda pelo Stape, e a cópia na Hostinger.
