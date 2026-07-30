-- Aktuální planogram EV 9 / Europa Snack / Milovice - AZ Klima.
-- Zdroj: Planogram [9] Europa Snack-2026-07-30.xlsx.
-- TID 597849; expirace se přebírají přesně ze zdrojového souboru.
-- Obecné varianty:
--   slot 13 Nestea -> primární Peach SKU 67, povolená náhrada Lemon SKU 275
--   slot 28 Bad Brambacher -> Malina SKU 207

begin;

do $$
begin
  if not exists (
    select 1
    from public.machines
    where id = 6
      and qr_token = 'vendsoft-9'
      and location_id = 40
  ) then
    raise exception 'EV 9 / Milovice - AZ Klima nebyl nalezen na očekávaném DB záznamu.';
  end if;
end
$$;

insert into public.machine_external_links (
  machine_id, provider, external_machine_id, telemetry_enabled, note
)
values
  (6, 'IMA', '597849', true, 'TID 597849 pro EV 9 / Europa Snack / Milovice - AZ Klima.'),
  (6, 'GP',  '597849', true, 'TID 597849 pro EV 9 / Europa Snack / Milovice - AZ Klima.')
on conflict (provider, external_machine_id) do update
set
  machine_id = excluded.machine_id,
  telemetry_enabled = true,
  note = excluded.note,
  updated_at = now();

update public.machine_planogram_slots
set active = false, updated_at = now()
where machine_id = 6;

insert into public.machine_planogram_slots (
  machine_id, slot_code, product_name, product_sku,
  price_czk, current_units, last_units, capacity_units,
  dex_price_czk, desired_units, target_units, expiry_date, telemetry_key,
  sort_order, active, product_family, product_variant,
  planned_product_name, planned_product_sku, planned_price_czk,
  substitution_policy, allowed_substitutes, operator_instruction, note
)
select
  6,
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
  'Planogram EV 9 / Milovice - AZ Klima / TID 597849 aktualizován ze souboru 2026-07-30.'
from (values
  ('1',  19::numeric,  2,  5,  6, 19::numeric, 4, '163',  0, 'QXE', null, 'QXE Energetický nápoj 250ml plech', 'exact', null, null, null::date),
  ('2',  27::numeric,  6,  6,  6, 27::numeric, 0, '4',    1, 'Hell', 'Classic', 'Hell Energetický nápoj classic 250ml plech', 'exact', null, null, null::date),
  ('3',  48::numeric,  6,  6,  6, 48::numeric, 0, '190',  2, 'Red Bull', null, 'Red Bull 0,25l', 'exact', null, null, null::date),
  ('4',  25::numeric,  6,  6,  6, 25::numeric, 0, '6',    3, 'Relax', 'Liči', 'Relax Limonáda liči 330ml plech', 'exact', null, null, null::date),
  ('5',  15::numeric,  5,  6,  6, 15::numeric, 1, '41',   4, 'Capri-Sun', 'Multivitamin', 'Capri-Sun Multivitamin ovocný nápoj 200ml', 'exact', null, null, null::date),
  ('6',  23::numeric,  6,  6,  6, 23::numeric, 0, '157',  5, 'Pepsi', 'Cola', 'Pepsi 0,33l plech', 'exact', null, null, null::date),
  ('12', 33::numeric,  4,  6,  6, 33::numeric, 2, '71',   6, 'Pepsi', 'Cola', 'Pepsi Cola 500ml PET', 'exact', null, null, null::date),
  ('13', 30::numeric,  6,  6,  6, 30::numeric, 0, '67',   7, 'Nestea', 'Peach', 'Nestea 0,5l různé druhy', 'approved_list', 'Nestea Lemon 0,5l (SKU 275)', 'Přednostně Peach SKU 67; lze použít Lemon SKU 275.', null::date),
  ('14', 32::numeric,  5,  6,  6, 32::numeric, 1, '70',   8, 'Kofola', 'Original', 'Kofola Original 500ml PET', 'exact', null, null, null::date),
  ('15', 24::numeric,  5,  6,  6, 24::numeric, 1, '209',  9, 'ZON', 'Různé druhy', 'ZON 500ml PET různé druhy', 'exact', null, null, null::date),
  ('16', 29::numeric,  5,  6,  6, 29::numeric, 1, '156', 10, 'Ice Coffee', null, 'Ice Coffee Ledová káva 350ml', 'exact', null, null, null::date),
  ('17', 39::numeric,  5,  6,  6, 39::numeric, 1, '2',   11, 'Big Shock!', 'Exotic', 'Big Shock! Energetický nápoj Exotic 500ml plech', 'exact', null, null, null::date),
  ('23', 55::numeric,  3,  6,  6, 55::numeric, 3, '278', 12, 'ATM', 'Masové koule', 'ATM - Masové koule', 'exact', null, null, '2026-08-04'::date),
  ('24', 55::numeric,  0,  6,  6, 55::numeric, 6, '17',  13, 'ATM', 'Kuřecí stripsy', 'ATM - Kuřecí stripsy', 'exact', null, null, '2026-08-04'::date),
  ('25', 55::numeric,  4,  6,  6, 55::numeric, 2, '154', 14, 'ATM', 'Trhané vepřové', 'ATM Trhané Vepřové', 'exact', null, null, '2026-08-04'::date),
  ('26', 19::numeric,  5,  5,  6, 19::numeric, 1, '38',  15, 'Havlík', 'Originál', 'Havlík Tyčinky originál 90g', 'exact', null, null, '2025-08-20'::date),
  ('27', 25::numeric,  6,  6,  6, 25::numeric, 0, '210', 16, 'Doritos', 'Nachos cheese', 'Doritos Tortillas Chipsy nachos cheese 44g', 'exact', null, null, '2025-08-20'::date),
  ('28', 29::numeric,  3,  6,  6, 29::numeric, 3, '207', 17, 'Bad Brambacher', 'Malina', 'Bad Brambacher 0,5l různé druhy', 'exact', null, null, null::date),
  ('34', 26::numeric, 12, 15, 15, 26::numeric, 3, '36',  18, 'Mila', null, 'Mila Oplatky 50g', 'exact', null, null, null::date),
  ('35', 20::numeric, 14, 15, 15, 20::numeric, 1, '35',  19, 'Sedita Horalky', 'Arašídové', 'Sedita Horalky Oplatky arašídové 50g', 'exact', null, null, null::date),
  ('36', 11::numeric, 12, 15, 15, 11::numeric, 3, '33',  20, 'Attack', 'Lískooříšková', 'Attack Oplatka lískooříšková 30g', 'exact', null, null, null::date),
  ('37', 30::numeric, 11, 11, 15, 30::numeric, 4, '28',  21, 'Kinder Bueno', null, 'Kinder Bueno Oplatky 43g', 'exact', null, null, null::date),
  ('38', 25::numeric, 17, 20, 20, 25::numeric, 3, '40',  22, 'Margot', null, 'Margot Tyčinka 80g', 'exact', null, null, null::date),
  ('39',  8::numeric, 14, 14, 14,  8::numeric, 0, '208', 23, 'Alaska', 'Různé druhy', 'Alaska kukuřičné trubičky plněné krémem 18g různé druhy', 'exact', null, null, null::date),
  ('45', 24::numeric, 15, 15, 15, 24::numeric, 0, '27',  24, 'Kit Kat', '4 Fingers', 'Kit Kat 4 Fingers Tyčinka 41,5g', 'exact', null, null, null::date),
  ('46', 14::numeric, 14, 14, 15, 14::numeric, 1, '254', 25, 'Dr.Ensa', 'Barbecue', 'Dr.Ensa Kukuřice pražená solená s příchutí barbecue 60g', 'exact', null, null, null::date),
  ('47', 11::numeric, 19, 20, 20, 11::numeric, 1, '165', 26, 'Knoppers', null, 'Knoppers Oplatka 25g', 'exact', null, null, null::date),
  ('48', 24::numeric, 20, 20, 20, 24::numeric, 0, '31',  27, 'Miňonky', 'Oříškové', 'Miňonky Oplatky oříškové 50g', 'exact', null, null, null::date),
  ('49', 30::numeric, 19, 20, 20, 30::numeric, 1, '26',  28, '3Bit', 'Různé druhy', '3Bit tyčinka různé druhy', 'exact', null, null, null::date),
  ('50', 21::numeric, 15, 15, 15, 21::numeric, 0, '261', 29, 'Corny Big', 'Banán', 'Corny Big Tyčinka banány v mléčné čokoládě 50g', 'exact', null, null, null::date),
  ('57', 27::numeric,  8,  8,  8, 27::numeric, 0, '39',  30, 'Haribo', 'Goldbären', 'Haribo Bonbóny goldbären želé medvídci 100g', 'exact', null, null, null::date),
  ('59', 20::numeric,  7, 10, 10, 20::numeric, 3, '42',  31, '7days', 'Lískový oříšek', '7days Croissant lískový oříšek 60g', 'exact', null, null, null::date),
  ('61', 21::numeric,  7,  8,  8, 21::numeric, 1, '144', 32, 'Yoohoo!', 'Kakao+lískový oříšek', 'Yoohoo! Vafle kakao+lískový oříšek 50', 'exact', null, null, null::date)
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
  where machine_id = 6 and active = true;

  if v_count <> 33 then
    raise exception 'EV 9: očekáváno 33 aktivních pozic, nalezeno %.', v_count;
  end if;
end
$$;

commit;
notify pgrst, 'reload schema';
