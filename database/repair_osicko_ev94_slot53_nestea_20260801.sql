-- Oprava návštěvy #71, EV94 / Koupaliště Osíčko, pozice 53.
-- Operátor fyzicky vložil 4 ks Nestea Peach, aplikace kvůli kolizi šaržových
-- rezervací zapsala pouze 1 ks. Doplníme chybějící 3 ks ze šarže 262.

begin;

do $$
declare
  v_reference constant text := 'repair-route-visit-71-slot-1938-nestea-additional-3';
begin
  if not exists (
    select 1
    from public.stock_movements_v13
    where reference_type = 'data_repair' and reference_id = v_reference
  ) then
    if coalesce((
      select quantity_on_hand
      from public.stock_location_balances
      where stock_location_id = 2 and product_id = 99 and batch_id = 262
    ), 0) < 3 then
      raise exception 'V Renaultu není dost Nestea Peach šarže 262 pro opravu 3 ks.';
    end if;

    perform public.apply_stock_movements_v13(
      jsonb_build_array(
        jsonb_build_object(
          'product_id', 99,
          'batch_id', 262,
          'from_stock_location_id', 2,
          'to_stock_location_id', 33,
          'movement_type', 'fill_machine',
          'quantity_base_units', 3,
          'reference_type', 'data_repair',
          'reference_id', v_reference,
          'note', 'Oprava návštěvy #71 · EV94 Koupaliště Osíčko · pozice 53 · fyzicky vloženy další 3 ks Nestea Peach'
        )
      )
    );
  end if;
end
$$;

update public.route_machine_visit_items
set
  suggested_add_quantity = 4,
  actual_add_quantity = 4,
  final_quantity = 4,
  operator_note = 'Doplnění: 1 ks · SKU 67 · expirace 2027-02-20 · Doplnění: 3 ks · SKU 67 · expirace 2027-03-30 · Oprava podle fyzického doplnění operátora 1. 8. 2026',
  updated_at = now()
where id = 1205
  and visit_id = 71
  and planogram_slot_id = 1938;

insert into public.route_machine_visit_food_fills (
  visit_id, visit_item_id, machine_id, planogram_slot_id,
  product_id, product_sku, product_name, quantity, expiry_date,
  sale_price_czk, load_order, stock_reference_id
)
select
  71, 1205, 74, 1938,
  99, '67', 'Nestea Peach 0,5l', 3, date '2027-03-30',
  40, 1, 'repair-route-visit-71-slot-1938-nestea-additional-3'
where not exists (
  select 1
  from public.route_machine_visit_food_fills
  where stock_reference_id = 'repair-route-visit-71-slot-1938-nestea-additional-3'
);

update public.machine_planogram_slots
set
  current_units = 4,
  desired_units = 2,
  fill_percent = 66.67,
  expiry_date = date '2027-02-20',
  updated_at = now()
where id = 1938
  and machine_id = 74
  and slot_code = '53';

update public.route_machine_visits
set
  food_preparation = jsonb_set(
    coalesce(food_preparation, '{}'::jsonb),
    '{1938}',
    jsonb_build_object(
      'actualBefore', 0,
      'assortmentMismatch', false,
      'existingExpiryDate', '2027-02-20',
      'fillItems', jsonb_build_array(
        jsonb_build_object('batchId', 261, 'expiryDate', '2027-02-20', 'productId', 99, 'quantity', 1),
        jsonb_build_object('batchId', 262, 'expiryDate', '2027-03-30', 'productId', 99, 'quantity', 3)
      ),
      'note', '',
      'picked', true,
      'preparedQuantity', 4,
      'selectedProductId', 99,
      'skipReason', '',
      'skipped', false,
      'wasteItems', '[]'::jsonb
    ),
    true
  ),
  synced_at = now()
where id = 71;

commit;

select
  i.id visit_item_id,
  i.physical_position_label,
  i.system_current_quantity,
  i.actual_before_quantity,
  i.suggested_add_quantity,
  i.actual_add_quantity,
  i.final_quantity,
  s.current_units slot_current_units,
  s.desired_units slot_desired_units,
  (select coalesce(sum(b.quantity_on_hand), 0)
   from public.stock_location_balances b
   where b.stock_location_id = 2 and b.product_id = 99) vehicle_quantity
from public.route_machine_visit_items i
join public.machine_planogram_slots s on s.id = i.planogram_slot_id
where i.id = 1205;
