-- Dílčí fyzická inventura surovin, kelímků a velkých víček na Fiat Doblo 5AP9000.
-- Zdroj: fyzický soupis z WhatsApp 2026-08-04 22:02 a následné upřesnění,
-- že jedna krabice malých i velkých kelímků obsahuje 1 000 ks.
-- Řádek „Čokoláda“ neměl v podkladu množství, proto produkt 106 zůstává beze změny.

begin;

do $$
declare
  v_location_id constant bigint := 4;
  v_vehicle_id constant bigint := 3;
  v_employee_id constant uuid := '9133f82b-89a6-4581-955c-d2138b947a8d';
  v_marker constant text := '[doblo-partial-inventory:2026-08-04-2202]';
  v_audit_id bigint;
  v_result jsonb;
begin
  if exists (
    select 1
    from public.inventory_audits
    where note like '%' || v_marker || '%'
      and status <> 'cancelled'
  ) then
    raise notice 'Inventura % už existuje; opakované spuštění nic nemění.', v_marker;
    return;
  end if;

  if not exists (
    select 1
    from public.stock_locations
    where id = v_location_id
      and location_type = 'vehicle'
      and vehicle_id = v_vehicle_id
      and name = 'Fiat Doblo · 5AP9000'
  ) then
    raise exception 'Skladové místo 4 už neodpovídá vozidlu Fiat Doblo 5AP9000.';
  end if;

  if exists (
    with expected(product_id, expected_name, expected_unit) as (
      values
        (110::bigint, 'Irish Cream 1 kg'::text, 'kg'::text),
        (109, 'oVe FRESH DRINK LEMON 1 kg', 'kg'),
        (103, 'oVe BASE WITH PISTACHIO FLAVOUR 1000g', 'kg'),
        (40, 'Creamio Slaný karamel PREMIUM 1 kg', 'g'),
        (143, 'AG PRO Matcha Latte Malina 1 kg', 'kg'),
        (104, 'oVe COFFEE CREAMER WHITE 1 kg', 'kg'),
        (105, 'oVe DRINK WITH CHOC WHITE FLAVOUR 1000g', 'kg'),
        (108, 'oVe FD COFFEE SOPHIA 500g', 'kg'),
        (42, 'Cukr Vending 1,5 kg', 'kg'),
        (78, 'Kelímek 180 ml', 'ks'),
        (80, 'Kelímek 300 ml', 'ks'),
        (136, 'VÍČKO HUHTAMAKI PLAST ČERNÉ 300ml', 'ks')
    )
    select 1
    from expected e
    left join public.products p on p.id = e.product_id
    where p.id is null
       or p.name <> e.expected_name
       or p.base_unit <> e.expected_unit
       or p.active is not true
  ) then
    raise exception 'Katalog surovin nebo obalů se změnil; inventura nebyla zapsána.';
  end if;

  insert into public.inventory_audits (
    audit_date,
    scope_type,
    stock_location_id,
    vehicle_id,
    assigned_employee_id,
    responsible_name,
    note,
    status,
    created_by,
    counted_at,
    transfer_confirmed_at,
    evaluated_at,
    evaluation_note
  ) values (
    date '2026-08-04',
    'vehicle',
    v_location_id,
    v_vehicle_id,
    v_employee_id,
    'Kristýna Dvořáková',
    'Dílčí inventura surovin, kelímků a velkých víček podle fyzického soupisu z 22:02. Tmavá čokoláda bez uvedeného počtu nebyla měněna. ' || v_marker,
    'evaluated',
    null,
    now(),
    now(),
    now(),
    'Fyzické počty již byly předány; přepočet: běžné prášky 1 kg/balení, Creamio 1 000 g/balení, Sophia 0,5 kg/balení, cukr 1,5 kg/balení, kelímky 1 000 ks/krabice a velká víčka 100 ks/tyč.'
  )
  returning id into v_audit_id;

  with targets(
    product_id,
    counted_quantity,
    package_id,
    package_count,
    counted_note
  ) as (
    values
      (110::bigint, 7::numeric, 34::bigint, 7::numeric, 'Irish: 7 balení × 1 kg'),
      (109, 6, 33, 6, 'Lemon: 6 balení × 1 kg'),
      (103, 1, 28, 1, 'Pistácie: 1 balení × 1 kg'),
      (40, 5000, 21, 5, 'Cappuccino Salty Toffee / Creamio Slaný karamel: 5 balení × 1 000 g'),
      (143, 6, 2, 6, 'Matcha Latte Malina: 6 balení × 1 kg'),
      (104, 13, 7, 13, 'Creamer: 13 balení × 1 kg'),
      (105, 16, 30, 16, 'Bílá čokoláda: 16 balení × 1 kg'),
      (108, 5.5, 32, 11, 'Caffe Sophia: 11 balení × 0,5 kg'),
      (42, 1.5, 6, 1, 'Cukr: 1 balení × 1,5 kg'),
      (78, 1000, 104, 1, 'Malé kelímky 180 ml: 1 krabice × 1 000 ks'),
      (80, 1000, 106, 1, 'Velké kelímky 300 ml: 1 krabice × 1 000 ks'),
      (136, 700, 35, 7, 'Velká víčka 300 ml: 7 tyčí × 100 ks')
  ),
  prepared as (
    select
      t.*,
      coalesce(sum(b.quantity_on_hand), 0)::numeric(14,3) as book_quantity,
      case
        when p.purchase_price is null then null
        when p.base_unit in ('g', 'ml') and pp.units_per_package > 1
          then p.purchase_price / pp.units_per_package
        when p.base_unit = 'ks' and pp.units_per_package > 1
          then p.purchase_price / pp.units_per_package
        else p.purchase_price
      end::numeric(12,2) as unit_cost
    from targets t
    join public.products p on p.id = t.product_id
    join public.product_packages pp on pp.id = t.package_id and pp.product_id = t.product_id
    left join public.stock_location_balances b
      on b.stock_location_id = v_location_id
     and b.product_id = t.product_id
    group by
      t.product_id,
      t.counted_quantity,
      t.package_id,
      t.package_count,
      t.counted_note,
      p.purchase_price,
      p.base_unit,
      pp.units_per_package
  )
  insert into public.inventory_audit_items (
    audit_id,
    stock_location_id,
    product_id,
    batch_id,
    book_quantity,
    counted_quantity,
    counted_package_id,
    counted_package_count,
    counted_loose_quantity,
    difference_quantity,
    unit_cost,
    difference_value,
    note,
    counted_note,
    counted_at
  )
  select
    v_audit_id,
    v_location_id,
    product_id,
    null,
    book_quantity,
    counted_quantity,
    package_id,
    package_count,
    0,
    round((counted_quantity - book_quantity)::numeric, 3),
    unit_cost,
    round(((counted_quantity - book_quantity) * coalesce(unit_cost, 0))::numeric, 2),
    'Dílčí fyzická inventura Dobla 5AP9000',
    counted_note,
    now()
  from prepared;

  update public.inventory_audits a
  set
    book_quantity_total = totals.book_quantity_total,
    counted_quantity_total = totals.counted_quantity_total,
    difference_quantity_total = totals.difference_quantity_total,
    difference_value_total = totals.difference_value_total
  from (
    select
      audit_id,
      round(sum(book_quantity)::numeric, 3) as book_quantity_total,
      round(sum(counted_quantity)::numeric, 3) as counted_quantity_total,
      round(sum(difference_quantity)::numeric, 3) as difference_quantity_total,
      round(sum(difference_value)::numeric, 2) as difference_value_total
    from public.inventory_audit_items
    where audit_id = v_audit_id
    group by audit_id
  ) totals
  where a.id = totals.audit_id;

  select public.close_inventory_audit_atomic(v_audit_id) into v_result;
  if coalesce(v_result->>'status', '') <> 'closed' then
    raise exception 'Inventura % se nepodařila uzavřít: %', v_audit_id, v_result;
  end if;
end $$;

commit;

select jsonb_build_object(
  'audit', (
    select to_jsonb(a)
    from (
      select
        id,
        audit_date,
        status,
        responsible_name,
        note,
        closed_at
      from public.inventory_audits
      where note like '%[doblo-partial-inventory:2026-08-04-2202]%'
      order by id desc
      limit 1
    ) a
  ),
  'items', (
    select jsonb_agg(to_jsonb(x) order by x.product_id)
    from (
      select
        p.id as product_id,
        p.name,
        p.base_unit,
        i.book_quantity,
        i.counted_quantity,
        i.difference_quantity,
        i.counted_note,
        coalesce(sum(b.quantity_on_hand), 0) as verified_balance
      from public.inventory_audits a
      join public.inventory_audit_items i on i.audit_id = a.id
      join public.products p on p.id = i.product_id
      left join public.stock_location_balances b
        on b.stock_location_id = a.stock_location_id
       and b.product_id = i.product_id
      where a.note like '%[doblo-partial-inventory:2026-08-04-2202]%'
      group by p.id, p.name, p.base_unit, i.book_quantity, i.counted_quantity,
               i.difference_quantity, i.counted_note
    ) x
  )
) as inventory_verification;
