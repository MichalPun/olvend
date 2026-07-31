begin;

alter table public.machine_planogram_slots
  add column if not exists changeover_old_units numeric(12,3),
  add column if not exists changeover_new_units numeric(12,3),
  add column if not exists changeover_started_at timestamptz;

comment on column public.machine_planogram_slots.changeover_old_units is
  'Units of the currently active product remaining in front of a planned replacement.';
comment on column public.machine_planogram_slots.changeover_new_units is
  'Units of planned_product_sku already physically loaded behind the old product.';

alter table public.telemetry_sales_events
  add column if not exists event_part smallint not null default 1;

do $$
declare
  v_constraint record;
begin
  for v_constraint in
    select conname
    from pg_constraint
    where conrelid = 'public.telemetry_sales_events'::regclass
      and contype = 'u'
      and pg_get_constraintdef(oid) ilike '%provider%ingest_id%machine_id%planogram_slot_id%selection_code%'
  loop
    execute format('alter table public.telemetry_sales_events drop constraint %I', v_constraint.conname);
  end loop;
end;
$$;

create unique index if not exists telemetry_sales_events_ingest_slot_part_uidx
  on public.telemetry_sales_events
  (provider, ingest_id, machine_id, planogram_slot_id, selection_code, event_part)
  where ingest_id is not null;

create unique index if not exists telemetry_sales_events_source_key_part_uidx
  on public.telemetry_sales_events (provider, source_event_key, event_part)
  where source_event_key is not null;

create or replace function public.split_vendsoft_mixed_changeover_sale()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_slot public.machine_planogram_slots%rowtype;
  v_old_sold numeric;
  v_new_sold numeric;
  v_ratio numeric;
begin
  if lower(new.provider) <> 'vendsoft' or new.event_part <> 1 then
    return new;
  end if;
  select * into v_slot from public.machine_planogram_slots where id = new.planogram_slot_id for update;
  if not found or coalesce(v_slot.changeover_new_units, 0) <= 0
     or nullif(trim(v_slot.planned_product_sku), '') is null then
    return new;
  end if;

  v_old_sold := least(new.quantity, greatest(0, coalesce(v_slot.changeover_old_units, 0)));
  v_new_sold := greatest(0, new.quantity - v_old_sold);

  if v_new_sold > 0 then
    v_ratio := v_new_sold / new.quantity;
    insert into public.telemetry_sales_events (
      provider, ingest_id, machine_id, planogram_slot_id, selection_code, product_name, product_sku,
      quantity, cash_quantity, cashless_quantity, unknown_payment_quantity, unit_price_czk,
      total_amount_czk, cash_amount_czk, cashless_amount_czk, unknown_payment_amount_czk,
      source_event_at, event_part
    ) values (
      new.provider, new.ingest_id, new.machine_id, new.planogram_slot_id, new.selection_code,
      v_slot.planned_product_name, v_slot.planned_product_sku, v_new_sold,
      round(new.cash_quantity * v_ratio, 3), round(new.cashless_quantity * v_ratio, 3),
      round(new.unknown_payment_quantity * v_ratio, 3), coalesce(v_slot.planned_price_czk, new.unit_price_czk),
      round(coalesce(v_slot.planned_price_czk, new.unit_price_czk) * v_new_sold, 2),
      round(coalesce(v_slot.planned_price_czk, new.unit_price_czk) * new.cash_quantity * v_ratio, 2),
      round(coalesce(v_slot.planned_price_czk, new.unit_price_czk) * new.cashless_quantity * v_ratio, 2),
      round(coalesce(v_slot.planned_price_czk, new.unit_price_czk) * new.unknown_payment_quantity * v_ratio, 2),
      new.source_event_at, 2
    );
  end if;

  update public.machine_planogram_slots
  set changeover_old_units = greatest(0, coalesce(changeover_old_units, 0) - v_old_sold),
      changeover_new_units = greatest(0, coalesce(changeover_new_units, 0) - v_new_sold),
      product_sku = case when v_old_sold >= coalesce(changeover_old_units, 0) then planned_product_sku else product_sku end,
      product_name = case when v_old_sold >= coalesce(changeover_old_units, 0) then coalesce(planned_product_name, product_name) else product_name end,
      price_czk = case when v_old_sold >= coalesce(changeover_old_units, 0) then coalesce(planned_price_czk, price_czk) else price_czk end,
      customer_price_czk = case when v_old_sold >= coalesce(changeover_old_units, 0) then coalesce(planned_price_czk, customer_price_czk) else customer_price_czk end,
      dex_price_czk = case when v_old_sold >= coalesce(changeover_old_units, 0) then coalesce(planned_price_czk, dex_price_czk) else dex_price_czk end,
      planned_product_sku = case when v_old_sold >= coalesce(changeover_old_units, 0) then null else planned_product_sku end,
      planned_product_name = case when v_old_sold >= coalesce(changeover_old_units, 0) then null else planned_product_name end,
      planned_price_czk = case when v_old_sold >= coalesce(changeover_old_units, 0) then null else planned_price_czk end,
      changeover_started_at = case when v_old_sold >= coalesce(changeover_old_units, 0) then null else changeover_started_at end
  where id = v_slot.id;

  if v_old_sold <= 0 then
    new.event_part := 2;
    new.product_name := v_slot.planned_product_name;
    new.product_sku := v_slot.planned_product_sku;
    new.unit_price_czk := coalesce(v_slot.planned_price_czk, new.unit_price_czk);
    return new;
  end if;
  v_ratio := v_old_sold / new.quantity;
  new.quantity := v_old_sold;
  new.cash_quantity := round(new.cash_quantity * v_ratio, 3);
  new.cashless_quantity := round(new.cashless_quantity * v_ratio, 3);
  new.unknown_payment_quantity := round(new.unknown_payment_quantity * v_ratio, 3);
  new.total_amount_czk := round(coalesce(new.unit_price_czk, 0) * v_old_sold, 2);
  new.cash_amount_czk := round(coalesce(new.unit_price_czk, 0) * new.cash_quantity, 2);
  new.cashless_amount_czk := round(coalesce(new.unit_price_czk, 0) * new.cashless_quantity, 2);
  new.unknown_payment_amount_czk := round(coalesce(new.unit_price_czk, 0) * new.unknown_payment_quantity, 2);
  return new;
end;
$$;

drop trigger if exists telemetry_sales_events_split_vendsoft_changeover on public.telemetry_sales_events;
create trigger telemetry_sales_events_split_vendsoft_changeover
before insert on public.telemetry_sales_events
for each row execute function public.split_vendsoft_mixed_changeover_sale();

create or replace function public.activate_planned_planogram_product_at_zero()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_planned_sku text;
  v_planned_name text;
  v_planned_price numeric;
begin
  v_planned_sku := nullif(trim(new.planned_product_sku), '');

  if coalesce(old.current_units, 0) > 0
     and coalesce(new.current_units, 0) <= 0
     and v_planned_sku is not null
     and coalesce(new.changeover_new_units, 0) <= 0
     and v_planned_sku is distinct from nullif(trim(new.product_sku), '') then
    v_planned_name := nullif(trim(new.planned_product_name), '');
    v_planned_price := new.planned_price_czk;
    new.product_sku := v_planned_sku;
    new.product_name := coalesce(v_planned_name, new.product_name);
    if v_planned_price is not null then
      new.price_czk := v_planned_price;
      new.customer_price_czk := v_planned_price;
      new.dex_price_czk := v_planned_price;
    end if;
    new.planned_product_sku := null;
    new.planned_product_name := null;
    new.planned_price_czk := null;
    new.changeover_old_units := null;
    new.changeover_new_units := null;
    new.changeover_started_at := null;
  end if;
  new.updated_at := now();
  return new;
end;
$$;

commit;
notify pgrst, 'reload schema';
