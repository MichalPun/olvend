-- Obousměrné pravidlo k náhradě FRUC Ice Tea:
-- Broskev (SKU 0025) je schválená náhrada za Lesní plody (SKU 0024).
-- Mění se pouze politika a seznam náhrad; cena, počet kusů a plánogram zůstávají.

begin;

do $$
declare
  v_target_ids bigint[];
  v_target_count integer;
  v_before jsonb;
  v_after jsonb;
  v_changed integer;
begin
  perform pg_advisory_xact_lock(hashtextextended('allow-fruc-peach-for-forest-fruit-20261119', 0));

  if not exists (
    select 1 from public.products
    where id = 261 and sku = '0024'
      and name = 'FRUC Ice Tea Lesní plody 0,5 l' and active is true
  ) then
    raise exception 'Aktivní produkt FRUC Ice Tea Lesní plody SKU 0024 nebyl nalezen.';
  end if;

  if not exists (
    select 1 from public.products
    where id = 262 and sku = '0025'
      and name = 'FRUC Ice Tea Broskev 0,5 l' and active is true
  ) then
    raise exception 'Aktivní produkt FRUC Ice Tea Broskev SKU 0025 nebyl nalezen.';
  end if;

  if exists (
    select 1
    from public.products
    where sku in ('0024', '0025')
    group by sale_price
    having count(*) = 1
  ) then
    raise exception 'FRUC Broskev a Lesní plody už nemají stejnou základní prodejní cenu.';
  end if;

  select array_agg(id order by id), count(*)
    into v_target_ids, v_target_count
  from public.machine_planogram_slots
  where active is true
    and product_sku = '0024';

  if v_target_count <> 21 then
    raise exception 'Očekáváno 21 aktivních pozic FRUC Lesní plody, nalezeno %.', v_target_count;
  end if;

  perform 1
  from public.machine_planogram_slots
  where id = any(v_target_ids)
  for update;

  select jsonb_agg(
    to_jsonb(slot) - array['substitution_policy', 'allowed_substitutes', 'updated_at']
    order by slot.id
  ) into v_before
  from public.machine_planogram_slots slot
  where slot.id = any(v_target_ids);

  update public.machine_planogram_slots
  set substitution_policy = 'approved_list',
      allowed_substitutes = concat_ws(
        '; ',
        nullif(trim(trailing '; ' from coalesce(allowed_substitutes, '')), ''),
        'FRUC Ice Tea Broskev 0,5 l (SKU 0025)'
      ),
      updated_at = now()
  where id = any(v_target_ids)
    and position('SKU 0025' in coalesce(allowed_substitutes, '')) = 0;

  get diagnostics v_changed = row_count;
  if v_changed <> v_target_count then
    raise exception 'Náhrada byla přidána jen na % z % pozic.', v_changed, v_target_count;
  end if;

  select jsonb_agg(
    to_jsonb(slot) - array['substitution_policy', 'allowed_substitutes', 'updated_at']
    order by slot.id
  ) into v_after
  from public.machine_planogram_slots slot
  where slot.id = any(v_target_ids);

  if v_before is distinct from v_after then
    raise exception 'Při změně náhrad se neočekávaně změnil plánogram, cena nebo zásoba.';
  end if;

  if exists (
    select 1
    from public.machine_planogram_slots
    where id = any(v_target_ids)
      and (
        substitution_policy is distinct from 'approved_list'
        or position('SKU 0025' in coalesce(allowed_substitutes, '')) = 0
      )
  ) then
    raise exception 'Některá pozice Lesních plodů stále nepovoluje Broskev.';
  end if;

  raise notice 'Broskev SKU 0025 povolena na % pozicích Lesních plodů.', v_target_count;
end
$$;

commit;

select
  count(*) as forest_fruit_slots,
  count(distinct machine_id) as machines,
  count(*) filter (
    where substitution_policy = 'approved_list'
      and position('SKU 0025' in coalesce(allowed_substitutes, '')) > 0
  ) as slots_allowing_peach
from public.machine_planogram_slots
where active is true
  and product_sku = '0024';
