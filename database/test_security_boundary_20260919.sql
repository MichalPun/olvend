-- All attempted writes are rolled back; no messages leave the transaction.
begin;
select set_config('test.operator',(select auth_user_id::text from public.employees where active and role='operator' and auth_user_id is not null limit 1),true);
select set_config('test.manager',(select auth_user_id::text from public.employees where active and role='admin' and auth_user_id is not null limit 1),true);
select set_config('test.inactive',(select auth_user_id::text from public.employees where active is false and auth_user_id is not null limit 1),true);
set local role authenticated;
select set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('test.operator'),'role','authenticated')::text,true);
do $$ declare n integer; begin
 if not public.security_active_employee() then raise exception 'Active operator rejected'; end if;
 if (select count(*) from public.employees)<>1 then raise exception 'Other employee profiles exposed'; end if;
 if (select count(*) from public.employee_directory)<2 then raise exception 'Staff directory unavailable'; end if;
 update public.employees set role='admin' where auth_user_id=auth.uid(); get diagnostics n=row_count;
 if n<>0 then raise exception 'Privilege escalation succeeded'; end if;
 if exists(select 1 from public.employee_location_logs where employee_id<>public.current_employee_id()) then raise exception 'Other GPS records exposed'; end if;
 if exists(select 1 from public.hr_requests where employee_id<>public.current_employee_id()) then raise exception 'Other HR records exposed'; end if;
 if exists(select 1 from public.payroll_month_entries) then raise exception 'Payroll exposed'; end if;
 begin
   insert into public.hr_requests(employee_id,request_type,status,date_from,date_to,reason)
   values(public.current_employee_id(),'vacation','approved',current_date,current_date,'Security rollback test');
   raise exception 'Employee approved own HR request';
 exception when insufficient_privilege then null; end;
 begin
   insert into public.email_notification_queue(employee_id,kind,subject,body)
   values(public.current_employee_id(),'task_assigned','Security rollback test','Must be denied');
   raise exception 'Employee forged email queue entry';
 exception when insufficient_privilege then null; end;
 if not exists(select 1 from public.machines) then raise exception 'Machine operations unavailable'; end if;
 perform public.get_mobile_route_sales_v42(array[58]::bigint[],now());
end $$;
select set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('test.inactive'),'role','authenticated')::text,true);
do $$ begin
 if public.security_active_employee() then raise exception 'Inactive account accepted'; end if;
 if exists(select 1 from public.machines) then raise exception 'Inactive RLS read succeeded'; end if;
 begin
   perform public.security_check_request();
   raise exception 'Inactive REST guard failed';
 exception when insufficient_privilege then null; end;
 begin
   perform public.apply_stock_movements_v13('[]'::jsonb);
   raise exception 'Inactive definer RPC allowed';
 exception when insufficient_privilege then null; end;
end $$;
select set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('test.manager'),'role','authenticated')::text,true);
do $$ begin
 if not public.has_manager_access() or (select count(*) from public.employees)<2 then raise exception 'Manager access broken'; end if;
 perform public.security_check_request();
end $$;
set local role anon;
select set_config('request.jwt.claims','{"role":"anon"}',true);
do $$ begin
 begin perform id from public.employees limit 1;raise exception 'Anonymous employee read succeeded';exception when insufficient_privilege then null;end;
 begin perform public.apply_stock_movements_v13('[]'::jsonb);raise exception 'Anonymous stock write succeeded';exception when insufficient_privilege then null;end;
 if exists(select 1 from storage.objects) then raise exception 'Anonymous files exposed';end if;
 if public.get_public_machine_by_qr('vendsoft-78') is null then raise exception 'Public QR unavailable';end if;
 perform public.submit_public_service_request('vendsoft-78','Bezpečnostní test rollback','Nahlášeno přes QR automatu · Neuložený test','normal');
end $$;
rollback;
select 'PASS: operator, manager, inactive, anonymous, files, public QR; writes rolled back' as result;
