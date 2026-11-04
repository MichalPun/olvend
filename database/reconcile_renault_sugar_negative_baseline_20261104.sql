-- Renault Kangoo 2TX7928 má cukr rozdělený do dvou evidenčních řádků:
-- -2 kg bez šarže a +2 kg v šarži 607. Záporný řádek vznikl zpětně
-- zapsaným ručním doplněním EV132 a chybně skrývá fyzicky evidované 2 kg.
-- Korekce pouze nuluje záporný základ; nejde o fyzickou nakládku ze skladu.

begin;

do $$
declare
  v_reference_id constant text := 'reconcile-renault-sugar-negative-baseline-20261104';
  v_unbatched numeric;
  v_batched numeric;
  v_total numeric;
  v_result jsonb;
begin
  if not exists (
    select 1
    from public.stock_locations location
    join public.vehicles vehicle on vehicle.id = location.vehicle_id
    where location.id = 2
      and location.location_type = 'vehicle'
      and vehicle.id = 1
      and vehicle.plate = '2TX7928'
  ) then
    raise exception 'Skladová lokace #2 už neodpovídá Renaultu Kangoo 2TX7928.';
  end if;

  if not exists (
    select 1
    from public.products
    where id = 42
      and sku = '43'
      and name = 'Cukr Vending 1 kg'
      and base_unit = 'kg'
  ) then
    raise exception 'Produkt #42 už neodpovídá cukru SKU 43 v kg.';
  end if;

  if exists (
    select 1
    from public.stock_movements_v13
    where reference_type = 'data_repair'
      and reference_id = v_reference_id
  ) then
    return;
  end if;

  select coalesce(sum(quantity_on_hand), 0)
  into v_unbatched
  from public.stock_location_balances
  where stock_location_id = 2
    and product_id = 42
    and batch_id is null;

  select coalesce(sum(quantity_on_hand), 0)
  into v_batched
  from public.stock_location_balances
  where stock_location_id = 2
    and product_id = 42
    and batch_id is not null;

  if v_unbatched <> -2 or v_batched <> 2 then
    raise exception 'Neočekávaný stav cukru před korekcí: bez šarže %, se šarží % kg.', v_unbatched, v_batched;
  end if;

  select public.apply_stock_movements_v13(jsonb_build_array(
    jsonb_build_object(
      'product_id', 42,
      'batch_id', null,
      'from_stock_location_id', null,
      'to_stock_location_id', 2,
      'movement_type', 'adjustment',
      'quantity_base_units', 2,
      'reference_type', 'data_repair',
      'reference_id', v_reference_id,
      'note', 'Dorovnání falešného záporného základu -2 kg cukru v Renaultu. Fyzické 2 kg jsou již evidované v šarži 607; nejde o novou nakládku.'
    )
  )) into v_result;

  if coalesce((v_result ->> 'inserted')::integer, 0) <> 1 then
    raise exception 'Korekční pohyb nebyl vložen právě jednou: %.', v_result;
  end if;

  select coalesce(sum(quantity_on_hand), 0)
  into v_total
  from public.stock_location_balances
  where stock_location_id = 2
    and product_id = 42;

  if v_total <> 2 then
    raise exception 'Výsledný stav cukru měl být 2 kg, je % kg.', v_total;
  end if;
end
$$;

commit;

select product.id,
       product.name,
       sum(balance.quantity_on_hand) as renault_quantity_kg,
       sum(balance.quantity_on_hand) filter (where balance.batch_id is null) as unbatched_quantity_kg,
       sum(balance.quantity_on_hand) filter (where balance.batch_id is not null) as batched_quantity_kg
from public.products product
join public.stock_location_balances balance on balance.product_id = product.id
where product.id = 42
  and balance.stock_location_id = 2
group by product.id, product.name;
