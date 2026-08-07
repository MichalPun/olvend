begin;

update public.products
set
  expiry_tracking_mode = 'best_before',
  expiry_warning_days = greatest(coalesce(expiry_warning_days, 0), 30),
  requires_batch_tracking = true,
  updated_at = now()
where (id = 156 and sku = '276')
   or (id = 155 and sku = '275');

do $$
declare
  v_enabled_count integer;
begin
  select count(*)
    into v_enabled_count
  from public.products
  where ((id = 156 and sku = '276') or (id = 155 and sku = '275'))
    and expiry_tracking_mode = 'best_before'
    and requires_batch_tracking = true
    and expiry_warning_days >= 30;

  if v_enabled_count <> 2 then
    raise exception 'Expiry tracking was enabled for % of 2 expected products.', v_enabled_count;
  end if;
end
$$;

commit;

select id, sku, name, expiry_tracking_mode, expiry_warning_days, requires_batch_tracking
from public.products
where id in (155, 156)
order by id;
