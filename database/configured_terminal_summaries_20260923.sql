begin;
-- Explicitly approved streams. Reuse the deployed counter reconciliation so
-- partial item sales are deducted and unknown products never deplete inventory.
do $setup$
declare r record; capture text; sync text; hook text; tab text; cap text; sy text; tr text;
begin
 if position('TERMINAL_SUMMARY' in pg_get_functiondef('public.get_dashboard_telemetry_profit_v49(timestamptz,timestamptz,timestamptz,timestamptz,date[],bigint)'::regprocedure))=0 then raise exception 'Profit summary exclusion missing'; end if;
 for r in select * from (values(31,'37','592145'),(42,'51','629426'),(14,'17','596512'),(15,'18','604306'),(30,'36','602225'),(23,'28','602228')) v(mid,ev,tid)
 loop
 if not exists(select 1 from public.machines m join public.machine_external_links l on l.machine_id=m.id where m.id=r.mid and m.evidence_number::text=r.ev and l.provider='IMA' and l.external_machine_id=r.tid and l.telemetry_enabled) then raise exception 'Machine/terminal mismatch EV %',r.ev;end if;
 tab:='terminal_counters_ev_'||r.ev;cap:='capture_terminal_ev_'||r.ev;sy:='sync_terminal_sales_ev_'||r.ev;tr:='trigger_terminal_sales_ev_'||r.ev;
 execute format('create table public.%I (like public.hlucin_terminal_counters including all)',tab);
 execute format('alter table public.%I enable row level security',tab);
 execute format('revoke all on public.%I from public,anon,authenticated',tab);
 execute format('grant all on public.%I to service_role',tab);
 capture:=pg_get_functiondef('public.capture_hlucin_terminal_counter()'::regprocedure);
 capture:=replace(capture,'capture_hlucin_terminal_counter',cap);
 capture:=replace(capture,'hlucin_terminal_counters',tab);
 capture:=replace(capture,'597848',r.tid);
 capture:=replace(capture,'machine_id=58','machine_id='||r.mid);
 capture:=replace(capture,'2026-09-13 16:06:25+00','2026-08-30 22:00:00+00');
 execute capture;
 execute format('revoke all on function public.%I() from public,anon,authenticated',cap);
 sync:=pg_get_functiondef('public.sync_hlucin_regular_sales()'::regprocedure);
 sync:=replace(sync,'sync_hlucin_regular_sales',sy);
 sync:=replace(sync,'hlucin_terminal_counters',tab);
 sync:=replace(sync,'59784858',(70000000+r.mid)::text);
 sync:=replace(sync,'machine_id=58','machine_id='||r.mid);
 sync:=replace(sync,'''IMA'',58,','''IMA'','||r.mid||',');
 sync:=replace(sync,'hlucin-terminal-day:','terminal-ev-'||r.ev||'-day:');
 sync:=replace(sync,'from deltas where amount>=0','from deltas where event_at>=''2026-08-31 22:00:00+00''::timestamptz and amount>=0');
 sync:=replace(sync,'''OU a PrŠ Hlučín'',''Bianchi Aria''',format('(select l.name from public.machines m join public.locations l on l.id=m.location_id where m.id=%s),(select name from public.machines where id=%s)',r.mid,r.mid));
 if position('machine_id=58' in sync)>0 or position('''IMA'',58,' in sync)>0 or position('hlucin-terminal-day:' in sync)>0 then raise exception 'Unreplaced source reference';end if;
 execute sync;
 execute format('revoke all on function public.%I() from public,anon,authenticated',sy);
 hook:=pg_get_functiondef('public.sync_hlucin_regular_sales_trigger()'::regprocedure);
 hook:=replace(hook,'sync_hlucin_regular_sales_trigger',tr);
 hook:=replace(hook,'sync_hlucin_regular_sales',sy);
 hook:=replace(hook,'machine_id<>58','machine_id<>'||r.mid);
 hook:=replace(hook,'machine_id is distinct from 58','machine_id is distinct from '||r.mid);
 execute hook;
 execute format('revoke all on function public.%I() from public,anon,authenticated',tr);
 execute format('create trigger %I after insert or update of raw_dex,dex_read_datetime,transmit_time,transaction_time on public.telemetry_dex_ingests for each row execute function public.%I()',cap,cap);
 execute format('create trigger %I after insert or update on public.%I for each statement execute function public.%I()',tab||'_sales',tab,tr);
 execute format('create trigger %I after insert or update or delete on public.telemetry_sales_events for each row execute function public.%I()',tr,tr);
 execute format($backfill$insert into public.%I select distinct on(ts) ts,id,v[1]::numeric/100,v[2]::bigint,c[1]::numeric/100,c[2]::bigint,d[1]::numeric/100,d[2]::bigint from (
 select id,coalesce(dex_read_datetime,transmit_time,transaction_time,created_at) ts,
 regexp_match(raw_dex,'(?:^|[\r\n])VA1\*([0-9]+)\*([0-9]+)(?:\*|[\r\n]|$)') v,
 regexp_match(raw_dex,'(?:^|[\r\n])CA2\*([0-9]+)\*([0-9]+)(?:\*|[\r\n]|$)') c,
 regexp_match(raw_dex,'(?:^|[\r\n])DA2\*([0-9]+)\*([0-9]+)(?:\*|[\r\n]|$)') d
 from public.telemetry_dex_ingests where provider='IMA' and device_id=%L and created_at>='2026-08-30 22:00:00+00'
 ) s where ts>='2026-08-30 22:00:00+00' and v is not null and c is not null and d is not null order by ts,id desc on conflict(event_at) do nothing$backfill$,tab,r.tid);
 end loop;
end $setup$;
commit;
