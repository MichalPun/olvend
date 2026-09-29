// Purchase preview only: these helpers never create orders or stock movements.
export function jipQuantity(row) {
  if (!row || row.calculation_error || row.recommended_order_qty == null) return null
  const qty = Number(row.recommended_order_qty)
  return Number.isFinite(qty) && qty >= 0 ? qty : null
}
export function mergeJipProfiles(profiles, rows) {
  const result = [...profiles]
  for (const row of rows) {
    if (result.some(p => String(p.supplier_id) === String(row.supplier_id) && String(p.product_id) === String(row.product_id) && p.pilot_scope === 'general')) continue
    result.push({ id: `jip-auto-${row.product_id}`, product_id: row.product_id, supplier_id: row.supplier_id,
      product_name: row.name, supplier_name: 'JIP', pilot_scope: 'general', active: true, reorder_enabled: true,
      package_quantity: row.package_quantity, order_multiple_quantity: row.package_quantity,
      base_order_quantity: 0, auto_from_mapping: true })
  }
  return result
}
export function receiptShortfalls(order) {
  if (order.status !== 'received') return []
  return (order.items || []).filter(i => Number(i.ordered_quantity) > Number(i.received_quantity || 0))
    .map(i => ({name: i.product_name || 'Produkt', quantity: Number(i.ordered_quantity) - Number(i.received_quantity || 0)}))
}
