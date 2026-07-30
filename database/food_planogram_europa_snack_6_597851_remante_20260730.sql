-- Aktuální planogram EV 6 / Europa Snack / REMANTE GROUP s.r.o., Otice.
-- Zdroj: Planogram [6] Europa Snack-2026-07-30.xlsx.
-- TID 597851; expirace se přebírají přesně ze zdrojového souboru.
-- Obecné varianty:
--   slot 12 DrWitt -> primární mango+citron SKU 277, náhrady citrus 276 a liči+hruška 200
--   slot 14 Nestea -> primární Peach SKU 67, povolená náhrada Lemon SKU 275
--   slot 29 Bad Brambacher -> Malina SKU 207

begin;

do $$
begin
  if not exists (
    select 1
    from public.machines
    where id = 4
      and qr_token = 'vendsoft-6'
      and location_id = 52
  ) then
    raise exception 'EV 6 / Remante nebyl nalezen na očekávaném DB záznamu.';
  end if;
end
$$;

insert into public.machine_external_links (
  machine_id, provider, external_machine_id, telemetry_enabled, note
)
values
  (4, 'IMA', '597851', true, 'TID 597851 pro EV 6 / Europa Snack / Remante.'),
  (4, 'GP',  '597851', true, 'TID 597851 pro EV 6 / Europa Snack / Remante.')
on conflict (provider, external_machine_id) do update
set
  machine_id = excluded.machine_id,
  telemetry_enabled = true,
  note = excluded.note,
  updated_at = now();

update public.machine_planogram_slots
set active = false, updated_at = now()
where machine_id = 4;

insert into public.machine_planogram_slots (
  machine_id, slot_code, product_name, product_sku,
  price_czk, current_units, last_units, capacity_units,
  dex_price_czk, desired_units, target_units, expiry_date, telemetry_key,
  sort_order, active, product_family, product_variant,
  planned_product_name, planned_product_sku, planned_price_czk,
  substitution_policy, allowed_substitutes, operator_instruction, note
)
select
  4,
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
  'Planogram EV 6 / Remante / TID 597851 aktualizován ze souboru 2026-07-30.'
from (values
  ('1',  39::numeric,  3,  6,  6, 39::numeric, 3, '2',    0, 'Big Shock!', 'Exotic', 'Big Shock! Energetický nápoj Exotic 500ml plech', 'exact', null, null, null::date),
  ('2',  27::numeric,  4,  6,  6, 27::numeric, 2, '4',    1, 'Hell', 'Classic', 'Hell Energetický nápoj classic 250ml plech', 'exact', null, null, null::date),
  ('3',  18::numeric,  4,  6,  6, 18::numeric, 2, '163',  2, 'QXE', null, 'QXE Energetický nápoj 250ml plech', 'exact', null, null, null::date),
  ('4',  23::numeric,  6,  6,  6, 23::numeric, 0, '6',    3, 'Relax', 'Liči', 'Relax Limonáda liči 330ml plech', 'exact', null, null, null::date),
  ('5',  25::numeric,  6,  6,  6, 25::numeric, 0, '187',  4, 'Staropramen Cool', 'Citron', 'Staropramen Cool citron nealkoholický nápoj z piva 500ml plech', 'exact', null, null, null::date),
  ('6',  30::numeric,  5,  6,  6, 30::numeric, 1, '71',   5, 'Pepsi', 'Cola', 'Pepsi Cola 500ml PET', 'exact', null, null, null::date),
  ('12', 29::numeric,  3,  6,  6, 29::numeric, 3, '277',  6, 'DrWitt', 'Mango+citron', 'DrWitt min. voda 0,55l různé druhy', 'approved_list', 'DrWitt citrus SKU 276; DrWitt liči+hruška SKU 200', 'Přednostně mango+citron SKU 277; lze použít citrus 276 nebo liči+hruška 200.', null::date),
  ('13', 28::numeric,  4,  5,  6, 28::numeric, 2, '156',  7, 'Ice Coffee', null, 'Ice Coffee Ledová káva 350ml', 'exact', null, null, null::date),
  ('14', 25::numeric,  3,  6,  6, 25::numeric, 3, '67',   8, 'Nestea', 'Peach', 'Nestea 0,5l různé druhy', 'approved_list', 'Nestea Lemon 0,5l (SKU 275)', 'Přednostně Peach SKU 67; lze použít Lemon SKU 275.', null::date),
  ('15', 46::numeric,  6,  6,  6, 46::numeric, 0, '190',  9, 'Red Bull', null, 'Red Bull 0,25l', 'exact', null, null, null::date),
  ('16', 13::numeric,  4,  6,  6, 13::numeric, 2, '41',  10, 'Capri-Sun', 'Multivitamin', 'Capri-Sun Multivitamin ovocný nápoj 200ml', 'exact', null, null, null::date),
  ('17', 30::numeric,  5,  6,  6, 30::numeric, 1, '71',  11, 'Pepsi', 'Cola', 'Pepsi Cola 500ml PET', 'exact', null, null, null::date),
  ('23', 55::numeric,  1,  5,  6, 55::numeric, 5, '278', 12, 'ATM', 'Masové koule', 'ATM - Masové koule', 'exact', null, null, '2026-08-04'::date),
  ('24', 55::numeric,  4,  6,  6, 55::numeric, 2, '16',  13, 'ATM', 'Chlebíčkový Labužník', 'ATM - Chlebíčkový Labužník', 'exact', null, null, '2026-08-04'::date),
  ('25', 55::numeric,  5,  5,  6, 55::numeric, 1, '17',  14, 'ATM', 'Kuřecí stripsy', 'ATM - Kuřecí stripsy', 'exact', null, null, '2026-08-04'::date),
  ('26', 18::numeric,  1,  6,  6, 18::numeric, 5, '38',  15, 'Havlík', 'Originál', 'Havlík Tyčinky originál 90g', 'exact', null, null, null::date),
  ('27', 27::numeric,  4,  6,  6, 27::numeric, 2, '210', 16, 'Doritos', 'Nachos cheese', 'Doritos Tortillas Chipsy nachos cheese 44g', 'exact', null, null, null::date),
  ('28', 30::numeric,  5,  5,  5, 30::numeric, 0, '279', 17, 'JoJo', 'Arašídy v cukru', 'Jojo Arašídky v cukru dražé 60g', 'exact', null, null, null::date),
  ('29', 28::numeric,  6,  6,  6, 28::numeric, 0, '207', 18, 'Bad Brambacher', 'Malina', 'Bad Brambacher 0,5l různé druhy', 'exact', null, null, null::date),
  ('34', 26::numeric, 15, 15, 15, 26::numeric, 0, '24',  19, 'Snickers', null, 'Snickers Tyčinka čokoládová 50g', 'exact', null, null, null::date),
  ('35', 26::numeric, 13, 13, 13, 26::numeric, 0, '25',  20, 'Twix', null, 'Twix Tyčinka 50g', 'exact', null, null, null::date),
  ('36', 24::numeric,  8, 10, 10, 24::numeric, 2, '40',  21, 'Margot', null, 'Margot Tyčinka 80g', 'exact', null, null, null::date),
  ('37', 26::numeric,  7, 10, 10, 26::numeric, 3, '36',  22, 'Mila', null, 'Mila Oplatky 50g', 'exact', null, null, null::date),
  ('38',  8::numeric,  4, 10, 10,  8::numeric, 6, '208', 23, 'Alaska', 'Různé druhy', 'Alaska kukuřičné trubičky plněné krémem 18g různé druhy', 'exact', null, null, null::date),
  ('39', 29::numeric,  5, 10, 10, 29::numeric, 5, '28',  24, 'Kinder Bueno', null, 'Kinder Bueno Oplatky 43g', 'exact', null, null, null::date),
  ('40', 14::numeric,  6, 10, 10, 14::numeric, 4, '30',  25, 'Romanca', 'Kakaová náplň', 'Romanca Sušenka s kakaovou náplní 40g', 'exact', null, null, null::date),
  ('45', 20::numeric,  8, 10, 10, 20::numeric, 2, '35',  26, 'Sedita Horalky', 'Arašídové', 'Sedita Horalky Oplatky arašídové 50g', 'exact', null, null, null::date),
  ('46', 11::numeric, 10, 10, 12, 11::numeric, 2, '33',  27, 'Attack', 'Lískooříšková', 'Attack Oplatka lískooříšková 30g', 'exact', null, null, null::date),
  ('47', 23::numeric, 10, 10, 10, 23::numeric, 0, '31',  28, 'Miňonky', 'Oříškové', 'Miňonky Oplatky oříškové 50g', 'exact', null, null, null::date),
  ('48', 28::numeric, 10, 10, 10, 28::numeric, 0, '26',  29, '3Bit', 'Různé druhy', '3Bit tyčinka různé druhy', 'exact', null, null, null::date),
  ('49', 22::numeric, 10, 11, 11, 22::numeric, 1, '27',  30, 'Kit Kat', '4 Fingers', 'Kit Kat 4 Fingers Tyčinka 41,5g', 'exact', null, null, null::date),
  ('50', 21::numeric,  9, 10, 10, 21::numeric, 1, '261', 31, 'Corny Big', 'Banán', 'Corny Big Tyčinka banány v mléčné čokoládě 50g', 'exact', null, null, null::date),
  ('51', 11::numeric,  9, 10, 10, 11::numeric, 1, '165', 32, 'Knoppers', null, 'Knoppers Oplatka 25g', 'exact', null, null, null::date),
  ('56', 27::numeric,  3,  4,  6, 27::numeric, 3, '20',  33, 'Dupetky', 'Hořčice+med+cibulka', 'Dupetky Snack pečený hořčice+med+cibulka 70g', 'exact', null, null, null::date),
  ('58', 26::numeric,  9, 10, 10, 26::numeric, 1, '39',  34, 'Haribo', 'Goldbären', 'Haribo Bonbóny goldbären želé medvídci 100g', 'exact', null, null, null::date),
  ('60', 13::numeric,  9,  9,  9, 13::numeric, 0, '142', 35, 'Racio Free Style', 'Rajče a bazalka', 'Racio Free Style Chlebíčky rajče a bazalka 25g', 'exact', null, null, null::date),
  ('62', 20::numeric, 10, 10, 10, 20::numeric, 0, '144', 36, 'Yoohoo!', 'Kakao+lískový oříšek', 'Yoohoo! Vafle kakao+lískový oříšek 50', 'exact', null, null, null::date)
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
begin
  select count(*) into v_count
  from public.machine_planogram_slots
  where machine_id = 4 and active = true;

  if v_count <> 37 then
    raise exception 'EV 6: očekáváno 37 aktivních pozic, nalezeno %.', v_count;
  end if;
end
$$;

commit;
notify pgrst, 'reload schema';
