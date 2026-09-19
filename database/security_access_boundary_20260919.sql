-- QR API and frontend must already be deployed. Preserve existing authenticated
-- and server privileges; remove anonymous direct access, including definer RPCs.
begin;
create or replace function public.security_active_employee()
returns boolean language sql stable security definer set search_path=pg_catalog,public as $$
 select exists(select 1 from public.employees where auth_user_id=auth.uid() and active is true)
$$;
revoke all on function public.security_active_employee() from public,anon;
grant execute on function public.security_active_employee() to authenticated,service_role;
do $$ declare r record; begin
 for r in select c.oid,c.relname,c.relkind from pg_class c join pg_namespace n on n.oid=c.relnamespace
 where n.nspname='public' and c.relkind in ('r','p','v','m','S') loop
   -- Authenticated users and server functions retain their existing privileges.
   execute format('revoke all on %s public.%I from anon, public',case when r.relkind='S' then 'sequence' else 'table' end,r.relname);
   if r.relkind in ('r','p') then
     execute format('alter table public.%I enable row level security',r.relname);
     execute format('drop policy if exists security_active_employee_gate on public.%I',r.relname);
     execute format('create policy security_active_employee_gate on public.%I as restrictive for all to authenticated using ((select public.security_active_employee())) with check ((select public.security_active_employee()))',r.relname);
   end if;
 end loop;
 for r in select p.oid,p.oid::regprocedure as signature,has_function_privilege('authenticated',p.oid,'execute') auth_allowed,
   has_function_privilege('service_role',p.oid,'execute') server_allowed
 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.prokind='f' loop
   if r.auth_allowed then execute format('grant execute on function %s to authenticated',r.signature); end if;
   if r.server_allowed then execute format('grant execute on function %s to service_role',r.signature); end if;
   execute format('revoke execute on function %s from anon, public',r.signature);
 end loop;
end $$;
grant execute on function public.get_public_machine_by_qr(text),public.submit_public_service_request(text,text,text,text) to anon;
create or replace function public.security_check_request()
returns void language plpgsql security definer set search_path=pg_catalog,public as $$
begin
 if auth.role()='service_role' then return; end if;
 if current_setting('request.path',true) in ('/rpc/get_public_machine_by_qr','/rpc/submit_public_service_request') then return; end if;
 if not public.security_active_employee() then
   raise exception 'Přístup vyžaduje aktivní zaměstnanecký účet.' using errcode='42501';
 end if;
end $$;
revoke all on function public.security_check_request() from public;
grant execute on function public.security_check_request() to anon,authenticated,service_role;
alter role authenticator set pgrst.db_pre_request='public.security_check_request';
alter default privileges in schema public revoke all on tables from anon,public;
alter default privileges in schema public revoke all on sequences from anon,public;
alter default privileges in schema public revoke execute on functions from anon,public;
notify pgrst,'reload config';
notify pgrst,'reload schema';
commit;
