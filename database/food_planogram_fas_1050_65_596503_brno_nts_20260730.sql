-- Aktuální planogram EV 65 / FAS 1050 / Brno - NTS.
-- Zdroj: Planogram [65] FAS 1050-2026-07-30.xlsx.
-- TID 596503; expirace se přebírají přesně ze zdrojového souboru.
-- Obecné varianty:
--   slot 36 DrWitt -> primární mango+citron SKU 277, náhrady citrus 276 a liči+hruška 200
--   slot 37 Bad Brambacher -> Malina SKU 207
--   slot 42 Nestea -> primární Peach SKU 67, povolená náhrada Lemon SKU 275

begin;

do $$
begin
  if not exists (
    select 1
    from public.machines
    where id = 49
      and evidence_number = 65
      and qr_token = 'vendsoft-65'
      and location_id = 13
      and machine_type = 'Snack'
  ) then
    raise exception 'EV 65 / Brno - NTS nebyl nalezen na očekávaném DB záznamu.';
  end if;
end
$$;

update public.machines
set
  name = 'FAS 1050',
  machine_type = 'Snack',
  sales_tracking_mode = 'telemetry',
  note = 'Import z VendSoft exportu; původní kód 65; lokalita Brno_NTS. TID 596503.',
  updated_at = now()
where id = 49;

insert into public.machine_external_links (
  machine_id, provider, external_machine_id, telemetry_enabled, note
)
values
  (49, 'IMA', '596503', true, 'TID 596503 pro EV 65 / FAS 1050 / Brno - NTS.'),
  (49, 'GP',  '596503', true, 'TID 596503 pro EV 65 / FAS 1050 / Brno - NTS.')
on conflict (provider, external_machine_id) do update
set
  machine_id = excluded.machine_id,
  telemetry_enabled = true,
  note = excluded.note,
  updated_at = now();

update public.machine_planogram_slots
set active = false, updated_at = now()
where machine_id = 49;

insert into public.machine_planogram_slots (
  machine_id, slot_code, product_name, product_sku,
  price_czk, current_units, last_units, capacity_units,
  dex_price_czk, desired_units, target_units, expiry_date, telemetry_key,
  sort_order, active, product_family, product_variant,
  planned_product_name, planned_product_sku, planned_price_czk,
  substitution_policy, allowed_substitutes, operator_instruction, note
)
select
  49,
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
  'Planogram EV 65 / Brno - NTS / TID 596503 aktualizován ze souboru 2026-07-30.'
from (values
  ('1',  27::numeric,  5,  5,  5, 27::numeric, 0, '39',   0, 'Haribo', 'Goldbären', 'Haribo Bonbóny goldbären želé medvídci 100g', 'exact', null, null, null::date),
  ('3',  20::numeric,  3,  5,  5, 20::numeric, 2, '42',   1, '7days', 'Lískový oříšek', '7days Croissant lískový oříšek 60g', 'exact', null, null, null::date),
  ('5',  21::numeric,  5,  5,  6, 21::numeric, 1, '144',  2, 'Yoohoo!', 'Kakao+lískový oříšek', 'Yoohoo! Vafle kakao+lískový oříšek 50', 'exact', null, null, null::date),
  ('7',  28::numeric,  5,  5,  5, 28::numeric, 0, '20',   3, 'Dupetky', 'Hořčice, med a cibulka', 'Dupetky Snack pečený hořčice+med+cibulka 70g', 'exact', null, null, null::date),
  ('9',  14::numeric,  5,  5,  5, 14::numeric, 0, '162',  4, 'Ovesná svačinka', 'Brusnice', 'Ovesná svačinka Sušenka s brusnicemi 36g', 'exact', null, null, null::date),
  ('11', 13::numeric,  7, 10, 10, 13::numeric, 3, '142',  5, 'Racio Free Style', 'Rajče a bazalka', 'Racio Free Style Chlebíčky rajče a bazalka 25g', 'exact', null, null, null::date),
  ('13', 14::numeric, 11, 11, 11, 14::numeric, 0, '254',  6, 'Dr.Ensa', 'Barbecue', 'Dr.Ensa Kukuřice pražená solená s příchutí barbecue 60g', 'exact', null, null, null::date),
  ('15', 24::numeric, 11, 11, 11, 24::numeric, 0, '31',   7, 'Miňonky', 'Oříškové', 'Miňonky Oplatky oříškové 50g', 'exact', null, null, null::date),
  ('17', 11::numeric, 13, 13, 13, 14::numeric, 0, '165',  8, 'Knoppers', null, 'Knoppers Oplatka 25g', 'exact', null, null, null::date),
  ('18', 24::numeric, 12, 13, 13, 24::numeric, 1, '27',   9, 'Kit Kat', '4 Fingers', 'Kit Kat 4 Fingers Tyčinka 41,5g', 'exact', null, null, null::date),
  ('19', 10::numeric,  8,  9,  9, 10::numeric, 1, '143', 10, 'Today Donut', 'Kakaová náplň', 'Today Donut Dezert s kakaovou náplní v polevě 50g', 'exact', null, null, null::date),
  ('20', 21::numeric,  8,  9,  9, 21::numeric, 1, '261', 11, 'Corny Big', 'Banán', 'Corny Big Tyčinka banány v mléčné čokoládě 50g', 'exact', null, null, null::date),
  ('21', 26::numeric, 13, 14, 14, 26::numeric, 1, '36',  12, 'Mila', null, 'Mila Oplatky 50g', 'exact', null, null, null::date),
  ('22', 20::numeric, 10, 14, 14, 20::numeric, 4, '35',  13, 'Sedita Horalky', 'Arašídové', 'Sedita Horalky Oplatky arašídové 50g', 'exact', null, null, null::date),
  ('23', 11::numeric, 14, 14, 14, 11::numeric, 0, '33',  14, 'Attack', 'Lískooříšková', 'Attack Oplatka lískooříšková 30g', 'exact', null, null, null::date),
  ('24', 26::numeric, 12, 13, 13, 26::numeric, 1, '24',  15, 'Snickers', null, 'Snickers Tyčinka čokoládová 50g', 'exact', null, null, null::date),
  ('25', 30::numeric,  9, 10, 10, 30::numeric, 1, '28',  16, 'Kinder Bueno', null, 'Kinder Bueno Oplatky 43g', 'exact', null, null, null::date),
  ('26', 25::numeric, 12, 15, 15, 25::numeric, 3, '40',  17, 'Margot', null, 'Margot Tyčinka 80g', 'exact', null, null, null::date),
  ('27',  8::numeric, 13, 13, 13,  8::numeric, 0, '208', 18, 'Alaska', 'Různé druhy', 'Alaska kukuřičné trubičky plněné krémem 18g různé druhy', 'exact', null, null, null::date),
  ('28', 30::numeric, 11, 12, 12, 30::numeric, 1, '26',  19, '3Bit', 'Různé druhy', '3Bit tyčinka různé druhy', 'exact', null, null, null::date),
  ('29', 26::numeric, 10, 10, 10, 26::numeric, 0, '25',  20, 'Twix', null, 'Twix Tyčinka 50g', 'exact', null, null, null::date),
  ('30', 14::numeric,  9, 10, 10, 14::numeric, 1, '30',  21, 'Romanca', 'Kakaová náplň', 'Romanca Sušenka s kakaovou náplní 40g', 'exact', null, null, null::date),
  ('31', 55::numeric,  5,  6,  6, 55::numeric, 1, '155', 22, 'ATM', 'Debrecínská', 'ATM Debrecínská bageta', 'exact', null, null, '2026-08-04'::date),
  ('32', 55::numeric,  0,  5,  5, 55::numeric, 5, '17',  23, 'ATM', 'Kuřecí stripsy', 'ATM - Kuřecí stripsy', 'exact', null, null, '2026-08-06'::date),
  ('33', 55::numeric,  0,  5,  5, 55::numeric, 5, '79',  24, 'ATM', 'Belgická', 'ATM - Belgická bageta', 'exact', null, null, '2026-08-06'::date),
  ('34', 19::numeric,  5,  5,  5, 19::numeric, 0, '38',  25, 'Havlík', 'Originál', 'Havlík Tyčinky originál 90g', 'exact', null, 'Při návštěvě ověř expiraci a neprodejné kusy odepiš.', '2026-02-24'::date),
  ('35', 25::numeric,  5,  5,  5, 25::numeric, 0, '210', 26, 'Doritos', 'Nachos cheese', 'Doritos Tortillas Chipsy nachos cheese 44g', 'exact', null, 'Při návštěvě ověř expiraci a neprodejné kusy odepiš.', '2026-01-13'::date),
  ('36', 29::numeric,  1,  6,  6, 29::numeric, 5, '277', 27, 'DrWitt', 'Mango+citron', 'DrWitt min. voda 0,55l různé druhy', 'approved_list', 'DrWitt citrus SKU 276; DrWitt liči+hruška SKU 200', 'Přednostně mango+citron SKU 277; lze použít citrus 276 nebo liči+hruška 200. Ověř expiraci.', '2026-02-24'::date),
  ('37', 29::numeric,  6,  6,  6, 29::numeric, 0, '207', 28, 'Bad Brambacher', 'Malina', 'Bad Brambacher 0,5l různé druhy', 'exact', null, 'Při návštěvě ověř expiraci a neprodejné kusy odepiš.', '2025-08-20'::date),
  ('38', 30::numeric,  5,  6,  6, 30::numeric, 1, '279', 29, 'JoJo', 'Arašídy v cukru', 'Jojo Arašídky v cukru dražé 60g', 'exact', null, 'Při návštěvě ověř expiraci a neprodejné kusy odepiš.', '2025-08-24'::date),
  ('39', 19::numeric,  4,  5,  5, 19::numeric, 1, '211', 30, 'Nový věk', 'Hořko-kakaová poleva', 'Nový věk Chlebíčky rýžové hořko-kakaová poleva 60g', 'exact', null, 'Při návštěvě ověř expiraci a neprodejné kusy odepiš.', '2025-08-20'::date),
  ('40', 25::numeric,  5,  5,  5, 25::numeric, 0, '259', 31, 'Hello', 'Malina', 'Hello Perlivé malinový perlivý nápoj 330ml plech', 'exact', null, null, '2026-08-01'::date),
  ('41', 32::numeric,  3,  5,  5, 32::numeric, 2, '71',  32, 'Pepsi', 'Cola', 'Pepsi Cola 500ml PET', 'exact', null, null, null::date),
  ('42', 30::numeric,  5,  5,  5, 30::numeric, 0, '67',  33, 'Nestea', 'Peach', 'Nestea 0,5l různé druhy', 'approved_list', 'Nestea Lemon 0,5l (SKU 275)', 'Přednostně Peach SKU 67; lze použít Lemon SKU 275.', null::date),
  ('43', 32::numeric,  1,  6,  6, 32::numeric, 5, '70',  34, 'Kofola', 'Original', 'Kofola Original 500ml PET', 'exact', null, null, null::date),
  ('44', 24::numeric,  6,  6,  6, 24::numeric, 0, '209', 35, 'ZON', 'Různé druhy', 'ZON 500ml PET různé druhy', 'exact', null, null, null::date),
  ('45', 29::numeric,  5,  5,  5, 29::numeric, 0, '156', 36, 'Ice Coffee', null, 'Ice Coffee Ledová káva 350ml', 'exact', null, null, null::date),
  ('46', 39::numeric,  5,  5,  5, 39::numeric, 0, '2',   37, 'Big Shock!', 'Exotic', 'Big Shock! Energetický nápoj Exotic 500ml plech', 'exact', null, null, null::date),
  ('47', 28::numeric,  2,  5,  5, 28::numeric, 3, '187', 38, 'Staropramen Cool', 'Citron', 'Staropramen Cool citron nealkoholický nápoj z piva 500ml plech', 'exact', null, null, null::date),
  ('48', 20::numeric,  3,  5,  5, 20::numeric, 2, '13',  39, 'Hanácká Kyselka', 'Citron jemně perlivá', 'Hanácká Kyselka Minerální voda citron jemně perlivá 500ml PET', 'exact', null, null, null::date),
  ('49', 32::numeric,  4,  5,  5, 32::numeric, 1, '71',  40, 'Pepsi', 'Cola', 'Pepsi Cola 500ml PET', 'exact', null, null, null::date),
  ('50', 24::numeric,  1,  5,  5, 24::numeric, 4, '209', 41, 'ZON', 'Různé druhy', 'ZON 500ml PET různé druhy', 'exact', null, null, null::date),
  ('51', 19::numeric,  3,  5,  5, 19::numeric, 2, '163', 42, 'QXE', null, 'QXE Energetický nápoj 250ml plech', 'exact', null, null, null::date),
  ('52', 27::numeric,  1,  5,  5, 27::numeric, 4, '4',   43, 'Hell', 'Classic', 'Hell Energetický nápoj classic 250ml plech', 'exact', null, null, null::date),
  ('53', 27::numeric,  2,  5,  5, 27::numeric, 3, '4',   44, 'Hell', 'Classic', 'Hell Energetický nápoj classic 250ml plech', 'exact', null, null, null::date),
  ('54', 48::numeric,  4,  4,  5, 48::numeric, 1, '190', 45, 'Red Bull', null, 'Red Bull 0,25l', 'exact', null, null, null::date),
  ('55', 25::numeric,  4,  5,  5, 25::numeric, 1, '6',   46, 'Relax', 'Liči', 'Relax Limonáda liči 330ml plech', 'exact', null, null, null::date),
  ('56', 15::numeric,  5,  5,  5, 15::numeric, 0, '41',  47, 'Capri-Sun', 'Multivitamin', 'Capri-Sun Multivitamin ovocný nápoj 200ml', 'exact', null, null, null::date),
  ('57', 23::numeric,  3,  6,  6, 23::numeric, 3, '157', 48, 'Pepsi', 'Cola', 'Pepsi 0,33l plech', 'exact', null, null, null::date),
  ('58', 39::numeric,  3,  5,  5, 39::numeric, 2, '2',   49, 'Big Shock!', 'Exotic', 'Big Shock! Energetický nápoj Exotic 500ml plech', 'exact', null, null, null::date),
  ('59', 19::numeric,  4,  5,  5, 19::numeric, 1, '163', 50, 'QXE', null, 'QXE Energetický nápoj 250ml plech', 'exact', null, null, null::date),
  ('60', 48::numeric,  5,  5,  5, 48::numeric, 0, '190', 51, 'Red Bull', null, 'Red Bull 0,25l', 'exact', null, null, null::date)
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
begin
  select count(*) into v_count
  from public.machine_planogram_slots
  where machine_id = 49 and active = true;

  if v_count <> 52 then
    raise exception 'EV 65: očekáváno 52 aktivních pozic, nalezeno %.', v_count;
  end if;

  select count(*) into v_links
  from public.machine_external_links
  where machine_id = 49
    and external_machine_id = '596503'
    and telemetry_enabled = true;

  if v_links <> 2 then
    raise exception 'EV 65: očekávány 2 aktivní vazby TID 596503, nalezeno %.', v_links;
  end if;

  select count(*) into v_bad_capacity
  from public.machine_planogram_slots
  where machine_id = 49
    and active = true
    and current_units > capacity_units;

  if v_bad_capacity <> 0 then
    raise exception 'EV 65: nalezeny pozice nad kapacitou: %.', v_bad_capacity;
  end if;
end
$$;

commit;
notify pgrst, 'reload schema';
