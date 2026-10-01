-- Keep GP-derived unit prices precise across save/reload and scope Vitar to coffee.
begin;
alter table public.sales_document_items alter column unit_price type numeric(16,6);
alter table public.partner_billing_profiles add column if not exists billing_machine_types text[] not null default '{}';
comment on column public.partner_billing_profiles.billing_machine_types is 'Optional machine type scope for partner billing, including historical machines. Empty means all types.';
do $$
begin
  if (select count(*) from public.machines where id in (121,122) and evidence_number in(125,126) and location_id=60 and machine_type='Coffee') <> 2 then
    raise exception 'Vitar Jetinno identities changed';
  end if;
  if not exists(select 1 from public.location_financial_rules where location_id=60 and direction='from_partner' and settlement_type='per_unit' and amount=4.13 and valid_to is null) then
    raise exception 'Expected Vitar rate missing';
  end if;
  if (select count(*) from public.machine_planogram_slots where machine_id in(121,122) and active=true) <> 36 then
    raise exception 'Expected 36 Jetinno selections';
  end if;
end $$;
update public.partner_billing_profiles set
  billing_machine_types=array['Coffee'],
  device_label='Jetinno JL300 · EV 125 a EV 126',
  machine_line_descriptions=coalesce(machine_line_descriptions,'{}'::jsonb) || jsonb_build_object(
    '121','Provoz kávového automatu Jetinno JL300 (EV 125) - {month}/{year}',
    '122','Provoz kávového automatu Jetinno JL300 (EV 126) - {month}/{year}'),
  updated_at=now()
where location_id=60;
update public.machine_planogram_slots set
  settlement_type='subsidy_receivable',settlement_amount_czk=4.13,
  settlement_partner='VITAR, s.r.o.',settlement_billing_enabled=true,
  settlement_note='VITAR: 4,13 Kč bez DPH za porci, pokračování pravidla provozovny po výměně 4. 9. 2026.',
  subsidy_amount_czk=4.13,subsidy_payer='VITAR, s.r.o.',subsidy_billing_enabled=true,
  updated_at=now()
where machine_id in(121,122) and active=true;
update public.machine_coffee_buttons set
  settlement_type='subsidy_receivable',settlement_amount_czk=4.13,
  settlement_partner='VITAR, s.r.o.',settlement_billing_enabled=true,
  settlement_note='VITAR: 4,13 Kč bez DPH za porci, pokračování pravidla provozovny po výměně 4. 9. 2026.',
  updated_at=now()
where machine_id in(121,122) and active=true;
commit;
