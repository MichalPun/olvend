alter table public.inventory_audits
  add column if not exists operator_statement text,
  add column if not exists operator_statement_at timestamp with time zone,
  add column if not exists statement_due_date date,
  add column if not exists responsibility_status text not null default 'pending',
  add column if not exists responsibility_decision_note text,
  add column if not exists responsibility_decided_at timestamp with time zone,
  add column if not exists bonus_impact_amount numeric(14,2),
  add column if not exists bonus_period date;

alter table public.inventory_audits
  drop constraint if exists inventory_audits_responsibility_status_check;

alter table public.inventory_audits
  add constraint inventory_audits_responsibility_status_check
  check (responsibility_status in ('pending', 'operator', 'not_operator', 'cancelled'));

create index if not exists inventory_audits_operator_review_idx
  on public.inventory_audits (assigned_employee_id, status, operator_statement_at, audit_date desc);

comment on column public.inventory_audits.operator_statement is
  'Vyjádření operátora k rozdílu. Samo o sobě neznamená uznání odpovědnosti.';

comment on column public.inventory_audits.responsibility_status is
  'Výsledek manažerského prověření: pending, operator, not_operator nebo cancelled.';

comment on column public.inventory_audits.bonus_impact_amount is
  'Schválený dopad do nenárokové prémie. NULL znamená, že dopad nebyl stanoven.';
