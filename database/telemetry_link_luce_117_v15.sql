insert into public.machine_external_links (
  machine_id,
  provider,
  external_machine_id,
  telemetry_enabled,
  note
) values
  (95, 'IMA', '592144', true, 'TID 592144 pro Luce X2 I / automat 117.'),
  (95, 'GP', '592144', true, 'TID 592144 pro Luce X2 I / automat 117.')
on conflict (provider, external_machine_id) do update
set
  machine_id = excluded.machine_id,
  telemetry_enabled = true,
  note = excluded.note,
  updated_at = now();
