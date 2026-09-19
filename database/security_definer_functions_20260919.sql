-- Enforce the active-account boundary inside definer RPCs as well as REST.
-- Preserve the original definition in an unexposed schema for rollback review.
begin;
create schema if not exists security_audit;
revoke all on schema security_audit from public,anon,authenticated;
create table if not exists security_audit.function_before_20260919(signature text primary key,definition text not null);
alter table security_audit.function_before_20260919 enable row level security;
revoke all on security_audit.function_before_20260919 from public,anon,authenticated;
create or replace function public.security_assert_active_employee()
returns void language plpgsql stable security definer set search_path=pg_catalog,public as $$
begin
 if current_setting('role',true) in ('anon','authenticated') and not public.security_active_employee() then
   raise exception 'Přístup vyžaduje aktivní zaměstnanecký účet.' using errcode='42501';
 end if;
end $$;
revoke all on function public.security_assert_active_employee() from public,anon;
grant execute on function public.security_assert_active_employee() to authenticated,service_role;
do $$ declare f record; replacement text; definition text; begin
 for f in select p.*,l.lanname from pg_proc p join pg_namespace n on n.oid=p.pronamespace join pg_language l on l.oid=p.prolang
 where n.nspname='public' and p.prosecdef and p.prorettype not in ('trigger'::regtype,'event_trigger'::regtype)
 and has_function_privilege('authenticated',p.oid,'execute')
 and p.proname not in ('security_active_employee','security_check_request','security_assert_active_employee','get_public_machine_by_qr','submit_public_service_request',
 'current_employee_id','has_manager_access','is_mail_owner','has_payroll_access','can_read_payroll_file','location_message_current_employee_id','location_message_can_manage','is_my_route_skip_request_v40')
 and position('security_assert_active_employee' in p.prosrc)=0 loop
   definition:=pg_get_functiondef(f.oid);
   insert into security_audit.function_before_20260919 values(f.oid::regprocedure::text,definition) on conflict do nothing;
   if f.lanname='plpgsql' then
     replacement:=regexp_replace(f.prosrc,'\mBEGIN\M','BEGIN PERFORM public.security_assert_active_employee();','i');
     if replacement=f.prosrc then raise exception 'Missing BEGIN in %',f.oid::regprocedure; end if;
   elsif f.lanname='sql' then
     replacement:='WITH security_guard AS MATERIALIZED (SELECT public.security_assert_active_employee()) SELECT secured.* FROM security_guard CROSS JOIN LATERAL ('||regexp_replace(trim(f.prosrc),';\s*$','')||') secured';
   else raise exception 'Unsupported definer language: %',f.oid::regprocedure;
   end if;
   execute replace(definition,f.prosrc,replacement);
 end loop;
end $$;
commit;
