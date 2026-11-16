-- OLVEND v56: centrálně schválená změna ceny nesmí být při další návštěvě
-- vrácena starou hodnotou planned_price_czk z plánogramu.

create or replace function public.clear_stale_planogram_price_after_central_change_v56()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
begin
  if new.status='applied' and old.status is distinct from 'applied' and new.target_type='food_slot' then
    update public.machine_planogram_slots
    set planned_price_czk=case
          when nullif(planned_product_sku,'') is not null and planned_product_sku is distinct from product_sku
            then planned_price_czk
          else null
        end,
        pending_price_czk=case
          when nullif(pending_product_sku,'') is not null and pending_product_sku is distinct from product_sku
            then pending_price_czk
          else null
        end,
        updated_at=now()
    where id=new.planogram_slot_id;
  end if;
  return new;
end
$$;

drop trigger if exists machine_price_clear_stale_plan_v56
on public.machine_price_change_items;
create trigger machine_price_clear_stale_plan_v56
after update of status on public.machine_price_change_items
for each row execute function public.clear_stale_planogram_price_after_central_change_v56();

revoke all on function public.clear_stale_planogram_price_after_central_change_v56()
from public,anon,authenticated;

-- RIGUM: dnešní aplikace chybně vrátila osm cen na staré hodnoty.
-- Fyzický automat nyní odpovídá nižším cenám; připravíme proto jediný
-- kontrolovaný úkol k návratu na ceny schválené 11. 11. 2026.
do $$
declare
  v_source_batch constant uuid := '689ef695-87a6-43eb-b9fc-874f88162ea9';
  v_batch_id uuid;
  v_message_id bigint;
  v_count integer;
begin
  perform pg_advisory_xact_lock(hashtextextended('restore-rigum-approved-prices-20261116',0));

  if exists(select 1 from public.machine_price_change_batches where batch_code='COR-RIGUM-20261116-RESTORE') then
    return;
  end if;

  if exists(select 1 from public.machine_price_change_items where machine_id=80 and status='pending') then
    raise exception 'RIGUM už má jinou čekající změnu ceny; oprava zastavena.';
  end if;

  if (select count(*) from public.machine_price_change_items where batch_id=v_source_batch and status='applied')<>8 then
    raise exception 'Původní schválená cenová sada RIGUM už neodpovídá osmi položkám.';
  end if;

  if exists(
    select 1
    from public.machine_price_change_items original
    join public.machine_planogram_slots slot on slot.id=original.planogram_slot_id
    where original.batch_id=v_source_batch
      and coalesce(slot.customer_price_czk,slot.price_czk)<>original.old_price_czk
  ) then raise exception 'Některá fyzická cena RIGUM už není na chybně vrácené hodnotě.'; end if;

  insert into public.location_operator_messages(
    location_id,machine_id,title,message,display_mode,requires_acknowledgement,is_active
  )
  select machine.location_id,machine.id,
         'Oprava cen po chybě aplikace',
         'Aplikace 16. 11. chybně vrátila 8 cen na staré hodnoty. Při příští návštěvě nastavte zpět pouze níže uvedené schválené ceny; další změny nedělejte.',
         'every_visit',false,true
  from public.machines machine where machine.id=80
  returning id into v_message_id;

  insert into public.machine_price_change_batches(
    batch_code,machine_id,status,note,approved_at,location_operator_message_id
  ) values(
    'COR-RIGUM-20261116-RESTORE',80,'approved',
    'Návrat na osm cen schválených 11. 11. 2026; 16. 11. je aplikace chybně vrátila přes zastaralý planned_price_czk.',
    now(),v_message_id
  ) returning id into v_batch_id;

  insert into public.machine_price_change_items(
    batch_id,machine_id,target_type,planogram_slot_id,coffee_button_id,slot_code,
    product_id,product_sku,product_name,category_key,purchase_price_czk,vat_rate,
    old_price_czk,recommended_price_czk,new_price_czk,minimum_margin_percent,
    benchmark_snapshot,status,label_printed_at
  )
  select v_batch_id,original.machine_id,original.target_type,original.planogram_slot_id,
         original.coffee_button_id,original.slot_code,product.id,slot.product_sku,
         slot.product_name,original.category_key,product.purchase_price,product.vat_rate,
         original.old_price_czk,original.new_price_czk,original.new_price_czk,
         original.minimum_margin_percent,
         jsonb_build_object('correction_of_batch',v_source_batch,'reason','stale planned_price_czk forced reversal on 2026-11-16'),
         'pending',now()
  from public.machine_price_change_items original
  join public.machine_planogram_slots slot on slot.id=original.planogram_slot_id
  left join public.products product on product.sku=slot.product_sku
  where original.batch_id=v_source_batch;
  get diagnostics v_count=row_count;
  if v_count<>8 then raise exception 'Připraveno pouze % z 8 opravných cen.',v_count; end if;

  update public.machine_price_change_batches set status='approved',updated_at=now() where id=v_batch_id;
end
$$;

notify pgrst,'reload schema';
