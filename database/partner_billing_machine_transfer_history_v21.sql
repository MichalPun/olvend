begin;

do $$
begin
  if not exists (select 1 from public.locations where id = 58 and active = true) then
    raise exception 'Aktivni lokalita Sportisimo (ID 58) nebyla nalezena.';
  end if;
  if not exists (select 1 from public.machines where id = 22 and evidence_number = 27) then
    raise exception 'Puvodni automat Sportisimo EV 27 nebyl nalezen.';
  end if;
  if not exists (select 1 from public.machines where id = 65 and evidence_number = 85) then
    raise exception 'Novy automat Sportisimo EV 85 nebyl nalezen.';
  end if;
end $$;

insert into public.machine_transfers (
  machine_id,
  from_location_id,
  to_location_id,
  transfer_kind,
  from_status,
  to_status,
  from_active,
  to_active,
  transferred_at,
  transferred_by,
  note
)
select
  22,
  58,
  null,
  'storage',
  'installed',
  'warehouse',
  true,
  true,
  '2026-08-14 15:45:00+00'::timestamptz,
  'Codex / potvrzeno Michal Puncochar',
  'Historicky doplnena vymena Sportisimo EV 27 za EV 85 dne 14. 8. 2026.'
where not exists (
  select 1
  from public.machine_transfers
  where machine_id = 22
    and from_location_id = 58
    and to_location_id is null
    and transferred_at = '2026-08-14 15:45:00+00'::timestamptz
);

insert into public.machine_transfers (
  machine_id,
  from_location_id,
  to_location_id,
  transfer_kind,
  from_status,
  to_status,
  from_active,
  to_active,
  transferred_at,
  transferred_by,
  note
)
select
  65,
  null,
  58,
  'relocation',
  'warehouse',
  'installed',
  true,
  true,
  '2026-08-14 15:45:00+00'::timestamptz,
  'Codex / potvrzeno Michal Puncochar',
  'Historicky doplnena vymena Sportisimo EV 27 za EV 85 dne 14. 8. 2026.'
where not exists (
  select 1
  from public.machine_transfers
  where machine_id = 65
    and from_location_id is null
    and to_location_id = 58
    and transferred_at = '2026-08-14 15:45:00+00'::timestamptz
);

do $$
begin
  if (
    select count(*)
    from public.machine_transfers
    where transferred_at = '2026-08-14 15:45:00+00'::timestamptz
      and (
        (machine_id = 22 and from_location_id = 58 and to_location_id is null)
        or (machine_id = 65 and from_location_id is null and to_location_id = 58)
      )
  ) <> 2 then
    raise exception 'Historie vymeny Sportisimo EV 27 za EV 85 neni kompletni.';
  end if;
end $$;

commit;
