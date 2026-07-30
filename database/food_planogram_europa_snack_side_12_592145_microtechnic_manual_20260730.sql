-- Ruční planogram EV 12 / Europa Snack SIDE / Microtechnic.
-- Zdroj: Planogram [12] Europa Snack SIDE-2026-07-30.xlsx.
-- TID 592145 je ponecháno pouze jako identifikátor. Telemetrie IMA/GP je
-- záměrně vypnutá, protože pro tento automat posílá nespolehlivé hodnoty.
--
-- current_units je výchozí orientační stav ze souboru, omezený fyzickou
-- kapacitou pozice. desired_units je ručně nastavená standardní servisní
-- zásoba, která se po návštěvě automaticky nepřepočítává.

begin;

do $$
begin
  if not exists (
    select 1
    from public.machines
    where id = 9
      and evidence_number = 12
      and qr_token = 'vendsoft-12'
      and location_id = 44
  ) then
    raise exception 'EV 12 / Microtechnic nebyl nalezen na očekávaném DB záznamu.';
  end if;
end
$$;

update public.machines
set
  name = 'Europa Snack SIDE',
  machine_type = 'Snack',
  sales_tracking_mode = 'none',
  note = 'Import z VendSoft exportu; původní kód 12; lokalita Microtechnic POTRAVINY. TID 592145 je pouze identifikační, telemetrie zásob/prodejů je nespolehlivá a automat se obsluhuje ručně.',
  updated_at = now()
where id = 9;

insert into public.machine_external_links (
  machine_id, provider, external_machine_id, telemetry_enabled, note
)
values
  (9, 'IMA', '592145', false, 'EV 12 / Microtechnic: telemetrie záměrně vypnuta, data jsou nespolehlivá; ruční obsluha.'),
  (9, 'GP',  '592145', false, 'EV 12 / Microtechnic: telemetrie záměrně vypnuta, data jsou nespolehlivá; ruční obsluha.')
on conflict (provider, external_machine_id) do update
set
  machine_id = excluded.machine_id,
  telemetry_enabled = false,
  note = excluded.note,
  updated_at = now();

update public.machine_planogram_slots
set active = false, updated_at = now()
where machine_id = 9;

insert into public.machine_planogram_slots (
  machine_id, slot_code, product_name, product_sku,
  price_czk, current_units, last_units, capacity_units,
  dex_price_czk, desired_units, target_units, expiry_date, telemetry_key,
  sort_order, active, product_family, product_variant,
  planned_product_name, planned_product_sku, planned_price_czk,
  substitution_policy, allowed_substitutes, operator_instruction, note
)
select
  9,
  d.slot_code,
  p.name,
  p.sku,
  d.price_czk,
  least(d.current_units, d.capacity_units),
  least(d.last_units, d.capacity_units),
  d.capacity_units,
  d.price_czk,
  d.service_units,
  least(d.capacity_units, least(d.current_units, d.capacity_units) + d.service_units),
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
  'EV 12 / Microtechnic / TID 592145. Ruční režim: bez telemetrického přepočtu; servisní zásoba je ručně nastavený standard.'
from (values
  ('11', 19::numeric,  6,  6,  6, 0, '163',  0, 'QXE', null, 'QXE Energetický nápoj 250ml plech', 'exact', null, null, null::date),
  ('12', 27::numeric,  6,  6,  6, 0, '4',    1, 'Hell', 'Classic', 'Hell Energetický nápoj classic 250ml plech', 'exact', null, null, null::date),
  ('13', 48::numeric,  6,  6,  5, 0, '190',  2, 'Red Bull', null, 'Red Bull 0,25l', 'exact', null, null, null::date),
  ('14', 25::numeric,  6,  6,  6, 0, '6',    3, 'Relax', 'Liči', 'Relax Limonáda liči 330ml plech', 'exact', null, null, null::date),
  ('15', 15::numeric,  6,  6,  6, 0, '41',   4, 'Capri-Sun', 'Multivitamin', 'Capri-Sun Multivitamin ovocný nápoj 200ml', 'exact', null, null, null::date),
  ('16', 23::numeric,  6,  6,  5, 0, '157',  5, 'Pepsi', 'Cola', 'Pepsi 0,33l plech', 'exact', null, null, null::date),
  ('21', 33::numeric,  0,  6,  6, 6, '71',   6, 'Pepsi', 'Cola', 'Pepsi Cola 500ml PET', 'exact', null, null, null::date),
  ('22', 30::numeric,  4,  6,  6, 2, '67',   7, 'Nestea', 'Peach', 'Nestea 0,5l různé druhy', 'approved_list', 'Nestea Lemon 0,5l (SKU 275)', 'Přednostně Peach SKU 67; lze použít Lemon SKU 275.', null::date),
  ('23', 32::numeric,  1,  6,  6, 5, '70',   8, 'Kofola', 'Original', 'Kofola Original 500ml PET', 'exact', null, null, null::date),
  ('24', 24::numeric,  3,  6,  5, 2, '209',  9, 'ZON', 'Různé druhy', 'ZON 500ml PET různé druhy', 'exact', null, null, null::date),
  ('25', 29::numeric,  6,  6,  6, 0, '156', 10, 'Ice Coffee', null, 'Ice Coffee Ledová káva 350ml', 'exact', null, null, null::date),
  ('26', 39::numeric,  6,  6,  5, 0, '2',   11, 'Big Shock!', 'Exotic', 'Big Shock! Energetický nápoj Exotic 500ml plech', 'exact', null, null, null::date),
  ('31', 55::numeric,  4,  4,  6, 2, '155', 12, 'ATM', 'Debrecínská', 'ATM Debrecínská bageta', 'exact', null, null, '2026-08-04'::date),
  ('32', 55::numeric,  4,  4,  6, 2, '16',  13, 'ATM', 'Chlebíčkový Labužník', 'ATM - Chlebíčkový Labužník', 'exact', null, null, '2026-08-04'::date),
  ('33', 55::numeric,  4,  4,  6, 2, '17',  14, 'ATM', 'Kuřecí stripsy', 'ATM - Kuřecí stripsy', 'exact', null, null, '2026-08-06'::date),
  ('34', 19::numeric,  7,  7,  6, 0, '38',  15, 'Havlík', 'Originál', 'Havlík Tyčinky originál 90g', 'exact', null, 'Při první návštěvě ověř expiraci 20.08.2025 a neprodejné kusy odepiš.', '2025-08-20'::date),
  ('35', 25::numeric,  6,  6,  6, 0, '210', 16, 'Doritos', 'Nachos cheese', 'Doritos Tortillas Chipsy nachos cheese 44g', 'exact', null, null, null::date),
  ('36', 29::numeric,  6,  6,  6, 0, '207', 17, 'Bad Brambacher', 'Malina', 'Bad Brambacher 0,5l různé druhy', 'exact', null, null, null::date),
  ('41', 26::numeric, 15, 15, 15, 0, '36',  18, 'Mila', null, 'Mila Oplatky 50g', 'exact', null, null, null::date),
  ('42', 20::numeric, 13, 13, 20, 7, '35',  19, 'Sedita Horalky', 'Arašídové', 'Sedita Horalky Oplatky arašídové 50g', 'exact', null, null, null::date),
  ('43', 11::numeric, 11, 11, 15, 4, '33',  20, 'Attack', 'Lískooříšková', 'Attack Oplatka lískooříšková 30g', 'exact', null, null, null::date),
  ('44', 26::numeric, 12, 12, 20, 8, '24',  21, 'Snickers', null, 'Snickers Tyčinka čokoládová 50g', 'exact', null, null, null::date),
  ('45', 30::numeric, 18, 18, 15, 0, '28',  22, 'Kinder Bueno', null, 'Kinder Bueno Oplatky 43g', 'exact', null, null, null::date),
  ('46',  8::numeric, 15, 15, 15, 0, '208', 23, 'Alaska', 'Různé druhy', 'Alaska kukuřičné trubičky plněné krémem 18g různé druhy', 'exact', null, null, null::date),
  ('47', 10::numeric,  6,  6,  6, 0, '143', 24, 'Today Donut', 'Kakaová náplň', 'Today Donut Dezert s kakaovou náplní v polevě 50g', 'exact', null, null, null::date),
  ('51', 26::numeric, 12, 12, 15, 3, '25',  25, 'Twix', null, 'Twix Tyčinka 50g', 'exact', null, null, null::date),
  ('52', 24::numeric, 10, 10, 15, 5, '27',  26, 'Kit Kat', '4 Fingers', 'Kit Kat 4 Fingers Tyčinka 41,5g', 'exact', null, null, null::date),
  ('53', 11::numeric,  7,  7, 15, 8, '165', 27, 'Knoppers', null, 'Knoppers Oplatka 25g', 'exact', null, null, null::date),
  ('54', 14::numeric, 11, 11, 15, 4, '254', 28, 'Dr.Ensa', 'Barbecue', 'Dr.Ensa Kukuřice pražená solená s příchutí barbecue 60g', 'exact', null, null, null::date),
  ('55', 24::numeric, 15, 15, 15, 0, '31',  29, 'Miňonky', 'Oříškové', 'Miňonky Oplatky oříškové 50g', 'exact', null, null, null::date),
  ('56', 21::numeric, 10, 10, 10, 0, '261', 30, 'Corny Big', 'Banán', 'Corny Big Tyčinka banány v mléčné čokoládě 50g', 'exact', null, null, null::date),
  ('62', 27::numeric, 10, 10, 10, 0, '39',  31, 'Haribo', 'Goldbären', 'Haribo Bonbóny goldbären želé medvídci 100g', 'exact', null, null, null::date),
  ('64', 20::numeric,  8,  8, 10, 2, '42',  32, '7days', 'Lískový oříšek', '7days Croissant lískový oříšek 60g', 'exact', null, null, null::date),
  ('66', 19::numeric,  5,  5,  5, 0, '20',  33, 'Dupetky', 'Hořčice, med a cibulka', 'Dupetky Snack pečený hořčice+med+cibulka 70g', 'exact', null, null, null::date)
) as d(
  slot_code, price_czk, current_units, last_units, capacity_units,
  service_units, product_sku, sort_order,
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
  v_enabled_links integer;
begin
  select count(*) into v_count
  from public.machine_planogram_slots
  where machine_id = 9 and active = true;

  if v_count <> 34 then
    raise exception 'EV 12: očekáváno 34 aktivních pozic, nalezeno %.', v_count;
  end if;

  select count(*) into v_enabled_links
  from public.machine_external_links
  where machine_id = 9 and telemetry_enabled = true;

  if v_enabled_links <> 0 then
    raise exception 'EV 12: telemetrie musí zůstat vypnutá; aktivní vazby %.', v_enabled_links;
  end if;
end
$$;

commit;
notify pgrst, 'reload schema';
