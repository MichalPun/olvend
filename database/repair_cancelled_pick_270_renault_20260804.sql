-- Fyzicky vychystané zboží zůstalo po stornu požadavku #270 v evidenci skladu BLUČINA.
-- Potvrzený stav před vychystáním:
--   Ovesná svačinka 5 balení po 20 ks, expirace 18. 2. 2027; 1 balení fyzicky v Renault Kangoo.
--   Twix 2 balení po 30 ks, expirace 6. 12. 2026; 1 balení fyzicky v Renault Kangoo.
--   Nový věk 2 balení po 20 ks, expirace 8. 5. 2027; 10 ks fyzicky v Renault Kangoo.

begin;

do $$
declare
  v_reference_prefix constant text := 'repair-cancelled-pick-270-renault-20260804';
begin
  if exists (
    select 1
    from public.stock_movements_v13
    where reference_type = 'data_repair'
      and reference_id like v_reference_prefix || '-%'
  ) then
    return;
  end if;

  if coalesce((
    select quantity_on_hand from public.stock_location_balances
    where stock_location_id = 1 and product_id = 111 and batch_id = 266
  ), 0) <> 100 then
    raise exception 'Neočekávaný stav Ovesné svačinky, šarže 266, ve skladu BLUČINA.';
  end if;

  if coalesce((
    select quantity_on_hand from public.stock_location_balances
    where stock_location_id = 1 and product_id = 133 and batch_id = 280
  ), 0) <> 60 then
    raise exception 'Neočekávaný stav Twixu, šarže 280, ve skladu BLUČINA.';
  end if;

  if coalesce((
    select quantity_on_hand from public.stock_location_balances
    where stock_location_id = 1 and product_id = 100 and batch_id = 264
  ), 0) <> 20 then
    raise exception 'Neočekávaný stav Nového věku, šarže 264, ve skladu BLUČINA.';
  end if;

  if coalesce((
    select quantity_on_hand from public.stock_location_balances
    where stock_location_id = 1 and product_id = 100 and batch_id = 265
  ), 0) <> 20 then
    raise exception 'Neočekávaný stav Nového věku, šarže 265, ve skladu BLUČINA.';
  end if;

  if coalesce((
    select sum(quantity_on_hand) from public.stock_location_balances
    where stock_location_id = 2 and product_id in (100, 111, 133)
  ), 0) <> 0 then
    raise exception 'V Renaultu Kangoo už je u opravovaných položek neočekávaný kladný zůstatek.';
  end if;

  perform public.apply_stock_movements_v13(
    jsonb_build_array(
      jsonb_build_object(
        'product_id', 100,
        'batch_id', 265,
        'from_stock_location_id', 1,
        'to_stock_location_id', null,
        'movement_type', 'adjustment',
        'quantity_base_units', 20,
        'package_id', 163,
        'package_count', 1,
        'reference_type', 'data_repair',
        'reference_id', v_reference_prefix || '-novy-vek-old-expiry-out',
        'note', 'Přeřazení 1 balení Nový věk z chybně evidované expirace 10. 6. 2027'
      ),
      jsonb_build_object(
        'product_id', 100,
        'batch_id', 264,
        'from_stock_location_id', null,
        'to_stock_location_id', 1,
        'movement_type', 'adjustment',
        'quantity_base_units', 20,
        'package_id', 163,
        'package_count', 1,
        'reference_type', 'data_repair',
        'reference_id', v_reference_prefix || '-novy-vek-correct-expiry-in',
        'note', 'Přiřazení 1 balení Nový věk ke skutečné expiraci 8. 5. 2027'
      ),
      jsonb_build_object(
        'product_id', 111,
        'batch_id', 266,
        'from_stock_location_id', 1,
        'to_stock_location_id', 2,
        'movement_type', 'load_vehicle',
        'quantity_base_units', 20,
        'package_id', 166,
        'package_count', 1,
        'reference_type', 'data_repair',
        'reference_id', v_reference_prefix || '-ovesna-svacinka-kangoo',
        'note', 'Fyzicky vychystané 1 balení Ovesné svačinky do Renault Kangoo po stornu požadavku #270'
      ),
      jsonb_build_object(
        'product_id', 133,
        'batch_id', 280,
        'from_stock_location_id', 1,
        'to_stock_location_id', 2,
        'movement_type', 'load_vehicle',
        'quantity_base_units', 30,
        'package_id', 176,
        'package_count', 1,
        'reference_type', 'data_repair',
        'reference_id', v_reference_prefix || '-twix-kangoo',
        'note', 'Fyzicky vychystané 1 balení Twix do Renault Kangoo po stornu požadavku #270'
      ),
      jsonb_build_object(
        'product_id', 100,
        'batch_id', 264,
        'from_stock_location_id', 1,
        'to_stock_location_id', 2,
        'movement_type', 'load_vehicle',
        'quantity_base_units', 10,
        'package_id', 64,
        'package_count', 10,
        'reference_type', 'data_repair',
        'reference_id', v_reference_prefix || '-novy-vek-kangoo',
        'note', 'Fyzicky vychystaných 10 ks Nový věk do Renault Kangoo po stornu požadavku #270'
      )
    )
  );

  update public.stock_movements_v13
  set package_id = case
        when reference_id like '%-ovesna-svacinka-kangoo' then 166
        when reference_id like '%-twix-kangoo' then 176
        when reference_id like '%-novy-vek-kangoo' then 64
        when product_id = 100 then 163
      end,
      package_count = case
        when reference_id like '%-novy-vek-kangoo' then 10
        else 1
      end
  where reference_type = 'data_repair'
    and reference_id like v_reference_prefix || '-%';
end
$$;

commit;

select
  p.name as product_name,
  sl.name as stock_location_name,
  coalesce(ib.use_by_date, ib.best_before_date) as expiry_date,
  sum(b.quantity_on_hand) as quantity_on_hand
from public.stock_location_balances b
join public.products p on p.id = b.product_id
join public.stock_locations sl on sl.id = b.stock_location_id
left join public.inventory_batches ib on ib.id = b.batch_id
where b.product_id in (100, 111, 133)
  and b.stock_location_id in (1, 2)
group by p.name, sl.name, coalesce(ib.use_by_date, ib.best_before_date)
having abs(sum(b.quantity_on_hand)) > 0.0001
order by p.name, sl.name, expiry_date;
