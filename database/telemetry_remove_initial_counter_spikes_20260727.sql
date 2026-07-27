-- First DEX payloads for freshly mapped coffee machines contained lifetime counters.
-- They were imported as today's sales because the previous manual baseline was zero/empty.
delete from public.telemetry_sales_events
where ingest_id in (23698, 23889, 23892, 23898, 23904, 23905);
