begin;

create temporary table audit27_balance_fix on commit drop as
with current_balances as (
  select stock_location_id, product_id, sum(quantity_on_hand) as quantity_on_hand
  from public.stock_location_balances
  group by stock_location_id, product_id
)
select
  item.stock_location_id,
  item.product_id,
  item.counted_quantity
from public.inventory_audit_items item
left join current_balances balance
  on balance.stock_location_id = item.stock_location_id
 and balance.product_id = item.product_id
where item.audit_id = 27
  and abs(coalesce(balance.quantity_on_hand, 0) - item.counted_quantity) > 0.001;

update public.stock_location_balances balance
set quantity_on_hand = 0,
    reserved_quantity = 0,
    updated_at = now()
from audit27_balance_fix fix
where balance.stock_location_id = fix.stock_location_id
  and balance.product_id = fix.product_id;

update public.stock_location_balances balance
set quantity_on_hand = fix.counted_quantity,
    reserved_quantity = 0,
    updated_at = now()
from audit27_balance_fix fix
where fix.counted_quantity > 0
  and balance.id = (
    select candidate.id
    from public.stock_location_balances candidate
    where candidate.stock_location_id = fix.stock_location_id
      and candidate.product_id = fix.product_id
      and candidate.batch_id is null
    order by candidate.id
    limit 1
  );

insert into public.stock_location_balances (
  stock_location_id,
  product_id,
  batch_id,
  quantity_on_hand,
  reserved_quantity,
  updated_at
)
select
  fix.stock_location_id,
  fix.product_id,
  null,
  fix.counted_quantity,
  0,
  now()
from audit27_balance_fix fix
where fix.counted_quantity > 0
  and not exists (
    select 1
    from public.stock_location_balances balance
    where balance.stock_location_id = fix.stock_location_id
      and balance.product_id = fix.product_id
      and balance.batch_id is null
  );

commit;
