-- Dva nove potravinove automaty Bianchi Vitality L na lokalite Vitar.
-- Planogram, ceny, kapacity a razeni jsou prevzaty z ARIA L EVO EV100 / RIGUM.
-- EV127 <- TID 592150 z odstaveneho LEI 600 EV80.
-- EV128 <- TID 587377 z Bianchi Aria EV78 na Vitaru.
-- Historicke prodeje a citace zustavaji na puvodnich strojich; nove stroje zacinaji baseline.

begin;

do $$
declare
  v_source_machine_id bigint;
  v_ev80_id bigint;
  v_ev78_id bigint;
  v_ev127_id bigint;
  v_ev128_id bigint;
  v_ev78_stock_location_id bigint;
  v_target_machine_id bigint;
  v_target_ev bigint;
  v_count integer;
begin
  select id into strict v_source_machine_id
  from public.machines
  where evidence_number=100 and name='ARIA L EVO' and model='ARIA L EVO'
    and machine_type='Snack' and location_id=23 and status='ok' and active=true;

  select id into strict v_ev80_id
  from public.machines
  where evidence_number=80 and name='LEI 600 Touch' and location_id is null and status='removed';

  select id into strict v_ev78_id
  from public.machines
  where evidence_number=78 and name='Bianchi Aria' and location_id=60 and status='ok' and active=true;

  if not exists (select 1 from public.locations where id=60 and name='Vitar' and active=true) then
    raise exception 'Aktivni lokalita Vitar ID60 nebyla nalezena.';
  end if;

  if (select count(*) from public.machine_planogram_slots where machine_id=v_source_machine_id and active)<>44 then
    raise exception 'Zdrojova ARIA EV100 nema presne 44 aktivnich pozic.';
  end if;

  if exists (select 1 from public.machines where evidence_number in (127,128))
     or exists (select 1 from public.machines where qr_token in ('bianchi-vitality-l-ev127','bianchi-vitality-l-ev128')) then
    raise exception 'EV127/EV128 nebo jejich QR tokeny uz existuji.';
  end if;

  if (select count(*) from public.machine_external_links
      where machine_id=v_ev80_id and external_machine_id='592150'
        and provider in ('IMA','GP') and telemetry_enabled=false)<>2 then
    raise exception 'EV80 nema obe deaktivovane vazby IMA/GP pro TID 592150.';
  end if;

  if (select count(*) from public.machine_external_links
      where machine_id=v_ev78_id and external_machine_id='587377'
        and provider in ('IMA','GP') and telemetry_enabled=true)<>2 then
    raise exception 'EV78 nema obe aktivni vazby IMA/GP pro TID 587377.';
  end if;

  insert into public.machines(
    location_id,name,machine_type,brand,model,serial_number,evidence_number,status,active,
    note,qr_token,sales_tracking_mode,stock_initialized_at
  ) values (
    60,'Bianchi Vitality L','Snack','Bianchi','Vitality L',null,127,'ok',true,
    'Bianchi Vitality L na lokalitě Vitar · planogram a ceny převzaty z ARIA L EVO EV100 / RIGUM · TID 592150.',
    'bianchi-vitality-l-ev127','telemetry',null
  ) returning id into v_ev127_id;

  insert into public.machines(
    location_id,name,machine_type,brand,model,serial_number,evidence_number,status,active,
    note,qr_token,sales_tracking_mode,stock_initialized_at
  ) values (
    60,'Bianchi Vitality L','Snack','Bianchi','Vitality L',null,128,'ok',true,
    'Bianchi Vitality L na lokalitě Vitar · planogram a ceny převzaty z ARIA L EVO EV100 / RIGUM · TID 587377.',
    'bianchi-vitality-l-ev128','telemetry',null
  ) returning id into v_ev128_id;

  foreach v_target_machine_id in array array[v_ev127_id,v_ev128_id]
  loop
    select evidence_number into strict v_target_ev from public.machines where id=v_target_machine_id;

    insert into public.machine_transfers(
      machine_id,from_location_id,to_location_id,transfer_kind,from_status,to_status,
      from_active,to_active,transferred_at,transferred_by,note
    ) values (
      v_target_machine_id,null,60,'relocation','installing','ok',true,true,now(),
      'Codex / potvrzeno Michal Punčochář',
      format('První umístění Bianchi Vitality L EV%s na lokalitu Vitar dne 4. 9. 2026.',v_target_ev)
    );

    insert into public.machine_service_rules(
      machine_id,service_frequency,fill_frequency,stock_critical_percent,max_visit_interval_days,
      route_visit_rules_active,route_planning_paused_until,route_planning_excluded_months,
      route_planning_note,last_service_at,last_fill_at,note
    )
    select v_target_machine_id,service_frequency,fill_frequency,stock_critical_percent,max_visit_interval_days,
           route_visit_rules_active,null,route_planning_excluded_months,route_planning_note,null,null,
           format('Výchozí servisní pravidla převzata z ARIA L EVO EV100 / RIGUM pro Vitality L EV%s.',v_target_ev)
    from public.machine_service_rules where machine_id=v_source_machine_id;

    insert into public.stock_locations(location_type,name,machine_id,active,note)
    values('machine','Automat EV '||v_target_ev,v_target_machine_id,true,
           format('Skladové místo Bianchi Vitality L EV%s na Vitaru; výchozí stav 0 ks.',v_target_ev));

    insert into public.machine_planogram_slots(
      machine_id,slot_code,product_name,product_sku,price_czk,capacity_units,current_units,
      fill_percent,active,sort_order,note,dex_price_czk,desired_units,expiry_date,telemetry_key,
      last_units,product_family,product_variant,planned_product_name,planned_product_sku,
      planned_price_czk,substitution_policy,allowed_substitutes,operator_instruction,
      customer_price_czk,subsidy_amount_czk,subsidy_payer,subsidy_billing_enabled,subsidy_note,
      settlement_type,settlement_amount_czk,settlement_partner,settlement_billing_enabled,
      settlement_note,target_units,replenishment_mode,pending_product_id,pending_product_sku,
      pending_product_name,pending_price_czk,pending_change_effective_date,pending_change_note,
      changeover_old_units,changeover_new_units,changeover_started_at,pending_change_mode
    )
    select v_target_machine_id,source.slot_code,source.product_name,source.product_sku,
           source.price_czk,source.capacity_units,0,0,source.active,source.sort_order,
           format('Bianchi Vitality L EV%s · rozložení, produkt, kapacita a cena převzaty z ARIA L EVO EV100 / RIGUM; výchozí stav 0 ks.',v_target_ev),
           source.dex_price_czk,coalesce(source.target_units,source.capacity_units,0),null,
           source.telemetry_key,0,source.product_family,source.product_variant,
           source.product_name,source.product_sku,source.price_czk,
           source.substitution_policy,source.allowed_substitutes,null,
           source.customer_price_czk,source.subsidy_amount_czk,source.subsidy_payer,
           source.subsidy_billing_enabled,source.subsidy_note,source.settlement_type,
           source.settlement_amount_czk,source.settlement_partner,source.settlement_billing_enabled,
           source.settlement_note,source.target_units,source.replenishment_mode,
           null,null,null,null,null,null,null,null,null,source.pending_change_mode
    from public.machine_planogram_slots source
    where source.machine_id=v_source_machine_id and source.active=true
    order by source.sort_order,source.slot_code;

    if (select count(*) from public.machine_planogram_slots where machine_id=v_target_machine_id and active)<>44 then
      raise exception 'Vitality L EV% nema presne 44 aktivnich pozic.',v_target_ev;
    end if;

    if exists (
      select 1 from (
        select slot_code,product_sku,product_name,price_czk,dex_price_czk,capacity_units,
               target_units,telemetry_key,sort_order,product_family,product_variant,
               substitution_policy,allowed_substitutes,customer_price_czk,
               subsidy_amount_czk,subsidy_payer,subsidy_billing_enabled,
               settlement_type,settlement_amount_czk,settlement_partner,settlement_billing_enabled
        from public.machine_planogram_slots where machine_id=v_source_machine_id and active
        except all
        select slot_code,product_sku,product_name,price_czk,dex_price_czk,capacity_units,
               target_units,telemetry_key,sort_order,product_family,product_variant,
               substitution_policy,allowed_substitutes,customer_price_czk,
               subsidy_amount_czk,subsidy_payer,subsidy_billing_enabled,
               settlement_type,settlement_amount_czk,settlement_partner,settlement_billing_enabled
        from public.machine_planogram_slots where machine_id=v_target_machine_id and active
      ) difference
    ) then
      raise exception 'Vitality L EV% nema stejne rozlozeni, ceny nebo konfiguraci jako EV100.',v_target_ev;
    end if;

    if exists (
      select 1 from public.machine_planogram_slots
      where machine_id=v_target_machine_id and active
        and (current_units<>0 or fill_percent<>0 or desired_units<>coalesce(target_units,capacity_units,0)
             or expiry_date is not null or last_units<>0)
    ) then
      raise exception 'Vitality L EV% nema cisty vychozi skladovy stav.',v_target_ev;
    end if;
  end loop;

  if exists (select 1 from public.machine_external_links where machine_id in (v_ev127_id,v_ev128_id))
     or exists (select 1 from public.machine_telemetry_state where machine_id in (v_ev127_id,v_ev128_id))
     or exists (select 1 from public.telemetry_planogram_counters where machine_id in (v_ev127_id,v_ev128_id))
     or exists (select 1 from public.telemetry_sales_events where machine_id in (v_ev127_id,v_ev128_id)) then
    raise exception 'Nektery novy Vitality L uz obsahuje telemetricka data pred prirazenim TID.';
  end if;

  update public.machine_external_links
  set machine_id=v_ev127_id,telemetry_enabled=true,
      note='TID 592150 · terminál převeden z odstaveného LEI 600 Touch EV80 na Bianchi Vitality L EV127 na Vitaru dne 4. 9. 2026. První nový DEX vytvoří výchozí čítače.',
      updated_at=now()
  where machine_id=v_ev80_id and external_machine_id='592150'
    and provider in ('IMA','GP') and telemetry_enabled=false;
  get diagnostics v_count=row_count;
  if v_count<>2 then raise exception 'Presun TID 592150 na EV127 upravil % misto 2 vazeb.',v_count; end if;

  update public.machine_external_links
  set machine_id=v_ev128_id,telemetry_enabled=true,
      note='TID 587377 · terminál převeden z Bianchi Aria EV78 na Bianchi Vitality L EV128 na Vitaru dne 4. 9. 2026. První nový DEX vytvoří výchozí čítače.',
      updated_at=now()
  where machine_id=v_ev78_id and external_machine_id='587377'
    and provider in ('IMA','GP') and telemetry_enabled=true;
  get diagnostics v_count=row_count;
  if v_count<>2 then raise exception 'Presun TID 587377 na EV128 upravil % misto 2 vazeb.',v_count; end if;

  update public.machines
  set note=concat_ws(' ',nullif(note,''),'· TID 592150 převeden na Bianchi Vitality L EV127 dne 4. 9. 2026.'),
      updated_at=now()
  where id=v_ev80_id;

  update public.machines
  set note=concat_ws(' ',nullif(note,''),'· TID 587377 převeden na Bianchi Vitality L EV128 dne 4. 9. 2026.'),
      updated_at=now()
  where id=v_ev78_id;

  select id into v_ev78_stock_location_id
  from public.stock_locations
  where location_type='machine' and machine_id=v_ev78_id
  order by active desc,id
  limit 1;

  insert into public.machine_transfers(
    machine_id,from_location_id,to_location_id,transfer_kind,from_status,to_status,
    from_active,to_active,transferred_at,transferred_by,note,
    from_stock_location_id,to_stock_location_id
  ) values (
    v_ev78_id,60,null,'storage','ok','removed',true,true,now(),
    'Codex / potvrzeno Michal Punčochář',
    'Bianchi Aria EV78 stažena z Vitaru do dílny/skladu Blučina dne 4. 9. 2026; TID 587377 převeden na Bianchi Vitality L EV128. Evidovaný obsah zůstává u stroje. EV78_VITAR_DILNA_20260904',
    v_ev78_stock_location_id,null
  );

  update public.machines
  set location_id=null,status='removed',active=true,sales_tracking_mode='none',
      note=concat_ws(' ',nullif(note,''),'· 4. 9. 2026: staženo z lokality Vitar do dílny/skladu Blučina; TID 587377 převeden na EV128, evidovaný obsah ponechán u stroje. · EV78_VITAR_DILNA_20260904'),
      updated_at=now()
  where id=v_ev78_id;

  if (select count(*) from public.machine_external_links
      where machine_id=v_ev127_id and external_machine_id='592150'
        and provider in ('IMA','GP') and telemetry_enabled=true)<>2
     or (select count(*) from public.machine_external_links
         where machine_id=v_ev128_id and external_machine_id='587377'
           and provider in ('IMA','GP') and telemetry_enabled=true)<>2 then
    raise exception 'Zaverecna kontrola terminalovych vazeb EV127/EV128 selhala.';
  end if;

  if not exists (
    select 1 from public.machines
    where id=v_ev78_id and location_id is null and status='removed'
      and active=true and sales_tracking_mode='none'
  ) or exists (select 1 from public.machine_external_links where machine_id=v_ev78_id) then
    raise exception 'Zaverecna kontrola presunu EV78 do dilny selhala.';
  end if;
end $$;

commit;

select m.id,m.evidence_number,m.name,m.brand,m.model,m.location_id,m.status,m.sales_tracking_mode,
       count(distinct s.id) filter(where s.active) active_slots,
       min(s.current_units) filter(where s.active) min_units,
       max(s.current_units) filter(where s.active) max_units,
       array_agg(distinct l.external_machine_id) filter(where l.telemetry_enabled) terminal_ids
from public.machines m
left join public.machine_planogram_slots s on s.machine_id=m.id
left join public.machine_external_links l on l.machine_id=m.id
where m.evidence_number in (127,128)
group by m.id,m.evidence_number,m.name,m.brand,m.model,m.location_id,m.status,m.sales_tracking_mode
order by m.evidence_number;
