import assert from 'node:assert/strict'
import fs from 'node:fs'

const sql = fs.readFileSync(new URL('../database/mobile_route_add_machine_guard_security_v55.sql', import.meta.url), 'utf8')

assert.match(sql, /create or replace function public\.guard_route_plan_pending_add_v52\(\)/)
assert.match(sql, /language plpgsql\s+security definer\s+set search_path = public/i)
assert.match(sql, /from public\.route_add_machine_requests r/)
assert.match(sql, /revoke all on function public\.guard_route_plan_pending_add_v52\(\) from public, anon, authenticated/)
assert.doesNotMatch(sql, /grant select on public\.route_add_machine_requests/i)

console.log('OK: trigger čte interní žádosti jako SECURITY DEFINER bez zpřístupnění tabulky mobilu')
