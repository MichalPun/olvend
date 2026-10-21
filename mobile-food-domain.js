/**
 * Demand and route-allocation rules for food machines.
 *
 * External business rules are injected so this module can be exercised with
 * plain data. It does not read the DOM, application globals or the database.
 */
export function createFoodDomain({
  getPlanogramChange,
  isExpiryExpired,
  getTransferReservedByBatch
}) {
  function getFoodPlanningSlot(slot, detail) {
    const draft = detail?.draft?.slots?.[String(slot?.id)]
    if (!draft || draft.accepted) return slot
    return {
      ...slot,
      current_units: draft.actualBefore ?? slot.current_units,
      capacity_units: draft.capacityUnits ?? slot.capacity_units,
      expiry_date: draft.existingExpiryDate ?? slot.expiry_date
    }
  }

  function getFoodDailySales(detail, slot, productSku = null) {
    const context = detail?.routePlanningContext
    if (!context?.loaded) return null
    const sku = productSku || slot?.product_sku || ''
    return Math.max(0, Number(context.sold28ByMachineSku.get(`${slot?.machine_id}:${sku}`) || 0) / 28)
  }

  function getFoodDemandTargetQuantity(slot, detail = null, productSku = null) {
    const capacity = Math.max(0, Number(slot?.capacity_units || 0))
    if (!capacity) return 0
    const configuredTarget = Number(slot?.target_units)
    const hardTarget = Number.isFinite(configuredTarget) && configuredTarget > 0
      ? Math.min(capacity, configuredTarget)
      : capacity
    if (slot?.replenishment_mode === 'fill_to_capacity') return capacity
    if (hardTarget < capacity && slot?.replenishment_mode !== 'sales_based') return hardTarget
    const dailySales = getFoodDailySales(detail, slot, productSku)
    if (dailySales == null) return hardTarget
    if (dailySales <= 0.001) return Math.min(hardTarget, 1)
    const weeklyDemand = Math.max(1, Math.ceil(dailySales * 7))
    const demandTarget = dailySales < 0.5 ? Math.max(2, weeklyDemand) : Math.ceil(weeklyDemand * 1.2)
    return Math.max(1, Math.min(hardTarget, demandTarget))
  }

  function getFoodRequiredFillQuantity(slot, detail = null) {
    slot = getFoodPlanningSlot(slot, detail)
    const storedSuggestion = Math.max(0, Number(slot?.desired_units || 0))
    const planogramChange = getPlanogramChange(slot)
    if (planogramChange?.fullSwap) {
      const capacity = Math.max(0, Number(slot?.target_units ?? slot?.capacity_units ?? 0))
      const replacementAlreadyInside = Math.max(0, Math.min(capacity, Number(slot?.changeover_new_units || 0)))
      return Math.max(0, Math.round(capacity - replacementAlreadyInside))
    }
    if (detail?.manualStockMode) return storedSuggestion
    const capacity = Number(slot?.capacity_units)
    const recordedCurrent = Math.max(0, Number(slot?.current_units || 0))
    const current = isExpiryExpired(slot?.expiry_date) ? 0 : recordedCurrent
    if (!Number.isFinite(capacity) || capacity <= 0) return storedSuggestion
    const freeCapacity = Math.max(0, Math.round(capacity - Math.min(capacity, current)))
    const target = getFoodDemandTargetQuantity(slot, detail)
    const targetNeed = Math.max(0, Math.round(target - Math.min(target, current)))
    const demandAware = Boolean(detail?.routePlanningContext?.loaded)
    return Math.min(freeCapacity, demandAware ? freeCapacity : Math.max(Math.round(storedSuggestion), targetNeed))
  }

  function getFoodRouteAllocatedQuantity(detail, stopId, slot, product, localDesired) {
    const requested = Math.max(0, Math.round(Number(localDesired || 0)))
    const context = detail?.routePlanningContext
    if (!requested || !context?.loaded || !product?.id || getPlanogramChange(slot)?.fullSwap) return requested
    const sku = String(product.sku || slot?.product_sku || '')
    const candidates = context.routeSlots
      .map((candidate) => getFoodPlanningSlot(candidate, detail))
      .filter((candidate) => String(candidate.product_sku || '') === sku || String(candidate.id) === String(slot?.id))
      .map((candidate) => {
        const current = isExpiryExpired(candidate.expiry_date) ? 0 : Math.max(0, Number(candidate.current_units || 0))
        const capacity = Math.max(0, Number(candidate.capacity_units || 0))
        const target = getFoodDemandTargetQuantity(candidate, detail, sku)
        return {
          slot: candidate,
          current,
          capacity,
          target,
          need: Math.max(0, Math.round(target - Math.min(target, current))),
          free: Math.max(0, Math.round(capacity - Math.min(capacity, current))),
          dailySales: getFoodDailySales(detail, candidate, sku) || 0,
          order: Number(context.stopOrderByMachine.get(String(candidate.machine_id)) ?? Number.MAX_SAFE_INTEGER),
          allocated: 0
        }
      })
      .filter((candidate) => candidate.free > 0)
    if (!candidates.length) return requested

    const reservedByBatch = getTransferReservedByBatch(detail, stopId, product.id)
    const stockBatches = detail?.vehicleBatches?.[String(product.id)] || []
    let remaining = stockBatches.length
      ? stockBatches.reduce((sum, batch) => sum + Math.max(0, Number(batch.quantity_on_hand || 0) - Number(reservedByBatch.get(String(batch.batch_id || 'none')) || 0)), 0)
      : Math.max(0, Math.floor(Number(detail?.vehicleStock?.[String(product.id)] || 0)))
    remaining = Math.max(0, Math.floor(remaining))
    if (!remaining) return 0

    const empty = candidates
      .filter((candidate) => candidate.current <= 0)
      .sort((a, b) => a.order - b.order || b.dailySales - a.dailySales)
    for (const candidate of empty) {
      if (remaining <= 0) break
      candidate.allocated += 1
      remaining -= 1
    }

    while (remaining > 0) {
      const next = candidates
        .filter((candidate) => candidate.allocated < Math.min(candidate.free, candidate.need))
        .sort((a, b) => ((a.current + a.allocated) / Math.max(0.1, a.dailySales || 0.1)) - ((b.current + b.allocated) / Math.max(0.1, b.dailySales || 0.1))
          || b.dailySales - a.dailySales
          || a.order - b.order)[0]
      if (!next) break
      next.allocated += 1
      remaining -= 1
    }

    const strongestFirst = [...candidates].sort((a, b) => b.dailySales - a.dailySales || a.order - b.order)
    for (const candidate of strongestFirst) {
      if (remaining <= 0) break
      const extra = Math.min(remaining, Math.max(0, candidate.free - candidate.allocated))
      candidate.allocated += extra
      remaining -= extra
    }
    const allocation = candidates.find((candidate) => String(candidate.slot.id) === String(slot.id))?.allocated
    return Math.max(0, Math.min(requested, Number(allocation ?? requested)))
  }

  return {
    getFoodDailySales,
    getFoodDemandTargetQuantity,
    getFoodPlanningSlot,
    getFoodRequiredFillQuantity,
    getFoodRouteAllocatedQuantity
  }
}
