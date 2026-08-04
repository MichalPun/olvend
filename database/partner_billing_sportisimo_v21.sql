-- SPORTISIMO s.r.o. · měsíční vyúčtování pěti kávových automatů.
-- Sazby jsou převzaté beze změny z FV26-0135 a FV26-0154:
--   34 druhů nápojů, 9,92 / 11,57 / 14,88 Kč bez DPH, DPH 21 %.
-- Kávové automaty EV 27, 29, 89, 98 a 107 jsou zahrnuté.
-- Snackové automaty EV 90 a 99 jsou z tohoto vyúčtování výslovně vyloučené.

begin;

create temporary table sportisimo_rates (
  product_sku text primary key,
  product_name text not null,
  rate numeric(10,2) not null
) on commit drop;

insert into sportisimo_rates (product_sku, product_name, rate)
select
  product.sku,
  regexp_replace(max(item.product_name), '\s*·\s*SKU\s+\S+\s*$', '', 'i'),
  min(item.unit_price)::numeric(10,2)
from public.sales_documents document
join public.sales_document_items item on item.document_id = document.id
join public.products product on product.id = item.product_id
where document.id in (11, 30)
group by product.sku
having count(distinct item.unit_price) = 1
   and count(distinct item.vat_rate) = 1
   and min(item.vat_rate) = 21;

do $$
begin
  if not exists (
    select 1
    from public.locations
    where id = 58
      and name = 'Sportisimo'
      and city = 'Slezská Ostrava-Hrušov'
  ) then
    raise exception 'Provozovna Sportisimo / Slezská Ostrava-Hrušov nebyla nalezena na očekávaném záznamu.';
  end if;

  if (
    select count(*)
    from public.business_contacts
    where id = 15
      and contact_type in ('customer', 'both')
      and active = true
      and public.olvend_contact_norm(name) = public.olvend_contact_norm('SPORTISIMO s.r.o.')
      and email = 'faktury@sportisimo.cz'
  ) <> 1 then
    raise exception 'Odběratel SPORTISIMO s.r.o. nebyl nalezen na očekávaném kontaktu.';
  end if;

  if (
    select count(*)
    from public.machines
    where location_id = 58
      and active = true
      and machine_type = 'Coffee'
      and (id, evidence_number) in ((22, 27), (24, 29), (69, 89), (78, 98), (87, 107))
  ) <> 5 then
    raise exception 'Pět kávových automatů Sportisimo nebylo nalezeno na očekávaných záznamech.';
  end if;

  if (
    select count(*)
    from public.machines
    where location_id = 58
      and active = true
      and machine_type = 'Snack'
      and (id, evidence_number) in ((70, 90), (79, 99))
  ) <> 2 then
    raise exception 'Snackové automaty Sportisimo nebyly nalezeny na očekávaných záznamech.';
  end if;

  if (select count(*) from sportisimo_rates) <> 34 then
    raise exception 'Z historických faktur Sportisimo nebylo odvozeno očekávaných 34 sazeb.';
  end if;

  if exists (
    select 1
    from sportisimo_rates
    where rate not in (9.92, 11.57, 14.88)
  ) then
    raise exception 'Historické faktury Sportisimo obsahují neočekávanou sazbu.';
  end if;

  if (
    select count(*)
    from public.machine_planogram_slots slot
    where slot.machine_id in (22, 24, 69, 78, 87)
      and slot.active = true
  ) <> 120 then
    raise exception 'Kávové automaty Sportisimo nemají očekávaných 120 aktivních voleb.';
  end if;

  if exists (
    select 1
    from public.machine_planogram_slots slot
    where slot.machine_id in (22, 24, 69, 78, 87)
      and slot.active = true
      and not exists (
        select 1 from sportisimo_rates rate where rate.product_sku = slot.product_sku
      )
  ) then
    raise exception 'Aktivní volba kávového automatu Sportisimo nemá sazbu z předchozích faktur.';
  end if;
end
$$;

update public.machine_planogram_slots slot
set
  settlement_type = 'none',
  settlement_amount_czk = 0,
  settlement_partner = null,
  settlement_billing_enabled = false,
  settlement_note = null,
  subsidy_amount_czk = 0,
  subsidy_payer = null,
  subsidy_billing_enabled = false,
  subsidy_note = null,
  updated_at = now()
from public.machines machine
where machine.id = slot.machine_id
  and machine.location_id = 58
  and slot.active = true;

update public.machine_planogram_slots slot
set
  settlement_type = 'subsidy_receivable',
  settlement_amount_czk = rate.rate,
  settlement_partner = 'SPORTISIMO s.r.o.',
  settlement_billing_enabled = true,
  settlement_note = 'SPORTISIMO: sazba podle druhu nápoje; ověřeno podle FV26-0135 a FV26-0154.',
  subsidy_amount_czk = rate.rate,
  subsidy_payer = 'SPORTISIMO s.r.o.',
  subsidy_billing_enabled = true,
  subsidy_note = 'SPORTISIMO: sazba podle druhu nápoje; ověřeno podle FV26-0135 a FV26-0154.',
  updated_at = now()
from sportisimo_rates rate
where slot.machine_id in (22, 24, 69, 78, 87)
  and slot.active = true
  and slot.product_sku = rate.product_sku;

update public.machine_coffee_buttons button
set
  settlement_type = 'none',
  settlement_amount_czk = 0,
  settlement_partner = null,
  settlement_billing_enabled = false,
  settlement_note = null,
  updated_at = now()
where button.machine_id in (22, 24, 69, 78, 87)
  and button.active = true;

update public.machine_coffee_buttons button
set
  settlement_type = 'subsidy_receivable',
  settlement_amount_czk = rate.rate,
  settlement_partner = 'SPORTISIMO s.r.o.',
  settlement_billing_enabled = true,
  settlement_note = 'SPORTISIMO: sazba podle druhu nápoje; ověřeno podle FV26-0135 a FV26-0154.',
  updated_at = now()
from sportisimo_rates rate
where button.machine_id in (22, 24, 69, 78, 87)
  and button.active = true
  and button.product_sku = rate.product_sku;

insert into public.partner_billing_profiles (
  location_id,
  business_contact_id,
  device_label,
  invoice_description_template,
  vat_rate,
  rounding_mode,
  customer_order_number,
  email_recipient,
  attachment_mode,
  billing_scope,
  product_category_filter,
  quantity_label,
  quantity_unit,
  unit_vat_rate,
  fixed_monthly_amount,
  fixed_vat_rate,
  fixed_description_template,
  itemized_grouping,
  machine_line_descriptions,
  billing_data_complete_from,
  billing_data_note,
  active
)
values (
  58,
  15,
  '5× Luce X2',
  'Dotace za prodané porce - {month}/{year}',
  21,
  'integer',
  null,
  'faktury@sportisimo.cz',
  'optional',
  'settlement_rules',
  null,
  'Prodané porce',
  'porcí',
  21,
  0,
  21,
  null,
  'product',
  '{}'::jsonb,
  date '2026-07-01',
  'Vyúčtování zahrnuje pouze kávové automaty EV 27, 29, 89, 98 a 107. Snackové EV 90 a 99 jsou vyloučené. Sazby podle druhu nápoje jsou ověřené z FV26-0135 a FV26-0154; červenec kombinuje historický přenos s navazující IMA/DEX telemetrií.',
  true
)
on conflict (location_id) do update set
  business_contact_id = excluded.business_contact_id,
  device_label = excluded.device_label,
  invoice_description_template = excluded.invoice_description_template,
  vat_rate = excluded.vat_rate,
  rounding_mode = excluded.rounding_mode,
  customer_order_number = excluded.customer_order_number,
  email_recipient = excluded.email_recipient,
  attachment_mode = excluded.attachment_mode,
  billing_scope = excluded.billing_scope,
  product_category_filter = excluded.product_category_filter,
  quantity_label = excluded.quantity_label,
  quantity_unit = excluded.quantity_unit,
  unit_vat_rate = excluded.unit_vat_rate,
  fixed_monthly_amount = excluded.fixed_monthly_amount,
  fixed_vat_rate = excluded.fixed_vat_rate,
  fixed_description_template = excluded.fixed_description_template,
  itemized_grouping = excluded.itemized_grouping,
  machine_line_descriptions = excluded.machine_line_descriptions,
  billing_data_complete_from = excluded.billing_data_complete_from,
  billing_data_note = excluded.billing_data_note,
  active = true,
  updated_at = now();

do $$
declare
  v_quantity numeric;
  v_unpriced_quantity numeric;
  v_net numeric;
  v_vat numeric;
  v_line_count integer;
begin
  if (
    select count(*)
    from public.machine_planogram_slots
    where machine_id in (22, 24, 69, 78, 87)
      and active = true
      and settlement_type = 'subsidy_receivable'
      and settlement_billing_enabled = true
      and settlement_amount_czk > 0
  ) <> 120 then
    raise exception 'Sportisimo nemá po nastavení očekávaných 120 zpoplatněných voleb.';
  end if;

  if exists (
    select 1
    from public.machine_planogram_slots slot
    join public.machines machine on machine.id = slot.machine_id
    where machine.location_id = 58
      and machine.machine_type = 'Snack'
      and slot.active = true
      and slot.settlement_billing_enabled = true
  ) then
    raise exception 'Snackový automat Sportisimo byl omylem zahrnut do vyúčtování.';
  end if;

  if (
    select count(*)
    from public.machine_coffee_buttons
    where machine_id in (22, 24, 69, 78, 87)
      and active = true
      and settlement_type = 'subsidy_receivable'
      and settlement_billing_enabled = true
      and settlement_amount_czk > 0
  ) <> 120 then
    raise exception 'Zrcadlené kávové volby Sportisimo nemají očekávané sazby.';
  end if;

  with july_rows as (
    select
      event.*,
      min(event.source_event_at) filter (where lower(event.provider) like '%ima%')
        over (partition by event.machine_id) as first_ima_at
    from public.telemetry_sales_events event
    where event.machine_id in (22, 24, 69, 78, 87)
      and event.source_event_at >= timestamptz '2026-07-01 00:00:00+02'
      and event.source_event_at < timestamptz '2026-08-01 00:00:00+02'
  ), authoritative as (
    select *
    from july_rows
    where lower(provider) like '%ima%'
       or first_ima_at is null
       or source_event_at < first_ima_at
  ), mapped as (
    select
      event.quantity,
      slot.product_sku,
      slot.settlement_amount_czk as rate,
      slot.id as slot_id,
      slot.settlement_billing_enabled
    from authoritative event
    left join public.machine_planogram_slots slot
      on slot.machine_id = event.machine_id
     and slot.active = true
     and case
       when btrim(slot.slot_code) ~ '^\d+$' then (btrim(slot.slot_code)::numeric)::text
       else btrim(slot.slot_code)
     end = case
       when btrim(event.selection_code) ~ '^\d+$' then (btrim(event.selection_code)::numeric)::text
       else btrim(event.selection_code)
     end
  ), product_totals as (
    select
      product_sku,
      max(rate) as rate,
      sum(quantity) as quantity,
      round(sum(quantity) * max(rate), 2) as net
    from mapped
    where slot_id is not null
      and settlement_billing_enabled = true
      and rate > 0
    group by product_sku
  )
  select
    (select coalesce(sum(quantity), 0) from mapped),
    (select coalesce(sum(quantity), 0) from mapped where slot_id is null or settlement_billing_enabled is distinct from true or rate <= 0),
    coalesce(sum(net), 0),
    coalesce(sum(round(net * 0.21, 2)), 0),
    count(*)
  into v_quantity, v_unpriced_quantity, v_net, v_vat, v_line_count
  from product_totals;

  if v_quantity <> 6736 or v_unpriced_quantity <> 0 then
    raise exception 'Kontrola Sportisimo červenec selhala: % porcí, % bez sazby; očekáváno 6736 a 0.', v_quantity, v_unpriced_quantity;
  end if;

  if v_net <> 83552.67 or v_vat <> 17546.08 or v_line_count <> 34 then
    raise exception 'Kontrola částek Sportisimo selhala: základ %, DPH %, řádky %.', v_net, v_vat, v_line_count;
  end if;

  if round(v_net + v_vat) <> 101099 then
    raise exception 'Zaokrouhlená částka Sportisimo nesedí: %.', round(v_net + v_vat);
  end if;

  if not exists (
    select 1
    from public.partner_billing_profiles
    where location_id = 58
      and business_contact_id = 15
      and billing_scope = 'settlement_rules'
      and itemized_grouping = 'product'
      and email_recipient = 'faktury@sportisimo.cz'
      and attachment_mode = 'optional'
      and active = true
  ) then
    raise exception 'Partnerský profil Sportisimo není nastaven správně.';
  end if;
end
$$;

commit;

select
  profile.location_id,
  contact.name as customer,
  profile.email_recipient,
  profile.attachment_mode,
  profile.billing_scope,
  6736::numeric as july_quantity,
  83552.67::numeric as july_net_czk,
  17546.08::numeric as july_vat_czk,
  101099::numeric as july_gross_rounded_czk
from public.partner_billing_profiles profile
join public.business_contacts contact on contact.id = profile.business_contact_id
where profile.location_id = 58;
