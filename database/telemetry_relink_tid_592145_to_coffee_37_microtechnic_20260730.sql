-- Oprava vazby TID 592145 na lokalitě Microtechnic.
-- TID patří kávovému automatu EV 37 / Luce X1 I/E, nikoli
-- potravinovému automatu EV 12 / Europa Snack SIDE.

begin;

do $$
begin
  if not exists (
    select 1
    from public.machines
    where id = 31
      and evidence_number = 37
      and qr_token = 'vendsoft-37'
      and location_id = 44
      and machine_type = 'Coffee'
  ) then
    raise exception 'Kávový automat EV 37 / Microtechnic nebyl nalezen na očekávaném DB záznamu.';
  end if;

  if not exists (
    select 1
    from public.machines
    where id = 9
      and evidence_number = 12
      and qr_token = 'vendsoft-12'
      and location_id = 44
      and machine_type = 'Snack'
  ) then
    raise exception 'Potravinový automat EV 12 / Microtechnic nebyl nalezen na očekávaném DB záznamu.';
  end if;
end
$$;

update public.machines
set
  sales_tracking_mode = 'telemetry',
  note = 'Import z VendSoft exportu; původní kód 37; lokalita Microtechnic KÁVA. TID 592145.',
  updated_at = now()
where id = 31;

update public.machines
set
  sales_tracking_mode = 'none',
  note = 'Import z VendSoft exportu; původní kód 12; lokalita Microtechnic POTRAVINY. Bez spolehlivé telemetrie; automat se obsluhuje ručně.',
  updated_at = now()
where id = 9;

insert into public.machine_external_links (
  machine_id, provider, external_machine_id, telemetry_enabled, note
)
values
  (31, 'IMA', '592145', true, 'TID 592145 patří EV 37 / Luce X1 I/E / Microtechnic KÁVA.'),
  (31, 'GP',  '592145', true, 'TID 592145 patří EV 37 / Luce X1 I/E / Microtechnic KÁVA.')
on conflict (provider, external_machine_id) do update
set
  machine_id = excluded.machine_id,
  telemetry_enabled = true,
  note = excluded.note,
  updated_at = now();

do $$
declare
  v_coffee_links integer;
  v_food_links integer;
begin
  select count(*) into v_coffee_links
  from public.machine_external_links
  where machine_id = 31
    and external_machine_id = '592145'
    and telemetry_enabled = true;

  if v_coffee_links <> 2 then
    raise exception 'EV 37: očekávány 2 aktivní vazby TID 592145, nalezeno %.', v_coffee_links;
  end if;

  select count(*) into v_food_links
  from public.machine_external_links
  where machine_id = 9
    and external_machine_id = '592145';

  if v_food_links <> 0 then
    raise exception 'EV 12 nesmí mít vazbu TID 592145; nalezeno % záznamů.', v_food_links;
  end if;
end
$$;

commit;
notify pgrst, 'reload schema';
