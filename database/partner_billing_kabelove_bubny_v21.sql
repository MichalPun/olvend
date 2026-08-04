-- KABELOVÉ BUBNY A BEDNY, s.r.o. · Velké Meziříčí · partnerské vyúčtování.
-- Ověřeno proti FV26-0153:
--   4,13 Kč bez DPH za každý výdej,
--   popis „Dotace za umístění automatu - 5-6/2026“,
--   DPH 21 % a zaokrouhlení výsledku na celé Kč.
-- Červenec 2026: 507 porcí v historickém měsíčním podkladu + 35 porcí
-- po přechodu na přímou IMA/DEX telemetrii = 542 porcí.

begin;

do $$
begin
  if not exists (
    select 1
    from public.locations
    where id = 62
      and name = 'Kabelové Bubny'
      and city = 'Velké Meziříčí'
  ) then
    raise exception 'Provozovna Kabelové Bubny / Velké Meziříčí nebyla nalezena na očekávaném záznamu.';
  end if;

  if not exists (
    select 1
    from public.machines
    where id = 90
      and location_id = 62
      and evidence_number = 110
      and machine_type = 'Coffee'
      and active = true
  ) then
    raise exception 'Kávový automat Kabelové Bubny EV 110 nebyl nalezen na očekávaném záznamu.';
  end if;

  if (
    select count(*)
    from public.business_contacts
    where contact_type in ('customer', 'both')
      and active = true
      and public.olvend_contact_norm(name) = public.olvend_contact_norm('KABELOVÉ BUBNY A BEDNY, s.r.o.')
  ) <> 1 then
    raise exception 'Odběratel KABELOVÉ BUBNY A BEDNY, s.r.o. nebyl nalezen jednoznačně.';
  end if;
end
$$;

update public.location_financial_rules
set
  scope_type = 'location',
  settlement_type = 'per_unit',
  direction = 'from_partner',
  amount = 4.13,
  currency = 'CZK',
  unit = 'porce',
  periodicity = 'monthly',
  note = 'Kabelové Bubny: 4,13 Kč bez DPH za každý výdej; ověřeno podle FV26-0153.',
  updated_at = now()
where location_id = 62
  and direction = 'from_partner'
  and settlement_type in ('subsidy', 'per_unit')
  and coalesce(valid_to, date '9999-12-31') >= date '2026-05-01';

insert into public.location_financial_rules (
  location_id, scope_type, settlement_type, direction, amount, currency,
  unit, periodicity, valid_from, note
)
select
  62, 'location', 'per_unit', 'from_partner', 4.13, 'CZK',
  'porce', 'monthly', date '2026-05-01',
  'Kabelové Bubny: 4,13 Kč bez DPH za každý výdej; ověřeno podle FV26-0153.'
where not exists (
  select 1
  from public.location_financial_rules rule
  where rule.location_id = 62
    and rule.direction = 'from_partner'
    and rule.settlement_type in ('subsidy', 'per_unit')
    and coalesce(rule.valid_to, date '9999-12-31') >= date '2026-05-01'
);

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
select
  62,
  contact.id,
  'rhFS1 touch 21,5',
  'Dotace za umístění automatu - {month}/{year}',
  21,
  'integer',
  null,
  'info@kabelovebubny.cz',
  'optional',
  'all_sales',
  null,
  'Vydané porce',
  'porcí',
  21,
  0,
  21,
  null,
  'product',
  '{}'::jsonb,
  date '2026-07-01',
  'Červenec 2026: 507 porcí v historickém měsíčním podkladu + 35 porcí po přechodu na IMA/DEX = 542 porcí. Od srpna běží přímá IMA/DEX telemetrie.',
  true
from public.business_contacts contact
where contact.contact_type in ('customer', 'both')
  and contact.active = true
  and public.olvend_contact_norm(contact.name) = public.olvend_contact_norm('KABELOVÉ BUBNY A BEDNY, s.r.o.')
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
begin
  with july_rows as (
    select event.*,
      min(event.source_event_at) filter (where lower(event.provider) like '%ima%')
        over (partition by event.machine_id) as first_ima_at
    from public.telemetry_sales_events event
    where event.machine_id = 90
      and event.source_event_at >= timestamptz '2026-07-01 00:00:00+02'
      and event.source_event_at < timestamptz '2026-08-01 00:00:00+02'
  ), authoritative as (
    select *
    from july_rows
    where lower(provider) like '%ima%'
       or first_ima_at is null
       or source_event_at < first_ima_at
  )
  select coalesce(sum(quantity), 0)
  into v_quantity
  from authoritative;

  if v_quantity <> 542 then
    raise exception 'Kontrola Kabelové Bubny červenec selhala: % porcí; očekáváno 542.', v_quantity;
  end if;

  if not exists (
    select 1
    from public.partner_billing_profiles profile
    join public.location_financial_rules rule
      on rule.location_id = profile.location_id
     and rule.direction = 'from_partner'
     and rule.settlement_type in ('subsidy', 'per_unit')
     and coalesce(rule.valid_to, date '9999-12-31') >= date '2026-07-01'
    where profile.location_id = 62
      and profile.active = true
      and profile.billing_scope = 'all_sales'
      and profile.billing_data_complete_from = date '2026-07-01'
      and rule.amount = 4.13
  ) then
    raise exception 'Partnerský profil nebo sazba Kabelových bubnů nejsou nastavené správně.';
  end if;
end
$$;

commit;

select
  profile.location_id,
  contact.name as customer,
  profile.email_recipient,
  profile.invoice_description_template,
  profile.attachment_mode,
  rule.amount as rate_czk,
  542::numeric as july_quantity,
  round(542 * rule.amount, 2) as july_net_czk,
  round(round(542 * rule.amount, 2) * 1.21) as july_gross_rounded_czk
from public.partner_billing_profiles profile
join public.business_contacts contact on contact.id = profile.business_contact_id
join public.location_financial_rules rule
  on rule.location_id = profile.location_id
 and rule.direction = 'from_partner'
 and rule.settlement_type in ('subsidy', 'per_unit')
 and coalesce(rule.valid_to, date '9999-12-31') >= date '2026-07-01'
where profile.location_id = 62
  and profile.active = true;
