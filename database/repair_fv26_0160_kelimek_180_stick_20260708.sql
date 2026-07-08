begin;

do $$
declare
  v_document_id bigint := 36;
  v_document_number text := 'FV26-0160';
  v_item_id bigint := 318;
  v_product_id bigint := 78;
  v_stock_location_id bigint := 1;
  v_movement_id bigint := 15675;
  v_units_per_stick numeric := 50;
  v_original_quantity numeric := 1;
  v_expected_quantity numeric := 50;
  v_delta numeric := 49;
begin
  if not exists (
    select 1
    from public.sales_document_items
    where id = v_item_id
      and document_id = v_document_id
      and product_id = v_product_id
      and quantity = v_original_quantity
  ) then
    raise exception 'Expected invoice line % on % was not found.', v_item_id, v_document_number;
  end if;

  update public.sales_document_items
  set unit = '1 tyč'
  where id = v_item_id
    and document_id = v_document_id
    and product_id = v_product_id;

  if exists (
    select 1
    from public.stock_movements_v13
    where id = v_movement_id
      and reference_type = 'sales_document'
      and product_id = v_product_id
      and from_stock_location_id = v_stock_location_id
      and quantity_base_units = v_original_quantity
  ) then
    update public.stock_movements_v13
    set quantity_base_units = v_expected_quantity,
        note = concat_ws(
          ' · ',
          nullif(note, ''),
          'oprava: fakturováno 1 tyč Kelímek 180 ml, skladový odečet 1 × 50 ks'
        )
    where id = v_movement_id;

    update public.stock_location_balances
    set quantity_on_hand = quantity_on_hand - v_delta,
        updated_at = now()
    where stock_location_id = v_stock_location_id
      and product_id = v_product_id
      and batch_id is null;

    if not found then
      insert into public.stock_location_balances (
        stock_location_id,
        product_id,
        batch_id,
        quantity_on_hand,
        reserved_quantity,
        updated_at
      ) values (
        v_stock_location_id,
        v_product_id,
        null,
        -v_delta,
        0,
        now()
      );
    end if;
  elsif not exists (
    select 1
    from public.stock_movements_v13
    where id = v_movement_id
      and reference_type = 'sales_document'
      and product_id = v_product_id
      and from_stock_location_id = v_stock_location_id
      and quantity_base_units = v_expected_quantity
  ) then
    raise exception 'Expected stock movement % for % was not found in original or repaired state.', v_movement_id, v_document_number;
  end if;

  raise notice '% repaired: invoice item unit=1 tyč, stock movement=% ks (% tyč × % ks).',
    v_document_number,
    v_expected_quantity,
    v_original_quantity,
    v_units_per_stick;
end $$;

commit;
