alter table public.daily_instructions
  add column if not exists attachment_url text,
  add column if not exists attachment_label text;
