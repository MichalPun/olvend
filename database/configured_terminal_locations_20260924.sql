begin;
-- Correct only the six configured terminal summaries; preserve sale-time locations.
create temporary table terminal_location_fix_before on commit drop as
select id,machine_id,quantity,total_amount_czk,cash_amount_czk,cashless_amount_czk
from public.telemetry_sales_events where source_event_key ~ '^terminal-ev-(17|18|28|36|37|51)-day:';
do $fix$
declare r record; body text; old_pair text := '''Hlučín · OU a PrŠ Hlučín'',''Bianchi Aria'''; replacement text;
begin
 for r in select * from (values (14,17),(15,18),(23,28),(30,36),(31,37),(42,51)) v(mid,ev) loop
 body := pg_get_functiondef(to_regprocedure(format('public.sync_terminal_sales_ev_%s()',r.ev)));
 replacement := format($expr$(select coalesce(nullif(concat_ws(' · ',nullif(l.city,''),nullif(l.name,'')),''),m.name,'Bez lokality') from public.machines m left join lateral (select true found,t.from_location_id from public.machine_transfers t where t.machine_id=m.id and t.transferred_at>coalesce(r.last_sale,r.sale_day::timestamp at time zone 'Europe/Prague') order by t.transferred_at,t.id limit 1) h on true left join public.locations l on l.id=case when h.found then h.from_location_id else m.location_id end where m.id=%s),(select name from public.machines where id=%s)$expr$,r.mid,r.mid);
 if position(old_pair in body)=0 then raise exception 'Expected source labels missing in EV %',r.ev; end if;
 body:=replace(body,old_pair,replacement);
 if position('Hlučín' in body)>0 or position('Bianchi Aria' in body)>0 then raise exception 'Source labels retained EV %',r.ev; end if;
 execute body;
 end loop;
end $fix$;
with corrected as (
 select s.id,m.name machine_label,coalesce(nullif(concat_ws(' · ',nullif(l.city,''),nullif(l.name,'')),''),m.name,'Bez lokality') location_label
 from public.telemetry_sales_events s join terminal_location_fix_before b on b.id=s.id join public.machines m on m.id=s.machine_id
 left join lateral (select true found,t.from_location_id from public.machine_transfers t where t.machine_id=m.id and t.transferred_at>s.source_event_at order by t.transferred_at,t.id limit 1) h on true
 left join public.locations l on l.id=case when h.found then h.from_location_id else m.location_id end
)
update public.telemetry_sales_events s set source_location_name=c.location_label,source_machine_name=c.machine_label from corrected c where c.id=s.id;
-- Exercise reconciliation again to ensure future ingestion cannot restore Hlucín.
select public.sync_terminal_sales_ev_17(),public.sync_terminal_sales_ev_18(),public.sync_terminal_sales_ev_28(),public.sync_terminal_sales_ev_36(),public.sync_terminal_sales_ev_37(),public.sync_terminal_sales_ev_51();
do $check$
begin
 if exists(select 1 from terminal_location_fix_before b full join (select * from public.telemetry_sales_events where source_event_key ~ '^terminal-ev-(17|18|28|36|37|51)-day:') s using(id) where b.id is null or s.id is null or (b.machine_id,b.quantity,b.total_amount_czk,b.cash_amount_czk,b.cashless_amount_czk) is distinct from (s.machine_id,s.quantity,s.total_amount_czk,s.cash_amount_czk,s.cashless_amount_czk)) then raise exception 'Sales amounts or identities changed'; end if;
 if exists(select 1 from public.telemetry_sales_events s join terminal_location_fix_before b on b.id=s.id where s.source_location_name ilike '%Hlučín%') then raise exception 'Wrong Hlucín labels remain'; end if;
end $check$;
select jsonb_agg(to_jsonb(x))::text verification from (select m.evidence_number,s.source_location_name,s.source_machine_name,count(*) rows,sum(s.total_amount_czk) revenue from public.telemetry_sales_events s join terminal_location_fix_before b on b.id=s.id join public.machines m on m.id=s.machine_id group by 1,2,3 order by 1) x;
commit;
