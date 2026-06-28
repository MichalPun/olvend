begin;

do $$
declare
  v_reference_id text := 'repair-mobile-writeoff-automaty-20260628';
  v_result jsonb;
  v_shortage text;
begin
  if exists (
    select 1
    from public.stock_movements_v13
    where reference_type = 'manual_correction'
      and reference_id = v_reference_id
  ) then
    raise notice 'Correction % already exists, skipping.', v_reference_id;
    return;
  end if;

  with required(product_id, quantity) as (
    values
      (11::bigint, 30.000::numeric),
      (12::bigint, 7.000::numeric),
      (14::bigint, 14.000::numeric),
      (17::bigint, 29.000::numeric),
      (18::bigint, 11.000::numeric),
      (27::bigint, 1.000::numeric),
      (158::bigint, 27.000::numeric)
  ),
  available as (
    select
      r.product_id,
      r.quantity as required_quantity,
      coalesce(sum(b.quantity_on_hand), 0) as available_quantity
    from required r
    left join public.stock_location_balances b
      on b.stock_location_id = 5
     and b.product_id = r.product_id
     and b.quantity_on_hand > 0
    group by r.product_id, r.quantity
  )
  select string_agg(
    coalesce(p.name, 'produkt #' || a.product_id::text)
      || ' požadováno ' || a.required_quantity::text
      || ', dostupné ' || a.available_quantity::text,
    '; '
  )
  into v_shortage
  from available a
  left join public.products p on p.id = a.product_id
  where a.available_quantity + 0.0001 < a.required_quantity;

  if v_shortage is not null then
    raise exception 'Nedostatek zásoby na Automaty pro korekci: %', v_shortage;
  end if;

  with required(product_id, quantity) as (
    values
      (11::bigint, 30.000::numeric),
      (12::bigint, 7.000::numeric),
      (14::bigint, 14.000::numeric),
      (17::bigint, 29.000::numeric),
      (18::bigint, 11.000::numeric),
      (27::bigint, 1.000::numeric),
      (158::bigint, 27.000::numeric)
  ),
  source_batches as (
    select
      b.product_id,
      b.batch_id,
      b.quantity_on_hand,
      coalesce(
        sum(b.quantity_on_hand) over (
          partition by b.product_id
          order by (b.batch_id is null), b.batch_id
          rows between unbounded preceding and 1 preceding
        ),
        0
      ) as quantity_before
    from public.stock_location_balances b
    join required r on r.product_id = b.product_id
    where b.stock_location_id = 5
      and b.quantity_on_hand > 0
  ),
  allocated as (
    select
      s.product_id,
      s.batch_id,
      least(s.quantity_on_hand, r.quantity - s.quantity_before) as moved_quantity
    from source_batches s
    join required r on r.product_id = s.product_id
    where r.quantity > s.quantity_before
  ),
  movement_rows as (
    select jsonb_agg(
      jsonb_build_object(
        'product_id', a.product_id,
        'batch_id', a.batch_id,
        'from_stock_location_id', 5,
        'to_stock_location_id', null,
        'movement_type', 'waste',
        'quantity_base_units', round(a.moved_quantity::numeric, 3),
        'unit_price', null,
        'reference_type', 'manual_correction',
        'reference_id', v_reference_id,
        'note', 'Oprava historických mobilních vratek/odpisů: odečet z Automatů bez zásahu do vozidel'
      )
      order by a.product_id, (a.batch_id is null), a.batch_id
    ) as rows
    from allocated a
    where a.moved_quantity > 0
  )
  select public.apply_stock_movements_v13(coalesce(rows, '[]'::jsonb))
  into v_result
  from movement_rows;

  raise notice 'Correction % applied: %', v_reference_id, v_result;
end $$;

commit;
