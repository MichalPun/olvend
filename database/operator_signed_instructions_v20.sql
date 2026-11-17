-- Signed daily instructions for OLVEND Operator.
-- Stores the final signature on the acknowledgement and a compact audit trail
-- of opening and reading the attached document.

alter table public.instruction_acknowledgements
  add column if not exists document_read_at timestamptz,
  add column if not exists signed_at timestamptz,
  add column if not exists signature_data_url text,
  add column if not exists document_version text,
  add column if not exists document_sha256 text,
  add column if not exists device_info jsonb not null default '{}'::jsonb,
  add column if not exists updated_at timestamptz not null default now();

create table if not exists public.instruction_events (
  id bigint generated always as identity primary key,
  instruction_id bigint not null references public.daily_instructions(id) on delete cascade,
  employee_id uuid not null references public.employees(id) on delete cascade,
  event_type text not null check (event_type in (
    'instruction_opened',
    'attachment_opened',
    'document_read',
    'signature_captured',
    'signed_confirmed'
  )),
  event_at timestamptz not null default now(),
  document_version text,
  document_sha256 text,
  signature_data_url text,
  device_info jsonb not null default '{}'::jsonb,
  details jsonb not null default '{}'::jsonb,
  constraint instruction_events_one_type_per_employee unique (instruction_id, employee_id, event_type)
);

alter table public.instruction_events
  add column if not exists signature_data_url text;

alter table public.instruction_events
  drop constraint if exists instruction_events_event_type_check;
alter table public.instruction_events
  add constraint instruction_events_event_type_check check (event_type in (
    'instruction_opened',
    'attachment_opened',
    'document_read',
    'signature_captured',
    'signed_confirmed'
  ));

create index if not exists instruction_events_employee_idx
  on public.instruction_events (employee_id, event_at desc);
create index if not exists instruction_events_instruction_idx
  on public.instruction_events (instruction_id, event_at desc);

alter table public.instruction_events enable row level security;

-- Remove the original anonymous acknowledgement policies before signatures are
-- stored in the same table. Existing authenticated application flows continue
-- to work, but an operator can only see and write their own acknowledgement.
drop policy if exists "Allow read instruction acknowledgements" on public.instruction_acknowledgements;
drop policy if exists "Allow insert instruction acknowledgements" on public.instruction_acknowledgements;
drop policy if exists "Allow update instruction acknowledgements" on public.instruction_acknowledgements;

drop policy if exists instruction_ack_select_self_or_manager on public.instruction_acknowledgements;
create policy instruction_ack_select_self_or_manager
on public.instruction_acknowledgements
for select to authenticated
using (employee_id = public.current_employee_id() or public.has_manager_access());

drop policy if exists instruction_ack_insert_self_or_manager on public.instruction_acknowledgements;
create policy instruction_ack_insert_self_or_manager
on public.instruction_acknowledgements
for insert to authenticated
with check (employee_id = public.current_employee_id() or public.has_manager_access());

drop policy if exists instruction_ack_update_self_or_manager on public.instruction_acknowledgements;
create policy instruction_ack_update_self_or_manager
on public.instruction_acknowledgements
for update to authenticated
using (employee_id = public.current_employee_id() or public.has_manager_access())
with check (employee_id = public.current_employee_id() or public.has_manager_access());

drop policy if exists instruction_events_select_self_or_manager on public.instruction_events;
create policy instruction_events_select_self_or_manager
on public.instruction_events
for select to authenticated
using (employee_id = public.current_employee_id() or public.has_manager_access());

grant select on public.instruction_events to authenticated;

create or replace function public.record_instruction_event(
  p_instruction_id bigint,
  p_event_type text,
  p_document_version text default null,
  p_document_sha256 text default null,
  p_device_info jsonb default '{}'::jsonb
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_employee_id uuid := public.current_employee_id();
  v_employee_role text;
  v_instruction public.daily_instructions%rowtype;
begin
  if v_employee_id is null then
    raise exception 'Přihlášený účet není zaměstnanec.';
  end if;
  if p_event_type not in ('instruction_opened', 'attachment_opened', 'document_read') then
    raise exception 'Nepovolený typ události pokynu.';
  end if;

  select role into v_employee_role from public.employees where id = v_employee_id and active is true;
  select * into v_instruction from public.daily_instructions where id = p_instruction_id;
  if not found or v_instruction.is_active is false then
    raise exception 'Pokyn není aktivní.';
  end if;
  if v_instruction.valid_from > current_date
     or (v_instruction.valid_to is not null and v_instruction.valid_to < current_date) then
    raise exception 'Pokyn dnes není platný.';
  end if;
  if not (
    v_instruction.target_type = 'company'
    or (v_instruction.target_type = 'employee' and v_instruction.target_employee_id = v_employee_id)
    or (v_instruction.target_type = 'role' and lower(v_instruction.target_role) = lower(v_employee_role))
  ) then
    raise exception 'Pokyn není určen přihlášenému operátorovi.';
  end if;

  insert into public.instruction_events (
    instruction_id, employee_id, event_type, document_version,
    document_sha256, device_info
  ) values (
    p_instruction_id, v_employee_id, p_event_type, nullif(p_document_version, ''),
    nullif(p_document_sha256, ''), coalesce(p_device_info, '{}'::jsonb)
  )
  on conflict (instruction_id, employee_id, event_type) do nothing;

  return true;
end;
$$;

create or replace function public.confirm_signed_instruction(
  p_instruction_id bigint,
  p_signature_data_url text,
  p_document_read_at timestamptz,
  p_document_version text default null,
  p_document_sha256 text default null,
  p_device_info jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_employee_id uuid := public.current_employee_id();
  v_employee_role text;
  v_instruction public.daily_instructions%rowtype;
  v_now timestamptz := now();
  v_requires_signature boolean;
  v_expected_version text;
  v_expected_sha256 text;
begin
  if v_employee_id is null then
    raise exception 'Přihlášený účet není zaměstnanec.';
  end if;

  select role into v_employee_role from public.employees where id = v_employee_id and active is true;
  select * into v_instruction from public.daily_instructions where id = p_instruction_id;
  if not found or v_instruction.is_active is false then
    raise exception 'Pokyn není aktivní.';
  end if;
  if v_instruction.valid_from > current_date
     or (v_instruction.valid_to is not null and v_instruction.valid_to < current_date) then
    raise exception 'Pokyn dnes není platný.';
  end if;
  if not (
    v_instruction.target_type = 'company'
    or (v_instruction.target_type = 'employee' and v_instruction.target_employee_id = v_employee_id)
    or (v_instruction.target_type = 'role' and lower(v_instruction.target_role) = lower(v_employee_role))
  ) then
    raise exception 'Pokyn není určen přihlášenému operátorovi.';
  end if;

  v_requires_signature := lower(coalesce(v_instruction.instruction_payload->>'requiresSignature', 'false')) = 'true';
  v_expected_version := nullif(v_instruction.instruction_payload->>'documentVersion', '');
  v_expected_sha256 := nullif(v_instruction.instruction_payload->>'documentSha256', '');

  if v_instruction.attachment_url is not null and not exists (
    select 1 from public.instruction_events e
    where e.instruction_id = p_instruction_id
      and e.employee_id = v_employee_id
      and e.event_type = 'document_read'
  ) then
    raise exception 'Nejdříve potvrďte přečtení přiloženého dokumentu.';
  end if;
  if v_requires_signature and (
    p_signature_data_url is null
    or length(p_signature_data_url) < 200
    or p_signature_data_url not like 'data:image/png;base64,%'
  ) then
    raise exception 'Podpis nebyl správně zaznamenán.';
  end if;
  if v_requires_signature and not exists (
    select 1 from public.instruction_events e
    where e.instruction_id = p_instruction_id
      and e.employee_id = v_employee_id
      and e.event_type = 'signature_captured'
      and e.signature_data_url = p_signature_data_url
  ) then
    raise exception 'Nejprve dokončete uložení podpisu.';
  end if;
  if v_expected_version is not null and coalesce(p_document_version, '') <> v_expected_version then
    raise exception 'Verze potvrzovaného dokumentu nesouhlasí.';
  end if;
  if v_expected_sha256 is not null and coalesce(p_document_sha256, '') <> v_expected_sha256 then
    raise exception 'Kontrolní otisk potvrzovaného dokumentu nesouhlasí.';
  end if;

  insert into public.instruction_acknowledgements (
    instruction_id, employee_id, acknowledged_at, document_read_at, signed_at,
    signature_data_url, document_version, document_sha256, device_info, updated_at
  ) values (
    p_instruction_id, v_employee_id, v_now, p_document_read_at,
    case when v_requires_signature then v_now else null end,
    case when v_requires_signature then p_signature_data_url else null end,
    nullif(p_document_version, ''), nullif(p_document_sha256, ''),
    coalesce(p_device_info, '{}'::jsonb), v_now
  )
  on conflict (instruction_id, employee_id) do update
  set acknowledged_at = excluded.acknowledged_at,
      document_read_at = excluded.document_read_at,
      signed_at = excluded.signed_at,
      signature_data_url = excluded.signature_data_url,
      document_version = excluded.document_version,
      document_sha256 = excluded.document_sha256,
      device_info = excluded.device_info,
      updated_at = excluded.updated_at;

  insert into public.instruction_events (
    instruction_id, employee_id, event_type, event_at, document_version,
    document_sha256, device_info
  ) values (
    p_instruction_id, v_employee_id, 'signed_confirmed', v_now,
    nullif(p_document_version, ''), nullif(p_document_sha256, ''),
    coalesce(p_device_info, '{}'::jsonb)
  )
  on conflict (instruction_id, employee_id, event_type) do update
  set event_at = excluded.event_at,
      document_version = excluded.document_version,
      document_sha256 = excluded.document_sha256,
      device_info = excluded.device_info;

  return jsonb_build_object(
    'instruction_id', p_instruction_id,
    'employee_id', v_employee_id,
    'acknowledged_at', v_now,
    'signed', v_requires_signature
  );
end;
$$;

create or replace function public.save_instruction_signature(
  p_instruction_id bigint,
  p_signature_data_url text default null,
  p_document_version text default null,
  p_document_sha256 text default null,
  p_device_info jsonb default '{}'::jsonb
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_employee_id uuid := public.current_employee_id();
  v_employee_role text;
  v_instruction public.daily_instructions%rowtype;
begin
  if v_employee_id is null then
    raise exception 'Přihlášený účet není zaměstnanec.';
  end if;

  select role into v_employee_role from public.employees where id = v_employee_id and active is true;
  select * into v_instruction from public.daily_instructions where id = p_instruction_id;
  if not found or v_instruction.is_active is false then
    raise exception 'Pokyn není aktivní.';
  end if;
  if not (
    v_instruction.target_type = 'company'
    or (v_instruction.target_type = 'employee' and v_instruction.target_employee_id = v_employee_id)
    or (v_instruction.target_type = 'role' and lower(v_instruction.target_role) = lower(v_employee_role))
  ) then
    raise exception 'Pokyn není určen přihlášenému operátorovi.';
  end if;
  if not exists (
    select 1 from public.instruction_events e
    where e.instruction_id = p_instruction_id
      and e.employee_id = v_employee_id
      and e.event_type = 'document_read'
  ) and v_instruction.attachment_url is not null then
    raise exception 'Nejdříve potvrďte přečtení přiloženého dokumentu.';
  end if;

  if p_signature_data_url is null or p_signature_data_url = '' then
    delete from public.instruction_events
    where instruction_id = p_instruction_id
      and employee_id = v_employee_id
      and event_type = 'signature_captured';
    return true;
  end if;

  if length(p_signature_data_url) < 200 or p_signature_data_url not like 'data:image/png;base64,%' then
    raise exception 'Podpis nebyl správně zaznamenán.';
  end if;

  insert into public.instruction_events (
    instruction_id, employee_id, event_type, event_at, document_version,
    document_sha256, signature_data_url, device_info
  ) values (
    p_instruction_id, v_employee_id, 'signature_captured', now(),
    nullif(p_document_version, ''), nullif(p_document_sha256, ''),
    p_signature_data_url, coalesce(p_device_info, '{}'::jsonb)
  )
  on conflict (instruction_id, employee_id, event_type) do update
  set event_at = excluded.event_at,
      document_version = excluded.document_version,
      document_sha256 = excluded.document_sha256,
      signature_data_url = excluded.signature_data_url,
      device_info = excluded.device_info;

  return true;
end;
$$;

revoke all on function public.record_instruction_event(bigint, text, text, text, jsonb) from public, anon;
revoke all on function public.confirm_signed_instruction(bigint, text, timestamptz, text, text, jsonb) from public, anon;
revoke all on function public.save_instruction_signature(bigint, text, text, text, jsonb) from public, anon;
grant execute on function public.record_instruction_event(bigint, text, text, text, jsonb) to authenticated;
grant execute on function public.confirm_signed_instruction(bigint, text, timestamptz, text, text, jsonb) to authenticated;
grant execute on function public.save_instruction_signature(bigint, text, text, text, jsonb) to authenticated;

comment on table public.instruction_events is
  'Audit trail of opening, reading and signing daily instructions in OLVEND Operator.';
comment on column public.instruction_acknowledgements.signature_data_url is
  'PNG signature captured on the operator PDA, stored as a data URL.';
