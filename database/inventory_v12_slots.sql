alter table public.stock_items
  add column if not exists planogram_slot_id bigint references public.machine_planogram_slots (id) on delete set null;

alter table public.stock_movements
  add column if not exists planogram_slot_id bigint references public.machine_planogram_slots (id) on delete set null;

create index if not exists stock_items_planogram_slot_idx
  on public.stock_items (planogram_slot_id);

create index if not exists stock_movements_planogram_slot_idx
  on public.stock_movements (planogram_slot_id);
