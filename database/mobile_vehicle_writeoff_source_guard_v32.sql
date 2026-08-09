begin;

create or replace function public.guard_mobile_vehicle_writeoff_source_v32()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_request_id bigint;
  v_request_type text;
  v_vehicle_id bigint;
  v_expected_location_id bigint;
begin
  if new.reference_type is distinct from 'mobile_stock_request'
     or new.movement_type is distinct from 'waste'
     or coalesce(new.reference_id, '') !~ '^mobile-stock:[0-9]+$' then
    return new;
  end if;

  v_request_id := substring(new.reference_id from 'mobile-stock:([0-9]+)')::bigint;

  select request_type, vehicle_id
  into v_request_type, v_vehicle_id
  from public.mobile_stock_requests
  where id = v_request_id;

  if v_request_type <> 'vehicle_writeoff' then
    return new;
  end if;

  select id
  into v_expected_location_id
  from public.stock_locations
  where location_type = 'vehicle'
    and vehicle_id = v_vehicle_id
  order by id
  limit 1;

  if v_expected_location_id is null then
    raise exception 'Pro odpis #% není založen sklad konkrétního vozidla.', v_request_id;
  end if;

  if new.from_stock_location_id is distinct from v_expected_location_id then
    raise exception 'Odpis #% musí odečítat zásobu z vozidla (sklad %), nikoliv ze skladu %.',
      v_request_id, v_expected_location_id, new.from_stock_location_id;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_guard_mobile_vehicle_writeoff_source_v32
on public.stock_movements_v13;

create trigger trg_guard_mobile_vehicle_writeoff_source_v32
before insert on public.stock_movements_v13
for each row
execute function public.guard_mobile_vehicle_writeoff_source_v32();

comment on function public.guard_mobile_vehicle_writeoff_source_v32() is
  'Brání tomu, aby ruční mobilní odpis navázaný na vozidlo odečetl zásobu ze souhrnného skladu Automaty.';

commit;

notify pgrst, 'reload schema';
