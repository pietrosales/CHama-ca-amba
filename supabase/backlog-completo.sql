-- Migração complementar do backlog: backup, manutenção, financeiro,
-- alertas e rastreamento. Execute depois de supabase-auditoria.sql.
begin;

insert into storage.buckets (id, name, public)
values ('backups', 'backups', false)
on conflict (id) do update set public = false;

drop policy if exists backups_admin_select on storage.objects;
create policy backups_admin_select on storage.objects for select to authenticated
using (bucket_id = 'backups' and public.usuario_eh_admin());
drop policy if exists backups_admin_insert on storage.objects;
create policy backups_admin_insert on storage.objects for insert to authenticated
with check (bucket_id = 'backups' and public.usuario_eh_admin());
drop policy if exists backups_admin_delete on storage.objects;
create policy backups_admin_delete on storage.objects for delete to authenticated
using (bucket_id = 'backups' and public.usuario_eh_admin());

create table if not exists public.manutencoes (
  id uuid primary key default gen_random_uuid(),
  cacamba_numero text not null,
  data date not null default current_date,
  descricao text not null,
  tipo text not null check (tipo in ('preventiva','corretiva')),
  valor numeric(12,2) not null default 0,
  status text not null default 'em andamento' check (status in ('em andamento','concluída')),
  responsavel text,
  criado_por uuid references auth.users(id),
  criado_em timestamptz not null default now()
);

create table if not exists public.financeiro (
  id uuid primary key default gen_random_uuid(),
  tipo text not null check (tipo in ('receita','despesa')),
  descricao text not null,
  valor numeric(12,2) not null check (valor >= 0),
  vencimento date,
  pagamento date,
  status text not null default 'pendente' check (status in ('pendente','pago','parcial')),
  locacao_id text,
  criado_por uuid references auth.users(id),
  criado_em timestamptz not null default now()
);

create table if not exists public.alertas (
  id uuid primary key default gen_random_uuid(),
  tipo text not null,
  destinatario text not null,
  mensagem text not null,
  enviado_em timestamptz,
  status text not null default 'pendente',
  criado_em timestamptz not null default now()
);

create table if not exists public.rastreamento_cacambas (
  id uuid primary key default gen_random_uuid(),
  cacamba_numero text not null,
  latitude numeric(10,7),
  longitude numeric(10,7),
  registrado_em timestamptz not null default now(),
  origem text default 'google-cloud'
);

alter table public.manutencoes enable row level security;
alter table public.financeiro enable row level security;
alter table public.alertas enable row level security;
alter table public.rastreamento_cacambas enable row level security;

drop policy if exists manutencoes_authenticated on public.manutencoes;
create policy manutencoes_authenticated on public.manutencoes for all to authenticated
using (true) with check (public.usuario_eh_admin() or auth.uid() is not null);
drop policy if exists financeiro_admin on public.financeiro;
create policy financeiro_admin on public.financeiro for all to authenticated
using (public.usuario_eh_admin()) with check (public.usuario_eh_admin());
drop policy if exists alertas_authenticated on public.alertas;
create policy alertas_authenticated on public.alertas for select to authenticated using (public.usuario_eh_admin());
drop policy if exists rastreamento_authenticated on public.rastreamento_cacambas;
create policy rastreamento_authenticated on public.rastreamento_cacambas for all to authenticated
using (true) with check (auth.uid() is not null);

create index if not exists manutencoes_cacamba_status_idx on public.manutencoes(cacamba_numero,status);
create index if not exists financeiro_vencimento_idx on public.financeiro(vencimento,status);
create index if not exists rastreamento_cacamba_data_idx on public.rastreamento_cacambas(cacamba_numero,registrado_em desc);
commit;
