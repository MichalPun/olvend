/**
 * Durable route-visit completion boundary.
 *
 * This module deliberately contains no DOM or global application state. The
 * mobile controller supplies the current visit detail and the concrete save
 * callback; this layer makes sure every confirmed stock position exists on the
 * server before the visit itself can be closed.
 */

export function hasAcceptedCoffeeContainerState(detail, container) {
  return (detail?.visitItems || []).some((item) => (
    item.item_kind === 'coffee_container'
    && String(item.coffee_container_id || '') === String(container?.id || '')
    && item.accepted_at
    && (
      item.final_quantity != null
      || (
        item.issue_type === 'missing_stock'
        && Number(item.actual_add_quantity || 0) === 0
        && String(item.operator_note || '').trim().length >= 10
      )
    )
  ))
}

export function getMissingCoffeeContainerStates(detail) {
  return (detail?.containers || []).filter((container) => (
    !hasAcceptedCoffeeContainerState(detail, container)
  ))
}

export async function persistUnchangedCoffeeContainerStates({ detail, saveContainerState }) {
  if (!detail?.visitId) throw new Error('Návštěva kávového automatu není připravená.')
  if (typeof saveContainerState !== 'function') throw new Error('Ukládání stavu zásobníků není dostupné.')

  const missing = getMissingCoffeeContainerStates(detail)
  if (detail.needsCalibration && missing.length) {
    throw new Error('První načtení automatu není dokončené. Fyzicky potvrď stav každého zásobníku.')
  }
  for (const container of missing) {
    const current = Math.max(0, Number(container.current_quantity || 0))
    await saveContainerState(container, {
      actual_before_quantity: current,
      final_quantity: current,
      issue_type: 'none',
      operator_note: 'Hromadně potvrzeno při dokončení: fyzický stav zásobníku souhlasí, bez dalšího doplnění.'
    })
  }
  return missing.length
}

export async function completeRouteVisitRecord({ client, visitId, completedAt, getPendingRequestCount }) {
  if (!client?.from) throw new Error('Databázové připojení pro dokončení návštěvy není dostupné.')
  if (!visitId) throw new Error('Návštěva automatu není připravená.')
  if (typeof getPendingRequestCount !== 'function') throw new Error('Offline synchronizace návštěvy není dostupná.')

  const pendingBeforeCompletion = getPendingRequestCount()
  const visitResult = await client
    .from('route_machine_visits')
    .update({ status: 'completed', completed_at: completedAt, synced_at: completedAt })
    .eq('id', visitId)
    .select('id, status, completed_at, synced_at')
    .maybeSingle()

  const completionQueued = getPendingRequestCount() > pendingBeforeCompletion
  if (visitResult.error && !completionQueued) throw visitResult.error
  if (!completionQueued && (
    String(visitResult.data?.id || '') !== String(visitId)
    || visitResult.data?.status !== 'completed'
    || !visitResult.data?.completed_at
  )) {
    throw new Error('Server nepotvrdil dokončení návštěvy. Automat zůstává otevřený; obnov připojení a zkus to znovu.')
  }

  return { completionQueued, visit: visitResult.data || null }
}
