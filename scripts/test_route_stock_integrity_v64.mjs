import fs from 'node:fs'
import assert from 'node:assert/strict'

const sql = fs.readFileSync(new URL('../database/route_stock_integrity_monitor_v64.sql', import.meta.url), 'utf8')
const dashboard = fs.readFileSync(new URL('../dashboard.html', import.meta.url), 'utf8')

assert.match(sql, /before insert on public\.route_machine_visits/)
assert.match(sql, /before update of status on public\.route_machine_visits/)
assert.match(sql, /item\.final_quantity is null[\s\S]+item\.issue_type = 'missing_stock'/)
assert.match(sql, /length\(trim\(coalesce\(item\.operator_note, ''\)\)\) >= 10/)
assert.match(sql, /physical_count_source = 'control_route'/)
assert.match(sql, /physical_count_source = 'technician_service'/)
assert.match(sql, /get_route_stock_integrity_issues_v64/)
assert.match(sql, /get_ai_dispatcher_alerts_v64/)
assert.match(dashboard, /rpc\("get_ai_dispatcher_alerts_v64"\)/)

console.log('PASS: v64 guards every stock write path and exposes manager alerts')
