/**
 * Persistence boundary for coffee-machine visits.
 *
 * The module is intentionally independent of the DOM and of the mobile
 * controller's global state. It owns the durable shape of coffee preparation
 * snapshots and the online/offline persistence rules for container records.
 */

export function serializeCoffeePreparation(
  detail,
  phase = detail?.machineOpen ? 'machine' : 'picklist',
  savedAt = new Date().toISOString()
) {
  return {
    version: 2,
    phase,
    containers: { ...(detail?.draft?.containers || {}) },
    picklistStep: detail?.draft?.picklistStep || 'stock',
    gearChecks: { ...(detail?.draft?.gearChecks || {}) },
    qualityOutcomes: { ...(detail?.draft?.qualityOutcomes || {}) },
    qualityProblemReasons: { ...(detail?.draft?.qualityProblemReasons || {}) },
    savedAt
  }
}

export async function saveCoffeePreparationRecord({
  client,
  visitId,
  preparation,
  syncedAt = new Date().toISOString(),
  online = true
}) {
  if (!visitId) throw new Error('Návštěva kávového automatu není připravená.')
  if (!online) return { saved: false, queuedOffline: true, visit: null, error: null }
  if (!client?.from) throw new Error('Databázové připojení pro uložení přípravy není dostupné.')

  const { data, error } = await client
    .from('route_machine_visits')
    .update({ coffee_preparation: preparation, synced_at: syncedAt })
    .eq('id', visitId)
    .select('id, coffee_preparation')
    .maybeSingle()

  return {
    saved: !error && String(data?.id || '') === String(visitId),
    queuedOffline: false,
    visit: data || null,
    error: error || null
  }
}

export async function persistCoffeeVisitItem({
  client,
  row,
  existing = null,
  offline = false,
  fallbackId,
  createUuid = () => globalThis.crypto.randomUUID(),
  getPendingRequestCount
}) {
  if (!client?.from) throw new Error('Databázové připojení pro uložení zásobníku není dostupné.')
  if (!row?.visit_id || !row?.coffee_container_id) throw new Error('Záznam zásobníku není úplný.')
  if (typeof getPendingRequestCount !== 'function') throw new Error('Offline synchronizace zásobníku není dostupná.')

  const pendingBeforeSave = getPendingRequestCount()
  let result

  if (existing?.client_uuid && (existing._offlinePending || String(existing.id || '').startsWith('offline-'))) {
    const offlineRow = { ...row, client_uuid: existing.client_uuid }
    const queuedResult = await client
      .from('route_machine_visit_items')
      .upsert([offlineRow], { onConflict: 'client_uuid' })
    result = {
      error: queuedResult.error,
      data: { ...offlineRow, id: existing.id, _offlinePending: true }
    }
  } else if (existing?.id) {
    result = await client
      .from('route_machine_visit_items')
      .update(row)
      .eq('id', existing.id)
      .select('*')
      .single()
  } else if (offline) {
    const clientUuid = createUuid()
    const offlineRow = { ...row, client_uuid: clientUuid }
    const queuedResult = await client
      .from('route_machine_visit_items')
      .upsert([offlineRow], { onConflict: 'client_uuid' })
    result = {
      error: queuedResult.error,
      data: { ...offlineRow, id: `offline-${clientUuid}`, _offlinePending: true }
    }
  } else {
    result = await client
      .from('route_machine_visit_items')
      .insert([row])
      .select('*')
      .single()
  }

  const requestQueued = getPendingRequestCount() > pendingBeforeSave
  if (result.error && !requestQueued) throw result.error

  const savedRow = result.data?.id
    ? { ...result.data, _offlinePending: requestQueued }
    : { ...row, id: existing?.id || fallbackId, _offlinePending: requestQueued }

  return { savedRow, requestQueued }
}
