-- Partnerské ceny mohou být sjednané včetně DPH. Přesnější základ zabrání
-- haléřové odchylce při převodu například 10 Kč / 1,21.

alter table public.machine_coffee_buttons
  alter column settlement_amount_czk type numeric(12,6);

alter table public.machine_planogram_slots
  alter column settlement_amount_czk type numeric(12,6),
  alter column subsidy_amount_czk type numeric(12,6);

alter table public.telemetry_financial_settlements
  alter column amount_per_unit_czk type numeric(12,6);
