create or replace function public.wa_claim_queue_batch(p_limit integer default 50)
returns table (
  id bigint,
  campaign_id bigint,
  customer_id bigint,
  phone text,
  idempotency_key uuid,
  retry_count integer
)
language sql
security definer
set search_path=public
as $$
  with candidates as (
    select r.id
    from public.wa_campaign_recipients r
    join public.wa_campaigns c on c.id=r.campaign_id
    where r.status='queued'
      and c.status='processing'
      and (r.next_retry_at is null or r.next_retry_at <= now())
    order by r.queued_at
    for update of r skip locked
    limit greatest(1,least(coalesce(p_limit,50),200))
  ), claimed as (
    update public.wa_campaign_recipients r
    set status='processing', processing_at=now(), updated_at=now()
    from candidates q
    where r.id=q.id
    returning r.id,r.campaign_id,r.customer_id,r.phone,r.idempotency_key,r.retry_count
  )
  select * from claimed;
$$;

revoke all on function public.wa_claim_queue_batch(integer) from public, anon, authenticated;
grant execute on function public.wa_claim_queue_batch(integer) to service_role;
