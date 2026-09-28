# Chamado para a AZAN (hospeda.info) — liberar o Cloudflare

Abrir no painel da AZAN, em Suporte > Abrir chamado, departamento técnico.

**Assunto:** crystalnowpp.com.br — liberar faixas de IP do Cloudflare e ler o IP real do visitante

**Mensagem:**

Olá. O domínio crystalnowpp.com.br (conta cPanel no servidor jupiter) passou a
usar o Cloudflare como DNS e, nos próximos dias, vai passar a usar o Cloudflare
também como proxy na frente do site. A hospedagem continua com vocês. Para isso
funcionar sem bloqueios, pedimos duas configurações no servidor:

1. Liberar no firewall (ModSecurity, Imunify360, CSF ou o que estiver em uso)
   todas as faixas de IP publicadas em https://www.cloudflare.com/ips/, IPv4 e
   IPv6. Com o proxy ligado, todo o tráfego do site chega desses IPs, e não
   podemos ter bloqueio automático nem limite de conexões sobre eles.
2. Configurar o LiteSpeed para usar o IP real do visitante enviado no cabeçalho
   `CF-Connecting-IP`, confiando nesse cabeçalho só quando a conexão vier das
   faixas do Cloudflare (opção "Use Client IP in Header" = "Trusted IP Only",
   com as faixas do Cloudflare na lista de IPs confiáveis).

Não é preciso mudar DNS, certificado nem nada no cPanel da conta. Por favor,
confirmem quando as duas configurações estiverem aplicadas.

Obrigado.
