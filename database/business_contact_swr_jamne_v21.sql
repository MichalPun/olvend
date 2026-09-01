-- SWR JIHLAVA, spol. s r.o. - odberatelska karta pro partnerskou fakturaci.

begin;

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
  'faktury@swrjihlava.cz',
  '+420 567 277 107',
  'Jamne 48, 588 27 Jamne',
  30,
  'Odberatel partnerskeho vyuctovani lokality SWR Jamne. SWR plati OLVENDu.',
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

update public.partner_billing_profiles profile
set
  business_contact_id = contact.id,
  email_recipient = 'faktury@swrjihlava.cz',
  attachment_mode = 'automatic',
  updated_at = now()
from public.business_contacts contact
where profile.location_id = 29
  and contact.contact_type = 'customer'
  and contact.name_norm = public.olvend_contact_norm('SWR JIHLAVA, spol. s r.o.');

do $$
begin
  if not exists (
    select 1
    from public.business_contacts
    where contact_type = 'customer'
      and name_norm = public.olvend_contact_norm('SWR JIHLAVA, spol. s r.o.')
      and company_id = '25307304'
      and tax_id = 'CZ25307304'
      and email = 'faktury@swrjihlava.cz'
      and active = true
  ) then
    raise exception 'Odberatelska karta SWR nebyla spravne ulozena.';
  end if;
end
$$;

commit;

select
  contact.id,
  contact.contact_type,
  contact.name,
  contact.company_id,
  contact.tax_id,
  contact.email,
  contact.phone,
  contact.billing_address,
  contact.default_due_days,
  contact.active
from public.business_contacts contact
where contact.contact_type = 'customer'
  and contact.name_norm = public.olvend_contact_norm('SWR JIHLAVA, spol. s r.o.');
