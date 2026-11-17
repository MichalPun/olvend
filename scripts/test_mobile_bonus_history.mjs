import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

const source = readFileSync(new URL('../mobile-personal-zone.js', import.meta.url), 'utf8')
const mobile = readFileSync(new URL('../mobile.html', import.meta.url), 'utf8')

assert.match(source, /Number\.isNaN\(date\.getTime\(\)\)/)
assert.match(source, /rows\.push\(\{ \.\.\.data, period \}\)/)
assert.doesNotMatch(source, /rows\.push\(\{ period, \.\.\.data \}\)/)
assert.match(mobile, /mobile-personal-zone\.js\?v=20261117-bonus-history-v1/)

const requestedPeriod = new Date(2026, 10, 1)
const rpcData = { period: '2026-11-01', total: 1250 }
const historyRow = { ...rpcData, period: requestedPeriod }

assert.equal(historyRow.period, requestedPeriod)
assert.equal(historyRow.total, 1250)
assert.equal(Number.isNaN(historyRow.period.getTime()), false)

console.log('Mobile bonus history checks passed')
