-- Aktuální planogram EV 79 / FAS 1050 / Ostrava - ViaPharma.
-- Zdroj: Planogram [79] FAS 1050-2026-07-30.xlsx.
-- TID 604313; expirace se přebírají pouze tam, kde jsou uvedené ve zdroji.
-- Současně opravuje historicky chybné umístění EV 79 z Podolí u Brna do Ostravy.

begin;

do $$
begin
  if not exists (
    select 1
    from public.machines
    where id = 59
      and evidence_number = 79
      and qr_token = 'vendsoft-79'
      and location_id in (50, 54)
      and machine_type = 'Snack'
  ) then
    raise exception 'EV 79 / Ostrava - ViaPharma nebyl nalezen na očekávaném DB záznamu.';
  end if;

  if not exists (
    select 1
    from public.locations
    where id = 50
      and name = 'ViaPharma'
      and city = 'Ostrava'
      and active = true
  ) then
    raise exception 'Aktivní lokalita ViaPharma Ostrava (ID 50) nebyla nalezena.';
  end if;
end
$$;

update public.machines
set
  location_id = 50,
  name = 'FAS 1050',
  machine_type = 'Snack',
  sales_tracking_mode = 'telemetry',
  note = 'Planogram 2026-07-30; EV 79; Ostrava - ViaPharma; TID 604313.',
  updated_at = now()
where id = 59;

insert into public.machine_external_links (
  machine_id, provider, external_machine_id, telemetry_enabled, note
)
values
  (59, 'IMA', '604313', true, 'TID 604313 pro EV 79 / FAS 1050 / Ostrava - ViaPharma.'),
  (59, 'GP',  '604313', true, 'TID 604313 pro EV 79 / FAS 1050 / Ostrava - ViaPharma.')
on conflict (provider, external_machine_id) do update
set
  machine_id = excluded.machine_id,
  telemetry_enabled = true,
  note = excluded.note,
  updated_at = now();

update public.machine_planogram_slots
set active = false, updated_at = now()
where machine_id = 59;

insert into public.machine_planogram_slots (
  machine_id, slot_code, product_name, product_sku,
  price_czk, current_units, last_units, capacity_units,
  dex_price_czk, desired_units, target_units, expiry_date, telemetry_key,
  sort_order, active, product_family, product_variant,
  planned_product_name, planned_product_sku, planned_price_czk,
  substitution_policy, allowed_substitutes, operator_instruction, note
)
select
  59,
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
  'Planogram EV 79 / Ostrava - ViaPharma / TID 604313 aktualizován ze souboru 2026-07-30.'
from (values
  ('11', 27::numeric,  3,  3,  5, 27::numeric, 2, '39',   0, 'Haribo', 'Goldbären', 'Haribo Bonbóny goldbären želé medvídci 100g', 'exact', null, null, null::date),
  ('13', 20::numeric,  8,  8,  8, 20::numeric, 0, '42',   1, '7days', 'Lískový oříšek', '7days Croissant lískový oříšek 60g', 'exact', null, null, null::date),
  ('15', 19::numeric,  7,  7,  7, 19::numeric, 0, '211',  2, 'Nový věk', 'Hořko-kakaová poleva', 'Nový věk Chlebíčky rýžové hořko-kakaová poleva 60g', 'exact', null, null, null::date),
  ('17', 28::numeric,  7,  7,  7, 28::numeric, 0, '20',   3, 'Dupetky', 'Hořčice, med a cibulka', 'Dupetky Snack pečený hořčice+med+cibulka 70g', 'exact', null, null, null::date),
  ('19', 14::numeric,  5,  5,  5, 14::numeric, 0, '162',  4, 'Ovesná svačinka', 'Brusnice', 'Ovesná svačinka Sušenka s brusnicemi 36g', 'exact', null, null, null::date),
  ('20', 25::numeric,  5,  5,  5, 25::numeric, 0, '261',  5, 'Corny Big', 'Banán', 'Corny Big Tyčinka banány v mléčné čokoládě 50g', 'exact', null, null, null::date),
  ('21', 26::numeric, 10, 10, 10, 26::numeric, 0, '25',   6, 'Twix', null, 'Twix Tyčinka 50g', 'exact', null, null, null::date),
  ('22', 24::numeric, 10, 10, 10, 24::numeric, 0, '27',   7, 'Kit Kat', '4 Fingers', 'Kit Kat 4 Fingers Tyčinka 41,5g', 'exact', null, null, null::date),
  ('23', 11::numeric,  9, 10, 10, 11::numeric, 1, '165',  8, 'Knoppers', null, 'Knoppers Oplatka 25g', 'exact', null, null, null::date),
  ('24', 14::numeric,  8,  9,  9, 14::numeric, 1, '254',  9, 'Dr.Ensa', 'Kukuřice BBQ', 'Dr.Ensa Kukuřice pražená BBQ 60g', 'exact', null, null, null::date),
  ('25', 24::numeric,  9,  9,  9, 24::numeric, 0, '31',  10, 'Miňonky', 'Oříškové', 'Miňonky Oplatky oříškové 50g', 'exact', null, null, null::date),
  ('26', 30::numeric,  7,  7,  7, 30::numeric, 0, '26',  11, '3Bit', 'Různé druhy', '3Bit Tyčinka různé druhy', 'exact', null, null, null::date),
  ('27', 30::numeric,  7,  7,  7, 30::numeric, 0, '279', 12, 'JoJo', 'Arašídky', 'JoJo Arašídky v čokoládě', 'exact', null, null, null::date),
  ('28', 19::numeric,  6,  7,  7, 19::numeric, 1, '38',  13, 'Havlík', 'Originál', 'Havlík Tyčinky originál 90g', 'exact', null, null, null::date),
  ('29', 21::numeric,  7,  7,  7, 21::numeric, 0, '144', 14, 'Yoohoo!', 'Kakao+lískový oříšek', 'Yoohoo! Vafle kakao+lískový oříšek 50', 'exact', null, null, null::date),
  ('30', 14::numeric,  8, 10, 10, 14::numeric, 2, '30',  15, 'Romanca', null, 'Romanca Oplatky', 'exact', null, null, null::date),
  ('31', 26::numeric, 15, 15, 15, 26::numeric, 0, '36',  16, 'Mila', null, 'Mila Oplatky 50g', 'exact', null, null, null::date),
  ('32', 20::numeric,  9, 10, 10, 20::numeric, 1, '35',  17, 'Sedita Horalky', 'Arašídové', 'Sedita Horalky Oplatky arašídové 50g', 'exact', null, null, null::date),
  ('33', 11::numeric,  9, 10, 10, 11::numeric, 1, '33',  18, 'Attack', 'Lískooříšková', 'Attack Oplatka lískooříšková 30g', 'exact', null, null, null::date),
  ('34', 26::numeric,  6,  7, 10, 26::numeric, 4, '24',  19, 'Snickers', null, 'Snickers Tyčinka čokoládová 50g', 'exact', null, null, null::date),
  ('35', 30::numeric,  7, 10, 10, 30::numeric, 3, '28',  20, 'Kinder Bueno', null, 'Kinder Bueno Oplatky 43g', 'exact', null, null, null::date),
  ('36', 25::numeric,  9, 10, 10, 25::numeric, 1, '40',  21, 'Margot', null, 'Margot Tyčinka 80g', 'exact', null, null, null::date),
  ('37',  8::numeric,  5,  6, 10,  8::numeric, 5, '208', 22, 'Alaska', 'Různé druhy', 'Alaska kukuřičné trubičky plněné krémem 18g různé druhy', 'exact', null, null, null::date),
  ('38', 10::numeric,  8, 10, 10, 10::numeric, 2, '143', 23, 'Today Donut', 'Kakaová náplň', 'Today Donut Dezert s kakaovou náplní v polevě 50g', 'exact', null, null, null::date),
  ('39', 13::numeric, 10, 10, 10, 13::numeric, 0, '142', 24, 'Racio Free Style', 'Rajče a bazalka', 'Racio Free Style Chlebíčky rajče a bazalka 25g', 'exact', null, null, null::date),
  ('40', 35::numeric,  6,  6,  6, 35::numeric, 0, '79',  25, 'ATM', 'Belgická', 'ATM - Belgická bageta', 'exact', null, 'Zkontroluj expiraci zásoby v automatu; neprodejné kusy odepiš.', '2026-08-06'::date),
  ('41', 35::numeric,  5,  6,  6, 35::numeric, 1, '155', 26, 'ATM', 'Debrecínská', 'ATM Debrecínská bageta', 'exact', null, 'Zkontroluj expiraci zásoby v automatu; neprodejné kusy odepiš.', '2026-08-06'::date),
  ('42', 35::numeric,  5,  6,  6, 35::numeric, 1, '278', 27, 'ATM', 'Masové koule', 'ATM Bageta masové koule', 'exact', null, 'Zkontroluj expiraci zásoby v automatu; neprodejné kusy odepiš.', '2026-08-06'::date),
  ('43', 35::numeric,  5,  6,  6, 35::numeric, 1, '154', 28, 'ATM', 'Trhané vepřové', 'ATM Bageta trhané vepřové', 'exact', null, 'Zkontroluj expiraci zásoby v automatu; neprodejné kusy odepiš.', '2026-08-06'::date),
  ('44', 35::numeric,  6,  6,  6, 35::numeric, 0, '17',  29, 'ATM', 'Kuřecí stripsy', 'ATM - Kuřecí stripsy', 'exact', null, null, null::date),
  ('45', 25::numeric,  2,  3,  6, 25::numeric, 4, '210', 30, 'Doritos', 'Nachos cheese', 'Doritos Tortillas Chipsy nachos cheese 44g', 'exact', null, null, null::date),
  ('46', 29::numeric,  5,  5,  5, 29::numeric, 0, '277', 31, 'DrWitt', 'Mango+citron', 'DrWitt min. voda 0,55l různé druhy', 'approved_list', 'DrWitt citrus SKU 276; DrWitt liči+hruška SKU 200', 'Přednostně mango+citron SKU 277; lze použít citrus SKU 276 nebo liči+hruška SKU 200.', null::date),
  ('47', 35::numeric,  5,  5,  6, 35::numeric, 1, '16',  32, 'ATM', 'Chlebíčkový Labužník', 'ATM Chlebíčkový Labužník', 'exact', null, null, null::date),
  ('48', 35::numeric,  4,  6,  6, 35::numeric, 2, '17',  33, 'ATM', 'Kuřecí stripsy', 'ATM - Kuřecí stripsy', 'exact', null, 'Zkontroluj expiraci zásoby v automatu; neprodejné kusy odepiš.', '2026-08-06'::date),
  ('49', 35::numeric,  5,  6,  6, 35::numeric, 1, '155', 34, 'ATM', 'Debrecínská', 'ATM Debrecínská bageta', 'exact', null, 'Zkontroluj expiraci zásoby v automatu; neprodejné kusy odepiš.', '2026-08-06'::date),
  ('50', 24::numeric,  6,  6,  6, 24::numeric, 0, '209', 35, 'ZON', 'Různé druhy', 'ZON 500ml PET různé druhy', 'exact', null, null, null::date),
  ('51', 32::numeric,  5,  6,  6, 32::numeric, 1, '71',  36, 'Pepsi', 'Cola', 'Pepsi Cola 500ml PET', 'exact', null, null, null::date),
  ('52', 30::numeric,  6,  6,  6, 30::numeric, 0, '67',  37, 'Nestea', 'Peach', 'Nestea 0,5l různé druhy', 'approved_list', 'Nestea Lemon 0,5l (SKU 275)', 'Přednostně Peach SKU 67; lze použít Lemon SKU 275.', null::date),
  ('53', 32::numeric,  3,  5,  5, 32::numeric, 2, '70',  38, 'Kofola', 'Original', 'Kofola Original 500ml PET', 'exact', null, null, null::date),
  ('54', 29::numeric,  5,  6,  6, 29::numeric, 1, '207', 39, 'Bad Brambacher', 'Malina', 'Bad Brambacher 0,5l různé druhy', 'exact', null, null, null::date),
  ('55', 29::numeric,  5,  6,  6, 29::numeric, 1, '156', 40, 'Ice Coffee', null, 'Ice Coffee Ledová káva 350ml', 'exact', null, null, null::date),
  ('56', 49::numeric,  5,  6,  6, 39::numeric, 1, '2',   41, 'Big Shock!', 'Exotic', 'Big Shock! Energetický nápoj Exotic 500ml plech', 'exact', null, 'Cena v automatu 49 Kč; DEX cena ve zdroji 39 Kč.', null::date),
  ('57', 28::numeric,  4,  6,  6, 28::numeric, 2, '187', 42, 'Staropramen Cool', 'Citron', 'Staropramen Cool citron nealkoholický nápoj z piva 500ml plech', 'exact', null, null, null::date),
  ('58', 20::numeric,  6,  6,  6, 20::numeric, 0, '13',  43, 'Hanácká Kyselka', 'Citron jemně perlivá', 'Hanácká Kyselka Minerální voda citron jemně perlivá 500ml PET', 'exact', null, null, null::date),
  ('59', 32::numeric,  4,  6,  6, 32::numeric, 2, '71',  44, 'Pepsi', 'Cola', 'Pepsi Cola 500ml PET', 'exact', null, null, null::date),
  ('60', 48::numeric,  6,  6,  6, 48::numeric, 0, '190', 45, 'Red Bull', null, 'Red Bull 0,25l', 'exact', null, null, null::date),
  ('61', 19::numeric,  4,  5,  6, 19::numeric, 2, '163', 46, 'QXE', null, 'QXE Energetický nápoj 250ml plech', 'exact', null, null, null::date),
  ('62', 19::numeric,  5,  6,  6, 19::numeric, 1, '163', 47, 'QXE', null, 'QXE Energetický nápoj 250ml plech', 'exact', null, null, null::date),
  ('63', 27::numeric,  6,  6,  6, 27::numeric, 0, '4',   48, 'Hell', 'Classic', 'Hell Energetický nápoj classic 250ml plech', 'exact', null, null, null::date),
  ('64', 48::numeric,  6,  6,  6, 48::numeric, 0, '190', 49, 'Red Bull', null, 'Red Bull 0,25l', 'exact', null, null, null::date),
  ('65', 25::numeric,  5,  6,  6, 25::numeric, 1, '6',   50, 'Relax', 'Liči', 'Relax Limonáda liči 330ml plech', 'exact', null, null, null::date),
  ('66', 15::numeric,  3,  6,  6, 15::numeric, 3, '41',  51, 'Capri-Sun', 'Multivitamin', 'Capri-Sun Multivitamin ovocný nápoj 200ml', 'exact', null, null, null::date),
  ('67', 25::numeric,  6,  6,  6, 25::numeric, 0, '259', 52, 'Hello', 'Malina', 'Hello Perlivé malinový perlivý nápoj 330ml plech', 'exact', null, null, null::date),
  ('68', 23::numeric,  6,  6,  6, 23::numeric, 0, '157', 53, 'Pepsi', 'Cola', 'Pepsi 0,33l plech', 'exact', null, null, null::date),
  ('69', 19::numeric,  5,  6,  6, 19::numeric, 1, '163', 54, 'QXE', null, 'QXE Energetický nápoj 250ml plech', 'exact', null, null, null::date)
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
  where machine_id = 59 and active = true;

  if v_count <> 55 then
    raise exception 'EV 79: očekáváno 55 aktivních pozic, nalezeno %.', v_count;
  end if;

  if v_desired <> 53 then
    raise exception 'EV 79: očekáváno celkem 53 ks k doplnění, nalezeno %.', v_desired;
  end if;

  if v_expiries <> 6 then
    raise exception 'EV 79: očekáváno 6 evidovaných expirací, nalezeno %.', v_expiries;
  end if;

  select count(*) into v_links
  from public.machine_external_links
  where machine_id = 59
    and external_machine_id = '604313'
    and telemetry_enabled = true;

  if v_links <> 2 then
    raise exception 'EV 79: očekávány 2 aktivní vazby TID 604313, nalezeno %.', v_links;
  end if;

  select count(*) into v_bad_capacity
  from public.machine_planogram_slots
  where machine_id = 59
    and active = true
    and current_units > capacity_units;

  if v_bad_capacity <> 0 then
    raise exception 'EV 79: nalezeny pozice nad kapacitou: %.', v_bad_capacity;
  end if;

  select location_id into v_location_id
  from public.machines
  where id = 59;

  if v_location_id <> 50 then
    raise exception 'EV 79: automat není připojen k lokaci ViaPharma Ostrava (ID 50), ale k %.', v_location_id;
  end if;
end
$$;

commit;
notify pgrst, 'reload schema';
