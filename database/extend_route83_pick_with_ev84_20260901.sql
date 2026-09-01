begin;

do $$
declare
  v_request public.mobile_stock_requests%rowtype;
  v_big_shock public.mobile_stock_request_items%rowtype;
begin
  select * into strict v_request
  from public.mobile_stock_requests
  where id = 372
  for update;

  if v_request.route_plan_id <> 83
     or v_request.vehicle_id <> 2
     or v_request.status not in ('requested', 'picking')
     or v_request.stock_applied_at is not null then
    raise exception 'Vychystani #372 uz neni bezpecne upravitelne.';
  end if;

  update public.route_plans
  set route_payload = jsonb_set(
        coalesce(route_payload, '{}'::jsonb),
        '{picking_extra_machine_ids}',
        '[64]'::jsonb,
        true
      ),
      updated_at = now()
  where id = 83
    and vehicle_id = 2;

  if not found then
    raise exception 'Trasa #83 neodpovida Opelu Vivaro.';
  end if;

  select * into strict v_big_shock
  from public.mobile_stock_request_items
  where id = 3426
    and request_id = 372
    and product_id = 27
    and unit = 'Celé balení'
  for update;

  update public.mobile_stock_request_items
  set requested_quantity = requested_quantity + 1,
      prepared_quantity = coalesce(prepared_quantity, requested_quantity) + 1,
      note = concat_ws(' · ', nullif(note, ''), 'EV84 navic: pridano 1 baleni = 6 ks'),
      updated_at = now()
  where id = v_big_shock.id;

  if exists (
    select 1
    from public.mobile_stock_request_items
    where request_id = 372
      and product_id in (64, 49, 81, 84, 93)
  ) then
    raise exception 'Nektera doplnovana polozka EV84 uz ve vychystani #372 existuje; prepocitej upravu.';
  end if;

  insert into public.mobile_stock_request_items (
    request_id,
    product_id,
    product_name,
    sku,
    unit,
    requested_quantity,
    prepared_quantity,
    confirmed_quantity,
    note
  ) values
    (372, 64, 'Hello Perlivé malinový perlivý nápoj 330ml plech', '259', 'ks', 1, 1, null, 'EV84 Marius Pedersen · chybi 1 ks po zapocteni zasoby Vivara'),
    (372, 49, 'Doritos Tortillas Chipsy nachos cheese 44g', '210', 'ks', 5, 5, null, 'EV84 Marius Pedersen · chybi 5 ks po zapocteni zasoby Vivara'),
    (372, 81, 'Kinder Bueno Oplatky 43g', '28', 'ks', 4, 4, null, 'EV84 Marius Pedersen · chybi 4 ks po zapocteni zasoby Vivara'),
    (372, 84, 'Knoppers Oplatka 25g', '165', 'ks', 1, 1, null, 'EV84 Marius Pedersen · chybi 1 ks po zapocteni zasoby Vivara'),
    (372, 93, 'Mila Oplatky 50g', '36', 'ks', 1, 1, null, 'EV84 Marius Pedersen · chybi 1 ks po zapocteni zasoby Vivara');

  update public.mobile_stock_requests
  set note = concat_ws(
        ' · ',
        nullif(note, ''),
        'AUTOMAT NAVIC PRO PREVOZ: EV84 Marius Pedersen zapocten bez pridani zastavky a bez zmeny lokality',
        'Ve skladu neni: 3Bit 4 ks, Corny 1 ks, Kit Kat 2 ks, Margot 9 ks, Straznicke bramburky 5 ks; nevytvoren zaporny vydej ani presun z jineho auta'
      ),
      updated_at = now()
  where id = 372;
end
$$;

commit;

select
  request.id,
  request.status,
  request.route_plan_id,
  request.vehicle_id,
  item.product_name,
  item.unit,
  item.requested_quantity,
  item.note
from public.mobile_stock_requests request
join public.mobile_stock_request_items item on item.request_id = request.id
where request.id = 372
  and (item.id = 3426 or item.product_id in (64, 49, 81, 84, 93))
order by item.id;
