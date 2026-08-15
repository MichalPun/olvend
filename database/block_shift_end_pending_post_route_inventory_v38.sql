begin;

create or replace function public.block_shift_end_with_pending_post_route_inventory_v38()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_audit_id bigint;
begin
  if new.actual_end is null or old.actual_end is not null then
    return new;
  end if;

  select audit.id
    into v_audit_id
  from public.inventory_audits audit
  where audit.assigned_employee_id = new.employee_id
    and audit.audit_date = new.attendance_date
    and audit.audit_origin = 'post_route_exception'
    and audit.status = 'assigned'
  order by audit.created_at desc, audit.id desc
  limit 1;

  if v_audit_id is not null then
    raise exception using
      errcode = 'P0001',
      message = format(
        'Směnu nelze ukončit: kontrolní inventura #%s ještě není dokončená.',
        v_audit_id
      );
  end if;

  return new;
end
$$;

drop trigger if exists trg_block_shift_end_pending_post_route_inventory_v38
  on public.attendance_days;

create trigger trg_block_shift_end_pending_post_route_inventory_v38
before update of actual_end, status on public.attendance_days
for each row
execute function public.block_shift_end_with_pending_post_route_inventory_v38();

commit;
