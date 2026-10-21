import fs from 'node:fs'
import assert from 'node:assert/strict'

const mobile = fs.readFileSync(new URL('../mobile.html', import.meta.url), 'utf8')
const sql = fs.readFileSync(new URL('../database/route_visit_completion_integrity_v63.sql', import.meta.url), 'utf8')

assert.match(mobile, /if \(!\(detail\.containers \|\| \[\]\)\.length\)/)
assert.match(mobile, /nemá nastavený plánogram zásobníků/)

assert.match(sql, /new\.status <> 'completed' or old\.status = 'completed'/)
assert.match(sql, /machine_coffee_containers[\s\S]+container\.active = true/)
assert.match(sql, /item\.coffee_container_id = container\.id[\s\S]+item\.accepted_at is not null/)
assert.match(sql, /machine_planogram_slots[\s\S]+slot\.active = true/)
assert.match(sql, /item\.planogram_slot_id = slot\.id[\s\S]+item\.accepted_at is not null/)
assert.match(sql, /using errcode = '23514'/)

console.log('PASS: mobile and database both block incomplete route-visit completion')
