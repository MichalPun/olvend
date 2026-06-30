-- Switch coffee recipes from discontinued oVe Elite to Barbera Tris.
-- Production note from 2026-06-30: operators no longer use Elite, they receive Tris.

update public.recipe_items
set product_id = 26
where product_id = 107;

update public.products
set
  active = false,
  note = concat_ws(E'\n', nullif(note, ''), '2026-06-30: Nahrazeno položkou Barbera Tris 1 kg (SKU 201). Nepoužívat pro nové nakládky ani receptury.')
where id = 107;
