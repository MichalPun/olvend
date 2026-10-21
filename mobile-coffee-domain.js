/**
 * Coffee-machine domain rules used by the mobile route controller.
 *
 * The factory receives all external data and unit helpers explicitly. This
 * keeps stock calculations, calibration and workflow decisions testable
 * without a browser, DOM or database connection.
 */
export function createCoffeeDomain({
  getDetail,
  getProducts,
  getProductPackages,
  normalizeText,
  convertQuantity,
  formatNumber
}) {
  const detailFor = (stopId) => getDetail(stopId)

  function isCoffeeCupProduct(container) {
    return /kelimek|kelímek|pohar|pohár|cup/.test(normalizeText(`${container?.product_name || ''} ${container?.product_sku || ''}`))
  }

  function isCoffeeLidProduct(container) {
    return /vicko|víčko|vicka|víčka|lid/.test(normalizeText(`${container?.product_name || ''} ${container?.product_sku || ''}`))
  }

  function getCoffeePackageNoun(packages, container) {
    const amount = Math.abs(Number(packages || 0))
    if (isCoffeeCupProduct(container) || isCoffeeLidProduct(container)) {
      if (amount === 1) return 'tyč'
      if (amount >= 2 && amount <= 4) return 'tyče'
      return 'tyčí'
    }
    return String(getCoffeeRefillPackage(container).label || 'balení').replace(/^1\s+/i, '')
  }

  function getCoffeeRefillPackage(container) {
    const configuredQuantity = Math.max(0, Number(container?.refill_package_quantity || 0))
    const configuredUnit = container?.refill_package_unit || container?.unit || ''
    const product = getProducts().find((item) => String(item.id) === String(container?.product_id || ''))
    const catalogPackage = getProductPackages().find((item) => (
      String(item.product_id) === String(container?.product_id || '')
      && item.active !== false
      && item.is_default === true
    ))
    const catalogQuantity = Math.max(0, Number(catalogPackage?.units_per_package || 0))
    const sameUnit = normalizeText(product?.base_unit || '') === normalizeText(container?.unit || '')
    const isStick = isCoffeeCupProduct(container) || isCoffeeLidProduct(container)
    if (catalogPackage && sameUnit && catalogQuantity > 1) {
      return {
        quantity: catalogQuantity,
        unit: container?.unit || product?.base_unit || configuredUnit,
        label: isStick ? 'tyč' : String(catalogPackage.package_name || 'balení').replace(/^1\s+/i, '')
      }
    }
    return {
      quantity: configuredQuantity || (isCoffeeCupProduct(container) ? 50 : isCoffeeLidProduct(container) ? 100 : 0),
      unit: configuredUnit,
      label: isStick ? 'tyč' : String(catalogPackage?.package_name || 'balení').replace(/^1\s+/i, '')
    }
  }

  function getCoffeeRefillPackageQuantity(container) {
    return getCoffeeRefillPackage(container).quantity
  }

  function getCoffeePackageCountLabel(packages, container) {
    return `${formatNumber(packages)} ${getCoffeePackageNoun(packages, container)}`
  }

  function getCoffeeVehiclePackageLabel(packages, container) {
    return `${formatNumber(packages)} ${getCoffeePackageNoun(packages, container)}`
  }

  function getCoffeeContainerSequence(container) {
    const configured = Number(container?.sort_order)
    if (Number.isFinite(configured)) return configured
    const codeNumber = Number(String(container?.container_code || '').match(/\d+(?:[.,]\d+)?/)?.[0]?.replace(',', '.'))
    return Number.isFinite(codeNumber) ? codeNumber : 9999
  }

  function getCoffeeContainersInBagOrder(detail, reverse = false) {
    const ordered = [...(detail?.containers || [])].sort((a, b) => getCoffeeContainerSequence(a) - getCoffeeContainerSequence(b))
    return reverse ? ordered.reverse() : ordered
  }

  function getCoffeeSuggestedPackages(container) {
    const capacity = Number(container?.capacity_quantity || 0)
    const current = Number(container?.current_quantity || 0)
    const packageQuantity = getCoffeeRefillPackageQuantity(container)
    if (!capacity || !packageQuantity) return 0
    return Math.floor(Math.max(0, capacity - current) / packageQuantity)
  }

  function getCoffeeActualBeforeQuantity(stopId, container) {
    const detail = detailFor(stopId)
    const draftValue = detail?.draft?.containers?.[String(container?.id)]?.actualBeforeQuantity
    if (draftValue != null && Number.isFinite(Number(draftValue))) return Math.max(0, Number(draftValue))
    const existing = detail?.visitItems?.find((item) => (
      String(item.coffee_container_id || '') === String(container?.id)
      && !String(item.operator_note || '').includes('První kalibrace')
    ))
    return Math.max(0, Number(existing?.actual_before_quantity ?? container?.current_quantity ?? 0))
  }

  function getCoffeeEntryUnit(container) {
    return normalizeText(container?.unit || '') === 'g' ? 'kg' : (container?.unit || 'ks')
  }

  function getCoffeeEntryQuantity(quantity, container) {
    return convertQuantity(Number(quantity || 0), container?.unit || '', getCoffeeEntryUnit(container))
  }

  function getCoffeeContainerQuantity(quantity, container) {
    return convertQuantity(Number(quantity || 0), getCoffeeEntryUnit(container), container?.unit || '')
  }

  function getCoffeeFillPercent(quantity, container) {
    const capacity = Number(container?.capacity_quantity || 0)
    if (!capacity) return 0
    return Math.max(0, Math.min(100, Math.round((Number(quantity || 0) / capacity) * 100)))
  }

  function getCoffeeCalibrationSliderStep(container) {
    if (normalizeText(container?.unit || '') === 'ks') return 1
    const capacity = Number(container?.capacity_quantity || 0)
    if (capacity >= 1000) return 10
    if (capacity >= 100) return 5
    return 1
  }

  function roundCoffeeCalibrationQuantity(value, container) {
    const step = getCoffeeCalibrationSliderStep(container)
    const capacity = Number(container?.capacity_quantity || 0)
    const rounded = Math.round(Number(value || 0) / step) * step
    return capacity ? Math.max(0, Math.min(capacity, rounded)) : Math.max(0, rounded)
  }

  function getCoffeeQuantityFromFillPercent(percent, container) {
    const capacity = Number(container?.capacity_quantity || 0)
    const boundedPercent = Math.max(0, Math.min(100, Number(percent || 0)))
    if (!capacity) return 0
    return roundCoffeeCalibrationQuantity(capacity * boundedPercent / 100, container)
  }

  function getCoffeeMaxPackages(stopId, container) {
    const capacity = Number(container?.capacity_quantity || 0)
    const detail = detailFor(stopId)
    const existing = detail?.visitItems?.find((item) => (
      String(item.coffee_container_id || '') === String(container.id)
      && !String(item.operator_note || '').includes('První kalibrace')
    ))
    const draftActualBefore = detail?.draft?.containers?.[String(container.id)]?.actualBeforeQuantity
    const current = draftActualBefore != null
      ? Number(draftActualBefore || 0)
      : Number(existing?.system_current_quantity ?? container?.current_quantity ?? 0)
    const packageQuantity = getCoffeeRefillPackageQuantity(container)
    if (!capacity || !packageQuantity) return Number.POSITIVE_INFINITY
    return Math.max(0, Math.floor(Math.max(0, capacity - current) / packageQuantity))
  }

  function isCoffeeMassPackageStock(container) {
    return ['kg', 'g'].includes(normalizeText(container?.refill_package_unit || container?.unit || ''))
  }

  function getProductBaseUnit(productId) {
    return getProducts().find((item) => String(item.id) === String(productId || ''))?.base_unit || ''
  }

  function convertCoffeeQuantityToProductBase(quantity, fromUnit, productId) {
    const productBaseUnit = getProductBaseUnit(productId)
    return convertQuantity(Number(quantity || 0), fromUnit, productBaseUnit || fromUnit)
  }

  function getCoffeePackageBaseQuantity(container) {
    return Math.max(0, convertCoffeeQuantityToProductBase(
      getCoffeeRefillPackageQuantity(container),
      getCoffeeRefillPackage(container).unit,
      container?.product_id
    ))
  }

  function getCoffeeVehiclePackageCount(container, vehicleQuantity) {
    const total = Number(vehicleQuantity || 0)
    if (isCoffeeMassPackageStock(container)) {
      const packageBaseQty = getCoffeePackageBaseQuantity(container)
      return packageBaseQty ? Math.max(0, Math.floor(total / packageBaseQty)) : Math.max(0, Math.floor(total))
    }
    const packageQty = getCoffeeRefillPackageQuantity(container)
    return packageQty ? Math.floor(total / packageQty) : Math.max(0, Math.floor(total))
  }

  function getCoffeeVehicleStockQuantity(container, packages) {
    return Math.max(0, Number(packages || 0)) * getCoffeePackageBaseQuantity(container)
  }

  function getCoffeeVehicleAvailablePackages(stopId, container) {
    const detail = detailFor(stopId)
    const vehiclePackages = detail?.vehiclePackages?.[String(container?.product_id)]
    if (vehiclePackages == null) return Number.POSITIVE_INFINITY
    const alreadyMoved = Number(detail?.draft?.containers?.[String(container?.id)]?.movedPackages || 0)
    return Math.max(0, Number(vehiclePackages || 0) + alreadyMoved)
  }

  function getCoffeeSelectableMaxPackages(stopId, container) {
    return Math.min(getCoffeeMaxPackages(stopId, container), getCoffeeVehicleAvailablePackages(stopId, container))
  }

  function getCoffeeActualPackages(stopId, container) {
    const detail = detailFor(stopId)
    const draft = detail?.draft?.containers?.[String(container.id)]
    if (draft?.packages != null) return Math.min(Number(draft.packages || 0), getCoffeeSelectableMaxPackages(stopId, container))
    if (detail?.manualCounterMode) return 0
    return Math.min(getCoffeeSuggestedPackages(container), getCoffeeSelectableMaxPackages(stopId, container))
  }

  function getCoffeeAddedQuantity(stopId, container) {
    return Math.max(0, getCoffeeActualPackages(stopId, container) * getCoffeeRefillPackageQuantity(container))
  }

  function getCoffeeNetMovedQuantity(rows, visitId, container) {
    const prefix = `route_visit_${visitId}_container_${container.id}`
    return (rows || [])
      .filter((row) => (
        String(row.product_id || '') === String(container.product_id || '')
        && (String(row.reference_id || '') === prefix || String(row.reference_id || '').startsWith(`${prefix}_`))
      ))
      .reduce((sum, row) => sum + (row.movement_type === 'return' ? -1 : 1) * Number(row.quantity_base_units || 0), 0)
  }

  function getCoffeeAfterQuantity(stopId, container) {
    const current = getCoffeeActualBeforeQuantity(stopId, container)
    const capacity = Number(container?.capacity_quantity || 0)
    const next = current + getCoffeeAddedQuantity(stopId, container)
    const packageQuantity = getCoffeeRefillPackageQuantity(container)
    const wholePackageTolerance = capacity && current <= capacity * 0.1 + 0.0001 ? packageQuantity : 0
    return capacity && next > capacity + wholePackageTolerance + 0.0001 ? capacity : next
  }

  function getCoffeeCalibrationQuantity(stopId, container) {
    const draft = detailFor(stopId)?.draft?.calibration?.[String(container.id)]
    return draft?.quantity != null ? Number(draft.quantity || 0) : Number(container?.current_quantity || 0)
  }

  function getCoffeeCalibrationStep(container) {
    if (normalizeText(container?.unit || '') === 'ks') return 1
    return Math.max(1, getCoffeeRefillPackageQuantity(container) || 1)
  }

  function describeCoffeeQuantity(quantity, container) {
    const value = Number(quantity || 0)
    const unit = container?.unit || 'g'
    const packageQty = getCoffeeRefillPackageQuantity(container)
    if (packageQty > 0) return `${getCoffeePackageCountLabel(value / packageQty, container)} · ${formatNumber(value)} ${unit}`
    return `${formatNumber(value)} ${unit}`
  }

  function isCoffeeContainerCalibrated(stopId, container) {
    const detail = detailFor(stopId)
    return Boolean(detail?.draft?.calibration?.[String(container.id)]?.done)
      || Boolean(detail?.calibratedContainers?.[String(container.id)])
  }

  function isCoffeeCalibrationComplete(stopId) {
    const detail = detailFor(stopId)
    if (!detail?.needsCalibration) return true
    return (detail.containers || []).every((container) => isCoffeeContainerCalibrated(stopId, container))
  }

  function getCoffeeGuidedCheckRows(detail) {
    return (detail?.checkRows || [])
      .filter((row) => ['inside', 'outside', 'test', 'photo'].includes(String(row.assigned_payload?.section || '')))
      .sort((a, b) => Number(a.assigned_payload?.order || 999) - Number(b.assigned_payload?.order || 999))
  }

  function hasCoffeeContainerRefillWork(stopId, container) {
    const detail = detailFor(stopId)
    const draft = detail?.draft?.containers?.[String(container?.id)] || {}
    return Boolean(
      detail?.manualCounterMode
      || getCoffeeActualPackages(stopId, container) > 0
      || Number(draft.movedPackages || 0) > 0
      || draft.actualBeforeQuantity != null
      || draft.stateCorrection
      || draft.addedOutsidePicklist
    )
  }

  function isCoffeeContainerPendingConfirmation(stopId, container) {
    const draft = detailFor(stopId)?.draft?.containers?.[String(container?.id)] || {}
    return !draft.accepted && hasCoffeeContainerRefillWork(stopId, container)
  }

  function getCoffeeGuidedStage(stopId, detail, readOnly = false) {
    if (readOnly) return 'done'
    if (!detail?.machineOpen) return 'goods'
    if (detail.draft?.extraContainerPickerOpen) return 'refill'
    if ((detail.containers || []).some((container) => isCoffeeContainerPendingConfirmation(stopId, container))) return 'refill'
    const hasContainers = (detail.containers || []).length > 0
    const hasPlannedRefill = (detail.containers || []).some((container) => getCoffeeActualPackages(stopId, container) > 0)
    if (hasContainers && !hasPlannedRefill && !detail.draft?.refillReviewed) return 'refill'
    const cashResolved = detail.cash && (detail.cash.collection_required ? detail.cash.operator_collected_confirmed : detail.cash.retained_for_next_visit)
    if (!cashResolved) return 'cash'
    if (getCoffeeGuidedCheckRows(detail).some((row) => row.status !== 'done')) return 'check'
    return 'finish'
  }

  function getCoffeePickTargetPackages(container) {
    return Math.max(getCoffeeSuggestedPackages(container), isCoffeeLidProduct(container) ? 1 : 0)
  }

  function getCoffeePickDecision(stopId, container) {
    const draft = detailFor(stopId)?.draft?.containers?.[String(container?.id)] || {}
    if (['taken', 'skipped', 'editing'].includes(String(draft.pickDecision || ''))) return draft.pickDecision
    const packages = getCoffeeActualPackages(stopId, container)
    if (draft.picked && Number(draft.movedPackages || 0) > 0) return 'taken'
    if (draft.picked && getCoffeePickTargetPackages(container) > 0 && packages <= 0) return 'skipped'
    return ''
  }

  function getCoffeePicklistContainers(detail) {
    return getCoffeeContainersInBagOrder(detail).filter((container) => {
      const draft = detail?.draft?.containers?.[String(container.id)] || {}
      return getCoffeePickTargetPackages(container) > 0 || Boolean(draft.addedOutsidePicklist)
    })
  }

  function getCoffeePickVisual(container) {
    const text = normalizeText(`${container?.product_name || ''} ${container?.product_sku || ''}`)
    if (/kelimek|pohar|cup|vicko|lid/.test(text)) return { type: 'cup', icon: '▱', label: isCoffeeLidProduct(container) ? 'Víčka' : 'Kelímky' }
    if (/matcha|pistaci/.test(text)) return { type: 'matcha', icon: '●', label: 'Matcha' }
    if (/cokolad|kakao/.test(text)) return { type: 'chocolate', icon: '◆', label: 'Čokoláda' }
    if (/mlek|smetan|creamer/.test(text)) return { type: 'milk', icon: '◒', label: 'Mléčná složka' }
    if (/kav|coffee|barber|sofie|zrno/.test(text)) return { type: 'coffee', icon: '●', label: 'Káva' }
    return { type: 'cup', icon: '◇', label: container?.container_code || 'Surovina' }
  }

  function getCoffeeExtraContainerMaxPackages(stopId, detail, container) {
    if (!container) return 0
    const before = Number(detail.draft?.extraContainerBeforeQuantity ?? container.current_quantity ?? 0)
    const capacity = Number(container.capacity_quantity || 0)
    const packageQuantity = getCoffeeRefillPackageQuantity(container)
    const capacityMax = capacity && packageQuantity
      ? Math.max(0, Math.floor((capacity - before) / packageQuantity))
      : Number.POSITIVE_INFINITY
    return Math.max(0, Math.min(capacityMax, getCoffeeVehicleAvailablePackages(stopId, container)))
  }

  return {
    convertCoffeeQuantityToProductBase,
    describeCoffeeQuantity,
    getCoffeeActualBeforeQuantity,
    getCoffeeActualPackages,
    getCoffeeAddedQuantity,
    getCoffeeAfterQuantity,
    getCoffeeCalibrationQuantity,
    getCoffeeCalibrationSliderStep,
    getCoffeeCalibrationStep,
    getCoffeeContainerQuantity,
    getCoffeeContainerSequence,
    getCoffeeContainersInBagOrder,
    getCoffeeEntryQuantity,
    getCoffeeEntryUnit,
    getCoffeeExtraContainerMaxPackages,
    getCoffeeFillPercent,
    getCoffeeGuidedCheckRows,
    getCoffeeGuidedStage,
    getCoffeeMaxPackages,
    getCoffeeNetMovedQuantity,
    getCoffeePackageBaseQuantity,
    getCoffeePackageCountLabel,
    getCoffeePackageNoun,
    getCoffeePickDecision,
    getCoffeePickTargetPackages,
    getCoffeePickVisual,
    getCoffeePicklistContainers,
    getCoffeeQuantityFromFillPercent,
    getCoffeeRefillPackage,
    getCoffeeRefillPackageQuantity,
    getCoffeeSelectableMaxPackages,
    getCoffeeSuggestedPackages,
    getCoffeeVehicleAvailablePackages,
    getCoffeeVehiclePackageCount,
    getCoffeeVehiclePackageLabel,
    getCoffeeVehicleStockQuantity,
    getProductBaseUnit,
    hasCoffeeContainerRefillWork,
    isCoffeeCalibrationComplete,
    isCoffeeContainerCalibrated,
    isCoffeeContainerPendingConfirmation,
    isCoffeeCupProduct,
    isCoffeeLidProduct,
    isCoffeeMassPackageStock,
    roundCoffeeCalibrationQuantity
  }
}
