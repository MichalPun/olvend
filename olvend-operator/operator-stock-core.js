(function (root) {
  'use strict'

  function aggregateStockRows(rows) {
    var grouped = Object.create(null)
    var order = []
    ;(Array.isArray(rows) ? rows : []).forEach(function (row) {
      var key = row.product_id != null
        ? 'product:' + String(row.product_id)
        : 'fallback:' + [row.product_name, row.sku, row.ean, row.base_unit].join('|')
      if (!grouped[key]) {
        grouped[key] = Object.assign({}, row)
        grouped[key].quantity_on_hand = Number(row.quantity_on_hand || 0)
        grouped[key].reserved_quantity = Number(row.reserved_quantity || 0)
        grouped[key].balance_row_count = 1
        order.push(key)
        return
      }
      grouped[key].quantity_on_hand += Number(row.quantity_on_hand || 0)
      grouped[key].reserved_quantity += Number(row.reserved_quantity || 0)
      grouped[key].balance_row_count += 1
      if (String(row.updated_at || '') > String(grouped[key].updated_at || '')) grouped[key].updated_at = row.updated_at
    })
    return order.map(function (key) { return grouped[key] })
  }

  function normalizeText(value) {
    return String(value || '').normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase()
  }

  function stockCategory(row) {
    var productCategory = normalizeText(row && row.product_category)
    var usageType = normalizeText(row && row.usage_type)
    if (productCategory === 'food_ready') return 'fresh'
    if (productCategory === 'beverage_ready') return 'drinks'
    if (productCategory === 'snack_ready') return 'sweets'
    if (productCategory === 'ingredient' || usageType === 'recipe_consumption' || usageType === 'internal_consumption') return 'ingredients'
    if (productCategory === 'consumable' || productCategory === 'spare_part' || usageType === 'service_use') return 'ingredients'

    var text = normalizeText([row && row.product_name, productCategory, usageType, row && row.base_unit].join(' '))
    if (/food_ready|baget|sendvic|svacink|hamka|porizek|chlebicek|cerstv/.test(text)) return 'fresh'
    if (/drink|beverage|energy|red bull|napoj|voda|cola|pepsi|juice|dzus/.test(text)) return 'drinks'
    if (/surovin|ingredient|kava|mleko|cukr|cokolad|matcha|kelimek|vick|michat/.test(text)) return 'ingredients'
    return 'sweets'
  }

  root.OlvendOperatorStockCore = {
    aggregateStockRows: aggregateStockRows,
    stockCategory: stockCategory
  }
})(typeof window !== 'undefined' ? window : globalThis)
