alter table public.daily_instructions
  add column if not exists instruction_type text not null default 'general',
  add column if not exists instruction_payload jsonb not null default '{}'::jsonb,
  add column if not exists source_reference text;

create unique index if not exists daily_instructions_source_reference_uidx
  on public.daily_instructions (source_reference)
  where source_reference is not null;

comment on column public.daily_instructions.instruction_type is
  'Presentation and workflow type. mandatory_fefo renders the locked short-expiry loading instruction.';
comment on column public.daily_instructions.instruction_payload is
  'Structured data used by specialized mobile instruction layouts.';

insert into public.daily_instructions (
  title, message, target_type, target_employee_id, valid_from, valid_to,
  priority, requires_acknowledgement, is_active,
  instruction_type, instruction_payload, source_reference
) values
(
  'Bagety s krátkou expirací',
  '[POVINNA_FEFO] Nejdřív nalož 8 ks baget s expirací 18. 8. 2026 a vlož je do automatů podle rozpisu. Novější expiraci použij až potom.',
  'employee', '9133f82b-89a6-4581-955c-d2138b947a8d'::uuid,
  date '2026-08-17', date '2026-08-17', 'critical', true, true,
  'mandatory_fefo',
  jsonb_build_object(
    'mandatoryQuantity', 8,
    'expiryDate', '2026-08-18',
    'expiryLabel', '18. 8.',
    'routeId', 55,
    'routeLabel', '#55',
    'warningTitle', 'Neber novější expiraci',
    'warningText', 'Nejdřív nalož všechny níže uvedené bagety s expirací 18. 8. Teprve potom doplň zbytek běžné nakládky.',
    'loadNotice', 'Těchto 8 kusů je povinná nejstarší část. Celkové množství načti přes Ranní nakládku; aplikace k němu přidá běžnou potřebu trasy.',
    'confirmText', 'Rozumím: v Ranní nakládce vezmu nejdřív 8 ks s expirací 18. 8. a vložím je do uvedených automatů.',
    'destinations', jsonb_build_array(
      jsonb_build_object('location', 'Vitar Tišnov · EV 78', 'quantity', 6, 'items', '2× Labužník · 2× Debrecínská · 2× Trhané vepřové'),
      jsonb_build_object('location', 'NTS Brno-Slatina · EV 65', 'quantity', 2, 'items', '1× Kuře teriyaki · 1× Debrecínská')
    )
  ),
  'mandatory-fefo:2026-08-17:employee:9133f82b-89a6-4581-955c-d2138b947a8d'
),
(
  'Bagety s krátkou expirací',
  '[POVINNA_FEFO] Nejdřív nalož 21 ks baget s expirací 18. 8. 2026 a vlož je do automatů podle rozpisu. Novější expiraci použij až potom.',
  'employee', '7f724803-eb2e-44fc-afba-0b87b82cdbc5'::uuid,
  date '2026-08-17', date '2026-08-17', 'critical', true, true,
  'mandatory_fefo',
  jsonb_build_object(
    'mandatoryQuantity', 21,
    'expiryDate', '2026-08-18',
    'expiryLabel', '18. 8.',
    'routeId', 56,
    'routeLabel', '#56',
    'warningTitle', 'Neber novější expiraci',
    'warningText', 'Nejdřív nalož všechny níže uvedené bagety s expirací 18. 8. Teprve potom doplň zbytek běžné nakládky.',
    'loadNotice', 'Těchto 21 kusů je povinná nejstarší část. Celkové množství načti přes Ranní nakládku; aplikace k němu přidá běžnou potřebu trasy.',
    'confirmText', 'Rozumím: v Ranní nakládce vezmu nejdřív 21 ks s expirací 18. 8. a vložím je do uvedených automatů.',
    'destinations', jsonb_build_array(
      jsonb_build_object('location', 'ViaPharma Ostrava · EV 79', 'quantity', 7, 'items', '2× Labužník · 3× Debrecínská · 2× Trhané vepřové'),
      jsonb_build_object('location', 'Sportisimo · EV 90', 'quantity', 8, 'items', '2× Labužník · 4× Debrecínská · 2× Trhané vepřové'),
      jsonb_build_object('location', 'RIGUM Dubňany · EV 100', 'quantity', 3, 'items', '3× Debrecínská'),
      jsonb_build_object('location', 'Hotel Kovák · EV 23', 'quantity', 1, 'items', '1× Debrecínská'),
      jsonb_build_object('location', 'AZ Klima Milovice · EV 9', 'quantity', 2, 'items', '2× Trhané vepřové')
    )
  ),
  'mandatory-fefo:2026-08-17:employee:7f724803-eb2e-44fc-afba-0b87b82cdbc5'
)
on conflict (source_reference) where source_reference is not null do update
set title = excluded.title,
    message = excluded.message,
    valid_from = excluded.valid_from,
    valid_to = excluded.valid_to,
    priority = excluded.priority,
    requires_acknowledgement = excluded.requires_acknowledgement,
    is_active = excluded.is_active,
    instruction_type = excluded.instruction_type,
    instruction_payload = excluded.instruction_payload,
    updated_at = now();
