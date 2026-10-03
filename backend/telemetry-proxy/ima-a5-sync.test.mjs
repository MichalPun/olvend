import test from 'node:test'
import assert from 'node:assert/strict'
import { normalizeSelection, parseCzechMoney, pragueIso, sanitizeRows } from './ima-a5-sync.mjs'

test('normalizes the A5 technical vend bit', () => {
  assert.equal(normalizeSelection('32792'), '24')
  assert.equal(normalizeSelection('24'), '24')
})

test('parses Czech prices', () => {
  assert.equal(parseCzechMoney('50,00'), 50)
  assert.equal(parseCzechMoney('1 234,50'), 1234.5)
})

test('converts Prague wall clock to UTC', () => {
  assert.equal(pragueIso('2.10.2026 14:53:56'), '2026-10-02T12:53:56.000Z')
})

test('keeps only safe allowed unique transactions', () => {
  const input = [{
    transactionId: '4368057', occurredAt: '2.10.2026 14:55:27', deviceUid: '635457',
    deviceAcronym: '635457', selection: '32792', unitPrice: '17,00', quantity: 1,
    productName: '', cardNumber: 'must-not-survive', personalNumber: 'must-not-survive'
  }]
  const result = sanitizeRows([...input, ...input])
  assert.equal(result.length, 1)
  assert.deepEqual(Object.keys(result[0]).sort(), [
    'deviceAcronym', 'deviceUid', 'occurredAt', 'productName', 'quantity',
    'selection', 'transactionId', 'unitPrice'
  ])
  assert.equal(result[0].selection, '24')
})
