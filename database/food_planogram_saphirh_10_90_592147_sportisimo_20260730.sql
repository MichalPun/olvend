-- Aktuální planogram EV 90 / Saphirh 10 / Sportisimo.
-- Zdroj: Planogram [90] Saphirh 10-2026-07-30.xlsx.
-- TID 592147; expirace se přebírají pouze tam, kde jsou uvedené ve zdroji.

begin;

do $$
begin
  if not exists (
    select 1
    from public.machines
    where id = 70
      and evidence_number = 90
      and qr_token = 'vendsoft-90'
      and location_id = 58
      and machine_type = 'Snack'
  ) then
    raise exception 'EV 90 / Saphirh 10 / Sportisimo nebyl nalezen na očekávaném DB záznamu.';
  end if;
end
$$;

update public.machines
set
  name = 'Saphirh 10',
  machine_type = 'Snack',
  sales_tracking_mode = 'telemetry',
  note = 'Planogram 2026-07-30; EV 90; Sportisimo, Slezská Ostrava-Hrušov. TID 592147.',
  updated_at = now()
where id = 70;

insert into public.machine_external_links (
  machine_id, provider, external_machine_id, telemetry_enabled, note
)
values
  (70, 'IMA', '592147', true, 'TID 592147 pro EV 90 / Saphirh 10 / Sportisimo.'),
  (70, 'GP',  '592147', true, 'TID 592147 pro EV 90 / Saphirh 10 / Sportisimo.')
on conflict (provider, external_machine_id) do update
set
  machine_id = excluded.machine_id,
  telemetry_enabled = true,
  note = excluded.note,
  updated_at = now();

update public.machine_planogram_slots
set active = false, updated_at = now()
where machine_id = 70;

insert into public.machine_planogram_slots (
  machine_id, slot_code, product_name, product_sku,
  price_czk, current_units, last_units, capacity_units,
  dex_price_czk, desired_units, target_units, expiry_date, telemetry_key,
  sort_order, active, product_family, product_variant,
  planned_product_name, planned_product_sku, planned_price_czk,
  substitution_policy, allowed_substitutes, operator_instruction, note
)
select
  70,
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
  'Planogram EV 90 / Sportisimo / TID 592147 aktualizován ze souboru 2026-07-30.'
from (values
  ('11', 26::numeric,  5,  6,  7, 26::numeric, 2, '39',   0, 'Haribo', 'Goldbären', 'Haribo Bonbóny goldbären želé medvídci 100g', 'exact', null, null, null::date),
  ('13', 16::numeric,  5,  8,  8, 16::numeric, 3, '42',   1, '7days', 'Lískový oříšek', '7days Croissant lískový oříšek 60g', 'exact', null, null, null::date),
  ('15', 22::numeric,  2,  3,  7, 22::numeric, 5, '211',  2, 'Nový věk', 'Hořko-kakaová poleva', 'Nový věk Chlebíčky rýžové hořko-kakaová poleva 60g', 'exact', null, null, null::date),
  ('17', 25::numeric,  6,  8,  8, 25::numeric, 2, '210',  3, 'Doritos', 'Nachos cheese', 'Doritos Tortillas Chipsy nachos cheese 44g', 'exact', null, null, null::date),
  ('19', 14::numeric,  2,  3,  7, 14::numeric, 5, '142',  4, 'Racio Free Style', 'Rajče a bazalka', 'Racio Free Style Chlebíčky rajče a bazalka 25g', 'exact', null, null, null::date),
  ('21', 27::numeric, 10, 10, 10, 27::numeric, 0, '20',   5, 'Dupetky', 'Hořčice, med a cibulka', 'Dupetky Snack pečený hořčice+med+cibulka 70g', 'exact', null, null, null::date),
  ('23', 12::numeric,  7, 10, 10, 12::numeric, 3, '162',  6, 'Ovesná svačinka', 'Brusnice', 'Ovesná svačinka Sušenka s brusnicemi 36g', 'exact', null, null, null::date),
  ('25', 18::numeric,  9, 10, 10, 18::numeric, 1, '38',   7, 'Havlík', 'Originál', 'Havlík Tyčinky originál 90g', 'exact', null, null, null::date),
  ('27', 10::numeric,  5,  5,  5, 10::numeric, 0, '143',  8, 'Today Donut', 'Kakaová náplň', 'Today Donut Dezert s kakaovou náplní v polevě 50g', 'exact', null, null, null::date),
  ('29', 10::numeric,  5,  5,  5, 10::numeric, 0, '143',  9, 'Today Donut', 'Kakaová náplň', 'Today Donut Dezert s kakaovou náplní v polevě 50g', 'exact', null, null, null::date),
  ('30', 21::numeric,  6, 10, 11, 21::numeric, 5, '261', 10, 'Corny Big', 'Banán', 'Corny Big Tyčinka banány v mléčné čokoládě 50g', 'exact', null, null, null::date),
  ('31', 26::numeric, 14, 14, 14, 26::numeric, 0, '36',  11, 'Mila', null, 'Mila Oplatky 50g', 'exact', null, null, null::date),
  ('32', 20::numeric, 13, 15, 15, 20::numeric, 2, '35',  12, 'Sedita Horalky', 'Arašídové', 'Sedita Horalky Oplatky arašídové 50g', 'exact', null, null, null::date),
  ('33', 11::numeric, 14, 14, 14, 11::numeric, 0, '33',  13, 'Attack', 'Lískooříšková', 'Attack Oplatka lískooříšková 30g', 'exact', null, null, null::date),
  ('34', 26::numeric, 15, 15, 15, 26::numeric, 0, '24',  14, 'Snickers', null, 'Snickers Tyčinka čokoládová 50g', 'exact', null, null, null::date),
  ('35', 29::numeric,  7, 13, 13, 29::numeric, 6, '28',  15, 'Kinder Bueno', null, 'Kinder Bueno Oplatky 43g', 'exact', null, null, null::date),
  ('36', 24::numeric, 14, 14, 14, 24::numeric, 0, '40',  16, 'Margot', null, 'Margot Tyčinka 80g', 'exact', null, null, null::date),
  ('37',  8::numeric, 10, 13, 14,  8::numeric, 4, '208', 17, 'Alaska', 'Různé druhy', 'Alaska kukuřičné trubičky plněné krémem 18g různé druhy', 'exact', null, null, null::date),
  ('38', 11::numeric, 10, 14, 14, 11::numeric, 4, '165', 18, 'Knoppers', null, 'Knoppers Oplatka 25g', 'exact', null, null, null::date),
  ('39', 14::numeric,  9, 10, 12, 14::numeric, 3, '254', 19, 'Dr.Ensa', 'Kukuřice BBQ', 'Dr.Ensa Kukuřice pražená solená s příchutí barbecue 60g', 'exact', null, null, null::date),
  ('40', 30::numeric,  6,  6,  6, 30::numeric, 0, '279', 20, 'JoJo', 'Arašídy v cukru', 'Jojo Arašídky v cukru dražé 60g', 'exact', null, 'Zkontroluj expiraci zásoby v automatu; neprodejné kusy odepiš.', '2025-09-13'::date),
  ('41', 55::numeric,  3,  6,  6, 55::numeric, 3, '154', 21, 'ATM', 'Trhané vepřové', 'ATM Trhané Vepřové', 'exact', null, 'Zkontroluj expiraci zásoby v automatu; neprodejné kusy odepiš.', '2026-08-06'::date),
  ('42', 55::numeric,  6,  6,  6, 55::numeric, 0, '155', 22, 'ATM', 'Debrecínská', 'ATM Debrecínská bageta', 'exact', null, 'Zkontroluj expiraci zásoby v automatu; neprodejné kusy odepiš.', '2026-08-04'::date),
  ('43', 55::numeric,  5,  6,  6, 55::numeric, 1, '278', 23, 'ATM', 'Masové koule', 'ATM - Masové koule', 'exact', null, 'Zkontroluj expiraci zásoby v automatu; neprodejné kusy odepiš.', '2026-08-06'::date),
  ('44', 55::numeric,  4,  6,  6, 55::numeric, 2, '278', 24, 'ATM', 'Masové koule', 'ATM - Masové koule', 'exact', null, 'Zkontroluj expiraci zásoby v automatu; neprodejné kusy odepiš.', '2026-08-06'::date),
  ('45', 55::numeric,  4,  6,  6, 55::numeric, 2, '17',  25, 'ATM', 'Kuřecí stripsy', 'ATM - Kuřecí stripsy', 'exact', null, 'Zkontroluj expiraci zásoby v automatu; neprodejné kusy odepiš.', '2026-08-06'::date),
  ('46', 55::numeric,  5,  6,  6, 55::numeric, 1, '155', 26, 'ATM', 'Debrecínská', 'ATM Debrecínská bageta', 'exact', null, 'Zkontroluj expiraci zásoby v automatu; neprodejné kusy odepiš.', '2026-08-04'::date),
  ('47', 55::numeric,  6,  6,  6, 55::numeric, 0, '16',  27, 'ATM', 'Chlebíčkový Labužník', 'ATM - Chlebíčkový Labužník', 'exact', null, 'Zkontroluj expiraci zásoby v automatu; neprodejné kusy odepiš.', '2026-07-30'::date),
  ('48', 55::numeric,  4,  6,  6, 55::numeric, 2, '79',  28, 'ATM', 'Belgická', 'ATM - Belgická bageta', 'exact', null, 'Zkontroluj expiraci zásoby v automatu; neprodejné kusy odepiš.', '2026-08-06'::date),
  ('49', 20::numeric,  1,  6,  6, 20::numeric, 5, '144', 29, 'Yoohoo!', 'Kakao+lískový oříšek', 'Yoohoo! Vafle kakao+lískový oříšek 50', 'exact', null, null, null::date),
  ('50', 25::numeric,  6,  6,  6, 25::numeric, 0, '259', 30, 'Hello', 'Malina', 'Hello Perlivé malinový perlivý nápoj 330ml plech', 'exact', null, null, null::date),
  ('51', 18::numeric,  3,  6,  6, 18::numeric, 3, '163', 31, 'QXE', null, 'QXE Energetický nápoj 250ml plech', 'exact', null, null, null::date),
  ('52', 18::numeric,  4,  6,  6, 18::numeric, 2, '163', 32, 'QXE', null, 'QXE Energetický nápoj 250ml plech', 'exact', null, null, null::date),
  ('53', 18::numeric,  4,  6,  6, 18::numeric, 2, '163', 33, 'QXE', null, 'QXE Energetický nápoj 250ml plech', 'exact', null, null, null::date),
  ('54', 25::numeric,  6,  6,  6, 25::numeric, 0, '259', 34, 'Hello', 'Malina', 'Hello Perlivé malinový perlivý nápoj 330ml plech', 'exact', null, null, null::date),
  ('55', 23::numeric,  3,  6,  6, 23::numeric, 3, '6',   35, 'Relax', 'Liči', 'Relax Limonáda liči 330ml plech', 'exact', null, null, null::date),
  ('56', 27::numeric,  5,  6,  6, 27::numeric, 1, '4',   36, 'Hell', 'Classic', 'Hell Energetický nápoj classic 250ml plech', 'exact', null, null, null::date),
  ('57', 27::numeric,  2,  6,  6, 27::numeric, 4, '4',   37, 'Hell', 'Classic', 'Hell Energetický nápoj classic 250ml plech', 'exact', null, null, null::date),
  ('58', 28::numeric,  2,  5,  6, 28::numeric, 4, '156', 38, 'Ice Coffee', null, 'Ice Coffee Ledová káva 350ml', 'exact', null, null, null::date),
  ('59', 28::numeric,  4,  6,  6, 28::numeric, 2, '156', 39, 'Ice Coffee', null, 'Ice Coffee Ledová káva 350ml', 'exact', null, null, null::date),
  ('60', 13::numeric,  6,  6,  6, 13::numeric, 0, '41',  40, 'Capri-Sun', 'Multivitamin', 'Capri-Sun Multivitamin ovocný nápoj 200ml', 'exact', null, null, null::date),
  ('61', 24::numeric,  6,  6,  6, 24::numeric, 0, '209', 41, 'ZON', 'Různé druhy', 'ZON 500ml PET různé druhy', 'exact', null, null, null::date),
  ('62', 24::numeric,  6,  6,  6, 24::numeric, 0, '209', 42, 'ZON', 'Různé druhy', 'ZON 500ml PET různé druhy', 'exact', null, null, null::date),
  ('63', 39::numeric,  5,  5,  5, 39::numeric, 0, '2',   43, 'Big Shock!', 'Exotic', 'Big Shock! Energetický nápoj Exotic 500ml plech', 'exact', null, null, null::date),
  ('64', 39::numeric,  5,  6,  5, 39::numeric, 0, '2',   44, 'Big Shock!', 'Exotic', 'Big Shock! Energetický nápoj Exotic 500ml plech', 'exact', null, null, null::date),
  ('65', 28::numeric,  6,  6,  6, 28::numeric, 0, '207', 45, 'Bad Brambacher', 'Malina', 'Bad Brambacher 0,5l různé druhy', 'exact', null, null, null::date),
  ('66', 28::numeric,  5,  6,  6, 28::numeric, 1, '207', 46, 'Bad Brambacher', 'Malina', 'Bad Brambacher 0,5l různé druhy', 'exact', null, null, null::date),
  ('67', 36::numeric,  6,  6,  6, 36::numeric, 0, '260', 47, 'IsoFruit', 'Grep', 'IsoFruit Izotonický nápoj grep 500ml plech', 'exact', null, null, null::date),
  ('68', 29::numeric,  6,  6,  6, 29::numeric, 0, '70',  48, 'Kofola', 'Original', 'Kofola Original 500ml PET', 'exact', null, null, null::date),
  ('69', 13::numeric,  1,  5,  6, 13::numeric, 5, '41',  49, 'Capri-Sun', 'Multivitamin', 'Capri-Sun Multivitamin ovocný nápoj 200ml', 'exact', null, null, null::date)
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
  where machine_id = 70 and active = true;

  if v_count <> 50 then
    raise exception 'EV 90: očekáváno 50 aktivních pozic, nalezeno %.', v_count;
  end if;

  if v_desired <> 88 then
    raise exception 'EV 90: očekáváno celkem 88 ks k doplnění, nalezeno %.', v_desired;
  end if;

  if v_expiries <> 9 then
    raise exception 'EV 90: očekáváno 9 evidovaných expirací, nalezeno %.', v_expiries;
  end if;

  select count(*) into v_links
  from public.machine_external_links
  where machine_id = 70
    and external_machine_id = '592147'
    and telemetry_enabled = true;

  if v_links <> 2 then
    raise exception 'EV 90: očekávány 2 aktivní vazby TID 592147, nalezeno %.', v_links;
  end if;

  select count(*) into v_bad_capacity
  from public.machine_planogram_slots
  where machine_id = 70
    and active = true
    and current_units > capacity_units;

  if v_bad_capacity <> 0 then
    raise exception 'EV 90: nalezeny pozice nad kapacitou: %.', v_bad_capacity;
  end if;

  select location_id into v_location_id
  from public.machines
  where id = 70;

  if v_location_id <> 58 then
    raise exception 'EV 90: automat není připojen k lokalitě Sportisimo (ID 58), ale k %.', v_location_id;
  end if;
end
$$;

commit;
notify pgrst, 'reload schema';
