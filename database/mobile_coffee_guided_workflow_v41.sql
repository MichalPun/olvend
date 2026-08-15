begin;

alter table public.route_machine_cash_reports
  add column if not exists collection_required boolean not null default false,
  add column if not exists collection_threshold_czk numeric(12,2) not null default 200,
  add column if not exists short_bag_code text,
  add column if not exists bag_reference uuid,
  add column if not exists retained_for_next_visit boolean not null default false;

create unique index if not exists route_machine_cash_open_bag_code_idx
  on public.route_machine_cash_reports (short_bag_code)
  where operator_collected_confirmed is true and supervisor_counted_at is null and short_bag_code is not null;

create table if not exists public.route_machine_visit_evidence (
  id uuid primary key default gen_random_uuid(),
  visit_id bigint not null references public.route_machine_visits(id) on delete cascade,
  machine_id bigint not null references public.machines(id) on delete cascade,
  employee_id uuid references public.employees(id) on delete set null,
  evidence_kind text not null default 'quality_photo'
    check (evidence_kind in ('quality_photo')),
  target_key text not null,
  target_label text not null,
  storage_path text,
  mime_type text,
  file_size_bytes bigint,
  captured_at timestamptz,
  latitude numeric,
  longitude numeric,
  review_status text not null default 'pending'
    check (review_status in ('pending','ok','issue','deleted')),
  reviewed_by uuid references public.employees(id) on delete set null,
  reviewed_at timestamptz,
  issue_resolved_at timestamptz,
  legal_hold boolean not null default false,
  delete_after timestamptz,
  deleted_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique (visit_id, evidence_kind)
);

create index if not exists route_machine_visit_evidence_retention_idx
  on public.route_machine_visit_evidence (delete_after)
  where deleted_at is null and legal_hold is false;

alter table public.route_machine_visit_evidence enable row level security;

drop policy if exists "Allow read route machine visit evidence" on public.route_machine_visit_evidence;
create policy "Allow read route machine visit evidence" on public.route_machine_visit_evidence
for select to authenticated, anon using (true);

drop policy if exists "Allow write route machine visit evidence" on public.route_machine_visit_evidence;
create policy "Allow write route machine visit evidence" on public.route_machine_visit_evidence
for all to authenticated, anon using (true) with check (true);

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'coffee-visit-evidence',
  'coffee-visit-evidence',
  false,
  2097152,
  array['image/jpeg','image/webp']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Mobile coffee evidence read" on storage.objects;
create policy "Mobile coffee evidence read" on storage.objects
for select to authenticated, anon
using (bucket_id = 'coffee-visit-evidence');

drop policy if exists "Mobile coffee evidence insert" on storage.objects;
create policy "Mobile coffee evidence insert" on storage.objects
for insert to authenticated, anon
with check (bucket_id = 'coffee-visit-evidence');

drop policy if exists "Mobile coffee evidence update" on storage.objects;
create policy "Mobile coffee evidence update" on storage.objects
for update to authenticated, anon
using (bucket_id = 'coffee-visit-evidence')
with check (bucket_id = 'coffee-visit-evidence');

drop policy if exists "Mobile coffee evidence delete" on storage.objects;
create policy "Mobile coffee evidence delete" on storage.objects
for delete to authenticated, anon
using (bucket_id = 'coffee-visit-evidence');

create or replace function public.assign_coffee_visit_guidance_v41(p_visit_id bigint)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_visit public.route_machine_visits%rowtype;
  v_button public.machine_coffee_buttons%rowtype;
  v_last_photo timestamptz;
  v_photo_required boolean := false;
  v_photo_target text;
  v_photo_label text;
  v_seed bigint;
  v_bag text;
  v_result jsonb;
begin
  select * into v_visit from public.route_machine_visits where id=p_visit_id;
  if not found then raise exception 'Návštěva neexistuje.'; end if;

  select max(captured_at) into v_last_photo
  from public.route_machine_visit_evidence
  where machine_id=v_visit.machine_id and captured_at is not null;

  v_seed := abs(hashtextextended(p_visit_id::text || ':' || v_visit.machine_id::text, 0));
  v_photo_required := v_last_photo is null
    or v_last_photo < now() - interval '30 days'
    or (v_seed % 100) < 25;

  case (v_seed % 6)
    when 0 then v_photo_target := 'internal_mixers'; v_photo_label := 'mixéry a míchací misky po umytí';
    when 1 then v_photo_target := 'internal_brewer'; v_photo_label := 'spařovací jednotku a prostor odpadu';
    when 2 then v_photo_target := 'internal_clean'; v_photo_label := 'čistý vnitřek automatu';
    when 3 then v_photo_target := 'external_panel'; v_photo_label := 'horní panel a nabídku nápojů';
    when 4 then v_photo_target := 'external_dispense'; v_photo_label := 'výdejní prostor a odkapávač';
    else v_photo_target := 'external_full'; v_photo_label := 'celý čistý automat zepředu';
  end case;

  select b.* into v_button
  from public.machine_coffee_buttons b
  where b.machine_id=v_visit.machine_id and b.active is true
  order by abs(hashtextextended(p_visit_id::text || ':' || b.id::text, 0))
  limit 1;

  insert into public.route_machine_visit_checks(visit_id,check_key,label,required,status,assigned_payload)
  values
    (p_visit_id,'inside_mixers','Vyjmi, umyj, vysuš a vrať mixéry a míchací misky',true,'pending','{"section":"inside","order":10}'::jsonb),
    (p_visit_id,'inside_outlets','Odstraň nánosy prášku z výsypek surovin',true,'pending','{"section":"inside","order":20}'::jsonb),
    (p_visit_id,'inside_hoses','Umyj hadičky, trysky a držák výdeje',true,'pending','{"section":"inside","order":30}'::jsonb),
    (p_visit_id,'inside_brewer','Vyčisti spařovací jednotku a prostor kávy',true,'pending','{"section":"inside","order":40}'::jsonb),
    (p_visit_id,'inside_waste','Vyprázdni a umyj odpad, vlož nový sáček',true,'pending','{"section":"inside","order":50}'::jsonb),
    (p_visit_id,'inside_surfaces','Umyj a vysuš vnitřní stěny a police',true,'pending','{"section":"inside","order":60}'::jsonb),
    (p_visit_id,'inside_reassemble','Zkontroluj sestavení a zavři vnitřní část',true,'pending','{"section":"inside","order":70}'::jsonb),
    (p_visit_id,'outside_panel','Umyj horní panel a nabídku nápojů',true,'pending','{"section":"outside","order":110}'::jsonb),
    (p_visit_id,'outside_payment','Vyčisti displej a platební část',true,'pending','{"section":"outside","order":120}'::jsonb),
    (p_visit_id,'outside_dispense','Umyj výdejní prostor a odkapávač',true,'pending','{"section":"outside","order":130}'::jsonb),
    (p_visit_id,'outside_front','Umyj spodní čelní panel automatu',true,'pending','{"section":"outside","order":140}'::jsonb),
    (p_visit_id,'outside_surroundings','Ukliď bezprostřední okolí automatu',true,'pending','{"section":"outside","order":150}'::jsonb)
  on conflict(visit_id,check_key) do nothing;

  if v_button.id is not null then
    insert into public.route_machine_visit_checks(visit_id,check_key,label,required,status,assigned_payload)
    values (
      p_visit_id,
      'test_drink',
      'Připrav zkušební nápoj',
      true,
      'pending',
      jsonb_build_object('section','test','order',90,'button_id',v_button.id,'selection_code',v_button.selection_code,'product_name',coalesce(v_button.product_name,'Nápoj'))
    ) on conflict(visit_id,check_key) do nothing;
  end if;

  if v_photo_required then
    insert into public.route_machine_visit_checks(visit_id,check_key,label,required,status,assigned_payload)
    values (
      p_visit_id,
      'quality_photo',
      'Pořiď jednu kontrolní fotografii',
      true,
      'pending',
      jsonb_build_object('section','photo','order',case when v_photo_target like 'internal_%' then 80 else 190 end,'target_key',v_photo_target,'target_label',v_photo_label)
    ) on conflict(visit_id,check_key) do nothing;
  end if;

  loop
    v_bag := lpad((1000 + floor(random()*9000)::int)::text,4,'0');
    exit when not exists(
      select 1 from public.route_machine_cash_reports
      where short_bag_code=v_bag and operator_collected_confirmed is true and supervisor_counted_at is null
    );
  end loop;

  select jsonb_build_object(
    'photo_required',v_photo_required,
    'photo_target',v_photo_target,
    'photo_label',v_photo_label,
    'test_button_id',v_button.id,
    'test_selection_code',v_button.selection_code,
    'test_product_name',v_button.product_name,
    'suggested_bag_code',v_bag
  ) into v_result;
  return v_result;
end;
$$;

grant execute on function public.assign_coffee_visit_guidance_v41(bigint) to authenticated, anon;

create or replace function public.cleanup_coffee_visit_evidence_v41()
returns integer
language plpgsql
security definer
set search_path = public, storage
as $$
declare v_count integer;
begin
  with doomed as (
    select id,storage_path
    from public.route_machine_visit_evidence
    where deleted_at is null
      and legal_hold is false
      and delete_after is not null
      and delete_after <= now()
      and (review_status <> 'issue' or issue_resolved_at is not null)
  ), deleted_objects as (
    delete from storage.objects o using doomed d
    where o.bucket_id='coffee-visit-evidence' and o.name=d.storage_path
    returning o.name
  )
  update public.route_machine_visit_evidence e
  set deleted_at=now(), review_status='deleted', storage_path=null
  from doomed d where e.id=d.id;
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke all on function public.cleanup_coffee_visit_evidence_v41() from public;

commit;
