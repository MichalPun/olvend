begin;

delete from public.purchase_order_items
where purchase_order_id in (
  select id
  from public.purchase_orders
  where order_scope = 'bagette_pilot'
);

delete from public.purchase_orders
where order_scope = 'bagette_pilot';

delete from public.purchase_product_profiles
where pilot_scope = 'bagette';

delete from public.purchase_recurring_order_items
where recurring_order_id in (
  select id
  from public.purchase_recurring_orders
  where pilot_scope = 'bagette'
);

delete from public.purchase_recurring_orders
where pilot_scope = 'bagette';

commit;
