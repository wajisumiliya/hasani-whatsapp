create table if not exists public.wa_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

alter table public.wa_admins enable row level security;

create or replace function public.wa_is_admin()
returns boolean language sql stable security definer set search_path=public as $$
  select exists(select 1 from public.wa_admins where user_id=auth.uid());
$$;

revoke all on function public.wa_is_admin() from public;
grant execute on function public.wa_is_admin() to authenticated;

create policy "admins can read own membership" on public.wa_admins
for select to authenticated using (user_id=auth.uid());

do $$ declare t text; begin
  foreach t in array array['wa_customers','wa_templates','wa_campaigns','wa_campaign_recipients','wa_messages','wa_opt_outs','wa_audit_log'] loop
    execute format('drop policy if exists "admin_all" on public.%I',t);
    execute format('create policy "admin_all" on public.%I for all to authenticated using (public.wa_is_admin()) with check (public.wa_is_admin())',t);
  end loop;
end $$;

revoke all on function public.wa_unsubscribe_customer(text,text,text) from public, anon, authenticated;
-- The service-role server client bypasses RLS and is the only application path that should invoke privileged mutations.
