begin;

-- Interní tržbové hranice pro manažerské hodnocení automatů.
-- Minimum = hranice rentability, cíl = zdravý měsíční výkon.
create table if not exists public.control_economic_thresholds (
  machine_kind text primary key check (machine_kind in ('coffee', 'food')),
  minimum_monthly_revenue_czk numeric(12,2) not null check (minimum_monthly_revenue_czk >= 0),
  target_monthly_revenue_czk numeric(12,2) not null check (target_monthly_revenue_czk >= minimum_monthly_revenue_czk),
  note text null,
  updated_by uuid null references public.employees(id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

insert into public.control_economic_thresholds (
  machine_kind, minimum_monthly_revenue_czk, target_monthly_revenue_czk, note
) values
  ('food', 8000, 10000, 'Potravinový automat: interní měsíční minimum a zdravý cíl.'),
  ('coffee', 6000, 8000, 'Kávový automat: interní měsíční minimum a zdravý cíl.')
on conflict (machine_kind) do nothing;

create or replace function public.touch_control_economic_thresholds_updated_at()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

drop trigger if exists trg_control_economic_thresholds_updated_at on public.control_economic_thresholds;
create trigger trg_control_economic_thresholds_updated_at
before update on public.control_economic_thresholds
for each row execute function public.touch_control_economic_thresholds_updated_at();

alter table public.control_economic_thresholds enable row level security;

drop policy if exists control_economic_thresholds_read on public.control_economic_thresholds;
create policy control_economic_thresholds_read
on public.control_economic_thresholds for select to authenticated
using (public.security_active_employee());

revoke insert, update, delete on public.control_economic_thresholds from public, anon, authenticated;
grant select on public.control_economic_thresholds to authenticated;

create or replace function public.update_control_economic_threshold_v57(
  p_machine_kind text,
  p_minimum_monthly_revenue_czk numeric,
  p_target_monthly_revenue_czk numeric,
  p_note text default null
)
returns public.control_economic_thresholds
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_kind text := lower(trim(coalesce(p_machine_kind, '')));
  v_row public.control_economic_thresholds%rowtype;
begin
  if not public.has_manager_access() then
    raise exception 'Ekonomické limity může měnit pouze vedení.' using errcode = '42501';
  end if;
  if v_kind not in ('coffee', 'food') then
    raise exception 'Neplatný typ automatu.';
  end if;
  if p_minimum_monthly_revenue_czk is null or p_minimum_monthly_revenue_czk < 0 then
    raise exception 'Minimum musí být nezáporná částka.';
  end if;
  if p_target_monthly_revenue_czk is null or p_target_monthly_revenue_czk < p_minimum_monthly_revenue_czk then
    raise exception 'Zdravý cíl nesmí být nižší než minimum.';
  end if;

  insert into public.control_economic_thresholds (
    machine_kind, minimum_monthly_revenue_czk, target_monthly_revenue_czk,
    note, updated_by
  ) values (
    v_kind, round(p_minimum_monthly_revenue_czk, 2), round(p_target_monthly_revenue_czk, 2),
    nullif(trim(coalesce(p_note, '')), ''), public.current_employee_id()
  )
  on conflict (machine_kind) do update set
    minimum_monthly_revenue_czk = excluded.minimum_monthly_revenue_czk,
    target_monthly_revenue_czk = excluded.target_monthly_revenue_czk,
    note = excluded.note,
    updated_by = excluded.updated_by,
    updated_at = timezone('utc', now())
  returning * into v_row;

  return v_row;
end;
$$;

revoke all on function public.update_control_economic_threshold_v57(text, numeric, numeric, text) from public, anon;
grant execute on function public.update_control_economic_threshold_v57(text, numeric, numeric, text) to authenticated;

-- Jeden bezpečný agregovaný zdroj pro mobilní kontrolní modul. Telemetrické
-- prodeje jsou deduplikované po automatu a dni: pokud existuje přímá IMA,
-- pomocná VendSoft data téhož dne se nezapočtou. U ručních automatů se použijí
-- pouze přírůstky nemazacích počítadel, takže se tržba nezdvojí.
create or replace function public.get_control_economics_v57(
  p_machine_ids bigint[],
  p_as_of date default (timezone('Europe/Prague', now()))::date
)
returns table (
  machine_id bigint,
  machine_kind text,
  sales_tracking_mode text,
  minimum_monthly_revenue_czk numeric,
  target_monthly_revenue_czk numeric,
  current_month_revenue_czk numeric,
  projected_month_revenue_czk numeric,
  previous_month_revenue_czk numeric,
  trailing_30_days_revenue_czk numeric,
  current_month_units numeric,
  previous_month_units numeric,
  latest_sale_at timestamptz,
  data_quality text,
  evaluation_status text,
  previous_month_status text
)
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  with params as (
    select
      coalesce(p_as_of, (timezone('Europe/Prague', now()))::date) as as_of_date,
      date_trunc('month', coalesce(p_as_of, (timezone('Europe/Prague', now()))::date)::timestamp)::date as current_start
  ), boundaries as (
    select
      as_of_date,
      current_start,
      (current_start - interval '1 month')::date as previous_start,
      (current_start + interval '1 month')::date as next_start,
      (as_of_date - 29)::date as trailing_start,
      (as_of_date + 1)::date as end_exclusive,
      extract(day from as_of_date)::numeric as elapsed_days,
      extract(day from (current_start + interval '1 month - 1 day'))::numeric as month_days
    from params
  ), requested as (
    select
      machine.id as machine_id,
      case
        when lower(coalesce(machine.machine_type, '')) ~ '(coffee|káv|kav)' then 'coffee'
        when lower(coalesce(machine.machine_type, '')) ~ '(food|snack|potrav)' then 'food'
        else 'other'
      end as machine_kind,
      coalesce(nullif(machine.sales_tracking_mode, ''), 'telemetry') as sales_tracking_mode
    from public.machines machine
    where machine.id = any(coalesce(p_machine_ids, array[]::bigint[]))
      and coalesce(machine.active, true)
  ), telemetry_ranked as (
    select
      event.*,
      (event.source_event_at at time zone 'Europe/Prague')::date as sale_date,
      bool_or(lower(coalesce(event.provider, '')) = 'ima') over (
        partition by event.machine_id, (event.source_event_at at time zone 'Europe/Prague')::date
      ) as has_direct_ima_that_day
    from public.telemetry_sales_events event
    cross join boundaries b
    where event.machine_id = any(coalesce(p_machine_ids, array[]::bigint[]))
      and event.source_event_at >= (least(b.previous_start, b.trailing_start)::timestamp at time zone 'Europe/Prague')
      and event.source_event_at < (b.end_exclusive::timestamp at time zone 'Europe/Prague')
  ), telemetry_source as (
    select *
    from telemetry_ranked
    where not (lower(coalesce(provider, '')) = 'vendsoft' and has_direct_ima_that_day)
  ), telemetry_agg as (
    select
      event.machine_id,
      sum(coalesce(event.total_amount_czk, 0)) filter (
        where event.sale_date >= b.current_start and event.sale_date <= b.as_of_date
      ) as current_revenue,
      sum(coalesce(event.total_amount_czk, 0)) filter (
        where event.sale_date >= b.previous_start and event.sale_date < b.current_start
      ) as previous_revenue,
      sum(coalesce(event.total_amount_czk, 0)) filter (
        where event.sale_date >= b.trailing_start and event.sale_date <= b.as_of_date
      ) as trailing_revenue,
      sum(coalesce(event.quantity, 0)) filter (
        where event.sale_date >= b.current_start and event.sale_date <= b.as_of_date
      ) as current_units,
      sum(coalesce(event.quantity, 0)) filter (
        where event.sale_date >= b.previous_start and event.sale_date < b.current_start
      ) as previous_units,
      max(event.source_event_at) as latest_sale_at
    from telemetry_source event
    cross join boundaries b
    group by event.machine_id
  ), manual_agg as (
    select
      reading.machine_id,
      sum(greatest(coalesce(reading.revenue_delta_czk, 0), 0)) filter (
        where (reading.reading_at at time zone 'Europe/Prague')::date >= b.current_start
          and (reading.reading_at at time zone 'Europe/Prague')::date <= b.as_of_date
      ) as current_revenue,
      sum(greatest(coalesce(reading.revenue_delta_czk, 0), 0)) filter (
        where (reading.reading_at at time zone 'Europe/Prague')::date >= b.previous_start
          and (reading.reading_at at time zone 'Europe/Prague')::date < b.current_start
      ) as previous_revenue,
      sum(greatest(coalesce(reading.revenue_delta_czk, 0), 0)) filter (
        where (reading.reading_at at time zone 'Europe/Prague')::date >= b.trailing_start
          and (reading.reading_at at time zone 'Europe/Prague')::date <= b.as_of_date
      ) as trailing_revenue,
      sum(greatest(coalesce(reading.portion_delta, 0), 0)) filter (
        where (reading.reading_at at time zone 'Europe/Prague')::date >= b.current_start
          and (reading.reading_at at time zone 'Europe/Prague')::date <= b.as_of_date
      ) as current_units,
      sum(greatest(coalesce(reading.portion_delta, 0), 0)) filter (
        where (reading.reading_at at time zone 'Europe/Prague')::date >= b.previous_start
          and (reading.reading_at at time zone 'Europe/Prague')::date < b.current_start
      ) as previous_units,
      max(reading.reading_at) as latest_sale_at
    from public.machine_manual_counter_readings reading
    cross join boundaries b
    where reading.machine_id = any(coalesce(p_machine_ids, array[]::bigint[]))
      and reading.reading_at >= (least(b.previous_start, b.trailing_start)::timestamp at time zone 'Europe/Prague')
      and reading.reading_at < (b.end_exclusive::timestamp at time zone 'Europe/Prague')
    group by reading.machine_id
  ), source_presence as (
    select
      requested.machine_id,
      case
        when requested.sales_tracking_mode = 'manual_counters' then exists (
          select 1 from public.machine_manual_counter_readings reading
          where reading.machine_id = requested.machine_id
        )
        when requested.sales_tracking_mode = 'none' then false
        else exists (
          select 1 from public.telemetry_sales_events event
          where event.machine_id = requested.machine_id
        ) or exists (
          select 1 from public.machine_external_links link
          where link.machine_id = requested.machine_id and coalesce(link.telemetry_enabled, false)
        )
      end as has_source
    from requested
  ), metrics as (
    select
      requested.machine_id,
      requested.machine_kind,
      requested.sales_tracking_mode,
      threshold.minimum_monthly_revenue_czk,
      threshold.target_monthly_revenue_czk,
      case when requested.sales_tracking_mode = 'manual_counters' then coalesce(manual.current_revenue, 0) else coalesce(telemetry.current_revenue, 0) end as current_revenue,
      case when requested.sales_tracking_mode = 'manual_counters' then coalesce(manual.previous_revenue, 0) else coalesce(telemetry.previous_revenue, 0) end as previous_revenue,
      case when requested.sales_tracking_mode = 'manual_counters' then coalesce(manual.trailing_revenue, 0) else coalesce(telemetry.trailing_revenue, 0) end as trailing_revenue,
      case when requested.sales_tracking_mode = 'manual_counters' then coalesce(manual.current_units, 0) else coalesce(telemetry.current_units, 0) end as current_units,
      case when requested.sales_tracking_mode = 'manual_counters' then coalesce(manual.previous_units, 0) else coalesce(telemetry.previous_units, 0) end as previous_units,
      case when requested.sales_tracking_mode = 'manual_counters' then manual.latest_sale_at else telemetry.latest_sale_at end as latest_sale_at,
      source_presence.has_source,
      b.as_of_date,
      b.elapsed_days,
      b.month_days
    from requested
    cross join boundaries b
    left join public.control_economic_thresholds threshold on threshold.machine_kind = requested.machine_kind
    left join telemetry_agg telemetry on telemetry.machine_id = requested.machine_id
    left join manual_agg manual on manual.machine_id = requested.machine_id
    left join source_presence on source_presence.machine_id = requested.machine_id
  ), evaluated as (
    select
      metrics.*,
      round(case when elapsed_days > 0 then current_revenue / elapsed_days * month_days else current_revenue end, 2) as projected_revenue,
      case
        when minimum_monthly_revenue_czk is null or not has_source then 'no_data'
        when latest_sale_at is null then 'no_data'
        when (latest_sale_at at time zone 'Europe/Prague')::date < as_of_date - 7 then 'stale'
        else 'fresh'
      end as quality
    from metrics
  )
  select
    evaluated.machine_id,
    evaluated.machine_kind,
    evaluated.sales_tracking_mode,
    evaluated.minimum_monthly_revenue_czk,
    evaluated.target_monthly_revenue_czk,
    round(evaluated.current_revenue, 2),
    evaluated.projected_revenue,
    round(evaluated.previous_revenue, 2),
    round(evaluated.trailing_revenue, 2),
    round(evaluated.current_units, 3),
    round(evaluated.previous_units, 3),
    evaluated.latest_sale_at,
    evaluated.quality,
    case
      when evaluated.quality = 'no_data' then 'no_data'
      when evaluated.projected_revenue < evaluated.minimum_monthly_revenue_czk then 'below'
      when evaluated.projected_revenue < evaluated.target_monthly_revenue_czk then 'watch'
      else 'good'
    end,
    case
      when evaluated.quality = 'no_data' then 'no_data'
      when evaluated.previous_revenue < evaluated.minimum_monthly_revenue_czk then 'below'
      when evaluated.previous_revenue < evaluated.target_monthly_revenue_czk then 'watch'
      else 'good'
    end
  from evaluated
  where public.security_active_employee()
  order by evaluated.machine_id;
$$;

revoke all on function public.get_control_economics_v57(bigint[], date) from public, anon;
grant execute on function public.get_control_economics_v57(bigint[], date) to authenticated;

create or replace function public.get_control_price_scenarios_v57(
  p_control_route_machine_ids bigint[],
  p_as_of date default (timezone('Europe/Prague', now()))::date
)
returns table (
  control_route_machine_id bigint,
  machine_id bigint,
  change_count integer,
  current_30_days_revenue_czk numeric,
  price_effect_no_volume_change_czk numeric,
  scenario_no_decline_czk numeric,
  scenario_volume_minus_5_czk numeric,
  scenario_volume_minus_10_czk numeric,
  break_even_volume_loss_percent numeric,
  data_quality text,
  changes jsonb
)
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  with allowed_machines as (
    select crm.id as control_route_machine_id, crm.machine_id, crm.machine_kind
    from public.control_route_machines crm
    join public.control_route_stops crs on crs.id = crm.control_route_stop_id
    join public.control_routes cr on cr.id = crs.control_route_id
    where crm.id = any(coalesce(p_control_route_machine_ids, array[]::bigint[]))
      and (
        cr.assigned_employee_id = public.current_employee_id()
        or public.has_manager_access()
      )
  ), control_changes_ranked as (
    select
      adjustment.control_route_machine_id,
      adjustment.machine_id,
      adjustment.target_kind,
      adjustment.target_record_id,
      coalesce(slot.slot_code, button.selection_code) as selection_code,
      coalesce(slot.product_name, button.product_name, 'Položka') as product_name,
      case
        when adjustment.target_kind = 'coffee_button' then nullif(adjustment.before_value->>'sale_price_czk', '')::numeric
        else nullif(adjustment.before_value->>'price_czk', '')::numeric
      end as old_price,
      case
        when adjustment.target_kind = 'coffee_button' then nullif(adjustment.after_value->>'sale_price_czk', '')::numeric
        else nullif(adjustment.after_value->>'price_czk', '')::numeric
      end as new_price,
      'Dnešní kontrola'::text as change_source,
      1 as source_priority,
      row_number() over (
        partition by adjustment.control_route_machine_id, adjustment.target_kind, adjustment.target_record_id
        order by adjustment.created_at desc, adjustment.id desc
      ) as source_rank
    from public.control_machine_adjustments adjustment
    join allowed_machines allowed on allowed.control_route_machine_id = adjustment.control_route_machine_id
    left join public.machine_planogram_slots slot
      on adjustment.target_kind = 'food_slot' and slot.id = adjustment.target_record_id
    left join public.machine_coffee_buttons button
      on adjustment.target_kind = 'coffee_button' and button.id = adjustment.target_record_id
    where adjustment.adjustment_type = 'price'
      and adjustment.status = 'applied'
  ), control_changes as (
    select * from control_changes_ranked
    where source_rank = 1 and old_price is not null and new_price is not null and old_price <> new_price
  ), pending_changes as (
    select
      allowed.control_route_machine_id,
      request.machine_id,
      'food_slot'::text as target_kind,
      request.planogram_slot_id as target_record_id,
      request.slot_code as selection_code,
      request.product_name,
      request.recommended_price_czk as old_price,
      request.proposed_price_czk as new_price,
      'Čeká na schválení'::text as change_source,
      2 as source_priority,
      1::bigint as source_rank
    from public.operator_price_change_requests request
    join allowed_machines allowed on allowed.machine_id = request.machine_id
    where request.status = 'pending'
  ), planned_food_changes as (
    select
      allowed.control_route_machine_id,
      slot.machine_id,
      'food_slot'::text as target_kind,
      slot.id as target_record_id,
      slot.slot_code as selection_code,
      coalesce(slot.planned_product_name, slot.product_name, 'Položka') as product_name,
      coalesce(slot.customer_price_czk, slot.price_czk) as old_price,
      slot.planned_price_czk as new_price,
      'Plánovaná cena'::text as change_source,
      3 as source_priority,
      1::bigint as source_rank
    from allowed_machines allowed
    join public.machine_planogram_slots slot
      on slot.machine_id = allowed.machine_id and coalesce(slot.active, true)
    where slot.planned_price_czk is not null
      and slot.planned_price_czk is distinct from coalesce(slot.customer_price_czk, slot.price_czk)
  ), planned_coffee_changes as (
    select
      allowed.control_route_machine_id,
      button.machine_id,
      'coffee_button'::text as target_kind,
      button.id as target_record_id,
      button.selection_code,
      coalesce(button.planned_product_name, button.product_name, 'Nápoj') as product_name,
      coalesce(button.customer_price_czk, button.sale_price_czk) as old_price,
      button.planned_price_czk as new_price,
      'Plánovaná cena'::text as change_source,
      3 as source_priority,
      1::bigint as source_rank
    from allowed_machines allowed
    join public.machine_coffee_buttons button
      on button.machine_id = allowed.machine_id and coalesce(button.active, true)
    where button.planned_price_czk is not null
      and button.planned_price_czk is distinct from coalesce(button.customer_price_czk, button.sale_price_czk)
  ), all_change_candidates as (
    select * from control_changes
    union all select * from pending_changes
    union all select * from planned_food_changes
    union all select * from planned_coffee_changes
  ), selected_changes as (
    select *
    from (
      select candidate.*,
        row_number() over (
          partition by candidate.control_route_machine_id, candidate.target_kind, candidate.target_record_id
          order by candidate.source_priority
        ) as final_rank
      from all_change_candidates candidate
    ) ranked
    where final_rank = 1
      and old_price is not null and new_price is not null and old_price > 0 and new_price > 0
  ), telemetry_ranked as (
    select
      event.*,
      bool_or(lower(coalesce(event.provider, '')) = 'ima') over (
        partition by event.machine_id, (event.source_event_at at time zone 'Europe/Prague')::date
      ) as has_direct_ima_that_day
    from public.telemetry_sales_events event
    where event.machine_id in (select allowed.machine_id from allowed_machines allowed)
      and event.source_event_at >= (((coalesce(p_as_of, (timezone('Europe/Prague', now()))::date) - 29)::timestamp) at time zone 'Europe/Prague')
      and event.source_event_at < (((coalesce(p_as_of, (timezone('Europe/Prague', now()))::date) + 1)::timestamp) at time zone 'Europe/Prague')
  ), telemetry_source as (
    select * from telemetry_ranked
    where not (lower(coalesce(provider, '')) = 'vendsoft' and has_direct_ima_that_day)
  ), machine_revenue as (
    select machine_id, sum(coalesce(total_amount_czk, 0)) as revenue
    from telemetry_source
    group by machine_id
  ), change_units as (
    select
      change.*,
      coalesce(sold.units, 0) as units_30_days,
      coalesce(sold.matched_events, 0) as matched_events
    from selected_changes change
    left join lateral (
      select sum(coalesce(event.quantity, 0)) as units, count(*) as matched_events
      from telemetry_source event
      where event.machine_id = change.machine_id
        and (
          event.selection_code = change.selection_code
          or (
            change.target_kind = 'food_slot'
            and event.planogram_slot_id = change.target_record_id
          )
        )
    ) sold on true
  ), aggregated as (
    select
      allowed.control_route_machine_id,
      allowed.machine_id,
      count(change.target_record_id)::integer as change_count,
      coalesce(max(revenue.revenue), 0) as baseline_revenue,
      coalesce(sum(change.units_30_days * (change.new_price - change.old_price)), 0) as price_effect,
      count(change.target_record_id) filter (where change.matched_events = 0) as unmatched_changes,
      coalesce(jsonb_agg(jsonb_build_object(
        'target_kind', change.target_kind,
        'target_record_id', change.target_record_id,
        'selection_code', change.selection_code,
        'product_name', change.product_name,
        'old_price_czk', change.old_price,
        'new_price_czk', change.new_price,
        'units_30_days', change.units_30_days,
        'monthly_effect_czk', round(change.units_30_days * (change.new_price - change.old_price), 2),
        'source', change.change_source,
        'has_sales_mix', change.matched_events > 0
      ) order by change.selection_code, change.target_record_id) filter (where change.target_record_id is not null), '[]'::jsonb) as changes
    from allowed_machines allowed
    left join change_units change on change.control_route_machine_id = allowed.control_route_machine_id
    left join machine_revenue revenue on revenue.machine_id = allowed.machine_id
    group by allowed.control_route_machine_id, allowed.machine_id
  )
  select
    aggregated.control_route_machine_id,
    aggregated.machine_id,
    aggregated.change_count,
    round(aggregated.baseline_revenue, 2),
    round(aggregated.price_effect, 2),
    round(aggregated.baseline_revenue + aggregated.price_effect, 2),
    round((aggregated.baseline_revenue + aggregated.price_effect) * 0.95, 2),
    round((aggregated.baseline_revenue + aggregated.price_effect) * 0.90, 2),
    case
      when aggregated.price_effect > 0 and aggregated.baseline_revenue + aggregated.price_effect > 0
        then round((1 - aggregated.baseline_revenue / (aggregated.baseline_revenue + aggregated.price_effect)) * 100, 1)
      else null
    end,
    case
      when aggregated.change_count = 0 then 'no_changes'
      when aggregated.baseline_revenue <= 0 then 'no_sales_data'
      when aggregated.unmatched_changes > 0 then 'incomplete_mix'
      else 'ready'
    end,
    aggregated.changes
  from aggregated
  where public.security_active_employee()
  order by aggregated.control_route_machine_id;
$$;

revoke all on function public.get_control_price_scenarios_v57(bigint[], date) from public, anon;
grant execute on function public.get_control_price_scenarios_v57(bigint[], date) to authenticated;

comment on table public.control_economic_thresholds is
  'Interní editovatelné měsíční tržbové minimum a zdravý cíl pro manažerské kontroly.';
comment on function public.get_control_economics_v57(bigint[], date) is
  'Vrací bezpečně agregované tržbové ukazatele automatů pro kontrolní trasu; neovlivňuje doplňovací trasy.';
comment on function public.get_control_price_scenarios_v57(bigint[], date) is
  'Odhaduje dopad cenových změn z kontroly, plánogramu a čekajících schválení při stejném, o 5 % a o 10 % nižším objemu prodeje.';

commit;
