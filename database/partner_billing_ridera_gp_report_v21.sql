-- Ridera Bohemia a.s. · vyúčtování podle povinného A5 reportu Global Payments.
-- Do faktury patří všechny řádky označené kartou 1942026 nebo názvem Ridera.
-- XLSX je povinný vstup pro výpočet; partner dostává automaticky filtrovaný PDF podklad.

begin;

alter table public.partner_billing_profiles
  drop constraint if exists partner_billing_profiles_billing_scope_check;

alter table public.partner_billing_profiles
  add constraint partner_billing_profiles_billing_scope_check
  check (billing_scope in ('all_sales', 'product_category', 'settlement_rules', 'external_report'));

alter table public.partner_billing_profiles
  add column if not exists external_report_provider text,
  add column if not exists external_report_required boolean not null default false,
  add column if not exists external_report_filter jsonb not null default '{}'::jsonb,
  add column if not exists external_report_machine_id bigint references public.machines (id) on delete set null;

alter table public.partner_billing_profiles
  drop constraint if exists partner_billing_profiles_external_report_filter_check;

alter table public.partner_billing_profiles
  add constraint partner_billing_profiles_external_report_filter_check
  check (jsonb_typeof(external_report_filter) = 'object');

do $$
begin
  if not exists (
    select 1
    from public.locations
    where id = 69
      and name = 'Ridera Bohemia a.s.'
      and city = 'Ostrava'
      and active = true
  ) then
    raise exception 'Provozovna Ridera Bohemia a.s. / Ostrava nebyla nalezena na očekávaném záznamu.';
  end if;

  if not exists (
    select 1
    from public.business_contacts
    where id = 10
      and company_id = '26847833'
      and public.olvend_contact_norm(name) = public.olvend_contact_norm('Ridera Bohemia a.s.')
      and active = true
  ) then
    raise exception 'Odběratel Ridera Bohemia a.s. nebyl nalezen na očekávaném kontaktu.';
  end if;

  if not exists (
    select 1
    from public.machines
    where id = 16
      and location_id = 69
      and evidence_number = 19
      and machine_type = 'Coffee'
      and note like '%592143%'
      and active = true
  ) then
    raise exception 'Kávový automat Ridera EV 19 / UID 592143 nebyl nalezen.';
  end if;

  if not exists (
    select 1
    from public.machines
    where id = 54
      and location_id = 69
      and evidence_number = 74
      and machine_type = 'Snack'
      and note like '%587379%'
      and active = true
  ) then
    raise exception 'Snackový automat Ridera EV 74 / UID 587379 nebyl nalezen.';
  end if;

  if (
    select count(*)
    from public.machine_planogram_slots
    where machine_id = 16
      and active = true
  ) <> 24 then
    raise exception 'Kávový automat Ridera EV 19 nemá očekávaných 24 aktivních voleb.';
  end if;

  if (
    select count(*)
    from public.sales_documents
    where id in (12, 27)
      and customer_name = 'Ridera Bohemia a.s.'
  ) <> 2 then
    raise exception 'Předchozí kontrolní faktury Ridery FV26-0136 a FV26-0151 nebyly nalezeny.';
  end if;
end
$$;

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
  external_report_provider,
  external_report_required,
  external_report_filter,
  external_report_machine_id,
  active
)
values (
  69,
  10,
  'Ridera · EV 19 a EV 74',
  'Prodeje zaměstnancům Ridera - {month}/{year}',
  21,
  'integer',
  null,
  'lubojacky2@ridera.eu',
  'automatic',
  'external_report',
  null,
  'Transakce Ridera',
  'transakcí',
  21,
  0,
  21,
  null,
  'product',
  '{}'::jsonb,
  date '2026-05-01',
  'Jediným autoritativním podkladem je měsíční A5 report Global Payments. Fakturují se všechny řádky označené kartou 1942026 nebo názvem Ridera; ostatní řádky se vyloučí. XLSX se partnerovi neposílá, automaticky se přiloží filtrovaný PDF podklad.',
  'Global Payments',
  true,
  jsonb_build_object(
    'cardValue', '1942026',
    'partnerText', 'Ridera',
    'machineUids', jsonb_build_object(
      '592143', 16,
      '587379', 54
    )
  ),
  16,
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
  external_report_provider = excluded.external_report_provider,
  external_report_required = excluded.external_report_required,
  external_report_filter = excluded.external_report_filter,
  external_report_machine_id = excluded.external_report_machine_id,
  active = true,
  updated_at = now();

do $$
begin
  if not exists (
    select 1
    from public.partner_billing_profiles
    where location_id = 69
      and business_contact_id = 10
      and billing_scope = 'external_report'
      and external_report_provider = 'Global Payments'
      and external_report_required = true
      and external_report_filter ->> 'cardValue' = '1942026'
      and external_report_filter -> 'machineUids' ->> '592143' = '16'
      and email_recipient = 'lubojacky2@ridera.eu'
      and attachment_mode = 'automatic'
      and active = true
  ) then
    raise exception 'Partnerský profil Ridery není nastaven správně.';
  end if;

end
$$;

commit;

select
  profile.location_id,
  contact.name as customer,
  profile.billing_scope,
  profile.external_report_provider,
  profile.external_report_required,
  profile.email_recipient,
  profile.attachment_mode,
  profile.external_report_filter
from public.partner_billing_profiles profile
join public.business_contacts contact on contact.id = profile.business_contact_id
where profile.location_id = 69;
