begin;

create or replace function public.guard_route_visit_completion_integrity_v63()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_expected_count integer := 0;
  v_missing_label text;
begin
  if new.status <> 'completed' or old.status = 'completed' then
    return new;
  end if;

  if lower(coalesce(new.machine_kind, '')) = 'coffee' then
    select count(*)
      into v_expected_count
    from public.machine_coffee_containers container
    where container.machine_id = new.machine_id
      and container.active = true;

    if v_expected_count = 0 then
      raise exception 'Návštěvu nelze dokončit: kávový automat nemá nastavený aktivní plánogram zásobníků.'
        using errcode = '23514';
    end if;

    select container.container_code
      into v_missing_label
    from public.machine_coffee_containers container
    where container.machine_id = new.machine_id
      and container.active = true
      and not exists (
        select 1
        from public.route_machine_visit_items item
        where item.visit_id = new.id
          and item.machine_id = new.machine_id
          and item.item_kind = 'coffee_container'
          and item.coffee_container_id = container.id
          and item.accepted_at is not null
      )
    order by container.sort_order, container.id
    limit 1;

    if v_missing_label is not null then
      raise exception 'Návštěvu nelze dokončit: zásobník % není potvrzený a uložený na serveru.', v_missing_label
        using errcode = '23514';
    end if;
  elsif lower(coalesce(new.machine_kind, '')) = 'food' then
    select count(*)
      into v_expected_count
    from public.machine_planogram_slots slot
    where slot.machine_id = new.machine_id
      and slot.active = true;

    if v_expected_count = 0 then
      raise exception 'Návštěvu nelze dokončit: potravinový automat nemá nastavený aktivní plánogram.'
        using errcode = '23514';
    end if;

    select slot.slot_code
      into v_missing_label
    from public.machine_planogram_slots slot
    where slot.machine_id = new.machine_id
      and slot.active = true
      and not exists (
        select 1
        from public.route_machine_visit_items item
        where item.visit_id = new.id
          and item.machine_id = new.machine_id
          and item.item_kind = 'food_slot'
          and item.planogram_slot_id = slot.id
          and item.accepted_at is not null
      )
    order by slot.sort_order, slot.id
    limit 1;

    if v_missing_label is not null then
      raise exception 'Návštěvu nelze dokončit: pozice % není potvrzená a uložená na serveru.', v_missing_label
        using errcode = '23514';
    end if;
  end if;

  return new;
end
$$;

drop trigger if exists route_machine_visits_completion_integrity_v63
  on public.route_machine_visits;

create trigger route_machine_visits_completion_integrity_v63
before update of status on public.route_machine_visits
for each row
execute function public.guard_route_visit_completion_integrity_v63();

commit;

notify pgrst, 'reload schema';
