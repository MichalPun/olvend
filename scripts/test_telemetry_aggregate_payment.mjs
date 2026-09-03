import assert from 'node:assert/strict'
import fs from 'node:fs'

const source = fs.readFileSync(new URL('../backend/supabase/functions/gp-vendsoft-telemetry/index.ts', import.meta.url), 'utf8')
const migration = fs.readFileSync(new URL('../database/fix_ima_synthetic_aggregate_free_vends_20260903.sql', import.meta.url), 'utf8')

assert.ok(source.includes('function isSyntheticAggregateSaleSlot'), 'Chybí ochrana souhrnného kávového slotu')
assert.ok(source.includes('!isSyntheticAggregateSaleSlot(slot, selection)'), 'Souhrnný slot nesmí být označen jako bezplatný výdej')
assert.ok(source.includes('isExplicitFreeVendSlot(item.slot, item.selection)'), 'Ochrana musí být použitá při alokaci plateb')
assert.ok(migration.includes('unknown_payment_quantity'), 'Historické souhrnné výdeje musí přejít do neurčené platby')
assert.ok(migration.includes('free_vend_quantity = 0'), 'Historická chybná klasifikace musí být odstraněna')

console.log('OK: souhrnná telemetrie volby 0 se nepovažuje za bezplatný výdej')
