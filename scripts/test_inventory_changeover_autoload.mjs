import assert from 'node:assert/strict'
import fs from 'node:fs'
import vm from 'node:vm'

const html = fs.readFileSync(new URL('../inventory.html', import.meta.url), 'utf8')

for (const match of html.matchAll(/<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)<\/script>/gi)) {
  if (!match[1].trim()) continue
  if (/^\s*import\s/m.test(match[1])) new vm.SourceTextModule(match[1], { identifier: 'inventory.html' })
  else new vm.Script(match[1], { filename: 'inventory.html' })
}

assert.match(html, /changeover_old_units, changeover_new_units, active/)
assert.match(html, /min_refill_quantity/)
assert.match(html, /Math\.max\(\s*Number\(\(capacity \* criticalPercent \/ 100\)/)
assert.match(html, /autoLoadCoffeeProductIds\.has\(String\(product\.id\)\)/)
assert.match(html, /convertRecipeQuantityToBase\(2, 'kg'/)
assert.match(html, /coffeeSafetyOverride/)
assert.match(html, /na autě zůstává minimálně 2 kg/)
assert.match(html, /calculation_snapshot: calculationSnapshot/)
assert.match(html, /rows: autoLoadRows\.map/)
assert.match(html, /const productChanged = Boolean\(pendingSku && String\(item\.product_sku \|\| ''\) !== pendingSku\)/)
assert.match(html, /if \(productChanged\) autoLoadExactProductIds\.add\(String\(product\.id\)\)/)
assert.match(html, /const sellThrough = productChanged && !fullSwap/)
assert.match(html, /oldVehicleRemainingByProduct/)
assert.match(html, /Zasoba jineho vozidla se sem nikdy/)
assert.match(html, /fillableCapacityAtArrival = sellThrough \? Math\.max\(0, Number\(\(capacity - oldProjectedAtArrival - oldVehicleAllocated\)\.toFixed\(3\)\)\) : capacity/)
assert.match(html, /if \(autoLoadExactProductIds\.has\(String\(product\?\.id \|\| ''\)\)\) return \[product\]/)
assert.match(html, /new Set\(\)/)
assert.match(html, /NOVÝ SORTIMENT:/)
assert.match(html, /první zásoba nového sortimentu se vydává v celém balení/)
assert.match(html, /původního zboží pokryje stejné auto/)
assert.match(html, /picking_extra_machine_ids/)
assert.match(html, /getAutoLoadPreferredWarehouseProduct/)
assert.match(html, /wholePackageQuantity/)
assert.match(html, /Lemon -12 ks versus Peach \+36 ks/)
assert.match(html, /productName\.includes\('kelimek'\)/)
assert.match(html, /if \(stickPackage\) return stickPackage/)

const cupSafetyMigration = fs.readFileSync(new URL('../database/coffee_vehicle_cup_safety_stock_v47.sql', import.meta.url), 'utf8')
assert.match(cupSafetyMigration, /safety_stock_quantity/)
assert.match(cupSafetyMigration, /50/)
assert.match(cupSafetyMigration, /units_per_package = 50/)

const calculateTransitionNeed = ({ capacity, oldCurrent, oldVehicle = 0, newCurrent, expectedOldSales }) => {
  const oldAtArrival = Math.max(0, oldCurrent - expectedOldSales)
  const oldVehicleAllocated = Math.min(oldVehicle, Math.max(0, capacity - oldAtArrival - newCurrent))
  const fillableAtArrival = Math.max(0, capacity - oldAtArrival - oldVehicleAllocated)
  return Math.max(0, fillableAtArrival - newCurrent)
}

assert.equal(calculateTransitionNeed({ capacity: 15, oldCurrent: 10, newCurrent: 0, expectedOldSales: 0 }), 5)
assert.equal(calculateTransitionNeed({ capacity: 15, oldCurrent: 10, newCurrent: 0, expectedOldSales: 3 }), 8)
assert.equal(calculateTransitionNeed({ capacity: 15, oldCurrent: 15, newCurrent: 0, expectedOldSales: 0 }), 0)
assert.equal(calculateTransitionNeed({ capacity: 10, oldCurrent: 0, newCurrent: 0, expectedOldSales: 0 }), 10)
assert.equal(calculateTransitionNeed({ capacity: 10, oldCurrent: 0, oldVehicle: 6, newCurrent: 0, expectedOldSales: 0 }), 4)
assert.equal(calculateTransitionNeed({ capacity: 10, oldCurrent: 0, oldVehicle: 12, newCurrent: 0, expectedOldSales: 0 }), 0)

console.log('OK: změna sortimentu počítá přesné nové SKU, uvolněnou kapacitu a celé první balení')
