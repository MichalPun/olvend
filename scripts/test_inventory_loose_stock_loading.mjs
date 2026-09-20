import assert from 'node:assert/strict'
import fs from 'node:fs'
import vm from 'node:vm'
const html = fs.readFileSync(new URL('../inventory.html', import.meta.url), 'utf8')
const extract = name => {
  const start = html.indexOf(`    function ${name}(`)
  assert.ok(start >= 0, name)
  const end = html.indexOf('\n    function ', start + 1)
  return html.slice(start, end)
}
const context = vm.createContext({
  normalizeText: value => String(value).toLowerCase(),
  formatQuantityValue: (qty, unit) => `${qty} ${unit}`,
  autoLoadManualOverrides: new Map(),
  autoLoadRows: [],
})
for (const name of ['limitAutoLoadToWarehouse','getAutoLoadApprovedPackageCount','normalizeAutoLoadApprovedQuantity','applyAutoLoadManualQuantity','syncAutoLoadApprovedInput']) {
  vm.runInContext(extract(name), context)
}
const plan = (planned, required, stock, unit='ks') => JSON.parse(JSON.stringify(context.limitAutoLoadToWarehouse({base_unit:unit}, planned, required, stock)))
assert.deepEqual(plan(24,10,14), {quantity:24,shortage:10}, 'Full request survives insufficient recorded stock')
assert.deepEqual(plan(24,10,24), {quantity:24,shortage:0}, 'prefer a full package when available')
assert.deepEqual(plan(24,10,6), {quantity:24,shortage:18}, 'preserve requested packages and show shortage')
assert.deepEqual(plan(48,28,30), {quantity:48,shortage:18}, 'preserve full request')
assert.deepEqual(plan(24,10,0), {quantity:24,shortage:24})
assert.deepEqual(plan(24,10,-3), {quantity:24,shortage:24})
assert.deepEqual(plan(0,0,14), {quantity:0,shortage:0}, 'do not create demand')
assert.deepEqual(plan(24,10,6.5), {quantity:24,shortage:18}, 'no fractional pieces')
assert.deepEqual(plan(10,2.5,3,'kg'), {quantity:10,shortage:7}, 'preserve base units')
const row = {product:{id:39,name:'Corny',base_unit:'ks'},packageQty:24,warehouseQty:14,warehouseWholePackageQty:0,autoSuggestedQty:10,approvedQty:10,reasons:[]}
context.autoLoadRows.push(row)
const input = value => ({dataset:{productId:'39'},value})
assert.equal(context.syncAutoLoadApprovedInput(input('10')).quantity,10, 'save accepts loose automatic suggestion')
assert.equal(row.approvedPackageCount,0)
assert.equal(context.syncAutoLoadApprovedInput(input('15')).quantity,15, 'manual request may exceed recorded stock')
context.syncAutoLoadApprovedInput(input('10'))
assert.throws(() => context.syncAutoLoadApprovedInput(input('1.5')), /celé kusy/)
assert.throws(() => context.syncAutoLoadApprovedInput(input('-1')), /kladné/)
// Execute the actual request serialization: loose quantities must not become packages.
const start = html.indexOf('const itemRows = rows.map((row) => {')
const end = html.indexOf('\n      const { data: createdDocument', start)
context.rows = [{...row,package:{package_name:'karton'},expectedDemand:10,currentVehicleQty:0,usageRatio:1}]
vm.runInContext(html.slice(start,end)+'\nglobalThis.payload = itemRows',context)
assert.equal(context.payload[0].unit,'ks')
assert.equal(context.payload[0].requested_quantity,10)
assert.equal(context.payload[0].prepared_quantity,10)
assert.match(context.payload[0].note,/10 ks/)
console.log('OK: loose stock recommendation, shortages, validation and request units')
