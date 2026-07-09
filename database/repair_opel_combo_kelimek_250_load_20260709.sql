do $$
declare
  v_product_id bigint := 79;
  v_movement_id bigint := 15326;
  v_from_location_id bigint := 1;
  v_to_location_id bigint := 6;
  v_old_quantity numeric := 10;
  v_new_quantity numeric := 500;
  v_delta numeric := 490;
begin
  if exists (
    select 1
    from public.stock_movements_v13
    where id = v_movement_id
      and product_id = v_product_id
      and from_stock_location_id = v_from_location_id
      and to_stock_location_id = v_to_location_id
      and quantity_base_units = v_old_quantity
  ) then
    update public.stock_movements_v13
    set
      quantity_base_units = v_new_quantity,
      note = '2026-07-07 · oprava: naloženo 10 tyčí Kelímek 250 ml, tj. 10 × 50 ks = 500 ks'
    where id = v_movement_id;

    update public.stock_location_balances
    set quantity_on_hand = round((quantity_on_hand - v_delta)::numeric, 3), updated_at = now()
    where stock_location_id = v_from_location_id
      and product_id = v_product_id
      and batch_id is null;

    update public.stock_location_balances
    set quantity_on_hand = round((quantity_on_hand + v_delta)::numeric, 3), updated_at = now()
    where stock_location_id = v_to_location_id
      and product_id = v_product_id
      and batch_id is null;
  end if;
end $$;

select
  sl.name as stock_location,
  b.quantity_on_hand
from public.stock_location_balances b
join public.stock_locations sl on sl.id = b.stock_location_id
where b.product_id = 79
  and b.stock_location_id in (1, 6)
order by b.stock_location_id;
