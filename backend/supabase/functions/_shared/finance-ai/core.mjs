export const CATEGORY_KEYS = [
  'goods_resale','ingredients','consumables','spare_parts','fuel','vehicle_service',
  'vehicle_insurance','rent','energy','machine_service','software','telecom','insurance',
  'bank_fees','office','marketing','professional_services','other'
]

export function normalizeText(value) {
  return String(value || '').normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase().replace(/[^a-z0-9]+/g, ' ').trim()
}

export function number(value) {
  const parsed = Number(String(value ?? '').replace(/\s/g, '').replace(',', '.'))
  return Number.isFinite(parsed) ? parsed : 0
}

export function roundMoney(value) {
  return Math.round((number(value) + Number.EPSILON) * 100) / 100
}

export function normalizeExtraction(input = {}) {
  const lines = Array.isArray(input.lines) ? input.lines.map((line, index) => ({
    line_number: Number(line.line_number || index + 1),
    source_line_id: line.source_line_id || null,
    supplier_item_code: line.supplier_item_code || null,
    ean: line.ean || null,
    description: String(line.description || `Položka ${index + 1}`).trim(),
    quantity: number(line.quantity),
    unit_code: line.unit_code || null,
    unit_price_net: line.unit_price_net == null ? null : number(line.unit_price_net),
    net_amount: roundMoney(line.net_amount),
    vat_rate: line.vat_rate == null ? null : number(line.vat_rate),
    vat_amount: roundMoney(line.vat_amount),
    total_amount: roundMoney(line.total_amount),
    category_key: CATEGORY_KEYS.includes(line.category_key) ? line.category_key : null,
    lot_code: line.lot_code || null,
    best_before_date: line.best_before_date || null,
    use_by_date: line.use_by_date || null,
    confidence: Math.max(0, Math.min(100, number(line.confidence))),
    warnings: Array.isArray(line.warnings) ? line.warnings.map(String) : []
  })) : []
  return {
    document_type: ['invoice','credit_note','advance_invoice','other'].includes(input.document_type) ? input.document_type : 'invoice',
    supplier_name: String(input.supplier_name || '').trim(),
    supplier_company_id: String(input.supplier_company_id || '').replace(/\D/g, '') || null,
    supplier_tax_id: String(input.supplier_tax_id || '').replace(/\s/g, '').toUpperCase() || null,
    document_number: String(input.document_number || '').trim(),
    issue_date: input.issue_date || null,
    taxable_date: input.taxable_date || null,
    due_date: input.due_date || null,
    currency: /^[A-Z]{3}$/.test(String(input.currency || '').toUpperCase()) ? String(input.currency).toUpperCase() : 'CZK',
    exchange_rate: number(input.exchange_rate) > 0 ? number(input.exchange_rate) : 1,
    net_amount: roundMoney(input.net_amount),
    vat_amount: roundMoney(input.vat_amount),
    total_amount: roundMoney(input.total_amount),
    bank_account: input.bank_account || null,
    bank_code: input.bank_code || null,
    iban: input.iban || null,
    swift: input.swift || null,
    variable_symbol: input.variable_symbol || null,
    payment_message: input.payment_message || null,
    category_key: CATEGORY_KEYS.includes(input.category_key) ? input.category_key : 'other',
    subcategory_key: input.subcategory_key || null,
    operational_summary: String(input.operational_summary || '').trim(),
    period_from: input.period_from || null,
    period_to: input.period_to || null,
    target_kind: input.target_kind || null,
    target_hint: input.target_hint || null,
    requires_physical_receipt: Boolean(input.requires_physical_receipt),
    confidence: Math.max(0, Math.min(100, number(input.confidence))),
    warnings: Array.isArray(input.warnings) ? input.warnings.map(String) : [],
    lines
  }
}

export function validateExtraction(doc) {
  const errors = [], warnings = [...(doc.warnings || [])]
  if (!doc.supplier_name) errors.push('Chybí dodavatel.')
  if (!doc.document_number) errors.push('Chybí číslo dokladu.')
  if (!doc.issue_date) warnings.push('Chybí datum vystavení.')
  if (!doc.total_amount) errors.push('Chybí nenulová částka k úhradě.')
  const headerDifference = Math.abs(roundMoney(doc.net_amount + doc.vat_amount - doc.total_amount))
  if (headerDifference > 1) errors.push(`Nesedí součet základu, DPH a celkové částky (rozdíl ${headerDifference.toFixed(2)}).`)
  if (doc.lines.length) {
    const linesTotal = roundMoney(doc.lines.reduce((sum, line) => sum + number(line.total_amount), 0))
    if (linesTotal && Math.abs(linesTotal - doc.total_amount) > 2) warnings.push(`Součet položek se liší od hlavičky o ${Math.abs(linesTotal - doc.total_amount).toFixed(2)}.`)
  }
  if (doc.document_type === 'invoice' && !doc.due_date) warnings.push('Chybí datum splatnosti.')
  if (doc.confidence < 80) warnings.push('Celková jistota vytěžení je nízká.')
  return { errors: [...new Set(errors)], warnings: [...new Set(warnings)] }
}

export function matchSupplier(doc, suppliers = []) {
  const companyId = String(doc.supplier_company_id || '').replace(/\D/g, '')
  if (companyId) {
    const exact = suppliers.find(row => String(row.company_id || '').replace(/\D/g, '') === companyId)
    if (exact) return exact
  }
  const wanted = normalizeText(doc.supplier_name)
  return suppliers.find(row => normalizeText(row.name) === wanted) || null
}

export function matchProduct(line, mappings = [], products = [], supplierId = null) {
  const available = mappings.filter(row => !supplierId || String(row.supplier_id) === String(supplierId))
  const byCode = line.supplier_item_code && available.find(row => normalizeText(row.supplier_item_code) === normalizeText(line.supplier_item_code))
  const byEan = !byCode && line.ean && available.find(row => String(row.ean || '') === String(line.ean))
  const mapping = byCode || byEan
  if (mapping) return { mapping, product: products.find(row => String(row.id) === String(mapping.product_id)) || null, confidence: 100 }
  const description = normalizeText(line.description)
  const candidates = products.filter(row => {
    const name = normalizeText(row.name)
    return description && name && (description.includes(name) || name.includes(description))
  })
  return candidates.length === 1 ? { mapping: null, product: candidates[0], confidence: 78 } : { mapping: null, product: null, confidence: 0 }
}

export function applyRules(doc, rules = []) {
  const output = structuredClone(doc)
  const supplierName = normalizeText(output.supplier_name)
  for (const rule of [...rules].filter(row => row.active !== false).sort((a, b) => Number(a.priority || 100) - Number(b.priority || 100))) {
    const matcher = rule.matcher || {}, outcome = rule.outcome || {}
    if (matcher.supplier_company_id && String(matcher.supplier_company_id) !== String(output.supplier_company_id || '')) continue
    if (matcher.supplier_name_contains && !supplierName.includes(normalizeText(matcher.supplier_name_contains))) continue
    if (matcher.category_key && matcher.category_key !== output.category_key) continue
    if (outcome.category_key && CATEGORY_KEYS.includes(outcome.category_key)) output.category_key = outcome.category_key
    if (outcome.subcategory_key) output.subcategory_key = outcome.subcategory_key
    if (outcome.target_kind) output.target_kind = outcome.target_kind
    if (outcome.target_id) output.target_id = outcome.target_id
    if (outcome.stock_location_id) output.stock_location_id = outcome.stock_location_id
    if (outcome.vehicle_id) output.vehicle_id = outcome.vehicle_id
    if (outcome.machine_id) output.machine_id = outcome.machine_id
    if (outcome.location_id) output.location_id = outcome.location_id
    if (typeof outcome.requires_physical_receipt === 'boolean') output.requires_physical_receipt = outcome.requires_physical_receipt
    output.applied_rule_ids = [...(output.applied_rule_ids || []), rule.id]
  }
  return output
}

export function stateForPlan({ openQuestions = 0, actions = [] } = {}) {
  if (openQuestions > 0) return 'waiting_answer'
  if (actions.some(action => action.status === 'failed')) return 'needs_review'
  if (actions.some(action => action.action_type === 'stock_receipt' && !['completed','skipped','cancelled'].includes(action.status))) return 'waiting_delivery'
  if (actions.some(action => !['completed','skipped','cancelled'].includes(action.status))) return 'ready_to_execute'
  return 'accountant_ready'
}

export function outputText(response) {
  if (response?.output_text) return response.output_text
  for (const item of response?.output || []) {
    for (const content of item?.content || []) if (content?.type === 'output_text' && content.text) return content.text
  }
  return ''
}
