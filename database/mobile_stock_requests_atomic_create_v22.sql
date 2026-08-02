-- Atomické vytvoření mobilního skladového dokladu.
-- Hlavička a řádky vzniknou v jediné DB transakci; aktivní doklad bez řádků
-- databáze odmítne i při použití starší verze mobilní aplikace.

begin;

create table if not exists public.mobile_stock_request_repair_audit_20260802 (
  request_id bigint primary key,
  request_before jsonb not null,
  items_before jsonb not null,
  repair_action text not null,
  repaired_at timestamptz not null default now()
);

alter table public.mobile_stock_request_repair_audit_20260802 enable row level security;

comment on table public.mobile_stock_request_repair_audit_20260802 is
  'Vratná záloha dokladů #253 až #255 před opravou osiřelých hlaviček dne 2026-08-02.';

do $$
declare
  v_request public.mobile_stock_requests%rowtype;
  v_item_count integer;
  v_movement_count integer;
begin
  if (select count(*) from public.mobile_stock_request_repair_audit_20260802) = 3 then
    return;
  elsif (select count(*) from public.mobile_stock_request_repair_audit_20260802) <> 0 then
    raise exception 'Záloha opravy #253 až #255 obsahuje neočekávaný počet řádků.';
  end if;

  if (
    select count(*)
    from public.stock_movements_v13
    where reference_type = 'data_repair'
      and reference_id in (
        'repair-renault-nestea-peach-load-20260801-batch-261',
        'repair-renault-nestea-peach-load-20260801-batch-262'
      )
      and product_id = 99
      and from_stock_location_id = 1
      and to_stock_location_id = 2
      and movement_type = 'load_vehicle'
  ) <> 2 or (
    select coalesce(sum(quantity_base_units), 0)
    from public.stock_movements_v13
    where reference_type = 'data_repair'
      and reference_id in (
        'repair-renault-nestea-peach-load-20260801-batch-261',
        'repair-renault-nestea-peach-load-20260801-batch-262'
      )
  ) <> 12 then
    raise exception 'Chybí přesný dříve provedený pohyb nakládky 12 ks Nestea; doklad #253 nelze pouze zdokumentovat.';
  end if;

  for v_request in
    select *
    from public.mobile_stock_requests
    where id in (253, 254, 255)
    order by id
    for update
  loop
    select count(*) into v_item_count
    from public.mobile_stock_request_items
    where request_id = v_request.id;

    select count(*) into v_movement_count
    from public.stock_movements_v13
    where reference_type = 'mobile_stock_request'
      and reference_id = coalesce(v_request.stock_reference_id, 'mobile-stock:' || v_request.id::text);

    if v_request.status not in ('picking', 'cancelled') or v_item_count <> 0 or v_movement_count <> 0
       or v_request.stock_applied_at is not null then
      raise exception
        'Doklad #% neodpovídá bezpečnému výchozímu stavu (status %, položky %, pohyby %, sklad %).',
        v_request.id, v_request.status, v_item_count, v_movement_count, v_request.stock_applied_at;
    end if;

    if (v_request.id = 253 and (v_request.request_type <> 'vehicle_load' or v_request.vehicle_id <> 1))
       or (v_request.id in (254, 255) and (v_request.request_type <> 'vehicle_unload' or v_request.vehicle_id <> 1)) then
      raise exception 'Doklad #% má neočekávaný typ nebo vozidlo.', v_request.id;
    end if;

    insert into public.mobile_stock_request_repair_audit_20260802 (
      request_id,
      request_before,
      items_before,
      repair_action
    ) values (
      v_request.id,
      to_jsonb(v_request),
      '[]'::jsonb,
      case when v_request.id = 253
        then 'document_existing_nestea_load'
        else 'cancel_empty_attempt_replaced_by_256'
      end
    )
    on conflict (request_id) do nothing;
  end loop;

  if (select count(*) from public.mobile_stock_request_repair_audit_20260802) <> 3 then
    raise exception 'Bezpečnostní kontrola opravy #253 až #255 nenalezla přesně tři zálohy.';
  end if;
end
$$;

insert into public.mobile_stock_request_items (
  request_id,
  product_id,
  product_name,
  sku,
  unit,
  requested_quantity,
  prepared_quantity,
  confirmed_quantity,
  batch_id,
  note
)
select
  source.request_id,
  source.product_id,
  source.product_name,
  source.sku,
  source.unit,
  source.requested_quantity,
  source.prepared_quantity,
  source.confirmed_quantity,
  source.batch_id,
  source.note
from (values
  (253::bigint, 99::bigint, 'Nestea Peach 0,5l'::text, '67'::text, 'ks'::text,
   8::numeric, 8::numeric, 8::numeric, 261::bigint,
   'Dokumentace fyzické nakládky 12 ks · FEFO šarže 261 · expirace 20.02.2027'::text),
  (253::bigint, 99::bigint, 'Nestea Peach 0,5l'::text, '67'::text, 'ks'::text,
   4::numeric, 4::numeric, 4::numeric, 262::bigint,
   'Dokumentace fyzické nakládky 12 ks · FEFO šarže 262 · expirace 30.03.2027'::text)
) as source(
  request_id,
  product_id,
  product_name,
  sku,
  unit,
  requested_quantity,
  prepared_quantity,
  confirmed_quantity,
  batch_id,
  note
)
where not exists (
  select 1
  from public.mobile_stock_request_items existing
  where existing.request_id = source.request_id
    and existing.product_id = source.product_id
    and existing.batch_id = source.batch_id
);

update public.mobile_stock_requests
set
  status = 'confirmed',
  warehouse_id = coalesce(
    warehouse_id,
    (select warehouse_id from public.vehicles where id = mobile_stock_requests.vehicle_id)
  ),
  prepared_by = employee_id,
  prepared_at = timestamptz '2026-08-01 12:09:49.158845+00',
  confirmed_by = employee_id,
  confirmed_at = timestamptz '2026-08-01 12:09:49.158845+00',
  stock_applied_at = timestamptz '2026-08-01 12:09:49.158845+00',
  stock_reference_id = 'repair-renault-nestea-peach-load-20260801',
  note = 'Potvrzená fyzická nakládka 12 ks Nestea Peach. Skladové pohyby byly dříve bezpečně doplněny opravou; tento doklad pouze obnovuje chybějící historii a zásoby znovu nemění.',
  updated_at = now()
where id = 253;

update public.mobile_stock_requests
set
  status = 'cancelled',
  note = 'Prázdný přerušený pokus o vykládku. Bez položek a bez skladového pohybu; nahrazeno dokončenou vykládkou #256.',
  updated_at = now()
where id in (254, 255);

create or replace function public.enforce_mobile_stock_request_has_items_v22()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.status in ('requested', 'picking', 'ready', 'confirmed')
     and not exists (
       select 1
       from public.mobile_stock_request_items item
       where item.request_id = new.id
     ) then
    raise exception 'Aktivní skladový doklad #% musí obsahovat alespoň jednu položku.', new.id;
  end if;
  return new;
end
$$;

drop trigger if exists trg_mobile_stock_request_has_items_v22
on public.mobile_stock_requests;

create constraint trigger trg_mobile_stock_request_has_items_v22
after insert or update
on public.mobile_stock_requests
deferrable initially deferred
for each row
execute function public.enforce_mobile_stock_request_has_items_v22();

create or replace function public.create_mobile_stock_request_with_items_v22(
  request_payload jsonb,
  items_payload jsonb
)
returns jsonb
language plpgsql
set search_path = public
as $$
declare
  v_request public.mobile_stock_requests%rowtype;
  v_items jsonb;
  v_request_type text := nullif(request_payload->>'request_type', '');
  v_status text := nullif(request_payload->>'status', '');
begin
  if v_request_type is null or v_request_type not in (
    'vehicle_order',
    'vehicle_load',
    'vehicle_unload',
    'vehicle_sale',
    'vehicle_return',
    'vehicle_writeoff'
  ) then
    raise exception 'Neplatný typ skladového dokladu.';
  end if;

  if v_status is null or v_status not in ('requested', 'picking') then
    raise exception 'Nový mobilní skladový doklad musí být ve stavu requested nebo picking.';
  end if;

  if jsonb_typeof(items_payload) <> 'array' or jsonb_array_length(items_payload) = 0 then
    raise exception 'Skladový doklad musí obsahovat alespoň jednu položku.';
  end if;

  if nullif(request_payload->>'vehicle_id', '') is null then
    raise exception 'Skladový doklad musí mít vybrané vozidlo.';
  end if;

  if exists (
    select 1
    from jsonb_array_elements(items_payload) item
    where coalesce(nullif(item->>'requested_quantity', '')::numeric, 0) <= 0
  ) then
    raise exception 'Každá položka skladového dokladu musí mít množství větší než nula.';
  end if;

  if exists (
    select 1
    from jsonb_array_elements(items_payload) item
    where nullif(item->>'batch_id', '') is not null
      and not exists (
        select 1
        from public.inventory_batches batch
        where batch.id = (item->>'batch_id')::bigint
          and batch.product_id = nullif(item->>'product_id', '')::bigint
      )
  ) then
    raise exception 'Vybraná šarže nepatří k produktu skladového řádku.';
  end if;

  insert into public.mobile_stock_requests (
    request_type,
    status,
    employee_id,
    vehicle_id,
    warehouse_id,
    attendance_day_id,
    loading_session_id,
    source_stock_location_id,
    target_stock_location_id,
    route_plan_id,
    calculation_source,
    requested_for_date,
    confirmed_by,
    confirmed_at,
    note
  ) values (
    v_request_type,
    v_status,
    nullif(request_payload->>'employee_id', '')::uuid,
    (request_payload->>'vehicle_id')::bigint,
    nullif(request_payload->>'warehouse_id', '')::bigint,
    nullif(request_payload->>'attendance_day_id', '')::bigint,
    nullif(request_payload->>'loading_session_id', '')::bigint,
    nullif(request_payload->>'source_stock_location_id', '')::bigint,
    nullif(request_payload->>'target_stock_location_id', '')::bigint,
    nullif(request_payload->>'route_plan_id', '')::bigint,
    coalesce(nullif(request_payload->>'calculation_source', ''), 'manual'),
    coalesce(nullif(request_payload->>'requested_for_date', '')::date, current_date),
    nullif(request_payload->>'confirmed_by', '')::uuid,
    nullif(request_payload->>'confirmed_at', '')::timestamptz,
    nullif(request_payload->>'note', '')
  )
  returning * into v_request;

  with inserted as (
    insert into public.mobile_stock_request_items (
      request_id,
      product_id,
      product_name,
      sku,
      unit,
      requested_quantity,
      prepared_quantity,
      confirmed_quantity,
      note,
      batch_id
    )
    select
      v_request.id,
      nullif(item->>'product_id', '')::bigint,
      nullif(item->>'product_name', ''),
      nullif(item->>'sku', ''),
      nullif(item->>'unit', ''),
      (item->>'requested_quantity')::numeric,
      nullif(item->>'prepared_quantity', '')::numeric,
      nullif(item->>'confirmed_quantity', '')::numeric,
      nullif(item->>'note', ''),
      nullif(item->>'batch_id', '')::bigint
    from jsonb_array_elements(items_payload) item
    returning *
  )
  select coalesce(jsonb_agg(to_jsonb(inserted) order by inserted.id), '[]'::jsonb)
  into v_items
  from inserted;

  if jsonb_array_length(v_items) <> jsonb_array_length(items_payload) then
    raise exception 'Položky skladového dokladu se neuložily kompletně.';
  end if;

  return jsonb_build_object(
    'request', to_jsonb(v_request),
    'items', v_items
  );
end
$$;

create or replace function public.cancel_unapplied_mobile_stock_request_v22(
  request_id_value bigint,
  reason_value text default null
)
returns boolean
language plpgsql
set search_path = public
as $$
declare
  v_request public.mobile_stock_requests%rowtype;
  v_reference_id text;
begin
  select *
  into v_request
  from public.mobile_stock_requests
  where id = request_id_value
  for update;

  if not found then
    return false;
  end if;

  v_reference_id := coalesce(v_request.stock_reference_id, 'mobile-stock:' || v_request.id::text);

  if v_request.stock_applied_at is not null or exists (
    select 1
    from public.stock_movements_v13 movement
    where movement.reference_type = 'mobile_stock_request'
      and movement.reference_id = v_reference_id
  ) then
    raise exception 'Doklad #% už má skladový pohyb a nelze ho automaticky zrušit.', v_request.id;
  end if;

  update public.mobile_stock_requests
  set
    status = 'cancelled',
    note = concat_ws(
      ' · ',
      nullif(reason_value, ''),
      nullif(v_request.note, ''),
      'Automaticky zrušeno po nedokončeném mobilním zápisu.'
    ),
    updated_at = now()
  where id = v_request.id;

  return true;
end
$$;

revoke all on function public.create_mobile_stock_request_with_items_v22(jsonb, jsonb) from public;
grant execute on function public.create_mobile_stock_request_with_items_v22(jsonb, jsonb) to authenticated, anon;

revoke all on function public.cancel_unapplied_mobile_stock_request_v22(bigint, text) from public;
grant execute on function public.cancel_unapplied_mobile_stock_request_v22(bigint, text) to authenticated, anon;

commit;

notify pgrst, 'reload schema';
