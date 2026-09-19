begin;
-- Dedicated source key; no product, slot, stock movement or assumed purchase cost.
create or replace function public.sync_hlucin_regular_sales()
returns void language plpgsql security definer set search_path=public as $$
#variable_conflict use_column
declare r record; rev numeric; qty numeric; cash numeric; card numeric; cq numeric; dq numeric;
begin
 perform pg_advisory_xact_lock(59784858);
 for r in
 with deltas as (
 select event_at,total_amount-lag(total_amount) over w amount,total_quantity-lag(total_quantity) over w qty,
 cash_amount-lag(cash_amount) over w cash,card_amount-lag(card_amount) over w card,
 cash_quantity-lag(cash_quantity) over w cq,card_quantity-lag(card_quantity) over w dq
 from hlucin_terminal_counters window w as(order by event_at)
 ), days as (
 select (event_at at time zone 'Europe/Prague')::date as sale_day,
 max(event_at) filter(where qty>0 or amount>0) last_sale,
 sum(amount) amount,sum(qty) qty,sum(cash) cash,sum(card) card,sum(cq) cq,sum(dq) dq
 from deltas where amount>=0 and qty>=0 and cash>=0 and card>=0 and cq>=0 and dq>=0
 and abs(amount-cash-card)<0.01 and qty=cq+dq
 group by 1
 )
 select d.*,coalesce(s.amount,0) item_amount,coalesce(s.qty,0) item_qty,coalesce(s.cash,0) item_cash,coalesce(s.cq,0) item_cq
 from days d left join lateral (
 select sum(total_amount_czk) amount,sum(greatest(0,quantity-coalesce(free_vend_quantity,0))) qty,
 sum(cash_amount_czk) cash,sum(cash_quantity) cq
 from telemetry_sales_events
 where machine_id=58 and selection_code<>'TERMINAL_SUMMARY'
 and source_event_at>=d.sale_day::timestamp at time zone 'Europe/Prague'
 and source_event_at<(d.sale_day+1)::timestamp at time zone 'Europe/Prague'
 ) s on true
 loop
 rev:=greatest(0,r.amount-r.item_amount);qty:=greatest(0,r.qty-r.item_qty);
 cash:=least(rev,greatest(0,r.cash-r.item_cash));card:=rev-cash;
 cq:=least(qty,greatest(0,r.cq-r.item_cq));dq:=qty-cq;
 if rev=0 and qty=0 and not exists(select 1 from telemetry_sales_events where provider='IMA' and source_event_key='hlucin-terminal-day:'||r.sale_day) then continue; end if;
 insert into telemetry_sales_events(provider,machine_id,selection_code,product_name,quantity,cash_quantity,cashless_quantity,
 unknown_payment_quantity,free_vend_quantity,unpaid_dispense_quantity,total_amount_czk,cash_amount_czk,cashless_amount_czk,
 unknown_payment_amount_czk,source_event_at,source_event_key,source_location_name,source_machine_name,price_source)
 values('IMA',58,'TERMINAL_SUMMARY','Denní souhrn – bez rozpisu produktu',qty,cq,dq,0,0,0,rev,cash,card,0,
 coalesce(r.last_sale,r.sale_day::timestamp at time zone 'Europe/Prague'),'hlucin-terminal-day:'||r.sale_day,'OU a PrŠ Hlučín','Bianchi Aria','terminal_counter_summary')
 on conflict(provider,source_event_key) do update set quantity=excluded.quantity,cash_quantity=excluded.cash_quantity,
 cashless_quantity=excluded.cashless_quantity,total_amount_czk=excluded.total_amount_czk,cash_amount_czk=excluded.cash_amount_czk,
 cashless_amount_czk=excluded.cashless_amount_czk,source_event_at=excluded.source_event_at
 where (telemetry_sales_events.quantity,telemetry_sales_events.total_amount_czk,telemetry_sales_events.cash_amount_czk,telemetry_sales_events.cash_quantity,telemetry_sales_events.source_event_at)
 is distinct from (excluded.quantity,excluded.total_amount_czk,excluded.cash_amount_czk,excluded.cash_quantity,excluded.source_event_at);
 end loop;
end $$;
revoke all on function public.sync_hlucin_regular_sales() from public,anon,authenticated;
create or replace function public.sync_hlucin_regular_sales_trigger()
returns trigger language plpgsql security definer set search_path=public as $$
begin
 if tg_table_name='telemetry_sales_events' then
  if tg_op='DELETE' then
   if old.machine_id<>58 or old.selection_code='TERMINAL_SUMMARY' then return old; end if;
  elsif tg_op='UPDATE' then
   if (new.machine_id is distinct from 58 and old.machine_id is distinct from 58) or (new.selection_code='TERMINAL_SUMMARY' and old.selection_code='TERMINAL_SUMMARY') then return new; end if;
  elsif new.machine_id<>58 or new.selection_code='TERMINAL_SUMMARY' then return new;
  end if;
 end if;
 perform public.sync_hlucin_regular_sales();
 return null;
end $$;
revoke all on function public.sync_hlucin_regular_sales_trigger() from public,anon,authenticated;
create trigger hlucin_counters_to_sales after insert or update on public.hlucin_terminal_counters for each statement execute function public.sync_hlucin_regular_sales_trigger();
create trigger hlucin_sales_reconcile after insert or update or delete on public.telemetry_sales_events for each row execute function public.sync_hlucin_regular_sales_trigger();
select public.sync_hlucin_regular_sales();
-- Unknown products must not appear as zero-cost profit.
do $$ declare definition text; begin
 select pg_get_functiondef('public.get_dashboard_telemetry_profit_v49(timestamptz,timestamptz,timestamptz,timestamptz,date[],bigint)'::regprocedure) into definition;
 if position('event.selection_code <> ''TERMINAL_SUMMARY''' in definition)=0 then
  definition:=replace(definition,'where event.source_event_at >= least(p_period_start, p_compare_start)', 'where event.selection_code <> ''TERMINAL_SUMMARY'' and event.source_event_at >= least(p_period_start, p_compare_start)');
  if position('event.selection_code <> ''TERMINAL_SUMMARY''' in definition)=0 then raise exception 'Profit function did not match expected definition';end if;
  execute definition;
 end if;
end $$;
commit;
