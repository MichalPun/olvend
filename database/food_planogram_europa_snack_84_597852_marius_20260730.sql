-- Aktuální planogram EV 84 / Europa Snack / Marius Pedersen a.s.
-- Zdroj: Planogram [84] Europa Snack-2026-07-30.xlsx.
-- TID 597852; expirace se přebírají pouze tam, kde jsou uvedené ve zdroji.
-- Pozice 61 má ve zdroji prodejní cenu 20 Kč a DEX cenu 0 Kč; rozdíl je zachován.

begin;

do $$
begin
  if not exists (
    select 1
    from public.machines
    where id = 64
      and evidence_number = 84
      and qr_token = 'vendsoft-84'
      and location_id = 14
      and machine_type = 'Snack'
  ) then
    raise exception 'EV 84 / Europa Snack / Marius Pedersen nebyl nalezen na očekávaném DB záznamu.';
  end if;
end
$$;

update public.machines
set
  name = 'Europa Snack',
  machine_type = 'Snack',
  sales_tracking_mode = 'telemetry',
  note = 'Planogram 2026-07-30; EV 84; Marius Pedersen a.s., Brno - Černovice. TID 597852.',
  updated_at = now()
where id = 64;

insert into public.machine_external_links (
  machine_id, provider, external_machine_id, telemetry_enabled, note
)
values
  (64, 'IMA', '597852', true, 'TID 597852 pro EV 84 / Europa Snack / Marius Pedersen.'),
  (64, 'GP',  '597852', true, 'TID 597852 pro EV 84 / Europa Snack / Marius Pedersen.')
on conflict (provider, external_machine_id) do update
set
  machine_id = excluded.machine_id,
  telemetry_enabled = true,
  note = excluded.note,
  updated_at = now();

update public.machine_planogram_slots
set active = false, updated_at = now()
where machine_id = 64;

insert into public.machine_planogram_slots (
  machine_id, slot_code, product_name, product_sku,
  price_czk, current_units, last_units, capacity_units,
  dex_price_czk, desired_units, target_units, expiry_date, telemetry_key,
  sort_order, active, product_family, product_variant,
  planned_product_name, planned_product_sku, planned_price_czk,
  substitution_policy, allowed_substitutes, operator_instruction, note
)
select
  64,
  d.slot_code,
  p.name,
  p.sku,
  d.price_czk,
  d.current_units,
  d.last_units,
  d.capacity_units,
  d.dex_price_czk,
  d.desired_units,
  least(d.capacity_units, d.current_units + d.desired_units),
  d.expiry_date,
  d.slot_code,
  d.sort_order,
  true,
  d.product_family,
  d.product_variant,
  d.planned_product_name,
  d.product_sku,
  d.price_czk,
  d.substitution_policy,
  d.allowed_substitutes,
  d.operator_instruction,
  'Planogram EV 84 / Marius Pedersen / TID 597852 aktualizován ze souboru 2026-07-30.'
from (values
  ('1',  19::numeric,  6,  6,  6, 19::numeric, 0, '163',  0, 'QXE', null, 'QXE Energetický nápoj 250ml plech', 'exact', null, null, null::date),
  ('2',  27::numeric,  5,  6,  6, 27::numeric, 1, '4',    1, 'Hell', 'Classic', 'Hell Energetický nápoj classic 250ml plech', 'exact', null, null, null::date),
  ('3',  48::numeric,  4,  6,  6, 48::numeric, 2, '190',  2, 'Red Bull', null, 'Red Bull 0,25l', 'exact', null, null, null::date),
  ('4',  25::numeric,  5,  5,  5, 25::numeric, 0, '6',    3, 'Relax', 'Liči', 'Relax Limonáda liči 330ml plech', 'exact', null, null, null::date),
  ('5',  15::numeric,  6,  6,  6, 15::numeric, 0, '41',   4, 'Capri-Sun', 'Multivitamin', 'Capri-Sun Multivitamin ovocný nápoj 200ml', 'exact', null, null, null::date),
  ('6',  25::numeric,  4,  4,  4, 25::numeric, 0, '259',  5, 'Hello', 'Malina', 'Hello Perlivé malinový perlivý nápoj 330ml plech', 'exact', null, null, null::date),
  ('12', 33::numeric,  4,  6,  6, 33::numeric, 2, '71',   6, 'Pepsi', 'Cola', 'Pepsi Cola 500ml PET', 'exact', null, null, null::date),
  ('13', 30::numeric,  6,  6,  6, 30::numeric, 0, '67',   7, 'Nestea', 'Peach', 'Nestea 0,5l různé druhy', 'approved_list', 'Nestea Lemon 0,5l (SKU 275)', 'Přednostně Peach SKU 67; lze použít Lemon SKU 275.', null::date),
  ('14', 32::numeric,  5,  6,  6, 32::numeric, 1, '70',   8, 'Kofola', 'Original', 'Kofola Original 500ml PET', 'exact', null, null, null::date),
  ('15', 24::numeric,  3,  6,  6, 24::numeric, 3, '209',  9, 'ZON', 'Různé druhy', 'ZON 500ml PET různé druhy', 'exact', null, null, null::date),
  ('16', 29::numeric,  6,  6,  6, 29::numeric, 0, '156', 10, 'Ice Coffee', null, 'Ice Coffee Ledová káva 350ml', 'exact', null, null, null::date),
  ('17', 39::numeric,  6,  6,  6, 39::numeric, 0, '2',   11, 'Big Shock!', 'Exotic', 'Big Shock! Energetický nápoj Exotic 500ml plech', 'exact', null, null, null::date),
  ('23', 55::numeric,  3,  4,  4, 55::numeric, 1, '155', 12, 'ATM', 'Debrecínská', 'ATM Debrecínská bageta', 'exact', null, 'Zkontroluj expiraci zásoby v automatu; neprodejné kusy odepiš.', '2026-08-04'::date),
  ('24', 55::numeric,  0,  3,  4, 55::numeric, 4, '278', 13, 'ATM', 'Masové koule', 'ATM - Masové koule', 'exact', null, 'Zkontroluj expiraci zásoby v automatu; neprodejné kusy odepiš.', '2026-08-06'::date),
  ('25', 55::numeric,  2,  5,  4, 55::numeric, 2, '17',  14, 'ATM', 'Kuřecí stripsy', 'ATM - Kuřecí stripsy', 'exact', null, 'Zkontroluj expiraci zásoby v automatu; neprodejné kusy odepiš.', '2026-07-30'::date),
  ('26', 19::numeric,  5,  6,  6, 19::numeric, 1, '38',  15, 'Havlík', 'Originál', 'Havlík Tyčinky originál 90g', 'exact', null, 'Zkontroluj expiraci zásoby v automatu; neprodejné kusy odepiš.', '2025-08-17'::date),
  ('27', 25::numeric,  6,  6,  6, 25::numeric, 0, '210', 16, 'Doritos', 'Nachos cheese', 'Doritos Tortillas Chipsy nachos cheese 44g', 'exact', null, null, null::date),
  ('28', 29::numeric,  3,  6,  6, 29::numeric, 3, '277', 17, 'DrWitt', 'Mango+citron', 'DrWitt min. voda 0,55l různé druhy', 'approved_list', 'DrWitt citrus SKU 276; DrWitt liči+hruška SKU 200', 'Přednostně mango+citron SKU 277; lze použít citrus SKU 276 nebo liči+hruška SKU 200.', null::date),
  ('29', 29::numeric,  6,  6,  6, 29::numeric, 0, '207', 18, 'Bad Brambacher', 'Malina', 'Bad Brambacher 0,5l různé druhy', 'exact', null, null, null::date),
  ('34', 26::numeric,  8,  8,  8, 26::numeric, 0, '36',  19, 'Mila', null, 'Mila Oplatky 50g', 'exact', null, null, null::date),
  ('35', 20::numeric, 15, 15, 15, 20::numeric, 0, '35',  20, 'Sedita Horalky', 'Arašídové', 'Sedita Horalky Oplatky arašídové 50g', 'exact', null, null, null::date),
  ('36', 11::numeric, 20, 20, 20, 11::numeric, 0, '33',  21, 'Attack', 'Lískooříšková', 'Attack Oplatka lískooříšková 30g', 'exact', null, null, null::date),
  ('37', 26::numeric, 15, 15, 15, 26::numeric, 0, '24',  22, 'Snickers', null, 'Snickers Tyčinka čokoládová 50g', 'exact', null, null, null::date),
  ('38', 30::numeric,  7,  7,  7, 30::numeric, 0, '28',  23, 'Kinder Bueno', null, 'Kinder Bueno Oplatky 43g', 'exact', null, null, null::date),
  ('39', 25::numeric,  8,  9,  9, 25::numeric, 1, '40',  24, 'Margot', null, 'Margot Tyčinka 80g', 'exact', null, null, null::date),
  ('40',  8::numeric, 15, 15, 15,  8::numeric, 0, '208', 25, 'Alaska', 'Různé druhy', 'Alaska kukuřičné trubičky plněné krémem 18g různé druhy', 'exact', null, null, null::date),
  ('45', 26::numeric, 15, 15, 15, 26::numeric, 0, '25',  26, 'Twix', null, 'Twix Tyčinka 50g', 'exact', null, null, null::date),
  ('46', 24::numeric,  9,  9,  9, 24::numeric, 0, '27',  27, 'Kit Kat', '4 Fingers', 'Kit Kat 4 Fingers Tyčinka 41,5g', 'exact', null, null, null::date),
  ('47', 11::numeric,  9,  9,  9, 11::numeric, 0, '165', 28, 'Knoppers', null, 'Knoppers Oplatka 25g', 'exact', null, null, null::date),
  ('48', 14::numeric,  6,  8,  8, 14::numeric, 2, '254', 29, 'Dr.Ensa', 'Kukuřice BBQ', 'Dr.Ensa Kukuřice pražená solená s příchutí barbecue 60g', 'exact', null, null, null::date),
  ('49', 24::numeric,  8,  8,  8, 24::numeric, 0, '31',  30, 'Miňonky', 'Oříškové', 'Miňonky Oplatky oříškové 50g', 'exact', null, null, null::date),
  ('50', 30::numeric, 15, 15, 15, 30::numeric, 0, '26',  31, '3Bit', 'Různé druhy', '3Bit tyčinka různé druhy', 'exact', null, null, null::date),
  ('51', 21::numeric, 10, 10, 10, 21::numeric, 0, '261', 32, 'Corny Big', 'Banán', 'Corny Big Tyčinka banány v mléčné čokoládě 50g', 'exact', null, null, null::date),
  ('56', 27::numeric,  8,  8,  8, 27::numeric, 0, '39',  33, 'Haribo', 'Goldbären', 'Haribo Bonbóny goldbären želé medvídci 100g', 'exact', null, null, null::date),
  ('57', 20::numeric,  6,  6,  6, 20::numeric, 0, '42',  34, '7days', 'Lískový oříšek', '7days Croissant lískový oříšek 60g', 'exact', null, null, null::date),
  ('58', 19::numeric,  5,  5,  7, 19::numeric, 2, '139', 35, 'Strážnické brambůrky', 'Česnekové', 'Strážnické brambůrky Chipsy česnekové 60g', 'exact', null, null, null::date),
  ('61', 20::numeric, 10, 10, 10,  0::numeric, 0, '144', 36, 'Yoohoo!', 'Kakao+lískový oříšek', 'Yoohoo! Vafle kakao+lískový oříšek 50', 'exact', null, 'Prodejní cena je 20 Kč; DEX cena ve zdroji je 0 Kč.', null::date)
) as d(
  slot_code, price_czk, current_units, last_units, capacity_units,
  dex_price_czk, desired_units, product_sku, sort_order,
  product_family, product_variant, planned_product_name,
  substitution_policy, allowed_substitutes, operator_instruction, expiry_date
)
join public.products p on p.sku = d.product_sku and p.active = true
on conflict (machine_id, slot_code) do update
set
  product_name = excluded.product_name,
  product_sku = excluded.product_sku,
  price_czk = excluded.price_czk,
  current_units = excluded.current_units,
  last_units = excluded.last_units,
  capacity_units = excluded.capacity_units,
  target_units = excluded.target_units,
  fill_percent = case
    when excluded.capacity_units > 0
      then round((excluded.current_units::numeric / excluded.capacity_units::numeric) * 100, 2)
    else 0
  end,
  dex_price_czk = excluded.dex_price_czk,
  desired_units = excluded.desired_units,
  expiry_date = excluded.expiry_date,
  telemetry_key = excluded.telemetry_key,
  sort_order = excluded.sort_order,
  active = true,
  product_family = excluded.product_family,
  product_variant = excluded.product_variant,
  planned_product_name = excluded.planned_product_name,
  planned_product_sku = excluded.planned_product_sku,
  planned_price_czk = excluded.planned_price_czk,
  substitution_policy = excluded.substitution_policy,
  allowed_substitutes = excluded.allowed_substitutes,
  operator_instruction = excluded.operator_instruction,
  note = excluded.note,
  updated_at = now();

do $$
declare
  v_count integer;
  v_links integer;
  v_bad_capacity integer;
  v_location_id bigint;
  v_desired integer;
  v_expiries integer;
  v_dex_zero integer;
begin
  select count(*), coalesce(sum(desired_units), 0), count(expiry_date)
  into v_count, v_desired, v_expiries
  from public.machine_planogram_slots
  where machine_id = 64 and active = true;

  if v_count <> 37 then
    raise exception 'EV 84: očekáváno 37 aktivních pozic, nalezeno %.', v_count;
  end if;

  if v_desired <> 25 then
    raise exception 'EV 84: očekáváno celkem 25 ks k doplnění, nalezeno %.', v_desired;
  end if;

  if v_expiries <> 4 then
    raise exception 'EV 84: očekávány 4 evidované expirace, nalezeno %.', v_expiries;
  end if;

  select count(*) into v_links
  from public.machine_external_links
  where machine_id = 64
    and external_machine_id = '597852'
    and telemetry_enabled = true;

  if v_links <> 2 then
    raise exception 'EV 84: očekávány 2 aktivní vazby TID 597852, nalezeno %.', v_links;
  end if;

  select count(*) into v_bad_capacity
  from public.machine_planogram_slots
  where machine_id = 64
    and active = true
    and current_units > capacity_units;

  if v_bad_capacity <> 0 then
    raise exception 'EV 84: nalezeny pozice nad kapacitou: %.', v_bad_capacity;
  end if;

  select count(*) into v_dex_zero
  from public.machine_planogram_slots
  where machine_id = 64
    and active = true
    and slot_code = '61'
    and price_czk = 20
    and dex_price_czk = 0;

  if v_dex_zero <> 1 then
    raise exception 'EV 84: rozdíl prodejní/DEX ceny na pozici 61 nebyl zachován.';
  end if;

  select location_id into v_location_id
  from public.machines
  where id = 64;

  if v_location_id <> 14 then
    raise exception 'EV 84: automat není připojen k lokalitě Marius Pedersen (ID 14), ale k %.', v_location_id;
  end if;
end
$$;

commit;
notify pgrst, 'reload schema';
