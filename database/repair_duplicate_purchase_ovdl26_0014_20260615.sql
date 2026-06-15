begin;

create temp table duplicate_purchase_receipt_20260615 as
select
  to_stock_location_id as stock_location_id,
  product_id,
  batch_id,
  sum(quantity_base_units)::numeric(12,3) as quantity_to_remove
from public.stock_movements_v13
where reference_type = 'purchase_order'
  and reference_id = '31'
  and movement_type = 'receipt'
group by to_stock_location_id, product_id, batch_id;

update public.stock_location_balances balance
set
  quantity_on_hand = round((balance.quantity_on_hand - duplicate.quantity_to_remove)::numeric, 3),
  updated_at = now()
from duplicate_purchase_receipt_20260615 duplicate
where balance.stock_location_id = duplicate.stock_location_id
  and balance.product_id = duplicate.product_id
  and balance.batch_id is not distinct from duplicate.batch_id;

delete from public.stock_movements_v13
where reference_type = 'purchase_order'
  and reference_id = '31';

delete from public.purchase_orders
where id = 31;

update public.purchase_orders
set
  note = concat_ws(
    E'\n',
    nullif(note, ''),
    '[slouceno:OVDL26-0014] Duplicitni dodaci list OVDL26-0014 byl 15. 6. 2026 sloucen do teto faktury; duplicitni skladovy prijem byl odebran.'
  ),
  updated_at = now()
where id = 36;

commit;
