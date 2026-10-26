-- První návštěva nového kávového automatu musí vycházet z fyzické kontroly.
-- Automaticky hromadně potvrzená nula už nesmí inicializovat zásobník.
begin;

create or replace function public.guard_route_visit_completion_integrity_v65()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_expected_count integer := 0;
  v_missing_label text;
  v_stock_initialized_at timestamptz;
begin
  if new.status <> 'completed'
     or (tg_op = 'UPDATE' and old.status = 'completed') then
    return new;
  end if;

  if lower(coalesce(new.machine_kind, '')) = 'coffee' then
    select machine.stock_initialized_at
      into v_stock_initialized_at
    from public.machines machine
    where machine.id = new.machine_id;

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
          and not (
            v_stock_initialized_at is null
            and coalesce(item.actual_before_quantity, 0) = 0
            and coalesce(item.actual_add_quantity, 0) = 0
            and coalesce(item.final_quantity, 0) = 0
            and item.operator_note ilike 'Hromadně potvrzeno při dokončení:%'
          )
          and (
            (
              item.final_quantity is not null
              and item.actual_before_quantity is not null
              and item.capacity_quantity is not null
              and item.capacity_quantity > 0
              and item.final_quantity >= 0
              and item.final_quantity <= container.capacity_quantity
                + case
                    when item.actual_before_quantity <= container.capacity_quantity * 0.1 + 0.0001
                      then coalesce(container.refill_package_quantity, 0)
                    else 0
                  end
                + 0.011
              and abs(
                item.final_quantity
                - (item.actual_before_quantity + coalesce(item.actual_add_quantity, 0) - coalesce(item.removed_quantity, 0))
              ) <= 0.011
            )
            or (
              item.final_quantity is null
              and item.issue_type = 'missing_stock'
              and coalesce(item.actual_add_quantity, 0) = 0
              and length(trim(coalesce(item.operator_note, ''))) >= 10
            )
          )
      )
    order by container.sort_order, container.id
    limit 1;

    if v_missing_label is not null then
      raise exception 'Návštěvu nelze dokončit: zásobník % nemá fyzicky potvrzený stav.', v_missing_label
        using errcode = '23514';
    end if;

    update public.machines
       set stock_initialized_at = coalesce(stock_initialized_at, now()),
           updated_at = now()
     where id = new.machine_id
       and stock_initialized_at is null;
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
          and item.actual_before_quantity is not null
          and item.final_quantity is not null
          and item.capacity_quantity is not null
          and item.capacity_quantity > 0
          and item.final_quantity >= 0
          and item.final_quantity <= slot.capacity_units + 0.011
          and abs(
            item.final_quantity
            - (item.actual_before_quantity + coalesce(item.actual_add_quantity, 0) - coalesce(item.removed_quantity, 0))
          ) <= 0.011
      )
    order by slot.sort_order, slot.id
    limit 1;

    if v_missing_label is not null then
      raise exception 'Návštěvu nelze dokončit: pozice % nemá platný potvrzený stav.', v_missing_label
        using errcode = '23514';
    end if;
  end if;

  return new;
end
$$;

drop trigger if exists route_machine_visits_completion_insert_v64 on public.route_machine_visits;
drop trigger if exists route_machine_visits_completion_update_v64 on public.route_machine_visits;
drop trigger if exists route_machine_visits_completion_insert_v65 on public.route_machine_visits;
drop trigger if exists route_machine_visits_completion_update_v65 on public.route_machine_visits;

create trigger route_machine_visits_completion_insert_v65
before insert on public.route_machine_visits
for each row execute function public.guard_route_visit_completion_integrity_v65();

create trigger route_machine_visits_completion_update_v65
before update of status on public.route_machine_visits
for each row execute function public.guard_route_visit_completion_integrity_v65();

commit;
notify pgrst, 'reload schema';

