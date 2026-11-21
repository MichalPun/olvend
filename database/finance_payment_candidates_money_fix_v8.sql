begin;

-- Faktury importované z Money mohou mít už dříve vytvořený úplný nebo částečný
-- příkaz k úhradě. Tyto položky musí snížit částku, kterou lze zadat znovu.
create or replace view public.finance_payment_candidates_v1 with (security_invoker=true) as
with invoice_orders as (
  select i.invoice_id,sum(i.amount) active_amount
  from public.finance_payment_batch_items i
  join public.finance_payment_batches b on b.id=i.batch_id
  where i.invoice_id is not null
    and i.status not in ('rejected','cancelled') and b.status<>'cancelled'
  group by i.invoice_id
), liability_orders as (
  select i.liability_id,sum(i.amount) active_amount
  from public.finance_payment_batch_items i
  join public.finance_payment_batches b on b.id=i.batch_id
  where i.liability_id is not null and i.source_kind='olvend'
    and i.status not in ('rejected','cancelled') and b.status<>'cancelled'
  group by i.liability_id
)
select 'invoice'::text target_type,i.id target_id,i.internal_number reference,
  i.supplier_name payee_name,coalesce(i.document_number,i.internal_number) description,
  i.due_date,i.currency,abs(i.total_amount) total_amount,
  greatest(coalesce(i.operational_remaining_amount,i.money_remaining_amount,abs(i.total_amount)),0) actual_remaining_amount,
  coalesce(o.active_amount,0) active_ordered_amount,
  greatest(coalesce(i.operational_remaining_amount,i.money_remaining_amount,abs(i.total_amount))-coalesce(o.active_amount,0),0) available_amount,
  coalesce(nullif(i.bank_account,''),p.creditor_account) bank_account,
  coalesce(nullif(i.bank_code,''),p.creditor_bank_code,
    nullif(substring(coalesce(i.bank_account,p.creditor_account) from '/([0-9]{4})$'),'')) bank_code,
  coalesce(nullif(i.variable_symbol,''),p.variable_symbol) variable_symbol,
  coalesce(nullif(i.constant_symbol,''),p.constant_symbol) constant_symbol,
  coalesce(nullif(i.specific_symbol,''),p.specific_symbol) specific_symbol,
  coalesce(nullif(i.payment_message,''),p.message,i.document_number) payment_message,
  i.payment_status,i.accounting_status
from public.finance_received_invoices i
left join invoice_orders o on o.invoice_id=i.id
left join lateral (
  select x.creditor_account,x.creditor_bank_code,x.variable_symbol,x.constant_symbol,x.specific_symbol,x.message
  from public.finance_payment_batch_items x where x.invoice_id=i.id
  order by x.id desc limit 1
) p on true
where i.payment_status not in ('paid','overpaid','cancelled')
union all
select 'liability'::text,l.id,l.internal_number,
  coalesce(l.payee_name,l.description),l.description,l.due_date,l.currency,abs(l.total_amount),
  greatest(l.actual_remaining_amount-l.bank_confirmed_amount,0),
  greatest(l.ordered_amount,0)+coalesce(o.active_amount,0),
  greatest(l.orderable_remaining_amount-coalesce(o.active_amount,0),0),
  coalesce(nullif(l.bank_account,''),p.creditor_account),
  coalesce(nullif(l.bank_code,''),p.creditor_bank_code,
    nullif(substring(coalesce(l.bank_account,p.creditor_account) from '/([0-9]{4})$'),'')),
  coalesce(nullif(l.variable_symbol,''),p.variable_symbol),
  coalesce(nullif(l.constant_symbol,''),p.constant_symbol),
  coalesce(nullif(l.specific_symbol,''),p.specific_symbol),
  coalesce(nullif(l.payment_message,''),p.message,l.description),
  l.payment_status,l.accounting_status
from public.finance_liabilities l
left join liability_orders o on o.liability_id=l.id
left join lateral (
  select x.creditor_account,x.creditor_bank_code,x.variable_symbol,x.constant_symbol,x.specific_symbol,x.message
  from public.finance_payment_batch_items x where x.liability_id=l.id
  order by x.id desc limit 1
) p on true
where l.payment_status not in ('paid','overpaid','cancelled');

comment on view public.finance_payment_candidates_v1 is
  'Společný výběr faktur a závazků; aktivní příkazy z OLVENDU i Money zabraňují opakované úhradě faktury.';

notify pgrst,'reload schema';
commit;
