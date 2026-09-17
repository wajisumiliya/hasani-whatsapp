create extension if not exists pgcrypto;

create table if not exists public.wa_customers (
 id bigint generated always as identity primary key,
 customer_code text,
 customer_name text not null,
 phone text not null unique,
 email text,
 whatsapp_opt_in boolean not null default false,
 opt_in_at timestamptz,
 opt_in_source text,
 is_active boolean not null default true,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create index if not exists wa_customers_name_idx on public.wa_customers(customer_name);
create index if not exists wa_customers_consent_idx on public.wa_customers(whatsapp_opt_in,is_active);

create table if not exists public.wa_templates (
 id bigint generated always as identity primary key,
 template_name text not null unique,
 category text not null default 'marketing' check (category in ('marketing','utility','authentication')),
 language_code text not null default 'en',
 message_body text not null,
 provider_template_name text,
 provider_template_id text,
 status text not null default 'draft' check (status in ('draft','pending','approved','rejected','disabled')),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create table if not exists public.wa_campaigns (
 id bigint generated always as identity primary key,
 campaign_name text not null,
 description text,
 template_id bigint references public.wa_templates(id),
 campaign_type text not null default 'marketing',
 status text not null default 'draft' check(status in ('draft','scheduled','processing','paused','completed','cancelled')),
 scheduled_at timestamptz, started_at timestamptz, completed_at timestamptz,
 created_by uuid references auth.users(id),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create table if not exists public.wa_campaign_recipients (
 id bigint generated always as identity primary key,
 campaign_id bigint not null references public.wa_campaigns(id) on delete cascade,
 customer_id bigint not null references public.wa_customers(id) on delete cascade,
 customer_name text not null, phone text not null,
 status text not null default 'queued' check(status in ('queued','processing','sent','delivered','read','failed','skipped','cancelled')),
 queued_at timestamptz not null default now(), processing_at timestamptz, sent_at timestamptz, delivered_at timestamptz, read_at timestamptz, failed_at timestamptz,
 failure_reason text, retry_count integer not null default 0, next_retry_at timestamptz,
 idempotency_key uuid not null default gen_random_uuid() unique,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 unique(campaign_id,customer_id)
);
create index if not exists wa_recipients_queue_idx on public.wa_campaign_recipients(status,next_retry_at,queued_at);

create table if not exists public.wa_messages (
 id bigint generated always as identity primary key,
 campaign_id bigint references public.wa_campaigns(id) on delete set null,
 recipient_id bigint references public.wa_campaign_recipients(id) on delete set null,
 customer_id bigint references public.wa_customers(id) on delete set null,
 phone text not null, provider text not null default 'mock', provider_message_id text,
 message_type text not null default 'template', status text not null default 'queued',
 error_code text,error_message text, provider_response jsonb,
 sent_at timestamptz,delivered_at timestamptz,read_at timestamptz,failed_at timestamptz,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create unique index if not exists wa_messages_provider_id_idx on public.wa_messages(provider,provider_message_id) where provider_message_id is not null;

create table if not exists public.wa_opt_outs (
 id bigint generated always as identity primary key,
 customer_id bigint references public.wa_customers(id) on delete set null,
 phone text not null unique, reason text, source text, opted_out_at timestamptz not null default now()
);

create table if not exists public.wa_audit_log (
 id bigint generated always as identity primary key,
 actor_id uuid references auth.users(id), action text not null, entity_type text not null, entity_id text,
 metadata jsonb not null default '{}'::jsonb, created_at timestamptz not null default now()
);

create or replace function public.wa_set_updated_at() returns trigger language plpgsql as $$ begin new.updated_at=now(); return new; end $$;
do $$ declare t text; begin foreach t in array array['wa_customers','wa_templates','wa_campaigns','wa_campaign_recipients','wa_messages'] loop execute format('drop trigger if exists %I on public.%I','trg_'||t||'_updated_at',t); execute format('create trigger %I before update on public.%I for each row execute function public.wa_set_updated_at()','trg_'||t||'_updated_at',t); end loop; end $$;

create or replace function public.wa_guard_recipient_consent() returns trigger language plpgsql as $$
declare c public.wa_customers%rowtype; begin
 select * into c from public.wa_customers where id=new.customer_id;
 if c.id is null or not c.is_active or not c.whatsapp_opt_in then raise exception 'Customer is not eligible for WhatsApp marketing'; end if;
 if exists(select 1 from public.wa_opt_outs where phone=c.phone) then raise exception 'Customer has opted out'; end if;
 new.customer_name=c.customer_name; new.phone=c.phone; return new;
end $$;
drop trigger if exists trg_wa_recipient_consent on public.wa_campaign_recipients;
create trigger trg_wa_recipient_consent before insert on public.wa_campaign_recipients for each row execute function public.wa_guard_recipient_consent();

create or replace function public.wa_unsubscribe_customer(p_phone text,p_reason text default null,p_source text default 'customer') returns void language plpgsql security definer set search_path=public as $$
declare cid bigint; begin
 select id into cid from public.wa_customers where phone=p_phone;
 insert into public.wa_opt_outs(customer_id,phone,reason,source) values(cid,p_phone,p_reason,p_source)
 on conflict(phone) do update set reason=excluded.reason,source=excluded.source,opted_out_at=now();
 update public.wa_customers set whatsapp_opt_in=false where phone=p_phone;
 update public.wa_campaign_recipients set status='cancelled' where phone=p_phone and status='queued';
end $$;

alter table public.wa_customers enable row level security;
alter table public.wa_templates enable row level security;
alter table public.wa_campaigns enable row level security;
alter table public.wa_campaign_recipients enable row level security;
alter table public.wa_messages enable row level security;
alter table public.wa_opt_outs enable row level security;
alter table public.wa_audit_log enable row level security;

create or replace view public.wa_campaign_summary as
select c.id,c.campaign_name,c.status,count(r.id) total,
 count(*) filter(where r.status='queued') queued,
 count(*) filter(where r.status='sent') sent,
 count(*) filter(where r.status='delivered') delivered,
 count(*) filter(where r.status='read') read,
 count(*) filter(where r.status='failed') failed
from public.wa_campaigns c left join public.wa_campaign_recipients r on r.campaign_id=c.id group by c.id;
