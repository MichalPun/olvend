begin;

create or replace function public.finance_default_operational_remaining_v1()
returns trigger
language plpgsql
set search_path=public,pg_temp
as $$
begin
  if new.operational_remaining_amount is null then
    new.operational_remaining_amount:=case
      when new.payment_status in ('paid','cancelled') then 0
      when new.money_remaining_amount is not null then greatest(new.money_remaining_amount,0)
      else greatest(abs(new.total_amount)-coalesce(new.bank_confirmed_amount,0),0)
    end;
  end if;
  return new;
end;
$$;

drop trigger if exists finance_received_invoices_default_remaining on public.finance_received_invoices;
create trigger finance_received_invoices_default_remaining
before insert or update of total_amount,payment_status,money_remaining_amount,bank_confirmed_amount,operational_remaining_amount
on public.finance_received_invoices
for each row execute function public.finance_default_operational_remaining_v1();

update public.finance_received_invoices
set operational_remaining_amount=case
  when payment_status in ('paid','cancelled') then 0
  when money_remaining_amount is not null then greatest(money_remaining_amount,0)
  else greatest(abs(total_amount)-coalesce(bank_confirmed_amount,0),0)
end
where operational_remaining_amount is null;

-- PostgreSQL při vytvoření pohledu rozbalí i.* napevno. Sloupce doplněné
-- pozdějšími migracemi se proto do původního pohledu samy nepropsaly.
-- Původní pořadí zachováváme a nové sloupce přidáváme až na konec, takže
-- CREATE OR REPLACE VIEW je bezpečný i pro existující klienty.
create or replace view public.finance_received_invoice_overview_v1
with (security_invoker=true) as
select
  i.id,
  i.internal_number,
  i.source_provider,
  i.source_external_id,
  i.source_event_id,
  i.source_received_at,
  i.source_payload,
  i.supplier_name,
  i.supplier_company_id,
  i.supplier_tax_id,
  i.document_number,
  i.document_type,
  i.issue_date,
  i.taxable_date,
  i.due_date,
  i.currency,
  i.exchange_rate,
  i.net_amount,
  i.vat_amount,
  i.total_amount,
  i.bank_account,
  i.bank_code,
  i.iban,
  i.swift,
  i.variable_symbol,
  i.constant_symbol,
  i.specific_symbol,
  i.payment_message,
  i.category,
  i.cost_center,
  i.owner_employee_id,
  i.extraction_confidence,
  i.extraction_warnings,
  i.status,
  i.payment_status,
  i.handoff_status,
  i.approved_at,
  i.approved_by,
  i.paid_at,
  i.accountant_note,
  i.note,
  i.created_at,
  i.updated_at,
  e.name||' '||e.surname as owner,
  a.file_name as attachment_name,
  a.storage_path as attachment_path,
  a.sha256 as attachment_sha256,
  coalesce((
    select sum(m.matched_amount)
    from public.finance_payment_matches m
    where m.invoice_id=i.id and m.status='confirmed'
  ),0) as matched_amount,
  i.money_guid,
  i.money_internal_number,
  i.money_series,
  i.money_series_number,
  i.money_partner_guid,
  i.money_remaining_amount,
  i.money_source_file_sha256,
  i.money_imported_at,
  i.received_date,
  i.money_payment_method,
  i.accounting_status,
  i.payment_evidence,
  i.operational_remaining_amount,
  i.bank_confirmed_amount,
  i.bank_last_payment_at,
  i.document_class,
  i.stock_receipt_status,
  i.purchase_order_id
from public.finance_received_invoices i
left join public.employees e on e.id=i.owner_employee_id
left join lateral(
  select x.file_name,x.storage_path,x.sha256
  from public.finance_invoice_attachments x
  where x.invoice_id=i.id and x.kind='original'
  order by x.id
  limit 1
) a on true;

grant select on table public.finance_received_invoice_overview_v1 to authenticated;

comment on view public.finance_received_invoice_overview_v1 is
  'Úplný provozní přehled přijatých faktur včetně Money, banky, účetní a skladového workflow.';
comment on function public.finance_default_operational_remaining_v1() is
  'Doplní bezpečný provozní zůstatek nové faktury, pokud jej zdroj výslovně neposkytl.';

notify pgrst,'reload schema';
commit;
