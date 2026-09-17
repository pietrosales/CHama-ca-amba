# Chama Caçamba

## Onde alterar

- `frontend/index.html`: telas, layout e regras do sistema no navegador.
- `frontend/config.js`: configuração pública do Supabase e Google Maps.
- `supabase/*.sql`: tabelas, auditoria, políticas e agendamentos.
- `supabase/functions/`: código executado no servidor (e-mail, backup e mapas).

## Publicação do frontend

Use a pasta `frontend` em GitHub Pages, Netlify ou Vercel. O arquivo inicial é `frontend/index.html`.

## Segurança

Não coloque tokens, senhas, `service_role`, `RESEND_API_KEY` ou credenciais da Z-API neste repositório. Esses valores permanecem nos Secrets do Supabase.

## Banco e funções

Os SQL já foram aplicados no projeto Supabase. Ao alterar funções, publique novamente com a CLI do Supabase a partir da pasta correspondente.
