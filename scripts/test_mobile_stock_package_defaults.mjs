import fs from 'node:fs'
import vm from 'node:vm'

const html = fs.readFileSync(new URL('../mobile.html', import.meta.url), 'utf8')
const functionStart = html.indexOf('    function updateStockUnitControls(')
const functionEnd = html.indexOf('    function updateStockQuantityHelp(', functionStart)
if (functionStart < 0 || functionEnd < 0) throw new Error('Stock unit control function is missing')
const functionSource = html.slice(functionStart, functionEnd)

const stockUnitSelect = {
  value: 'base',
  dataset: {},
  _innerHTML: '',
  set innerHTML(value) {
    this._innerHTML = value
    const selectedMatch = value.match(/<option value="([^"]+)" selected/)
    this.value = selectedMatch?.[1] || value.match(/<option value="([^"]+)"/)?.[1] || ''
  },
  get innerHTML() { return this._innerHTML }
}

const packageOptions = new Map([
  [108, [
    { value: 'base', label: 'kg / základ' },
    { value: 'package:32', label: '0,5 kg (0,5 kg)' }
  ]],
  [109, [{ value: 'base', label: 'kg / základ' }]]
])
const context = {
  els: {
    stockUnitSelect,
    stockQuantityHelp: { textContent: '' },
    stockProductInput: { value: '' }
  },
  getStockEntryUnitOptions: (product) => packageOptions.get(product?.id) || [{ value: 'base', label: 'základ' }],
  getDefaultStockEntryUnitMode: (product) => product?.id === 108 ? 'package:32' : 'base',
  updateStockQuantityHelp: (product) => {
    context.els.stockQuantityHelp.textContent = product?.id === 108 && stockUnitSelect.value === 'package:32'
      ? '6 0,5 kg = 3.00 kg'
      : 'base'
  },
  resolveProductFromInput: () => null,
  escapeHtml: (value) => String(value)
}

vm.createContext(context)
vm.runInContext(`${functionSource}\nthis.updateStockUnitControls = updateStockUnitControls`, context)

const sophia = { id: 108, name: 'oVe FD COFFEE SOPHIA 500g', base_unit: 'kg' }
context.updateStockUnitControls(sophia)

if (stockUnitSelect.value !== 'package:32') {
  throw new Error(`Newly selected Sophia should default to 0.5 kg packages, got ${stockUnitSelect.value}`)
}
if (context.els.stockQuantityHelp.textContent !== '6 0,5 kg = 3.00 kg') {
  throw new Error(`Unexpected Sophia conversion help: ${context.els.stockQuantityHelp.textContent}`)
}

stockUnitSelect.value = 'base'
context.updateStockUnitControls(sophia)
if (stockUnitSelect.value !== 'base') {
  throw new Error('An explicit unit choice must be preserved while the same product stays selected')
}

const otherProduct = { id: 109, name: 'oVe FRESH DRINK LEMON 1 kg', base_unit: 'kg' }
context.updateStockUnitControls(otherProduct)
if (stockUnitSelect.value !== 'base') {
  throw new Error('A newly selected product without a configured package should use its base unit')
}

if (!html.includes('return Number(convertRecipeQuantity(amount * unitsPerPackage, packageUnit, baseUnit).toFixed(3))')) {
  throw new Error('Package quantities are no longer converted to the product base unit')
}

console.log('Mobile stock package default checks passed.')
