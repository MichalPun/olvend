export const cleanText = (value) => String(value ?? '').trim().replace(/\s+/g, ' ')

export const normalizeText = (value) => cleanText(value)
  .normalize('NFD')
  .replace(/[\u0300-\u036f]/g, '')
  .toLowerCase()

export const cleanProductName = (value) => cleanText(value).replace(/\s+NEW$/i, '').trim()

export function productKind(product) {
  const note = String(product?.note || '')
  const tagged = note.match(/\[olvend_product_kind:([a-z_]+)\]/)
  if (tagged?.[1]) return tagged[1]
  if (/Zdrojový typ:\s*Teplé nápoje/i.test(note)) return 'hot_drink'
  if (product?.product_category && product.product_category !== 'beverage_ready') return product.product_category
  return product?.product_category || product?.usage_type || ''
}

export function productTypeLabel(value) {
  return {
    beverage_ready: 'Hotové nápoje',
    water_product: 'Vody',
    hot_drink: 'Teplé nápoje',
    snack_ready: 'Cukrovinky',
    food_ready: 'Bagety / hotová jídla',
    ingredient: 'Suroviny',
    consumable: 'Spotřební materiál',
    service_material: 'Spotřební materiál',
    spare_part: 'Náhradní díly',
  }[value] || 'Nezařazeno'
}

export function indexProducts(products = []) {
  const bySku = new Map()
  const byName = new Map()
  const prefer = (map, key, product) => {
    if (!key) return
    const current = map.get(key)
    if (!current || (product?.active && !current?.active)) map.set(key, product)
  }
  products.forEach((product) => {
    prefer(bySku, normalizeText(product?.sku), product)
    prefer(byName, normalizeText(cleanProductName(product?.name)), product)
  })
  return { bySku, byName }
}

export function catalogProduct(row, catalog) {
  const sku = normalizeText(row?.product_sku)
  if (sku && catalog.bySku.has(sku)) return catalog.bySku.get(sku)
  const name = normalizeText(cleanProductName(row?.product_name))
  return name ? catalog.byName.get(name) || null : null
}

export function canonicalProductRow(row, catalog) {
  const product = catalogProduct(row, catalog)
  let name = cleanProductName(product?.name || row?.product_name)
  if (String(row?.selection_code || '').trim() === '0' && /^telemetrie prodej kava(?:\s+new)?$/i.test(normalizeText(name))) {
    name = 'Kávový nápoj – druh neurčen'
  }
  return {
    ...row,
    product_name: name || cleanProductName(row?.product_name) || row?.product_sku || 'Bez produktu',
    product_sku: product?.sku || row?.product_sku || '',
    product_category_label: product ? productTypeLabel(productKind(product)) : 'Nezařazeno',
  }
}

export function dedupeTelemetryRows(rows = []) {
  const direct = rows.filter((row) => normalizeText(row.provider) === 'ima').map((row) => ({ row, used: false }))
  const duplicateIds = new Set()
  rows.filter((row) => normalizeText(row.provider) === 'vendsoft').forEach((fallback) => {
    const fallbackAt = new Date(fallback.source_event_at || 0).getTime()
    let best = null
    direct.forEach((candidate) => {
      if (candidate.used) return
      const row = candidate.row
      if (String(row.machine_id) !== String(fallback.machine_id)) return
      if (String(row.selection_code || '') !== String(fallback.selection_code || '')) return
      if (String(row.product_sku || '') !== String(fallback.product_sku || '')) return
      if (Number(row.quantity || 0) !== Number(fallback.quantity || 0)) return
      if (Math.abs(Number(row.total_amount_czk || 0) - Number(fallback.total_amount_czk || 0)) > 0.01) return
      const distance = Math.abs(new Date(row.source_event_at || 0).getTime() - fallbackAt)
      if (distance > 20 * 60 * 1000) return
      if (!best || distance < best.distance) best = { candidate, distance }
    })
    if (best) {
      best.candidate.used = true
      duplicateIds.add(String(fallback.id))
    }
  })
  return rows.filter((row) => !duplicateIds.has(String(row.id)))
}

export function aggregateProductRows(rows = [], products = []) {
  const catalog = indexProducts(products)
  const grouped = new Map()
  dedupeTelemetryRows(rows).map((row) => canonicalProductRow(row, catalog)).forEach((row) => {
    const sku = normalizeText(row.product_sku)
    const key = sku ? `sku:${sku}` : `name:${normalizeText(row.product_name) || 'bez-produktu'}`
    const current = grouped.get(key) || {
      key,
      sku: row.product_sku || '',
      label: row.product_name || 'Bez produktu',
      typeLabel: row.product_category_label || 'Nezařazeno',
      quantity: 0,
      revenue: 0,
      cash: 0,
      cashless: 0,
      unknown: 0,
    }
    current.quantity += Number(row.quantity || 0)
    current.revenue += Number(row.total_amount_czk || 0)
    current.cash += Number(row.cash_amount_czk || 0)
    current.cashless += Number(row.cashless_amount_czk || 0)
    current.unknown += Number(row.unknown_payment_amount_czk || 0)
    grouped.set(key, current)
  })
  return [...grouped.values()].sort((a, b) => b.revenue - a.revenue || a.label.localeCompare(b.label, 'cs'))
}

export function reportTotals(rows = []) {
  return rows.reduce((total, row) => ({
    quantity: total.quantity + Number(row.quantity || 0),
    revenue: total.revenue + Number(row.revenue || 0),
    cash: total.cash + Number(row.cash || 0),
    cashless: total.cashless + Number(row.cashless || 0),
    unknown: total.unknown + Number(row.unknown || 0),
  }), { quantity: 0, revenue: 0, cash: 0, cashless: 0, unknown: 0 })
}

export function reportGroups(rows = []) {
  const map = new Map()
  rows.forEach((row) => {
    const label = row.typeLabel || 'Nezařazeno'
    if (!map.has(label)) map.set(label, [])
    map.get(label).push(row)
  })
  return [...map.entries()].map(([label, groupRows]) => ({
    label,
    rows: [...groupRows].sort((a, b) => b.revenue - a.revenue || a.label.localeCompare(b.label, 'cs')),
    totals: reportTotals(groupRows),
  })).sort((a, b) => a.label.localeCompare(b.label, 'cs'))
}

export function periodFromMonth(monthValue) {
  const match = String(monthValue || '').match(/^(\d{4})-(\d{2})/)
  if (!match) throw new Error('Neplatné období.')
  const year = Number(match[1])
  const month = Number(match[2])
  if (month < 1 || month > 12) throw new Error('Neplatné období.')
  const nextYear = month === 12 ? year + 1 : year
  const nextMonth = month === 12 ? 1 : month + 1
  return {
    period: `${year}-${String(month).padStart(2, '0')}-01`,
    nextPeriod: `${nextYear}-${String(nextMonth).padStart(2, '0')}-01`,
    label: new Intl.DateTimeFormat('cs-CZ', { month: 'long', year: 'numeric', timeZone: 'Europe/Prague' }).format(new Date(Date.UTC(year, month - 1, 15))),
  }
}

export function previousMonthPeriod(now = new Date()) {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Europe/Prague', year: 'numeric', month: '2-digit', day: '2-digit',
  }).formatToParts(now).reduce((result, part) => ({ ...result, [part.type]: part.value }), {})
  let year = Number(parts.year)
  let month = Number(parts.month) - 1
  if (month === 0) { month = 12; year -= 1 }
  return periodFromMonth(`${year}-${String(month).padStart(2, '0')}`)
}

export function zonedMidnightUtc(localDate, timeZone = 'Europe/Prague') {
  const guess = new Date(`${localDate}T00:00:00.000Z`)
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone, year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', second: '2-digit', hourCycle: 'h23',
  }).formatToParts(guess).reduce((result, part) => ({ ...result, [part.type]: part.value }), {})
  const represented = Date.UTC(Number(parts.year), Number(parts.month) - 1, Number(parts.day), Number(parts.hour), Number(parts.minute), Number(parts.second))
  return new Date(guess.getTime() - (represented - guess.getTime())).toISOString()
}
