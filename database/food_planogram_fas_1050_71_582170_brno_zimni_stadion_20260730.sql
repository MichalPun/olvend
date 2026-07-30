-- Aktuální planogram EV 71 / FAS 1050 / Brno - Zimní stadion.
-- Zdroj: Planogram [71] FAS 1050-2026-07-30.xlsx.
-- TID 582170; expirace se přebírají ze zdrojového souboru.
-- U pozice 37 je zjevný překlep 21/08/2052 opraven na 21/08/2025.
-- Lokalita je uzavřená: provozní upozornění se znovu zobrazí od 17. 8. 2026.

begin;

do $$
begin
  if not exists (
    select 1
    from public.machines
    where id = 51
      and evidence_number = 71
      and qr_token = 'vendsoft-71'
      and location_id = 12
      and machine_type = 'Snack'
  ) then
    raise exception 'EV 71 / Brno - Zimní stadion nebyl nalezen na očekávaném DB záznamu.';
  end if;
end
$$;

update public.locations
set
  service_suspended_until = '2026-08-17'::date,
  service_plan_note = 'Zimní stadion je uzavřený; provozní upozornění a doporučené trasy znovu od 17. 8. 2026.',
  updated_at = now()
where id = 12;

update public.machines
set
  name = 'FAS 1050',
  machine_type = 'Snack',
  sales_tracking_mode = 'telemetry',
  note = 'Import z VendSoft exportu; původní kód 71; lokalita Brno Zimní stadion. TID 582170.',
  updated_at = now()
where id = 51;

insert into public.machine_external_links (
  machine_id, provider, external_machine_id, telemetry_enabled, note
)
values
  (51, 'IMA', '582170', true, 'TID 582170 pro EV 71 / FAS 1050 / Brno - Zimní stadion.'),
  (51, 'GP',  '582170', true, 'TID 582170 pro EV 71 / FAS 1050 / Brno - Zimní stadion.')
on conflict (provider, external_machine_id) do update
set
  machine_id = excluded.machine_id,
  telemetry_enabled = true,
  note = excluded.note,
  updated_at = now();

update public.machine_planogram_slots
set active = false, updated_at = now()
where machine_id = 51;

insert into public.machine_planogram_slots (
  machine_id, slot_code, product_name, product_sku,
  price_czk, current_units, last_units, capacity_units,
  dex_price_czk, desired_units, target_units, expiry_date, telemetry_key,
  sort_order, active, product_family, product_variant,
  planned_product_name, planned_product_sku, planned_price_czk,
  substitution_policy, allowed_substitutes, operator_instruction, note
)
select
  51,
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
  'Planogram EV 71 / Brno - Zimní stadion / TID 582170 aktualizován ze souboru 2026-07-30.'
from (values
  ('1',  31::numeric,  6,  6, 10, 31::numeric, 4, '39',   0, 'Haribo', 'Goldbären', 'Haribo Bonbóny goldbären želé medvídci 100g', 'exact', null, null, null::date),
  ('3',  25::numeric,  6,  6,  7, 25::numeric, 1, '42',   1, '7days', 'Lískový oříšek', '7days Croissant lískový oříšek 60g', 'exact', null, null, null::date),
  ('5',  30::numeric,  4,  4,  4, 30::numeric, 0, '139',  2, 'Strážnické brambůrky', 'Česnekové', 'Strážnické brambůrky česnekové 60g', 'exact', null, null, null::date),
  ('7',  22::numeric,  3,  3,  7, 22::numeric, 4, '211',  3, 'Nový věk', 'Hořko-kakaová poleva', 'Nový věk Chlebíčky rýžové hořko-kakaová poleva 60g', 'exact', null, null, null::date),
  ('9',  32::numeric,  5,  5,  9, 32::numeric, 4, '20',   4, 'Dupetky', 'Hořčice, med a cibulka', 'Dupetky Snack pečený hořčice+med+cibulka 70g', 'exact', null, null, null::date),
  ('11', 29::numeric, 11, 11, 11, 29::numeric, 0, '25',   5, 'Twix', null, 'Twix Tyčinka 50g', 'exact', null, null, null::date),
  ('12', 27::numeric, 10, 10, 11, 27::numeric, 1, '27',   6, 'Kit Kat', '4 Fingers', 'Kit Kat 4 Fingers Tyčinka 41,5g', 'exact', null, null, null::date),
  ('13', 20::numeric,  6,  6, 11, 20::numeric, 5, '37',   7, 'Dr.Ensa', 'Arašídy', 'Dr.Ensa Arašídy pražené solené 60g', 'exact', null, null, null::date),
  ('15', 15::numeric,  6,  6, 10, 15::numeric, 4, '162',  8, 'Ovesná svačinka', 'Brusnice', 'Ovesná svačinka Sušenka s brusnicemi 36g', 'exact', null, null, null::date),
  ('17', 23::numeric,  8,  8,  9, 23::numeric, 1, '261',  9, 'Corny Big', 'Banán', 'Corny Big Tyčinka banány v mléčné čokoládě 50g', 'exact', null, null, null::date),
  ('18', 22::numeric,  9,  9,  9, 22::numeric, 0, '31',  10, 'Miňonky', 'Oříškové', 'Miňonky Oplatky oříškové 50g', 'exact', null, null, null::date),
  ('19', 24::numeric, 10, 10, 11, 24::numeric, 1, '144', 11, 'Yoohoo!', 'Kakao+lískový oříšek', 'Yoohoo! Vafle kakao+lískový oříšek 50', 'exact', null, null, null::date),
  ('20', 14::numeric, 11, 11, 11, 14::numeric, 0, '165', 12, 'Knoppers', null, 'Knoppers Oplatka 25g', 'exact', null, null, null::date),
  ('21', 29::numeric, 14, 14, 15, 29::numeric, 1, '36',  13, 'Mila', null, 'Mila Oplatky 50g', 'exact', null, null, null::date),
  ('22', 23::numeric, 10, 10, 14, 23::numeric, 4, '35',  14, 'Sedita Horalky', 'Arašídové', 'Sedita Horalky Oplatky arašídové 50g', 'exact', null, null, null::date),
  ('23', 14::numeric, 11, 11, 13, 14::numeric, 2, '33',  15, 'Attack', 'Lískooříšková', 'Attack Oplatka lískooříšková 30g', 'exact', null, null, null::date),
  ('24', 29::numeric, 11, 11, 13, 29::numeric, 2, '24',  16, 'Snickers', null, 'Snickers Tyčinka čokoládová 50g', 'exact', null, null, null::date),
  ('25', 33::numeric,  8,  8, 11, 33::numeric, 3, '28',  17, 'Kinder Bueno', null, 'Kinder Bueno Oplatky 43g', 'exact', null, null, null::date),
  ('26', 28::numeric,  8,  8, 11, 28::numeric, 3, '40',  18, 'Margot', null, 'Margot Tyčinka 80g', 'exact', null, null, null::date),
  ('27', 10::numeric,  8,  8, 13, 10::numeric, 5, '208', 19, 'Alaska', 'Různé druhy', 'Alaska kukuřičné trubičky plněné krémem 18g různé druhy', 'exact', null, null, null::date),
  ('28', 13::numeric,  2,  2, 11, 13::numeric, 9, '143', 20, 'Today Donut', 'Kakaová náplň', 'Today Donut Dezert s kakaovou náplní v polevě 50g', 'exact', null, null, null::date),
  ('29', 16::numeric,  5,  5,  9, 16::numeric, 4, '142', 21, 'Racio Free Style', 'Rajče a bazalka', 'Racio Free Style Chlebíčky rajče a bazalka 25g', 'exact', null, null, null::date),
  ('31', 55::numeric,  1,  1,  3, 65::numeric, 2, '79',  22, 'ATM', 'Belgická', 'ATM - Belgická bageta', 'exact', null, 'Při první návštěvě po otevření ověř expiraci a neprodejné kusy odepiš.', '2026-06-16'::date),
  ('32', 65::numeric,  3,  3,  3, 65::numeric, 0, '17',  23, 'ATM', 'Kuřecí stripsy', 'ATM - Kuřecí stripsy', 'exact', null, 'Při první návštěvě po otevření ověř expiraci a neprodejné kusy odepiš.', '2026-06-20'::date),
  ('33', 65::numeric,  3,  3,  3, 65::numeric, 0, '155', 24, 'ATM', 'Debrecínská', 'ATM Debrecínská bageta', 'exact', null, 'Při první návštěvě po otevření ověř expiraci a neprodejné kusy odepiš.', '2026-06-20'::date),
  ('34', 23::numeric,  5,  5,  6, 23::numeric, 1, '38',  25, 'Havlík', 'Originál', 'Havlík Tyčinky originál 90g', 'exact', null, 'Při první návštěvě po otevření ověř expiraci a neprodejné kusy odepiš.', '2026-01-06'::date),
  ('35', 29::numeric,  1,  1,  5, 29::numeric, 4, '210', 26, 'Doritos', 'Nachos cheese', 'Doritos Tortillas Chipsy nachos cheese 44g', 'exact', null, 'Při první návštěvě po otevření ověř expiraci a neprodejné kusy odepiš.', '2026-01-13'::date),
  ('36', 35::numeric,  0,  0,  5, 35::numeric, 5, '277', 27, 'DrWitt', 'Mango+citron', 'DrWitt min. voda 0,55l různé druhy', 'approved_list', 'DrWitt citrus SKU 276; DrWitt liči+hruška SKU 200', 'Přednostně mango+citron SKU 277; lze použít citrus 276 nebo liči+hruška 200. Při první návštěvě po otevření ověř expiraci.', '2026-01-06'::date),
  ('37', 35::numeric,  3,  3,  5, 35::numeric, 2, '207', 28, 'Bad Brambacher', 'Malina', 'Bad Brambacher 0,5l různé druhy', 'exact', null, 'Při první návštěvě po otevření ověř expiraci a neprodejné kusy odepiš.', '2025-08-21'::date),
  ('38', 29::numeric,  2,  2,  5, 29::numeric, 3, '210', 29, 'Doritos', 'Nachos cheese', 'Doritos Tortillas Chipsy nachos cheese 44g', 'exact', null, 'Při první návštěvě po otevření ověř expiraci a neprodejné kusy odepiš.', '2026-02-21'::date),
  ('39', 35::numeric,  0,  0,  5, 35::numeric, 5, '277', 30, 'DrWitt', 'Mango+citron', 'DrWitt min. voda 0,55l různé druhy', 'approved_list', 'DrWitt citrus SKU 276; DrWitt liči+hruška SKU 200', 'Přednostně mango+citron SKU 277; lze použít citrus 276 nebo liči+hruška 200. Při první návštěvě po otevření ověř expiraci.', '2026-02-19'::date),
  ('40', 35::numeric,  1,  1,  5, 35::numeric, 4, '207', 31, 'Bad Brambacher', 'Malina', 'Bad Brambacher 0,5l různé druhy', 'exact', null, 'Při první návštěvě po otevření ověř expiraci a neprodejné kusy odepiš.', '2026-02-19'::date),
  ('41', 40::numeric,  5,  5,  5, 40::numeric, 0, '71',  32, 'Pepsi', 'Cola', 'Pepsi Cola 500ml PET', 'exact', null, null, null::date),
  ('42', 40::numeric,  1,  1,  5, 40::numeric, 4, '67',  33, 'Nestea', 'Peach', 'Nestea 0,5l různé druhy', 'approved_list', 'Nestea Lemon 0,5l (SKU 275)', 'Přednostně Peach SKU 67; lze použít Lemon SKU 275. Při první návštěvě po otevření ověř expiraci.', '2025-08-24'::date),
  ('43', 40::numeric,  2,  2,  5, 40::numeric, 3, '70',  34, 'Kofola', 'Original', 'Kofola Original 500ml PET', 'exact', null, 'Při první návštěvě po otevření ověř expiraci a neprodejné kusy odepiš.', '2025-08-21'::date),
  ('44', 30::numeric,  0,  0,  5, 30::numeric, 5, '209', 35, 'ZON', 'Různé druhy', 'ZON 500ml PET různé druhy', 'exact', null, 'Při první návštěvě po otevření ověř expiraci a neprodejné kusy odepiš.', '2025-08-20'::date),
  ('45', 35::numeric,  2,  2,  5, 35::numeric, 3, '156', 36, 'Ice Coffee', null, 'Ice Coffee Ledová káva 350ml', 'exact', null, null, null::date),
  ('46', 45::numeric,  5,  5,  5, 45::numeric, 0, '2',   37, 'Big Shock!', 'Exotic', 'Big Shock! Energetický nápoj Exotic 500ml plech', 'exact', null, null, null::date),
  ('47', 35::numeric,  5,  5,  5, 35::numeric, 0, '187', 38, 'Staropramen Cool', 'Citron', 'Staropramen Cool citron nealkoholický nápoj z piva 500ml plech', 'exact', null, null, null::date),
  ('48', 30::numeric,  2,  2,  5, 30::numeric, 3, '13',  39, 'Hanácká Kyselka', 'Citron jemně perlivá', 'Hanácká Kyselka Minerální voda citron jemně perlivá 500ml PET', 'exact', null, null, null::date),
  ('49', 40::numeric,  5,  5,  5, 40::numeric, 0, '71',  40, 'Pepsi', 'Cola', 'Pepsi Cola 500ml PET', 'exact', null, null, null::date),
  ('50', 30::numeric,  2,  2,  5, 30::numeric, 3, '209', 41, 'ZON', 'Různé druhy', 'ZON 500ml PET různé druhy', 'exact', null, null, null::date),
  ('51', 22::numeric,  5,  5,  5, 22::numeric, 0, '163', 42, 'QXE', null, 'QXE Energetický nápoj 250ml plech', 'exact', null, null, null::date),
  ('52', 22::numeric,  5,  5,  5, 22::numeric, 0, '163', 43, 'QXE', null, 'QXE Energetický nápoj 250ml plech', 'exact', null, null, null::date),
  ('53', 35::numeric,  5,  5,  5, 35::numeric, 0, '4',   44, 'Hell', 'Classic', 'Hell Energetický nápoj classic 250ml plech', 'exact', null, null, null::date),
  ('54', 60::numeric,  5,  5,  5, 60::numeric, 0, '190', 45, 'Red Bull', null, 'Red Bull 0,25l', 'exact', null, null, null::date),
  ('55', 30::numeric,  3,  3,  5, 30::numeric, 2, '6',   46, 'Relax', 'Liči', 'Relax Limonáda liči 330ml plech', 'exact', null, null, null::date),
  ('56', 20::numeric,  4,  4,  5, 20::numeric, 1, '41',  47, 'Capri-Sun', 'Multivitamin', 'Capri-Sun Multivitamin ovocný nápoj 200ml', 'exact', null, null, null::date),
  ('57', 27::numeric,  0,  0,  5, 27::numeric, 5, '157', 48, 'Pepsi', 'Cola', 'Pepsi 0,33l plech', 'exact', null, null, null::date),
  ('58', 30::numeric,  5,  5,  5, 30::numeric, 0, '259', 49, 'Hello', 'Malina', 'Hello Perlivé malinový perlivý nápoj 330ml plech', 'exact', null, null, null::date),
  ('59', 22::numeric,  3,  3,  5, 22::numeric, 2, '163', 50, 'QXE', null, 'QXE Energetický nápoj 250ml plech', 'exact', null, null, null::date),
  ('60', 60::numeric,  5,  5,  5, 60::numeric, 0, '190', 51, 'Red Bull', null, 'Red Bull 0,25l', 'exact', null, null, null::date)
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
  v_suspended_until date;
begin
  select count(*) into v_count
  from public.machine_planogram_slots
  where machine_id = 51 and active = true;

  if v_count <> 52 then
    raise exception 'EV 71: očekáváno 52 aktivních pozic, nalezeno %.', v_count;
  end if;

  select count(*) into v_links
  from public.machine_external_links
  where machine_id = 51
    and external_machine_id = '582170'
    and telemetry_enabled = true;

  if v_links <> 2 then
    raise exception 'EV 71: očekávány 2 aktivní vazby TID 582170, nalezeno %.', v_links;
  end if;

  select count(*) into v_bad_capacity
  from public.machine_planogram_slots
  where machine_id = 51
    and active = true
    and current_units > capacity_units;

  if v_bad_capacity <> 0 then
    raise exception 'EV 71: nalezeny pozice nad kapacitou: %.', v_bad_capacity;
  end if;

  select service_suspended_until into v_suspended_until
  from public.locations
  where id = 12;

  if v_suspended_until <> '2026-08-17'::date then
    raise exception 'EV 71: neočekávané datum obnovení upozornění %.', v_suspended_until;
  end if;
end
$$;

commit;
notify pgrst, 'reload schema';
