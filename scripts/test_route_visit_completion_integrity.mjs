import fs from 'node:fs'
import assert from 'node:assert/strict'

const mobile = fs.readFileSync(new URL('../mobile.html', import.meta.url), 'utf8')
const sql = fs.readFileSync(new URL('../database/route_stock_integrity_monitor_v64.sql', import.meta.url), 'utf8')

assert.match(mobile, /if \(!\(detail\.containers \|\| \[\]\)\.length\)/)
assert.match(mobile, /nemá nastavený plánogram zásobníků/)
assert.match(mobile, /async function persistUnchangedCoffeeContainerStates/)
assert.match(mobile, /await persistUnchangedCoffeeContainerStates\(stop\.id\)/)
assert.match(mobile, /Hromadně potvrzeno při dokončení: fyzický stav zásobníku souhlasí/)

assert.match(sql, /new\.status <> 'completed'[\s\S]+tg_op = 'UPDATE' and old\.status = 'completed'/)
assert.match(sql, /machine_coffee_containers[\s\S]+container\.active = true/)
assert.match(sql, /item\.coffee_container_id = container\.id[\s\S]+item\.accepted_at is not null/)
assert.match(sql, /machine_planogram_slots[\s\S]+slot\.active = true/)
assert.match(sql, /item\.planogram_slot_id = slot\.id[\s\S]+item\.accepted_at is not null/)
assert.match(sql, /using errcode = '23514'/)
assert.match(sql, /before insert on public\.route_machine_visits/)

console.log('PASS: mobile and database both block incomplete route-visit completion')
