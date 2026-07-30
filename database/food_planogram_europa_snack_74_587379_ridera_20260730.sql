-- Aktuální planogram EV 74 / Europa Snack / Ridera Bohemia.
-- Zdroj: Planogram [74] Europa Snack-2026-07-30.xlsx.
-- TID 587379; expirace a rozdíly prodejní/DEX ceny se přebírají přesně ze zdroje.
-- Obecné varianty:
--   slot 14 Nestea -> primární Peach SKU 67, povolená náhrada Lemon SKU 275
--   slot 28 Bad Brambacher -> Malina SKU 207
--   slot 29 DrWitt -> primární mango+citron SKU 277, náhrady citrus 276 a liči+hruška 200

begin;

do $$
begin
  if not exists (
    select 1
    from public.machines
    where id = 54
      and evidence_number = 74
      and qr_token = 'vendsoft-74'
      and location_id = 69
      and machine_type = 'Snack'
  ) then
    raise exception 'EV 74 / Ridera Bohemia nebyl nalezen na očekávaném DB záznamu.';
  end if;
end
$$;

update public.machines
set
  name = 'Europa Snack',
  machine_type = 'Snack',
  sales_tracking_mode = 'telemetry',
  note = 'Přesunuto na Ridera Bohemia a.s. · Ostrava 29. 4. 2026 · přesun z ViaPharma Ostrava. TID 587379.',
  updated_at = now()
where id = 54;

insert into public.machine_external_links (
  machine_id, provider, external_machine_id, telemetry_enabled, note
)
values
  (54, 'IMA', '587379', true, 'TID 587379 pro EV 74 / Europa Snack / Ridera Bohemia.'),
  (54, 'GP',  '587379', true, 'TID 587379 pro EV 74 / Europa Snack / Ridera Bohemia.')
on conflict (provider, external_machine_id) do update
set
  machine_id = excluded.machine_id,
  telemetry_enabled = true,
  note = excluded.note,
  updated_at = now();

update public.products
set
  active = true,
  note = concat_ws(
    ' · ',
    nullif(note, ''),
    'Znovu aktivováno podle aktuálního planogramu EV 74 / Ridera 2026-07-30.'
  ),
  updated_at = now()
where sku = '166'
  and name = 'Studentská pečeť Oplatka s arašídovou náplní v mléčné čokoládě 31g';

update public.machine_planogram_slots
set active = false, updated_at = now()
where machine_id = 54;

insert into public.machine_planogram_slots (
  machine_id, slot_code, product_name, product_sku,
  price_czk, current_units, last_units, capacity_units,
  dex_price_czk, desired_units, target_units, expiry_date, telemetry_key,
  sort_order, active, product_family, product_variant,
  planned_product_name, planned_product_sku, planned_price_czk,
  substitution_policy, allowed_substitutes, operator_instruction, note
)
select
  54,
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
  'Planogram EV 74 / Ridera Bohemia / TID 587379 aktualizován ze souboru 2026-07-30.'
from (values
  ('1',  39::numeric,  5,  6,  6, 39::numeric, 1, '2',    0, 'Big Shock!', 'Exotic', 'Big Shock! Energetický nápoj Exotic 500ml plech', 'exact', null, null, null::date),
  ('2',  27::numeric,  6,  6,  6, 27::numeric, 0, '4',    1, 'Hell', 'Classic', 'Hell Energetický nápoj classic 250ml plech', 'exact', null, null, null::date),
  ('3',  18::numeric,  5,  6,  6, 18::numeric, 1, '163',  2, 'QXE', null, 'QXE Energetický nápoj 250ml plech', 'exact', null, null, null::date),
  ('4',  25::numeric,  5,  6,  6, 24::numeric, 1, '209',  3, 'ZON', 'Různé druhy', 'ZON 500ml PET různé druhy', 'exact', null, null, null::date),
  ('5',  23::numeric,  6,  6,  6, 23::numeric, 0, '6',    4, 'Relax', 'Liči', 'Relax Limonáda liči 330ml plech', 'exact', null, null, null::date),
  ('6',  25::numeric,  3,  6,  6, 25::numeric, 3, '187',  5, 'Staropramen Cool', 'Citron', 'Staropramen Cool citron nealkoholický nápoj z piva 500ml plech', 'exact', null, null, null::date),
  ('7',  30::numeric,  6,  6,  6, 30::numeric, 0, '71',   6, 'Pepsi', 'Cola', 'Pepsi Cola 500ml PET', 'exact', null, null, null::date),
  ('12', 48::numeric,  5,  5,  5, 48::numeric, 0, '190',  7, 'Red Bull', null, 'Red Bull 0,25l', 'exact', null, null, null::date),
  ('13', 28::numeric,  6,  6,  6, 28::numeric, 0, '156',  8, 'Ice Coffee', null, 'Ice Coffee Ledová káva 350ml', 'exact', null, null, null::date),
  ('14', 25::numeric,  6,  6,  6, 25::numeric, 0, '67',   9, 'Nestea', 'Peach', 'Nestea 0,5l různé druhy', 'approved_list', 'Nestea Lemon 0,5l (SKU 275)', 'Přednostně Peach SKU 67; lze použít Lemon SKU 275.', null::date),
  ('15', 24::numeric,  4,  6,  6, 24::numeric, 2, '209', 10, 'ZON', 'Různé druhy', 'ZON 500ml PET různé druhy', 'exact', null, null, null::date),
  ('16', 18::numeric,  6,  6,  6, 18::numeric, 0, '163', 11, 'QXE', null, 'QXE Energetický nápoj 250ml plech', 'exact', null, null, null::date),
  ('17', 32::numeric,  4,  6,  6, 33::numeric, 2, '70',  12, 'Kofola', 'Original', 'Kofola Original 500ml PET', 'exact', null, null, null::date),
  ('18', 30::numeric,  6,  6,  6, 30::numeric, 0, '71',  13, 'Pepsi', 'Cola', 'Pepsi Cola 500ml PET', 'exact', null, null, null::date),
  ('23', 55::numeric,  1,  3,  3, 55::numeric, 2, '155', 14, 'ATM', 'Debrecínská', 'ATM Debrecínská bageta', 'exact', null, 'Při návštěvě ověř dnešní expiraci a neprodejné kusy odepiš.', '2026-07-30'::date),
  ('24', 55::numeric,  3,  3,  3, 55::numeric, 0, '79',  15, 'ATM', 'Belgická', 'ATM - Belgická bageta', 'exact', null, 'Při návštěvě ověř dnešní expiraci a neprodejné kusy odepiš.', '2026-07-30'::date),
  ('25', 55::numeric,  1,  2,  3, 55::numeric, 2, '16',  16, 'ATM', 'Chlebíčkový Labužník', 'ATM - Chlebíčkový Labužník', 'exact', null, 'Při návštěvě ověř dnešní expiraci a neprodejné kusy odepiš.', '2026-07-30'::date),
  ('26', 16::numeric,  5,  5,  5, 19::numeric, 0, '38',  17, 'Havlík', 'Originál', 'Havlík Tyčinky originál 90g', 'exact', null, 'Při návštěvě ověř expiraci a neprodejné kusy odepiš.', '2026-05-05'::date),
  ('27', 25::numeric,  5,  6,  6, 25::numeric, 1, '210', 18, 'Doritos', 'Nachos cheese', 'Doritos Tortillas Chipsy nachos cheese 44g', 'exact', null, 'Při návštěvě ověř expiraci a neprodejné kusy odepiš.', '2026-05-05'::date),
  ('28', 29::numeric,  6,  6,  6, 29::numeric, 0, '207', 19, 'Bad Brambacher', 'Malina', 'Bad Brambacher 0,5l různé druhy', 'exact', null, null, null::date),
  ('29', 29::numeric,  5,  5,  5, 29::numeric, 0, '277', 20, 'DrWitt', 'Mango+citron', 'DrWitt min. voda 0,55l různé druhy', 'approved_list', 'DrWitt citrus SKU 276; DrWitt liči+hruška SKU 200', 'Přednostně mango+citron SKU 277; lze použít citrus 276 nebo liči+hruška 200.', null::date),
  ('34', 26::numeric, 10, 10, 10, 26::numeric, 0, '24',  21, 'Snickers', null, 'Snickers Tyčinka čokoládová 50g', 'exact', null, null, null::date),
  ('35', 26::numeric, 10, 10, 10, 26::numeric, 0, '25',  22, 'Twix', null, 'Twix Tyčinka 50g', 'exact', null, null, null::date),
  ('36', 24::numeric,  8,  8,  8, 24::numeric, 0, '40',  23, 'Margot', null, 'Margot Tyčinka 80g', 'exact', null, null, null::date),
  ('37', 26::numeric,  9, 10, 10, 26::numeric, 1, '36',  24, 'Mila', null, 'Mila Oplatky 50g', 'exact', null, null, null::date),
  ('38',  8::numeric,  8,  8,  8,  8::numeric, 0, '208', 25, 'Alaska', 'Různé druhy', 'Alaska kukuřičné trubičky plněné krémem 18g různé druhy', 'exact', null, null, null::date),
  ('39', 29::numeric, 10, 10, 10, 29::numeric, 0, '28',  26, 'Kinder Bueno', null, 'Kinder Bueno Oplatky 43g', 'exact', null, null, null::date),
  ('40', 14::numeric, 10, 10, 10, 14::numeric, 0, '30',  27, 'Romanca', 'Kakaová náplň', 'Romanca Sušenka s kakaovou náplní 40g', 'exact', null, null, null::date),
  ('45', 20::numeric, 10, 10, 10, 20::numeric, 0, '35',  28, 'Sedita Horalky', 'Arašídové', 'Sedita Horalky Oplatky arašídové 50g', 'exact', null, null, null::date),
  ('46', 11::numeric, 10, 10, 10, 11::numeric, 0, '33',  29, 'Attack', 'Lískooříšková', 'Attack Oplatka lískooříšková 30g', 'exact', null, null, null::date),
  ('47', 23::numeric, 15, 15, 15, 23::numeric, 0, '31',  30, 'Miňonky', 'Oříškové', 'Miňonky Oplatky oříškové 50g', 'exact', null, null, null::date),
  ('48', 28::numeric, 10, 10, 10, 28::numeric, 0, '26',  31, '3Bit', 'Různé druhy', '3Bit tyčinka různé druhy', 'exact', null, null, null::date),
  ('49', 22::numeric,  9, 10, 10, 22::numeric, 1, '27',  32, 'Kit Kat', '4 Fingers', 'Kit Kat 4 Fingers Tyčinka 41,5g', 'exact', null, null, null::date),
  ('50', 15::numeric,  3,  3, 12, 15::numeric, 9, '166', 33, 'Studentská pečeť', 'Arašídová náplň', 'Studentská pečeť Oplatka s arašídovou náplní v mléčné čokoládě 31g', 'exact', null, null, null::date),
  ('51', 11::numeric,  9,  9, 10, 11::numeric, 1, '165', 34, 'Knoppers', null, 'Knoppers Oplatka 25g', 'exact', null, null, null::date),
  ('57', 27::numeric,  5,  5,  5, 27::numeric, 0, '20',  35, 'Dupetky', 'Hořčice+med+cibulka', 'Dupetky Snack pečený hořčice+med+cibulka 70g', 'exact', null, null, null::date),
  ('59', 26::numeric, 10, 10, 10, 26::numeric, 0, '39',  36, 'Haribo', 'Goldbären', 'Haribo Bonbóny goldbären želé medvídci 100g', 'exact', null, null, null::date),
  ('61', 13::numeric, 10, 10, 10, 13::numeric, 0, '142', 37, 'Racio Free Style', 'Rajče a bazalka', 'Racio Free Style Chlebíčky rajče a bazalka 25g', 'exact', null, null, null::date)
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
  where machine_id = 54 and active = true;

  if v_count <> 38 then
    raise exception 'EV 74: očekáváno 38 aktivních pozic, nalezeno %.', v_count;
  end if;

  select count(*) into v_links
  from public.machine_external_links
  where machine_id = 54
    and external_machine_id = '587379'
    and telemetry_enabled = true;

  if v_links <> 2 then
    raise exception 'EV 74: očekávány 2 aktivní vazby TID 587379, nalezeno %.', v_links;
  end if;

  select count(*) into v_bad_capacity
  from public.machine_planogram_slots
  where machine_id = 54
    and active = true
    and current_units > capacity_units;

  if v_bad_capacity <> 0 then
    raise exception 'EV 74: nalezeny pozice nad kapacitou: %.', v_bad_capacity;
  end if;
end
$$;

commit;
notify pgrst, 'reload schema';
