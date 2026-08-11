begin;

alter table public.mail_message_index
  add column if not exists is_answered boolean not null default false;

commit;
