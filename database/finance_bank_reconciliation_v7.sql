-- Bankovní výpis může jednoznačně potvrdit také položku dříve vytvořeného
-- platebního příkazu. To je důležité pro mzdy, splátky a závazky bez VS v
-- základní evidenci. Zároveň vždy dopočítává skutečný zůstatek po částečné úhradě.

create or replace function public.finance_reconcile_bank_import_v2(p_import_sha256 text)
returns jsonb
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare
  v_tx record;
  v_candidate_count integer;
  v_batch_item_id bigint;
  v_invoice_id bigint;
  v_liability_id bigint;
  v_confidence numeric(5,2);
  v_inserted integer;
  v_invoice_matches integer:=0;
  v_liability_matches integer:=0;
begin
  if not public.finance_can_manage_v1() then
    raise exception 'Přístup odepřen.' using errcode='42501';
  end if;
  if coalesce(p_import_sha256,'') !~ '^[0-9a-f]{64}$' then
    raise exception 'Neplatný SHA-256 otisk.';
  end if;

  for v_tx in
    select t.*
    from public.finance_bank_transactions t
    where t.raw_payload->>'import_sha256'=p_import_sha256
      and t.amount<0
      and not exists (
        select 1 from public.finance_payment_matches m
        where m.bank_transaction_id=t.id and m.status='confirmed'
      )
    order by t.booked_on,t.id
  loop
    v_inserted:=0;
    with candidates as (
      select bi.id,bi.invoice_id,bi.liability_id,
        case
          when
            coalesce(regexp_replace(bi.variable_symbol,'^0+',''),'')<>''
            and regexp_replace(coalesce(bi.variable_symbol,''),'^0+','')=regexp_replace(coalesce(v_tx.variable_symbol,''),'^0+','')
            and coalesce(regexp_replace(right(lpad(regexp_replace(coalesce(v_tx.counterparty_account,''),'[^0-9]','','g'),16,'0'),10),'^0+',''),'')=
                coalesce(regexp_replace(regexp_replace(split_part(split_part(coalesce(bi.creditor_account,''),'/',1),'-',-1),'[^0-9]','','g'),'^0+',''),'')
            and coalesce(v_tx.counterparty_bank_code,'')=coalesce(nullif(split_part(coalesce(bi.creditor_account,''),'/',2),''),v_tx.counterparty_bank_code,'')
          then 100
          when
            coalesce(regexp_replace(bi.variable_symbol,'^0+',''),'')<>''
            and regexp_replace(coalesce(bi.variable_symbol,''),'^0+','')=regexp_replace(coalesce(v_tx.variable_symbol,''),'^0+','')
          then 98
          when
            coalesce(regexp_replace(right(lpad(regexp_replace(coalesce(v_tx.counterparty_account,''),'[^0-9]','','g'),16,'0'),10),'^0+',''),'')<>''
            and regexp_replace(right(lpad(regexp_replace(coalesce(v_tx.counterparty_account,''),'[^0-9]','','g'),16,'0'),10),'^0+','')=
                regexp_replace(regexp_replace(split_part(split_part(coalesce(bi.creditor_account,''),'/',1),'-',-1),'[^0-9]','','g'),'^0+','')
            and coalesce(v_tx.counterparty_bank_code,'')=coalesce(nullif(split_part(coalesce(bi.creditor_account,''),'/',2),''),v_tx.counterparty_bank_code,'')
          then 95
          else 0
        end as score
      from public.finance_payment_batch_items bi
      where abs(bi.amount-abs(v_tx.amount))<.01
        and bi.status not in ('rejected','cancelled')
    ), best as (
      select * from candidates
      where score>0 and score=(select max(score) from candidates)
    )
    select count(*),min(id),min(invoice_id),min(liability_id),min(score)
      into v_candidate_count,v_batch_item_id,v_invoice_id,v_liability_id,v_confidence
    from best;

    if v_candidate_count=1 then
      insert into public.finance_payment_matches(
        invoice_id,liability_id,bank_transaction_id,matched_amount,match_method,confidence,status,confirmed_at
      ) values(
        v_invoice_id,v_liability_id,v_tx.id,abs(v_tx.amount),'batch_reference',v_confidence,'confirmed',now()
      ) on conflict do nothing;
      get diagnostics v_inserted=row_count;
      if v_inserted=1 then
        update public.finance_payment_batch_items set status='processed' where id=v_batch_item_id;
        if v_invoice_id is not null then v_invoice_matches:=v_invoice_matches+1; end if;
        if v_liability_id is not null then v_liability_matches:=v_liability_matches+1; end if;
      end if;
    end if;

    if v_inserted=0 then
      select count(*),min(l.id)
        into v_candidate_count,v_liability_id
      from public.finance_liabilities l
      where l.due_date=v_tx.booked_on
        and abs(l.actual_remaining_amount-abs(v_tx.amount))<.01
        and l.payment_status in ('unpaid','ordered','partially_paid');
      if v_candidate_count=1 then
        insert into public.finance_payment_matches(
          liability_id,bank_transaction_id,matched_amount,match_method,confidence,status,confirmed_at
        ) values(
          v_liability_id,v_tx.id,abs(v_tx.amount),'money_date_amount',99,'confirmed',now()
        ) on conflict do nothing;
        get diagnostics v_inserted=row_count;
        if v_inserted=1 then v_liability_matches:=v_liability_matches+1; end if;
      end if;
    end if;
  end loop;

  update public.finance_received_invoices i set
    bank_confirmed_amount=x.amount,
    bank_last_payment_at=x.last_paid,
    payment_evidence=case when i.payment_evidence='money_s3' then 'mixed' else 'bank' end,
    payment_status=case when x.amount>=abs(i.total_amount)-.01 then 'paid'
      when x.amount>.01 then 'partially_paid' else i.payment_status end,
    operational_remaining_amount=greatest(abs(i.total_amount)-x.amount,0),
    paid_at=case when x.amount>=abs(i.total_amount)-.01 then x.last_paid else i.paid_at end,
    status=case when x.amount>=abs(i.total_amount)-.01 then 'settled' else i.status end,
    updated_at=now()
  from (
    select m.invoice_id,sum(m.matched_amount) amount,max(t.booked_on) last_paid
    from public.finance_payment_matches m
    join public.finance_bank_transactions t on t.id=m.bank_transaction_id
    where m.status='confirmed' and m.invoice_id is not null
    group by m.invoice_id
  ) x where i.id=x.invoice_id;

  update public.finance_liabilities l set
    bank_confirmed_amount=x.amount,
    bank_last_payment_at=x.last_paid,
    payment_status=case when x.amount>=abs(l.actual_remaining_amount)-.01 then 'paid'
      when x.amount>.01 then 'partially_paid' else l.payment_status end,
    updated_at=now()
  from (
    select m.liability_id,sum(m.matched_amount) amount,max(t.booked_on) last_paid
    from public.finance_payment_matches m
    join public.finance_bank_transactions t on t.id=m.bank_transaction_id
    where m.status='confirmed' and m.liability_id is not null
    group by m.liability_id
  ) x where l.id=x.liability_id;

  update public.finance_payment_batch_items bi set status='processed'
  where bi.status not in ('processed','rejected','cancelled')
    and exists (
      select 1
      from public.finance_payment_matches m
      join public.finance_bank_transactions t on t.id=m.bank_transaction_id
      where m.status='confirmed'
        and t.raw_payload->>'import_sha256'=p_import_sha256
        and abs(m.matched_amount-bi.amount)<.01
        and ((m.invoice_id is not null and m.invoice_id=bi.invoice_id)
          or (m.liability_id is not null and m.liability_id=bi.liability_id))
    );

  update public.finance_payment_batches b set status='processed'
  where b.status not in ('processed','cancelled')
    and exists (select 1 from public.finance_payment_batch_items bi where bi.batch_id=b.id)
    and not exists (
      select 1 from public.finance_payment_batch_items bi
      where bi.batch_id=b.id and bi.status not in ('processed','rejected','cancelled')
    );

  return jsonb_build_object(
    'invoice_matches',v_invoice_matches,
    'liability_matches',v_liability_matches,
    'import_sha256',p_import_sha256
  );
end;
$$;

revoke all on function public.finance_reconcile_bank_import_v2(text) from public,anon;
grant execute on function public.finance_reconcile_bank_import_v2(text) to authenticated,service_role;

comment on function public.finance_reconcile_bank_import_v2(text) is
  'Dopáruje bankovní pohyby přes jednoznačnou položku platebního příkazu a přepočte částečné úhrady.';
