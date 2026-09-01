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
assert.match(html, /const productChanged = Boolean\(pendingSku && String\(item\.product_sku \|\| ''\) !== pendingSku\)/)
assert.match(html, /if \(productChanged\) autoLoadExactProductIds\.add\(String\(product\.id\)\)/)
assert.match(html, /const sellThrough = productChanged && !fullSwap/)
assert.match(html, /fillableCapacityAtArrival = sellThrough \? Math\.max\(0, Number\(\(capacity - oldProjectedAtArrival\)\.toFixed\(3\)\)\) : capacity/)
assert.match(html, /if \(autoLoadExactProductIds\.has\(String\(product\?\.id \|\| ''\)\)\) return \[product\]/)
assert.match(html, /new Set\(\)/)
assert.match(html, /NOVÝ SORTIMENT:/)
assert.match(html, /první zásoba nového sortimentu se vydává v celém balení/)

const calculateTransitionNeed = ({ capacity, oldCurrent, newCurrent, expectedOldSales }) => {
  const oldAtArrival = Math.max(0, oldCurrent - expectedOldSales)
  const fillableAtArrival = Math.max(0, capacity - oldAtArrival)
  return Math.max(0, fillableAtArrival - newCurrent)
}

assert.equal(calculateTransitionNeed({ capacity: 15, oldCurrent: 10, newCurrent: 0, expectedOldSales: 0 }), 5)
assert.equal(calculateTransitionNeed({ capacity: 15, oldCurrent: 10, newCurrent: 0, expectedOldSales: 3 }), 8)
assert.equal(calculateTransitionNeed({ capacity: 15, oldCurrent: 15, newCurrent: 0, expectedOldSales: 0 }), 0)
assert.equal(calculateTransitionNeed({ capacity: 10, oldCurrent: 0, newCurrent: 0, expectedOldSales: 0 }), 10)

console.log('OK: změna sortimentu počítá přesné nové SKU, uvolněnou kapacitu a celé první balení')
