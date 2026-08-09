begin;

do $$
declare
  v_reference_id text := 'repair-inventory30-sophia-unit-history-20260809';
  v_result jsonb;
begin
  if exists (
    select 1
    from public.stock_movements_v13
    where reference_type = 'manual_correction'
      and reference_id = v_reference_id
  ) then
    raise notice 'Correction % already exists, skipping stock movements.', v_reference_id;
  else
    if not exists (
      select 1
      from public.inventory_audit_items
      where audit_id = 10 and product_id = 108
        and book_quantity = 5.5 and counted_quantity = 4
    ) then
      raise exception 'Sophia row in inventory #10 does not match the expected historical values.';
    end if;

    if not exists (
      select 1
      from public.stock_movements_v13
      where id = 15609 and product_id = 108
        and from_stock_location_id = 2 and to_stock_location_id = 5
        and quantity_base_units = 2
    ) then
      raise exception 'Sophia transfer #15609 does not match the expected historical values.';
    end if;

    select public.apply_stock_movements_v13(jsonb_build_array(
      jsonb_build_object(
        'product_id', 108, 'batch_id', null,
        'from_stock_location_id', 2, 'to_stock_location_id', null,
        'movement_type', 'adjustment', 'quantity_base_units', 2,
        'reference_type', 'manual_correction', 'reference_id', v_reference_id,
        'note', 'Oprava inventury #10: 4 balení Sophie po 500 g jsou 2 kg, nikoliv 4 kg',
        'allow_negative_source', true
      ),
      jsonb_build_object(
        'product_id', 108, 'batch_id', null,
        'from_stock_location_id', 5, 'to_stock_location_id', 2,
        'movement_type', 'adjustment', 'quantity_base_units', 1,
        'reference_type', 'manual_correction', 'reference_id', v_reference_id,
        'note', 'Oprava převodu #15609: 2 balení Sophie po 500 g jsou 1 kg, nikoliv 2 kg'
      )
    )) into v_result;

    if coalesce((v_result->>'inserted')::integer, 0) <> 2 then
      raise exception 'Expected 2 Sophia correction movements, got %.', v_result;
    end if;
  end if;

  update public.stock_movements_v13
  set note = concat_ws(' · ', nullif(note, ''), 'JEDNOTKA OPRAVENA korekcí ' || v_reference_id)
  where id in (12136, 15609)
    and note not ilike '%JEDNOTKA OPRAVENA korekcí%';

  update public.inventory_audit_items
  set counted_quantity = 2,
      difference_quantity = -3.5,
      difference_value = -735,
      note = concat_ws(' · ', nullif(note, ''), 'Opraveno: zadány 4 balení po 500 g = 2 kg')
  where audit_id = 10 and product_id = 108;

  update public.inventory_audit_items
  set book_quantity = counted_quantity,
      difference_quantity = 0,
      difference_value = 0,
      note = concat_ws(' · ', nullif(note, ''), 'Historický rozdíl jednotek opraven přes inventuru #10 a převod #15609')
  where audit_id = 30 and product_id = 108;

  update public.inventory_audits a
  set book_quantity_total = totals.book_qty,
      counted_quantity_total = totals.counted_qty,
      difference_quantity_total = totals.diff_qty,
      difference_value_total = totals.diff_value,
      evaluation_note = concat_ws(E'\n', nullif(a.evaluation_note, ''),
        case when a.id = 10
          then '9. 8. 2026: Sophia opravena z 4 kg na 4 balení po 500 g = 2 kg.'
          else '9. 8. 2026: odstraněn falešný rozdíl 1 kg Sophie vzniklý dvěma historickými převody jednotek.'
        end),
      updated_at = now()
  from (
    select audit_id,
           round(sum(book_quantity), 3) as book_qty,
           round(sum(counted_quantity), 3) as counted_qty,
           round(sum(difference_quantity), 3) as diff_qty,
           round(sum(difference_value), 2) as diff_value
    from public.inventory_audit_items
    where audit_id in (10, 30)
    group by audit_id
  ) totals
  where a.id = totals.audit_id;
end $$;

commit;
