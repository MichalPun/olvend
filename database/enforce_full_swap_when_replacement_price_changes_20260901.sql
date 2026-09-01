begin;

create or replace function public.enforce_food_replacement_price_mode()
returns trigger
language plpgsql
as $$
declare
  v_current_price numeric;
begin
  v_current_price := coalesce(new.customer_price_czk, new.price_czk, new.dex_price_czk);

  if new.pending_product_sku is not null
     and new.pending_product_sku is distinct from new.product_sku
     and new.pending_price_czk is not null
     and v_current_price is not null
     and new.pending_price_czk is distinct from v_current_price then
    new.pending_change_mode := 'full_swap';
    new.pending_change_note := concat_ws(
      ' · ',
      nullif(new.pending_change_note, ''),
      'Povinna kompletni vymena: novy produkt ma jinou prodejni cenu. Puvodni prodejne kusy vrat do stejneho vozidla a pouzij na dalsim vhodnem automatu vlastni trasy.'
    );
    new.operator_instruction := 'Vyndej vsechny prodejne kusy puvodniho produktu do sveho vozidla. Vloz pouze novy produkt, zmen cenu primo na automatu a potvrď ji v aplikaci.';
  end if;

  return new;
end
$$;

drop trigger if exists trg_enforce_food_replacement_price_mode
  on public.machine_planogram_slots;

create trigger trg_enforce_food_replacement_price_mode
before insert or update of
  pending_product_sku,
  pending_price_czk,
  product_sku,
  price_czk,
  customer_price_czk,
  dex_price_czk
on public.machine_planogram_slots
for each row
execute function public.enforce_food_replacement_price_mode();

update public.machine_planogram_slots slot
set pending_change_mode = 'full_swap',
    pending_change_note = concat_ws(
      ' · ',
      nullif(slot.pending_change_note, ''),
      'Povinna kompletni vymena kvuli rozdilne prodejni cene. Puvodni prodejne kusy vrat do stejneho vozidla pro dalsi vhodny automat vlastni trasy.'
    ),
    operator_instruction = 'Vyndej vsechny prodejne kusy puvodniho produktu do sveho vozidla. Vloz pouze novy produkt, zmen cenu primo na automatu a potvrď ji v aplikaci.',
    changeover_old_units = slot.current_units,
    changeover_new_units = 0,
    updated_at = now()
where slot.active is true
  and slot.pending_product_sku is not null
  and slot.pending_product_sku is distinct from slot.product_sku
  and slot.pending_price_czk is not null
  and coalesce(slot.customer_price_czk, slot.price_czk, slot.dex_price_czk) is not null
  and slot.pending_price_czk is distinct from coalesce(slot.customer_price_czk, slot.price_czk, slot.dex_price_czk);

commit;

select
  machine.evidence_number,
  slot.slot_code,
  slot.product_name,
  slot.current_units,
  coalesce(slot.customer_price_czk, slot.price_czk, slot.dex_price_czk) as current_price_czk,
  slot.pending_product_name,
  slot.pending_price_czk,
  slot.pending_change_mode
from public.machine_planogram_slots slot
join public.machines machine on machine.id = slot.machine_id
where slot.active is true
  and slot.pending_product_sku is not null
order by machine.evidence_number, slot.slot_code;
