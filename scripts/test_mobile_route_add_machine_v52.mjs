import assert from 'node:assert/strict'
import fs from 'node:fs'
import vm from 'node:vm'

const html = fs.readFileSync(new URL('../mobile.html', import.meta.url), 'utf8')
const sql = fs.readFileSync(new URL('../database/mobile_route_add_machine_approval_v52.sql', import.meta.url), 'utf8')
const nextStopSql = fs.readFileSync(new URL('../database/mobile_route_add_machine_next_stop_v53.sql', import.meta.url), 'utf8')
const edge = fs.readFileSync(new URL('../backend/supabase/functions/route-add-approval/index.ts', import.meta.url), 'utf8')
const approval = fs.readFileSync(new URL('../route-add-approval.html', import.meta.url), 'utf8')

for (const match of html.matchAll(/<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)<\/script>/gi)) {
  if (!match[1].trim()) continue
  if (/^\s*import\s/m.test(match[1])) new vm.SourceTextModule(match[1], { identifier: 'mobile.html' })
  else new vm.Script(match[1], { filename: 'mobile.html' })
}

assert.match(html, /\+ Požádat o přidání automatu/)
assert.match(html, /data-add-route-machine-id/)
assert.match(html, /route-add-approval/)
assert.match(html, /get_my_route_add_machine_requests_v52/)
assert.match(html, /cancel_my_route_add_machine_request_v52/)
assert.match(html, /refreshRouteAddMachineApproval/)
assert.match(html, /byl přidán jako další zastávka/)
assert.match(html, /Schválený automat je závazně další otevřená zastávka/)
assert.match(html, /\|order:\$\{openOrder\}\|live:/)
assert.match(html, /data-coffee-before-percent/)
assert.match(html, /data-coffee-extra-before-percent/)
assert.match(html, /input type="range" min="0" max="100" step="5"/)
assert.match(html, /data-coffee-percent-column/)
assert.match(html, /data-coffee-percent-readout/)
assert.match(html, /data-coffee-percent-quick="\$\{percent\}"/)
assert.match(html, /data-coffee-percent-system-quantity/)
assert.match(html, /data-coffee-accept-live/)
assert.match(html, /updateCoffeeFillPercentSelector/)
assert.match(html, /getCoffeeQuantityFromFillPercent/)
assert.doesNotMatch(html, /data-coffee-before-input/)
assert.doesNotMatch(html, /data-coffee-extra-before-input/)
assert.doesNotMatch(html, /coffee-percent-entry/)

assert.match(sql, /create table if not exists public\.route_add_machine_requests/)
assert.match(sql, /create or replace function public\.decide_route_add_machine_v52/)
assert.match(sql, /insert into public\.route_plan_stops/)
assert.match(sql, /'restock', 'planned'/)
assert.match(sql, /guard_route_plan_pending_add_v52/)
assert.match(sql, /added_route_plan_stop_id/)
assert.match(sql, /select min\(stop_order\) into v_stop_order/)
assert.match(sql, /set stop_order = stop_order \+ 1000000/)
assert.match(sql, /set stop_order = stop_order - 999999/)
assert.match(nextStopSql, /place_approved_route_add_next_v53/)
assert.match(nextStopSql, /new\.stop_order := v_next_order/)
assert.match(nextStopSql, /r\.status = 'pending'/)
assert.match(edge, /decide_route_add_machine_v52/)
assert.match(edge, /route_add_machine_requests/)
assert.match(edge, /Tento automat už v trase je/)
assert.match(approval, /route-add-approval/)

console.log('OK: procentuální stav zásobníků a schvalované přidání automatu do trasy')
