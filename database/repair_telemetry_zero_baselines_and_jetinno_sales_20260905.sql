-- Oprava spolecne priciny zmizelych prvnich prodeju po zalozeni nebo presunu TID:
-- 1. doplni chybejici nulove PA2 baseline napric aktivni IMA telemetrii,
-- 2. obnovi tri uzivatelem a DEXem potvrzene kartove prodeje EV125,
-- 3. opravi kartovou klasifikaci posledniho prodeje EV128, kterou znecistil
--    preneseny cekajici kredit stareho terminalu,
-- 4. zrusi pouze prechodove cekajici kredity novych EV125-EV128.
-- Historicke prodeje puvodnich stroju se nemeni.

begin;

do $$
declare
  v_ev125_id bigint;
  v_ev126_id bigint;
  v_ev127_id bigint;
  v_ev128_id bigint;
  v_sale_id bigint;
  v_seeded integer;
begin
  select id into strict v_ev125_id from public.machines where evidence_number=125 and active=true;
  select id into strict v_ev126_id from public.machines where evidence_number=126 and active=true;
  select id into strict v_ev127_id from public.machines where evidence_number=127 and active=true;
  select id into strict v_ev128_id from public.machines where evidence_number=128 and active=true;

  if (select count(*) from public.machine_planogram_slots where machine_id=v_ev125_id and active)<>18
     or (select count(*) from public.machine_planogram_slots where machine_id=v_ev126_id and active)<>18
     or (select count(*) from public.machine_planogram_slots where machine_id=v_ev127_id and active)<>44
     or (select count(*) from public.machine_planogram_slots where machine_id=v_ev128_id and active)<>44 then
    raise exception 'Bezpecnostni kontrola planogramu EV125-EV128 selhala.';
  end if;

  -- Posledni DEX kazdeho aktivniho IMA stroje je autoritativni baseline pouze
  -- tam, kde je citac nula. Kladny chybejici citac se automaticky nezaklada,
  -- protoze by mohl predstavovat dosud nezauctovany prvni prodej.
  with active_links as (
    select link.machine_id,link.external_machine_id
    from public.machine_external_links link
    join public.machines machine on machine.id=link.machine_id
      and machine.active=true and machine.sales_tracking_mode='telemetry'
    where link.provider='IMA' and link.telemetry_enabled=true
  ), latest as (
    select link.machine_id,ingest.id ingest_id,
           coalesce(ingest.dex_read_datetime,ingest.transaction_time,ingest.created_at) event_at,
           ingest.raw_dex
    from active_links link
    cross join lateral (
      select row.id,row.dex_read_datetime,row.transaction_time,row.created_at,row.raw_dex
      from public.telemetry_dex_ingests row
      where row.provider='IMA' and row.device_id=link.external_machine_id
      order by row.created_at desc,row.id desc
      limit 1
    ) ingest
  ), parsed as (
    select latest.machine_id,latest.ingest_id,latest.event_at,
           regexp_replace((match)[1],'^0+([0-9])','\1') selection_code,
           (match)[2]::numeric total_count
    from latest
    cross join lateral regexp_matches(
      latest.raw_dex,
      E'PA1\\*([0-9]+)\\*[^\\r\\n]*\\r?\\nPA2\\*([0-9]+)\\*',
      'g'
    ) match
  )
  insert into public.telemetry_planogram_counters(
    provider,machine_id,planogram_slot_id,selection_code,last_total_count,
    last_cash_count,last_cashless_count,last_event_at,last_ingest_id
  )
  select 'IMA',slot.machine_id,slot.id,
         regexp_replace(slot.slot_code,'^0+([0-9])','\1'),0,0,0,
         parsed.event_at,parsed.ingest_id
  from public.machine_planogram_slots slot
  join parsed on parsed.machine_id=slot.machine_id
    and parsed.selection_code=regexp_replace(slot.slot_code,'^0+([0-9])','\1')
    and parsed.total_count=0
  where slot.active=true
  on conflict (provider,machine_id,planogram_slot_id,selection_code) do nothing;
  get diagnostics v_seeded=row_count;

  -- Matcha DeLuxe: DEX 350599 obsahuje prvni PA2 0 -> 1 a soucasne
  -- kartovy narust 1 / 10 Kc. Prodej byl pred fyzickym srovnanim zasobniku.
  insert into public.telemetry_sales_events(
    provider,ingest_id,machine_id,planogram_slot_id,selection_code,
    product_name,product_sku,quantity,cash_quantity,cashless_quantity,
    free_vend_quantity,unknown_payment_quantity,unpaid_dispense_quantity,
    unit_price_czk,total_amount_czk,cash_amount_czk,cashless_amount_czk,
    unknown_payment_amount_czk,source_event_at,source_event_key,event_part
  )
  select 'IMA',ingest.id,v_ev125_id,slot.id,'13',slot.product_name,slot.product_sku,
         1,0,1,0,0,0,10,10,0,10,0,
         coalesce(ingest.dex_read_datetime,ingest.transaction_time,ingest.created_at),
         'ev125-recovered-first-positive-350599-selection13',1
  from public.telemetry_dex_ingests ingest
  join public.machine_planogram_slots slot on slot.machine_id=v_ev125_id
    and slot.active and slot.slot_code='13'
  where ingest.id=350599 and ingest.device_id='602227'
  on conflict (provider,source_event_key)
  do update set cash_quantity=0,cashless_quantity=1,unknown_payment_quantity=0,
                unpaid_dispense_quantity=0,unit_price_czk=10,total_amount_czk=10,
                cash_amount_czk=0,cashless_amount_czk=10,unknown_payment_amount_czk=0;

  -- Prvni test Bile kavy byl fyzicky nastaven jako volba 47, kterou tento DEX
  -- export vubec neobsahoval. Uzivatel prodej potvrdil a DA2 vzrostlo o 10 Kc.
  -- Prodej byl pred fyzickym srovnanim zasobniku.
  insert into public.telemetry_sales_events(
    provider,ingest_id,machine_id,planogram_slot_id,selection_code,
    product_name,product_sku,quantity,cash_quantity,cashless_quantity,
    free_vend_quantity,unknown_payment_quantity,unpaid_dispense_quantity,
    unit_price_czk,total_amount_czk,cash_amount_czk,cashless_amount_czk,
    unknown_payment_amount_czk,source_event_at,source_event_key,event_part
  )
  select 'IMA',ingest.id,v_ev125_id,slot.id,'4',slot.product_name,slot.product_sku,
         1,0,1,0,0,0,10,10,0,10,0,
         coalesce(ingest.dex_read_datetime,ingest.transaction_time,ingest.created_at),
         'ev125-confirmed-white-coffee-id47-352754',1
  from public.telemetry_dex_ingests ingest
  join public.machine_planogram_slots slot on slot.machine_id=v_ev125_id
    and slot.active and slot.slot_code='4'
  where ingest.id=352754 and ingest.device_id='602227'
  on conflict (provider,source_event_key)
  do update set cash_quantity=0,cashless_quantity=1,unknown_payment_quantity=0,
                unpaid_dispense_quantity=0,unit_price_czk=10,total_amount_czk=10,
                cash_amount_czk=0,cashless_amount_czk=10,unknown_payment_amount_czk=0;

  -- Po premapovani Bile kavy na ID 4 DEX 353374 jednoznacne potvrzuje
  -- PA2 0 -> 1 a kartovy narust 1 / 10 Kc. Tento prodej je az po fyzickem
  -- srovnani zasobniku, proto se jednou odecte receptura i kelimek.
  insert into public.telemetry_sales_events(
    provider,ingest_id,machine_id,planogram_slot_id,selection_code,
    product_name,product_sku,quantity,cash_quantity,cashless_quantity,
    free_vend_quantity,unknown_payment_quantity,unpaid_dispense_quantity,
    unit_price_czk,total_amount_czk,cash_amount_czk,cashless_amount_czk,
    unknown_payment_amount_czk,source_event_at,source_event_key,event_part
  )
  select 'IMA',ingest.id,v_ev125_id,slot.id,'4',slot.product_name,slot.product_sku,
         1,0,1,0,0,0,10,10,0,10,0,
         coalesce(ingest.dex_read_datetime,ingest.transaction_time,ingest.created_at),
         'ev125-recovered-first-positive-353374-selection4',1
  from public.telemetry_dex_ingests ingest
  join public.machine_planogram_slots slot on slot.machine_id=v_ev125_id
    and slot.active and slot.slot_code='4'
  where ingest.id=353374 and ingest.device_id='602227'
  on conflict (provider,source_event_key)
  do update set cash_quantity=0,cashless_quantity=1,unknown_payment_quantity=0,
                unpaid_dispense_quantity=0,unit_price_czk=10,total_amount_czk=10,
                cash_amount_czk=0,cashless_amount_czk=10,unknown_payment_amount_czk=0
  returning id into v_sale_id;

  if v_sale_id is null then
    select id into strict v_sale_id from public.telemetry_sales_events
    where provider='IMA' and source_event_key='ev125-recovered-first-positive-353374-selection4'
      and event_part=1;
  end if;
  perform public.apply_telemetry_coffee_depletion(array[v_sale_id]);
  perform public.apply_telemetry_stock_depletion(array[v_sale_id]);

  -- EV128 ingest 353576: DA2 +2 / 48 Kc a PA2 volba 54 +2. Stary cekajici
  -- hotovostni citac z presunuteho terminalu jej chybne oznacil jako hotovost.
  update public.telemetry_sales_events
  set cash_quantity=0,cashless_quantity=2,unknown_payment_quantity=0,
      unpaid_dispense_quantity=0,cash_amount_czk=0,cashless_amount_czk=48,
      unknown_payment_amount_czk=0,total_amount_czk=48
  where machine_id=v_ev128_id and provider='IMA' and ingest_id=353576
    and selection_code='54' and quantity=2 and unit_price_czk=24;
  if not found then
    raise exception 'Ocekavany prodej EV128 ingest 353576 volba 54 nebyl nalezen.';
  end if;

  -- Po explicitnim dorovnani jsou prechodove kredity techto ctyr novych
  -- stroju spotrebovane nebo prokazatelne jen zbytky ze stareho TID.
  update public.machine_telemetry_state
  set counters_payload=jsonb_set(coalesce(counters_payload,'{}'::jsonb),
                                 '{pending_payment_credit}','null'::jsonb,true),
      updated_at=now()
  where provider='IMA' and machine_id in(v_ev125_id,v_ev126_id,v_ev127_id,v_ev128_id);

  if exists (
    with active_links as (
      select link.machine_id,link.external_machine_id
      from public.machine_external_links link
      join public.machines machine on machine.id=link.machine_id
        and machine.active=true and machine.sales_tracking_mode='telemetry'
      where link.provider='IMA' and link.telemetry_enabled=true
    ), latest as (
      select link.machine_id,ingest.raw_dex
      from active_links link
      cross join lateral (
        select row.raw_dex from public.telemetry_dex_ingests row
        where row.provider='IMA' and row.device_id=link.external_machine_id
        order by row.created_at desc,row.id desc limit 1
      ) ingest
    ), parsed_zero as (
      select latest.machine_id,regexp_replace((match)[1],'^0+([0-9])','\1') selection_code
      from latest cross join lateral regexp_matches(
        latest.raw_dex,E'PA1\\*([0-9]+)\\*[^\\r\\n]*\\r?\\nPA2\\*(0)\\*','g'
      ) match
    )
    select 1
    from public.machine_planogram_slots slot
    join parsed_zero parsed on parsed.machine_id=slot.machine_id
      and parsed.selection_code=regexp_replace(slot.slot_code,'^0+([0-9])','\1')
    left join public.telemetry_planogram_counters counter
      on counter.provider='IMA' and counter.machine_id=slot.machine_id
     and counter.planogram_slot_id=slot.id
     and counter.selection_code=regexp_replace(slot.slot_code,'^0+([0-9])','\1')
    where slot.active=true and counter.id is null
  ) then
    raise exception 'Po oprave stale existuje chybejici nulovy IMA baseline.';
  end if;

  if (select count(*) from public.telemetry_sales_events
      where provider='IMA' and source_event_key in(
        'ev125-recovered-first-positive-350599-selection13',
        'ev125-confirmed-white-coffee-id47-352754',
        'ev125-recovered-first-positive-353374-selection4'
      ))<>3 then
    raise exception 'Kontrola obnovenych prodeju EV125 selhala.';
  end if;

  raise notice 'Doplneno % nulovych IMA baseline; tri potvrzene prodeje EV125 obnoveny.',v_seeded;
end $$;

commit;

notify pgrst,'reload schema';
