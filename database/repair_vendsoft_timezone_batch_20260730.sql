-- One-off repair of the first automatic VendSoft batch.
-- The XLSX timestamp was initially interpreted as UTC although it is a Prague wall-clock value.
-- The batch is removed and its stock deductions are reversed before the corrected parser reimports
-- only transactions newer than vendsoft_food_sync_state.started_at.

begin;

with batch as (
  select
    planogram_slot_id,
    sum(quantity) as quantity_to_restore
  from public.vendsoft_food_sales_imports
  where created_at >= '2026-07-30 17:42:00+00'::timestamptz
    and status = 'applied'
    and planogram_slot_id is not null
  group by planogram_slot_id
)
update public.machine_planogram_slots slot
set
  current_units = least(
    coalesce(slot.capacity_units, slot.current_units + batch.quantity_to_restore),
    slot.current_units + batch.quantity_to_restore
  ),
  fill_percent = case
    when coalesce(slot.capacity_units, 0) > 0
      then round(
        (
          least(
            slot.capacity_units,
            slot.current_units + batch.quantity_to_restore
          ) / slot.capacity_units
        ) * 100,
        2
      )
    else null
  end,
  updated_at = now()
from batch
where slot.id = batch.planogram_slot_id;

delete from public.telemetry_sales_events
where lower(provider) = 'vendsoft'
  and created_at >= '2026-07-30 17:42:00+00'::timestamptz;

delete from public.vendsoft_food_sales_imports
where created_at >= '2026-07-30 17:42:00+00'::timestamptz;

update public.vendsoft_food_sync_state
set
  last_seen_event_at = null,
  last_imported_count = 0,
  last_skipped_count = 0,
  last_unmatched_count = 0,
  last_error = null,
  updated_at = now()
where singleton = true;

commit;
