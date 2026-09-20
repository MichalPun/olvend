begin;
select set_config('request.jwt.claims',jsonb_build_object('sub',(select auth_user_id from public.employees where active and role='admin' and auth_user_id is not null limit 1),'role','authenticated')::text,true);
do $$ declare pid bigint; loc bigint; before_qty numeric; after_qty numeric; result jsonb; begin
 if exists(select 1 from public.products p join public.supplier_product_mappings m on m.product_id=p.id where m.supplier_id=3 and (p.expiry_tracking_mode<>'none' or p.requires_batch_tracking)) then raise exception 'JIP expiry still required'; end if;
 select m.product_id into strict pid from public.supplier_product_mappings m where m.supplier_id=3 limit 1;
 update public.products set expiry_tracking_mode='best_before',requires_batch_tracking=true where id=pid;
 if exists(select 1 from public.products where id=pid and (expiry_tracking_mode<>'none' or requires_batch_tracking)) then raise exception 'JIP policy was bypassed'; end if;
 select b.stock_location_id,b.quantity_on_hand into strict loc,before_qty from public.stock_location_balances b join public.stock_locations l on l.id=b.stock_location_id where b.product_id=pid and b.batch_id is null and l.location_type='warehouse' order by b.id limit 1 for update of b;
 result:=public.apply_stock_movements_v13(jsonb_build_array(jsonb_build_object('product_id',pid,'from_stock_location_id',loc,'movement_type','load_vehicle','quantity_base_units',greatest(before_qty,0)+3,'allow_negative_source',true,'reference_type','security_test','reference_id','jip-negative-rollback')));
 select quantity_on_hand into after_qty from public.stock_location_balances where stock_location_id=loc and product_id=pid and batch_id is null order by id limit 1;
 if after_qty<>before_qty-greatest(before_qty,0)-3 or after_qty>=0 then raise exception 'Negative stock not applied correctly'; end if;
 if has_function_privilege('anon','public.jip_product_expiry_policy_20260920()','execute') or has_function_privilege('authenticated','public.jip_product_expiry_policy_20260920()','execute') then raise exception 'Trigger function exposed as RPC'; end if;
end $$;
rollback;
select 'PASS: JIP expiry policy, protected trigger, negative stock; test writes rolled back' as result;
