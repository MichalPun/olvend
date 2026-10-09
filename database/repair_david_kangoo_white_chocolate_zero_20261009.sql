-- Fyzická kontrola 2026-10-09: David Boudný nemá v Renault Kangoo žádnou
-- bílou čokoládu. Knižních 49 kg vzniklo chybným převodem historické mobilní
-- nakládky z kartonů na základní jednotku; nejde o skutečně vychystané zboží.

begin;

do $$
declare
  v_product_id constant bigint := 105;
  v_vehicle_location_id bigint;
  v_balance_id bigint;
  v_current_quantity numeric(12,3);
  v_reference_id constant text := 'david-kangoo-white-chocolate-zero-20261009';
begin
  select sl.id
    into strict v_vehicle_location_id
  from public.stock_locations sl
  join public.vehicles v on v.id = sl.vehicle_id
  join public.employees e on e.id = v.assigned_employee_id
  where sl.location_type = 'vehicle'
    and sl.active = true
    and v.plate = '2TX7928'
    and lower(concat_ws(' ', e.name, e.surname)) = 'david boudný';

  if exists (
    select 1
    from public.stock_movements_v13 movement
    where movement.reference_type = 'data_repair'
      and movement.reference_id = v_reference_id
      and movement.product_id = v_product_id
  ) then
    return;
  end if;

  select balance.id, balance.quantity_on_hand
    into strict v_balance_id, v_current_quantity
  from public.stock_location_balances balance
  where balance.stock_location_id = v_vehicle_location_id
    and balance.product_id = v_product_id
    and balance.batch_id is null
  for update;

  if v_current_quantity <> 49 then
    raise exception 'Stav bílé čokolády v Kangoo se změnil: očekáváno 49 kg, nalezeno % kg.', v_current_quantity;
  end if;

  perform public.apply_stock_movements_v13(jsonb_build_array(jsonb_build_object(
    'product_id', v_product_id,
    'batch_id', null,
    'from_stock_location_id', v_vehicle_location_id,
    'to_stock_location_id', null,
    'movement_type', 'adjustment',
    'quantity_base_units', v_current_quantity,
    'reference_type', 'data_repair',
    'reference_id', v_reference_id,
    'note', 'Fyzicky potvrzeno 2026-10-09: David Boudný má v Kangoo 0 kg bílé čokolády; 49 kg byl chybný evidenční převod a nebylo fyzicky vychystáno.'
  )));

  if (select quantity_on_hand from public.stock_location_balances where id = v_balance_id) <> 0 then
    raise exception 'Korekce nedorovnala stav bílé čokolády v Kangoo na nulu.';
  end if;
end $$;

commit;

select v.name as vehicle,v.plate,e.name||' '||e.surname as employee,
       p.name as product,b.quantity_on_hand,p.base_unit,b.updated_at
from public.stock_location_balances b
join public.stock_locations sl on sl.id=b.stock_location_id
join public.vehicles v on v.id=sl.vehicle_id
join public.employees e on e.id=v.assigned_employee_id
join public.products p on p.id=b.product_id
where v.plate='2TX7928' and p.id=105 and b.batch_id is null;
