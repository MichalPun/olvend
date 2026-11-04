export function normalizeText(value) {
  return String(value ?? '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .trim()
}

export function escapeHtml(value) {
  return String(value ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;')
}

export function formatQuantity(value, maximumFractionDigits = 2) {
  return Number(value || 0).toLocaleString('cs-CZ', { maximumFractionDigits })
}

export function formatBaseQuantity(value, product, fallbackUnit = 'ks') {
  return `${formatQuantity(value)} ${product?.base_unit || fallbackUnit}`
}

export function parseQuantity(value, fallback = 0) {
  const parsed = Number(String(value ?? '').replace(',', '.'))
  return Number.isFinite(parsed) && parsed >= 0 ? parsed : fallback
}

export function getStoragePosition(product) {
  const match = String(product?.note || '').match(/\[olvend_storage_position:([^\]]+)\]/)
  return match?.[1]?.trim() || ''
}

export function getProductKind(product) {
  if (product?.product_category && product.product_category !== 'beverage_ready') return product.product_category
  const match = String(product?.note || '').match(/\[olvend_product_kind:([a-z_]+)\]/)
  return match?.[1] || product?.product_category || ''
}

export function getPickingCategory(product) {
  const kind = getProductKind(product)
  if (kind === 'water_product') return { key: 'waters', label: 'Vody', order: 1 }
  if (['snack_ready', 'food_ready'].includes(kind)) return { key: 'snacks', label: 'Cukrovinky', order: 2 }
  return { key: 'ingredients', label: 'Suroviny', order: 0 }
}

export function sortPickingItems(items, productsById) {
  return [...(items || [])].sort((left, right) => {
    const productLeft = productsById.get(String(left.product_id)) || {}
    const productRight = productsById.get(String(right.product_id)) || {}
    const categoryDifference = getPickingCategory(productLeft).order - getPickingCategory(productRight).order
    if (categoryDifference) return categoryDifference
    const positionDifference = normalizeText(getStoragePosition(productLeft))
      .localeCompare(normalizeText(getStoragePosition(productRight)), 'cs', { numeric: true })
    if (positionDifference) return positionDifference
    return normalizeText(left.product_name || productLeft.name)
      .localeCompare(normalizeText(right.product_name || productRight.name), 'cs', { numeric: true })
  })
}

export function getProductPackages(productId, packages) {
  return (packages || [])
    .filter((pack) => String(pack.product_id) === String(productId) && pack.active !== false)
    .sort((left, right) => Number(right.is_default === true) - Number(left.is_default === true)
      || Number(right.units_per_package || 0) - Number(left.units_per_package || 0))
}

export function getPickingPackage(item, product, packages) {
  const candidates = getProductPackages(product?.id, packages)
  const itemUnit = normalizeText(item?.unit)
  return candidates.find((pack) => itemUnit && normalizeText(pack.package_name) === itemUnit)
    || candidates.find((pack) => pack.is_default && Number(pack.units_per_package || 0) > 1)
    || candidates.find((pack) => Number(pack.units_per_package || 0) > 1)
    || null
}

export function quantityToBase(quantity, unit, product, pack) {
  const amount = Number(quantity || 0)
  if (!pack || normalizeText(unit) === normalizeText(product?.base_unit || 'ks')) return amount
  if (normalizeText(unit) !== normalizeText(pack.package_name)) return amount
  return Number((amount * Number(pack.units_per_package || 1)).toFixed(3))
}

export function quantityFromBase(quantity, mode, product, pack) {
  const amount = Number(quantity || 0)
  if (mode !== 'package' || !pack || Number(pack.units_per_package || 0) <= 0) return amount
  return Number((amount / Number(pack.units_per_package)).toFixed(3))
}

export function getItemBaseQuantity(item, product, packages, field = 'prepared_quantity') {
  const pack = getPickingPackage(item, product, packages)
  const value = item?.[field] ?? (field === 'prepared_quantity' ? item?.requested_quantity : 0) ?? 0
  return quantityToBase(value, item?.unit || product?.base_unit || 'ks', product, pack)
}

export function hasProductSubstitution(item) {
  return Boolean(item?.prepared_product_id)
    && String(item.prepared_product_id) !== String(item?.product_id || '')
}

export function getPreparedProductId(item) {
  return hasProductSubstitution(item) ? item.prepared_product_id : item?.product_id
}

export function getPreparedUnit(item, product) {
  return hasProductSubstitution(item)
    ? (item?.prepared_unit || product?.base_unit || 'ks')
    : (item?.unit || product?.base_unit || 'ks')
}

export function getPreparedItemBaseQuantity(item, productsById, packages, field = 'prepared_quantity') {
  const useOriginal = field === 'requested_quantity'
  const productId = useOriginal ? item?.product_id : getPreparedProductId(item)
  const product = productsById.get(String(productId)) || null
  const unit = useOriginal ? (item?.unit || product?.base_unit || 'ks') : getPreparedUnit(item, product)
  const pack = getPickingPackage({ ...item, product_id: productId, unit }, product, packages)
  const fallback = field === 'prepared_quantity' ? item?.requested_quantity : 0
  const value = item?.[field] ?? fallback ?? 0
  return quantityToBase(value, unit, product, pack)
}

export function getAllowedSubstituteSkus(value) {
  const skus = []
  const pattern = /SKU\s*([A-Za-z0-9_-]+)/gi
  const source = String(value || '')
  let match = pattern.exec(source)
  while (match) {
    if (match[1]) skus.push(String(match[1]).trim())
    match = pattern.exec(source)
  }
  return skus
}

export function getApprovedSubstituteProducts(originalProduct, products, rules) {
  const originalSku = normalizeText(originalProduct?.sku)
  if (!originalSku) return []
  const approvedSkus = new Set()
  const originalRules = (rules || []).filter((rule) => normalizeText(rule?.product_sku) === originalSku)
  for (const rule of originalRules) {
    if (rule?.substitution_policy === 'approved_list') {
      getAllowedSubstituteSkus(rule.allowed_substitutes).forEach((sku) => approvedSkus.add(normalizeText(sku)))
    }
    if (rule?.substitution_policy === 'same_family' && normalizeText(rule.product_family)) {
      const family = normalizeText(rule.product_family)
      ;(rules || [])
        .filter((candidate) => candidate?.active !== false && normalizeText(candidate?.product_family) === family)
        .forEach((candidate) => approvedSkus.add(normalizeText(candidate.product_sku)))
    }
  }
  approvedSkus.delete(originalSku)
  const seen = new Set()
  return (products || [])
    .filter((product) => product?.active !== false && approvedSkus.has(normalizeText(product?.sku)))
    .filter((product) => {
      const key = String(product.id)
      if (seen.has(key)) return false
      seen.add(key)
      return true
    })
    .sort((left, right) => normalizeText(left.name).localeCompare(normalizeText(right.name), 'cs', { numeric: true }))
}

export function isSkippedItem(item) {
  return Number(item?.prepared_quantity || 0) <= 0
    && Number(item?.requested_quantity || 0) > 0
    && /\[Nevychystáno:/i.test(String(item?.note || ''))
}

export function isHandledItem(item) {
  return Boolean(item?.warehouse_picked_at) || isSkippedItem(item)
}

export function pluralizeItems(value) {
  const count = Number(value || 0)
  if (count === 1) return `${count} položka`
  if (count > 1 && count < 5) return `${count} položky`
  return `${count} položek`
}
