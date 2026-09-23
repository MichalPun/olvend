-- Run after setup in the same transaction; append ROLLBACK for the deployment rehearsal.
do $test$ declare before_rows jsonb; after_rows jsonb; r record; begin
 select jsonb_agg(to_jsonb(e) order by id) into before_rows from public.telemetry_sales_events e where source_event_key like 'terminal-ev-%-day:%';
 if before_rows is null then raise exception 'No summaries generated';end if;
 for r in select unnest(array['37','51','17','18','36','28']) ev loop execute format('select public.sync_terminal_sales_ev_%s()',r.ev); end loop;
 select jsonb_agg(to_jsonb(e) order by id) into after_rows from public.telemetry_sales_events e where source_event_key like 'terminal-ev-%-day:%';
 if before_rows is distinct from after_rows then raise exception 'Reconciliation is not idempotent';end if;
 if exists(select 1 from public.telemetry_sales_events where source_event_key like 'terminal-ev-%-day:%' and (machine_id not in(31,42,14,15,30,23) or planogram_slot_id is not null or product_sku is not null or source_event_at<'2026-08-31 22:00:00+00' or total_amount_czk<>cash_amount_czk+cashless_amount_czk or quantity<>cash_quantity+cashless_quantity)) then raise exception 'Invalid summary attribution';end if;
 for r in select unnest(array['37','51','17','18','36','28']) ev loop
 if has_table_privilege('anon','public.terminal_counters_ev_'||r.ev,'SELECT') or has_table_privilege('authenticated','public.terminal_counters_ev_'||r.ev,'INSERT') or has_function_privilege('anon','public.sync_terminal_sales_ev_'||r.ev||'()','EXECUTE') then raise exception 'Unexpected public privilege';end if;
 end loop;
end $test$;
select m.evidence_number ev,count(*) days,sum(e.total_amount_czk) added_revenue,sum(e.quantity) added_quantity from public.telemetry_sales_events e join public.machines m on m.id=e.machine_id where e.source_event_key like 'terminal-ev-%-day:%' group by 1 order by 1;
