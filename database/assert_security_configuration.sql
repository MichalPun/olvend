-- Read-only release check. Must PASS after every schema/permission migration.
-- This complements (does not replace) test_security_boundary_20260919.sql.
begin transaction read only;
do $$
declare bad text;
begin
 select string_agg(c.relname, ', ') into bad
 from pg_class c join pg_namespace n on n.oid=c.relnamespace
 where n.nspname='public' and c.relkind in ('r','p','v','m')
 and has_table_privilege('anon',c.oid,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER');
 if bad is not null then raise exception 'SECURITY FAIL: anonymous table/view privileges: %',bad; end if;

 select string_agg(c.relname, ', ') into bad
 from pg_class c join pg_namespace n on n.oid=c.relnamespace
 where n.nspname='public' and c.relkind in ('r','p') and not c.relrowsecurity;
 if bad is not null then raise exception 'SECURITY FAIL: RLS disabled: %',bad; end if;

 select string_agg(c.relname, ', ') into bad
 from pg_class c join pg_namespace n on n.oid=c.relnamespace
 where n.nspname='public' and c.relkind in ('r','p') and not exists (
   select 1 from pg_policy p where p.polrelid=c.oid
   and p.polname='security_active_employee_gate' and not p.polpermissive and p.polcmd='*'
   and (select oid from pg_roles where rolname='authenticated')=any(p.polroles)
   and pg_get_expr(p.polqual,p.polrelid) like '%security_active_employee()%'
   and pg_get_expr(p.polwithcheck,p.polrelid) like '%security_active_employee()%'
 );
 if bad is not null then raise exception 'SECURITY FAIL: missing active-employee gate: %',bad; end if;

 select string_agg(p.oid::regprocedure::text, ', ') into bad
 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname='public' and p.prokind='f' and has_function_privilege('anon',p.oid,'EXECUTE')
 and p.oid not in (
   'public.get_public_machine_by_qr(text)'::regprocedure,
   'public.submit_public_service_request(text,text,text,text)'::regprocedure,
   'public.security_check_request()'::regprocedure
 );
 if bad is not null then raise exception 'SECURITY FAIL: unexpected anonymous RPC: %',bad; end if;

 if exists(select 1 from storage.buckets where public) then
   raise exception 'SECURITY FAIL: public storage bucket';
 end if;
 if exists(select 1 from auth.users u join public.employees e on e.auth_user_id=u.id
           where e.active is not true and (u.banned_until is null or u.banned_until<=now())) then
   raise exception 'SECURITY FAIL: inactive employee login is not banned';
 end if;
 if exists(select 1 from auth.users u where not exists(select 1 from public.employees e where e.auth_user_id=u.id)) then
   raise exception 'SECURITY FAIL: auth account without employee';
 end if;
 if not exists(select 1 from pg_db_role_setting s join pg_roles r on r.oid=s.setrole
               where r.rolname='authenticator' and s.setdatabase=0
               and 'pgrst.db_pre_request=public.security_check_request'=any(s.setconfig)) then
   raise exception 'SECURITY FAIL: REST pre-request guard missing';
 end if;
end $$;
rollback;
select 'PASS: anonymous privileges, RLS, active gates, RPC allowlist, storage, inactive accounts, REST guard' result;
