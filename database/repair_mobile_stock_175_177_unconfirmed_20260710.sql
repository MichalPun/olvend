begin;

do $$
declare
  v_refs text[] := array['mobile-stock:175', 'mobile-stock:177'];
  v_rows integer;
begin
  if exists (
    select 1
    from public.mobile_stock_requests r
    where r.id in (175, 177)
      and (r.status = 'confirmed' or r.stock_applied_at is not null)
  ) then
    raise exception 'Repair stopped: mobile request 175 or 177 is already confirmed/applied.';
  end if;

  create temp table tmp_repair_mobile_175_177 as
  select *
  from public.stock_movements_v13
  where reference_type = 'mobile_stock_request'
    and reference_id = any(v_refs);

  select count(*) into v_rows from tmp_repair_mobile_175_177;
  if v_rows = 0 then
    raise notice 'No stock movements found for requests 175/177.';
    return;
  end if;

  insert into public.stock_location_balances (
    stock_location_id,
    product_id,
    batch_id,
    quantity_on_hand,
    reserved_quantity,
    updated_at
  )
  select
    from_stock_location_id,
    product_id,
    batch_id,
    sum(quantity_base_units),
    0,
    now()
  from tmp_repair_mobile_175_177
  where from_stock_location_id is not null
  group by from_stock_location_id, product_id, batch_id
  on conflict (stock_location_id, product_id, batch_id)
  do update set
    quantity_on_hand = round((public.stock_location_balances.quantity_on_hand + excluded.quantity_on_hand)::numeric, 3),
    updated_at = now();

  update public.stock_location_balances b
  set
    quantity_on_hand = round((b.quantity_on_hand - x.qty)::numeric, 3),
    updated_at = now()
  from (
    select
      to_stock_location_id as stock_location_id,
      product_id,
      batch_id,
      sum(quantity_base_units) as qty
    from tmp_repair_mobile_175_177
    where to_stock_location_id is not null
    group by to_stock_location_id, product_id, batch_id
  ) x
  where b.stock_location_id = x.stock_location_id
    and b.product_id = x.product_id
    and b.batch_id is not distinct from x.batch_id;

  delete from public.stock_movements_v13
  where id in (select id from tmp_repair_mobile_175_177);

  update public.mobile_stock_requests
  set
    note = concat_ws(' · ', nullif(note, ''), 'Oprava 10. 7. 2026: odstraněn chybně propsaný skladový pohyb z rozpracovaného dokladu. Doklad znovu potvrď až po kontrole skutečně vydaného množství.'),
    updated_at = now()
  where id in (175, 177);

  raise notice 'Rolled back % unconfirmed mobile stock movement rows for requests 175/177.', v_rows;
end $$;

select
  p.sku,
  p.name,
  round(sum(b.quantity_on_hand)::numeric, 3) as blucina_quantity
from public.stock_location_balances b
join public.products p on p.id = b.product_id
where b.stock_location_id = 1
  and (
    p.product_category = 'food_ready'
    or lower(coalesce(p.name, '')) like '%baget%'
  )
group by p.sku, p.name
order by blucina_quantity asc, p.name;

commit;
