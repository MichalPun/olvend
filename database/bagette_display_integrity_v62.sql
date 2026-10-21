-- Bagetove vystaveni: jednorazova nahrada nesmi rozbit zakladni planogram.
-- U malych automatu (max. 3 fresh pozice) databaze zaroven odmitne primou
-- zmenu planogramu, ktera by vytvorila dva stejne druhy. Nouzove fyzicke
-- doplneni je nadale mozne, protoze se zapisuje do navstevy, ne do planogramu.
begin;

create table if not exists public.bagette_display_repair_audit_20261021 (
  id bigint generated always as identity primary key,
  repair_key text not null unique,
  machine_id bigint not null references public.machines(id),
  slot_id bigint not null references public.machine_planogram_slots(id),
  before_data jsonb not null,
  after_data jsonb not null,
  reason text not null,
  created_at timestamptz not null default now()
);
alter table public.bagette_display_repair_audit_20261021 enable row level security;
revoke all on table public.bagette_display_repair_audit_20261021 from public, anon, authenticated;

create or replace function public.guard_basic_fresh_planogram_uniqueness_v62()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_is_fresh boolean;
  v_fresh_count integer;
  v_unique_count integer;
begin
  if tg_op = 'UPDATE'
     and new.machine_id is not distinct from old.machine_id
     and new.product_sku is not distinct from old.product_sku
     and new.active is not distinct from old.active then
    return new;
  end if;

  if new.active is not true or new.product_sku is null then
    return new;
  end if;

  select exists (
    select 1
    from public.products product
    where product.sku = new.product_sku
      and (
        lower(coalesce(product.product_category, '')) = 'food_ready'
        or lower(coalesce(product.name, '')) similar to '%(baget|strips)%'
      )
  ) into v_is_fresh;
  if not v_is_fresh then return new; end if;

  with fresh_after as (
    select slot.product_sku
    from public.machine_planogram_slots slot
    join public.products product on product.sku = slot.product_sku
    where slot.machine_id = new.machine_id
      and slot.active is true
      and slot.id <> coalesce(new.id, -1)
      and (
        lower(coalesce(product.product_category, '')) = 'food_ready'
        or lower(coalesce(product.name, '')) similar to '%(baget|strips)%'
      )
    union all
    select new.product_sku
  )
  select count(*), count(distinct product_sku)
    into v_fresh_count, v_unique_count
  from fresh_after;

  if v_fresh_count between 2 and 3 and v_unique_count < v_fresh_count then
    raise exception 'Zakladni automat musi mit rozdilne druhy baget. Nouzovou nahradu zapis do navstevy, ne jako zmenu planogramu.';
  end if;
  return new;
end
$$;

drop trigger if exists guard_basic_fresh_planogram_uniqueness_v62 on public.machine_planogram_slots;
create trigger guard_basic_fresh_planogram_uniqueness_v62
before insert or update of machine_id, product_sku, active
on public.machine_planogram_slots
for each row execute function public.guard_basic_fresh_planogram_uniqueness_v62();

do $$
declare
  v_slot public.machine_planogram_slots%rowtype;
  v_product public.products%rowtype;
  v_after jsonb;
begin
  perform pg_advisory_xact_lock(hashtextextended('bagette-display-integrity-20261021', 0));

  -- EV 1: obe duplicitni pozice jsou prazdne, lze tedy bezpecne obnovit
  -- historicky puvodni Debrecin na pozici 23 ihned.
  select slot.* into strict v_slot
  from public.machine_planogram_slots slot
  join public.machines machine on machine.id = slot.machine_id
  where machine.evidence_number = 1 and slot.slot_code = '23'
  for update;
  select * into strict v_product from public.products where sku = 'SIMPLY-DEBRECIN';
  if v_slot.product_sku is distinct from v_product.sku then
    if coalesce(v_slot.current_units,0) <> 0 then
      raise exception 'EV 1 / pozice 23 uz neni prazdna; automatickou opravu zastavuji.';
    end if;
    update public.machine_planogram_slots
    set product_sku = v_product.sku,
      product_name = v_product.name,
      planned_product_sku = null,
      planned_product_name = null,
      planned_price_czk = null,
      pending_product_id = null,
      pending_product_sku = null,
      pending_product_name = null,
      pending_price_czk = null,
      pending_change_effective_date = null,
      pending_change_note = null,
      pending_change_mode = 'sell_through',
      changeover_old_units = null,
      changeover_new_units = null,
      changeover_started_at = null
    where id = v_slot.id;
  end if;
  select to_jsonb(slot) into v_after from public.machine_planogram_slots slot where slot.id = v_slot.id;
  insert into public.bagette_display_repair_audit_20261021(repair_key,machine_id,slot_id,before_data,after_data,reason)
  values('ev1-slot23-restore-debrecin',v_slot.machine_id,v_slot.id,to_jsonb(v_slot),v_after,'Prazdna duplicitni pozice obnovena podle historie planogramu.')
  on conflict(repair_key) do nothing;

  -- Na dalsich trech automatech je duplicitni zbozi fyzicky uvnitr.
  -- Nelzeme o stavu: pripravime povinnou vymenu pri nejblizsi navsteve.
  for v_slot in
    select slot.*
    from public.machine_planogram_slots slot
    join public.machines machine on machine.id = slot.machine_id
    where (machine.evidence_number, slot.slot_code) in ((84,'23'),(5,'24'),(72,'24'))
    order by machine.evidence_number
    for update
  loop
    select * into strict v_product from public.products where sku = case
      when (select evidence_number from public.machines where id=v_slot.machine_id) = 5 then 'SIMPLY-MLSKA'
      when (select evidence_number from public.machines where id=v_slot.machine_id) = 72 then 'SIMPLY-PORIZEK'
      else 'SIMPLY-DEBRECIN'
    end;
    update public.machine_planogram_slots
    set planned_product_sku = v_product.sku,
        planned_product_name = v_product.name,
        planned_price_czk = coalesce(customer_price_czk,price_czk),
        pending_product_id = v_product.id,
        pending_product_sku = v_product.sku,
        pending_product_name = v_product.name,
        pending_price_czk = coalesce(customer_price_czk,price_czk),
        pending_change_effective_date = current_date,
        pending_change_note = 'Obnovit tri ruzne druhy baget; duplicitni prodejne kusy vratit do vozidla.',
        pending_change_mode = 'full_swap'
    where id = v_slot.id;
    select to_jsonb(slot) into v_after from public.machine_planogram_slots slot where slot.id = v_slot.id;
    insert into public.bagette_display_repair_audit_20261021(repair_key,machine_id,slot_id,before_data,after_data,reason)
    values(
      'ev'||(select evidence_number from public.machines where id=v_slot.machine_id)||'-slot'||v_slot.slot_code||'-restore-variety',
      v_slot.machine_id,v_slot.id,to_jsonb(v_slot),v_after,
      'Fyzicky stav zachovan; pri nejblizsi navsteve je povinna rizena vymena za historicky cilovy druh.'
    ) on conflict(repair_key) do nothing;
  end loop;
end
$$;

commit;
notify pgrst, 'reload schema';

select machine.evidence_number, location.name as location, slot.slot_code,
       slot.product_name, slot.current_units, slot.pending_product_name,
       slot.pending_change_mode
from public.machine_planogram_slots slot
join public.machines machine on machine.id = slot.machine_id
join public.locations location on location.id = machine.location_id
where machine.evidence_number in (1,5,72,84)
  and slot.active is true
  and slot.product_sku like 'SIMPLY-%'
order by machine.evidence_number, slot.sort_order, slot.slot_code;
