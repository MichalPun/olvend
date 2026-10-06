-- Allow price-safe substitutions across the new HAMÉ chilled assortment.
-- Only substitution metadata changes; stock, prices, expiry and changeovers stay intact.
begin;

do $$
declare
  v_target_ids bigint[];
  v_before jsonb;
  v_after jsonb;
  v_target_count integer;
  v_invalid_count integer;
begin
  perform pg_advisory_xact_lock(hashtextextended('hame-bagette-substitutions-20261006', 0));

  create temporary table hame_substitution_targets on commit drop as
  with hame_skus(sku, is_strips) as (
    values
      ('SIMPLY-DEBRECIN', false),
      ('SIMPLY-MLSKA', false),
      ('SIMPLY-PORIZEK', false),
      ('SIMPLY-SVACINKA', false),
      ('SIMPLY-HAMKA', false),
      ('HAME-KURECI-STRIPS', true)
  ), target_slots as (
    select
      slot.id,
      slot.machine_id,
      coalesce(slot.pending_product_sku, slot.planned_product_sku, slot.product_sku) as target_sku,
      coalesce(
        slot.pending_price_czk,
        slot.planned_price_czk,
        slot.customer_price_czk,
        slot.price_czk,
        slot.dex_price_czk
      ) as target_price
    from public.machine_planogram_slots slot
    join public.machines machine on machine.id = slot.machine_id
    where slot.active is true
      and machine.active is true
      and (
        slot.product_sku in (
          'SIMPLY-DEBRECIN','SIMPLY-MLSKA','SIMPLY-PORIZEK',
          'SIMPLY-SVACINKA','SIMPLY-HAMKA','HAME-KURECI-STRIPS',
          '155','17','282','79','16','154'
        )
        or slot.pending_product_sku in (
          'SIMPLY-DEBRECIN','SIMPLY-MLSKA','SIMPLY-PORIZEK',
          'SIMPLY-SVACINKA','SIMPLY-HAMKA','HAME-KURECI-STRIPS'
        )
        or slot.planned_product_sku in (
          'SIMPLY-DEBRECIN','SIMPLY-MLSKA','SIMPLY-PORIZEK',
          'SIMPLY-SVACINKA','SIMPLY-HAMKA','HAME-KURECI-STRIPS'
        )
      )
  ), classified as (
    select target.*, coalesce(hame.is_strips, false) as target_is_strips
    from target_slots target
    left join hame_skus hame on hame.sku = target.target_sku
  )
  select
    target.id,
    target.machine_id,
    target.target_sku,
    target.target_price,
    case
      when exists (
        select 1
        from classified sibling
        where sibling.machine_id = target.machine_id
          and sibling.id <> target.id
          and sibling.target_price is not distinct from target.target_price
          and sibling.target_is_strips is distinct from target.target_is_strips
      ) then
        'SKU SIMPLY-DEBRECIN, SKU SIMPLY-MLSKA, SKU SIMPLY-PORIZEK, '
        || 'SKU SIMPLY-SVACINKA, SKU SIMPLY-HAMKA, SKU HAME-KURECI-STRIPS'
      when target.target_is_strips then
        'SKU HAME-KURECI-STRIPS'
      else
        'SKU SIMPLY-DEBRECIN, SKU SIMPLY-MLSKA, SKU SIMPLY-PORIZEK, '
        || 'SKU SIMPLY-SVACINKA, SKU SIMPLY-HAMKA'
    end as allowed_substitutes
  from classified target;

  select array_agg(id order by id), count(*)
    into v_target_ids, v_target_count
  from hame_substitution_targets;

  if v_target_count = 0 then
    raise exception 'No active HAMÉ bagette positions found.';
  end if;

  perform 1
  from public.machine_planogram_slots
  where id = any(v_target_ids)
  for update;

  select jsonb_agg(
    to_jsonb(slot) - array[
      'product_family','substitution_policy','allowed_substitutes','updated_at'
    ]
    order by slot.id
  ) into v_before
  from public.machine_planogram_slots slot
  where slot.id = any(v_target_ids);

  update public.machine_planogram_slots slot
  set product_family = 'HAMÉ chlazený sortiment',
      substitution_policy = 'approved_list',
      allowed_substitutes = target.allowed_substitutes,
      updated_at = now()
  from hame_substitution_targets target
  where slot.id = target.id
    and (slot.product_family, slot.substitution_policy, slot.allowed_substitutes)
      is distinct from (
        'HAMÉ chlazený sortiment',
        'approved_list',
        target.allowed_substitutes
      );

  select jsonb_agg(
    to_jsonb(slot) - array[
      'product_family','substitution_policy','allowed_substitutes','updated_at'
    ]
    order by slot.id
  ) into v_after
  from public.machine_planogram_slots slot
  where slot.id = any(v_target_ids);

  if v_before is distinct from v_after then
    raise exception 'Unexpected change outside HAMÉ substitution metadata.';
  end if;

  select count(*) into v_invalid_count
  from hame_substitution_targets target
  join public.machine_planogram_slots slot on slot.id = target.id
  where slot.product_family is distinct from 'HAMÉ chlazený sortiment'
     or slot.substitution_policy is distinct from 'approved_list'
     or slot.allowed_substitutes is distinct from target.allowed_substitutes
     or position(('SKU ' || target.target_sku) in slot.allowed_substitutes) = 0;

  if v_invalid_count <> 0 then
    raise exception 'HAMÉ substitution validation failed for % positions.', v_invalid_count;
  end if;

  raise notice 'HAMÉ substitutions normalized for % active positions.', v_target_count;
end
$$;

commit;

select
  count(*) as active_hame_positions,
  count(distinct slot.machine_id) as machines,
  count(*) filter (
    where slot.allowed_substitutes like '%SKU HAME-KURECI-STRIPS%'
      and slot.allowed_substitutes like '%SKU SIMPLY-DEBRECIN%'
  ) as positions_allowing_all_six,
  count(*) filter (
    where slot.allowed_substitutes = 'SKU HAME-KURECI-STRIPS'
  ) as strips_only_positions
from public.machine_planogram_slots slot
join public.machines machine on machine.id = slot.machine_id
where slot.active is true
  and machine.active is true
  and slot.product_family = 'HAMÉ chlazený sortiment'
  and slot.substitution_policy = 'approved_list';
