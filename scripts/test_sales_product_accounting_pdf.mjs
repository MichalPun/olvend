import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { runInNewContext } from 'node:vm'

const html = readFileSync(new URL('../report-telemetry.html', import.meta.url), 'utf8')
const start = html.indexOf('    function productPdfTotals(')
const end = html.indexOf('    function drawPdfBrandBar(', start)
assert(start >= 0 && end > start, 'PDF grouping helpers are missing')

const context = {}
runInNewContext(`${html.slice(start, end)}\nthis.productPdfTotals=productPdfTotals;this.productPdfGroups=productPdfGroups;`, context)

const rows = [
  { label:'Čokoláda', sku:'CHOCO', typeLabel:'Teplé nápoje', quantity:10, revenue:200, cash:50, cashless:140, unknown:10 },
  { label:'Káva', sku:'COFFEE', typeLabel:'Teplé nápoje', quantity:5, revenue:150, cash:40, cashless:110, unknown:0 },
  { label:'Voda', sku:'WATER', typeLabel:'Vody', quantity:3, revenue:90, cash:30, cashless:60, unknown:0 }
]

assert.deepEqual(
  JSON.parse(JSON.stringify(context.productPdfTotals(rows))),
  { quantity:18, revenue:440, cash:120, cashless:310, unknown:10 }
)

const groups = context.productPdfGroups(rows)
assert.equal(groups.length, 2)
assert.equal(groups[0].label, 'Teplé nápoje')
assert.equal(groups[0].rows.length, 2)
assert.equal(groups[0].totals.revenue, 350)
assert.equal(groups[1].label, 'Vody')
assert.equal(groups[1].totals.quantity, 3)

for (const requiredText of [
  'Souhrn podle skupin',
  'Kontrola plateb:',
  'Mezisoučet · ${group.label}',
  'Tržby jsou uvedené včetně DPH',
  'Strana ${page} z ${pageCount}'
]) assert(html.includes(requiredText), `Missing accounting PDF element: ${requiredText}`)

console.log('Sales-product PDF: category grouping, totals, payment reconciliation and page numbering passed.')
