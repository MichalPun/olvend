begin;

alter table public.technical_jobs
  add column if not exists parent_job_id bigint references public.technical_jobs(id) on delete set null;

create index if not exists technical_jobs_parent_job_idx
  on public.technical_jobs(parent_job_id)
  where parent_job_id is not null;

commit;
