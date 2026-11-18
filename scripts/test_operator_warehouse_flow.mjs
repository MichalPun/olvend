import assert from 'node:assert/strict'
import { readFileSync, existsSync } from 'node:fs'

const html = readFileSync(new URL('../olvend-operator/sklad.html', import.meta.url), 'utf8')
const script = readFileSync(new URL('../olvend-operator/operator-warehouse.js', import.meta.url), 'utf8')
const worker = readFileSync(new URL('../olvend-operator/sw-v44.js', import.meta.url), 'utf8')

assert.match(html, /operator-warehouse-v2\.css/)
assert.match(script, /warehouse-loading-v1\.jpg/)
assert.match(script, /Ranní nakládka/)
assert.match(script, /Bagety na dnešní trasu/)
assert.match(script, /Prodejné vratky/)
assert.match(script, /Expirace a odpisy/)
assert.match(script, /Inventura před dokončením/)
assert.match(script, /route_machine_visit_items/)
assert.match(script, /route_vehicle_waste_items/)
assert.match(script, /inventory_audit_items/)
assert.match(script, /apply_stock_movements_v13/)
assert.match(script, /record_operator_warehouse_step_v66/)
assert.match(script, /route\.execution_status === 'done'/)
assert.doesNotMatch(script, /\.finally\(/, 'Android 7.1 workflow must not depend on Promise.finally')
assert.ok(existsSync(new URL('../olvend-operator/assets/warehouse-loading-v1.jpg', import.meta.url)))
assert.match(worker, /olvend-operator-v46-warehouse-flow/)
assert.match(worker, /operator-warehouse-v2\.css/)
assert.match(worker, /warehouse-loading-v1\.jpg/)

console.log('operator warehouse flow checks passed')
