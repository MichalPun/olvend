begin;

create extension if not exists pg_cron with schema pg_catalog;
create extension if not exists pg_net with schema extensions;

alter table public.mail_accounts
  add column if not exists account_purpose text not null default 'personal',
  add column if not exists finance_last_uid bigint,
  add column if not exists finance_uid_validity text,
  add column if not exists finance_last_result jsonb not null default '{}'::jsonb;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid='public.mail_accounts'::regclass
      and conname='mail_accounts_purpose_check'
  ) then
    alter table public.mail_accounts
      add constraint mail_accounts_purpose_check
      check(account_purpose in ('personal','finance_intake'));
  end if;
end;
$$;

create unique index if not exists mail_accounts_one_active_finance_intake_idx
  on public.mail_accounts(account_purpose)
  where account_purpose='finance_intake' and active;

alter table public.finance_document_intake_queue
  add column if not exists mail_account_uuid uuid references public.mail_accounts(id) on delete restrict,
  add column if not exists message_received_at timestamptz;

create unique index if not exists finance_intake_mail_uid_attachment_idx
  on public.finance_document_intake_queue(mail_account_uuid,mail_folder,mail_uid,attachment_index)
  where mail_account_uuid is not null;

create index if not exists finance_intake_recent_idx
  on public.finance_document_intake_queue(discovered_at desc);

grant select on table public.finance_document_intake_queue to authenticated;

do $$
declare existing_job_id bigint;
begin
  select jobid into existing_job_id
  from cron.job where jobname='finance-mail-intake-5m' limit 1;
  if existing_job_id is not null then perform cron.unschedule(existing_job_id); end if;

  perform cron.schedule(
    'finance-mail-intake-5m',
    '*/5 * * * *',
    $cron$
      select net.http_get(
        url := 'https://olvend-mail-service.onrender.com/healthz?finance=1',
        timeout_milliseconds := 70000
      );
    $cron$
  );
end;
$$;

comment on column public.mail_accounts.account_purpose is
  'Odděluje soukromou zaměstnaneckou schránku od jediné sdílené schránky pro příjem faktur.';
comment on column public.finance_document_intake_queue.mail_account_uuid is
  'Vazba na šifrovaně uložené IMAP připojení v mail_accounts.';

commit;
