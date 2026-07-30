begin;

update public.products
set
  expiry_tracking_mode = 'best_before',
  expiry_warning_days = 30,
  requires_batch_tracking = false,
  updated_at = now()
where product_category = 'snack_ready'
  and usage_type = 'direct_sale';

commit;

notify pgrst, 'reload schema';
