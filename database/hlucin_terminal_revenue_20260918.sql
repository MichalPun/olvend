begin;
-- Preserve small terminal snapshots independently of seven-day raw DEX retention.
create table if not exists public.hlucin_terminal_counters (
  event_at timestamptz primary key,
  ingest_id bigint not null,
  total_amount numeric not null check(total_amount>=0),
  total_quantity bigint not null check(total_quantity>=0),
  cash_amount numeric not null check(cash_amount>=0),
  cash_quantity bigint not null check(cash_quantity>=0),
  card_amount numeric not null check(card_amount>=0),
  card_quantity bigint not null check(card_quantity>=0)
);
alter table public.hlucin_terminal_counters enable row level security;
revoke all on public.hlucin_terminal_counters from public,anon,authenticated;
grant select on public.hlucin_terminal_counters to authenticated;
create policy hlucin_counter_read on public.hlucin_terminal_counters for select to authenticated using(true);

create or replace function public.capture_hlucin_terminal_counter()
returns trigger language plpgsql security definer set search_path=public as $$
declare v text[]; c text[]; d text[]; ts timestamptz;
begin
  if new.provider<>'IMA' or new.device_id<>'597848' then return new; end if;
  ts:=coalesce(new.dex_read_datetime,new.transmit_time,new.transaction_time,new.created_at);
  -- Do not attribute the terminal's previous installation to Hlučín.
  if ts<'2026-09-13 16:06:25+00'::timestamptz then return new; end if;
  if not exists(select 1 from public.machine_external_links where machine_id=58 and provider='IMA' and external_machine_id='597848' and telemetry_enabled) then return new; end if;
  v:=regexp_match(new.raw_dex,'(?:^|[\r\n])VA1\*([0-9]+)\*([0-9]+)(?:\*|[\r\n]|$)');
  c:=regexp_match(new.raw_dex,'(?:^|[\r\n])CA2\*([0-9]+)\*([0-9]+)(?:\*|[\r\n]|$)');
  d:=regexp_match(new.raw_dex,'(?:^|[\r\n])DA2\*([0-9]+)\*([0-9]+)(?:\*|[\r\n]|$)');
  if v is null or c is null or d is null then return new; end if;
  -- IMA amounts for this terminal are in haléře. Store CZK, not lifetime revenue.
  insert into public.hlucin_terminal_counters values(ts,new.id,v[1]::numeric/100,v[2]::bigint,c[1]::numeric/100,c[2]::bigint,d[1]::numeric/100,d[2]::bigint)
  on conflict(event_at) do update set ingest_id=excluded.ingest_id,total_amount=excluded.total_amount,total_quantity=excluded.total_quantity,cash_amount=excluded.cash_amount,cash_quantity=excluded.cash_quantity,card_amount=excluded.card_amount,card_quantity=excluded.card_quantity
  where excluded.ingest_id>=hlucin_terminal_counters.ingest_id;
  return new;
end $$;
revoke all on function public.capture_hlucin_terminal_counter() from public,anon,authenticated;
create trigger capture_hlucin_terminal_counter after insert or update of raw_dex,dex_read_datetime,transmit_time,transaction_time on public.telemetry_dex_ingests for each row execute function public.capture_hlucin_terminal_counter();
-- Populate retained history without changing the original payload or its status.
insert into public.hlucin_terminal_counters
select distinct on(ts) ts,id,v[1]::numeric/100,v[2]::bigint,c[1]::numeric/100,c[2]::bigint,d[1]::numeric/100,d[2]::bigint
from (
 select id,coalesce(dex_read_datetime,transmit_time,transaction_time,created_at) ts,
 regexp_match(raw_dex,'(?:^|[\r\n])VA1\*([0-9]+)\*([0-9]+)(?:\*|[\r\n]|$)') v,
 regexp_match(raw_dex,'(?:^|[\r\n])CA2\*([0-9]+)\*([0-9]+)(?:\*|[\r\n]|$)') c,
 regexp_match(raw_dex,'(?:^|[\r\n])DA2\*([0-9]+)\*([0-9]+)(?:\*|[\r\n]|$)') d
 from public.telemetry_dex_ingests where provider='IMA' and device_id='597848'
) s where ts>='2026-09-13 16:06:25+00' and v is not null and c is not null and d is not null
order by ts,id desc on conflict(event_at) do nothing;

create or replace function public.get_hlucin_terminal_revenue(p_start timestamptz,p_end timestamptz)
returns jsonb language sql stable security invoker set search_path=public as $$
with ordered as (
 select *,lag(event_at) over w previous_at,
 total_amount-lag(total_amount) over w revenue,
 total_quantity-lag(total_quantity) over w quantity,
 cash_amount-lag(cash_amount) over w cash,
 card_amount-lag(card_amount) over w card,
 cash_quantity-lag(cash_quantity) over w cash_qty,
 card_quantity-lag(card_quantity) over w card_qty
 from public.hlucin_terminal_counters where event_at<p_end window w as(order by event_at)
), period as (
 select *,revenue>=0 and quantity>=0 and cash>=0 and card>=0 and cash_qty>=0 and card_qty>=0 and abs(revenue-cash-card)<0.01 and quantity=cash_qty+card_qty valid
 from ordered where event_at>=p_start
)
select jsonb_build_object(
 'revenue',coalesce(sum(revenue) filter(where valid),0),
 'quantity',coalesce(sum(quantity) filter(where valid),0),
 'cash',coalesce(sum(cash) filter(where valid),0),
 'card',coalesce(sum(card) filter(where valid),0),
 'intervals',count(*) filter(where valid),
 'skipped',count(*) filter(where previous_at is not null and not valid),
 'first_recorded_at',(select min(event_at) from public.hlucin_terminal_counters),
 'last_seen',max(event_at),
 'partial',not exists(select 1 from public.hlucin_terminal_counters where event_at<=p_start)
) from period;
$$;
revoke all on function public.get_hlucin_terminal_revenue(timestamptz,timestamptz) from public,anon;
grant execute on function public.get_hlucin_terminal_revenue(timestamptz,timestamptz) to authenticated,service_role;
commit;
