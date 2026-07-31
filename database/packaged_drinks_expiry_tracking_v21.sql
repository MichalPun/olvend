with packaged_drinks as (
  select distinct p.id
  from public.products p
  join public.machine_planogram_slots s on s.product_sku = p.sku and s.active = true
  join public.machines m
    on m.id = s.machine_id
   and lower(coalesce(m.machine_type, '')) = 'snack'
  where p.active = true
    and p.product_category = 'beverage_ready'
)
update public.products p
set expiry_tracking_mode = 'best_before',
    expiry_warning_days = greatest(coalesce(p.expiry_warning_days, 0), 30),
    requires_batch_tracking = true,
    updated_at = now()
from packaged_drinks d
where p.id = d.id;

select count(*) as tracked_packaged_drinks
from public.products p
where p.active = true
  and p.product_category = 'beverage_ready'
  and p.expiry_tracking_mode = 'best_before'
  and p.requires_batch_tracking = true;
