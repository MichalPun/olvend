-- Aktuální planogram EV 99 / FAS 1050 / Sportisimo.
-- Zdroj: Planogram [99] FAS 1050-2026-07-30.xlsx.
-- TID 582172; zdroj neobsahuje žádné údaje o expiraci.

begin;

do $$
begin
  if not exists (
    select 1
    from public.machines
    where id = 79
      and evidence_number = 99
      and qr_token = 'vendsoft-99'
      and location_id = 58
      and machine_type = 'Snack'
  ) then
    raise exception 'EV 99 / FAS 1050 / Sportisimo nebyl nalezen na očekávaném DB záznamu.';
  end if;

  if not exists (
    select 1
    from public.locations
    where id = 58
      and name = 'Sportisimo'
      and city = 'Slezská Ostrava-Hrušov'
      and active = true
  ) then
    raise exception 'Aktivní lokalita Sportisimo (ID 58) nebyla nalezena.';
  end if;
end
$$;

update public.machines
set
  name = 'FAS 1050',
  machine_type = 'Snack',
  sales_tracking_mode = 'telemetry',
  note = 'Planogram 2026-07-30; EV 99; Sportisimo, Slezská Ostrava-Hrušov. TID 582172.',
  updated_at = now()
where id = 79;

insert into public.machine_external_links (
  machine_id, provider, external_machine_id, telemetry_enabled, note
)
values
  (79, 'IMA', '582172', true, 'TID 582172 pro EV 99 / FAS 1050 / Sportisimo.'),
  (79, 'GP',  '582172', true, 'TID 582172 pro EV 99 / FAS 1050 / Sportisimo.')
on conflict (provider, external_machine_id) do update
set
  machine_id = excluded.machine_id,
  telemetry_enabled = true,
  note = excluded.note,
  updated_at = now();

update public.machine_planogram_slots
set active = false, updated_at = now()
where machine_id = 79;

insert into public.machine_planogram_slots (
  machine_id, slot_code, product_name, product_sku,
  price_czk, current_units, last_units, capacity_units,
  dex_price_czk, desired_units, target_units, expiry_date, telemetry_key,
  sort_order, active, product_family, product_variant,
  planned_product_name, planned_product_sku, planned_price_czk,
  substitution_policy, allowed_substitutes, operator_instruction, note
)
select
  79,
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
  null::date,
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
  'Planogram EV 99 / Sportisimo / TID 582172 aktualizován ze souboru 2026-07-30.'
from (values
  ('11', 10::numeric,  7, 10, 10, 10::numeric, 3, '143',  0, 'Today Donut', 'Kakaová náplň', 'Today Donut Dezert s kakaovou náplní v polevě 50g', 'exact', null, null),
  ('13', 10::numeric, 10, 10, 10, 26::numeric, 0, '39',   1, 'Haribo', 'Goldbären', 'Haribo Bonbóny goldbären želé medvídci 100g', 'exact', null, 'Cena v automatu 10 Kč; DEX cena ve zdroji 26 Kč.'),
  ('15', 16::numeric,  7,  7,  7, 16::numeric, 0, '162',  2, 'Ovesná svačinka', 'Brusnice', 'Ovesná svačinka Sušenka s brusnicemi 36g', 'exact', null, null),
  ('17', 16::numeric,  3,  3,  4, 25::numeric, 1, '210',  3, 'Doritos', 'Nachos cheese', 'Doritos Tortillas Chipsy nachos cheese 44g', 'exact', null, 'Cena v automatu 16 Kč; DEX cena ve zdroji 25 Kč.'),
  ('19', 27::numeric,  6,  6,  6, 27::numeric, 0, '20',   4, 'Dupetky', 'Hořčice, med a cibulka', 'Dupetky Snack pečený hořčice+med+cibulka 70g', 'exact', null, null),
  ('20', 18::numeric,  1,  7,  7, 18::numeric, 6, '38',   5, 'Havlík', 'Originál', 'Havlík Tyčinky originál 90g', 'exact', null, null),
  ('21', 14::numeric,  1, 10, 10, 14::numeric, 9, '254',  6, 'Dr.Ensa', 'Kukuřice BBQ', 'Dr.Ensa Kukuřice pražená solená s příchutí barbecue 60g', 'exact', null, null),
  ('22', 22::numeric,  6,  9,  9, 22::numeric, 3, '27',   7, 'Kit Kat', '4 Fingers', 'Kit Kat 4 Fingers Tyčinka 41,5g', 'exact', null, null),
  ('23', 26::numeric,  7,  8, 10, 26::numeric, 3, '25',   8, 'Twix', null, 'Twix Tyčinka 50g', 'exact', null, null),
  ('24', 11::numeric,  7, 10, 10, 11::numeric, 3, '165',  9, 'Knoppers', null, 'Knoppers Oplatka 25g', 'exact', null, null),
  ('25', 23::numeric, 10, 10, 10, 23::numeric, 0, '31',  10, 'Miňonky', 'Oříškové', 'Miňonky Oplatky oříškové 50g', 'exact', null, null),
  ('26', 28::numeric,  3,  5,  7, 28::numeric, 4, '26',  11, '3Bit', 'Různé druhy', '3Bit tyčinka různé druhy', 'exact', null, null),
  ('27', 21::numeric,  5,  7,  7, 21::numeric, 2, '261', 12, 'Corny Big', 'Banán', 'Corny Big Tyčinka banány v mléčné čokoládě 50g', 'exact', null, null),
  ('28', 18::numeric,  2,  7,  7, 18::numeric, 5, '280', 13, 'Veneto', 'Vanilka a kakao', 'Veneto Oplatka s vanilkovou a kakaovou náplní 65g', 'exact', null, null),
  ('29', 22::numeric,  9,  9,  9, 22::numeric, 0, '211', 14, 'Nový věk', 'Hořko-kakaová poleva', 'Nový věk Chlebíčky rýžové hořko-kakaová poleva 60g', 'exact', null, null),
  ('30', 26::numeric, 11, 11, 11, 26::numeric, 0, '36',  15, 'Mila', null, 'Mila Oplatky 50g', 'exact', null, null),
  ('31', 29::numeric, 15, 15, 15, 29::numeric, 0, '28',  16, 'Kinder Bueno', null, 'Kinder Bueno Oplatky 43g', 'exact', null, null),
  ('32', 20::numeric, 13, 13, 13, 20::numeric, 0, '35',  17, 'Sedita Horalky', 'Arašídové', 'Sedita Horalky Oplatky arašídové 50g', 'exact', null, null),
  ('33', 28::numeric, 14, 14, 14, 11::numeric, 0, '33',  18, 'Attack', 'Lískooříšková', 'Attack Oplatka lískooříšková 30g', 'exact', null, 'Cena v automatu 28 Kč; DEX cena ve zdroji 11 Kč.'),
  ('34', 10::numeric, 13, 13, 13, 14::numeric, 0, '142', 19, 'Racio Free Style', 'Rajče a bazalka', 'Racio Free Style Chlebíčky rajče a bazalka 25g', 'exact', null, 'Cena v automatu 10 Kč; DEX cena ve zdroji 14 Kč.'),
  ('35', 26::numeric,  6,  7, 10, 26::numeric, 4, '24',  20, 'Snickers', null, 'Snickers Tyčinka čokoládová 50g', 'exact', null, null),
  ('36', 14::numeric,  9, 11, 11, 10::numeric, 2, '143', 21, 'Today Donut', 'Kakaová náplň', 'Today Donut Dezert s kakaovou náplní v polevě 50g', 'exact', null, 'Cena v automatu 14 Kč; DEX cena ve zdroji 10 Kč.'),
  ('37', 14::numeric, 10, 11, 11, 14::numeric, 1, '30',  22, 'Romanca', 'Kakaová náplň', 'Romanca Sušenka s kakaovou náplní 40g', 'exact', null, null),
  ('38',  8::numeric,  5, 10, 11,  8::numeric, 6, '208', 23, 'Alaska', 'Různé druhy', 'Alaska kukuřičné trubičky plněné krémem 18g různé druhy', 'exact', null, null),
  ('39', 24::numeric, 10, 11, 11, 24::numeric, 1, '40',  24, 'Margot', null, 'Margot Tyčinka 80g', 'exact', null, null),
  ('40', 29::numeric,  6,  6,  6, 29::numeric, 0, '277', 25, 'DrWitt', 'Mango+citron', 'DrWitt min. voda 0,55l různé druhy', 'approved_list', 'DrWitt citrus SKU 276; DrWitt liči+hruška SKU 200', 'Přednostně mango+citron SKU 277; lze použít citrus SKU 276 nebo liči+hruška SKU 200.'),
  ('41', 30::numeric,  5,  6,  6, 30::numeric, 1, '71',  26, 'Pepsi', 'Cola', 'Pepsi Cola 500ml PET', 'exact', null, null),
  ('42', 30::numeric,  6,  6,  6, 30::numeric, 0, '71',  27, 'Pepsi', 'Cola', 'Pepsi Cola 500ml PET', 'exact', null, null),
  ('43', 27::numeric,  5,  6,  6, 24::numeric, 1, '209', 28, 'ZON', 'Různé druhy', 'ZON 500ml PET různé druhy', 'exact', null, 'Cena v automatu 27 Kč; DEX cena ve zdroji 24 Kč.'),
  ('44', 27::numeric,  6,  6,  6, 27::numeric, 0, '209', 29, 'ZON', 'Různé druhy', 'ZON 500ml PET různé druhy', 'exact', null, null),
  ('45', 18::numeric,  5,  6,  6, 18::numeric, 1, '13',  30, 'Hanácká Kyselka', 'Citron jemně perlivá', 'Hanácká Kyselka Minerální voda citron jemně perlivá 500ml PET', 'exact', null, null),
  ('46', 18::numeric,  6,  6,  6, 18::numeric, 0, '13',  31, 'Hanácká Kyselka', 'Citron jemně perlivá', 'Hanácká Kyselka Minerální voda citron jemně perlivá 500ml PET', 'exact', null, null),
  ('47', 28::numeric,  6,  6,  6, 28::numeric, 0, '207', 32, 'Bad Brambacher', 'Malina', 'Bad Brambacher 0,5l různé druhy', 'exact', null, null),
  ('48', 28::numeric,  5,  6,  6, 28::numeric, 1, '207', 33, 'Bad Brambacher', 'Malina', 'Bad Brambacher 0,5l různé druhy', 'exact', null, null),
  ('49', 29::numeric,  6,  6,  6, 29::numeric, 0, '277', 34, 'DrWitt', 'Mango+citron', 'DrWitt min. voda 0,55l různé druhy', 'approved_list', 'DrWitt citrus SKU 276; DrWitt liči+hruška SKU 200', 'Přednostně mango+citron SKU 277; lze použít citrus SKU 276 nebo liči+hruška SKU 200.'),
  ('50', 29::numeric,  6,  6,  6, 29::numeric, 0, '70',  35, 'Kofola', 'Original', 'Kofola Original 500ml PET', 'exact', null, null),
  ('51', 30::numeric,  6,  6,  6, 30::numeric, 0, '71',  36, 'Pepsi', 'Cola', 'Pepsi Cola 500ml PET', 'exact', null, null),
  ('52', 30::numeric,  5,  6,  6, 30::numeric, 1, '71',  37, 'Pepsi', 'Cola', 'Pepsi Cola 500ml PET', 'exact', null, null),
  ('53', 25::numeric,  6,  6,  6, 25::numeric, 0, '67',  38, 'Nestea', 'Peach', 'Nestea 0,5l různé druhy', 'approved_list', 'Nestea Lemon 0,5l (SKU 275)', 'Přednostně Peach SKU 67; lze použít Lemon SKU 275.'),
  ('54', 25::numeric,  6,  6,  6, 25::numeric, 0, '67',  39, 'Nestea', 'Peach', 'Nestea 0,5l různé druhy', 'approved_list', 'Nestea Lemon 0,5l (SKU 275)', 'Přednostně Peach SKU 67; lze použít Lemon SKU 275.'),
  ('55', 25::numeric,  6,  6,  6, 25::numeric, 0, '67',  40, 'Nestea', 'Peach', 'Nestea 0,5l různé druhy', 'approved_list', 'Nestea Lemon 0,5l (SKU 275)', 'Přednostně Peach SKU 67; lze použít Lemon SKU 275.'),
  ('56', 13::numeric,  0,  6,  6, 13::numeric, 6, '41',  41, 'Capri-Sun', 'Multivitamin', 'Capri-Sun Multivitamin ovocný nápoj 200ml', 'exact', null, null),
  ('57', 13::numeric,  3,  6,  6, 13::numeric, 3, '41',  42, 'Capri-Sun', 'Multivitamin', 'Capri-Sun Multivitamin ovocný nápoj 200ml', 'exact', null, null),
  ('58', 29::numeric,  3,  6,  6, 29::numeric, 3, '70',  43, 'Kofola', 'Original', 'Kofola Original 500ml PET', 'exact', null, null),
  ('59', 29::numeric,  5,  6,  6, 29::numeric, 1, '70',  44, 'Kofola', 'Original', 'Kofola Original 500ml PET', 'exact', null, null),
  ('60', 24::numeric,  3,  6,  6, 23::numeric, 3, '157', 45, 'Pepsi', 'Cola', 'Pepsi 0,33l plech', 'exact', null, 'Cena v automatu 24 Kč; DEX cena ve zdroji 23 Kč.'),
  ('61', 18::numeric,  6,  6,  6, 18::numeric, 0, '163', 46, 'QXE', null, 'QXE Energetický nápoj 250ml plech', 'exact', null, null),
  ('62', 18::numeric,  5,  6,  6, 18::numeric, 1, '163', 47, 'QXE', null, 'QXE Energetický nápoj 250ml plech', 'exact', null, null),
  ('63', 18::numeric,  2,  6,  6, 18::numeric, 4, '163', 48, 'QXE', null, 'QXE Energetický nápoj 250ml plech', 'exact', null, null),
  ('64', 27::numeric,  5,  6,  6, 27::numeric, 1, '4',   49, 'Hell', 'Classic', 'Hell Energetický nápoj classic 250ml plech', 'exact', null, null),
  ('65', 46::numeric,  5,  6,  6, 46::numeric, 1, '190', 50, 'Red Bull', null, 'Red Bull 0,25l', 'exact', null, null),
  ('66', 39::numeric,  4,  5,  5, 39::numeric, 1, '2',   51, 'Big Shock!', 'Exotic', 'Big Shock! Energetický nápoj Exotic 500ml plech', 'exact', null, null),
  ('67', 39::numeric,  5,  5,  5, 39::numeric, 0, '2',   52, 'Big Shock!', 'Exotic', 'Big Shock! Energetický nápoj Exotic 500ml plech', 'exact', null, null),
  ('68', 39::numeric,  5,  5,  5, 25::numeric, 0, '259', 53, 'Hello', 'Malina', 'Hello Perlivé malinový perlivý nápoj 330ml plech', 'exact', null, 'Cena v automatu 39 Kč; DEX cena ve zdroji 25 Kč.'),
  ('69', 23::numeric,  5,  6,  6, 23::numeric, 1, '157', 54, 'Pepsi', 'Cola', 'Pepsi 0,33l plech', 'exact', null, null)
) as d(
  slot_code, price_czk, current_units, last_units, capacity_units,
  dex_price_czk, desired_units, product_sku, sort_order,
  product_family, product_variant, planned_product_name,
  substitution_policy, allowed_substitutes, operator_instruction
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
  expiry_date = null,
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
  where machine_id = 79 and active = true;

  if v_count <> 55 then
    raise exception 'EV 99: očekáváno 55 aktivních pozic, nalezeno %.', v_count;
  end if;

  if v_desired <> 83 then
    raise exception 'EV 99: očekáváno celkem 83 ks k doplnění, nalezeno %.', v_desired;
  end if;

  if v_expiries <> 0 then
    raise exception 'EV 99: zdroj neobsahuje expirace, ale nalezeno jich bylo %.', v_expiries;
  end if;

  select count(*) into v_links
  from public.machine_external_links
  where machine_id = 79
    and external_machine_id = '582172'
    and telemetry_enabled = true;

  if v_links <> 2 then
    raise exception 'EV 99: očekávány 2 aktivní vazby TID 582172, nalezeno %.', v_links;
  end if;

  select count(*) into v_bad_capacity
  from public.machine_planogram_slots
  where machine_id = 79
    and active = true
    and current_units > capacity_units;

  if v_bad_capacity <> 0 then
    raise exception 'EV 99: nalezeny pozice nad kapacitou: %.', v_bad_capacity;
  end if;

  select location_id into v_location_id
  from public.machines
  where id = 79;

  if v_location_id <> 58 then
    raise exception 'EV 99: automat není připojen k lokalitě Sportisimo (ID 58), ale k %.', v_location_id;
  end if;
end
$$;

commit;
notify pgrst, 'reload schema';
