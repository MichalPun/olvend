import assert from 'node:assert/strict'
import { aggregateProductRows, periodFromMonth, previousMonthPeriod, reportGroups, reportTotals, zonedMidnightUtc } from '../backend/supabase/functions/send-monthly-accounting-report/report-core.mjs'

const products = [
  { sku:'KAVA-1', name:'Staccato 0,5 kg Enzo Bencini', product_category:'ingredient', active:true },
  { sku:'FIRST', name:'FIRST 0,5 l', product_category:'beverage_ready', active:true },
]
const rows = [
  { id:1, provider:'ima', machine_id:1, selection_code:'1', product_sku:'KAVA-1', product_name:'Sophia', quantity:2, total_amount_czk:60, cash_amount_czk:30, cashless_amount_czk:30, unknown_payment_amount_czk:0, source_event_at:'2026-09-10T10:00:00Z' },
  { id:2, provider:'vendsoft', machine_id:1, selection_code:'1', product_sku:'KAVA-1', product_name:'Sophia', quantity:2, total_amount_czk:60, cash_amount_czk:30, cashless_amount_czk:30, unknown_payment_amount_czk:0, source_event_at:'2026-09-10T10:05:00Z' },
  { id:3, provider:'ima', machine_id:2, selection_code:'4', product_sku:'FIRST', product_name:'FIRST NEW', quantity:1, total_amount_czk:40, cash_amount_czk:0, cashless_amount_czk:40, unknown_payment_amount_czk:0, source_event_at:'2026-09-11T10:00:00Z' },
]

const aggregate = aggregateProductRows(rows, products)
assert.equal(aggregate.length, 2, 'VendSoft duplicita nesmí navýšit export')
assert.equal(aggregate.find((row) => row.sku === 'KAVA-1').label, 'Staccato 0,5 kg Enzo Bencini')
assert.equal(reportGroups(aggregate).length, 2)
assert.deepEqual(reportTotals(aggregate), { quantity:3, revenue:100, cash:30, cashless:70, unknown:0 })
assert.deepEqual(previousMonthPeriod(new Date('2026-10-27T10:00:00Z')), periodFromMonth('2026-09'))
assert.equal(zonedMidnightUtc('2026-09-01'), '2026-08-31T22:00:00.000Z')
assert.equal(zonedMidnightUtc('2026-11-01'), '2026-10-31T23:00:00.000Z')

console.log('Monthly accounting report: products, deduplication, grouping, totals, period and Prague boundaries passed.')
