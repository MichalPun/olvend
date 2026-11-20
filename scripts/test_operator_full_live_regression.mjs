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
assert.ok(mobile.includes('luce\\s*x2|jetinno|bianchi|fas'))
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
assert.match(worker, /olvend-operator-v56-full-live-regression/)
assert.ok(existsSync(new URL('../assets/product-images/200001.png', import.meta.url)))

console.log('PASS: ostrý operátorský tok chrání živá data, fotky, vozidlo, ukazatele a jednotky zásob')
