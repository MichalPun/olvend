export const CALIBRATION_STATUS = Object.freeze({
  OK: 'ok',
  MISSING: 'missing_calibration',
  INVALID: 'invalid_calibration',
  MANUAL: 'manual',
  NOT_APPLICABLE: 'not_applicable',
  UNSUPPORTED_UNIT: 'unsupported_unit'
})

export function parseLocaleNumber(value) {
  if (typeof value === 'number') return Number.isFinite(value) ? value : null
  const normalized = String(value ?? '').trim().replace(/\s+/g, '').replace(',', '.')
  if (!normalized) return null
  const parsed = Number(normalized)
  return Number.isFinite(parsed) ? parsed : null
}

export function timeToDsec(value, unit = 'dsec') {
  const parsed = parseLocaleNumber(value)
  if (parsed == null) return null
  if (unit === 's') return parsed * 10
  if (unit === 'dsec') return parsed
  return null
}

export function resolveCalibrationMeasurement(currentMeasurement, latestCompletedMeasurement) {
  return currentMeasurement || latestCompletedMeasurement || {}
}

export function roundToStep(value, step = 1) {
  const number = parseLocaleNumber(value)
  const precision = parseLocaleNumber(step)
  if (number == null || precision == null || precision <= 0) return null
  return Math.round((number / precision) + Number.EPSILON) * precision
}

export function calculateDispenseSetting({
  requiredQuantity,
  requiredUnit = 'g',
  calibrationTime,
  timeUnit = 'dsec',
  measuredAmount,
  precisionStepDsec = 1,
  calibrationMode = 'timed'
} = {}) {
  if (calibrationMode === 'manual') return { status: CALIBRATION_STATUS.MANUAL }
  if (calibrationMode === 'skip' || String(requiredUnit).toLowerCase() === 'ks') {
    return { status: CALIBRATION_STATUS.NOT_APPLICABLE }
  }
  if (String(requiredUnit).toLowerCase() !== 'g') {
    return { status: CALIBRATION_STATUS.UNSUPPORTED_UNIT }
  }

  const dose = parseLocaleNumber(requiredQuantity)
  const timeDsec = timeToDsec(calibrationTime, timeUnit)
  const amountG = parseLocaleNumber(measuredAmount)
  const stepDsec = parseLocaleNumber(precisionStepDsec)

  if (dose == null || dose < 0 || timeDsec == null || amountG == null || stepDsec == null) {
    return { status: CALIBRATION_STATUS.MISSING }
  }
  if (timeDsec <= 0 || amountG <= 0 || stepDsec <= 0) {
    return { status: CALIBRATION_STATUS.INVALID }
  }

  const rateGPerDsec = amountG / timeDsec
  const rawDsec = dose * timeDsec / amountG
  const settingDsec = roundToStep(rawDsec, stepDsec)
  return {
    status: CALIBRATION_STATUS.OK,
    rateGPerDsec,
    rawDsec,
    settingDsec
  }
}

export function physicalButtonSort(left, right) {
  const leftColumn = Number(left.grid_column ?? Number.MAX_SAFE_INTEGER)
  const rightColumn = Number(right.grid_column ?? Number.MAX_SAFE_INTEGER)
  if (leftColumn !== rightColumn) return leftColumn - rightColumn

  const leftRow = Number(left.grid_row_from_bottom ?? Number.MIN_SAFE_INTEGER)
  const rightRow = Number(right.grid_row_from_bottom ?? Number.MIN_SAFE_INTEGER)
  if (leftRow !== rightRow) return rightRow - leftRow

  const leftOrder = Number(left.sort_order ?? Number.MAX_SAFE_INTEGER)
  const rightOrder = Number(right.sort_order ?? Number.MAX_SAFE_INTEGER)
  if (leftOrder !== rightOrder) return leftOrder - rightOrder
  return String(left.selection_code ?? '').localeCompare(String(right.selection_code ?? ''), 'cs', { numeric: true })
}

export function buildCalibrationResults({
  buttons = [],
  recipeItems = [],
  containers = [],
  measurements = [],
  precisionStepDsec = 1
} = {}) {
  const activeButtons = buttons.filter((item) => item.active !== false).sort(physicalButtonSort)
  const containerById = new Map(containers.map((item) => [String(item.id), item]))
  const measurementByContainer = new Map(measurements.map((item) => [String(item.coffee_container_id), item]))
  const recipeByButton = new Map()

  recipeItems.filter((item) => item.active !== false).forEach((item) => {
    const key = String(item.coffee_button_id)
    if (!recipeByButton.has(key)) recipeByButton.set(key, [])
    recipeByButton.get(key).push(item)
  })

  return activeButtons.map((button) => {
    const ingredients = (recipeByButton.get(String(button.id)) || [])
      .sort((a, b) => Number(a.sort_order || 0) - Number(b.sort_order || 0))
      .map((recipe) => {
        const container = containerById.get(String(recipe.coffee_container_id)) || null
        const measurement = measurementByContainer.get(String(recipe.coffee_container_id)) || null
        const result = calculateDispenseSetting({
          requiredQuantity: recipe.quantity_per_vend,
          requiredUnit: recipe.unit,
          calibrationTime: measurement?.calibration_time_dsec,
          timeUnit: 'dsec',
          measuredAmount: measurement?.measured_amount_g,
          precisionStepDsec,
          calibrationMode: measurement?.calibration_mode || (String(recipe.unit).toLowerCase() === 'ks' ? 'skip' : 'timed')
        })
        return {
          recipeItemId: recipe.id,
          containerId: recipe.coffee_container_id,
          productId: recipe.product_id || container?.product_id || null,
          containerCode: recipe.container_code || container?.container_code || null,
          ingredientName: recipe.ingredient_name || container?.product_name || 'Surovina',
          requiredQuantity: parseLocaleNumber(recipe.quantity_per_vend),
          requiredUnit: recipe.unit || container?.unit || null,
          ...result
        }
      })
    return { ...button, ingredients }
  })
}

export function formatDsec(value, maximumFractionDigits = 3) {
  const parsed = parseLocaleNumber(value)
  if (parsed == null) return '—'
  return `${new Intl.NumberFormat('cs-CZ', { maximumFractionDigits }).format(parsed)} dsec`
}

export function measurementFingerprint(measurements = []) {
  return JSON.stringify([...measurements]
    .map((item) => ({
      coffee_container_id: String(item.coffee_container_id || ''),
      calibration_mode: item.calibration_mode || 'timed',
      calibration_time_dsec: parseLocaleNumber(item.calibration_time_dsec),
      measured_amount_g: parseLocaleNumber(item.measured_amount_g)
    }))
    .sort((a, b) => a.coffee_container_id.localeCompare(b.coffee_container_id)))
}
