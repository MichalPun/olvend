begin;

create or replace function public.sync_machine_slot_expiry_from_stock(
  p_stock_location_id bigint,
  p_product_id bigint
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_machine_id bigint;
  v_product_sku text;
  v_next_expiry date;
begin
  select location.machine_id
  into v_machine_id
  from public.stock_locations location
  where location.id = p_stock_location_id
    and location.location_type = 'machine';

  if v_machine_id is null then
    return;
  end if;

  select product.sku
  into v_product_sku
  from public.products product
  where product.id = p_product_id;

  if nullif(trim(coalesce(v_product_sku, '')), '') is null then
    return;
  end if;

  select min(coalesce(batch.use_by_date, batch.best_before_date))
  into v_next_expiry
  from public.stock_location_balances balance
  join public.inventory_batches batch on batch.id = balance.batch_id
  where balance.stock_location_id = p_stock_location_id
    and balance.product_id = p_product_id
    and balance.quantity_on_hand > 0;

  update public.machine_planogram_slots slot
  set expiry_date = v_next_expiry,
      updated_at = now()
  where slot.machine_id = v_machine_id
    and slot.active = true
    and trim(coalesce(slot.product_sku, '')) = trim(v_product_sku)
    and slot.expiry_date is distinct from v_next_expiry;
end;
$$;

create or replace function public.sync_machine_slot_expiry_from_balance_trigger()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'DELETE' then
    perform public.sync_machine_slot_expiry_from_stock(old.stock_location_id, old.product_id);
    return old;
  end if;

  perform public.sync_machine_slot_expiry_from_stock(new.stock_location_id, new.product_id);

  if tg_op = 'UPDATE'
     and (old.stock_location_id, old.product_id) is distinct from (new.stock_location_id, new.product_id) then
    perform public.sync_machine_slot_expiry_from_stock(old.stock_location_id, old.product_id);
  end if;

  return new;
end;
$$;

drop trigger if exists sync_machine_slot_expiry_from_balance
  on public.stock_location_balances;

create trigger sync_machine_slot_expiry_from_balance
after insert or update of quantity_on_hand, batch_id, stock_location_id, product_id or delete
on public.stock_location_balances
for each row
execute function public.sync_machine_slot_expiry_from_balance_trigger();

do $$
declare
  pair record;
begin
  for pair in
    select distinct balance.stock_location_id, balance.product_id
    from public.stock_location_balances balance
    join public.stock_locations location on location.id = balance.stock_location_id
    where location.location_type = 'machine'
  loop
    perform public.sync_machine_slot_expiry_from_stock(pair.stock_location_id, pair.product_id);
  end loop;
end;
$$;

revoke all on function public.sync_machine_slot_expiry_from_stock(bigint, bigint) from public;
grant execute on function public.sync_machine_slot_expiry_from_stock(bigint, bigint) to service_role;

commit;

notify pgrst, 'reload schema';
