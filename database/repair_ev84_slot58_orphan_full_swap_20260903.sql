begin;

update public.machine_planogram_slots
set pending_change_mode = 'sell_through',
    updated_at = now()
where id = 1782
  and machine_id = 64
  and slot_code = '58'
  and product_sku = '139'
  and planned_product_sku = '20'
  and pending_product_sku is null
  and pending_change_mode = 'full_swap';

do $$
begin
  if exists (
    select 1
    from public.machine_planogram_slots
    where id = 1782
      and pending_product_sku is null
      and pending_change_mode = 'full_swap'
  ) then
    raise exception 'EV84 slot 58 remains blocked by orphan full_swap mode.';
  end if;
end
$$;

commit;

notify pgrst, 'reload schema';
