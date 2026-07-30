-- Aktuální planogram EV 94 / FAS 1050 / Koupaliště Osíčko.
-- Zdroj: Planogram [94] FAS 1050-2026-07-30.xlsx.
-- TID 604311; sezónní přesun ze Sportovní haly Krásné Pole.
-- Lokalita VendSoft 96: 768 61 Osíčko-Chvalčov; GPS 49.426041, 17.751813.
-- Expirace se přebírají pouze tam, kde jsou uvedené ve zdroji.

begin;

select pg_advisory_xact_lock(hashtext('olvend:location:koupaliste-osicko'));

do $$
begin
  if not exists (
    select 1
    from public.machines
    where id = 74
      and evidence_number = 94
      and qr_token = 'vendsoft-94'
      and location_id in (49, 74)
      and machine_type = 'Snack'
  ) then
    raise exception 'EV 94 / FAS 1050 nebyl nalezen na očekávaném DB záznamu.';
  end if;

  if exists (
    select 1
    from public.locations
    where id = 74
      and (
        name <> 'Koupaliště Osíčko'
        or coalesce(city, '') <> 'Osíčko-Chvalčov'
        or coalesce(address, '') <> '768 61 Osíčko-Chvalčov'
      )
  ) then
    raise exception 'ID lokality 74 je již použité pro jinou lokalitu.';
  end if;
end
$$;

insert into public.locations (
  id,
  name,
  city,
  address,
  customer_name,
  contact_person,
  contact_phone,
  service_window,
  route_note,
  vendsoft_location_id,
  active,
  latitude,
  longitude,
  created_at,
  updated_at
)
values (
  74,
  'Koupaliště Osíčko',
  'Osíčko-Chvalčov',
  '768 61 Osíčko-Chvalčov',
  'Obec Osíčko – koupaliště',
  'Vladimíra Kouřilová',
  '+420 573 390 230',
  'po–pá 8:00–20:00',
  'Kontakt: mistostarosta@osicko.cz. Sezónní umístění EV 94; po skončení letní sezóny vrátit do Sportovní haly Krásné Pole.',
  96,
  true,
  49.426041,
  17.751813,
  now(),
  now()
)
on conflict (id) do update
set
  name = excluded.name,
  city = excluded.city,
  address = excluded.address,
  customer_name = excluded.customer_name,
  contact_person = excluded.contact_person,
  contact_phone = excluded.contact_phone,
  service_window = excluded.service_window,
  route_note = excluded.route_note,
  vendsoft_location_id = excluded.vendsoft_location_id,
  active = true,
  latitude = excluded.latitude,
  longitude = excluded.longitude,
  updated_at = now();

update public.machines
set
  location_id = 74,
  name = 'FAS 1050',
  machine_type = 'Snack',
  sales_tracking_mode = 'telemetry',
  note = 'Planogram 2026-07-30; EV 94 sezónně přesunut ze Sportovní haly Krásné Pole na Koupaliště Osíčko. TID 604311.',
  updated_at = now()
where id = 74;

insert into public.machine_external_links (
  machine_id, provider, external_machine_id, telemetry_enabled, note
)
values
  (74, 'IMA', '604311', true, 'TID 604311 pro EV 94 / FAS 1050 / Koupaliště Osíčko.'),
  (74, 'GP',  '604311', true, 'TID 604311 pro EV 94 / FAS 1050 / Koupaliště Osíčko.')
on conflict (provider, external_machine_id) do update
set
  machine_id = excluded.machine_id,
  telemetry_enabled = true,
  note = excluded.note,
  updated_at = now();

update public.machine_planogram_slots
set active = false, updated_at = now()
where machine_id = 74;

insert into public.machine_planogram_slots (
  machine_id, slot_code, product_name, product_sku,
  price_czk, current_units, last_units, capacity_units,
  dex_price_czk, desired_units, target_units, expiry_date, telemetry_key,
  sort_order, active, product_family, product_variant,
  planned_product_name, planned_product_sku, planned_price_czk,
  substitution_policy, allowed_substitutes, operator_instruction, note
)
select
  74,
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
  'Planogram EV 94 / Koupaliště Osíčko / TID 604311 aktualizován ze souboru 2026-07-30.'
from (values
  ('11', 31::numeric,  2,  5,  5, 31::numeric, 3, '39',   0, 'Haribo', 'Goldbären', 'Haribo Bonbóny goldbären želé medvídci 100g', 'exact', null, null, null::date),
  ('13', 25::numeric,  8,  8,  8, 25::numeric, 0, '42',   1, '7days', 'Lískový oříšek', '7days Croissant lískový oříšek 60g', 'exact', null, null, null::date),
  ('15', 25::numeric,  4,  4,  4, 25::numeric, 0, '42',   2, '7days', 'Lískový oříšek', '7days Croissant lískový oříšek 60g', 'exact', null, null, null::date),
  ('17', 23::numeric,  6,  6,  6, 23::numeric, 0, '211',  3, 'Nový věk', 'Hořko-kakaová poleva', 'Nový věk Chlebíčky rýžové hořko-kakaová poleva 60g', 'exact', null, null, null::date),
  ('19', 32::numeric,  7,  7,  7, 32::numeric, 0, '20',   4, 'Dupetky', 'Hořčice, med a cibulka', 'Dupetky Snack pečený hořčice+med+cibulka 70g', 'exact', null, null, null::date),
  ('20', 18::numeric,  7,  7,  7, 18::numeric, 0, '280',  5, 'Veneto', 'Vanilka a kakao', 'Veneto Oplatka s vanilkovou a kakaovou náplní 65g', 'exact', null, null, null::date),
  ('21', 29::numeric,  9,  9,  9, 29::numeric, 0, '25',   6, 'Twix', null, 'Twix Tyčinka 50g', 'exact', null, null, null::date),
  ('22', 27::numeric,  9, 10, 10, 27::numeric, 1, '27',   7, 'Kit Kat', '4 Fingers', 'Kit Kat 4 Fingers Tyčinka 41,5g', 'exact', null, null, null::date),
  ('23', 14::numeric,  6,  6,  6, 14::numeric, 0, '165',  8, 'Knoppers', null, 'Knoppers Oplatka 25g', 'exact', null, null, null::date),
  ('24', 16::numeric, 10, 10, 10, 16::numeric, 0, '254',  9, 'Dr.Ensa', 'Kukuřice BBQ', 'Dr.Ensa Kukuřice pražená solená s příchutí barbecue 60g', 'exact', null, null, null::date),
  ('25', 27::numeric, 10, 10, 10, 27::numeric, 0, '31',  10, 'Miňonky', 'Oříškové', 'Miňonky Oplatky oříškové 50g', 'exact', null, null, null::date),
  ('26', 34::numeric,  8,  8,  8, 34::numeric, 0, '26',  11, '3Bit', 'Různé druhy', '3Bit tyčinka různé druhy', 'exact', null, null, null::date),
  ('27', 23::numeric,  8,  8,  8, 23::numeric, 0, '261', 12, 'Corny Big', 'Banán', 'Corny Big Tyčinka banány v mléčné čokoládě 50g', 'exact', null, null, null::date),
  ('28', 22::numeric,  5,  7,  7, 22::numeric, 2, '213', 13, 'Skittles', 'Ovocné', 'Skittles Bonbóny ovocné žvýkací 38g', 'exact', null, null, null::date),
  ('29', 22::numeric,  8,  8,  8, 22::numeric, 0, '144', 14, 'Yoohoo!', 'Kakao+lískový oříšek', 'Yoohoo! Vafle kakao+lískový oříšek 50', 'exact', null, null, null::date),
  ('30', 17::numeric,  9, 10, 10, 17::numeric, 1, '30',  15, 'Romanca', 'Kakaová náplň', 'Romanca Sušenka s kakaovou náplní 40g', 'exact', null, null, null::date),
  ('31', 29::numeric, 15, 15, 15, 29::numeric, 0, '36',  16, 'Mila', null, 'Mila Oplatky 50g', 'exact', null, null, null::date),
  ('32', 23::numeric, 14, 14, 14, 23::numeric, 0, '35',  17, 'Sedita Horalky', 'Arašídové', 'Sedita Horalky Oplatky arašídové 50g', 'exact', null, null, null::date),
  ('33', 14::numeric, 13, 13, 13, 14::numeric, 0, '33',  18, 'Attack', 'Lískooříšková', 'Attack Oplatka lískooříšková 30g', 'exact', null, null, null::date),
  ('34', 29::numeric, 14, 14, 14, 29::numeric, 0, '24',  19, 'Snickers', null, 'Snickers Tyčinka čokoládová 50g', 'exact', null, null, null::date),
  ('35', 33::numeric,  6, 10, 10, 33::numeric, 4, '28',  20, 'Kinder Bueno', null, 'Kinder Bueno Oplatky 43g', 'exact', null, null, null::date),
  ('36', 28::numeric, 10, 10, 10, 28::numeric, 0, '40',  21, 'Margot', null, 'Margot Tyčinka 80g', 'exact', null, null, null::date),
  ('37', 10::numeric,  8, 10, 10, 10::numeric, 2, '208', 22, 'Alaska', 'Různé druhy', 'Alaska kukuřičné trubičky plněné krémem 18g různé druhy', 'exact', null, null, null::date),
  ('38', 13::numeric,  7, 11, 11, 13::numeric, 4, '143', 23, 'Today Donut', 'Kakaová náplň', 'Today Donut Dezert s kakaovou náplní v polevě 50g', 'exact', null, null, null::date),
  ('39', 16::numeric,  3, 10, 10, 16::numeric, 7, '142', 24, 'Racio Free Style', 'Rajče a bazalka', 'Racio Free Style Chlebíčky rajče a bazalka 25g', 'exact', null, null, null::date),
  ('40', 35::numeric,  4,  4,  4, 35::numeric, 0, '277', 25, 'DrWitt', 'Mango+citron', 'DrWitt min. voda 0,55l různé druhy', 'approved_list', 'DrWitt citrus SKU 276; DrWitt liči+hruška SKU 200', 'Přednostně mango+citron SKU 277; lze použít citrus SKU 276 nebo liči+hruška SKU 200. Zdroj uváděl kapacitu 3 při stavu 4; provozní kapacita sjednocena na 4.', null::date),
  ('41', 35::numeric,  3,  3,  3, 35::numeric, 0, '207', 26, 'Bad Brambacher', 'Malina', 'Bad Brambacher 0,5l různé druhy', 'exact', null, 'Zkontroluj expiraci zásoby v automatu; neprodejné kusy odepiš.', '2026-07-09'::date),
  ('42', 30::numeric,  5,  5,  5, 30::numeric, 0, '209', 27, 'ZON', 'Různé druhy', 'ZON 500ml PET různé druhy', 'exact', null, 'Zkontroluj expiraci zásoby v automatu; neprodejné kusy odepiš.', '2026-07-09'::date),
  ('43', 40::numeric,  5,  5,  5, 40::numeric, 0, '67',  28, 'Nestea', 'Peach', 'Nestea 0,5l různé druhy', 'approved_list', 'Nestea Lemon 0,5l (SKU 275)', 'Přednostně Peach SKU 67; lze použít Lemon SKU 275. Zkontroluj expiraci zásoby v automatu.', '2026-07-09'::date),
  ('44', 23::numeric,  6,  6,  6, 23::numeric, 0, '38',  29, 'Havlík', 'Originál', 'Havlík Tyčinky originál 90g', 'exact', null, 'Zkontroluj expiraci zásoby v automatu; neprodejné kusy odepiš.', '2026-07-01'::date),
  ('45', 29::numeric,  0,  6,  6, 29::numeric, 6, '210', 30, 'Doritos', 'Nachos cheese', 'Doritos Tortillas Chipsy nachos cheese 44g', 'exact', null, 'Zkontroluj expiraci zásoby v automatu; neprodejné kusy odepiš.', '2026-02-21'::date),
  ('46', 35::numeric,  5,  6,  6, 35::numeric, 1, '277', 31, 'DrWitt', 'Mango+citron', 'DrWitt min. voda 0,55l různé druhy', 'approved_list', 'DrWitt citrus SKU 276; DrWitt liči+hruška SKU 200', 'Přednostně mango+citron SKU 277; lze použít citrus SKU 276 nebo liči+hruška SKU 200. Zkontroluj expiraci zásoby v automatu.', '2026-02-21'::date),
  ('47', 35::numeric,  6,  6,  6, 35::numeric, 0, '207', 32, 'Bad Brambacher', 'Malina', 'Bad Brambacher 0,5l různé druhy', 'exact', null, null, null::date),
  ('48', 35::numeric,  3,  3,  3, 35::numeric, 0, '70',  33, 'Kofola', 'Original', 'Kofola Original 500ml PET', 'exact', null, null, null::date),
  ('49', 40::numeric,  3,  4,  4, 40::numeric, 1, '71',  34, 'Pepsi', 'Cola', 'Pepsi Cola 500ml PET', 'exact', null, null, null::date),
  ('50', 30::numeric,  5,  5,  5, 30::numeric, 0, '209', 35, 'ZON', 'Různé druhy', 'ZON 500ml PET různé druhy', 'exact', null, null, null::date),
  ('51', 40::numeric,  6,  6,  6, 40::numeric, 0, '71',  36, 'Pepsi', 'Cola', 'Pepsi Cola 500ml PET', 'exact', null, null, null::date),
  ('52', 40::numeric,  6,  6,  6, 40::numeric, 0, '67',  37, 'Nestea', 'Peach', 'Nestea 0,5l různé druhy', 'approved_list', 'Nestea Lemon 0,5l (SKU 275)', 'Přednostně Peach SKU 67; lze použít Lemon SKU 275.', null::date),
  ('53', 40::numeric,  6,  6,  6, 40::numeric, 0, '67',  38, 'Nestea', 'Peach', 'Nestea 0,5l různé druhy', 'approved_list', 'Nestea Lemon 0,5l (SKU 275)', 'Přednostně Peach SKU 67; lze použít Lemon SKU 275.', null::date),
  ('54', 30::numeric,  5,  6,  6, 30::numeric, 1, '209', 39, 'ZON', 'Různé druhy', 'ZON 500ml PET různé druhy', 'exact', null, null, null::date),
  ('55', 35::numeric,  2,  6,  6, 35::numeric, 4, '156', 40, 'Ice Coffee', null, 'Ice Coffee Ledová káva 350ml', 'exact', null, null, null::date),
  ('56', 45::numeric,  5,  5,  5, 45::numeric, 0, '2',   41, 'Big Shock!', 'Exotic', 'Big Shock! Energetický nápoj Exotic 500ml plech', 'exact', null, null, null::date),
  ('57', 35::numeric,  5,  5,  5, 35::numeric, 0, '187', 42, 'Staropramen Cool', 'Citron', 'Staropramen Cool citron nealkoholický nápoj z piva 500ml plech', 'exact', null, null, null::date),
  ('58', 30::numeric,  6,  6,  6, 30::numeric, 0, '13',  43, 'Hanácká Kyselka', 'Citron jemně perlivá', 'Hanácká Kyselka Minerální voda citron jemně perlivá 500ml PET', 'exact', null, null, null::date),
  ('59', 40::numeric,  6,  6,  6, 40::numeric, 0, '71',  44, 'Pepsi', 'Cola', 'Pepsi Cola 500ml PET', 'exact', null, null, null::date),
  ('60', 60::numeric,  5,  6,  6, 20::numeric, 1, '190', 45, 'Red Bull', null, 'Red Bull 0,25l', 'exact', null, 'Cena v automatu 60 Kč; DEX cena ve zdroji 20 Kč.', null::date),
  ('61', 22::numeric,  6,  6,  6, 22::numeric, 0, '163', 46, 'QXE', null, 'QXE Energetický nápoj 250ml plech', 'exact', null, null, null::date),
  ('62', 22::numeric,  6,  6,  6, 22::numeric, 0, '163', 47, 'QXE', null, 'QXE Energetický nápoj 250ml plech', 'exact', null, null, null::date),
  ('63', 35::numeric,  6,  6,  6, 35::numeric, 0, '4',   48, 'Hell', 'Classic', 'Hell Energetický nápoj classic 250ml plech', 'exact', null, null, null::date),
  ('64', 60::numeric,  5,  6,  6, 60::numeric, 1, '190', 49, 'Red Bull', null, 'Red Bull 0,25l', 'exact', null, null, null::date),
  ('65', 20::numeric,  0,  5,  6, 30::numeric, 6, '69',  50, 'Kubík', 'Různé druhy', 'Kubík 0,3l různé druhy', 'exact', null, 'Cena v automatu 20 Kč; DEX cena ve zdroji 30 Kč.', null::date),
  ('66', 20::numeric,  5,  6,  6, 20::numeric, 1, '41',  51, 'Capri-Sun', 'Multivitamin', 'Capri-Sun Multivitamin ovocný nápoj 200ml', 'exact', null, null, null::date),
  ('67', 27::numeric,  6,  6,  6, 27::numeric, 0, '157', 52, 'Pepsi', 'Cola', 'Pepsi 0,33l plech', 'exact', null, null, null::date),
  ('68', 30::numeric,  6,  6,  6, 30::numeric, 0, '259', 53, 'Hello', 'Malina', 'Hello Perlivé malinový perlivý nápoj 330ml plech', 'exact', null, null, null::date),
  ('69', 22::numeric,  4,  6,  6, 22::numeric, 2, '163', 54, 'QXE', null, 'QXE Energetický nápoj 250ml plech', 'exact', null, null, null::date)
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
begin
  select count(*), coalesce(sum(desired_units), 0), count(expiry_date)
  into v_count, v_desired, v_expiries
  from public.machine_planogram_slots
  where machine_id = 74 and active = true;

  if v_count <> 55 then
    raise exception 'EV 94: očekáváno 55 aktivních pozic, nalezeno %.', v_count;
  end if;

  if v_desired <> 48 then
    raise exception 'EV 94: očekáváno celkem 48 ks k doplnění, nalezeno %.', v_desired;
  end if;

  if v_expiries <> 6 then
    raise exception 'EV 94: očekáváno 6 evidovaných expirací, nalezeno %.', v_expiries;
  end if;

  select count(*) into v_links
  from public.machine_external_links
  where machine_id = 74
    and external_machine_id = '604311'
    and telemetry_enabled = true;

  if v_links <> 2 then
    raise exception 'EV 94: očekávány 2 aktivní vazby TID 604311, nalezeno %.', v_links;
  end if;

  select count(*) into v_bad_capacity
  from public.machine_planogram_slots
  where machine_id = 74
    and active = true
    and current_units > capacity_units;

  if v_bad_capacity <> 0 then
    raise exception 'EV 94: nalezeny pozice nad kapacitou: %.', v_bad_capacity;
  end if;

  select location_id into v_location_id
  from public.machines
  where id = 74;

  if v_location_id <> 74 then
    raise exception 'EV 94: automat není připojen k lokalitě Koupaliště Osíčko (ID 74), ale k %.', v_location_id;
  end if;
end
$$;

commit;
notify pgrst, 'reload schema';
