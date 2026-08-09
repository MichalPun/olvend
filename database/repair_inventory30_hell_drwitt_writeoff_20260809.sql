begin;

do $$
declare
  v_reference_id text := 'repair-inventory30-hell-drwitt-writeoff-20260809';
  v_result jsonb;
begin
  if exists (
    select 1
    from public.stock_movements_v13
    where reference_type = 'manual_correction'
      and reference_id = v_reference_id
  ) then
    raise notice 'Correction % already exists, skipping stock movements.', v_reference_id;
    return;
  else
    if not exists (
      select 1 from public.inventory_audits
      where id = 30 and stock_location_id = 2 and status = 'counted'
    ) then
      raise exception 'Inventory audit #30 is not in the expected counted state.';
    end if;

    if not exists (
      select 1 from public.stock_movements_v13
      where id = 27334 and product_id = 63 and batch_id = 248
        and from_stock_location_id = 1 and to_stock_location_id = 2
        and quantity_base_units = 24
    ) then
      raise exception 'Duplicate HELL movement #27334 does not match the expected values.';
    end if;

    if not exists (
      select 1 from public.stock_movements_v13
      where id = 29136 and product_id = 112 and from_stock_location_id = 5
        and quantity_base_units = 24
    ) or not exists (
      select 1 from public.stock_movements_v13
      where id = 29137 and product_id = 27 and from_stock_location_id = 5
        and quantity_base_units = 1
    ) then
      raise exception 'Writeoff #285 movements do not match the expected values.';
    end if;

    select public.apply_stock_movements_v13(jsonb_build_array(
      jsonb_build_object(
        'product_id', 63, 'batch_id', 248,
        'from_stock_location_id', 2, 'to_stock_location_id', 1,
        'movement_type', 'return', 'quantity_base_units', 24,
        'reference_type', 'manual_correction', 'reference_id', v_reference_id,
        'note', 'Storno duplicitní nakládky HELL #284: vráceno z Kangoo do Blučiny'
      ),
      jsonb_build_object(
        'product_id', 112, 'batch_id', null,
        'from_stock_location_id', null, 'to_stock_location_id', 5,
        'movement_type', 'adjustment', 'quantity_base_units', 24,
        'reference_type', 'manual_correction', 'reference_id', v_reference_id,
        'note', 'Reverzace chybného odpisu 1 balení Pepsi z Automatů v dokladu #285'
      ),
      jsonb_build_object(
        'product_id', 27, 'batch_id', null,
        'from_stock_location_id', null, 'to_stock_location_id', 5,
        'movement_type', 'adjustment', 'quantity_base_units', 1,
        'reference_type', 'manual_correction', 'reference_id', v_reference_id,
        'note', 'Reverzace chybného odpisu Big Shock z Automatů v dokladu #285'
      ),
      jsonb_build_object(
        'product_id', 112, 'batch_id', 267,
        'from_stock_location_id', 2, 'to_stock_location_id', null,
        'movement_type', 'waste', 'quantity_base_units', 1,
        'reference_type', 'manual_correction', 'reference_id', v_reference_id,
        'note', 'Správný kusový odpis prasklé Pepsi z Kangoo podle dokladu #285'
      ),
      jsonb_build_object(
        'product_id', 27, 'batch_id', 232,
        'from_stock_location_id', 2, 'to_stock_location_id', null,
        'movement_type', 'waste', 'quantity_base_units', 1,
        'reference_type', 'manual_correction', 'reference_id', v_reference_id,
        'note', 'Správný kusový odpis prasklého Big Shock z Kangoo podle dokladu #285'
      ),
      jsonb_build_object(
        'product_id', 51, 'batch_id', null,
        'from_stock_location_id', 2, 'to_stock_location_id', null,
        'movement_type', 'adjustment', 'quantity_base_units', 5,
        'reference_type', 'manual_correction', 'reference_id', v_reference_id,
        'note', 'Srovnání záměny příchutí DrWitt v Kangoo: liči+hruška -5 ks'
      ),
      jsonb_build_object(
        'product_id', 157, 'batch_id', null,
        'from_stock_location_id', null, 'to_stock_location_id', 2,
        'movement_type', 'adjustment', 'quantity_base_units', 5,
        'reference_type', 'manual_correction', 'reference_id', v_reference_id,
        'note', 'Srovnání záměny příchutí DrWitt v Kangoo: mango+citron +5 ks'
      )
    )) into v_result;

    if coalesce((v_result->>'inserted')::integer, 0) <> 7 then
      raise exception 'Expected 7 correction movements, got %.', v_result;
    end if;
  end if;

  update public.mobile_stock_request_items
  set unit = 'ks', note = concat_ws(' · ', nullif(note, ''), 'Opraveno: kusový odpis z Kangoo')
  where request_id = 285 and product_id in (27, 112);

  update public.mobile_stock_requests
  set note = concat_ws(' · ', nullif(note, ''), 'Opraveno 9. 8. 2026: odpis 1+1 ks patří Kangoo; původní odečet z Automatů reverzován')
  where id = 285;

  update public.mobile_stock_requests
  set note = concat_ws(' · ', nullif(note, ''), 'Opraveno 9. 8. 2026: duplicitní nakládka 24 ks HELL reverzována')
  where id = 284;

  update public.stock_movements_v13
  set note = concat_ws(' · ', nullif(note, ''), 'REVERZOVÁNO korekcí ' || v_reference_id)
  where id in (27334, 29136, 29137)
    and note not ilike '%REVERZOVÁNO korekcí%';

  update public.inventory_audit_items
  set book_quantity = counted_quantity,
      difference_quantity = 0,
      difference_value = 0,
      note = concat_ws(' · ', nullif(note, ''), 'Oprava evidence: duplicitní nakládka HELL #284')
  where audit_id = 30 and product_id = 63;

  update public.inventory_audit_items
  set book_quantity = counted_quantity,
      difference_quantity = 0,
      difference_value = 0,
      note = concat_ws(' · ', nullif(note, ''), 'Srovnáno proti -5 ks jiné příchuti DrWitt')
  where audit_id = 30 and product_id = 51;

  update public.inventory_audit_items
  set book_quantity = counted_quantity,
      difference_quantity = 0,
      difference_value = 0,
      note = concat_ws(' · ', nullif(note, ''), 'Kusový odpis z Kangoo podle dokladu #285')
  where audit_id = 30 and product_id = 112;

  update public.inventory_audit_items
  set book_quantity = book_quantity - 1,
      difference_quantity = counted_quantity - (book_quantity - 1),
      difference_value = round((counted_quantity - (book_quantity - 1)) * coalesce(unit_cost, 0), 2),
      note = concat_ws(' · ', nullif(note, ''), 'Jeden kus odepsán z Kangoo podle dokladu #285')
  where id = (
    select i.id
    from public.inventory_audit_items i
    where i.audit_id = 30 and i.product_id = 27
    order by i.difference_quantity, i.id
    limit 1
  );

  update public.inventory_audit_items
  set difference_value = 0,
      note = concat_ws(' · ', nullif(note, ''), 'Kusový rozdíl baget bez finančního dopadu dle rozhodnutí managementu')
  where audit_id = 30 and product_id in (11, 14, 158, 164);

  update public.inventory_audits a
  set book_quantity_total = totals.book_qty,
      counted_quantity_total = totals.counted_qty,
      difference_quantity_total = totals.diff_qty,
      difference_value_total = totals.diff_value,
      evaluation_note = concat_ws(E'\n', nullif(a.evaluation_note, ''),
        '9. 8. 2026: opraven HELL #284, záměna DrWitt a doklad #285. Bagety ponechány kusově bez finančního dopadu.'),
      updated_at = now()
  from (
    select audit_id,
           round(sum(book_quantity), 3) as book_qty,
           round(sum(counted_quantity), 3) as counted_qty,
           round(sum(difference_quantity), 3) as diff_qty,
           round(sum(difference_value), 2) as diff_value
    from public.inventory_audit_items
    where audit_id = 30
    group by audit_id
  ) totals
  where a.id = totals.audit_id;
end $$;

commit;
