-- Fyzicky vychystané zboží zůstalo po stornu požadavků #269 a #270 v evidenci skladu.
-- Potvrzený stav před vychystáním:
--   Kit Kat 3 balení po 24 ks, expirace 30. 5. 2027; 1 balení fyzicky v Opel Vivaro.
--   Snickers 2 balení po 40 ks, expirace 25. 4. 2027; 1 balení fyzicky v Opel Vivaro.
--   Dupetky 1 balení po 21 ks, expirace 15. 7. 2027; 1 balení fyzicky v Opel Vivaro.

begin;

do $$
declare
  v_reference_prefix constant text := 'repair-cancelled-picks-269-270-vivaro-20260804';
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
    where stock_location_id = 1 and product_id = 83 and batch_id = 252
  ), 0) <> 24 then
    raise exception 'Neočekávaný stav Kit Kat šarže 252 ve skladu BLUČINA.';
  end if;

  if coalesce((
    select quantity_on_hand from public.stock_location_balances
    where stock_location_id = 1 and product_id = 83 and batch_id = 253
  ), 0) <> 48 then
    raise exception 'Neočekávaný stav Kit Kat šarže 253 ve skladu BLUČINA.';
  end if;

  if coalesce((
    select quantity_on_hand from public.stock_location_balances
    where stock_location_id = 1 and product_id = 125 and batch_id = 275
  ), 0) <> 80 then
    raise exception 'Neočekávaný stav Snickers šarže 275 ve skladu BLUČINA.';
  end if;

  if coalesce((
    select quantity_on_hand from public.stock_location_balances
    where stock_location_id = 1 and product_id = 52 and batch_id = 242
  ), 0) <> 21 then
    raise exception 'Neočekávaný stav Dupetky šarže 242 ve skladu BLUČINA.';
  end if;

  if coalesce((
    select sum(quantity_on_hand) from public.stock_location_balances
    where stock_location_id = 3 and product_id in (52, 83, 125)
  ), 0) <> 0 then
    raise exception 'Ve Vivaru už je u opravovaných položek neočekávaný kladný zůstatek.';
  end if;

  perform public.apply_stock_movements_v13(
    jsonb_build_array(
      jsonb_build_object(
        'product_id', 83,
        'batch_id', 252,
        'from_stock_location_id', 1,
        'to_stock_location_id', null,
        'movement_type', 'adjustment',
        'quantity_base_units', 24,
        'package_id', 158,
        'package_count', 1,
        'reference_type', 'data_repair',
        'reference_id', v_reference_prefix || '-kitkat-old-expiry-out',
        'note', 'Přeřazení 1 balení Kit Kat z chybně evidované expirace 30. 4. 2027'
      ),
      jsonb_build_object(
        'product_id', 83,
        'batch_id', 253,
        'from_stock_location_id', null,
        'to_stock_location_id', 1,
        'movement_type', 'adjustment',
        'quantity_base_units', 24,
        'package_id', 158,
        'package_count', 1,
        'reference_type', 'data_repair',
        'reference_id', v_reference_prefix || '-kitkat-correct-expiry-in',
        'note', 'Přiřazení 1 balení Kit Kat ke skutečné expiraci 30. 5. 2027'
      ),
      jsonb_build_object(
        'product_id', 83,
        'batch_id', 253,
        'from_stock_location_id', 1,
        'to_stock_location_id', 3,
        'movement_type', 'load_vehicle',
        'quantity_base_units', 24,
        'package_id', 158,
        'package_count', 1,
        'reference_type', 'data_repair',
        'reference_id', v_reference_prefix || '-kitkat-vivaro',
        'note', 'Fyzicky vychystané 1 balení Kit Kat do Opel Vivaro po stornu požadavku #269'
      ),
      jsonb_build_object(
        'product_id', 125,
        'batch_id', 275,
        'from_stock_location_id', 1,
        'to_stock_location_id', 3,
        'movement_type', 'load_vehicle',
        'quantity_base_units', 40,
        'package_id', 172,
        'package_count', 1,
        'reference_type', 'data_repair',
        'reference_id', v_reference_prefix || '-snickers-vivaro',
        'note', 'Fyzicky vychystané 1 balení Snickers do Opel Vivaro po stornu vychystávání #269 a #270'
      ),
      jsonb_build_object(
        'product_id', 52,
        'batch_id', 242,
        'from_stock_location_id', 1,
        'to_stock_location_id', 3,
        'movement_type', 'load_vehicle',
        'quantity_base_units', 21,
        'package_id', 149,
        'package_count', 1,
        'reference_type', 'data_repair',
        'reference_id', v_reference_prefix || '-dupetky-vivaro',
        'note', 'Fyzicky vychystané 1 balení Dupetky do Opel Vivaro po stornu požadavku #269'
      )
    )
  );

  update public.stock_movements_v13
  set package_id = case
        when product_id = 83 then 158
        when product_id = 125 then 172
        when product_id = 52 then 149
      end,
      package_count = 1
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
where b.product_id in (52, 83, 125)
  and b.stock_location_id in (1, 3)
group by p.name, sl.name, coalesce(ib.use_by_date, ib.best_before_date)
having abs(sum(b.quantity_on_hand)) > 0.0001
order by p.name, sl.name, expiry_date;
