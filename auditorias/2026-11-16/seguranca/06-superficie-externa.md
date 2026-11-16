# 06 · Sites, Cloudflare, e-mail, Supabase e GitHub vistos de fora (16/11/2026)

Feito por Claude, só com leitura. Nada foi alterado em produção.

- **Como foi feito:** pedidos GET simples aos sites, consulta pública de DNS, API do Cloudflare com a chave da zona,
  consultas de catálogo no Supabase (sem dados de clientes) e leitura do GitHub.
- **O que não deu para testar daqui:** portas da VPS além de 80/443, certificados TLS e acesso direto ao IP da AZAN.
  O ambiente desta sessão sai por um proxy que só fala HTTP/HTTPS e refaz o TLS.

## Achados

| ID | Gravidade | O risco, em uma frase | Evidência | O que fazer | Confiança |
|---|---|---|---|---|---|
| X-01 | **Alto** (só o dono resolve) | A chave mestra do Supabase que vazou em 06/10 (INF-02 da revisão de 24/10) **continua valendo**: quem a guardou lê e altera a base inteira (11 mil clientes com nome, e-mail, CPF e telefone; 5,7 milhões de mensagens antigas do WhatsApp) e libera ou bloqueia acessos | A chave `anon` legada está ligada (`disabled: false`) e foi emitida em 28/07/2026; as duas chaves legadas nascem do mesmo segredo e são desligadas juntas, logo a `service_role` de 06/10 nunca foi invalidada | Supabase › Settings › API Keys › **Disable legacy API keys**. Antes, conferir que o n8n usa a chave nova (`sb_secret_…`); a VPS já usa desde 09/10. Depois: trocar a senha do banco (a agência conhecia), apagar os 2 usuários do Supabase Auth (último login em 03/10) e conferir os membros da organização | Confirmado (estado das chaves); o vazamento em si vem do registro de 06/10 |
| X-02 | **Alto** | O n8n da VPS está na versão `1.123.10`, e a linha 1.x recebeu depois dela várias levas de correção, com falhas críticas de execução de código (corrigidas em `1.123.22`, `1.123.33` e, em 30/09, `1.123.83`); a tela de login dele (`editor.`) está aberta para a internet. O n8n guarda o token da Assiny e a chave do Supabase | `https://editor.…/metrics` responde sem senha: `n8n_version_info{version="v1.123.10"}`; `/signin` com 200 de qualquer lugar | Atualizar o n8n para a 1.123.x mais nova (ou 2.x, com teste); restringir `editor.` por IP, como já é o Portainer; fechar o `/metrics` | Versão confirmada; a lista de falhas vem de avisos públicos (ver fontes) e não foi testada |
| X-03 | Médio | O `/metrics` do n8n entrega, sem senha, versão do n8n e do Node, número de fluxos ativos e uso de memória/CPU | `GET https://editor.…/metrics` → 200, 10 KB | `N8N_METRICS=false` ou bloquear o caminho no Traefik | Confirmado |
| X-04 | Médio | O site de vendas roda em **PHP 7.4.33**, sem correção de segurança desde 11/2022, e anuncia isso no cabeçalho | `x-powered-by: PHP/7.4.33` em `crystalnowpp.com.br` | cPanel da AZAN › MultiPHP Manager › PHP 8.2 ou 8.3 (testar as páginas depois). Some sozinho se o site virar estático | Confirmado |
| X-05 | Médio (a confirmar por dentro) | O `robots.txt` do site é um arquivo físico, alterado em **23/08/2026 às 03:37** (horário de Brasília), que lista 5 sitemaps inexistentes; esse padrão é assinatura comum de invasão que injeta spam | `last-modified: Sun, 23 Aug 2026 06:37:35 GMT`; `sitemap613/592/669/690/712.xml` → 404. De fora **não há** sinal ativo: mesma página para navegador e Googlebot, nenhum link ou script estranho | No WordPress: conferir Usuários (algum administrador desconhecido?), plugins e o Code Snippets; rodar o antivírus da hospedagem (cPGuard/Imunify); olhar "Problemas de segurança" e "Sitemaps" no Google Search Console; apagar o `robots.txt` físico (o Rank Math gera o certo) | Arquivo e data confirmados; a invasão é hipótese |
| X-06 | Médio | O WordPress entrega o nome de login do administrador (`admin`) a qualquer um, e a tela de login é pública: metade do trabalho de quem tenta adivinhar a senha | `/wp-json/wp/v2/users` → `slug: admin`; `/?author=1` → `/author/admin/` | Criar outro administrador com nome não óbvio e 2FA, e rebaixar o `admin`; bloquear `/wp-json/wp/v2/users` e `?author=` no Cloudflare. Atenuantes já no ar: freio no `wp-login` (16/11) e o captcha da hospedagem | Confirmado |
| X-07 | Médio | Qualquer pessoa pode mandar e-mail **fingindo ser** `@crystalnowpp.com.br` (golpe de "seu código de acesso" em cliente), porque o DMARC está em `p=none` | `_dmarc` = `v=DMARC1; p=none;` | Pôr um endereço de relatório (`rua=`), observar 2 semanas e subir para `p=quarantine` | Confirmado |
| X-08 | Médio (a esclarecer) | Existe no DNS uma identidade do Amazon SES (3 chaves DKIM e o `bounce.`) que ninguém do time reconhece; o dono dessa conta AWS consegue mandar e-mail assinado como o domínio | Registros criados em 21/09 na cópia da zona da AZAN: `…._domainkey → ….dkim.amazonses.com` (3) e `bounce` (MX e TXT) | Descobrir de quem é (agência? ferramenta de disparo?). Se não for de ninguém, apagar os 5 registros | Registros confirmados; o dono é desconhecido |
| X-09 | Médio | A VPS mostrou em 15/11 "18 atualizações pendentes" e "**reinício necessário**": correções do sistema já instaladas que só valem depois de reiniciar | Tela de login colada pelo dono em 15/11 | Reiniciar numa madrugada (`reboot`) e conferir `app-status` depois; ligar o reinício automático das atualizações de segurança | Confirmado pelo print; estado de hoje não conferido |
| X-10 | Baixo | O site de vendas não manda nenhum cabeçalho de proteção (HSTS, anti-moldura, `nosniff`) | Cabeçalhos de `crystalnowpp.com.br` | Depois de alguns dias estável no Cloudflare: HSTS e `X-Frame-Options`/`nosniff` por regra da zona. **Não** ligar o "Add security headers" do Cloudflare (manda `referrer-policy` e atrapalha o rastreio) | Confirmado |
| X-11 | Baixo | `readme.html`, `license.txt` e `wp-admin/install.php` respondem; o `/api` do Chatwoot diz a versão (`4.18.0`); `atendimento.` e `editor.` não mandam HSTS | Pedidos GET de 16/11 | Bloquear os três arquivos na borda; HSTS no Traefik para todos os nomes da VPS | Confirmado |
| X-12 | Baixo | Sem DNSSEC e sem registro CAA: falsificar resposta de DNS ou emitir certificado por outra autoridade fica mais fácil do que precisa | `dnssec.status = disabled`; CAA vazio | DNSSEC: um clique no Cloudflare + registro DS no Registro.br (decisão do dono: hoje a regra é não mexer no Registro.br). CAA para as autoridades em uso | Confirmado |
| X-13 | Baixo | O IP da AZAN é público (`mail.`, `ftp.`, SPF), então quem quiser pula o Cloudflare e bate direto no servidor | DNS | Em hospedagem compartilhada não dá para fechar. Resolve quando o site sair da AZAN | DNS confirmado; o contorno não foi testado daqui |
| X-14 | Baixo | Bibliotecas de teste do app (vitest, tinypool, vite) têm 18 avisos, 2 críticos; elas não vão para as imagens de produção | `pnpm audit`: produção **sem avisos**; desenvolvimento 18 | Atualizar o vitest na próxima leva | Confirmado |
| X-15 | Informativo | No Supabase, 10 funções SQL são chamáveis com a chave pública; nenhuma lê tabela (rodam com a permissão de quem chama, e a chave pública não tem permissão em tabela nenhuma). 13 funções da agência sem `search_path` fixo | Catálogo do Supabase em 16/11 | Tirar o `EXECUTE` de `anon`/`authenticated` por higiene | Confirmado |
| X-16 | Informativo | Duas contas além da do dono têm permissão de escrita no código do app (`luizfpinho`, `o-igor-andrade`) | Colaboradores do `crystal-web-chat` | Confirmar que as duas são do time e têm 2FA | Confirmado |
| X-17 | Informativo | A chave do Cloudflare usada no degrau 2 está guardada no ambiente desta sessão | Network secrets do ambiente | Apagar no Cloudflare e no ambiente depois da conferência das 12:00 | Confirmado |

Fontes do X-02 (versões corrigidas do n8n 1.x):
- https://heise.de/-11268517 (seis falhas, duas críticas; corrigidas na `1.123.33`);
- https://wz-it.com/en/blog/n8n-security-update-september-2026/ (14 avisos; corrigidos na `1.123.83`, de 30/09/2026);
- https://community.n8n.io/t/security-bulletin-february-25-2026/270324 (`1.123.22`).

## Conferido e ok

- **App (`app.`) e API (`api.`):**
  - CSP com nonce, HSTS, `nosniff`, `frame-ancestors 'none'`;
  - CORS só para `https://app.crystalnowpp.com.br`, inclusive quando o pedido vem de outra origem;
  - erro sem detalhe interno;
  - sem `/docs`, `/metrics` ou `/debug`;
  - `/me` com 401 sem sessão.
- **Portainer (`painel.`):** 403 para quem não está na lista de IPs.
- **Chatwoot (`atendimento.`):** cadastro fechado (`signupEnabled: false`); `/super_admin` com 403 no Traefik.
- **`webhook.`:** só responde em `/webhook/…` e `/healthz`.
- **Supabase:**
  - todas as tabelas com RLS e **nenhuma** legível com a chave pública;
  - as funções `app_*` só para `service_role`;
  - nenhuma conexão direta de fora ao banco no momento da consulta;
  - o sistema da agência parou de gravar em 16/10 (última conversa do WhatsApp) e 12/10 (última compra).
- **Cloudflare:** SSL Full (strict), TLS 1.2+, sempre HTTPS, `xmlrpc` bloqueado, freio no `wp-login`.
- **Site de vendas:**
  - `.env`, `.git`, `wp-config` de backup, `error_log` e `debug.log` não saem (403/406);
  - sem listagem de pastas;
  - registro de usuário fechado;
  - só 1 usuário com conteúdo publicado.
- **Imagens do app:** `node:22.22.2-alpine` com versão fixa; dependências de produção sem aviso.
- **Registros `send`, `rsend` e `resend._domainkey`:** criados em 29/09, no dia em que o Resend foi configurado.
  Parecem ser dele; confirmar no painel do Resend.

## Nota sobre as funções da agência no Supabase

Há 15 Edge Functions da agência ativas (9 sem a checagem de JWT do Supabase) e 3 tarefas que chamam três delas a cada
minuto. A revisão de 24/10 não as tinha olhado. A análise do código está em `05-supabase-funcoes-agencia.md`.
