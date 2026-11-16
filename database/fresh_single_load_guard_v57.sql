-- OLVEND v57: jedna fresh položka smí mít pro stejné vozidlo a den jen jeden
-- ranní zdroj. Pokud už ji obsahuje trasový doklad, mobil nesmí založit druhý
-- ruční vehicle_load; množství se upraví na původním řádku.

create or replace function public.guard_duplicate_manual_fresh_load_v57()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
declare
  v_request public.mobile_stock_requests%rowtype;
  v_product public.products%rowtype;
  v_existing_request_id bigint;
begin
  select * into v_request from public.mobile_stock_requests where id=new.request_id;
  if not found or v_request.request_type<>'vehicle_load'
     or v_request.route_plan_id is not null
     or coalesce(v_request.calculation_source,'manual')<>'manual' then
    return new;
  end if;

  select * into v_product from public.products where id=new.product_id;
  if not found or not (
    v_product.product_category='food_ready'
    or lower(coalesce(v_product.name,'')) like '%baget%'
    or lower(coalesce(v_product.name,'')) like '%strips%'
  ) then return new; end if;

  select other_request.id into v_existing_request_id
  from public.mobile_stock_requests other_request
  join public.mobile_stock_request_items other_item on other_item.request_id=other_request.id
  where other_request.id<>v_request.id
    and other_request.request_type='vehicle_load'
    and other_request.vehicle_id=v_request.vehicle_id
    and other_request.requested_for_date=v_request.requested_for_date
    and other_request.status<>'cancelled'
    and (other_request.route_plan_id is not null or other_request.calculation_source='route_plan')
    and other_item.product_id=new.product_id
    and coalesce(other_item.requested_quantity,0)>0
  order by other_request.id
  limit 1;

  if v_existing_request_id is not null then
    raise exception using
      errcode='23505',
      message=format(
        'Fresh položka %s už je pro toto vozidlo a dnešek v trasovém dokladu #%s. Uprav skutečně převzaté množství tam; druhý výdej není povolen.',
        coalesce(v_product.name,v_product.sku,'produkt'),v_existing_request_id
      );
  end if;

  return new;
end
$$;

drop trigger if exists mobile_stock_items_guard_duplicate_fresh_v57
on public.mobile_stock_request_items;
create trigger mobile_stock_items_guard_duplicate_fresh_v57
before insert or update of request_id,product_id,requested_quantity
on public.mobile_stock_request_items
for each row execute function public.guard_duplicate_manual_fresh_load_v57();

revoke all on function public.guard_duplicate_manual_fresh_load_v57() from public,anon,authenticated;

comment on function public.guard_duplicate_manual_fresh_load_v57() is
  'Blokuje druhý ruční ranní výdej fresh položky, pokud už existuje v trasovém dokladu stejného vozidla a dne.';

notify pgrst,'reload schema';
