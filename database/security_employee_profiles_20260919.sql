begin;
-- Stable definer helpers avoid recursive employees RLS checks.
create or replace function public.security_active_employee() returns boolean language sql stable security definer set search_path=pg_catalog,public as $$
 select exists(select 1 from public.employees where auth_user_id=auth.uid() and active is true)
$$;
revoke all on function public.security_active_employee() from public,anon;
grant execute on function public.security_active_employee() to authenticated,service_role;
drop policy if exists security_employee_insert_gate on public.employees;
create policy security_employee_insert_gate on public.employees as restrictive for insert to authenticated with check(public.has_manager_access());
drop policy if exists security_employee_update_gate on public.employees;
create policy security_employee_update_gate on public.employees as restrictive for update to authenticated using(public.has_manager_access()) with check(public.has_manager_access());
drop policy if exists security_employee_delete_gate on public.employees;
create policy security_employee_delete_gate on public.employees as restrictive for delete to authenticated using(public.has_manager_access());
drop policy if exists security_employee_read_gate on public.employees;
create policy security_employee_read_gate on public.employees as restrictive for select to authenticated using(auth_user_id=auth.uid() or public.has_manager_access());
-- Explicit minimal directory for operational selectors, never employment/HR fields.
create or replace view public.employee_directory with (security_barrier=true) as
 select id,name,surname,role,email,active,warehouse_id from public.employees
 where public.security_active_employee();
revoke all on public.employee_directory from public,anon,authenticated;
grant select on public.employee_directory to authenticated;

create or replace function public.security_sync_employee_auth_status()
returns trigger language plpgsql security definer set search_path=pg_catalog,public as $$
begin
 if new.auth_user_id is not null then
   if new.active is not true then
     update auth.users set banned_until=greatest(coalesce(banned_until,'-infinity'::timestamptz),'2100-01-01'::timestamptz) where id=new.auth_user_id;
   elsif tg_op='UPDATE' and old.active is not true then
     update auth.users set banned_until=null where id=new.auth_user_id and banned_until='2100-01-01'::timestamptz;
   end if;
 end if;
 return new;
end $$;
revoke all on function public.security_sync_employee_auth_status() from public,anon,authenticated;
drop trigger if exists security_sync_employee_auth_status on public.employees;
create trigger security_sync_employee_auth_status after insert or update of active,auth_user_id on public.employees for each row execute function public.security_sync_employee_auth_status();
update auth.users u set banned_until=greatest(coalesce(u.banned_until,'-infinity'::timestamptz),'2100-01-01'::timestamptz)
where exists(select 1 from public.employees e where e.auth_user_id=u.id and e.active is not true);
commit;
