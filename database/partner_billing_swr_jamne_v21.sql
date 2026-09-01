-- SWR JIHLAVA, spol. s r.o. / Jamne: partner plati OLVENDu za vydane porce.
-- Ověřeno podle historicke FV260090: 4,13 Kc bez DPH za porci, DPH 21 %.

begin;

do $$
begin
  if not exists (
    select 1
    from public.locations
    where id = 29
      and name = 'SWR'
      and city = 'Jamné'
      and active = true
  ) then
    raise exception 'Provozovna SWR / Jamne nebyla nalezena na ocekavanem zaznamu.';
  end if;

  if not exists (
    select 1
    from public.machines
    where id = 50
      and location_id = 29
      and evidence_number = 67
      and machine_type = 'Coffee'
      and active = true
  ) then
    raise exception 'Kavovy automat SWR EV 67 nebyl nalezen na ocekavanem zaznamu.';
  end if;

  if not exists (
    select 1
    from public.machine_external_links
    where machine_id = 50
      and provider = 'IMA'
      and external_machine_id = '596506'
      and telemetry_enabled = true
  ) then
    raise exception 'SWR EV 67 nema aktivni IMA telemetrii TID 596506.';
  end if;
end
$$;

insert into public.business_contacts (
  contact_type,
  name,
  name_norm,
  company_id,
  tax_id,
  email,
  phone,
  billing_address,
  default_due_days,
  note,
  active,
  source
)
values (
  'customer',
  'SWR JIHLAVA, spol. s r.o.',
  public.olvend_contact_norm('SWR JIHLAVA, spol. s r.o.'),
  '25307304',
  'CZ25307304',
  'obchod@swrjihlava.cz',
  '+420 567 277 107',
  'Jamné 48, 588 27 Jamné',
  30,
  'Partner hradi OLVENDu 4,13 Kc bez DPH za kazdou vydanou porci v automatu EV 67.',
  true,
  'partner_billing_swr'
)
on conflict (contact_type, name_norm) do update set
  name = excluded.name,
  company_id = excluded.company_id,
  tax_id = excluded.tax_id,
  email = excluded.email,
  phone = excluded.phone,
  billing_address = excluded.billing_address,
  default_due_days = excluded.default_due_days,
  note = excluded.note,
  active = true,
  source = excluded.source,
  updated_at = now();

update public.location_financial_rules
set
  scope_type = 'location',
  settlement_type = 'per_unit',
  direction = 'from_partner',
  amount = 4.13,
  currency = 'CZK',
  unit = 'porce',
  periodicity = 'monthly',
  valid_from = date '2025-12-01',
  valid_to = null,
  note = 'SWR plati OLVENDu 4,13 Kc bez DPH za kazdou vydanou porci; dle historicke FV260090.',
  updated_at = now()
where location_id = 29
  and direction = 'from_partner'
  and settlement_type in ('subsidy', 'per_unit');

insert into public.location_financial_rules (
  location_id, scope_type, settlement_type, direction, amount, currency,
  unit, periodicity, valid_from, note
)
select
  29, 'location', 'per_unit', 'from_partner', 4.13, 'CZK',
  'porce', 'monthly', date '2025-12-01',
  'SWR plati OLVENDu 4,13 Kc bez DPH za kazdou vydanou porci; dle historicke FV260090.'
where not exists (
  select 1
  from public.location_financial_rules
  where location_id = 29
    and direction = 'from_partner'
    and settlement_type in ('subsidy', 'per_unit')
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
  29,
  contact.id,
  'X1 E',
  'Úhrada za umístění zařízení {device} - {month}/{year}',
  21,
  'integer',
  null,
  'obchod@swrjihlava.cz',
  'automatic',
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
  date '2025-12-01',
  'Fakturace podle autoritativní IMA/DEX telemetrie EV 67 / TID 596506. Partner platí OLVENDu.',
  true
from public.business_contacts contact
where contact.contact_type = 'customer'
  and contact.name_norm = public.olvend_contact_norm('SWR JIHLAVA, spol. s r.o.')
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
  v_august_quantity numeric;
begin
  select coalesce(sum(quantity), 0)
  into v_august_quantity
  from public.telemetry_sales_events
  where machine_id = 50
    and lower(provider) like '%ima%'
    and source_event_at >= timestamptz '2026-08-01 00:00:00+02'
    and source_event_at < timestamptz '2026-09-01 00:00:00+02';

  if v_august_quantity <> 564 then
    raise exception 'Kontrola SWR srpen selhala: % porci; ocekavano 564.', v_august_quantity;
  end if;

  if not exists (
    select 1
    from public.partner_billing_profiles profile
    join public.location_financial_rules rule
      on rule.location_id = profile.location_id
     and rule.direction = 'from_partner'
     and rule.settlement_type = 'per_unit'
     and rule.valid_from = date '2025-12-01'
     and rule.valid_to is null
    join public.business_contacts contact
      on contact.id = profile.business_contact_id
    where profile.location_id = 29
      and profile.active = true
      and profile.billing_scope = 'all_sales'
      and profile.billing_data_complete_from = date '2025-12-01'
      and rule.amount = 4.13
      and contact.company_id = '25307304'
  ) then
    raise exception 'Partnersky profil nebo sazba SWR nejsou nastavene spravne.';
  end if;
end
$$;

commit;

select
  profile.location_id,
  contact.name as customer,
  contact.company_id,
  profile.email_recipient,
  profile.invoice_description_template,
  rule.direction,
  rule.amount as rate_czk,
  564::numeric as august_quantity,
  round(564 * rule.amount, 2) as august_net_czk,
  round(round(564 * rule.amount, 2) * 1.21) as august_gross_rounded_czk
from public.partner_billing_profiles profile
join public.business_contacts contact on contact.id = profile.business_contact_id
join public.location_financial_rules rule
  on rule.location_id = profile.location_id
 and rule.direction = 'from_partner'
 and rule.settlement_type = 'per_unit'
 and rule.valid_to is null
where profile.location_id = 29;
