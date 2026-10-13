-- OLVEND v53: schválený automat patří na první otevřené místo probíhající
-- trasy. Hotové zastávky zůstanou beze změny; dosud otevřené se posunou.
-- Trigger opravuje i aktuálně nasazenou v52 funkci, která počítala max + 1.

create or replace function public.place_approved_route_add_next_v53()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_next_order integer;
begin
  if new.stop_kind <> 'restock' or not exists(
    select 1
    from public.route_add_machine_requests r
    where r.route_plan_id = new.route_plan_id
      and r.machine_id = new.machine_id
      and r.status = 'pending'
  ) then
    return new;
  end if;

  perform 1 from public.route_plans where id = new.route_plan_id for update;

  select min(s.stop_order) into v_next_order
  from public.route_plan_stops s
  where s.route_plan_id = new.route_plan_id
    and not (
      s.status in ('done','completed','skipped')
      or s.completed_at is not null
      or s.skipped_at is not null
    );

  -- Když už nejsou žádné otevřené zastávky, původní max + 1 je správně.
  if v_next_order is null then
    return new;
  end if;

  -- Novější definice v52 může mít pořadí připravené už před insertem.
  if new.stop_order < v_next_order then
    return new;
  end if;

  -- Dvoufázový posun neporuší unique(route_plan_id, stop_order).
  update public.route_plan_stops
  set stop_order = stop_order + 1000000
  where route_plan_id = new.route_plan_id and stop_order >= v_next_order;

  update public.route_plan_stops
  set stop_order = stop_order - 999999
  where route_plan_id = new.route_plan_id and stop_order >= v_next_order + 1000000;

  new.stop_order := v_next_order;
  return new;
end;
$$;

drop trigger if exists trg_place_approved_route_add_next_v53 on public.route_plan_stops;
create trigger trg_place_approved_route_add_next_v53
before insert on public.route_plan_stops
for each row execute function public.place_approved_route_add_next_v53();

comment on function public.place_approved_route_add_next_v53() is
  'Vloží automat schválený z mobilní žádosti jako první otevřenou zastávku probíhající trasy.';
