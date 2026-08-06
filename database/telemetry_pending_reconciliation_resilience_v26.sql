-- Delayed CA2/DA2 counters are reconciled against pending PA2 vends on every
-- IMA ingest. Without this partial index PostgreSQL scanned the entire sales
-- history and the Edge Function repeatedly hit the statement timeout.

-- Supabase's linked SQL runner executes migration files in a transaction, so this
-- intentionally uses a regular CREATE INDEX. The partial predicate keeps the
-- indexed data set small and the one-time lock brief.
create index if not exists telemetry_sales_pending_reconcile_idx
  on public.telemetry_sales_events (
    provider,
    machine_id,
    source_event_at,
    id
  )
  where unpaid_dispense_quantity > 0;

comment on index public.telemetry_sales_pending_reconcile_idx is
  'Fast lookup of unresolved IMA vends for delayed DEX payment reconciliation.';
