begin;

create or replace function public.guard_coffee_visit_completion()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_container_key text;
begin
  if new.status = 'completed'
     and old.status is distinct from 'completed'
     and lower(coalesce(new.machine_kind, '')) = 'coffee'
  then
    select entry.key
      into v_container_key
    from jsonb_each(coalesce(new.coffee_preparation->'containers', '{}'::jsonb)) entry
    where coalesce(entry.value->>'accepted', 'false') <> 'true'
      and (
        case when jsonb_typeof(entry.value->'packages') = 'number'
          then (entry.value->>'packages')::numeric else 0 end > 0
        or case when jsonb_typeof(entry.value->'movedPackages') = 'number'
          then (entry.value->>'movedPackages')::numeric else 0 end > 0
        or entry.value ? 'actualBeforeQuantity'
        or entry.value->'stateCorrection' = 'true'::jsonb
        or entry.value->'addedOutsidePicklist' = 'true'::jsonb
      )
    limit 1;

    if v_container_key is not null then
      raise exception 'Návštěvu nelze dokončit: zásobník % nemá potvrzené doplnění nebo opravu skutečného stavu.', v_container_key
        using errcode = '23514';
    end if;
  end if;

  return new;
end
$$;

drop trigger if exists route_machine_visits_coffee_completion_guard
  on public.route_machine_visits;

create trigger route_machine_visits_coffee_completion_guard
before update of status on public.route_machine_visits
for each row
execute function public.guard_coffee_visit_completion();

commit;
