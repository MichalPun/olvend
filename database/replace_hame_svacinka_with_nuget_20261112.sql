-- Svačinka se už neobjednává; její pravidelnou objednávku přebírá Nuget.
-- Zásoba Svačinky zůstane prodejná do doprodeje. Pozice se po doprodeji
-- bezpečně přepnou na Nuget a Nuget zůstává povolenou náhradou všech baget HAMÉ.

begin;

do $$
declare
  v_svacinka_id bigint;
  v_nuget_id bigint;
  v_recurring_order_id bigint;
  v_recurring_base numeric(12,3);
  v_recurring_by_weekday jsonb;
  v_changed_slots integer;
begin
  perform pg_advisory_xact_lock(hashtextextended('replace-hame-svacinka-with-nuget-20261112', 0));

  select id into strict v_svacinka_id
  from public.products
  where sku = 'SIMPLY-SVACINKA';

  select id into strict v_nuget_id
  from public.products
  where sku = 'SIMPLY-NUGET'
    and active is true;

  -- Přenes přesně dosavadní stálé množství a rozpis Svačinky na Nuget.
  select recurring_order_id, base_order_quantity, order_quantity_by_weekday
    into strict v_recurring_order_id, v_recurring_base, v_recurring_by_weekday
  from public.purchase_recurring_order_items
  where product_id = v_svacinka_id
    and active is true
  order by id
  limit 1
  for update;

  insert into public.purchase_recurring_order_items (
    recurring_order_id,
    product_id,
    active,
    base_order_quantity,
    order_quantity_by_weekday,
    note
  ) values (
    v_recurring_order_id,
    v_nuget_id,
    true,
    v_recurring_base,
    v_recurring_by_weekday,
    'Nahrazuje ukončenou Svačinku; převzaté stálé množství a rozpis.'
  )
  on conflict (recurring_order_id, product_id) do update set
    active = true,
    base_order_quantity = excluded.base_order_quantity,
    order_quantity_by_weekday = excluded.order_quantity_by_weekday,
    note = excluded.note,
    updated_at = now();

  update public.purchase_recurring_order_items
  set active = false,
      base_order_quantity = 0,
      order_quantity_by_weekday = '{}'::jsonb,
      note = 'Ukončeno 12. 11. 2026; objednávku převzal Simply Fresh Nuget 185g.',
      updated_at = now()
  where product_id = v_svacinka_id
    and active is true;

  update public.purchase_product_profiles
  set active = false,
      reorder_enabled = false,
      base_order_quantity = 0,
      note = 'Ukončeno 12. 11. 2026; neobjednávat. Zbývající kusy pouze doprodat.',
      updated_at = now()
  where product_id = v_svacinka_id;

  update public.purchase_product_profiles
  set active = true,
      reorder_enabled = true,
      base_order_quantity = v_recurring_base,
      note = 'Nahrazuje ukončenou Svačinku; stálá objednávka převzata beze změny množství.',
      updated_at = now()
  where product_id = v_nuget_id;

  if not found then
    raise exception 'Nákupní profil Nugetu nebyl nalezen.';
  end if;

  -- Svačinku v automatech administrativně nemažeme. Doprodej zůstává evidovaný
  -- a po vyprázdnění mobilní aplikace nabídne cílový Nuget.
  update public.machine_planogram_slots
  set pending_product_id = v_nuget_id,
      pending_product_sku = 'SIMPLY-NUGET',
      pending_product_name = 'Simply Fresh Nuget 185g',
      pending_price_czk = 50,
      pending_change_effective_date = date '2026-11-12',
      pending_change_note = 'Svačinka ukončena; po doprodeji nahradit Nugetem.',
      pending_change_mode = 'sell_through',
      updated_at = now()
  where active is true
    and product_sku = 'SIMPLY-SVACINKA';

  get diagnostics v_changed_slots = row_count;
  if v_changed_slots = 0 then
    raise exception 'Nebyla nalezena žádná aktivní pozice Svačinky k doprodeji.';
  end if;

  -- Případné dosud neprovedené budoucí změny ze Svačinky přesměruj na Nuget.
  update public.machine_planogram_slots
  set planned_product_sku = 'SIMPLY-NUGET',
      planned_product_name = 'Simply Fresh Nuget 185g',
      planned_price_czk = 50,
      updated_at = now()
  where active is true
    and planned_product_sku = 'SIMPLY-SVACINKA';

  update public.machine_planogram_slots
  set pending_product_id = v_nuget_id,
      pending_product_sku = 'SIMPLY-NUGET',
      pending_product_name = 'Simply Fresh Nuget 185g',
      pending_price_czk = 50,
      pending_change_effective_date = coalesce(pending_change_effective_date, date '2026-11-12'),
      pending_change_note = 'Svačinka ukončena; nahradit Nugetem.',
      pending_change_mode = coalesce(pending_change_mode, 'sell_through'),
      updated_at = now()
  where active is true
    and pending_product_sku = 'SIMPLY-SVACINKA';

  -- Oprav pravidla i pro případ, že některá pozice Nuget ještě neobsahuje.
  update public.machine_planogram_slots
  set allowed_substitutes = case
        when nullif(trim(allowed_substitutes), '') is null then 'SKU SIMPLY-NUGET'
        else allowed_substitutes || ', SKU SIMPLY-NUGET'
      end,
      updated_at = now()
  where active is true
    and product_family = 'HAMÉ chlazený sortiment'
    and substitution_policy = 'approved_list'
    and position('SKU SIMPLY-NUGET' in coalesce(allowed_substitutes, '')) = 0;

  if exists (
    select 1
    from public.purchase_product_profiles
    where product_id = v_svacinka_id
      and (active is true or reorder_enabled is true or base_order_quantity <> 0)
  ) then
    raise exception 'Svačinka zůstala aktivní v nákupním profilu.';
  end if;

  if not exists (
    select 1
    from public.purchase_recurring_order_items
    where recurring_order_id = v_recurring_order_id
      and product_id = v_nuget_id
      and active is true
      and base_order_quantity = v_recurring_base
      and order_quantity_by_weekday = v_recurring_by_weekday
  ) then
    raise exception 'Pravidelná objednávka nebyla správně převedena na Nuget.';
  end if;

  if exists (
    select 1
    from public.machine_planogram_slots
    where active is true
      and product_family = 'HAMÉ chlazený sortiment'
      and position('SKU SIMPLY-NUGET' in coalesce(allowed_substitutes, '')) = 0
  ) then
    raise exception 'Některá aktivní pozice HAMÉ stále nepovoluje Nuget.';
  end if;

  raise notice 'Svačinka vypnuta v objednávkách; Nuget převzal rozpis; % pozic čeká na doprodej.', v_changed_slots;
end
$$;

commit;

notify pgrst, 'reload schema';

select
  product.sku,
  profile.active as purchase_profile_active,
  profile.reorder_enabled,
  profile.base_order_quantity,
  recurring.active as recurring_active,
  recurring.base_order_quantity as recurring_quantity,
  recurring.order_quantity_by_weekday
from public.products product
left join public.purchase_product_profiles profile on profile.product_id = product.id
left join public.purchase_recurring_order_items recurring on recurring.product_id = product.id
where product.sku in ('SIMPLY-SVACINKA', 'SIMPLY-NUGET')
order by product.sku;

select
  count(*) filter (where product_sku = 'SIMPLY-SVACINKA') as svacinka_sell_through_slots,
  count(*) filter (where pending_product_sku = 'SIMPLY-NUGET') as pending_nuget_slots,
  count(*) filter (where position('SKU SIMPLY-NUGET' in coalesce(allowed_substitutes, '')) > 0) as hame_slots_allowing_nuget,
  count(*) as active_hame_slots
from public.machine_planogram_slots
where active is true
  and product_family = 'HAMÉ chlazený sortiment';
