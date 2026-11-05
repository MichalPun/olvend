begin;

-- Rollout schválený 5. 11. 2026:
--   Nestea                 -> FRUC Ice Tea Broskev
--   jedna duplicitní QXE   -> FRUC Ice Tea Lesní plody
--   Staropramen Cool       -> rovnoměrně tři příchutě Fructal First
--   Ice Coffee             -> rovnoměrně tři příchutě FRUC
--
-- Všechny změny jsou řízené doprodejem. Současný produkt, cena a fyzický stav
-- zůstávají aktivní až do potvrzení prázdné pozice operátorem.

do $$
declare
  v_count integer;
  v_details text;
begin
  select count(*) into v_count
  from public.products
  where active is true
    and (sku, ean) in (
      ('0011', '3838945041713'),
      ('0014', '3838945035293'),
      ('0017', '3838945037808'),
      ('0022', '3838945501392'),
      ('0024', '3838945043694'),
      ('0025', '3838945043663'),
      ('0028', '3838945501248'),
      ('0032', '3838945508094')
    );

  if v_count <> 8 then
    raise exception 'Expected 8 active Fructal products with verified EANs, found %.', v_count;
  end if;

  select count(*) into v_count
  from public.machines
  where active is true
    and evidence_number in (71, 94);

  if v_count <> 2 then
    raise exception 'Expected public-price machines EV71 and EV94, found %.', v_count;
  end if;

  select count(*),
         string_agg(machine.evidence_number::text || '/' || slot.slot_code || '=' || slot.pending_product_sku, ', ' order by machine.evidence_number, slot.slot_code)
    into v_count, v_details
  from public.machine_planogram_slots slot
  join public.machines machine on machine.id = slot.machine_id
  where machine.active is true
    and slot.active is true
    and slot.product_sku in ('275', '67', '187', '156', '163')
    and slot.pending_product_sku is not null;

  if v_count <> 0 then
    raise exception 'Target slots already contain pending changes: %', v_details;
  end if;
end
$$;

-- Firemní katalogové ceny. Veřejný režim se nastavuje na pozicích níže.
update public.products
set sale_price = case
      when sku in ('0011', '0014', '0017') then 32
      when sku in ('0022', '0028', '0032') then 35
      when sku in ('0024', '0025') then 32
      else sale_price
    end,
    updated_at = now()
where sku in ('0011', '0014', '0017', '0022', '0024', '0025', '0028', '0032');

create temporary table tmp_fructal_planogram_targets (
  slot_id bigint primary key,
  mapping_key text not null,
  target_product_id bigint not null,
  target_sku text not null,
  target_name text not null,
  target_price_czk numeric(10,2) not null
) on commit drop;

-- Nestea: všechny pozice přejdou po doprodání na broskev.
insert into tmp_fructal_planogram_targets
  (slot_id, mapping_key, target_product_id, target_sku, target_name, target_price_czk)
select
  slot.id,
  'nestea_to_ice_tea_peach',
  product.id,
  product.sku,
  product.name,
  case when machine.evidence_number in (71, 94) then 40 else 32 end
from public.machine_planogram_slots slot
join public.machines machine on machine.id = slot.machine_id
join public.products product on product.sku = '0025' and product.active is true
where machine.active is true
  and slot.active is true
  and slot.product_sku in ('275', '67');

-- Staropramen Cool: tři příchutě First se rozloží 7/7/7.
with ranked as (
  select
    slot.id,
    machine.evidence_number,
    row_number() over (
      order by machine.evidence_number, slot.sort_order nulls last, slot.slot_code, slot.id
    ) as position_no
  from public.machine_planogram_slots slot
  join public.machines machine on machine.id = slot.machine_id
  where machine.active is true
    and slot.active is true
    and slot.product_sku = '187'
), desired as (
  select
    ranked.id as slot_id,
    ranked.evidence_number,
    case (ranked.position_no - 1) % 3
      when 0 then '0011'
      when 1 then '0014'
      else '0017'
    end as target_sku
  from ranked
)
insert into tmp_fructal_planogram_targets
  (slot_id, mapping_key, target_product_id, target_sku, target_name, target_price_czk)
select
  desired.slot_id,
  'cool_to_first',
  product.id,
  product.sku,
  product.name,
  case when desired.evidence_number in (71, 94) then 40 else 32 end
from desired
join public.products product on product.sku = desired.target_sku and product.active is true;

-- Ice Coffee: tři příchutě FRUC se rozloží 9/9/8.
with ranked as (
  select
    slot.id,
    machine.evidence_number,
    row_number() over (
      order by machine.evidence_number, slot.sort_order nulls last, slot.slot_code, slot.id
    ) as position_no
  from public.machine_planogram_slots slot
  join public.machines machine on machine.id = slot.machine_id
  where machine.active is true
    and slot.active is true
    and slot.product_sku = '156'
), desired as (
  select
    ranked.id as slot_id,
    ranked.evidence_number,
    case (ranked.position_no - 1) % 3
      when 0 then '0022'
      when 1 then '0028'
      else '0032'
    end as target_sku
  from ranked
)
insert into tmp_fructal_planogram_targets
  (slot_id, mapping_key, target_product_id, target_sku, target_name, target_price_czk)
select
  desired.slot_id,
  'ice_coffee_to_fruc',
  product.id,
  product.sku,
  product.name,
  case when desired.evidence_number in (71, 94) then 40 else 35 end
from desired
join public.products product on product.sku = desired.target_sku and product.active is true;

-- QXE: pouze poslední z duplicitních pozic na každém automatu. První QXE
-- zůstává beze změny; u automatů s jedinou QXE se nemění nic.
with ranked as (
  select
    slot.id,
    machine.evidence_number,
    count(*) over (partition by slot.machine_id) as qxe_count,
    row_number() over (
      partition by slot.machine_id
      order by slot.sort_order desc nulls last, slot.slot_code desc, slot.id desc
    ) as duplicate_rank
  from public.machine_planogram_slots slot
  join public.machines machine on machine.id = slot.machine_id
  where machine.active is true
    and slot.active is true
    and slot.product_sku = '163'
)
insert into tmp_fructal_planogram_targets
  (slot_id, mapping_key, target_product_id, target_sku, target_name, target_price_czk)
select
  ranked.id,
  'duplicate_qxe_to_ice_tea_forest',
  product.id,
  product.sku,
  product.name,
  case when ranked.evidence_number in (71, 94) then 40 else 32 end
from ranked
join public.products product on product.sku = '0024' and product.active is true
where ranked.qxe_count > 1
  and ranked.duplicate_rank = 1;

do $$
declare
  v_total integer;
  v_nestea integer;
  v_cool integer;
  v_coffee integer;
  v_qxe integer;
  v_public integer;
begin
  select count(*),
         count(*) filter (where mapping_key = 'nestea_to_ice_tea_peach'),
         count(*) filter (where mapping_key = 'cool_to_first'),
         count(*) filter (where mapping_key = 'ice_coffee_to_fruc'),
         count(*) filter (where mapping_key = 'duplicate_qxe_to_ice_tea_forest'),
         count(*) filter (where target_price_czk = 40)
    into v_total, v_nestea, v_cool, v_coffee, v_qxe, v_public
  from tmp_fructal_planogram_targets;

  if (v_total, v_nestea, v_cool, v_coffee, v_qxe, v_public)
     is distinct from (96, 29, 21, 26, 20, 10) then
    raise exception 'Unexpected target counts total/nestea/cool/coffee/qxe/public: %/%/%/%/%/%',
      v_total, v_nestea, v_cool, v_coffee, v_qxe, v_public;
  end if;
end
$$;

-- První krok vyplní cílový produkt a cenu. Ochranný trigger může dočasně
-- nastavit full_swap, protože se cena mění.
update public.machine_planogram_slots slot
set planned_product_name = target.target_name,
    planned_product_sku = target.target_sku,
    planned_price_czk = target.target_price_czk,
    pending_product_id = target.target_product_id,
    pending_product_name = target.target_name,
    pending_product_sku = target.target_sku,
    pending_price_czk = target.target_price_czk,
    pending_change_effective_date = date '2026-11-05',
    pending_change_note = 'Plánovaná náhrada novým sortimentem Fructal po doprodání původního produktu.',
    updated_at = now()
from tmp_fructal_planogram_targets target
where slot.id = target.slot_id;

-- Schválené chování je doprodej. Tento samostatný update už nemění produkt
-- ani cenu, proto záměrně přepíše ochranný full_swap na sell_through.
update public.machine_planogram_slots slot
set pending_change_mode = 'sell_through',
    pending_change_note = format(
      'Doprodej %s a už jej nedoplňuj. Po vyprázdnění vlož %s a nastav cenu %s Kč.',
      slot.product_name,
      target.target_name,
      trim(to_char(target.target_price_czk, 'FM999990D00'))
    ),
    operator_instruction = format(
      'Původní produkt nedoplňuj. Po úplném doprodání vlož %s, na automatu nastav cenu %s Kč a potvrď výměnu v aplikaci.',
      target.target_name,
      trim(to_char(target.target_price_czk, 'FM999990D00'))
    ),
    changeover_old_units = null,
    changeover_new_units = null,
    changeover_started_at = null,
    updated_at = now()
from tmp_fructal_planogram_targets target
where slot.id = target.slot_id;

do $$
declare
  v_wrong integer;
  v_first_distribution integer[];
  v_fruc_distribution integer[];
begin
  select count(*) into v_wrong
  from tmp_fructal_planogram_targets target
  join public.machine_planogram_slots slot on slot.id = target.slot_id
  where slot.pending_product_id is distinct from target.target_product_id
     or slot.pending_product_sku is distinct from target.target_sku
     or slot.pending_product_name is distinct from target.target_name
     or slot.pending_price_czk is distinct from target.target_price_czk
     or slot.planned_product_sku is distinct from target.target_sku
     or slot.planned_price_czk is distinct from target.target_price_czk
     or slot.pending_change_mode is distinct from 'sell_through'
     or slot.changeover_old_units is not null
     or slot.changeover_new_units is not null;

  if v_wrong <> 0 then
    raise exception 'Found % incorrectly prepared Fructal changeover slots.', v_wrong;
  end if;

  select array_agg(quantity order by target_sku)
    into v_first_distribution
  from (
    select target_sku, count(*)::integer as quantity
    from tmp_fructal_planogram_targets
    where mapping_key = 'cool_to_first'
    group by target_sku
  ) distribution;

  if v_first_distribution is distinct from array[7, 7, 7] then
    raise exception 'Unexpected First distribution: %', v_first_distribution;
  end if;

  select array_agg(quantity order by target_sku)
    into v_fruc_distribution
  from (
    select target_sku, count(*)::integer as quantity
    from tmp_fructal_planogram_targets
    where mapping_key = 'ice_coffee_to_fruc'
    group by target_sku
  ) distribution;

  if v_fruc_distribution is distinct from array[9, 9, 8] then
    raise exception 'Unexpected FRUC distribution: %', v_fruc_distribution;
  end if;
end
$$;

commit;

notify pgrst, 'reload schema';
