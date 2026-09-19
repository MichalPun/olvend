begin;
create policy security_instruction_read_gate on public.daily_instructions as restrictive for select to authenticated using(
 public.has_manager_access() or target_type='company'
 or (target_type='employee' and target_employee_id=public.current_employee_id())
 or (target_type='role' and lower(target_role)=(select lower(role) from public.employees where auth_user_id=auth.uid()))
);
create policy security_instruction_insert_gate on public.daily_instructions as restrictive for insert to authenticated with check(public.has_manager_access());
create policy security_instruction_update_gate on public.daily_instructions as restrictive for update to authenticated using(public.has_manager_access()) with check(public.has_manager_access());
create policy security_instruction_delete_gate on public.daily_instructions as restrictive for delete to authenticated using(public.has_manager_access());
create policy security_personal_document_read_gate on storage.objects as restrictive for select to authenticated using(
 public.has_manager_access() or owner_id=auth.uid()::text
 or (bucket_id='daily-instructions' and exists(select 1 from public.daily_instructions d where right(split_part(d.attachment_url,'?',1),length(name)+1)='/'||name))
 or (bucket_id='shift-documents' and exists(select 1 from public.vehicle_operation_logs v where v.employee_id=public.current_employee_id() and right(split_part(v.fuel_receipt_url,'?',1),length(name)+1)='/'||name))
 or bucket_id not in ('daily-instructions','shift-documents')
);
commit;
