import assert from 'node:assert/strict'
import { processOfflineQueueInOrder } from '../offline-queue.js'

const calls = []
const queue = [{ id: 'item-1' }, { id: 'item-2' }, { id: 'complete-visit' }]
const failed = await processOfflineQueueInOrder(queue, async (item) => {
  calls.push(item.id)
  return item.id !== 'item-2'
})

assert.deepEqual(calls, ['item-1', 'item-2'])
assert.equal(failed.synced, 1)
assert.deepEqual(failed.remaining.map((item) => item.id), ['item-2', 'complete-visit'])

const retryCalls = []
const retried = await processOfflineQueueInOrder(failed.remaining, async (item) => {
  retryCalls.push(item.id)
  return true
})
assert.deepEqual(retryCalls, ['item-2', 'complete-visit'])
assert.equal(retried.synced, 2)
assert.deepEqual(retried.remaining, [])

const thrown = await processOfflineQueueInOrder(queue, async (item) => {
  if (item.id === 'item-2') throw new Error('network')
  return true
})
assert.equal(thrown.synced, 1)
assert.deepEqual(thrown.remaining.map((item) => item.id), ['item-2', 'complete-visit'])

console.log('PASS: offline queue preserves causal order after a failed write')
