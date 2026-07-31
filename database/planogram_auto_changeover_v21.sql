-- Activate an explicitly planned product only after the current product reaches zero.
-- The sale that lowers current_units to zero is recorded before this slot update,
-- so it remains attributed to the original product.

create or replace function public.activate_planned_planogram_product_at_zero()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_planned_sku text;
  v_planned_name text;
  v_planned_price numeric;
begin
  v_planned_sku := nullif(trim(new.planned_product_sku), '');

  if coalesce(old.current_units, 0) > 0
     and coalesce(new.current_units, 0) <= 0
     and v_planned_sku is not null
     and v_planned_sku is distinct from nullif(trim(new.product_sku), '') then
    v_planned_name := nullif(trim(new.planned_product_name), '');
    v_planned_price := new.planned_price_czk;

    new.product_sku := v_planned_sku;
    new.product_name := coalesce(v_planned_name, new.product_name);

    if v_planned_price is not null then
      new.price_czk := v_planned_price;
      new.customer_price_czk := v_planned_price;
      new.dex_price_czk := v_planned_price;
    end if;

    new.planned_product_sku := null;
    new.planned_product_name := null;
    new.planned_price_czk := null;
    new.updated_at := now();
  end if;

  return new;
end;
$$;

drop trigger if exists machine_planogram_slots_activate_planned_at_zero
  on public.machine_planogram_slots;

create trigger machine_planogram_slots_activate_planned_at_zero
before update of current_units on public.machine_planogram_slots
for each row
execute function public.activate_planned_planogram_product_at_zero();

comment on function public.activate_planned_planogram_product_at_zero() is
  'When a stocked slot reaches zero, atomically activates its planned replacement product and price.';

