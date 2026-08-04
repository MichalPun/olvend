-- AZ KLIMA a.s. · Milovice · měsíční vyúčtování kávového automatu EV 92.
-- Pravidla byla ověřena proti fakturám FV26-0133 a FV26-0149:
--   nápoje 180 ml = 9,92 Kč bez DPH / ks,
--   nápoje 300 ml = 14,88 Kč bez DPH / ks,
--   DPH 21 %, výsledná částka se zaokrouhluje na celé Kč.

begin;

alter table public.partner_billing_profiles
  drop constraint if exists partner_billing_profiles_billing_scope_check;

alter table public.partner_billing_profiles
  add constraint partner_billing_profiles_billing_scope_check
  check (billing_scope in ('all_sales', 'product_category', 'settlement_rules'));

do $$
declare
  v_location_id constant bigint := 40;
  v_machine_id constant bigint := 72;
  v_contact_id constant bigint := 11;
  v_note constant text := 'AZ Klima: sazby ověřené podle FV26-0133 a FV26-0149; 180 ml 9,92 Kč, 300 ml 14,88 Kč bez DPH.';
begin
  if not exists (
    select 1 from public.locations
    where id = v_location_id and name = 'AZ Klima' and city = 'Milovice'
  ) then
    raise exception 'Provozovna AZ Klima / Milovice nebyla nalezena na očekávaném záznamu.';
  end if;

  if not exists (
    select 1 from public.machines
    where id = v_machine_id
      and location_id = v_location_id
      and evidence_number = 92
      and machine_type = 'Coffee'
  ) then
    raise exception 'Kávový automat AZ Klima EV 92 nebyl nalezen na očekávaném záznamu.';
  end if;

  if not exists (
    select 1 from public.business_contacts
    where id = v_contact_id and company_id = '24772631'
  ) then
    raise exception 'Odběratel AZ KLIMA a.s. nebyl nalezen na očekávaném záznamu.';
  end if;

  if (
    select count(*)
    from public.machine_planogram_slots
    where machine_id = v_machine_id
      and active = true
      and slot_code ~ '^([1-9]|1[0-9]|2[0-4])$'
  ) <> 24 then
    raise exception 'Automat AZ Klima EV 92 nemá očekávaných 24 aktivních nápojových tlačítek.';
  end if;

  update public.machine_planogram_slots
  set
    settlement_type = 'subsidy_receivable',
    settlement_amount_czk = case when slot_code::integer <= 12 then 9.92 else 14.88 end,
    settlement_partner = 'AZ KLIMA a.s.',
    settlement_billing_enabled = true,
    settlement_note = v_note,
    subsidy_amount_czk = case when slot_code::integer <= 12 then 9.92 else 14.88 end,
    subsidy_payer = 'AZ KLIMA a.s.',
    subsidy_billing_enabled = true,
    subsidy_note = v_note,
    updated_at = now()
  where machine_id = v_machine_id
    and active = true
    and slot_code ~ '^([1-9]|1[0-9]|2[0-4])$';

  update public.machine_coffee_buttons
  set
    settlement_type = 'subsidy_receivable',
    settlement_amount_czk = case when selection_code::integer <= 12 then 9.92 else 14.88 end,
    settlement_partner = 'AZ KLIMA a.s.',
    settlement_billing_enabled = true,
    settlement_note = v_note,
    updated_at = now()
  where machine_id = v_machine_id
    and active = true
    and selection_code ~ '^([1-9]|1[0-9]|2[0-4])$';
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
  active
)
values (
  40,
  11,
  'Luce X2 I',
  'Vyúčtování vydaných nápojů - {month}/{year}',
  21,
  'integer',
  null,
  'faktury@azklima.com',
  'optional',
  'settlement_rules',
  null,
  'Vydané nápoje',
  'nápojů',
  21,
  0,
  21,
  null,
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

commit;

select
  m.evidence_number,
  s.slot_code,
  s.product_sku,
  s.product_name,
  s.settlement_amount_czk,
  s.settlement_billing_enabled
from public.machine_planogram_slots s
join public.machines m on m.id = s.machine_id
where s.machine_id = 72
  and s.active = true
order by s.slot_code::integer;
