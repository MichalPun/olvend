begin;

-- OLVEND přebírá po cut-over přidělování interní řady přijatých faktur Money.
-- Originální číslo dodavatele zůstává v document_number; FPYYNNNN je interní evidence.
create or replace function public.finance_next_money_invoice_number_v1(p_issue_date date default null)
returns text
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare
  v_year text:=to_char(coalesce(p_issue_date,current_date),'YY');
  v_sequence integer;
begin
  perform pg_advisory_xact_lock(hashtext('finance-money-invoice-'||v_year));
  select coalesce(max(candidate),0)+1 into v_sequence
  from (
    select substring(i.internal_number from ('^FP'||v_year||'([0-9]+)$'))::integer candidate
    from public.finance_received_invoices i
    where i.internal_number~('^FP'||v_year||'[0-9]+$')
    union all
    select i.money_series_number
    from public.finance_received_invoices i
    where i.money_series_number is not null
      and (i.money_series='FPrr' or i.money_internal_number~('^FP'||v_year||'[0-9]+$'))
  ) numbers;
  if v_sequence>9999 then raise exception 'Číselná řada FP% je vyčerpaná.',v_year; end if;
  return 'FP'||v_year||lpad(v_sequence::text,4,'0');
end;
$$;

revoke all on function public.finance_next_money_invoice_number_v1(date) from public,anon,authenticated;
grant execute on function public.finance_next_money_invoice_number_v1(date) to service_role;

create or replace function public.finance_assign_internal_number_v1()
returns trigger
language plpgsql
security definer
set search_path=public,pg_temp
as $$
begin
  if new.internal_number is null then
    new.internal_number:=public.finance_next_money_invoice_number_v1(new.issue_date);
    new.money_internal_number:=new.internal_number;
    new.money_series:='FPrr';
    new.money_series_number:=substring(new.internal_number from '^FP[0-9]{2}([0-9]+)$')::integer;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_finance_invoice_number on public.finance_received_invoices;
create trigger trg_finance_invoice_number
before insert on public.finance_received_invoices
for each row execute function public.finance_assign_internal_number_v1();

comment on function public.finance_next_money_invoice_number_v1(date) is
  'Atomicky vrátí další interní číslo řady přijatých faktur Money ve formátu FPYYNNNN.';
comment on function public.finance_assign_internal_number_v1() is
  'Novým fakturám z OLVEND přiděluje interní evidenční číslo navazující na řadu Money.';

notify pgrst,'reload schema';
commit;
