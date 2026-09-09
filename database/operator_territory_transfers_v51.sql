begin;

-- Keep the previous assignment available when a future handover is saved.
create or replace function public.snapshot_operator_territory_v51()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  insert into public.operator_territory_assignment_history
    (location_id,primary_employee_id,backup_employee_id,assignment_scope,selected_machine_ids,effective_from,note,changed_at,changed_by)
  values (old.location_id,old.primary_employee_id,old.backup_employee_id,old.assignment_scope,old.selected_machine_ids,old.effective_from,old.note,old.updated_at,old.updated_by);
  return new;
end;
$$;
revoke all on function public.snapshot_operator_territory_v51() from public;
drop trigger if exists snapshot_operator_territory_v51 on public.operator_territory_assignments;
create trigger snapshot_operator_territory_v51 before update on public.operator_territory_assignments
for each row execute function public.snapshot_operator_territory_v51();

create or replace function public.get_operator_territories_v51(p_date date default current_date)
returns setof public.operator_territory_assignments
language sql stable security definer set search_path=public as $$
  with versions as (
    select location_id, effective_from, updated_at as changed_at, 1 as priority, 0::bigint as sequence, to_jsonb(a) as value
      from public.operator_territory_assignments a
    union all
    select h.location_id,h.effective_from,h.changed_at,0,h.id,
      to_jsonb(a) || jsonb_build_object('primary_employee_id',h.primary_employee_id,
      'backup_employee_id',h.backup_employee_id,'assignment_scope',h.assignment_scope,
      'selected_machine_ids',h.selected_machine_ids,'effective_from',h.effective_from,'note',h.note)
      from public.operator_territory_assignment_history h
      join public.operator_territory_assignments a using(location_id)
  ), chosen as (
    select distinct on(location_id) value from versions
    where effective_from <= coalesce(p_date,current_date) and auth.uid() is not null
    order by location_id,effective_from desc,changed_at desc,priority desc,sequence desc
  ) select (jsonb_populate_record(null::public.operator_territory_assignments,value)).* from chosen;
$$;
revoke all on function public.get_operator_territories_v51(date) from public,anon;
grant execute on function public.get_operator_territories_v51(date) to authenticated;

create or replace function public.transfer_operator_territories_v51(p_changes jsonb,p_effective_from date,p_reason text)
returns integer language plpgsql security definer set search_path=public as $$
declare change jsonb; current_row public.operator_territory_assignments; effective_row public.operator_territory_assignments; target_id uuid; total integer:=0;
begin
  if not public.has_manager_access() then raise exception 'Předání může uložit pouze vedení.' using errcode='42501'; end if;
  if p_effective_from is null or p_effective_from < (now() at time zone 'Europe/Prague')::date then raise exception 'Vyberte dnešní nebo budoucí datum předání.'; end if;
  if length(trim(coalesce(p_reason,'')))<3 then raise exception 'Doplňte důvod předání.'; end if;
  if jsonb_typeof(p_changes) is distinct from 'array' or jsonb_array_length(p_changes) not between 1 and 1000 then raise exception 'Vyberte lokality k předání.'; end if;
  if (select count(distinct (x->>'location_id')::bigint) from jsonb_array_elements(p_changes)x) <> jsonb_array_length(p_changes) then raise exception 'Lokalita je uvedena vícekrát.'; end if;
  -- A consistent lock order and the revision check prevent overlapping handovers.
  for change in select x from jsonb_array_elements(p_changes)x order by (x->>'location_id')::bigint loop
    select * into current_row from public.operator_territory_assignments where location_id=(change->>'location_id')::bigint for update;
    if not found then raise exception 'Přiřazení lokality se změnilo. Obnovte náhled.'; end if;
    if current_row.updated_at is distinct from (change->>'expected_updated_at')::timestamptz then raise exception 'Rajón mezitím někdo upravil. Obnovte náhled.'; end if;
    select * into effective_row from public.get_operator_territories_v51(p_effective_from) where location_id=current_row.location_id;
    if not found or effective_row.primary_employee_id is distinct from (change->>'expected_owner_id')::uuid then raise exception 'Vlastník se změnil. Obnovte náhled.'; end if;
    target_id := (change->>'target_employee_id')::uuid;
    if not exists(select 1 from public.employees where id=target_id and active=true and lower(role) in ('operator','manager','admin')) then raise exception 'Vyberte aktivního operátora.'; end if;
    if target_id=effective_row.primary_employee_id then raise exception 'Nový operátor je stejný jako původní.'; end if;
    if not exists(select 1 from public.locations where id=current_row.location_id and active=true) then raise exception 'Lokalita už není aktivní.'; end if;
    if exists(select 1 from public.operator_territory_assignment_history where location_id=current_row.location_id and effective_from>p_effective_from)
       or current_row.effective_from>p_effective_from then raise exception 'Lokalita má naplánovanou pozdější změnu. Nejdřív zkontrolujte její datum.'; end if;
    perform public.save_operator_territory_assignment(current_row.location_id,target_id,
      case when effective_row.backup_employee_id=target_id then null else effective_row.backup_employee_id end,
      effective_row.assignment_scope,effective_row.selected_machine_ids,p_effective_from,
      concat('Hromadné předání: ',trim(p_reason),' | Původní operátor: ',effective_row.primary_employee_id));
    total:=total+1;
  end loop;
  return total;
end;
$$;
revoke all on function public.transfer_operator_territories_v51(jsonb,date,text) from public,anon;
grant execute on function public.transfer_operator_territories_v51(jsonb,date,text) to authenticated;
commit;
