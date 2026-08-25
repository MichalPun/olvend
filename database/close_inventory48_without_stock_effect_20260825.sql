-- Inventory #48 was counted almost six days after its book snapshot and after
-- three completed routes. The recorded difference therefore cannot be used to
-- determine operator responsibility. Close the case as a managerial decision
-- only: preserve the original observation, create no stock movement and cancel
-- the unfinished warehouse follow-up #52.

begin;

do $$
declare
  v_parent public.inventory_audits%rowtype;
  v_control public.inventory_audits%rowtype;
  v_parent_item_count integer;
  v_control_item_count integer;
begin
  select * into v_parent
  from public.inventory_audits
  where id = 48
  for update;

  select * into v_control
  from public.inventory_audits
  where id = 52
  for update;

  if v_parent.id is null
     or v_parent.audit_date <> date '2026-08-19'
     or v_parent.scope_type <> 'vehicle'
     or v_parent.stock_location_id <> 4
     or v_parent.vehicle_id <> 3
     or v_parent.assigned_employee_id <> '9133f82b-89a6-4581-955c-d2138b947a8d'::uuid
     or v_parent.status <> 'counted'
     or v_parent.resolution_status <> 'warehouse_check'
     or v_parent.difference_value_total <> -2275.60 then
    raise exception 'Inventura #48 už neodpovídá ověřenému výchozímu stavu.';
  end if;

  if v_control.id is null
     or v_control.parent_audit_id <> 48
     or v_control.scope_type <> 'warehouse'
     or v_control.audit_origin <> 'vehicle_discrepancy_control'
     or v_control.status <> 'assigned'
     or v_control.counted_at is not null then
    raise exception 'Kontrola skladu #52 už není bezpečně zrušitelná.';
  end if;

  select count(*) into v_parent_item_count
  from public.inventory_audit_items
  where audit_id = 48;

  select count(*) into v_control_item_count
  from public.inventory_audit_items
  where audit_id = 52;

  if v_parent_item_count <> 13 or v_control_item_count <> 3 then
    raise exception 'Inventury #48/#52 mají neočekávaný počet položek (%/%).',
      v_parent_item_count, v_control_item_count;
  end if;

  if exists (
    select 1
    from public.inventory_audit_items
    where audit_id in (48, 52)
      and movement_id is not null
  ) or exists (
    select 1
    from public.stock_movements_v13
    where reference_id in (
      'inventory-audit:48', 'vehicle-inventory:48',
      'inventory-audit:52', 'vehicle-inventory:52'
    )
  ) then
    raise exception 'Inventura #48 nebo kontrola #52 už má skladový dopad.';
  end if;

  if exists (
    select 1
    from public.inventory_audit_items
    where audit_id = 52
      and (
        counted_at is not null
        or counted_quantity <> 0
        or difference_quantity <> 0
        or difference_value <> 0
      )
  ) then
    raise exception 'Kontrola skladu #52 už obsahuje fyzické počty.';
  end if;

  update public.inventory_audit_items
  set resolution_code = 'no_operator',
      resolution_note = 'Bez odpovědnosti operátorky: fyzický počet z 24. 8. 2026 byl porovnán se snapshotem z 18. 8. 2026, mezi nimiž proběhly tři trasy. Původní rozdíl je ponechán pouze jako historický záznam.',
      charge_selected = false,
      charge_quantity = 0,
      charge_amount = 0
  where audit_id = 48;

  update public.inventory_audits
  set status = 'cancelled',
      resolution_status = 'manager_review',
      assigned_employee_id = null,
      responsible_name = 'Fronta skladu BLUČINA',
      note = concat_ws(E'\n', nullif(note, ''),
        'Kontrola skladu zrušena 25. 8. 2026 rozhodnutím manažera. Vznikla z neaktuálního snapshotu inventury #48; fyzické počítání ani skladové pohyby nebyly zahájeny.'),
      updated_at = now()
  where id = 52;

  update public.daily_instructions
  set is_active = false,
      updated_at = now()
  where id = v_parent.instruction_id;

  update public.inventory_audits
  set status = 'closed',
      resolution_status = 'ready_to_send',
      responsibility_status = 'not_operator',
      responsibility_decision_note = 'Bez odpovědnosti Kristýny Dvořákové. Inventura byla spočítána 24. 8. 2026 proti snapshotu z 18. 8. 2026 a mezitím proběhly tři celé trasy. Evidované pohyby vysvětlují většinu rozdílů; historický výsledek není způsobilý pro výpočet manka.',
      responsibility_decided_at = now(),
      bonus_impact_amount = 0,
      evaluated_at = coalesce(evaluated_at, now()),
      closed_at = now(),
      evaluation_note = concat_ws(E'\n', nullif(evaluation_note, ''),
        'Uzavřeno 25. 8. 2026 bez skladového dorovnání a bez finančního dopadu. Původní inventurní rozdíl zůstává v protokolu pouze jako historický údaj; zásoby vozidla ani skladu nebyly změněny.'),
      updated_at = now()
  where id = 48;

  if not exists (
       select 1
       from public.inventory_audits
       where id = 48
         and status = 'closed'
         and responsibility_status = 'not_operator'
         and bonus_impact_amount = 0
     )
     or exists (
       select 1
       from public.inventory_audit_items
       where audit_id = 48
         and (
           resolution_code <> 'no_operator'
           or charge_selected
           or charge_quantity <> 0
           or charge_amount <> 0
         )
     )
     or not exists (
       select 1
       from public.inventory_audits
       where id = 52 and status = 'cancelled'
     )
     or exists (
       select 1
       from public.stock_movements_v13
       where reference_id in (
         'inventory-audit:48', 'vehicle-inventory:48',
         'inventory-audit:52', 'vehicle-inventory:52'
       )
     ) then
    raise exception 'Kontrola bezpečného uzavření inventury #48 selhala.';
  end if;
end;
$$;

commit;

select
  audit.id,
  audit.status,
  audit.resolution_status,
  audit.responsibility_status,
  audit.difference_value_total,
  audit.bonus_impact_amount,
  audit.closed_at,
  (select coalesce(sum(item.charge_amount), 0)
   from public.inventory_audit_items item
   where item.audit_id = audit.id) as charge_total,
  (select count(*)
   from public.stock_movements_v13 movement
   where movement.reference_id in (
     'inventory-audit:' || audit.id::text,
     'vehicle-inventory:' || audit.id::text
   )) as stock_movement_count
from public.inventory_audits audit
where audit.id in (48, 52)
order by audit.id;
