begin;

do $$
declare
  v_reference_id text := 'repair-inventory31-units-vivaro-writeoffs-20260809';
  v_original record;
  v_balance_id bigint;
  v_remaining numeric(12,3);
  v_take numeric(12,3);
  v_balance record;
  v_fix record;
begin
  if not exists (
    select 1
    from public.inventory_audits
    where id = 31 and stock_location_id = 3 and status = 'counted'
  ) then
    raise exception 'Inventory #31 is not the expected counted Vivaro inventory.';
  end if;

  if not exists (
    select 1
    from public.stock_movements_v13
    where reference_type = 'manual_correction' and reference_id = v_reference_id
  ) then
    -- Restore every proven historical writeoff to Automaty and apply the same
    -- product, batch and quantity to the Vivaro that submitted the request.
    for v_original in
      select *
      from public.stock_movements_v13
      where id in (25713,25714,25715,25716,25717,25718,25719,25720,25721,29138,29139,29140)
      order by id
    loop
      if v_original.movement_type <> 'waste'
         or v_original.from_stock_location_id <> 5
         or v_original.reference_id not in ('mobile-stock:262','mobile-stock:275','mobile-stock:287') then
        raise exception 'Original movement % no longer matches the audited writeoff.', v_original.id;
      end if;

      select id into v_balance_id
      from public.stock_location_balances
      where stock_location_id = 5
        and product_id = v_original.product_id
        and batch_id is not distinct from v_original.batch_id
      order by id limit 1 for update;

      if v_balance_id is null then
        insert into public.stock_location_balances (
          stock_location_id, product_id, batch_id, quantity_on_hand, reserved_quantity, updated_at
        ) values (
          5, v_original.product_id, v_original.batch_id,
          v_original.quantity_base_units, 0, now()
        );
      else
        update public.stock_location_balances
        set quantity_on_hand = round((quantity_on_hand + v_original.quantity_base_units)::numeric, 3),
            updated_at = now()
        where id = v_balance_id;
      end if;

      v_balance_id := null;
      select id into v_balance_id
      from public.stock_location_balances
      where stock_location_id = 3
        and product_id = v_original.product_id
        and batch_id is not distinct from v_original.batch_id
      order by id limit 1 for update;

      if v_balance_id is null then
        insert into public.stock_location_balances (
          stock_location_id, product_id, batch_id, quantity_on_hand, reserved_quantity, updated_at
        ) values (
          3, v_original.product_id, v_original.batch_id,
          -v_original.quantity_base_units, 0, now()
        );
      else
        update public.stock_location_balances
        set quantity_on_hand = round((quantity_on_hand - v_original.quantity_base_units)::numeric, 3),
            updated_at = now()
        where id = v_balance_id;
      end if;

      insert into public.stock_movements_v13 (
        product_id, batch_id, from_stock_location_id, to_stock_location_id,
        movement_type, quantity_base_units, unit_price, reference_type, reference_id, note
      ) values
      (
        v_original.product_id, v_original.batch_id, null, 5,
        'adjustment', v_original.quantity_base_units, v_original.unit_price,
        'manual_correction', v_reference_id,
        'Reverzace chybného odpisu z Automatů; původní pohyb #' || v_original.id
      ),
      (
        v_original.product_id, v_original.batch_id, 3, null,
        'waste', v_original.quantity_base_units, v_original.unit_price,
        'manual_correction', v_reference_id,
        'Správný odpis z Vivara; původní pohyb #' || v_original.id
      );
    end loop;

    update public.stock_movements_v13
    set note = concat_ws(' · ', nullif(note, ''), 'REVERZOVÁNO korekcí ' || v_reference_id)
    where id in (25713,25714,25715,25716,25717,25718,25719,25720,25721,29138,29139,29140)
      and note not ilike '%REVERZOVÁNO korekcí%';

    update public.mobile_stock_requests
    set note = concat_ws(' · ', nullif(note, ''),
      'Opraveno 9. 8. 2026: odpis byl převeden z Automatů na Vivaro')
    where id in (262,275,287);

    -- Remove the two proven historical unit overstatements from usable Vivaro stock.
    for v_fix in
      select * from (values
        (62::bigint, 58.000::numeric, 'Havlík: inventura #27 uložila 2 ks jako 2 balení = 60 ks'),
        (108::bigint, 3.500::numeric, 'Sophia: inventura #27 uložila 7 balení po 500 g jako 7 kg')
      ) as correction(product_id, quantity, reason)
    loop
      v_remaining := v_fix.quantity;
      for v_balance in
        select id, batch_id, quantity_on_hand
        from public.stock_location_balances
        where stock_location_id = 3
          and product_id = v_fix.product_id
          and quantity_on_hand > 0
        order by (batch_id is null), batch_id, id
        for update
      loop
        exit when v_remaining <= 0.0001;
        v_take := least(v_balance.quantity_on_hand, v_remaining);
        update public.stock_location_balances
        set quantity_on_hand = round((quantity_on_hand - v_take)::numeric, 3), updated_at = now()
        where id = v_balance.id;
        insert into public.stock_movements_v13 (
          product_id, batch_id, from_stock_location_id, movement_type,
          quantity_base_units, reference_type, reference_id, note
        ) values (
          v_fix.product_id, v_balance.batch_id, 3, 'adjustment',
          v_take, 'manual_correction', v_reference_id, v_fix.reason
        );
        v_remaining := round((v_remaining - v_take)::numeric, 3);
      end loop;
      if v_remaining > 0.0001 then
        raise exception 'Insufficient Vivaro stock for historical correction product %, missing %.',
          v_fix.product_id, v_remaining;
      end if;
    end loop;
  end if;

  -- Idempotently reconstruct the inventory book values after the corrections.
  update public.inventory_audit_items item
  set book_quantity = corrected.book_quantity,
      difference_quantity = round((item.counted_quantity - corrected.book_quantity)::numeric, 3),
      difference_value = case
        when product.product_category = 'food_ready' then 0
        else round(((item.counted_quantity - corrected.book_quantity) * item.unit_cost)::numeric, 2)
      end,
      note = concat_ws(' · ', nullif(item.note, ''), corrected.reason)
  from (values
    (62::bigint, 0.000::numeric, 'Opravená jednotka Havlík z inventury #27'),
    (108::bigint, 2.500::numeric, 'Opravená jednotka Sophia z inventury #27'),
    (137::bigint, -9.000::numeric, 'Odpis #262 převeden z Automatů na Vivaro'),
    (49::bigint, -2.000::numeric, 'Odpis #262 převeden z Automatů na Vivaro'),
    (100::bigint, -1.000::numeric, 'Odpis #262 převeden z Automatů na Vivaro'),
    (12::bigint, -3.000::numeric, 'Odpisy #275 a #287 převedeny z Automatů na Vivaro; bez finančního manka'),
    (14::bigint, 0.000::numeric, 'Odpis #275 převeden z Automatů na Vivaro; bez finančního manka'),
    (120::bigint, 0.000::numeric, 'Odpis #275 převeden z Automatů na Vivaro'),
    (27::bigint, 0.000::numeric, 'Odpis #275 převeden z Automatů na Vivaro'),
    (17::bigint, 2.000::numeric, 'Odpis #287 převeden z Automatů na Vivaro; bez finančního manka'),
    (18::bigint, 5.000::numeric, 'Odpis #287 převeden z Automatů na Vivaro; bez finančního manka')
  ) as corrected(product_id, book_quantity, reason)
  join public.products product on product.id = corrected.product_id
  where item.audit_id = 31 and item.product_id = corrected.product_id;

  -- Resolved unit errors and fresh food do not belong in a warehouse recount.
  delete from public.inventory_audit_items child
  using public.inventory_audit_items parent, public.products product
  where child.audit_id = 32
    and child.parent_audit_item_id = parent.id
    and parent.product_id = product.id
    and (
      parent.product_id in (62,108)
      or product.product_category = 'food_ready'
      or parent.difference_quantity >= -0.0001
    );

  update public.inventory_audits audit
  set book_quantity_total = totals.book_total,
      counted_quantity_total = totals.counted_total,
      difference_quantity_total = totals.difference_total,
      difference_value_total = totals.value_total,
      updated_at = now()
  from (
    select audit_id,
      coalesce(sum(book_quantity),0) book_total,
      coalesce(sum(counted_quantity),0) counted_total,
      coalesce(sum(difference_quantity),0) difference_total,
      coalesce(sum(difference_value),0) value_total
    from public.inventory_audit_items
    where audit_id in (31,32)
    group by audit_id
  ) totals
  where audit.id = totals.audit_id;
end $$;

commit;
