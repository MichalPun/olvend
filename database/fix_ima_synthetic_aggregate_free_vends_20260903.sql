begin;

create table if not exists public.telemetry_synthetic_free_backup_20260903 as
select sale.*
from public.telemetry_sales_events sale
join public.machine_planogram_slots slot on slot.id = sale.planogram_slot_id
where false;

insert into public.telemetry_synthetic_free_backup_20260903
select sale.*
from public.telemetry_sales_events sale
join public.machine_planogram_slots slot on slot.id = sale.planogram_slot_id
where sale.provider = 'IMA'
  and trim(coalesce(sale.selection_code, '')) = '0'
  and lower(trim(coalesce(slot.product_name, ''))) in (
    'telemetrie prodej kava',
    'telemetrie prodej kava new',
    'telemetrie prodej káva',
    'telemetrie prodej káva new'
  )
  and coalesce(sale.free_vend_quantity, 0) > 0
  and not exists (
    select 1
    from public.telemetry_synthetic_free_backup_20260903 backup
    where backup.id = sale.id
  );

update public.telemetry_sales_events sale
set
  unknown_payment_quantity = coalesce(sale.unknown_payment_quantity, 0) + coalesce(sale.free_vend_quantity, 0),
  free_vend_quantity = 0,
  unknown_payment_amount_czk = coalesce(sale.unknown_payment_amount_czk, 0)
from public.machine_planogram_slots slot
where slot.id = sale.planogram_slot_id
  and sale.provider = 'IMA'
  and trim(coalesce(sale.selection_code, '')) = '0'
  and lower(trim(coalesce(slot.product_name, ''))) in (
    'telemetrie prodej kava',
    'telemetrie prodej kava new',
    'telemetrie prodej káva',
    'telemetrie prodej káva new'
  )
  and coalesce(sale.free_vend_quantity, 0) > 0;

do $$
declare
  v_remaining integer;
begin
  select count(*)
  into v_remaining
  from public.telemetry_sales_events sale
  join public.machine_planogram_slots slot on slot.id = sale.planogram_slot_id
  where sale.provider = 'IMA'
    and trim(coalesce(sale.selection_code, '')) = '0'
    and lower(trim(coalesce(slot.product_name, ''))) in (
      'telemetrie prodej kava',
      'telemetrie prodej kava new',
      'telemetrie prodej káva',
      'telemetrie prodej káva new'
    )
    and coalesce(sale.free_vend_quantity, 0) > 0;

  if v_remaining <> 0 then
    raise exception 'Synthetic aggregate free-vend correction failed: % rows remain', v_remaining;
  end if;
end $$;

commit;
