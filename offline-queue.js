// Offline writes are causally ordered: visit items must reach the server
// before the later request that closes the visit. After the first failure we
// keep that request and every following request for the next sync attempt.
export async function processOfflineQueueInOrder(queue, send) {
  const items = Array.isArray(queue) ? queue : []
  let synced = 0

  for (let index = 0; index < items.length; index += 1) {
    let ok = false
    try {
      ok = await send(items[index])
    } catch (_) {
      ok = false
    }
    if (!ok) return { remaining: items.slice(index), synced }
    synced += 1
  }

  return { remaining: [], synced }
}
