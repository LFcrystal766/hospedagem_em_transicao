Você vai preparar os acessos da migração do site crystalnowpp.com.br. Ele sai da hospedagem AZAN (painel hospeda.info, cPanel no servidor jupiter.servidor.net.br) para a Hostinger, com o Cloudflare na frente. Outra sessão do Claude, na nuvem, executa a migração. Ela precisa das credenciais abaixo. Seu trabalho é criar essas credenciais nos painéis que já estão abertos e logados no meu computador, e abrir um chamado na AZAN.

Faça tudo sem me pedir para executar passos. Peça só acesso a apps e sites, e confirmação quando uma regra abaixo mandar.

## Regras que não podem ser quebradas

- Não altere DNS em lugar nenhum: nem na zona da AZAN, nem no Cloudflare, nem os servidores DNS no Registro.br.
- Não ligue a nuvem laranja nem mude configurações da zona no Cloudflare. Só mexa em API Tokens.
- Não cancele, não pague e não mude plano de nada.
- Nunca mostre um token, chave ou senha no chat. Nem parcialmente.
- Cada segredo criado vai direto para o destino descrito em "Onde guardar". Se não conseguir, pare e me diga em qual passo travou.

## Onde guardar cada segredo

Destino principal: as variáveis de ambiente do ambiente de nuvem do Claude Code que usa o repositório LFcrystal766/hospedagem_em_transicao. Em claude.ai/code, abra o menu do ambiente, clique em Edit e adicione cada variável com o nome exato indicado em cada tarefa.

Se esse caminho não existir ou não aceitar edição, salve num arquivo de texto no meu computador, em Documentos/crystal-migracao/.env.local, uma variável por linha, no formato NOME=valor. Depois me diga só o caminho do arquivo.

## Tarefa 1 — Cloudflare: corrigir e trocar o token

O token de conta atual (id 856e07e65b984fe5ffb01451bfa3e49e, conta a938d629ec1d8ac1f21e77e8723ac514) vazou num chat e não tem permissões suficientes.

1. Em dash.cloudflare.com, abra Manage Account > Account API Tokens e edite esse token. Se não achar, crie um novo com o nome claude-crystal-migracao.
2. Em Zone Resources, deixe incluída a zona crystalnowpp.com.br.
3. Garanta estas permissões de zona. Se um nome aparecer um pouco diferente no painel, use o equivalente:
   - Zone: Edit
   - DNS: Edit
   - Zone Settings: Edit
   - SSL and Certificates: Edit
   - Config Rules: Edit
   - Transform Rules: Edit
   - Cache Settings (Cache Rules): Edit
   - Managed headers: Edit
   - Zone WAF: Edit
   - Single Redirect: Edit
   - Bot Management: Edit
   - Page Rules: Read
   - Zaraz: Read
   - Analytics: Read
   - Cache Purge: Purge
4. Validade até 31/12/2026.
5. Salve e faça Roll do token, para o valor antigo parar de funcionar. Se criou um token novo, apague o antigo.
6. Guarde CLOUDFLARE_API_TOKEN com o valor novo e CLOUDFLARE_ACCOUNT_ID=a938d629ec1d8ac1f21e77e8723ac514.
7. Confira se a conta tem autenticação em dois fatores ligada em My Profile > Authentication. Não ligue você mesmo, porque precisa do meu celular. Só me diga se está ligada ou desligada.

## Tarefa 2 — AZAN (hospeda.info e cPanel)

1. No cPanel da conta onde está o crystalnowpp.com.br, abra Segurança > Gerenciar tokens da API e crie um token com o nome claude-migracao e validade de 90 dias.
2. Guarde CPANEL_AZAN_HOST=jupiter.servidor.net.br, CPANEL_AZAN_USER com o usuário do cPanel e CPANEL_AZAN_TOKEN com o token.
3. Na área do cliente da hospeda.info, veja a data de vencimento da próxima fatura do plano. Só leia, não pague.
4. Abra um chamado de suporte técnico com o texto abaixo, sem mudar nada. Anote o número do chamado.

Assunto: crystalnowpp.com.br — liberar faixas de IP do Cloudflare e ler o IP real do visitante

Mensagem:
Olá. O domínio crystalnowpp.com.br (conta cPanel no servidor jupiter) passou a usar o Cloudflare como DNS e, nos próximos dias, vai passar a usar o Cloudflare também como proxy na frente do site. A hospedagem continua com vocês. Para isso funcionar sem bloqueios, pedimos duas configurações no servidor:
1. Liberar no firewall (ModSecurity, Imunify360, CSF ou o que estiver em uso) todas as faixas de IP publicadas em https://www.cloudflare.com/ips/, IPv4 e IPv6. Com o proxy ligado, todo o tráfego do site chega desses IPs, e não podemos ter bloqueio automático nem limite de conexões sobre eles.
2. Configurar o LiteSpeed para usar o IP real do visitante enviado no cabeçalho CF-Connecting-IP, confiando nesse cabeçalho só quando a conexão vier das faixas do Cloudflare (opção "Use Client IP in Header" = "Trusted IP Only", com as faixas do Cloudflare na lista de IPs confiáveis).
Não é preciso mudar DNS, certificado nem nada no cPanel da conta. Por favor, confirmem quando as duas configurações estiverem aplicadas.
Obrigado.

## Tarefa 3 — WordPress do crystalnowpp.com.br

1. Em crystalnowpp.com.br/wp-admin, abra Usuários > Perfil do usuário admin.
2. Em Senhas de aplicativo, crie uma com o nome claude-migracao.
3. Guarde WP_APP_USER=admin e WP_APP_PASSWORD com a senha gerada.
4. Não troque a senha do admin. Só me lembre, no resumo final, que ela precisa ser trocada.

## Tarefa 4 — Stape

1. Em stape.io, abra o nome da conta > Account settings > API Keys e crie uma chave com o nome claude-migracao-leitura.
2. Guarde STAPE_ACCOUNT_API_KEY com o valor. A chave aparece uma vez só, então guarde na hora.
3. Não mexa em containers, domínios nem configurações do Stape.

## Tarefa 5 — Registro.br (só com minha confirmação)

O e-mail de contato do titular (contato LFMPI73) é admin@leticiafelisberto.com, que depende da AZAN. Ele precisa ir para uma caixa fora da AZAN.

1. Antes de mudar, me pergunte qual e-mail usar.
2. Com o e-mail confirmado, troque só o e-mail do contato LFMPI73 e siga a confirmação que o Registro.br mandar.
3. Não toque nos servidores DNS do domínio.

## Resumo final

No fim, me mande uma lista curta com uma linha por tarefa: feito, parcial ou travado, e o motivo quando não estiver feito. Inclua:
- os nomes das variáveis guardadas, sem os valores;
- a data da próxima fatura da AZAN;
- o número do chamado;
- se o 2FA do Cloudflare está ligado;
- o lembrete de trocar a senha do admin do WordPress.
