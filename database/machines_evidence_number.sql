create sequence if not exists public.machine_evidence_number_seq;

alter table public.machines
  add column if not exists evidence_number bigint;

update public.machines
set evidence_number = substring(qr_token from 'vendsoft-(\d+)')::bigint
where evidence_number is null
  and qr_token ~* '^vendsoft-[0-9]+$';

select setval(
  'public.machine_evidence_number_seq',
  greatest(
    coalesce((select max(evidence_number) from public.machines), 0),
    1
  ),
  coalesce((select max(evidence_number) from public.machines), 0) > 0
);

alter table public.machines
  alter column evidence_number set default nextval('public.machine_evidence_number_seq');

create unique index if not exists machines_evidence_number_uidx
  on public.machines (evidence_number)
  where evidence_number is not null;
