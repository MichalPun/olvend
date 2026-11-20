import assert from 'node:assert/strict'
import { existsSync, readFileSync } from 'node:fs'

const mobile = readFileSync(new URL('../mobile.html', import.meta.url), 'utf8')
const coffee = readFileSync(new URL('../olvend-operator/index.html', import.meta.url), 'utf8')
const food = readFileSync(new URL('../olvend-operator/potravinovy-automat-preview.html', import.meta.url), 'utf8')
const route = readFileSync(new URL('../olvend-operator/operator-route.js', import.meta.url), 'utf8')
const warehouse = readFileSync(new URL('../olvend-operator/operator-warehouse.js', import.meta.url), 'utf8')
const vehicle = readFileSync(new URL('../olvend-operator/operator-vehicle.js', import.meta.url), 'utf8')
const dashboard = readFileSync(new URL('../olvend-operator/operator-dashboard-v1.js', import.meta.url), 'utf8')
const worker = readFileSync(new URL('../olvend-operator/sw-v44.js', import.meta.url), 'utf8')

assert.match(mobile, /machine\?\.brand, machine\?\.model, machine\?\.name/)
const machineKindSource = mobile.match(/function getMachineKind\(machine\) \{[\s\S]*?\n    \}/)?.[0]
assert.ok(machineKindSource, 'getMachineKind must stay available in mobile.html')
const getMachineKind = Function(`return (${machineKindSource})`)()
assert.equal(getMachineKind({ machine_type: 'Snack', name: 'FAS 1050', brand: 'Rheavendors' }), 'food')
assert.equal(getMachineKind({ machine_type: 'Coffee', name: 'FAS 1050', brand: 'Rheavendors' }), 'coffee')
assert.equal(getMachineKind({ machine_type: 'Potravinový automat', name: 'FAS 1050' }), 'food')
assert.equal(getMachineKind({ machine_type: '', name: 'Luce X2', brand: 'Rheavendors' }), 'coffee')
assert.match(mobile, /vehicle: routeVehicle \? \{ id: routeVehicle\.id, name: routeVehicle\.name \|\| '', plate: routeVehicle\.plate \|\| '' \} : null/)
for (const name of ['nuget', 'porizek', 'debrecin', 'strips', 'svacink', 'hamka', 'mlska']) assert.match(mobile, new RegExp(`/${name}/`))

assert.match(coffee, /operator-live-pending/)
assert.match(coffee, /Načítám skutečný automat/)
assert.match(coffee, /data-shift-vehicle/)
assert.match(coffee, /snapshot\.vehicle/)
assert.match(coffee, /failLive/)

assert.match(food, /Není v autě · Opravit/)
assert.match(food, /data-shift-vehicle/)
assert.match(food, /photo\.addEventListener\('error'/)

assert.match(route, /Trasa zahájena v/)
assert.match(route, /locationCountLabel/)
assert.match(route, /machineCountLabel/)
assert.match(warehouse, /metric\('UPRAVENO',changed/)
assert.match(vehicle, /totals\[category\]\[unit\]/)
assert.match(vehicle, /alt="' \+ escapeHtml\(row\.product_name\)/)
assert.match(dashboard, /Math\.max\(number\(vehicle\.current_odometer_km\),Math\.round\(start\+plannedDriven\)\)/)
assert.match(dashboard, /group\.stops\.every/)
assert.match(vehicle, /estimatedVehicleOdometer\(\) - Number\(log\.start_odometer_km/)
assert.match(worker, /olvend-operator-v57-production-audit/)
assert.ok(existsSync(new URL('../assets/product-images/200001.png', import.meta.url)))
assert.ok(existsSync(new URL('../assets/product-images/265.jpg', import.meta.url)))

console.log('PASS: ostrý operátorský tok chrání živá data, fotky, vozidlo, ukazatele a jednotky zásob')
