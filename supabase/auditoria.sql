-- A-004 — Registro de auditoria para Chama Caçamba Gestão
-- Execute este script uma única vez no SQL Editor do projeto Supabase.
-- Ele pressupõe as tabelas public.locacoes (id, data jsonb) e public.perfis
-- (user_id uuid, role text) já usadas pelo sistema.

begin;

create table if not exists public.auditoria (
  id bigint generated always as identity primary key,
  operacao text not null check (operacao in ('INSERT', 'UPDATE', 'DELETE')),
  user_id uuid references auth.users(id) on delete set null,
  user_email text,
  locacao_id text not null,
  campo text not null,
  valor_anterior jsonb,
  valor_novo jsonb,
  data_hora timestamptz not null default now()
);

comment on table public.auditoria is 'Registro imutável de INSERT/UPDATE/DELETE da tabela locacoes.';
create index if not exists auditoria_data_hora_idx on public.auditoria (data_hora desc);
create index if not exists auditoria_locacao_id_idx on public.auditoria (locacao_id);
create index if not exists auditoria_user_email_idx on public.auditoria (user_email);

-- A função é SECURITY DEFINER para a policy não depender de uma policy recursiva
-- sobre perfis. Ela só devolve verdadeiro para o próprio usuário autenticado admin.
create or replace function public.usuario_eh_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.perfis
    where user_id = auth.uid()
      and role = 'admin'
      and ativo is distinct from false
  );
$$;

revoke all on function public.usuario_eh_admin() from public;
grant execute on function public.usuario_eh_admin() to authenticated;

-- Captura o usuário da sessão Supabase no momento da alteração. Como o gatilho
-- é executado no banco, o cliente não pode escolher ou adulterar esses valores.
create or replace function public.registrar_auditoria_locacao()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  chave text;
  houve_alteracao boolean := false;
  dados_anteriores jsonb;
  dados_novos jsonb;
  responsavel uuid := auth.uid();
  email_responsavel text := auth.jwt() ->> 'email';
begin
  if tg_op = 'INSERT' then
    insert into public.auditoria (operacao, user_id, user_email, locacao_id, campo, valor_anterior, valor_novo)
    values ('INSERT', responsavel, email_responsavel, new.id::text, 'REGISTRO', null, coalesce(new.data, '{}'::jsonb));
    return new;
  end if;

  if tg_op = 'DELETE' then
    insert into public.auditoria (operacao, user_id, user_email, locacao_id, campo, valor_anterior, valor_novo)
    values ('DELETE', responsavel, email_responsavel, old.id::text, 'REGISTRO', coalesce(old.data, '{}'::jsonb), null);
    return old;
  end if;

  dados_anteriores := coalesce(old.data, '{}'::jsonb);
  dados_novos := coalesce(new.data, '{}'::jsonb);
  for chave in select jsonb_object_keys(dados_anteriores || dados_novos)
  loop
    if (dados_anteriores -> chave) is distinct from (dados_novos -> chave) then
      insert into public.auditoria (operacao, user_id, user_email, locacao_id, campo, valor_anterior, valor_novo)
      values ('UPDATE', responsavel, email_responsavel, new.id::text, chave, dados_anteriores -> chave, dados_novos -> chave);
      houve_alteracao := true;
    end if;
  end loop;

  -- Mantém a rastreabilidade até em um UPDATE que não altere o JSON.
  if not houve_alteracao then
    insert into public.auditoria (operacao, user_id, user_email, locacao_id, campo, valor_anterior, valor_novo)
    values ('UPDATE', responsavel, email_responsavel, new.id::text, 'REGISTRO_SEM_ALTERACAO', dados_anteriores, dados_novos);
  end if;
  return new;
end;
$$;

revoke all on function public.registrar_auditoria_locacao() from public;

drop trigger if exists locacoes_auditoria_trigger on public.locacoes;
create trigger locacoes_auditoria_trigger
after insert or update or delete on public.locacoes
for each row execute function public.registrar_auditoria_locacao();

alter table public.auditoria enable row level security;

drop policy if exists auditoria_admin_leitura on public.auditoria;
create policy auditoria_admin_leitura
on public.auditoria
for select
to authenticated
using (public.usuario_eh_admin());

-- Nenhum usuário do navegador recebe privilégio de gravar, editar ou apagar.
-- A inserção permitida é exclusivamente a do gatilho SECURITY DEFINER acima.
revoke all on table public.auditoria from anon, authenticated;
grant select on table public.auditoria to authenticated;

commit;
