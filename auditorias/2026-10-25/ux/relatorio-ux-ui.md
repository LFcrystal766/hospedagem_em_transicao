# Relatório de UX/UI da Crystal · 25/10/2026

Para: Luiz (dono), Igor (dev), Gisele (admin), Bia (suporte).
Base: código em `3c343df` (branch `painel/onda6-custo-aluno-2`, a revisão de segurança, pronta e não publicada), 104 capturas reais
do app e do painel em modo de demonstração, 143 achados brutos revisados um a um.
Depois de juntar os achados repetidos entre lentes, sobraram **98 achados distintos**
(10 altos, 65 médios, 23 baixos). Capturas em `capturas/`. PRD de execução, com as mesmas três ondas e os mesmos números: `docs/ux/PRD-ux-ui-2026-10-25.md` no repositório do app (58 itens, U01 a U58).

---

## 1. Resumo em 10 linhas

1. **App da aluna: nota 7 de 10.** A conversa é boa: cara de WhatsApp, bolhas curtas, áudio e print funcionam, tema claro e escuro. O que falha é o entorno: entrar (código que não chega sem saída), errar (uma frase só para cinco causas), esperar (sem "digitando…" nos primeiros segundos) e pedir ajuda (a Crystal manda para "Menu > Suporte", e o menu não tem Suporte).
2. **Painel da equipe: nota 6,5 de 10.** No computador o kit é sólido e as ações sem volta são bem protegidas. No iPhone, que é onde o dono opera, todo campo dá zoom, as telas mais usadas têm 7 a 10 telas de rolagem sem índice, a sessão vencida cai no login da aluna e não existe "Sair".
3. **Problema 1:** a aluna vê "Não consegui terminar minha resposta" para saldo zerado, modelo vazio, áudio sem transcrição e queda de rede, e fica sem "digitando…" até o modelo começar (UX-17, UX-16). É o atrito mais frequente: vale para cada uma das ~111 mil respostas.
4. **Problema 2:** "Menu > Suporte" não existe na tela (UX-15). A dúvida mais comum fora da paquera (aulas, pagamento, reembolso) termina em beco sem saída.
5. **Problema 3:** quando o código de login não chega (3 casos reais em 2 dias), a tela não dá saída nem dica para Hotmail/Outlook (UX-01).
6. **Problema 4:** os telefones de ajuda em crise (188, 180, 190, 192) chegam como texto que não dá para tocar (UX-18). É a situação de maior consequência do produto.
7. **Problema 5:** no painel, a sessão da equipe vencida cai no login da aluna, onde o e-mail da equipe "não existe" (UX-90); e todo campo de 14–15 px faz o Safari do iPhone dar zoom (UX-58). Logo atrás: trocar o modelo sem ver o salto de custo (UX-116) e sete pares de cor abaixo do mínimo de contraste (UX-43).
8. **O que está bom e não se mexe:** a cara de WhatsApp da conversa (papel de parede, tiques, status no topo, áudio com segurar e deslizar), a tela de início com três botões iguais e a Crystal como contato, a tela de Suporte com dois cartões, o login só com e-mail e código, o tutorial em três partes (só enxugar), a alma da Crystal e os blocos fixos de segurança.
9. **No painel, manter:** o kit (lista vira cartão no celular, filtros em folha com a URL, CPF sempre mascarado), a confirmação forte com palavra digitada e código por e-mail, o "Enviar teste para mim" com prévia dupla, e o 404 no lugar de 403.
10. **Caminho:** três ondas, as mesmas do PRD de execução. A U-onda 1 junta ganhos rápidos, acessibilidade e os erros da conversa e do login (7 dos 10 altos e 22 dos 40 ganhos rápidos, de esforço P e impacto alto ou médio); a U-onda 2 é painel e suporte (os outros 3 altos e 14 ganhos rápidos); a U-onda 3 é início, consistência visual e design system, com o primeiro acesso enxuto (4 ganhos rápidos). Nenhuma proposta mexe na alma.

---

## 2. Método

**O que foi olhado**

- Código do monorepo em `3c343df`, só leitura: telas, textos (microcopy), API, testes de ponta a ponta.
- 104 capturas reais, feitas em 25/10 com o app em modo de demonstração (usuários fictícios, respostas fixas, sem modelo de IA), em 390×844 (iPhone) e 1280×800 (computador), tema claro e escuro.
- Documentos do produto: PRD de otimização, PRD do painel, ondas 1 a 6.1, consultoria de 20/10, revisão de segurança de 24/10, reclamações reais registradas de 05 a 24/10 (sem nomes).
- Dez lentes, cada uma com um revisor e um mapa próprio: primeiro acesso, conversa, início/menu/suporte, acessibilidade, mobile, microcopy, navegação do painel, fluxos do suporte, dados/configuração, consistência visual.
- Verificação adversarial: cada achado foi conferido de novo contra o código e as capturas por outro revisor. Nenhum caiu por inteiro; vários tiveram evidência corrigida (linha errada, afirmação só parcial, contraste recalculado) e a proposta ajustada. Onde a proposta depende de decisão do dono, está escrito "(OK do dono)".
- Agrupamento: 45 IDs eram o mesmo problema visto por lentes diferentes. Cada grupo ficou com um ID principal e os irmãos entre parênteses. A severidade do grupo é a maior entre os membros; o esforço é o do principal.

**Limites**

- Sem teste com alunas reais e sem métricas de uso: a gravidade vem da frequência da tela, das reclamações registradas e do custo de errar, não de medição.
- Capturas em modo de demonstração: o login aparece com CPF (o modo real, só e-mail, não roda no ambiente de teste, ver UX-72); a base e as fichas aparecem com erro por falta de banco.
- Sem Android na equipe (pendência 15 do PRD do painel): o que foi medido em 390 px vale para o iPhone do dono; Samsung Internet e Chrome do Android não foram vistos em aparelho.
- Esforço P/M/G é estimativa de implementação pelo Igor, na mesma escala do PRD: P até meio dia, M até três dias, G uma semana ou mais.

---

## 3. Achados por área

Legenda das tabelas: ID principal (irmãos entre parênteses) · Severidade · Problema · Proposta · Esforço · Captura.

### 3.1 Aluna · Primeiro acesso (login, tutorial, perfil, instalação)

O caminho real da aluna nova tem oito camadas antes da primeira mensagem: login em dois passos (com a caixa da política depois do código), tutorial parte 1 com três balões, aceite de dados sensíveis, tutorial parte 2, formulário de cinco perguntas, tutorial parte 3 com três balões, folha "Ative as notificações" e a faixa "Instale o app" que nunca sai. Cada peça faz sentido sozinha; juntas, viram carga. O momento mais frágil é o passo do código: três casos reais de "não chegou" em dois dias (Hotmail/Outlook), e a tela não oferece saída. As capturas mostram o modo CPF do ambiente de teste; em produção o login é só e-mail.

| ID | Sev. | Problema | Proposta | Esf. | Captura |
|---|---|---|---|---|---|
| UX-01 | Alta | Código que não chega: o passo 2 não tem saída para o suporte nem dica para Hotmail/Outlook; "Reenviar" num desafio sem e-mail diz "reenviado" sem nada sair | Bloco "Não chegou?" visível quando o reenvio libera: olhar spam, "Trocar o e-mail", botão "Falar com o suporte" com mensagem pronta (sem o e-mail), aviso para domínios da Microsoft (OK do dono no botão: S12 era "o Luiz cuida"; padrão do PRD: entra) | P | aluna-login-codigo-390.png |
| UX-02 | Média | Pedir o código de novo em 5 min devolve o mesmo desafio e a tela diz que mandou outro | A resposta marca "reaproveitado"; a tela diz "Use o código que já está no seu e-mail" e "Ele ainda vale por {mm:ss}: não precisa pedir outro" | P | aluna-login-codigo-390.png |
| UX-03 | Média | No primeiro acesso, o OK na política só aparece depois do código certo, com um segundo "Entrar"; redigitar gasta tentativa e os 5 min podem vencer no meio | Esconder o campo depois do código certo, mostrar "Código certo! Falta só o seu OK" com a caixa e "Concordar e entrar"; a API devolve a tentativa e renova o prazo | M | aluna-login-consentimento-390.png |
| UX-04 (UX-44) | Média | E-mail incompleto: só a borda fica vermelha, sem frase; o botão nasce apagado e parece quebrado | Botão sempre ativo; ao tocar, frase sob o campo ("Esse e-mail parece incompleto. Confere se tem o @ e o ponto") ligada ao campo para leitor de tela | P | aluna-login-390.png |
| UX-05 (UX-76) | Média | Passo do código: três parágrafos com "se", dois relógios (05:00 e 60 s) e "Voltar" sem dizer para onde | Título "Agora olha o seu e-mail"; um relógio só, visível no último minuto; "Voltar" vira "Trocar o e-mail" com o campo preenchido | P | aluna-login-codigo-390.png |
| UX-69 (UX-06) | Média | "Reenviar código" e "Voltar" são links de ~20 px lado a lado; a rota /login fica fora da regra de 44 px e da auditoria | Os dois viram botões de 44 px em linha; o cartão do login entra na regra `.mobile-controls` | P | aluna-login-codigo-390.png |
| UX-07 | Média | Tutorial parte 1: três balões antes de qualquer ação (Suporte e Crystal travada repetem o que está na tela); "Pular" some com tudo | Com perfil incompleto, um balão só ("me conta quem você é em 5 perguntas") com "Completar perfil" e "Agora não"; quem já tem perfil mantém os passos (OK do dono: ajuste do P02; padrão do PRD: fica como está) | M | aluna-tutorial-3-390.png |
| UX-08 | Baixa | O aceite sensível ocupa uma tela inteira com "Todas as respostas são obrigatórias" sem pergunta; "Excluir minha conta" já aparece no primeiro acesso | Apoio "Primeiro o seu OK; depois, 5 perguntas rápidas"; rodapé empurrado para o pé da tela, "Excluir" menor e abaixo de um divisor | P | aluna-onboarding-1-consentimento-390.png |
| UX-13 | Baixa | O balão da parte 2 foca o nome, que já vem da compra; o contador começa em "1 de 5" sem a aluna fazer nada | Focar a primeira pergunta vazia (a idade); contador por faltantes ("Faltam 4 respostas") (OK do dono no contador: o P13 cita "N de 5 respondidas"; padrão do PRD: fica como está) | P | aluna-onboarding-2-formulario-390.png |
| UX-09 | Média | Salvar o perfil não confirma nada e volta ao início; a aluna precisa perceber que "Conversa" destravou | No primeiro salvamento abrir a conversa com uma pílula "Perfil salvo. Agora é só me contar o que está rolando" (não é mensagem da Crystal; S07 intacto) | P | aluna-onboarding-2-formulario-390.png |
| UX-10 | Média | Primeira conversa: três balões cobrem a boas-vindas e, ao fechar, sobe a folha de notificações; no iPhone instalado, duas folhas | Parte 3 com um balão só e "Começar" que abre o teclado (OK do dono: ajuste do P02; padrão do PRD: fica como está); a folha de notificações espera a abertura seguinte | M | aluna-tutorial-chat-390.png |
| UX-11 | Média | Instalar no iPhone termina num login do zero, sem aviso de que isso era esperado, e pede o código de novo | Lead especial no login do app recém-instalado ("Pronto, o app está instalado! Entra de novo com o e-mail da compra, só desta vez."); aviso no guia antes de sair do Safari | M | aluna-inicio-390.png |

### 3.2 Aluna · Conversa

A conversa é o produto, e o visual acertou: bolhas curtas com rabinho só na primeira, papel de parede, tiques, status real no topo, áudio com segurar/deslizar. Os problemas estão nos momentos em que algo sai do normal. A trava de vazamento segura a resposta inteira antes de mostrar, e a tela ainda não acendeu "digitando…" nesse intervalo: a aluna acha que não foi ouvida e manda de novo, o que abre um segundo turno que não vê o primeiro. Quando a Crystal falha, cinco causas diferentes viram a mesma bolha cinza. E o caminho para a equipe, que a Crystal chama de "Menu > Suporte", não existe no menu.

| ID | Sev. | Problema | Proposta | Esf. | Captura |
|---|---|---|---|---|---|
| UX-15 (UX-28, UX-73) | Alta | A Crystal e a bolha fixa do #reset mandam para "Menu > Suporte"; o menu de três pontinhos tem Tema, Notificações, Política e Sair. Da conversa, o único caminho é voltar ao início | Item "Suporte" no menu, entre Notificações e Política, válido no início e na conversa. A fala da Crystal passa a ser verdade sem tocar na alma | P | aluna-menu-390.png |
| UX-16 | Alta | Entre enviar e o primeiro sinal do modelo não há "digitando…" (com a trava, isso vem depois de ler alma, base e histórico); depois, as pausas do ritmo somam até 8 s | Marcar "lida" (tiques azuis + "digitando…") no instante em que a Crystal recebe o turno; no painel, Ritmo: 40 → 20 ms por letra e pausa máxima 3.000 → 1.500 ms (OK do dono, sem publicar; padrão: nada muda até ele mexer no painel) | P | aluna-chat-resposta-1-390.png |
| UX-17 (UX-74, UX-75) | Alta | Saldo zerado, modelo vazio, transcrição fora, pausa pelo painel e queda de rede dão a mesma bolha "Não consegui terminar minha resposta" com "Tentar de novo"; o topo diz "fora do ar agora" em 12 px cinza e nada mais muda | Texto por causa: "Estou com um problema aqui do meu lado. Me escreve de novo daqui a alguns minutos." (sem botão), "Não consegui ouvir esse áudio agora…" (botão fica), "Nossa conversa caiu no meio. Toca em Tentar de novo que eu continuo."; faixa "Estou fora do ar agora. Tenta de novo daqui a alguns minutos." no topo quando a Crystal está fora; "em pausa" em minúscula; manutenção com um texto só | M | aluna-chat-390.png |
| UX-18 | Alta | Num turno de risco, "ligue 188", "ligue 180/190/192" e "cvv.org.br" chegam como texto puro: a aluna precisa decorar e discar | Lista fechada: só esses números viram `tel:` e só esse endereço vira link, nas bolhas da Crystal; nenhum outro link do modelo vira clicável | P | — |
| UX-19 | Média | Resposta barrada pela trava vira "Desculpa, me perdi aqui. Pode repetir?" como bolha normal, sem "Tentar de novo"; repetir à mão cai na mesma trava | Marcar a bolha neutra e oferecer o mesmo "Tentar de novo" da resposta interrompida (frase e alma intactas) | M | — |
| UX-20 | Média | Aos 2:00 o áudio é enviado sozinho, cortado no meio da frase | No limite, pausar em vez de enviar: painel com "2:00", lixeira e enviar, aviso "Chegou no limite de 2 minutos" (OK do dono: reverte uma linha do S02; padrão do PRD: para e espera) | P | aluna-chat-compositor-390.png |
| UX-21 | Média | Foto ou áudio que falhou some sem aviso quando a aluna fecha o app; texto, não | Guardar no aparelho o arquivo que falhou por rede (não o recusado), recriar a bolha ao reabrir e tentar sozinho; teto de 5 arquivos | M | — |
| UX-22 | Média | Mensagem enviada enquanto a Crystal escreve vira turno que não vê a resposta anterior; as respostas chegam intercaladas | Na API, enfileirar por conversa (espera a geração anterior, teto de 20 s); a tela mostra um tique até "entregue" | M | aluna-chat-390.png |
| UX-23 | Média | A faixa de backup diz "O WhatsApp está instável" num app que vira o canal principal; até três faixas podem empilhar | Texto "Estou te atendendo por aqui, no app"; padrão de backup desligado; uma faixa só por prioridade (manutenção > backup > recado) | P | — |
| UX-24 | Média | Recomeçar a conversa só existe digitando "#reset"; ninguém descobre | Item "Recomeçar a conversa" no menu da conversa, com diálogo "Eu esqueço o que a gente conversou até aqui…" e "Recomeçar" (mesmo caminho do #reset) (OK do dono: item novo no menu do P17; padrão do PRD: entra) | P | aluna-menu-390.png |
| UX-25 | Média | O aviso de microfone recusado fica fixo acima do campo e manda a "ajustes do navegador" | Botão de fechar no aviso; texto por aparelho (Ajustes do iPhone, botão AA do Safari, cadeado do Chrome) (conferir no iPhone do dono) | P | aluna-chat-compositor-390.png |
| UX-26 (UX-77, UX-79) | Baixa | Erros de imagem com jargão ("JPG, PNG ou WebP", "5MB"); "a contagem volta a zero no domingo" soa como perda; tutorial promete "três opções" | "Isso não é uma imagem. Me manda um print da tela ou uma foto da galeria?"; "Suas imagens desta semana acabaram. No domingo libera de novo"; tutorial nomeia o clipe sem prometer número | P | aluna-chat-compositor-390.png |

### 3.3 Aluna · Início, menu e suporte

A tela de início é simples e certa: foto, nome, três botões do mesmo tamanho, a Crystal como contato. O menu de três pontinhos é curto, e é por isso que "Sair" sem confirmação pesa: um toque errado custa um código novo por e-mail. A tela de Suporte está boa, mas o texto a restringe a "app ou acesso", quando é para lá que devem ir dúvidas de aula, pagamento e reembolso. As páginas legais abertas pelo menu só têm "Voltar" no fim de 8 a 10 mil pixels, e os Termos ainda mostram uma nota de rascunho jurídico.

| ID | Sev. | Problema | Proposta | Esf. | Captura |
|---|---|---|---|---|---|
| UX-29 | Média | Suporte diz "ajuda com o app ou com seu acesso"; a mensagem pronta do WhatsApp também. A aluna com dúvida de aula ou pagamento não se reconhece | Lead "Dúvida sobre o curso, as aulas, seu acesso, pagamento ou o app? Fale com a nossa equipe"; mensagem pronta neutra; assunto do e-mail idem | P | aluna-suporte-390.png |
| UX-30 (UX-80) | Média | "Sair" é o último item do menu e age no primeiro toque; voltar exige código novo (teto diário; Outlook às vezes não recebe) | Diálogo "Sair do app?" com "Para entrar de novo, você vai precisar de um código novo no seu e-mail", botões "Ficar" (foco) e "Sair" | P | aluna-menu-390.png |
| UX-31 (UX-132) | Média | Folha Notificações: o texto diz "este navegador não recebe" e, abaixo, um controle ligado; o interruptor é uma caixa de marcar esticada; carregando mostra "…" | Separar "Neste aparelho" (estado e passo que resolve) de "Na sua conta" (interruptor desenhado, "Ligado/Desligado"); um só interruptor para app e painel | P | aluna-notificacoes-390.png |
| UX-32 | Média | O pedido de notificações vende "aulas e ofertas"; o aviso mais frequente é a resposta da Crystal com o app fechado | Texto "Assim você sabe na hora quando a Crystal responde, mesmo com o app fechado…"; "ofertas" sai do título do interruptor | P | — |
| UX-33 | Média | A folha de notificações pode subir no início antes de a aluna salvar o perfil, sem contexto | Só pedir depois que a conversa destravou e a parte 3 do tutorial passou; daí em diante a cada abertura, como hoje (S27 mantida) | P | — |
| UX-34 | Média | Excluir conta: um toque num botão vermelho, até 90 s sem dizer que demora; o link no rodapé é igual ao "Ver o tutorial de novo" | Caixa "Entendi que não dá para desfazer" antes de liberar o botão; "Pode levar até um minuto. Não feche o app"; link separado por divisor e com outra cara | P | aluna-perfil-390.png |
| UX-35 | Média | Política, Termos e Excluir conta abrem sem cabeçalho do app nem seta; o único "Voltar" é um link no fim de 7.600 a 10.000 px | Moldura comum das páginas públicas com seta de voltar de 44 px no topo e título | P | aluna-privacidade-390.png |
| UX-36 | Média | Textos públicos defasados: "entre com CPF e e-mail", "metas, progresso e insights"; os Termos abrem com "não deve ser considerado vinculante" e "campos marcados 👤" (nota para o dev) | Trocar palavra por palavra pelo login atual e pelo que o app guarda de fato; uma caixa só "Estes Termos ainda estão em revisão" (texto legal: a confirmar com o dono, S18; padrão do PRD: só a página de exclusão, o painel e a API) | P | aluna-excluir-conta-390.png |
| UX-37 (UX-12) | Média | Faixa "Instale o app": botão de 36 px e texto verde sobre branco em 3,14:1 (mínimo 4,5) | Botão de 44 px e verde mais escuro só na tinta do botão (novo token), faixa igual | P | — |
| UX-38 (UX-55, UX-137) | Média | Erro crítico (o caso dos iPhones antigos) sai sem estilo: página branca, botão índigo de 40 px, sem suporte; splash e offline só têm o escuro | Estilos próprios na tela de erro (cores da marca, 44 px, link para o suporte); splash e offline continuam escuros (decisão registrada), com teste que confere as cópias das cores do tema | P | — |
| UX-39 | Baixa | A foto do início é botão sem pista (nada de câmera); com perfil incompleto, tocar muda de tela sem explicar | Selo de câmera sobre a foto quando o perfil está completo; sem perfil, a foto não é botão | P | aluna-inicio-390.png |
| UX-40 | Baixa | "Pular" esconde o tutorial para sempre; só volta por um link cinza no fim do perfil; a tela de Suporte não ensina nada do app | "Ver de novo" também reabre a parte da conversa; na tela de Suporte, abaixo da nota, o botão de texto "Ver o tutorial de novo" (sem cartão novo: os dois cartões do S25 ficam) | M | aluna-perfil-390.png |
| UX-41 | Baixa | Pontinhos do carrossel com 36 px de largura | Área de toque de 44 px (o ponto desenhado não muda) | P | — |

### 3.4 Painel · Navegação (moldura, barra, cabeçalho, sessão)

No computador, a barra lateral em três grupos funciona. No celular, a moldura cobra caro: o cabeçalho gasta duas linhas com Tema, Minha senha e Ir para o chat, não existe "Sair", a barra inferior é igual para todo papel (Suporte fixo; Crystal e Laboratório atrás de "Mais") e, ao rolar, nada diz em que tela a pessoa está. Dois casos trancam a equipe de verdade: a sessão vencida cai no login da aluna, que por segurança não tem link para a entrada da equipe, e o 404 dentro do painel manda para o início da aluna.

| ID | Sev. | Problema | Proposta | Esf. | Captura |
|---|---|---|---|---|---|
| UX-90 (UX-112) | Alta | Sessão vencida (14 dias sem uso) leva ao login da aluna, onde o e-mail da equipe responde "não encontrado"; endereço errado ou área sem permissão mostra o 404 da Crystal com "Voltar para o início" da aluna | Quem já entrou como equipe cai em `/login/equipe?sessao=expirada` com a faixa "Sua sessão da área da equipe expirou. Entre de novo com e-mail e senha."; 404 dentro da moldura do painel com "Voltar para o Início" | P | equipe-404-1280.png |
| UX-89 (UX-59, UX-143) | Média | Não existe "Sair" na área da equipe (o caminho é ir ao chat da aluna); Tema (um select nativo, diferente do menu da aluna), Minha senha e Ir para o chat gastam uma linha inteira (~105 px) em toda tela do celular | Cabeçalho de uma linha com botão-avatar de 44 px que abre a folha "Sua conta": Tema (três opções, igual ao app), Minha senha, Abrir o app e Sair | M | equipe-inicio-390.png |
| UX-91 (UX-68) | Média | Toda abertura direta do painel (recarregar o PWA, tocar numa notificação) é tela branca até a sessão ser conferida; alimenta a fama de "às vezes não carrega" | Marca pulsando com "Um instante…" enquanto a sessão é conferida (nada do painel aparece antes, para quem não é da equipe não deduzir a área); depois de 8 s, "Está demorando mais que o normal. Confere a internet." com Tentar de novo | P | equipe-inicio-390.png |
| UX-88 (UX-60) | Média | Barra inferior igual para todo papel: Suporte fixo (caixa que nunca recebe nada), Crystal e Laboratório a dois toques atrás de "Mais" para o dono | Barra por papel: admin vê Início, Alunos, Mensagens, Crystal; suporte vê Início, Alunos, Mensagens, Suporte; link "Abrir o Laboratório" na tela Crystal (OK do dono: muda o princípio 2 do PRD do painel; padrão do PRD: só a folha "Mais" é reagrupada) | P | equipe-mais-390.png |
| UX-98 | Média | No celular o cabeçalho rola para fora; em telas de 7 a 16 mil px (Crystal, Configurações, Métricas) só resta a barra inferior marcando "Mais" | Barra fixa de 44 px no topo, só no celular, com o nome da tela e o "voltar" quando houver | M | equipe-crystal-390.png |
| UX-93 | Média | O Início é só leitura: "Conversaram hoje" não abre nada, cada envio em "Últimos envios" não é link, o aviso de reembolso leva à lista inteira | Bloco "Atalhos" por papel (Buscar aluno, Liberar acesso, Nova conta, Nova mensagem, Crystal, Laboratório); todo cartão e todo item com link para o filtro certo | M | equipe-inicio-suporte-1280.png |
| UX-95 | Média | Ficha: sem "Voltar" na tela normal, aba fora da URL (um link do Início não chega na aba certa), toda ficha se chama "Alunos · Crystal" na janela; cinco jeitos de voltar no painel | "← Alunos" acima do cabeçalho da ficha e o mesmo padrão nas outras sub-rotas; aba na URL (`?aba=`); título da janela com o nome do aluno | P | equipe-ficha-390.png |
| UX-96 (UX-126, UX-83) | Média | Menu diz "Equipe", a tela diz "Usuários — Alunos e equipe no mesmo lugar"; o papel oferece "Aluno"; criar conta exige CPF (inútil para login por senha) e a senha é definida em outro lugar; textos da Base mandam para "aba Contas no app", que não existe | Título "Equipe"; só papéis de equipe, com a linha "Suporte vê: Início, Alunos…"; CPF opcional; criar conta já abre "Definir senha"; textos apontam para "aba Alunos" | M | equipe-usuarios-1280.png |
| UX-99 | Baixa | A folha "Mais" lista nove itens por grupo, não por uso: "Ajustar" mistura Crystal, Laboratório, Configurações, Integrações, Financeiro e Equipe | Grupos Operar / Crystal / Entender / Ajustar; Financeiro vai para Operar; Crystal e Laboratório sobem | P | equipe-mais-390.png |

### 3.5 Painel · Fluxos do suporte (Bia, Gisele, Luiz no celular)

O atendimento mais comum é "não consigo entrar". Hoje ele exige saber que existem duas buscas (contas do app e base da compra), chegar à quarta aba da ficha para ver as tentativas de entrada e, no celular, descobrir que a faixa de abas rola (a quarta aparece como um "S" cortado). As ações sem volta estão bem protegidas pelo código por e-mail, mas o diálogo não diz quanto o código vale nem que há teto de 4 em 15 minutos, e no iPhone os botões ficam atrás do teclado. A caixa de entrada do Suporte ocupa lugar fixo na barra e está sempre vazia: a aluna não abre pedido pelo app e a equipe não tem como registrar um.

| ID | Sev. | Problema | Proposta | Esf. | Captura |
|---|---|---|---|---|---|
| UX-92 (UX-103) | Alta | A busca em Alunos só olha quem já entrou no app; quem só comprou está na aba "Base de alunos", e o vazio diz "Nenhum aluno com esses filtros" sem nenhum botão. O cartão da base não leva à ficha | Vazio com "Não achei {busca} entre os alunos do app." + botão "Buscar na base de alunos" (leva o termo, sem pôr na URL) + "Liberar acesso manual" se for e-mail; cartão da base com "Abrir a ficha no app" quando há conta | M | equipe-alunos-390.png |
| UX-102 | Média | Para ver por que a aluna não entra: Alunos → buscar → nome → rolar as abas até "Aparelhos e sessões" → rolar até "Tentativas de entrada" (5 toques); o Resumo não explica a causa | Bloco "Entrada no app" no topo do Resumo com as 3 últimas tentativas e a frase de ação ("O código saiu e a pessoa não entrou. Se é Outlook ou Hotmail…" + botão "Corrigir e-mail") | M | equipe-ficha-390.png |
| UX-62 (UX-51, UX-106) | Média | Oito abas roláveis na ficha (e nas Métricas) sem sinal de que há mais à direita; a quarta aparece cortada; aba trocada por código não rola até ela | Degradê de "há mais" nas pontas enquanto houver conteúdo escondido; a aba ativa rola para a vista; rótulo curto "Aparelhos" no celular | P | equipe-ficha-390.png |
| UX-101 | Média | Diálogo do código não diz para qual e-mail antes de enviar, nem que vale 10 min, nem o teto de 4 em 15 min; no 5.º pedido, "espera um minutinho" que nunca resolve | "Mandamos um código para {e-mail}. Vale 10 minutos. Código 2 de 4"; ao estourar, "Dá para pedir outro em {m} min" com contagem | M | equipe-ficha-dialogo-codigo-390.png |
| UX-63 | Média | No iPhone a folha do diálogo não trata o teclado: ao focar "Motivo" ou "Código", os botões ficam atrás dele; num iPhone pequeno o título some para cima | Folha com altura da área visível (visual viewport); só o corpo rola; rodapé com os botões sempre visível | M | equipe-ficha-dialogo-codigo-390.png |
| UX-52 (UX-111) | Média | Desligar, Nova conta e Liberação manual: o select obrigatório abre com uma linha em branco e o botão fica cinza sem dizer o que falta | Opção "Escolha…" desabilitada no lugar da linha vazia; linha "Falta: motivo" sob o botão travado | P | — |
| UX-105 | Média | Folha "Ações" com até 12 itens sem grupo; "Apagar dados" em vermelho só troca de aba; "Revogar sessões" vira "Encerrar todas" no diálogo | Grupos Cadastro / Conta / Equipe / Dados do aluno; "Encerrar sessões" nos dois lugares; "Pedidos e dados do aluno" sem vermelho | P | equipe-ficha-acoes-1280.png |
| UX-61 | Média | A barra "N selecionados" (Enviar mensagem, Exportar CSV) fica atrás da barra de abas no celular; só aparece ao rolar até o fim | Barra grudada acima da barra de abas, uma linha, botões de 44 px com rótulo curto | P | equipe-alunos-390.png |
| UX-109 (UX-122) | Média | Nenhuma ação tem "Desfazer" (Desligar, Silenciar, Encerrar, interruptores de Configurações gravam no toque); o toast de 4 s não pausa no toque e não aceita botão | Toast com botão "Desfazer" e "Fechar", 8 s, pausa no toque; aplicar em Desligar/Religar, Silenciar, Encerrar ticket, interruptores e listas de Configurações | M | — |
| UX-110 | Média | Suporte manda mensagem a uma aluna em 4 passos; "Público" já vem preenchido e "Quando" tem uma opção só (7 toques) | Passos por papel: para o suporte com aluna definida, só Conteúdo e Revisar ("Passo 1 de 2") | M | — |
| UX-97 (UX-107) | Média | A caixa de entrada do Suporte nunca recebe nada (a aluna fala por WhatsApp e e-mail; a ação "Abrir pedido" existe no texto e não está ligada); o atendimento real não deixa rastro na ficha; a 390 px o rótulo quebra em "AGUARDAND / O ALUNO" | Rota para a equipe registrar um pedido (origem WhatsApp/e-mail) a partir de Ações da ficha; cartões em 2 colunas no celular com rótulos curtos ("Aguardando", "Meus") | M | equipe-suporte-bia-1280.png |
| UX-64 | Média | Nova mensagem no celular: rodapé fixo + barra de abas + toast tomam ~200 px do fundo; com teclado sobram ~250 px para escrever | Rodapé de uma linha (Voltar / Continuar); no passo 4, "Enviar teste" em cima e Voltar/Enviar embaixo; frase do teste vira aviso só ao tentar enviar sem teste; toast no topo (esconder a barra inferior nesse fluxo só com OK do dono; padrão do PRD: não) | M | equipe-mensagens-390.png |
| UX-104 | Baixa | Cabeçalho diz "14 alunos" e a lista "15 alunos nesta lista" (uma é conta de revisão da loja) | Um contador só, por busca e filtro; contas de revisão fora por padrão (OK do dono; padrão do PRD: ficam fora) | P | equipe-alunos-390.png |
| UX-108 | Baixa | Ticket: trocar responsável ou categoria grava no toque; "Encerrar" sem confirmação; "Ticket atualizado" fica para sempre; caixa de resposta dá zoom | Toast com o valor gravado; "Encerrar este pedido?" com "Dá para reabrir"; filtros com rótulo visível; campo em 16 px | P | — |
| UX-113 | Baixa | Auditoria no celular: botão "Filtros" sem contagem nem resumo do que está aplicado (Alunos já mostra "Filtros (2)") | "Filtros (n)" e chips com os filtros ativos acima da lista | P | — |
| UX-115 | Baixa | O bloco com Importar memória, Silenciar WhatsApp e Recomeçar conversa não tem título, fica no fim do Resumo e responde com caixas rosa que nunca somem | Título "Crystal e WhatsApp", bloco logo após "Conta", sucesso por toast | P | equipe-ficha-390.png |

### 3.6 Painel · Dados e configuração (Crystal, Métricas, Configurações, Laboratório, Financeiro, Banners)

Aqui está o que o dono faz todo dia pelo iPhone: trocar modelo, ver custo, pausar, testar. A página Crystal tem 12 blocos em sete telas de rolagem sem índice, o status "No ar" é o da hora em que a página abriu, e o modelo é o décimo bloco. Dois incidentes reais (16/10 e 23/10) nasceram de troca de modelo: o salto de custo é hoje o sinal mais fraco da ficha do modelo e a confirmação é um clique. Configurações empilha 40+ chaves em dez telas, com "Chave: op_x" em cada campo. Jargão de código (SQL, superadmin, p95, TTL) aparece em erros que o dono e a gestora precisam entender sozinhos.

| ID | Sev. | Problema | Proposta | Esf. | Captura |
|---|---|---|---|---|---|
| UX-116 | Alta | Na ficha do modelo, "Não lê imagem" e "Gratuito" são avisos vermelhos, mas "+N% de custo" fica em letra pequena cinza; "Trocar o modelo?" confirma com um clique e sem o valor atual ao lado | Com +50% ou mais, aviso vermelho "Custa N% a mais: cerca de {novo}/mês contra {atual} hoje"; diálogo com "De: … / Para: …" em linhas fixas; palavra TROCAR quando o custo dobra ou o preço não é conhecido | P | equipe-crystal-1280.png |
| UX-120 | Média | Com a lista de modelos carregada, o seletor não diz quem trocou, quando, nem qual era o anterior; só "Voltar ao padrão" | Linha "Em uso: {modelo} · escolhido por {nome} em {data} · antes: {anterior}", "Ver histórico" e "Voltar para {anterior}" | P | equipe-crystal-390.png |
| UX-123 (UX-65, UX-94) | Média | Página Crystal: 12 blocos sem índice, status que não se renova, modelo no 10.º bloco; Alma, Base e Acompanhar sem navegação entre si; quatro lugares para "testar" e dois para "memória" | Status fixo no topo com recarga a cada 60 s; abas Modelo / Comportamento / Fichas / Saúde na URL; subnavegação comum entre Painel, Alma, Base, Acompanhar e Laboratório; busca no seletor de modelo | M | equipe-crystal-390.png |
| UX-121 | Média | Configurações no celular: dez telas de rolagem, "Grupo" some ao rolar, sem voltar ao topo; "Chave: op_x" em todo campo; o "Padrão" pode estar fora da faixa que a própria tela cobra | Chips fixos por grupo no celular com seções recolhíveis e contagem; chave técnica só na folha de histórico; ajuda gerada da regra real | M | equipe-configuracoes-390.png |
| UX-124 (UX-85, UX-100) | Média | Erros e rótulos falam com o técnico ("As funções app_ficha_* já estão no Supabase?", p95, TTL, dedup); "só o superadmin muda" sem dizer quem é; o cabeçalho mostra "Admin" para quatro pessoas com poderes diferentes | Primeira linha para a equipe ("Não consegui ler as fichas agora. Tenta de novo; se continuar, avisa quem cuida da técnica."), detalhe técnico recolhido; selo "Publica a alma" na tela Equipe e no cabeçalho; aviso claro quando ninguém está autorizado | M | equipe-crystal-base-1280.png |
| UX-117 (UX-70) | Média | Números dos cartões quebram no meio da palavra ("1 conversand/o", "AGUARDAND/O ALUNO") e a moeda se separa do símbolo ("R$ / 1.297,00") | Valor e unidade separados no cartão, sem quebra no número; espaço fixo entre símbolo e valor; plural tratado | P | equipe-metricas-390.png |
| UX-118 | Média | Gráficos no celular: os dois últimos rótulos de data se sobrepõem; eixo mostra "0,5" aluno quando a série é zero | Descartar o penúltimo rótulo quando não cabe; eixo inteiro nas contagens | P | equipe-metricas-390.png |
| UX-119 | Média | Não dá para tocar num ponto ou barra e ler o valor do dia; os números só existem numa tabela oculta | Toque ou teclado seleciona o ponto e mostra "04/10 · Logins: 4 · Alunos: 3" sob o gráfico; "Ver como tabela" abaixo dele | M | equipe-metricas-1280.png |
| UX-127 (UX-66) | Média | Laboratório no iPhone: lista de conversas em cima do chat (duas rolagens), campo de mensagem no fim, até sete botões de 12 px por resposta, dicas só no hover (nunca aparecem no toque) | No celular a lista vira folha; campo fixo acima da barra; por mensagem só 👍/👎 e "Mais" (folha com cada ação explicada); selo da trava abre "Por quê?" | M | equipe-laboratorio-390.png |
| UX-125 (UX-67) | Média | Financeiro é a única tela com tabela que rola de lado no celular; filtros sem rótulo; "Ver no Financeiro" da ficha perde o aluno | Lista do kit (cartão por lançamento com status em selo); filtros com rótulo visível; link da ficha já filtrado pelo aluno | M | equipe-financeiro-1280.png |
| UX-56 | Baixa | Filtros antigos (Suporte, Financeiro, Equipe) só têm a primeira opção como rótulo; no Laboratório a explicação do selo e do "Refazer" só existe no hover | Filtros com o campo do kit (rótulo acima); textos de ajuda visíveis sob os botões do Laboratório | P | — |
| UX-128 | Baixa | Criar banner com imagem termina num toast "envie a imagem" (já enviada) e ainda falta ligar e salvar de novo; cinco botões por banner quebram no celular | Interruptor "Ligar assim que criar"; toast "Banner criado e no ar"; na lista só Ligar/Desligar e Editar, o resto em "Mais" | P | equipe-banners-novo-1280.png |

### 3.7 Transversal · Acessibilidade

O público é adulto, muitas vezes com óculos de leitura e celular antigo. Os piores pares de cor estão justamente no botão que entra no app, no erro de código e na transcrição do áudio. O foco do teclado é quase invisível (importa para a Bia e o Igor no computador). O leitor de tela ouve "digitando…" até nove vezes por resposta. E não há como aumentar a letra: no app instalado não existe o "Aa" do Safari.

| ID | Sev. | Problema | Proposta | Esf. | Captura |
|---|---|---|---|---|---|
| UX-43 | Alta | Sete pares abaixo do mínimo: branco sobre o verde do "Entrar" (3,14 e 2,26), "Instalar" verde sobre branco (3,14), erro de campo do kit no escuro (3,58), erro do login (3,50), placeholder do perfil (2,95), transcrição do áudio (2,98), caixa amarela dos Termos (3,11) | Tokens de tinta mais escuros para botão verde, erro e sucesso; transcrição sem transparência; teste de contraste ampliado para pegar opacidade e telas da aluna (OK do dono no botão de entrar: verde mais escuro ou rosa; padrão do PRD: verde) | M | aluna-login-codigo-errado-390.png |
| UX-45 (UX-141) | Média | Foco do teclado: anéis rosa a 30–40% (1,2:1) e itens de menu que só mudam o fundo; nenhum botão tem estado de toque; três opacidades de desabilitado e seis anéis diferentes | Regra global de foco visível (2 px na cor da marca), estado de toque em todo botão, uma opacidade de desabilitado; guarda no CI contra anéis fora do kit | M | — |
| UX-49 | Média | Leitor de tela ouve "digitando…", "Crystal está digitando", "Crystal disse…", "online" até nove vezes numa resposta de 3 bolhas; a falha de envio passa em silêncio | Uma região viva só: "Crystal está digitando" uma vez por turno, "Crystal disse" por bolha, "Não consegui enviar" na falha | P | aluna-chat-escuro-390.png |
| UX-48 | Média | Letra fixa em 15 px (hora e tiques em 11 px); o app ignora o ajuste de texto do celular; a pinça encolhe a conversa | "Tamanho da letra" no menu (Normal, Grande, Muito grande) guardado no aparelho (OK do dono: item novo no menu do P17; padrão do PRD: entra); a pinça não é tratada como teclado | M | — |
| UX-46 (UX-71) | Baixa | Alvos de 20 a 40 px fora do que a auditoria mede: reenviar, voltar, play do áudio (40), velocidade (~26), "Tentar de novo" em texto, fechar o visor, instalar (36) | Regra de 44 px no corpo inteiro; "Tentar de novo" vira pílula com ícone; play e velocidade de 44 px | P | aluna-login-codigo-errado-390.png |
| UX-142 (UX-54, UX-27) | Baixa | "Reduzir movimento" do celular não desliga os três pontinhos (loop infinito a cada resposta), o esqueleto, o spinner nem o zoom do visor | Um bloco só no CSS que respeita a preferência: pontinhos parados, spinner mais lento, sem zoom | P | aluna-chat-resposta-1-390.png |
| UX-57 | Baixa | Entre tocar numa área e o conteúdo chegar, o leitor de tela não ouve nada; toasts longos somem em 4 s sem como segurar no celular | "Carregando…" só para leitor de tela em todo esqueleto; duração do toast pelo tamanho do texto e pausa no toque | P | — |

### 3.8 Transversal · Mobile

Os achados de celular estão espalhados pelas áreas acima (ficha, diálogos, Crystal, Configurações, Laboratório, Nova mensagem). Dois são de raiz: o tamanho da letra dos campos, que faz o Safari do iPhone ampliar a tela a cada toque, e a auditoria automática, que não roda em 390 px nem nas telas que mais quebram.

| ID | Sev. | Problema | Proposta | Esf. | Captura |
|---|---|---|---|---|---|
| UX-58 (UX-47) | Alta | Todo campo do painel tem 14 px e o e-mail do login 15 px: o Safari do iPhone dá zoom ao focar e a tela fica ampliada e deslocada (busca de aluno, motivo, código de reautenticação, texto da mensagem, senha, tema) | 16 px no celular e 14 no computador na classe única dos campos do kit; 16 px nos dois logins; teste que falha se um campo tiver menos de 16 px | P | equipe-mensagens-390.png |
| UX-72 (UX-53, UX-14) | Média | A auditoria mobile roda em 360/384/393/412 (não em 390 nem 375) e só nas rotas de primeiro nível; o login real (só e-mail), a ficha, o ticket, o envio, o banner, o Laboratório e todo diálogo aberto ficam de fora; o axe não vê estados de erro | Larguras 360/375/390/412; sub-rotas com dados do seed; diálogo aberto medido; projeto do e2e com o login só por e-mail; checagem de campo < 16 px e de elemento fixo sobre a barra | M | — |

### 3.9 Transversal · Microcopy (textos)

A regra do produto está clara: a Crystal fala "eu" na conversa; com a equipe fala o sistema. O que escapa são textos que envelheceram (CPF como chave de entrada, "Usuários"), textos da aluna que vazaram para a equipe (o código da entrada da equipe diz "Te mandei um código"), plural sem tratar e o mesmo "Cancelar" com dois sentidos. O gênero da microcopy (hoje no masculino: "chamado", "tímido", "solteiro") é decisão do dono; o público é misto.

| ID | Sev. | Problema | Proposta | Esf. | Captura |
|---|---|---|---|---|---|
| UX-82 | Média | Na entrada da equipe, a Crystal fala em primeira pessoa com quem é do suporte ("Te mandei um código"); rodapé "Conversa protegida"; Suporte, Equipe, Financeiro, Integrações e Laboratório mostram o erro de carga com a voz da aluna | Versão "equipe" do passo do código ("Mandamos um código para…"); rodapé "Área da equipe"; erros por tela em voz de sistema (sessão vencida: ver UX-90) | M | equipe-login-codigo-390.png |
| UX-84 (UX-114) | Média | CPF ainda aparece como chave de entrada: diálogo "Religar" ("volta a entrar com CPF e e-mail"), funil de login ("CPF ou e-mail não batem"), API ("Me confirma seu CPF?"), página de exclusão, Termos e Privacidade | Trocar palavra por palavra pelo login atual (e-mail + código); Termos e Privacidade como item a confirmar com o dono (S18) | P | equipe-ficha-acoes-1280.png |
| UX-86 | Média | "Cancelar" vermelho no cartão de Agendadas cancela o envio; "Cancelar" em todo diálogo só fecha; o diálogo responde "Sim, cancelar" | Botão "Cancelar envio"; diálogo "Cancelar o envio agendado?" com "Sim, cancelar o envio" / "Manter agendado"; regra: quem desfaz algo nunca se chama só "Cancelar" | P | equipe-mensagens-agendadas-1280.png |
| UX-87 | Baixa | "Vai para 1 alunos", "1 aparelhos recebem"; o alerta de integridade da auditoria nomeia uma pessoa da equipe de hoje | Função de plural única; "Avise quem cuida da técnica" | P | equipe-mensagens-390.png |
| UX-78 | Baixa | Perfil e suporte no masculino ("Como você quer ser chamado?", "fico tímido", "solteiro", "Sou aluno") para um público misto | Frases neutras ("Que nome você quer que eu use?", "sem relacionamento"); mensagem pronta "Oi, {atendente}! Faço o curso da Crystal e preciso de ajuda." (OK do dono: gênero; padrão do PRD: forma neutra) | P | aluna-onboarding-3-erro-idade-390.png |
| UX-81 | Baixa | A página sem conexão do navegador fala formal ("Confira", "tente") e a do app fala "confere", "tenta"; a aluna pode ver as duas no mesmo minuto | Mesma voz nas duas; regra de voz registrada no arquivo de textos | P | — |

### 3.10 Transversal · Consistência visual e design system

Os dois lados dividem os tokens de cor, mas não os componentes: o botão principal tem oito desenhos e duas cores (verde só no login, rosa no resto), o campo de texto cinco desenhos, o "carregando" cinco formas, nove componentes abrem algo por cima da tela com quatro véus e quatro versões de foco preso. Para a aluna isso dá sensação de app colado de partes; para o Igor, corrigir o mesmo bug em nove lugares. A documentação do design system descreve outro produto (accent rosa nos docs, amarelo no CSS).

| ID | Sev. | Problema | Proposta | Esf. | Captura |
|---|---|---|---|---|---|
| UX-130 | Média | Botão primário em oito desenhos (raio 10/12/pílula, 14 ou 16 px, peso 500/600) e duas cores de ação | Componente único de botão (primary, secondary, danger, text, cta só no login), dois tamanhos, um raio; o kit da equipe passa a usar | M | aluna-login-390.png |
| UX-131 | Média | Campo de texto em cinco desenhos (quatro raios, dois fundos, cinco anéis, três tamanhos); o perfil reimplementa o campo em vez de usar o kit | Campos do kit movidos para a pasta comum, 16 px no celular, raio igual ao botão; perfil usa o kit no tamanho grande | M | aluna-perfil-390.png |
| UX-139 | Média | "Deu errado" em duas cores (amarelo no kit e no perfil, vermelho no login e sob os campos); dez moldes copiados; vermelho em 12–14 px no escuro fica em 3,5:1 | Componente de aviso com tons info / atenção / erro / sucesso e tokens com contraste; erro de carga é atenção, erro de campo é erro | M | aluna-login-codigo-errado-390.png |
| UX-134 (UX-129, UX-42) | Média | "Carregando" em cinco formas: painel em branco, texto solto ("Carregando…"), esqueleto, marca pulsando, "…" na folha de notificações; telas antigas mostram erro com a voz da aluna | Regra de três estados (abrir: marca + "Um instante…"; conteúdo: esqueleto; ação: spinner no botão) e um componente de carga/erro para as telas antigas | P | equipe-laboratorio-390.png |
| UX-133 (UX-50) | Média | Nove diálogos/folhas, véus em quatro cores, quatro versões de foco preso; o visor e a prévia de imagem dizem "modal" mas deixam o Tab e o leitor de tela escaparem para a conversa atrás | Uma base só sobre o diálogo nativo (foco preso, Esc, voltar do Android, área segura); Dialog, Sheet, visor e prévia em cima dela | G | equipe-usuarios-detalhe-1280.png |
| UX-135 | Baixa | A caixa "nada aqui" foi reescrita cinco vezes; o Laboratório vazio mostra duas caixas dizendo a mesma coisa; a pílula de status tem quatro moldes | Um vazio só, com ação dentro; no Laboratório vazio, uma caixa com "Nova conversa"; um selo só | P | equipe-laboratorio-390.png |
| UX-136 | Baixa | Sem conjunto de ícones: traços de 1,1 a 2,2, avião e cadeado copiados, emoji como ícone no painel (muda por aparelho) | Arquivo único de ícones (24 px, traço 1,75), usado pelos dois lados; 👍/👎 viram ícones | M | aluna-chat-390.png |
| UX-138 | Baixa | "accent" é amarelo no CSS e rosa na documentação; cinco tokens sem uso; a pasta do design system descreve o site antigo | Renomear para "warning", apagar o que não se usa, documentação única do app | M | — |
| UX-140 | Baixa | A fonte da marca aparece no lado da aluna só na palavra "Crystal"; os títulos de Perfil e Suporte têm cara de rótulo; a marca com símbolo só no painel | Cabeçalho de página comum aos dois lados (título na fonte da marca) e bloco de marca no início | M | aluna-suporte-390.png |

---

## 4. Priorização

### 4.1 Matriz impacto × esforço (98 achados distintos)

| | **P** (até meio dia) | **M** (até três dias) | **G** (uma semana ou mais) |
|---|---|---|---|
| **Alta** (7 + 3 + 0) | UX-01, UX-15, UX-16, UX-18, UX-58, UX-90, UX-116 | UX-17, UX-43, UX-92 | — |
| **Média** (33 + 31 + 1) | UX-02, UX-04, UX-05, UX-09, UX-20, UX-23, UX-24, UX-25, UX-29, UX-30, UX-31, UX-32, UX-33, UX-34, UX-35, UX-36, UX-37, UX-38, UX-49, UX-52, UX-61, UX-62, UX-69, UX-84, UX-86, UX-88, UX-91, UX-95, UX-105, UX-117, UX-118, UX-120, UX-134 | UX-03, UX-07, UX-10, UX-11, UX-19, UX-21, UX-22, UX-45, UX-48, UX-63, UX-64, UX-72, UX-82, UX-89, UX-93, UX-96, UX-97, UX-98, UX-101, UX-102, UX-109, UX-110, UX-119, UX-121, UX-123, UX-124, UX-125, UX-127, UX-130, UX-131, UX-139 | UX-133 |
| **Baixa** (19 + 4 + 0) | UX-08, UX-13, UX-26, UX-39, UX-41, UX-46, UX-56, UX-57, UX-78, UX-81, UX-87, UX-99, UX-104, UX-108, UX-113, UX-115, UX-128, UX-135, UX-142 | UX-40, UX-136, UX-138, UX-140 | — |

Leitura: 59 dos 98 achados são P. Dez são altos, e sete deles são P. O único G (UX-133, base única dos diálogos) é trabalho de fundação e fica para a onda 3.

### 4.2 Ganhos rápidos (P, alta ou média): 40 achados

Ordem sugerida, do que mais dói para o que menos dói; entre colchetes, o item do PRD que atende. Os sete primeiros são altos. No PRD, 22 deles entram na U-onda 1 (linhas 1 a 5 e 8 a 11), 14 na U-onda 2 (linhas 6, 7, 12 e 13, todos do painel, porque usam a moldura, os tokens e a rede de testes que a onda 1 cria) e 4 na U-onda 3 (linha 14, que mexe no mesmo fluxo do primeiro acesso e do tutorial).

1. **UX-15** Suporte no menu de três pontinhos (início e conversa). [U04 · onda 1]
2. **UX-16** "Lida" e "digitando…" assim que a Crystal recebe o turno; ritmo mais curto no painel. [U07 · onda 1]
3. **UX-18** Telefones de ajuda e o endereço do CVV clicáveis nas bolhas de risco. [U08 · onda 1]
4. **UX-01** Bloco "Não chegou?" com saída para o suporte e aviso para Hotmail/Outlook. [U10 · onda 1]
5. **UX-58** Campos com 16 px no celular (painel inteiro e os dois logins). [U03 · onda 1]
6. **UX-90** Sessão vencida e 404 voltam para a entrada e a moldura da equipe. [U24 · onda 2]
7. **UX-116** Salto de custo como aviso vermelho e diálogo "De / Para" ao trocar o modelo. [U38 · onda 2]
8. **UX-05**, **UX-02**, **UX-04**, **UX-69** O passo do código inteiro: um relógio, "Trocar o e-mail", código reaproveitado explicado, e-mail incompleto com frase, botões de 44 px. [U09, U10 · onda 1]
9. **UX-23**, **UX-25**, **UX-24**, **UX-20** Conversa: faixa de backup sem "WhatsApp instável", aviso do microfone que fecha e explica, "Recomeçar" no menu, áudio de 2 min não sai sozinho. [U22, U13, U04 · onda 1]
10. **UX-29**, **UX-30**, **UX-49** Suporte com o escopo certo, "Sair" com confirmação, leitor de tela ouve a resposta uma vez. [U04, U20, U15 · onda 1]
11. **UX-34**, **UX-35**, **UX-36**, **UX-37**, **UX-38**, **UX-84** Excluir conta com trava, seta nas páginas legais, textos públicos atualizados, faixa de instalar com 44 px e contraste, tela de erro crítico com a cara do app, CPF fora dos textos de entrada. [U20, U21, U18, U01, U19 · onda 1]
12. **UX-91**, **UX-62**, **UX-61**, **UX-52**, **UX-95**, **UX-105** Painel: "Um instante…" na abertura, abas com sinal de "há mais", barra de seleção visível, "Falta: motivo", voltar e aba na URL da ficha, folha Ações em grupos. [U26, U30, U32, U31, U29 · onda 2]
13. **UX-88**, **UX-86**, **UX-117**, **UX-118**, **UX-120**, **UX-134** Barra por papel (OK do dono), "Cancelar envio", números que não quebram, rótulos dos gráficos, "quem trocou o modelo" e "voltar ao anterior", um "carregando" só. [U45, U34, U32, U42, U38, U26 · onda 2]
14. **UX-09**, **UX-32**, **UX-33**, **UX-31** Perfil salvo abre a conversa; pedido de notificações com o benefício real, no momento certo, e folha coerente. [U56, U57, U52 · onda 3]

---

## 5. Roadmap em três ondas

As ondas são as do PRD de execução (`docs/ux/PRD-ux-ui-2026-10-25.md` no repositório do app, 58 itens, U01 a U58): mesma numeração, mesmo conteúdo, mesmos números. Cada achado está no item do PRD que o atende; quando um achado tem duas partes (por exemplo, a cor do botão agora e o componente único depois), ele aparece nas duas ondas. Cada onda é uma publicação só, sem ambiente de teste (cada publicação chega a todas as alunas): imagens pelo workflow `imagens-vps` na branch da onda, `backup` e `app-subir sha-XXXXXXX` na VPS pelo dono, conferência no iPhone dele logo depois de subir e volta pela tag anterior na hora se um item falhar. A revisão de segurança (`sha-3c343df`) sobe antes da onda 1 ou junto com ela. Nenhuma onda mexe na alma nem nos blocos fixos de segurança; nenhuma pede SQL no Supabase nem mudança no n8n; na VPS, só a subida das imagens (a onda 1 leva uma migração aditiva no banco do app, a coluna `messages.neutra`, que roda na subida e não atrapalha a volta).

| Onda | Itens do PRD | Altos | Ganhos rápidos |
|---|---|---|---|
| U-onda 1 · Ganhos rápidos, acessibilidade e erros da conversa e do login | U01 a U23 | 7 (UX-01, UX-15, UX-16, UX-17, UX-18, UX-43, UX-58) | 22 |
| U-onda 2 · Painel e suporte | U24 a U47 | 3 (UX-90, UX-92, UX-116) | 14 |
| U-onda 3 · Início, consistência visual e design system | U48 a U58 | nenhum | 4 |
| **Total** | **58 itens** | **10** | **40** |

### U-onda 1 · Ganhos rápidos, acessibilidade e erros da conversa e do login

| Item | O que muda | Achados que atende |
|---|---|---|
| U01 | Cores dentro do AA: tintas de erro e sucesso, CTA verde legível, opacidade fora do texto | UX-43, UX-37, UX-12, UX-139 (tokens), UX-130 (decisão do verde) |
| U02 | Foco visível em tudo, retorno ao toque e um só desabilitado | UX-45, UX-141 |
| U03 | Nenhum campo abaixo de 16 px no toque: o iPhone deixa de dar zoom | UX-58, UX-47, UX-06 (parte do campo e da moldura), UX-131 (parte dos 16 px; a unificação é o U49) |
| U04 | O menu de três pontinhos corresponde à fala: Suporte e Recomeçar a conversa | UX-73, UX-28, UX-15, UX-24, UX-29 |
| U05 | A bolha de erro diz a causa; a tela diz que a Crystal está fora do ar | UX-74, UX-17, UX-75 |
| U06 | Resposta barrada pela trava ganha "Tentar de novo" | UX-19 |
| U07 | "Digitando…" quando a Crystal recebe a mensagem; fila por conversa | UX-16, UX-22 |
| U08 | Telefones de ajuda e cvv.org.br tocáveis na bolha da Crystal | UX-18 |
| U09 | Login, passo 1: o botão não nasce apagado e o e-mail errado ganha uma frase | UX-04, UX-44 |
| U10 | Login, passo 2: menos incerteza, um relógio, saída quando o código não chega | UX-01, UX-05, UX-76, UX-02, UX-69, UX-06 (parte dos alvos), UX-46 (parte do login) |
| U11 | O OK na política, depois do código, não custa tentativa nem prazo | UX-03 |
| U12 | Instalar no iPhone termina num login que explica por que pede de novo | UX-11 |
| U13 | Áudio: aos 2:00 a aluna decide; o erro do microfone diz onde liberar | UX-20, UX-25 |
| U14 | Foto e áudio que falharam ficam no aparelho até sair | UX-21 |
| U15 | Leitor de tela na conversa: uma região viva, e a falha de envio é anunciada | UX-49 |
| U16 | "Reduzir movimento" desliga toda animação decorativa num bloco só | UX-142, UX-54, UX-27 (parte do movimento) |
| U17 | Alvos de 44 px de largura na conversa, no carrossel e nas telas de erro | UX-27 (parte dos alvos), UX-71, UX-41 |
| U18 | Textos defasados (CPF, "metas e insights", rascunho jurídico) e voz das telas de sistema | UX-84, UX-114, UX-36, UX-81, UX-77, UX-26, UX-79, UX-78 |
| U19 | Erro crítico com a cara da Crystal; espelhos do tema conferidos por teste | UX-38, UX-55, UX-137 |
| U20 | Sair pede confirmação; Excluir conta pede "Entendi" e deixa de parecer link inofensivo | UX-30, UX-80, UX-34 |
| U21 | Páginas públicas com cabeçalho e seta de voltar | UX-35 |
| U22 | Faixa de backup sem culpar o WhatsApp; uma faixa no topo por vez | UX-23 |
| U23 | Rede de testes: login real, 390 px, sub-rotas, diálogos abertos, axe completo | UX-14, UX-72, UX-53 (e as partes de audit de UX-69, UX-46, UX-71, UX-03, UX-10) |

**Por quê:** é onde estão as reclamações reais de outubro (código que não chega, "Crystal parou", "onde ficam as aulas", "Tentar de novo" sem fim) e é o que a aluna sente na primeira semana. Os três primeiros itens (U01 a U03) criam os tokens, o foco e os campos de 16 px que as outras ondas usam, e o U23 monta o e2e do login real antes de qualquer item mexer no passo do código. Tudo é local e reversível; a alma não entra.

**O que a aluna vai notar:** a Crystal "responde" na hora (tiques azuis e "digitando…" assim que recebe a mensagem); quando algo falha, a bolha diz o que foi e o que fazer; o menu tem Suporte e Recomeçar; o passo do código tem um relógio só e saída quando o código não chega; os números de ajuda abrem o telefone; "Sair" pede confirmação; foto e áudio que falharam não se perdem; o botão de entrar, os erros e a transcrição ficam legíveis; as páginas legais têm seta de voltar.

**O que a equipe vai notar:** os campos do painel e da entrada da equipe param de dar zoom no iPhone; o foco do teclado fica visível no computador; os textos do painel deixam de tratar o CPF como chave de entrada; a faixa de backup não culpa mais o WhatsApp; o e2e passa a cobrir o login real (só e-mail), 390 px, sub-rotas e diálogos abertos.

**Pede OK do dono antes (padrão do PRD, que vale se ele não responder):** U01 (verde do botão de entrar; padrão: verde mais escuro), U04 (Recomeçar no menu, UX-24; padrão: entra), U07 (ritmo no painel, UX-16 parte 2; padrão: nada muda até ele mexer), U10 (botão do suporte no passo do código, UX-01, S12; padrão: entra), U13 (áudio aos 2:00, UX-20; padrão: para e espera), U18 (páginas legais, UX-36 e UX-84, S18; padrão: só a página de exclusão, o painel e a API; e gênero da microcopy, UX-78; padrão: forma neutra).

### U-onda 2 · Painel e suporte

| Item | O que muda | Achados que atende |
|---|---|---|
| U24 | Sessão vencida e endereço errado voltam para a equipe, e a equipe tem "Sair" | UX-112, UX-90, UX-82 (itens 1 a 3 e 5) |
| U25 | Cabeçalho do painel em uma linha, folha "Sua conta" e nome da tela fixo no celular | UX-89, UX-59, UX-143, UX-98 |
| U26 | Carregando: regra de três estados, portão neutro, kit nas telas antigas | UX-134, UX-129, UX-91, UX-68, UX-42, UX-57 (parte do carregando) |
| U27 | Toast com "Desfazer", pausa no toque e botão de fechar | UX-109, UX-122, UX-57 (parte do toast), UX-108 (parte do toast) |
| U28 | Alunos: a busca que não acha leva à base; o cartão da base leva à ficha; contadores iguais | UX-92, UX-103, UX-83, UX-104 |
| U29 | Ficha do aluno: "Entrada no app" no topo, Ações em grupos, bloco Crystal e WhatsApp com título | UX-102, UX-105, UX-115 |
| U30 | Ficha e sub-rotas: voltar, aba na URL, título por item, abas roláveis que mostram que há mais | UX-95, UX-106, UX-62, UX-51 |
| U31 | Select obrigatório abre em "Escolha…" e o botão travado diz o que falta | UX-111, UX-52 |
| U32 | Barra de seleção à vista, números que não quebram, plural certo | UX-61, UX-117, UX-70, UX-87 |
| U33 | Diálogo do código: validade, contagem, teto com relógio, e o teclado do iPhone não esconde o botão | UX-101, UX-63 |
| U34 | Nova mensagem: só os passos que o papel decide, rodapé de uma linha, "Cancelar envio" | UX-110, UX-64, UX-86 |
| U35 | Suporte: cartões que cabem, "Registrar atendimento" pela equipe, ticket sem gravação silenciosa | UX-107, UX-97, UX-108, UX-56 (filtros do suporte) |
| U36 | Tela Equipe: nome certo, papéis de equipe, CPF opcional, senha no mesmo fluxo, quem publica a alma | UX-126, UX-96, UX-100, UX-85 (item 1) |
| U37 | Página Crystal: Status fixo e renovado, abas na URL, navegação entre as sub-páginas | UX-123, UX-65, UX-94 |
| U38 | Trocar o modelo: o salto de custo em vermelho, De/Para no diálogo, quem trocou e volta ao anterior | UX-116, UX-120 |
| U39 | Laboratório no celular: lista em folha, "Mais" por mensagem com ajuda visível, trava explicada | UX-127, UX-66, UX-135 (parte do Laboratório), UX-56 (parte dos `title`), UX-85 (item 3) |
| U40 | Configurações no celular: chips fixos, grupos fechados, chave técnica só no histórico | UX-121, UX-85 (item 2), UX-65 (parte de Configurações) |
| U41 | Jargão fora da primeira linha: a equipe lê o que fazer, o técnico lê o detalhe | UX-124 |
| U42 | Gráficos: ler o valor de um ponto por toque e teclado; eixo que não se atropela nem fraciona aluno | UX-119, UX-118 |
| U43 | Financeiro: cartões no celular, filtros com rótulo, filtro do aluno visível, diálogo do kit | UX-125, UX-67, UX-50 (parte do "Novo lançamento") |
| U44 | Início com atalhos por papel; todo cartão e todo envio levam a algum lugar | UX-93 |
| U45 | Barra inferior por papel e folha "Mais" reagrupada | UX-88, UX-60, UX-99 |
| U46 | Banners: ligar ao criar e lista com "Mais" | UX-128 |
| U47 | Auditoria no celular: "Filtros (n)" e os filtros ativos à vista | UX-113 |

**Por quê:** são mudanças de estrutura (moldura, abas, folhas, rotas novas, API de ticket) que pedem mais teste e algumas decisões, e usam o que a onda 1 cria (tokens, foco, campos de 16 px, rede de testes). Por isso os três altos do painel (sessão vencida, busca de aluno, salto de custo do modelo) e os 14 ganhos rápidos do painel entram aqui, nos primeiros itens da onda, e não na onda 1.

**O que a equipe vai notar:** a sessão vencida volta para a entrada da equipe e existe "Sair"; cabeçalho de uma linha e o nome da tela fixo no celular; nada de tela branca ao abrir; "Desfazer" depois de desligar a aluna errada; a busca de aluno não termina em beco; a ficha responde "por que ela não entra" na primeira tela; o código por e-mail diz quanto vale e quantos restam, e os botões não somem atrás do teclado; o atendimento do WhatsApp fica registrado na ficha; o custo salta aos olhos antes de trocar o modelo, com "Voltar para {anterior}"; o dono acha o modelo e a pausa em dois toques, com o status atualizado; Configurações e Laboratório cabem no celular; os erros falam com quem opera, não com quem programa.

**O que a aluna vai notar:** quase nada direto. Indiretamente, suporte mais rápido e menos erro de operação.

**Pede OK do dono antes (padrão do PRD):** U28 (contas de revisão fora da lista, UX-104; padrão: ficam fora), U33 item 5 (código num segundo passo da mesma folha, UX-63; padrão: não faz), U34 parte B (barra inferior escondida na Nova mensagem, UX-64; padrão: não), U45 (barra inferior por papel, UX-88; padrão: só a folha "Mais" reagrupada) e a pendência 20 do PRD do painel (a Bia religa aluno; padrão: o código de hoje, e o "Desfazer" do U27 segue a mesma permissão).

### U-onda 3 · Início, consistência visual e design system

| Item | O que muda | Achados que atende |
|---|---|---|
| U48 | Um botão para os dois lados: `components/ui/Button` | UX-130, UX-141 (parte do desabilitado e do toque) |
| U49 | Um campo de texto para os dois lados: `components/ui/fields` | UX-131 |
| U50 | Um aviso para os dois lados: `components/ui/Notice`; amarelo é aviso, vermelho é erro | UX-139, UX-138 (item 1) |
| U51 | Um diálogo para os dois lados: `Overlay`, `Dialog` e `Sheet` sobre `<dialog>` nativo | UX-133, UX-50 (visor e prévia) |
| U52 | Interruptor, vazio e pílula únicos | UX-132, UX-135, UX-31 (parte do interruptor) |
| U53 | Um conjunto de ícones: `components/ui/icons.tsx` | UX-136 |
| U54 | Títulos e marca iguais nos dois lados: `PageHeader` e `CrystalLockup` | UX-140 |
| U55 | Tokens mortos fora, design-system legado separado, `DESIGN.md` reescrito | UX-138 (itens 2 a 4) |
| U56 | Primeiro acesso com menos telas: tutorial enxuto, notificações no momento certo, "Perfil salvo" | UX-07, UX-13, UX-10, UX-33, UX-09, UX-08, UX-40 |
| U57 | Notificações: o pedido fala do benefício certo e a folha separa aparelho de conta | UX-32, UX-31 (texto e estrutura) |
| U58 | Início: a foto diz que é botão; tamanho da letra no menu | UX-39, UX-48 |

**Por quê:** são mudanças de fundação. Botão, campo, aviso, diálogo, interruptor, ícones e título únicos reduzem o número de lugares onde o Igor corrige o mesmo bug e tornam as ondas seguintes mais baratas; mexem em muitos arquivos de uma vez, e nada das ondas 1 e 2 depende deles. O primeiro acesso (tutorial, notificações, "Perfil salvo") entra junto porque pede decisão de produto e conferência com uma conta nova no iPhone.

**O que a aluna vai notar:** o app com a mesma cara do login ao perfil; ao salvar o perfil pela primeira vez, a conversa abre com "Perfil salvo…"; a folha de notificações chega depois da primeira conversa e fala da resposta da Crystal; a foto do início com selo de câmera; letra maior quando quiser; com o OK do dono, um balão só em cada parte do tutorial.

**O que a equipe vai notar:** o painel e o app com a mesma família de botões, campos, avisos e diálogos; o Igor mantém um componente em vez de nove; o `DESIGN.md` passa a descrever o app de verdade.

**Pede OK do dono antes (padrão do PRD):** U56 (tutorial partes 1 e 3 com um balão e contador "Faltam N respostas", UX-07, UX-10, UX-13; padrão: ficam como estão, e o resto do item entra) e U58 item 2 (tamanho da letra no menu, UX-48; padrão: entra).

---

## 6. O que NÃO fazer

Decisões já tomadas e itens recusados pelo dono. Nenhum achado deste relatório os reabre, e nenhuma onda deve reabri-los "de passagem".

**A alma da Crystal não muda** (decisão final de 23/10). Nenhuma proposta pede mudança no texto do prompt nem nos blocos fixos do código (formato em bolhas, áudio, imagem, resumo, padrões de risco). Isso arquivou três ajustes que continuam arquivados: responder a vários assuntos numa mensagem, "dúvidas do app e do curso → Menu > Suporte" via prompt, e o falso positivo em "lembra da nossa conversa no WhatsApp". A resposta de UX a "a Crystal não fala de mais de uma coisa" é a fila por conversa e o "digitando…" imediato (UX-22, UX-16), não a alma. A resposta a "onde ficam as aulas" é o item Suporte no menu e o escopo da tela de Suporte (UX-15, UX-29), não a alma.

**Itens recusados (não propor de novo):** foto e nome do Instagram (P04); "Analisar o Instagram" (P05); perfil chegando à Crystal (S01); reescrita do texto da Crystal (S04); ajustar a rede de segurança dos telefones de emergência (S05: UX-18 só torna o texto clicável, não muda quando ele aparece); primeira mensagem da Crystal depois do perfil (S07: a pílula de UX-09 é do app, não da Crystal, e não entra no histórico); limite de uso por aluna além das 25 imagens (S09); base de alunos ligada ao login (S10, já superado); login e ajuda para entrar (S12, "o Luiz cuida": o UX-01 não guarda o passo do código entre aberturas, e o botão do suporte no passo do código vai como pergunta ao dono, com padrão "entra", porque a tela já manda ao suporte em texto); tela "abra no navegador" (S13); lojas antes do PWA (S14); aviso de IA e consentimento detalhado (S15: os textos do aceite ficam como estão em UX-03 e UX-08); denunciar resposta (S16); conferir idade (S17); páginas legais além do encarregado (S18: UX-36 e UX-84 marcam os trechos legais como "a confirmar"); notificação genérica (S19, já superado pelo B01); plano de passagem do WhatsApp (S20); funil de produto com eventos de tela (S21: nada aqui pede medir "tela vista"); alarmes e backup pelo app (S22); ambiente de teste (S23: por isso toda onda conferida no iPhone do dono); modo treino e revisão por print (S28).

**Fora do escopo do painel (PRD):** editar ou apagar mensagens da aluna pelo painel; ver jeito de conversar, momento de vida e memória; custo em reais por resposta; mensagem gerada por tema; histórico de avisos no app da aluna; gatilhos automáticos; A/B; imagem ou áudio nas mensagens da equipe; editar segredos, URLs, prazos, matriz de áreas, blocos fixos, microcopy e páginas legais pelo painel; TOTP; backup pelo painel; importar alunos por planilha; papel "editor". UX-97 (registrar pedido de suporte) foi prometido pelo PRD do painel e por isso entra; religar aluno pelo suporte (pendência 20) segue como está até o dono responder.

**Riscos assumidos que não se reabrem:** papel de parede original do WhatsApp; aceite "só você acessa"; idade sem conferência; sem ambiente de teste; token da Assiny mantido.

**Regras de segurança que as propostas respeitam:** o login responde igual para qualquer e-mail (UX-01, UX-02 e UX-05 mantêm a frase "se for o e-mail da sua compra" e nunca mostram o e-mail na mensagem ao suporte); a equipe só entra por `/login/equipe` e o login da aluna continua sem link para lá (UX-90 só manda para lá quem já entrou como equipe neste aparelho); nenhum link vindo do modelo vira clicável fora da lista fechada de UX-18; motivos das ações continuam sem e-mail, CPF ou telefone; CPF sempre mascarado; nada de segredo, chave ou identificador de modelo em tela.

**O que está bom e fica como está:** cara de WhatsApp da conversa; três botões iguais no início; Crystal como contato com cadeado até o perfil; Suporte com dois cartões e a nota "aqui você fala com pessoas" (o UX-40 só acrescenta um botão de texto abaixo da nota, sem cartão novo); login só com e-mail e código; tutorial em três partes (só enxugado); kit do painel (lista vira cartão, filtros em folha com URL, PageHeading, selos); confirmação forte com palavra e código; prévia dupla e "Enviar teste para mim"; 404 em vez de 403; tema claro e escuro guardado no aparelho.

---

## 7. Capturas citadas

Todas em `capturas/` (modo de demonstração, dados fictícios; 390 px = iPhone, 1280 px = computador).

| Arquivo | O que mostra |
|---|---|
| `capturas/aluna-login-390.png` | Entrada da aluna no modo do ambiente de teste (CPF + e-mail), botão "Entrar" apagado com o formulário vazio |
| `capturas/aluna-login-codigo-390.png` | Passo do código: "Te mandei um código por e-mail", campo de 6 dígitos, "Código válido por 05:00", botão verde, "Reenviar em 60s" e "Voltar" como links pequenos |
| `capturas/aluna-login-codigo-errado-390.png` | Código incorreto: faixa vermelha clara "Você ainda tem 4 tentativas" sobre o verde do botão; os dois links pequenos embaixo |
| `capturas/aluna-login-consentimento-390.png` | Primeiro acesso: caixa "Li e concordo com a Política" aparecendo depois do código, com o mesmo botão "Entrar" |
| `capturas/aluna-tutorial-3-390.png` | Tutorial parte 1, passo 3 de 3: fundo escuro, linha "Crystal — Liberada quando você salvar o perfil" acesa, balão da Crystal com "Pular" e "Completar perfil" |
| `capturas/aluna-tutorial-chat-390.png` | Tutorial parte 2 (conversa): balão sobre o campo de mensagem, cobrindo a boas-vindas |
| `capturas/aluna-onboarding-1-consentimento-390.png` | Cartão "Antes de guardar as coisas mais delicadas" ocupando a tela, com "Ver o tutorial de novo" e "Excluir minha conta" logo abaixo |
| `capturas/aluna-onboarding-2-formulario-390.png` | Formulário do perfil vazio: "1 de 5 respondidas" com o nome já preenchido |
| `capturas/aluna-onboarding-3-erro-idade-390.png` | Erro de idade (menor de 18) e os textos do perfil no masculino |
| `capturas/aluna-perfil-390.png` | Perfil preenchido (5 de 5), botão "Salvar" e, no rodapé, "Ver o tutorial de novo" e "Excluir minha conta" com a mesma cara |
| `capturas/aluna-inicio-390.png` | Início com perfil completo: cabeçalho "Crystal" + três pontinhos, inicial "D", "Perfil completo", botões Perfil / Conversa / Suporte, Crystal como contato |
| `capturas/aluna-menu-390.png` | Menu de três pontinhos aberto: Tema (Claro, Escuro, Sistema), Notificações, Política de privacidade, Sair. Sem Suporte |
| `capturas/aluna-notificacoes-390.png` | Folha Notificações: "Este navegador não recebe notificações" e, abaixo, "Avisos de aulas e ofertas" com uma caixa de marcar rosa |
| `capturas/aluna-suporte-390.png` | Suporte: lead "Precisa de ajuda com o app ou com seu acesso?", cartão WhatsApp e cartão E-mail, nota no fim |
| `capturas/aluna-chat-390.png` | Conversa com duas perguntas e respostas em bolhas curtas sobre o papel de parede; campo, clipe e microfone embaixo |
| `capturas/aluna-chat-resposta-1-390.png` | Primeira troca: bolha rosa da aluna com tiques, três bolhas brancas da Crystal, "online" no topo |
| `capturas/aluna-chat-escuro-390.png` | A mesma conversa no tema escuro |
| `capturas/aluna-chat-compositor-390.png` | Barra de escrever: campo "Mensagem", clipe e botão rosa do microfone |
| `capturas/aluna-privacidade-390.png` | Política de privacidade inteira (7.600 px) sem cabeçalho nem seta no topo |
| `capturas/aluna-excluir-conta-390.png` | Página pública de exclusão com o passo "entre com seu CPF e e-mail" |
| `capturas/equipe-login-codigo-390.png` | Entrada da equipe, passo do código: "Acesso da equipe" e, logo abaixo, "Te mandei um código por e-mail" na voz da Crystal; rodapé "Conversa protegida" |
| `capturas/equipe-404-1280.png` | 404 da Crystal fora da moldura do painel, com "Voltar para o início" (da aluna) |
| `capturas/equipe-inicio-390.png` | Início do painel no iPhone: cabeçalho de duas linhas (nome, papel, Tema, Minha senha, Ir para o chat), cartões com "0 agendadas para hoje" em três linhas, barra inferior |
| `capturas/equipe-inicio-suporte-1280.png` | Início visto pelo suporte: quatro números e "Tudo em ordem", sem atalhos |
| `capturas/equipe-mais-390.png` | Folha "Mais" do admin: Operar (Banners), Entender (Métricas, Auditoria), Ajustar (Crystal, Laboratório, Configurações, Integrações, Financeiro, Equipe) |
| `capturas/equipe-alunos-390.png` | Lista de alunos no iPhone: "14 alunos" no cabeçalho e "15 alunos nesta lista" abaixo; cartões com nomes parecidos; abas Alunos / Base de alunos / Lotes |
| `capturas/equipe-ficha-390.png` | Ficha no iPhone: abas "Resumo · Mensagens · Aparelhos e sessões · S" cortadas; blocos Conta, Uso, Perfil, Imagens e o bloco sem título com Importar / Silenciar / Recomeçar |
| `capturas/equipe-ficha-acoes-1280.png` | Folha "Ações": lista plana de Enviar mensagem a Apagar dados, "Desligar" e "Apagar dados" em vermelho |
| `capturas/equipe-ficha-dialogo-codigo-390.png` | Diálogo "Recomeçar a conversa deste aluno": motivo, "Confirme que é você", e-mail mascarado, campo Código, "Sim, recomeçar" em vermelho no fim da folha |
| `capturas/equipe-suporte-bia-1280.png` | Caixa de entrada do Suporte vista pelo suporte: contadores em zero e lista vazia |
| `capturas/equipe-mensagens-390.png` | Nova mensagem no iPhone: passo 1 de 4, campos de 14 px, rodapé fixo com "Continuar" e a frase do teste, barra de abas logo abaixo |
| `capturas/equipe-mensagens-agendadas-1280.png` | Aba Agendadas: cartão com "Editar" e "Cancelar" (vermelho) |
| `capturas/equipe-usuarios-1280.png` | Menu "Equipe" ativo e título "Usuários — Alunos e equipe no mesmo lugar"; três contas de equipe |
| `capturas/equipe-usuarios-detalhe-1280.png` | Painel lateral de uma pessoa da equipe (outro véu e outro estilo de diálogo) |
| `capturas/equipe-crystal-1280.png` | Página Crystal inteira no computador: Status, Inteligência, Ligações, Pausa, Manutenção, Foto, Memória, Fichas, Ritmo, Modelo (10.º bloco), Teste, atalho do Laboratório |
| `capturas/equipe-crystal-390.png` | A mesma página no iPhone: cerca de sete telas de rolagem |
| `capturas/equipe-crystal-base-1280.png` | Base de conhecimento com o erro "A base de conhecimento não respondeu" e a pergunta técnica sobre SQL |
| `capturas/equipe-configuracoes-390.png` | Configurações no iPhone: dezenas de cartões empilhados, "Chave: …" em cada um |
| `capturas/equipe-metricas-390.png` | Métricas no iPhone: gráfico com rótulos de data atropelados e eixo "0,5"; cartão "1 conversand/o" |
| `capturas/equipe-metricas-1280.png` | Métricas no computador: gráficos sem leitura de ponto |
| `capturas/equipe-laboratorio-390.png` | Laboratório vazio no iPhone: duas caixas tracejadas dizendo "nenhuma conversa" uma embaixo da outra |
| `capturas/equipe-financeiro-1280.png` | Financeiro: seis cartões, filtros sem rótulo, tabela de 7 colunas; "R$" quebrado em outra linha no cartão Recebido |
| `capturas/equipe-banners-novo-1280.png` | Cadastro de banner novo sem o interruptor de ligar |
