-- Deploy secure-files.js before switching these buckets to private.
begin;
do $$ declare p record; begin
 for p in select policyname from pg_policies where schemaname='storage' and tablename='objects'
 and ('anon'=any(roles) or 'public'=any(roles)) loop
   execute format('alter policy %I on storage.objects to authenticated',p.policyname);
 end loop;
end $$;
create policy security_active_employee_gate on storage.objects as restrictive for all to authenticated
 using((select public.security_active_employee())) with check((select public.security_active_employee()));
update storage.buckets set public=false where id in ('daily-instructions','technical-job-files','shift-documents');
commit;
