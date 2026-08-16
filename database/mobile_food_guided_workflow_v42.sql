begin;

alter table public.route_machine_cash_reports
  add column if not exists collection_required boolean not null default false,
  add column if not exists collection_threshold_czk numeric(12,2) not null default 200,
  add column if not exists short_bag_code text,
  add column if not exists bag_reference uuid,
  add column if not exists retained_for_next_visit boolean not null default false;

create unique index if not exists route_machine_cash_open_bag_code_idx
  on public.route_machine_cash_reports (short_bag_code)
  where operator_collected_confirmed is true and supervisor_counted_at is null and short_bag_code is not null;

create or replace function public.get_mobile_route_sales_v42(
  p_machine_ids bigint[],
  p_since timestamptz
)
returns table(machine_id bigint, product_sku text, sold_quantity numeric)
language sql
stable
security definer
set search_path = public
as $$
  select
    sale.machine_id,
    sale.product_sku,
    sum(
      coalesce(sale.cash_quantity,0)
      + coalesce(sale.cashless_quantity,0)
      + coalesce(sale.free_vend_quantity,0)
      + coalesce(sale.unknown_payment_quantity,0)
    )::numeric as sold_quantity
  from public.telemetry_sales_events sale
  where sale.machine_id = any(coalesce(p_machine_ids,'{}'::bigint[]))
    and sale.source_event_at >= p_since
  group by sale.machine_id,sale.product_sku;
$$;

revoke all on function public.get_mobile_route_sales_v42(bigint[],timestamptz) from public, anon;
grant execute on function public.get_mobile_route_sales_v42(bigint[],timestamptz) to authenticated;

create or replace function public.assign_food_visit_guidance_v42(p_visit_id bigint)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_visit public.route_machine_visits%rowtype;
  v_last_collection timestamptz;
  v_expected_cash numeric(12,2) := 0;
  v_collection_required boolean := false;
  v_bag text;
  v_cash public.route_machine_cash_reports%rowtype;
begin
  select * into v_visit
  from public.route_machine_visits
  where id = p_visit_id;
  if not found then raise exception 'Návštěva neexistuje.'; end if;
  if v_visit.machine_kind is distinct from 'food' then
    raise exception 'Vedený potravinový postup lze přiřadit pouze potravinovému automatu.';
  end if;

  insert into public.route_machine_visit_checks(visit_id,check_key,label,required,status,assigned_payload)
  values
    (p_visit_id,'waste_bag','Odnes odpad a obaly',true,'pending','{"section":"inside","order":10}'::jsonb),
    (p_visit_id,'washed','Očisti vnitřek automatu',true,'pending','{"section":"inside","order":20}'::jsonb),
    (p_visit_id,'shelves','Srovnej police a spirály',true,'pending','{"section":"inside","order":30}'::jsonb),
    (p_visit_id,'polished','Očisti sklo a ovládací panel',true,'pending','{"section":"outside","order":40}'::jsonb),
    (p_visit_id,'test_vend','Proveď kontrolní výdej a ověř chod',true,'pending','{"section":"test","order":50}'::jsonb)
  on conflict(visit_id,check_key) do update
  set label = excluded.label,
      required = true,
      assigned_payload = excluded.assigned_payload;

  select max(operator_collected_at) into v_last_collection
  from public.route_machine_cash_reports
  where machine_id = v_visit.machine_id
    and visit_id <> p_visit_id
    and operator_collected_confirmed is true;

  select coalesce(sum(coalesce(cash_amount_czk,0)),0)::numeric(12,2) into v_expected_cash
  from public.telemetry_sales_events
  where machine_id = v_visit.machine_id
    and (v_last_collection is null or source_event_at > v_last_collection);

  v_collection_required := v_expected_cash > 200;
  if v_collection_required then
    perform pg_advisory_xact_lock(hashtextextended('route_machine_cash_short_bag_code',0));
    loop
      v_bag := lpad((1000 + floor(random()*9000)::int)::text,4,'0');
      exit when not exists(
        select 1 from public.route_machine_cash_reports
        where short_bag_code = v_bag
          and supervisor_counted_at is null
      );
    end loop;
  end if;

  select * into v_cash
  from public.route_machine_cash_reports
  where visit_id = p_visit_id
  for update;

  if v_cash.id is null then
    insert into public.route_machine_cash_reports(
      visit_id,machine_id,expected_cash_czk,expected_total_czk,
      collection_required,collection_threshold_czk,short_bag_code,bag_reference,
      retained_for_next_visit
    ) values (
      p_visit_id,v_visit.machine_id,v_expected_cash,v_expected_cash,
      v_collection_required,200,case when v_collection_required then v_bag else null end,
      case when v_collection_required then gen_random_uuid() else null end,
      not v_collection_required
    ) returning * into v_cash;
  elsif v_cash.operator_collected_at is null
    and v_cash.operator_collected_confirmed is false then
    update public.route_machine_cash_reports
    set expected_cash_czk = v_expected_cash,
        expected_total_czk = v_expected_cash,
        collection_required = v_collection_required,
        collection_threshold_czk = 200,
        short_bag_code = case when v_collection_required then coalesce(v_cash.short_bag_code,v_bag) else null end,
        bag_reference = case when v_collection_required then coalesce(v_cash.bag_reference,gen_random_uuid()) else null end,
        retained_for_next_visit = not v_collection_required
    where id = v_cash.id
    returning * into v_cash;
  end if;

  return jsonb_build_object(
    'collection_required',v_cash.collection_required,
    'suggested_bag_code',v_cash.short_bag_code,
    'cash_report_id',v_cash.id
  );
end;
$$;

grant execute on function public.assign_food_visit_guidance_v42(bigint) to authenticated, anon;

commit;
