-- Kombinované partnerské vyúčtování: sazba za vybranou kategorii + měsíční fix.

alter table public.partner_billing_profiles
  add column if not exists billing_scope text not null default 'all_sales'
    check (billing_scope in ('all_sales', 'product_category')),
  add column if not exists product_category_filter text,
  add column if not exists quantity_label text not null default 'Vydané porce',
  add column if not exists quantity_unit text not null default 'porcí',
  add column if not exists unit_vat_rate numeric(5,2),
  add column if not exists fixed_monthly_amount numeric(14,2) not null default 0
    check (fixed_monthly_amount >= 0),
  add column if not exists fixed_vat_rate numeric(5,2) not null default 21,
  add column if not exists fixed_description_template text;

-- ViaPharma Ostrava: 20 Kč bez DPH za každé vydané hotové jídlo/bagetu.
update public.location_financial_rules
set
  scope_type = 'location',
  settlement_type = 'per_unit',
  amount = 20,
  currency = 'CZK',
  unit = 'bageta',
  periodicity = 'monthly',
  note = 'ViaPharma Ostrava: doplatek 20 Kč bez DPH za každé vydané hotové jídlo/bagetu.',
  updated_at = now()
where location_id = 50
  and direction = 'from_partner'
  and settlement_type in ('subsidy', 'per_unit')
  and coalesce(valid_to, date '9999-12-31') >= date '2026-01-01';

insert into public.location_financial_rules (
  location_id, scope_type, settlement_type, direction, amount, currency,
  unit, periodicity, valid_from, note
)
select
  50, 'location', 'per_unit', 'from_partner', 20, 'CZK',
  'bageta', 'monthly', date '2026-01-01',
  'ViaPharma Ostrava: doplatek 20 Kč bez DPH za každé vydané hotové jídlo/bagetu.'
where not exists (
  select 1
  from public.location_financial_rules rule
  where rule.location_id = 50
    and rule.direction = 'from_partner'
    and rule.settlement_type in ('subsidy', 'per_unit')
    and coalesce(rule.valid_to, date '9999-12-31') >= date '2026-01-01'
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
  active
)
values (
  50,
  5,
  'FAS 1050 + rhFS1 touch',
  'Doplatek za prodané bagety – {month}/{year}',
  12,
  'integer',
  null,
  'fakturace@viapharma.cz',
  'optional',
  'product_category',
  'food_ready',
  'Prodané bagety',
  'baget',
  12,
  3000,
  21,
  'Fixní poplatek za umístění automatu – {month}/{year}',
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
  active = true,
  updated_at = now();
