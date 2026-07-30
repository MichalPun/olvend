-- Aktuální planogram EV 78 / Bianchi Aria / Tišnov - Vitar.
-- Zdroj: Planogram [78] Bianchi Aria-2026-07-30.xlsx.
-- TID 587377; expirace a rozdíly prodejní/DEX ceny se přebírají přesně ze zdroje.
-- Pozice 46: zdroj uvádí 6 kusů při kapacitě 5; kapacita je opravena na 6.
-- Obecné varianty:
--   slot 45 DrWitt -> primární mango+citron SKU 277, náhrady citrus 276 a liči+hruška 200
--   slot 46 Bad Brambacher -> Malina SKU 207
--   slot 51 Nestea -> primární Peach SKU 67, povolená náhrada Lemon SKU 275

begin;

do $$
begin
  if not exists (
    select 1
    from public.machines
    where id = 58
      and evidence_number = 78
      and qr_token = 'vendsoft-78'
      and location_id = 60
      and machine_type = 'Snack'
  ) then
    raise exception 'EV 78 / Tišnov - Vitar nebyl nalezen na očekávaném DB záznamu.';
  end if;
end
$$;

update public.machines
set
  name = 'Bianchi Aria',
  machine_type = 'Snack',
  sales_tracking_mode = 'telemetry',
  note = 'Import z VendSoft exportu; původní kód 78; lokalita Tišnov_Vitar POTRAVINY. TID 587377.',
  updated_at = now()
where id = 58;

insert into public.machine_external_links (
  machine_id, provider, external_machine_id, telemetry_enabled, note
)
values
  (58, 'IMA', '587377', true, 'TID 587377 pro EV 78 / Bianchi Aria / Tišnov - Vitar.'),
  (58, 'GP',  '587377', true, 'TID 587377 pro EV 78 / Bianchi Aria / Tišnov - Vitar.')
on conflict (provider, external_machine_id) do update
set
  machine_id = excluded.machine_id,
  telemetry_enabled = true,
  note = excluded.note,
  updated_at = now();

update public.machine_planogram_slots
set active = false, updated_at = now()
where machine_id = 58;

insert into public.machine_planogram_slots (
  machine_id, slot_code, product_name, product_sku,
  price_czk, current_units, last_units, capacity_units,
  dex_price_czk, desired_units, target_units, expiry_date, telemetry_key,
  sort_order, active, product_family, product_variant,
  planned_product_name, planned_product_sku, planned_price_czk,
  substitution_policy, allowed_substitutes, operator_instruction, note
)
select
  58,
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
  'Planogram EV 78 / Tišnov - Vitar / TID 587377 aktualizován ze souboru 2026-07-30.'
from (values
  ('10', 20::numeric,  5,  7,  7, 20::numeric, 2, '42',   0, '7days', 'Lískový oříšek', '7days Croissant lískový oříšek 60g', 'exact', null, null, null::date),
  ('12', 30::numeric,  7,  7,  7, 19::numeric, 0, '279',  1, 'JoJo', 'Arašídy v cukru', 'Jojo Arašídky v cukru dražé 60g', 'exact', null, null, null::date),
  ('14', 21::numeric,  7,  7,  7, 21::numeric, 0, '144',  2, 'Yoohoo!', 'Kakao+lískový oříšek', 'Yoohoo! Vafle kakao+lískový oříšek 50', 'exact', null, null, null::date),
  ('16', 28::numeric,  6,  7,  7, 28::numeric, 1, '20',   3, 'Dupetky', 'Hořčice+med+cibulka', 'Dupetky Snack pečený hořčice+med+cibulka 70g', 'exact', null, null, null::date),
  ('18', 14::numeric,  9, 10, 10, 14::numeric, 1, '162',  4, 'Ovesná svačinka', 'Brusnice', 'Ovesná svačinka Sušenka s brusnicemi 36g', 'exact', null, null, null::date),
  ('20', 26::numeric, 10, 10, 10, 26::numeric, 0, '25',   5, 'Twix', null, 'Twix Tyčinka 50g', 'exact', null, null, null::date),
  ('22', 11::numeric, 10, 10, 10, 11::numeric, 0, '165',  6, 'Knoppers', null, 'Knoppers Oplatka 25g', 'exact', null, null, null::date),
  ('23', 14::numeric, 10, 10, 10, 14::numeric, 0, '254',  7, 'Dr.Ensa', 'Barbecue', 'Dr.Ensa Kukuřice pražená solená s příchutí barbecue 60g', 'exact', null, null, null::date),
  ('24', 24::numeric, 13, 13, 13, 24::numeric, 0, '31',   8, 'Miňonky', 'Oříškové', 'Miňonky Oplatky oříškové 50g', 'exact', null, null, null::date),
  ('25', 30::numeric, 13, 13, 13, 30::numeric, 0, '26',   9, '3Bit', 'Různé druhy', '3Bit tyčinka různé druhy', 'exact', null, null, null::date),
  ('26', 21::numeric, 10, 10, 10, 21::numeric, 0, '261', 10, 'Corny Big', 'Banán', 'Corny Big Tyčinka banány v mléčné čokoládě 50g', 'exact', null, null, null::date),
  ('27', 19::numeric,  7,  7,  7, 19::numeric, 0, '211', 11, 'Nový věk', 'Hořko-kakaová poleva', 'Nový věk Chlebíčky rýžové hořko-kakaová poleva 60g', 'exact', null, null, null::date),
  ('29', 18::numeric,  7,  7,  7, 18::numeric, 0, '280', 12, 'Veneto', 'Vanilková a kakaová náplň', 'Veneto Oplatka s vanilkovou a kakaovou náplní 65g', 'exact', null, null, null::date),
  ('30', 26::numeric, 11, 13, 13, 26::numeric, 2, '36',  13, 'Mila', null, 'Mila Oplatky 50g', 'exact', null, null, null::date),
  ('31', 20::numeric, 13, 13, 13, 20::numeric, 0, '35',  14, 'Sedita Horalky', 'Arašídové', 'Sedita Horalky Oplatky arašídové 50g', 'exact', null, null, null::date),
  ('32', 11::numeric, 12, 12, 12, 11::numeric, 0, '33',  15, 'Attack', 'Lískooříšková', 'Attack Oplatka lískooříšková 30g', 'exact', null, null, null::date),
  ('33', 26::numeric, 11, 12, 13, 26::numeric, 2, '24',  16, 'Snickers', null, 'Snickers Tyčinka čokoládová 50g', 'exact', null, null, null::date),
  ('34', 30::numeric, 15, 15, 15, 30::numeric, 0, '28',  17, 'Kinder Bueno', null, 'Kinder Bueno Oplatky 43g', 'exact', null, null, null::date),
  ('35', 25::numeric, 15, 15, 15, 25::numeric, 0, '40',  18, 'Margot', null, 'Margot Tyčinka 80g', 'exact', null, null, null::date),
  ('36',  8::numeric,  9, 10, 10,  9::numeric, 1, '208', 19, 'Alaska', 'Různé druhy', 'Alaska kukuřičné trubičky plněné krémem 18g různé druhy', 'exact', null, null, null::date),
  ('37', 10::numeric, 10, 10, 10, 10::numeric, 0, '143', 20, 'Today Donut', 'Kakaová náplň', 'Today Donut Dezert s kakaovou náplní v polevě 50g', 'exact', null, null, null::date),
  ('38', 13::numeric, 10, 10, 10, 13::numeric, 0, '142', 21, 'Racio Free Style', 'Rajče a bazalka', 'Racio Free Style Chlebíčky rajče a bazalka 25g', 'exact', null, null, null::date),
  ('39', 14::numeric, 10, 10, 10, 14::numeric, 0, '30',  22, 'Romanca', 'Kakaová náplň', 'Romanca Sušenka s kakaovou náplní 40g', 'exact', null, null, null::date),
  ('40', 55::numeric,  5,  6,  5, 55::numeric, 0, '155', 23, 'ATM', 'Debrecínská', 'ATM Debrecínská bageta', 'exact', null, null, '2026-08-04'::date),
  ('41', 55::numeric,  6,  6,  6, 55::numeric, 0, '278', 24, 'ATM', 'Masové koule', 'ATM - Masové koule', 'exact', null, null, '2026-08-06'::date),
  ('42', 55::numeric,  5,  5,  5, 55::numeric, 0, '79',  25, 'ATM', 'Belgická', 'ATM - Belgická bageta', 'exact', null, null, '2026-08-06'::date),
  ('43', 19::numeric,  3,  5,  6, 19::numeric, 3, '38',  26, 'Havlík', 'Originál', 'Havlík Tyčinky originál 90g', 'exact', null, 'Při návštěvě ověř expiraci a neprodejné kusy odepiš.', '2026-02-19'::date),
  ('44', 25::numeric,  6,  6,  6, 25::numeric, 0, '210', 27, 'Doritos', 'Nachos cheese', 'Doritos Tortillas Chipsy nachos cheese 44g', 'exact', null, 'Při návštěvě ověř expiraci a neprodejné kusy odepiš.', '2026-02-24'::date),
  ('45', 29::numeric,  6,  6,  6, 29::numeric, 0, '277', 28, 'DrWitt', 'Mango+citron', 'DrWitt min. voda 0,55l různé druhy', 'approved_list', 'DrWitt citrus SKU 276; DrWitt liči+hruška SKU 200', 'Přednostně mango+citron SKU 277; lze použít citrus 276 nebo liči+hruška 200. Při návštěvě ověř expiraci.', '2026-02-24'::date),
  ('46', 29::numeric,  6,  6,  6, 29::numeric, 0, '207', 29, 'Bad Brambacher', 'Malina', 'Bad Brambacher 0,5l různé druhy', 'exact', null, null, null::date),
  ('47', 55::numeric,  6,  6,  6, 55::numeric, 0, '154', 30, 'ATM', 'Trhané vepřové', 'ATM Trhané Vepřové', 'exact', null, null, '2026-08-06'::date),
  ('48', 55::numeric,  6,  6,  6, 55::numeric, 0, '79',  31, 'ATM', 'Belgická', 'ATM - Belgická bageta', 'exact', null, null, '2026-08-06'::date),
  ('49', 55::numeric,  4,  5,  6, 55::numeric, 2, '17',  32, 'ATM', 'Kuřecí stripsy', 'ATM - Kuřecí stripsy', 'exact', null, null, '2026-08-06'::date),
  ('50', 33::numeric,  6,  6,  6, 32::numeric, 0, '71',  33, 'Pepsi', 'Cola', 'Pepsi Cola 500ml PET', 'exact', null, null, null::date),
  ('51', 30::numeric,  6,  6,  6, 30::numeric, 0, '67',  34, 'Nestea', 'Peach', 'Nestea 0,5l různé druhy', 'approved_list', 'Nestea Lemon 0,5l (SKU 275)', 'Přednostně Peach SKU 67; lze použít Lemon SKU 275.', null::date),
  ('52', 32::numeric,  5,  6,  6, 32::numeric, 1, '70',  35, 'Kofola', 'Original', 'Kofola Original 500ml PET', 'exact', null, null, null::date),
  ('53', 24::numeric,  6,  6,  6, 24::numeric, 0, '209', 36, 'ZON', 'Různé druhy', 'ZON 500ml PET různé druhy', 'exact', null, null, null::date),
  ('54', 29::numeric,  5,  6,  6, 29::numeric, 1, '156', 37, 'Ice Coffee', null, 'Ice Coffee Ledová káva 350ml', 'exact', null, null, null::date),
  ('55', 39::numeric,  5,  6,  6, 39::numeric, 1, '2',   38, 'Big Shock!', 'Exotic', 'Big Shock! Energetický nápoj Exotic 500ml plech', 'exact', null, null, null::date),
  ('56', 28::numeric,  6,  6,  6, 28::numeric, 0, '187', 39, 'Staropramen Cool', 'Citron', 'Staropramen Cool citron nealkoholický nápoj z piva 500ml plech', 'exact', null, null, null::date),
  ('57', 20::numeric,  4,  6,  6, 20::numeric, 2, '13',  40, 'Hanácká Kyselka', 'Citron jemně perlivá', 'Hanácká Kyselka Minerální voda citron jemně perlivá 500ml PET', 'exact', null, null, null::date),
  ('58', 32::numeric,  5,  6,  6, 32::numeric, 1, '71',  41, 'Pepsi', 'Cola', 'Pepsi Cola 500ml PET', 'exact', null, null, null::date),
  ('59', 24::numeric,  5,  5,  6, 24::numeric, 1, '209', 42, 'ZON', 'Různé druhy', 'ZON 500ml PET různé druhy', 'exact', null, null, null::date),
  ('60', 19::numeric,  6,  6,  6, 19::numeric, 0, '163', 43, 'QXE', null, 'QXE Energetický nápoj 250ml plech', 'exact', null, null, null::date),
  ('61', 19::numeric,  6,  6,  6, 19::numeric, 0, '163', 44, 'QXE', null, 'QXE Energetický nápoj 250ml plech', 'exact', null, null, null::date),
  ('62', 27::numeric,  6,  6,  6, 27::numeric, 0, '4',   45, 'Hell', 'Classic', 'Hell Energetický nápoj classic 250ml plech', 'exact', null, null, null::date),
  ('63', 48::numeric,  6,  6,  6, 48::numeric, 0, '190', 46, 'Red Bull', null, 'Red Bull 0,25l', 'exact', null, null, null::date),
  ('64', 25::numeric,  6,  6,  6, 25::numeric, 0, '6',   47, 'Relax', 'Liči', 'Relax Limonáda liči 330ml plech', 'exact', null, null, null::date),
  ('65', 48::numeric,  6,  6,  6, 48::numeric, 0, '190', 48, 'Red Bull', null, 'Red Bull 0,25l', 'exact', null, null, null::date),
  ('66', 23::numeric,  4,  5,  6, 23::numeric, 2, '157', 49, 'Pepsi', 'Cola', 'Pepsi 0,33l plech', 'exact', null, null, null::date),
  ('67', 25::numeric,  4,  5,  5, 25::numeric, 1, '259', 50, 'Hello', 'Malina', 'Hello Perlivé malinový perlivý nápoj 330ml plech', 'exact', null, null, null::date),
  ('68', 19::numeric,  5,  5,  6, 19::numeric, 1, '163', 51, 'QXE', null, 'QXE Energetický nápoj 250ml plech', 'exact', null, null, null::date),
  ('69', 48::numeric,  6,  6,  6, 48::numeric, 0, '190', 52, 'Red Bull', null, 'Red Bull 0,25l', 'exact', null, null, null::date)
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
  where machine_id = 58 and active = true;

  if v_count <> 53 then
    raise exception 'EV 78: očekáváno 53 aktivních pozic, nalezeno %.', v_count;
  end if;

  select count(*) into v_links
  from public.machine_external_links
  where machine_id = 58
    and external_machine_id = '587377'
    and telemetry_enabled = true;

  if v_links <> 2 then
    raise exception 'EV 78: očekávány 2 aktivní vazby TID 587377, nalezeno %.', v_links;
  end if;

  select count(*) into v_bad_capacity
  from public.machine_planogram_slots
  where machine_id = 58
    and active = true
    and current_units > capacity_units;

  if v_bad_capacity <> 0 then
    raise exception 'EV 78: nalezeny pozice nad kapacitou: %.', v_bad_capacity;
  end if;
end
$$;

commit;
notify pgrst, 'reload schema';
