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

  root.OlvendOperatorStockCore = {
    aggregateStockRows: aggregateStockRows
  }
})(typeof window !== 'undefined' ? window : globalThis)
