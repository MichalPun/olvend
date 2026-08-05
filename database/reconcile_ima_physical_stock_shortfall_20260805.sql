-- One-time guarded reconstruction for the 64 physical PA2 vends from the
-- 2026-08-04 payment repair that exceeded the already-zero book balance.
begin;

lock table public.telemetry_sales_events in share row exclusive mode;
lock table public.stock_location_balances in share row exclusive mode;

create table if not exists public.telemetry_stock_reconstruction_backup_v25_20260805 (
  sale_event_id bigint primary key,
  row_data jsonb not null,
  backed_up_at timestamptz not null default now()
);

create temporary table ima_stock_shortfalls on commit drop as
with original_unpaid as (
  select id
  from public.telemetry_sales_payment_backup_v25_20260804
  where coalesce((row_data ->> 'unpaid_dispense_quantity')::numeric, 0) > 0
), expected as (
  select
    sale.id as sale_event_id,
    sale.machine_id,
    sale.quantity,
    product.id as product_id,
    location.id as stock_location_id
  from original_unpaid original
  join public.telemetry_sales_events sale using (id)
  join lateral (
    select candidate.id
    from public.products candidate
    where candidate.sku = sale.product_sku
    order by candidate.active desc, candidate.id
    limit 1
  ) product on true
  join lateral (
    select candidate.id
    from public.stock_locations candidate
    where candidate.location_type = 'machine'
      and candidate.machine_id = sale.machine_id
    order by candidate.id
    limit 1
  ) location on true
  where not exists (
    select 1
    from public.machine_coffee_buttons button
    where button.machine_id = sale.machine_id
      and button.selection_code = sale.selection_code
      and button.active
  )
), actual as (
  select
    depletion.sale_event_id,
    depletion.product_id,
    sum(depletion.quantity) as quantity
  from public.telemetry_stock_depletions depletion
  join expected
    on expected.sale_event_id = depletion.sale_event_id
   and expected.product_id = depletion.product_id
  group by depletion.sale_event_id, depletion.product_id
)
select
  expected.sale_event_id,
  expected.machine_id,
  expected.stock_location_id,
  expected.product_id,
  greatest(0, expected.quantity - coalesce(actual.quantity, 0))::numeric(14,3) as quantity
from expected
left join actual using (sale_event_id, product_id)
where expected.quantity > coalesce(actual.quantity, 0);

do $$
declare
  v_shortage numeric;
  v_existing_backup numeric;
  v_book_balance numeric;
begin
  select coalesce(sum(quantity), 0) into v_shortage
  from ima_stock_shortfalls;

  select coalesce(sum((row_data ->> 'quantity')::numeric), 0) into v_existing_backup
  from public.telemetry_stock_reconstruction_backup_v25_20260805;

  if not (
    v_shortage = 64
    or (v_shortage = 0 and v_existing_backup = 64)
  ) then
    raise exception 'Expected the guarded 64-unit IMA stock reconstruction, found % units with % already backed up.',
      v_shortage, v_existing_backup;
  end if;

  select coalesce(sum(balance.quantity_on_hand), 0) into v_book_balance
  from public.stock_location_balances balance
  join (
    select distinct stock_location_id, product_id
    from ima_stock_shortfalls
  ) shortage
    on shortage.stock_location_id = balance.stock_location_id
   and shortage.product_id = balance.product_id;

  if v_book_balance <> 0 then
    raise exception 'IMA reconstruction is only valid above a zero book balance; current guarded balance is %.', v_book_balance;
  end if;
end $$;

insert into public.telemetry_stock_reconstruction_backup_v25_20260805 (sale_event_id, row_data)
select
  shortage.sale_event_id,
  jsonb_build_object(
    'sale_event_id', shortage.sale_event_id,
    'machine_id', shortage.machine_id,
    'stock_location_id', shortage.stock_location_id,
    'product_id', shortage.product_id,
    'quantity', shortage.quantity
  )
from ima_stock_shortfalls shortage
on conflict (sale_event_id) do nothing;

insert into public.stock_movements_v13 (
  product_id,
  batch_id,
  from_stock_location_id,
  to_stock_location_id,
  movement_type,
  quantity_base_units,
  reference_type,
  reference_id,
  note
)
select
  shortage.product_id,
  null,
  null,
  shortage.stock_location_id,
  'adjustment',
  shortage.quantity,
  'telemetry_stock_reconstruction',
  'telemetry-stock-reconstruction:' || shortage.sale_event_id,
  '2026-08-05 · rekonstrukce chybějícího stavu podle fyzického PA2 výdeje #' || shortage.sale_event_id
from ima_stock_shortfalls shortage
where not exists (
  select 1
  from public.stock_movements_v13 movement
  where movement.reference_type = 'telemetry_stock_reconstruction'
    and movement.reference_id = 'telemetry-stock-reconstruction:' || shortage.sale_event_id
);

insert into public.telemetry_stock_depletions (
  sale_event_id,
  stock_location_id,
  product_id,
  batch_id,
  quantity
)
select
  shortage.sale_event_id,
  shortage.stock_location_id,
  shortage.product_id,
  null,
  shortage.quantity
from ima_stock_shortfalls shortage
on conflict (sale_event_id, product_id, batch_id) do update
set quantity = public.telemetry_stock_depletions.quantity + excluded.quantity;

insert into public.stock_movements_v13 (
  product_id,
  batch_id,
  from_stock_location_id,
  to_stock_location_id,
  movement_type,
  quantity_base_units,
  reference_type,
  reference_id,
  note
)
select
  shortage.product_id,
  null,
  shortage.stock_location_id,
  null,
  'sale',
  shortage.quantity,
  'telemetry_sale_reconstruction',
  'telemetry-sale-reconstruction:' || shortage.sale_event_id,
  '2026-08-05 · fyzický telemetrický výdej #' || shortage.sale_event_id || ' podle PA2 · rekonstruovaný stav'
from ima_stock_shortfalls shortage
where not exists (
  select 1
  from public.stock_movements_v13 movement
  where movement.reference_type = 'telemetry_sale_reconstruction'
    and movement.reference_id = 'telemetry-sale-reconstruction:' || shortage.sale_event_id
);

do $$
declare
  v_missing numeric;
  v_reconstructed_in numeric;
  v_reconstructed_out numeric;
begin
  with expected as (
    select
      backup.sale_event_id,
      (backup.row_data ->> 'product_id')::bigint as product_id,
      (backup.row_data ->> 'quantity')::numeric as repaired_quantity
    from public.telemetry_stock_reconstruction_backup_v25_20260805 backup
  ), current_depletion as (
    select
      depletion.sale_event_id,
      depletion.product_id,
      sum(depletion.quantity) as quantity
    from public.telemetry_stock_depletions depletion
    join expected using (sale_event_id, product_id)
    group by depletion.sale_event_id, depletion.product_id
  )
  select coalesce(sum(greatest(0, expected.repaired_quantity - coalesce(current_depletion.quantity, 0))), 0)
  into v_missing
  from expected
  left join current_depletion using (sale_event_id, product_id);

  select coalesce(sum(quantity_base_units), 0) into v_reconstructed_in
  from public.stock_movements_v13
  where reference_type = 'telemetry_stock_reconstruction';

  select coalesce(sum(quantity_base_units), 0) into v_reconstructed_out
  from public.stock_movements_v13
  where reference_type = 'telemetry_sale_reconstruction';

  if v_missing <> 0 or v_reconstructed_in <> 64 or v_reconstructed_out <> 64 then
    raise exception 'IMA stock reconstruction validation failed: missing %, in %, out %.',
      v_missing, v_reconstructed_in, v_reconstructed_out;
  end if;
end $$;

commit;

select
  count(*) as repaired_event_rows,
  sum((row_data ->> 'quantity')::numeric) as repaired_quantity
from public.telemetry_stock_reconstruction_backup_v25_20260805;
