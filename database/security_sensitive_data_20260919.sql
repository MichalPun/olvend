begin;
do $$ declare t text; begin
 foreach t in array array['attendance_days','attendance_events','employee_availability','employee_location_logs','hr_requests','notification_preferences'] loop
   execute format('create policy security_own_or_manager_gate on public.%I as restrictive for all to authenticated using (employee_id=public.current_employee_id() or public.has_manager_access()) with check (employee_id=public.current_employee_id() or public.has_manager_access())',t);
 end loop;
 foreach t in array array['payroll_absence_overrides','payroll_month_entries','payroll_settings','budget_expense_entries','budget_lines','budget_scenarios','location_financial_rules','machine_financial_rules','service_ai_intakes','service_ai_pilot_intakes'] loop
   execute format('create policy security_manager_gate on public.%I as restrictive for all to authenticated using (public.has_manager_access()) with check (public.has_manager_access())',t);
 end loop;
 foreach t in array array['app_settings','attendance_profiles','meeting_calendar_settings','operator_territory_settings','service_request_notification_recipients','route_skip_approvers'] loop
   execute format('create policy security_manager_insert_gate on public.%I as restrictive for insert to authenticated with check (public.has_manager_access())',t);
   execute format('create policy security_manager_update_gate on public.%I as restrictive for update to authenticated using (public.has_manager_access()) with check (public.has_manager_access())',t);
   execute format('create policy security_manager_delete_gate on public.%I as restrictive for delete to authenticated using (public.has_manager_access())',t);
 end loop;
 -- Historical backups and import/audit copies must not expose alternate routes.
 for t in select tablename from pg_tables where schemaname='public' and (tablename like '%backup%' or tablename ~ '_audit_[0-9]') loop
   execute format('revoke all on public.%I from authenticated',t);
 end loop;
end $$;
create policy security_notification_read_gate on public.email_notification_queue as restrictive for select to authenticated using(employee_id=public.current_employee_id() or public.has_manager_access());
create policy security_notification_insert_gate on public.email_notification_queue as restrictive for insert to authenticated with check(public.has_manager_access());
create policy security_notification_update_gate on public.email_notification_queue as restrictive for update to authenticated using(public.has_manager_access()) with check(public.has_manager_access());
create policy security_notification_delete_gate on public.email_notification_queue as restrictive for delete to authenticated using(public.has_manager_access());
-- Employees may submit and cancel pending requests, never approve their own.
create or replace function public.security_guard_hr_request()
returns trigger language plpgsql security definer set search_path=pg_catalog,public as $$
begin
 if current_setting('role',true) not in ('anon','authenticated') or public.has_manager_access() then
   if tg_op='DELETE' then return old; else return new; end if;
 end if;
 if tg_op='DELETE' then raise exception 'Žádost lze zrušit, nikoli odstranit.' using errcode='42501'; end if;
 if new.status not in ('pending','cancelled') or new.manager_note is not null or new.approved_at is not null or new.approved_by_employee_id is not null
 or (tg_op='UPDATE' and old.status<>'pending') then
   raise exception 'Schválení žádosti může měnit pouze vedení.' using errcode='42501';
 end if;
 return new;
end $$;
revoke all on function public.security_guard_hr_request() from public,anon,authenticated;
create trigger security_guard_hr_request before insert or update or delete on public.hr_requests for each row execute function public.security_guard_hr_request();
-- Internal maintenance is not an employee-facing API.
revoke execute on function public.cleanup_telemetry_dex_history(integer),public.cleanup_coffee_visit_evidence_v41() from authenticated;
notify pgrst,'reload schema';
commit;
