begin;

with grouped_balances as (
  select
    stock_location_id,
    product_id,
    batch_id,
    min(id) as keep_id,
    count(*) as row_count,
    round(sum(coalesce(quantity_on_hand, 0))::numeric, 3) as total_quantity,
    round(sum(coalesce(reserved_quantity, 0))::numeric, 3) as total_reserved
  from public.stock_location_balances
  group by stock_location_id, product_id, batch_id
),
updated_keepers as (
  update public.stock_location_balances balance
  set
    quantity_on_hand = grouped_balances.total_quantity,
    reserved_quantity = grouped_balances.total_reserved,
    updated_at = now()
  from grouped_balances
  where balance.id = grouped_balances.keep_id
    and grouped_balances.row_count > 1
  returning balance.id
)
delete from public.stock_location_balances balance
using grouped_balances
where grouped_balances.row_count > 1
  and balance.stock_location_id = grouped_balances.stock_location_id
  and balance.product_id = grouped_balances.product_id
  and balance.batch_id is not distinct from grouped_balances.batch_id
  and balance.id <> grouped_balances.keep_id;

with negative_balances as (
  select
    id,
    stock_location_id,
    product_id,
    batch_id,
    quantity_on_hand
  from public.stock_location_balances
  where quantity_on_hand < 0
)
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
  product_id,
  batch_id,
  null,
  stock_location_id,
  'adjustment',
  abs(quantity_on_hand),
  'negative_balance_repair',
  'negative-balance-repair:2026-05-27',
  concat('2026-05-27 · dorovnání záporného stavu na nulu · původní stav ', quantity_on_hand, ' · balance_id ', id)
from negative_balances;

update public.stock_location_balances
set
  quantity_on_hand = 0,
  updated_at = now()
where quantity_on_hand < 0;

create unique index if not exists stock_location_balances_location_product_batch_uidx
on public.stock_location_balances (stock_location_id, product_id, batch_id) nulls not distinct;

commit;
