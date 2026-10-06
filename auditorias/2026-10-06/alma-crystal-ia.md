# Conferência do repositório `LFcrystal766/crystal-ia` (entrega da agência, 06/10/2026)

Dois commits do Tuan em 06/10 (08:23 e 08:48 BRT), branch `main`, 89 arquivos, 1,2 MB.
Pacote "Crystal AI v0.16.1": runtime Python (FastAPI + LangGraph + Redis Streams),
prompts, Dockerfile, Compose e documentação navegável. É a Crystal do WhatsApp via
LendChat, não um pacote feito para o nosso app.

## O que é a "alma" de fato

| Arquivo | Tamanho | O que é |
|---|---|---|
| `prompts/system_prompt.md` | 18,9 mil caracteres (v2.2) | Persona, tom, regras invioláveis, protocolo de investigação, anti-alucinação |
| `prompts/vision.md` | 0,5 mil | Descrição de print (quem mandou o quê, lado, cor, horário) |
| `prompts/summarizer_system.md` + `_user_template.md` | 5 mil | Memória: `lead_profile` em JSON e narrativa em 4 tags XML |
| `prompts/splitter.md` | 6 mil | Quebra da resposta em balões (array JSON) |

A **base de conhecimento não está no repositório.** O prompt obriga a ferramenta
`crystal_knowledge_search`, que chama a Edge Function `crystal_hybrid_search` do
Supabase (projeto Crystal AI) e lê a tabela `leticia_crystal_vector_store`. Os
textos da Letícia estão lá, não no Git.

## Segurança

- Varredura de segredos (chaves OpenRouter/OpenAI/Supabase JWT/Resend/Groq/Telegram/
  AWS/chave privada): nada encontrado. `.env` ignorado, `.env.example` só com nomes.
- O manifesto diz excluir "identificadores de outros ambientes e links de pagamento
  originais", mas ficaram: `lendchat.agencialendaria.ai` e `trace.agencialendaria.ai`
  como padrão em `config.py`, e dois links da Assiny (`gates.py`, `order_bump.py`).
  Não são segredos. Avisar o Tuan.
- Bloco `sales_and_limits_protocol` no prompt, **desativado** (`{{ false ? ... }}`):
  manda sustentar a narrativa de "galeria do celular cheia" para vender um pack de
  fotos e proíbe dizer "sou uma inteligência artificial". Não entra no nosso app:
  o app é transparente que a Crystal é IA e não tem order bump.
- Sem protocolo de risco (ideação suicida, violência) no prompt da agência. O nosso
  fica: detecção em código, orientação e contatos (CVV 188, 180, 190, 192).

## Modelos que a agência usa (explica o gasto da conta OpenRouter)

| Papel | Principal | Reservas |
|---|---|---|
| agente | google/gemini-2.5-flash | deepseek/deepseek-v4-pro, google/gemini-3-flash-preview, minimax/minimax-m2.7 |
| visão | google/gemini-2.5-flash | openai/gpt-4.1-mini |
| splitter | openai/gpt-4o-mini | |
| resumidor | openai/gpt-oss-120b | |

Janela de histórico: 25 mensagens. Custo real por chamada via `usage.include`
(mesma técnica que entrou na nossa Crystal em `otimizacao/custo-modelo`), gravado na
tabela `agencia_lendaria_ai_token_usage` com `TOKEN_USAGE_CLIENT_ID` e `AGENCY_ID`:
a conta e a tabela são multi-cliente da agência.

## Diferenças para o nosso app (o que adaptar)

1. Marcadores do n8n no prompt (`{{ $now... }}`, `{{ $('normLongTermMemory')... }}`):
   o Python troca por string exata (`graph/prompts.py`). Na nossa Crystal, trocar
   pela linha de data e hora e pelo resumo do aluno que já existem.
2. Ferramentas: o prompt exige `crystal_knowledge_search` antes de qualquer conselho.
   A nossa Crystal não tem ferramentas; põe a base no prompt (até 60 mil caracteres).
   Dois caminhos: (a) chamar a mesma Edge Function do Supabase a cada turno com a
   mensagem do aluno como busca e colar os trechos no prompt; (b) implementar tool
   calling. O (a) é menor e mantém a base num lugar só.
3. `long_term_memory`, `contact_info_name/email`: a nossa já tem resumo por aluno e o
   cadastro vem do login. Adotar o esquema de memória (perfil + 4 tags) é opcional.
4. Formato: "máximo 3 balões", "PROIBIDO listas". A nossa `INSTRUCAO_IMAGEM` pede três
   opções com o porquê; conciliar com a Letícia.
5. Público: o prompt fala com homens ("gatão", "a mulher"). Conferir com a Letícia se
   o app segue igual.
6. O prompt tem `v2.2` solto na primeira linha e o bloco desativado: limpar na cópia.

## Próximos passos

- Dono: rodar no SQL Editor do Supabase a consulta da base (tamanho e fontes) e, na
  VPS, o teste da Edge Function (comandos na sessão de 06/10).
- Sessão: montar `prompt/crystal.md` a partir do `system_prompt.md` com as adaptações
  acima, e a busca na base por turno; só depois a imagem nova.
