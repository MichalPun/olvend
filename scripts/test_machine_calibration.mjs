import test from 'node:test'
import assert from 'node:assert/strict'
import {
  CALIBRATION_STATUS,
  buildCalibrationResults,
  calculateDispenseSetting,
  parseLocaleNumber,
  physicalButtonSort,
  timeToDsec
} from '../machine-calibration-core.mjs'

const samples = [
  ['Instantní káva', 7.41, 2.2, 21],
  ['Cukr', 47, 6, 9],
  ['Smetana', 31.77, 8.4, 19],
  ['Čokoláda', 35.24, 26, 52],
  ['Bílá čokoláda', 41.78, 25, 42],
  ['Matcha malina', 26.73, 25.5, 67],
  ['Matcha pistácie', 41.86, 25.5, 43],
  ['Irish', 31.6, 22, 49]
]

test('kontrolní kalibrace ze zadání dávají očekávané celé dsec', () => {
  for (const [name, measuredAmount, requiredQuantity, expected] of samples) {
    const result = calculateDispenseSetting({
      requiredQuantity,
      requiredUnit: 'g',
      calibrationTime: 70,
      timeUnit: 'dsec',
      measuredAmount,
      precisionStepDsec: 1
    })
    assert.equal(result.status, CALIBRATION_STATUS.OK, name)
    assert.equal(result.settingDsec, expected, name)
  }
})

test('desetinná čárka a sekundy se normalizují do dsec', () => {
  assert.equal(parseLocaleNumber('47,5'), 47.5)
  assert.equal(timeToDsec('7,0', 's'), 70)
  const result = calculateDispenseSetting({
    requiredQuantity: '6,0', requiredUnit: 'g', calibrationTime: '7,0',
    timeUnit: 's', measuredAmount: '47,0', precisionStepDsec: 1
  })
  assert.equal(result.settingDsec, 9)
})

test('nulová, chybějící a kusová kalibrace nevyrábí výsledek', () => {
  assert.equal(calculateDispenseSetting({ requiredQuantity: 6, requiredUnit: 'g', calibrationTime: 70, measuredAmount: 0 }).status, CALIBRATION_STATUS.INVALID)
  assert.equal(calculateDispenseSetting({ requiredQuantity: 6, requiredUnit: 'g', calibrationTime: '', measuredAmount: 47 }).status, CALIBRATION_STATUS.MISSING)
  assert.equal(calculateDispenseSetting({ requiredQuantity: 1, requiredUnit: 'ks', calibrationTime: 70, measuredAmount: 47 }).status, CALIBRATION_STATUS.NOT_APPLICABLE)
  assert.equal(calculateDispenseSetting({ requiredQuantity: 7, requiredUnit: 'g', calibrationMode: 'manual' }).status, CALIBRATION_STATUS.MANUAL)
})

test('přesnost automatu se aplikuje až na konečný čas', () => {
  const full = calculateDispenseSetting({ requiredQuantity: 6, requiredUnit: 'g', calibrationTime: 70, measuredAmount: 47, precisionStepDsec: 0.5 })
  assert.ok(Math.abs(full.rawDsec - 8.936170212765957) < 1e-12)
  assert.equal(full.settingDsec, 9)
})

test('tlačítka se řadí po fyzických sloupcích shora dolů', () => {
  const ordered = [
    { selection_code: '6', grid_column: 2, grid_row_from_bottom: 3 },
    { selection_code: '2', grid_column: 1, grid_row_from_bottom: 3 },
    { selection_code: '1', grid_column: 1, grid_row_from_bottom: 4 },
    { selection_code: '5', grid_column: 2, grid_row_from_bottom: 4 }
  ].sort(physicalButtonSort).map((item) => item.selection_code)
  assert.deepEqual(ordered, ['1', '2', '5', '6'])
})

test('výsledky používají vazby přes ID kontejneru, ne názvy surovin', () => {
  const result = buildCalibrationResults({
    buttons: [{ id: 1, selection_code: '1', product_name: 'Káva', active: true, grid_column: 1, grid_row_from_bottom: 1 }],
    containers: [{ id: 10, product_id: 100, product_name: 'Libovolný název', unit: 'g' }],
    recipeItems: [{ id: 20, coffee_button_id: 1, coffee_container_id: 10, product_id: 100, ingredient_name: 'Jiný historický název', quantity_per_vend: 2.2, unit: 'g', active: true }],
    measurements: [{ coffee_container_id: 10, calibration_time_dsec: 70, measured_amount_g: 7.41, calibration_mode: 'timed' }]
  })
  assert.equal(result[0].ingredients[0].settingDsec, 21)
  assert.equal(result[0].ingredients[0].productId, 100)
})
