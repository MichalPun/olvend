-- Aktuální planogram EV 23 / Luce Snack X / Hotel Kovák.
-- Zdroj: Planogram [23] Luce Snack X-2026-07-30.xlsx.
-- TID 582171; expirace se přebírají přesně ze zdrojového souboru.
-- Obecné varianty:
--   slot 2 Nestea -> primární Peach SKU 67, povolená náhrada Lemon SKU 275
--   slot 29 Bad Brambacher -> Malina SKU 207
--   slot 31 DrWitt -> primární mango+citron SKU 277, náhrady citrus 276 a liči+hruška 200

begin;

do $$
begin
  if not exists (
    select 1
    from public.machines
    where id = 19
      and evidence_number = 23
      and qr_token = 'vendsoft-23'
      and location_id = 59
      and machine_type = 'Snack'
  ) then
    raise exception 'EV 23 / Hotel Kovák nebyl nalezen na očekávaném DB záznamu.';
  end if;
end
$$;

update public.machines
set
  name = 'Luce Snack X',
  machine_type = 'Snack',
  sales_tracking_mode = 'telemetry',
  note = 'Import z VendSoft exportu; původní kód 23; lokalita Ostrava_Hotel Kovák - POTRAVINY. TID 582171.',
  updated_at = now()
where id = 19;

insert into public.machine_external_links (
  machine_id, provider, external_machine_id, telemetry_enabled, note
)
values
  (19, 'IMA', '582171', true, 'TID 582171 pro EV 23 / Luce Snack X / Hotel Kovák.'),
  (19, 'GP',  '582171', true, 'TID 582171 pro EV 23 / Luce Snack X / Hotel Kovák.')
on conflict (provider, external_machine_id) do update
set
  machine_id = excluded.machine_id,
  telemetry_enabled = true,
  note = excluded.note,
  updated_at = now();

update public.machine_planogram_slots
set active = false, updated_at = now()
where machine_id = 19;

insert into public.machine_planogram_slots (
  machine_id, slot_code, product_name, product_sku,
  price_czk, current_units, last_units, capacity_units,
  dex_price_czk, desired_units, target_units, expiry_date, telemetry_key,
  sort_order, active, product_family, product_variant,
  planned_product_name, planned_product_sku, planned_price_czk,
  substitution_policy, allowed_substitutes, operator_instruction, note
)
select
  19,
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
  'Planogram EV 23 / Hotel Kovák / TID 582171 aktualizován ze souboru 2026-07-30.'
from (values
  ('1',  33::numeric,  3,  3,  6, 33::numeric, 3, '71',   0, 'Pepsi', 'Cola', 'Pepsi Cola 500ml PET', 'exact', null, null, null::date),
  ('2',  30::numeric,  6,  6,  6, 30::numeric, 0, '67',   1, 'Nestea', 'Peach', 'Nestea 0,5l různé druhy', 'approved_list', 'Nestea Lemon 0,5l (SKU 275)', 'Přednostně Peach SKU 67; lze použít Lemon SKU 275.', null::date),
  ('3',  32::numeric,  6,  6,  6, 32::numeric, 0, '70',   2, 'Kofola', 'Original', 'Kofola Original 500ml PET', 'exact', null, null, null::date),
  ('4',  24::numeric,  6,  6,  6, 24::numeric, 0, '209',  3, 'ZON', 'Různé druhy', 'ZON 500ml PET různé druhy', 'exact', null, null, null::date),
  ('5',  20::numeric,  5,  5,  6, 20::numeric, 1, '13',   4, 'Hanácká Kyselka', 'Citron jemně perlivá', 'Hanácká Kyselka Minerální voda citron jemně perlivá 500ml PET', 'exact', null, null, null::date),
  ('6',  39::numeric,  6,  6,  6, 39::numeric, 0, '2',    5, 'Big Shock!', 'Exotic', 'Big Shock! Energetický nápoj Exotic 500ml plech', 'exact', null, null, null::date),
  ('7',  29::numeric,  6,  6,  6, 28::numeric, 0, '187',  6, 'Staropramen Cool', 'Citron', 'Staropramen Cool citron nealkoholický nápoj z piva 500ml plech', 'exact', null, null, null::date),
  ('8',  28::numeric,  6,  6,  6, 29::numeric, 0, '156',  7, 'Ice Coffee', null, 'Ice Coffee Ledová káva 350ml', 'exact', null, null, null::date),
  ('9',  32::numeric,  6,  6,  6, 33::numeric, 0, '71',   8, 'Pepsi', 'Cola', 'Pepsi Cola 500ml PET', 'exact', null, null, null::date),
  ('12', 19::numeric,  6,  6,  6, 19::numeric, 0, '163',  9, 'QXE', null, 'QXE Energetický nápoj 250ml plech', 'exact', null, null, null::date),
  ('13', 19::numeric,  6,  6,  6, 19::numeric, 0, '163', 10, 'QXE', null, 'QXE Energetický nápoj 250ml plech', 'exact', null, null, null::date),
  ('14', 27::numeric,  6,  6,  6, 27::numeric, 0, '4',   11, 'Hell', 'Classic', 'Hell Energetický nápoj classic 250ml plech', 'exact', null, null, null::date),
  ('15', 48::numeric,  6,  6,  6, 48::numeric, 0, '190', 12, 'Red Bull', null, 'Red Bull 0,25l', 'exact', null, null, null::date),
  ('16', 25::numeric,  6,  6,  6, 25::numeric, 0, '6',   13, 'Relax', 'Liči', 'Relax Limonáda liči 330ml plech', 'exact', null, null, null::date),
  ('17', 19::numeric,  6,  6,  6, 19::numeric, 0, '163', 14, 'QXE', null, 'QXE Energetický nápoj 250ml plech', 'exact', null, null, null::date),
  ('18', 25::numeric,  6,  6,  6, 25::numeric, 0, '259', 15, 'Hello', 'Malina', 'Hello Perlivé malinový perlivý nápoj 330ml plech', 'exact', null, null, null::date),
  ('19', 23::numeric,  6,  6,  6, 23::numeric, 0, '157', 16, 'Pepsi', 'Cola', 'Pepsi 0,33l plech', 'exact', null, null, null::date),
  ('20', 13::numeric,  6,  6,  6, 15::numeric, 0, '41',  17, 'Capri-Sun', 'Multivitamin', 'Capri-Sun Multivitamin ovocný nápoj 200ml', 'exact', null, null, null::date),
  ('23', 55::numeric,  6,  6,  6, 55::numeric, 0, '17',  18, 'ATM', 'Kuřecí stripsy', 'ATM - Kuřecí stripsy', 'exact', null, null, '2026-08-06'::date),
  ('24', 55::numeric,  5,  5,  5, 55::numeric, 0, '79',  19, 'ATM', 'Belgická', 'ATM - Belgická bageta', 'exact', null, null, '2026-08-06'::date),
  ('25', 55::numeric,  6,  6,  6, 55::numeric, 0, '79',  20, 'ATM', 'Belgická', 'ATM - Belgická bageta', 'exact', null, null, '2026-08-06'::date),
  ('26', 55::numeric,  3,  3,  5, 55::numeric, 2, '278', 21, 'ATM', 'Masové koule', 'ATM - Masové koule', 'exact', null, null, '2026-08-06'::date),
  ('27', 55::numeric,  5,  5,  5, 55::numeric, 0, '154', 22, 'ATM', 'Trhané vepřové', 'ATM Trhané Vepřové', 'exact', null, null, '2026-08-06'::date),
  ('28', 25::numeric,  6,  6,  6, 25::numeric, 0, '210', 23, 'Doritos', 'Nachos cheese', 'Doritos Tortillas Chipsy nachos cheese 44g', 'exact', null, null, null::date),
  ('29', 28::numeric,  6,  6,  6, 29::numeric, 0, '207', 24, 'Bad Brambacher', 'Malina', 'Bad Brambacher 0,5l různé druhy', 'exact', null, null, null::date),
  ('30', 19::numeric,  6,  6,  6, 19::numeric, 0, '38',  25, 'Havlík', 'Originál', 'Havlík Tyčinky originál 90g', 'exact', null, null, null::date),
  ('31', 29::numeric,  6,  6,  6, 29::numeric, 0, '277', 26, 'DrWitt', 'Mango+citron', 'DrWitt min. voda 0,55l různé druhy', 'approved_list', 'DrWitt citrus SKU 276; DrWitt liči+hruška SKU 200', 'Přednostně mango+citron SKU 277; lze použít citrus 276 nebo liči+hruška 200.', null::date),
  ('34', 29::numeric, 15, 15, 15, 29::numeric, 0, '28',  27, 'Kinder Bueno', null, 'Kinder Bueno Oplatky 43g', 'exact', null, null, null::date),
  ('35', 20::numeric, 15, 15, 15, 20::numeric, 0, '35',  28, 'Sedita Horalky', 'Arašídové', 'Sedita Horalky Oplatky arašídové 50g', 'exact', null, null, null::date),
  ('36', 28::numeric, 15, 15, 15, 28::numeric, 0, '26',  29, '3Bit', 'Různé druhy', '3Bit tyčinka různé druhy', 'exact', null, null, null::date),
  ('37', 22::numeric, 15, 15, 15, 22::numeric, 0, '27',  30, 'Kit Kat', '4 Fingers', 'Kit Kat 4 Fingers Tyčinka 41,5g', 'exact', null, null, null::date),
  ('38', 26::numeric, 15, 15, 15, 26::numeric, 0, '24',  31, 'Snickers', null, 'Snickers Tyčinka čokoládová 50g', 'exact', null, null, null::date),
  ('39', 11::numeric, 10, 10, 10, 11::numeric, 0, '33',  32, 'Attack', 'Lískooříšková', 'Attack Oplatka lískooříšková 30g', 'exact', null, null, null::date),
  ('40', 24::numeric, 10, 10, 10, 24::numeric, 0, '40',  33, 'Margot', null, 'Margot Tyčinka 80g', 'exact', null, null, null::date),
  ('41', 26::numeric, 10, 10, 10, 26::numeric, 0, '36',  34, 'Mila', null, 'Mila Oplatky 50g', 'exact', null, null, null::date),
  ('46', 14::numeric, 10, 10, 10, 14::numeric, 0, '254', 35, 'Dr.Ensa', 'Barbecue', 'Dr.Ensa Kukuřice pražená solená s příchutí barbecue 60g', 'exact', null, null, null::date),
  ('48', 12::numeric, 10, 10, 10, 14::numeric, 0, '162', 36, 'Ovesná svačinka', 'Brusnice', 'Ovesná svačinka Sušenka s brusnicemi 36g', 'exact', null, null, null::date),
  ('50', 28::numeric, 10, 10, 10, 28::numeric, 0, '20',  37, 'Dupetky', 'Hořčice, med a cibulka', 'Dupetky Snack pečený hořčice+med+cibulka 70g', 'exact', null, null, null::date),
  ('52', 10::numeric, 10, 10, 10, 10::numeric, 0, '143', 38, 'Today Donut', 'Kakaová náplň', 'Today Donut Dezert s kakaovou náplní v polevě 50g', 'exact', null, null, null::date),
  ('57', 19::numeric,  8,  8,  8, 19::numeric, 0, '211', 39, 'Nový věk', 'Hořko-kakaová poleva', 'Nový věk Chlebíčky rýžové hořko-kakaová poleva 60g', 'exact', null, null, null::date),
  ('59', 21::numeric,  6,  6,  6, 21::numeric, 0, '144', 40, 'Yoohoo!', 'Kakao+lískový oříšek', 'Yoohoo! Vafle kakao+lískový oříšek 50', 'exact', null, null, null::date),
  ('61', 16::numeric, 10, 10, 10, 20::numeric, 0, '42',  41, '7days', 'Lískový oříšek', '7days Croissant lískový oříšek 60g', 'exact', null, null, null::date),
  ('63', 26::numeric, 10, 10, 10, 27::numeric, 0, '39',  42, 'Haribo', 'Goldbären', 'Haribo Bonbóny goldbären želé medvídci 100g', 'exact', null, null, null::date)
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
  where machine_id = 19 and active = true;

  if v_count <> 43 then
    raise exception 'EV 23: očekáváno 43 aktivních pozic, nalezeno %.', v_count;
  end if;

  select count(*) into v_links
  from public.machine_external_links
  where machine_id = 19
    and external_machine_id = '582171'
    and telemetry_enabled = true;

  if v_links <> 2 then
    raise exception 'EV 23: očekávány 2 aktivní vazby TID 582171, nalezeno %.', v_links;
  end if;

  select count(*) into v_bad_capacity
  from public.machine_planogram_slots
  where machine_id = 19
    and active = true
    and current_units > capacity_units;

  if v_bad_capacity <> 0 then
    raise exception 'EV 23: nalezeny pozice nad kapacitou: %.', v_bad_capacity;
  end if;
end
$$;

commit;
notify pgrst, 'reload schema';
