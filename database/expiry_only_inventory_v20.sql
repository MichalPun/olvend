begin;

-- Provoz OLVEND sleduje u potravin datum expirace. Výrobní číslo šarže
-- není pro příjem ani další pohyby povinné; inventory_batches zůstává
-- interním nosičem jednotlivých skupin kusů se stejnou expirací.
update public.products
set requires_batch_tracking = false,
    updated_at = now()
where requires_batch_tracking is true;

commit;
