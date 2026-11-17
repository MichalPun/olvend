create table if not exists public.operator_weather_cache (
  cache_key text primary key,
  latitude numeric(8, 4) not null,
  longitude numeric(8, 4) not null,
  place_name text,
  temperature_c numeric(5, 1) not null,
  condition_code text not null,
  condition_label text not null,
  observed_at timestamptz,
  fetched_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.operator_weather_cache enable row level security;

revoke all on table public.operator_weather_cache from anon, authenticated;

create index if not exists operator_weather_cache_fetched_at_idx
  on public.operator_weather_cache (fetched_at desc);

comment on table public.operator_weather_cache is
  'Server-side cache for OLVEND Operator weather. MET Norway forecasts outside the Nordic region are reused for at least three hours.';
