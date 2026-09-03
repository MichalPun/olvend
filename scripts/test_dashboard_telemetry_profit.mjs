import assert from 'node:assert/strict'
import fs from 'node:fs'
import vm from 'node:vm'

const dashboard = fs.readFileSync(new URL('../dashboard.html', import.meta.url), 'utf8')
const migration = fs.readFileSync(new URL('../database/dashboard_telemetry_profit_v49.sql', import.meta.url), 'utf8')

for (const match of dashboard.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/gi)) {
  if (!match[1].trim() || /^\s*import\s/m.test(match[1])) continue
  new vm.Script(match[1], { filename: 'dashboard.html' })
}

assert.match(dashboard, /get_dashboard_telemetry_profit_v49/)
assert.match(dashboard, /data-telemetry-key="profit"/)
assert.match(dashboard, /<span>Zisk<\/span>/)
assert.match(dashboard, /hrubý bez DPH · marže/)
assert.doesNotMatch(dashboard, /data-telemetry-key="machines"/)

assert.match(migration, /security invoker/i)
assert.match(migration, /candidate\.purchase_price/)
assert.match(migration, /total_amount_czk \/ \(1 \+ vat_rate \/ 100\) - quantity \* unit_cost/)
assert.match(migration, /missing_cost_count/)

console.log('OK: dashboard telemetry profit card and SQL')
