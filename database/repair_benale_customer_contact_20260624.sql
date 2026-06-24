update public.business_contacts
set company_id = '29371384',
    tax_id = 'CZ29371384',
    contact_name = 'Lates',
    email = 'j.lapes@benale.cz',
    phone = '+420 737 641 508',
    billing_address = 'Zemědělská 498, 66463 Žabčice',
    default_due_days = 14,
    source = 'issued_invoice_repair',
    updated_at = now()
where contact_type = 'customer'
  and name_norm = public.olvend_contact_norm('BENALE s.r.o.');
