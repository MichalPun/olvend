begin;

do $$
declare
  v_created jsonb;
begin
  if exists (
    select 1
    from public.mobile_stock_requests request
    join public.mobile_stock_request_items item on item.request_id = request.id
    where request.route_plan_id = 83
      and request.vehicle_id = 2
      and request.request_type in ('vehicle_order', 'vehicle_load')
      and request.status <> 'cancelled'
      and item.product_id = 205
  ) then
    raise exception 'Trasa #83 uz ma aktivni doklad s Proteinovym sukem.';
  end if;

  select public.create_mobile_stock_request_with_items_v22(
    jsonb_build_object(
      'request_type', 'vehicle_order',
      'status', 'requested',
      'employee_id', '7f724803-eb2e-44fc-afba-0b87b82cdbc5',
      'vehicle_id', 2,
      'warehouse_id', 1,
      'route_plan_id', 83,
      'calculation_source', 'route_plan',
      'requested_for_date', '2026-09-02',
      'note', 'NOVY SORTIMENT: EV 99 Sportisimo, pozice 23. Twix je 0 ks; vychystat 1 cely karton Proteinoveho suku z BLUCINY do Opel Vivaro. Zasobu jinych aut nepouzivat.'
    ),
    jsonb_build_array(
      jsonb_build_object(
        'product_id', 205,
        'product_name', 'Proteinovy suk s vanilkovou prichuti 45g',
        'sku', 'SOCO-PROTEIN-VANILKA-45',
        'unit', 'ks',
        'requested_quantity', 30,
        'note', '1 x Karton 30 ks pro schvalenou zmenu sortimentu na trase #83'
      )
    )
  ) into v_created;

  if nullif(v_created #>> '{request,id}', '') is null then
    raise exception 'Skladovy doklad pro trasu #83 se nevytvoril.';
  end if;
end
$$;

commit;

select
  request.id,
  request.status,
  request.route_plan_id,
  request.vehicle_id,
  request.warehouse_id,
  item.product_name,
  item.requested_quantity,
  item.unit,
  request.note
from public.mobile_stock_requests request
join public.mobile_stock_request_items item on item.request_id = request.id
where request.route_plan_id = 83
  and request.vehicle_id = 2
  and item.product_id = 205
order by request.id desc
limit 1;
