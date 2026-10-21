/**
 * Persistence and serialization boundary for food-machine visits.
 *
 * It contains no DOM access and no implicit application state. The mobile
 * controller supplies the current slot drafts and applies the returned rows.
 */

export function serializeFoodPreparation({ slots = [], getDraft }) {
  if (typeof getDraft !== 'function') throw new Error('Čtení rozpracovaných pozic není dostupné.')
  return Object.fromEntries(slots.map((slot) => {
    const draft = getDraft(slot)
    return [String(slot.id), {
      selectedProductId: draft.selectedProductId || null,
      fillItems: draft.fillItems.map((fill) => ({
        productId: fill.productId || null,
        quantity: draft.skipped ? 0 : Math.max(0, Number(fill.quantity || 0)),
        batchId: fill.batchId || null,
        expiryDate: fill.expiryDate || ''
      })),
      preparedQuantity: draft.skipped ? 0 : Math.max(0, Number(draft.preparedQuantity || draft.pickedQuantity || 0)),
      basePreparedQuantity: draft.skipped ? 0 : Math.max(0, Number(draft.basePreparedQuantity || 0)),
      extraVehicleQuantity: draft.skipped ? 0 : Math.max(0, Number(draft.extraVehicleQuantity || 0)),
      picked: Boolean(draft.picked),
      skipped: Boolean(draft.skipped),
      skipReason: draft.skipReason || '',
      notInsertedReason: draft.notInsertedReason || '',
      capacityUnits: Math.max(1, Math.round(Number(draft.capacityUnits ?? slot.capacity_units ?? 1))),
      actualBefore: Math.max(0, Number(draft.actualBefore || 0)),
      actualAdd: draft.skipped ? 0 : Math.max(0, Number(draft.fillItems.reduce((sum, fill) => sum + Number(fill.quantity || 0), 0))),
      wasteItems: draft.wasteItems.map((item) => ({
        quantity: Math.max(0, Number(item.quantity || 0)),
        reason: item.reason || '',
        autoSuggested: Boolean(item.autoSuggested)
      })),
      existingExpiryDate: draft.existingExpiryDate || '',
      assortmentMismatch: Boolean(draft.assortmentMismatch),
      existingProductId: draft.existingProductId || null,
      expiryVerified: Boolean(draft.expiryVerified),
      transferQuantity: Math.max(0, Number(draft.transferQuantity || 0)),
      transferRecommendation: draft.transferRecommendation || null,
      manualProductChoice: Boolean(draft.manualProductChoice),
      pickConfirmed: Boolean(draft.pickConfirmed),
      operatorProposedPrice: draft.operatorProposedPrice === '' ? null : Number(draft.operatorProposedPrice),
      operatorPriceNote: draft.operatorPriceNote || '',
      operatorPriceConfirmed: Boolean(draft.operatorPriceConfirmed),
      operatorPriceRequestStatus: draft.operatorPriceRequestStatus || '',
      operatorPriceRequestId: draft.operatorPriceRequestId || null,
      operatorPriceClientKey: draft.operatorPriceClientKey || '',
      operatorPriceMailWarning: draft.operatorPriceMailWarning || '',
      deferFullSwap: Boolean(draft.deferFullSwap),
      cartLoadOrder: Math.max(0, Number(draft.cartLoadOrder || 0)),
      note: draft.note || ''
    }]
  }))
}

export async function saveFoodProgressRecord({
  client,
  visitId,
  workPhase,
  preparation,
  syncedAt = new Date().toISOString()
}) {
  if (!client?.from) throw new Error('Databázové připojení pro uložení potravinové návštěvy není dostupné.')
  if (!visitId) throw new Error('Návštěva potravinového automatu není připravená.')
  const { error } = await client
    .from('route_machine_visits')
    .update({ work_phase: workPhase, food_preparation: preparation, synced_at: syncedAt })
    .eq('id', visitId)
  if (error) throw error
  return { workPhase, preparation }
}

export function hasPersistedFoodVisitItemId(value) {
  return /^\d+$/.test(String(value || ''))
}

export async function persistFoodVisitItem({ client, row, existing = null, online = true }) {
  if (!client?.from) throw new Error('Databázové připojení pro uložení pozice není dostupné.')
  if (!row?.visit_id || !row?.planogram_slot_id) throw new Error('Záznam pozice není úplný.')

  let persisted = existing
  if ((!persisted?.id || !hasPersistedFoodVisitItemId(persisted.id)) && online) {
    const lookup = await client
      .from('route_machine_visit_items')
      .select('*')
      .eq('visit_id', row.visit_id)
      .eq('planogram_slot_id', row.planogram_slot_id)
      .order('id', { ascending: false })
      .limit(1)
      .maybeSingle()
    if (lookup.error) throw lookup.error
    persisted = lookup.data || null
  }

  const result = persisted?.id && hasPersistedFoodVisitItemId(persisted.id)
    ? await client.from('route_machine_visit_items').update(row).eq('id', Number(persisted.id)).select('*').single()
    : await client.from('route_machine_visit_items').insert([row]).select('*').single()
  if (result.error) throw result.error
  if (!result.data?.id) throw new Error('Server nepotvrdil uložení pozice automatu.')
  return { savedRow: result.data, previousRow: persisted }
}
