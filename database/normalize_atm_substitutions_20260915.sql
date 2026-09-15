-- Operator confirmed that ATM bagettes may substitute for one another.
-- Change rules only; preserve stock, prices, expiry and pending changeovers.
do $$
declare
  slot_ids bigint[];
  before_data jsonb;
  after_data jsonb;
  variants text;
begin
  perform pg_advisory_xact_lock(hashtextextended('atm-substitutions-20260915',0));
  select array_agg(id order by id) into slot_ids
  from public.machine_planogram_slots
  where active and (product_family='ATM' or product_name ilike 'ATM%');
  perform 1 from public.machine_planogram_slots where id=any(slot_ids) for update;
  select jsonb_agg(to_jsonb(s)-array['product_family','substitution_policy','allowed_substitutes','updated_at'] order by id)
    into before_data from public.machine_planogram_slots s where id=any(slot_ids);
  select string_agg('SKU '||sku, ', ' order by sku) into variants
    from public.products where active and name ilike 'ATM%';
  if variants is null then raise exception 'No active ATM variants'; end if;
  update public.machine_planogram_slots
    set product_family='ATM',substitution_policy='same_family',allowed_substitutes=variants,updated_at=now()
    where id=any(slot_ids) and (product_family,substitution_policy,allowed_substitutes)
      is distinct from ('ATM','same_family',variants);
  select jsonb_agg(to_jsonb(s)-array['product_family','substitution_policy','allowed_substitutes','updated_at'] order by id)
    into after_data from public.machine_planogram_slots s where id=any(slot_ids);
  if before_data is distinct from after_data then raise exception 'Unexpected change outside substitution rules'; end if;
end $$;
select count(*) as atm_slots, count(distinct machine_id) as machines
from public.machine_planogram_slots where active and product_family='ATM' and substitution_policy='same_family';
