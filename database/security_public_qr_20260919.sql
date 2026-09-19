-- Deploy before removing anonymous table grants. No internal ticket data is returned.
begin;
create or replace function public.get_public_machine_by_qr(p_qr_token text)
returns jsonb language sql stable security definer set search_path=pg_catalog,public as $$
 select jsonb_build_object('machine',jsonb_build_object(
   'id',m.id,'name',m.name,'qr_token',m.qr_token,'location_id',m.location_id,
   'evidence_number',m.evidence_number,'machine_type',m.machine_type,'status',m.status),
   'location',case when l.id is null then null else jsonb_build_object('id',l.id,'name',l.name,'city',l.city) end)
 from public.machines m left join public.locations l on l.id=m.location_id
 where m.qr_token=p_qr_token and length(p_qr_token) between 4 and 200 limit 1
$$;
create or replace function public.submit_public_service_request(p_qr_token text,p_title text,p_description text,p_priority text default 'normal')
returns jsonb language plpgsql security definer set search_path=pg_catalog,public as $$
declare machine_row public.machines%rowtype; request_id bigint;
begin
 if p_qr_token is null or length(p_qr_token) not between 4 and 200
 or p_title is null or length(trim(p_title)) not between 3 and 200
 or p_description is null or length(p_description) not between 1 and 4000
 or p_priority is null or p_priority not in ('low','normal','high','critical') then
   raise exception 'Neplatné servisní hlášení.' using errcode='22023';
 end if;
 select * into machine_row from public.machines where qr_token=p_qr_token;
 if not found or machine_row.location_id is null then raise exception 'Automat nenalezen.' using errcode='22023'; end if;
 perform pg_advisory_xact_lock(hashtextextended('public-qr:'||machine_row.id,0));
 if (select count(*) from public.service_requests where machine_id=machine_row.id
     and created_at>now()-interval '5 minutes' and description like 'Nahlášeno přes QR automatu%')>=5 then
   raise exception 'Bylo přijato více hlášení. Zkuste to prosím za několik minut.' using errcode='P0001';
 end if;
 insert into public.service_requests(machine_id,location_id,title,description,priority,status)
 values(machine_row.id,machine_row.location_id,trim(p_title),
 case when p_description like 'Nahlášeno přes QR automatu%' then p_description else 'Nahlášeno přes QR automatu · '||p_description end,p_priority,'new')
 returning id into request_id;
 return jsonb_build_object('id',request_id);
end $$;
revoke all on function public.get_public_machine_by_qr(text),public.submit_public_service_request(text,text,text,text) from public;
grant execute on function public.get_public_machine_by_qr(text),public.submit_public_service_request(text,text,text,text) to anon,authenticated,service_role;
commit;
