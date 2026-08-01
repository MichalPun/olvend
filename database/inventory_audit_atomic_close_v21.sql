create or replace function public.close_inventory_audit_atomic(p_audit_id bigint)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_audit public.inventory_audits%rowtype;
  v_item record;
  v_expiry record;
  v_batch_id bigint;
  v_balance_id bigint;
  v_expiry_total numeric;
  v_item_count integer := 0;
  v_batch_count integer := 0;
begin
  select * into v_audit
  from public.inventory_audits
  where id = p_audit_id
  for update;

  if not found then
    raise exception 'Inventura % neexistuje.', p_audit_id;
  end if;
  if v_audit.status = 'closed' then
    return jsonb_build_object('audit_id', p_audit_id, 'status', 'closed', 'already_closed', true);
  end if;
  if v_audit.status <> 'evaluated' then
    raise exception 'Inventura % musí být před uzavřením vyhodnocená (aktuálně %).', p_audit_id, v_audit.status;
  end if;

  for v_item in
    select i.*, p.expiry_tracking_mode, p.requires_batch_tracking
    from public.inventory_audit_items i
    join public.products p on p.id = i.product_id
    where i.audit_id = p_audit_id
    order by i.id
    for update of i
  loop
    v_item_count := v_item_count + 1;
    select coalesce(sum(e.quantity_base_units), 0)
      into v_expiry_total
    from public.inventory_audit_expiry_counts e
    where e.audit_item_id = v_item.id;

    if (v_item.requires_batch_tracking or v_item.expiry_tracking_mode <> 'none')
       and v_item.counted_quantity > 0
       and abs(v_expiry_total - v_item.counted_quantity) > 0.001 then
      raise exception 'Položka %: součet expirací % neodpovídá napočítanému množství %.',
        v_item.product_id, v_expiry_total, v_item.counted_quantity;
    end if;

    if abs(coalesce(v_item.difference_quantity, 0)) > 0.0001 then
      insert into public.stock_movements_v13 (
        product_id, batch_id, from_stock_location_id, to_stock_location_id,
        movement_type, quantity_base_units, unit_price, reference_type, reference_id, note
      ) values (
        v_item.product_id,
        v_item.batch_id,
        case when v_item.difference_quantity < 0 then v_item.stock_location_id end,
        case when v_item.difference_quantity > 0 then v_item.stock_location_id end,
        'adjustment', abs(v_item.difference_quantity), v_item.unit_cost,
        case when v_audit.scope_type = 'warehouse' then 'warehouse_inventory_audit' else 'vehicle_inventory_audit' end,
        'vehicle-inventory:' || p_audit_id,
        concat_ws(' · ', v_audit.audit_date::text,
          case when v_audit.scope_type = 'warehouse' then 'dorovnání řízené inventury skladu' else 'dorovnání řízené inventury vozidla' end,
          nullif(coalesce(v_item.counted_note, v_item.note), ''))
      );
    end if;

    if exists (select 1 from public.inventory_audit_expiry_counts e where e.audit_item_id = v_item.id) then
      update public.stock_location_balances
      set quantity_on_hand = 0, updated_at = now()
      where stock_location_id = v_item.stock_location_id
        and product_id = v_item.product_id;

      for v_expiry in
        select
          e.expiry_date,
          bool_or(e.expiry_unknown) as expiry_unknown,
          nullif(btrim(e.lot_code), '') as lot_code,
          sum(e.quantity_base_units) as quantity_base_units
        from public.inventory_audit_expiry_counts e
        where e.audit_item_id = v_item.id
          and e.quantity_base_units > 0
        group by e.expiry_date, nullif(btrim(e.lot_code), '')
      loop
        select b.id into v_batch_id
        from public.inventory_batches b
        where b.product_id = v_item.product_id
          and b.lot_code is not distinct from v_expiry.lot_code
          and b.best_before_date is not distinct from
            (case when not v_expiry.expiry_unknown and v_item.expiry_tracking_mode <> 'use_by' then v_expiry.expiry_date end)
          and b.use_by_date is not distinct from
            (case when not v_expiry.expiry_unknown and v_item.expiry_tracking_mode = 'use_by' then v_expiry.expiry_date end)
        order by b.id
        limit 1;

        if v_batch_id is null then
          insert into public.inventory_batches (
            product_id, lot_code, best_before_date, use_by_date, received_at, note
          ) values (
            v_item.product_id,
            v_expiry.lot_code,
            case when not v_expiry.expiry_unknown and v_item.expiry_tracking_mode <> 'use_by' then v_expiry.expiry_date end,
            case when not v_expiry.expiry_unknown and v_item.expiry_tracking_mode = 'use_by' then v_expiry.expiry_date end,
            now(),
            case when v_expiry.expiry_unknown
              then 'Expirace nezjištěná při inventuře #' || p_audit_id
              else 'Založeno inventurou #' || p_audit_id end
          ) returning id into v_batch_id;
          v_batch_count := v_batch_count + 1;
        end if;

        select id into v_balance_id
        from public.stock_location_balances
        where stock_location_id = v_item.stock_location_id
          and product_id = v_item.product_id
          and batch_id = v_batch_id
        order by id
        limit 1
        for update;

        if v_balance_id is null then
          insert into public.stock_location_balances (
            stock_location_id, product_id, batch_id, quantity_on_hand, reserved_quantity, updated_at
          ) values (
            v_item.stock_location_id, v_item.product_id, v_batch_id,
            v_expiry.quantity_base_units, 0, now()
          );
        else
          update public.stock_location_balances
          set quantity_on_hand = v_expiry.quantity_base_units, updated_at = now()
          where id = v_balance_id;
        end if;
      end loop;
    elsif abs(coalesce(v_item.difference_quantity, 0)) > 0.0001 then
      select id into v_balance_id
      from public.stock_location_balances
      where stock_location_id = v_item.stock_location_id
        and product_id = v_item.product_id
        and batch_id is not distinct from v_item.batch_id
      order by id
      limit 1
      for update;

      if v_balance_id is null then
        insert into public.stock_location_balances (
          stock_location_id, product_id, batch_id, quantity_on_hand, reserved_quantity, updated_at
        ) values (
          v_item.stock_location_id, v_item.product_id, v_item.batch_id,
          v_item.difference_quantity, 0, now()
        );
      else
        update public.stock_location_balances
        set quantity_on_hand = quantity_on_hand + v_item.difference_quantity, updated_at = now()
        where id = v_balance_id;
      end if;
    end if;
  end loop;

  if v_item_count = 0 then
    raise exception 'Inventura % nemá žádné položky.', p_audit_id;
  end if;

  update public.inventory_audits
  set status = 'closed', closed_at = now()
  where id = p_audit_id;

  return jsonb_build_object(
    'audit_id', p_audit_id,
    'status', 'closed',
    'items', v_item_count,
    'created_batches', v_batch_count
  );
end;
$$;

revoke all on function public.close_inventory_audit_atomic(bigint) from public;
grant execute on function public.close_inventory_audit_atomic(bigint) to authenticated;
