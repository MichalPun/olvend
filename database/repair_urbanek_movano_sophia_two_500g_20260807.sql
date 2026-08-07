-- Mobile load request 286 recorded two 500 g Sophia packages as 2 kg.
-- Correct the request to 1 kg and return the extra 1 kg from Movano to warehouse 1.

do $$
declare
  v_reference constant text := 'repair-urbanek-movano-sophia-two-500g-20260807';
begin
  if not exists (
    select 1
    from public.mobile_stock_request_items
    where id = 2517
      and request_id = 286
      and product_id = 108
      and unit = 'kg'
      and requested_quantity in (1, 2)
  ) then
    raise exception 'Mobile stock request item 2517 no longer matches the audited Sophia row.';
  end if;

  if not exists (
    select 1
    from public.stock_movements_v13
    where reference_type = 'data_repair'
      and reference_id = v_reference
  ) then
    if not exists (
      select 1
      from public.stock_movements_v13
      where id = 28105
        and product_id = 108
        and from_stock_location_id = 1
        and to_stock_location_id = 58
        and quantity_base_units = 2
    ) then
      raise exception 'Original Sophia load movement 28105 does not match the audit.';
    end if;

    perform public.apply_stock_movements_v13(
      jsonb_build_array(
        jsonb_build_object(
          'product_id', 108,
          'batch_id', null,
          'from_stock_location_id', 58,
          'to_stock_location_id', 1,
          'movement_type', 'return',
          'quantity_base_units', 1,
          'package_id', 32,
          'package_count', 2,
          'reference_type', 'data_repair',
          'reference_id', v_reference,
          'note', 'Oprava nakladky 286: 2 baleni Sophia po 500 g jsou celkem 1 kg, nikoli 2 kg.'
        )
      )
    );
  end if;

  update public.mobile_stock_request_items
  set requested_quantity = 1,
      prepared_quantity = 1,
      confirmed_quantity = case when confirmed_quantity is null then null else 1 end,
      note = concat_ws(' · ', nullif(note, ''), 'Opraveno: 2 × 500 g = 1 kg.'),
      updated_at = now()
  where id = 2517 and request_id = 286 and product_id = 108;
end
$$;

select jsonb_build_object(
  'request_item', (select to_jsonb(i) from public.mobile_stock_request_items i where i.id = 2517),
  'movano_sophia_kg', (select sum(quantity_on_hand) from public.stock_location_balances where stock_location_id = 58 and product_id = 108),
  'packages_500g', (select sum(quantity_on_hand) / 0.5 from public.stock_location_balances where stock_location_id = 58 and product_id = 108)
) as result;
