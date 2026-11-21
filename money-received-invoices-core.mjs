function escapeRegExp(value) {
  return String(value).replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
}

function blocks(xml, tag) {
  const safe = escapeRegExp(tag)
  const pattern = new RegExp(`<${safe}(?:\\s[^>]*)?>([\\s\\S]*?)<\\/${safe}>`, 'gi')
  return Array.from(String(xml || '').matchAll(pattern), (match) => match[1])
}

function decodeXml(value) {
  return String(value ?? '')
    .replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, '$1')
    .replace(/&#x([0-9a-f]+);/gi, (_, code) => String.fromCodePoint(Number.parseInt(code, 16)))
    .replace(/&#([0-9]+);/g, (_, code) => String.fromCodePoint(Number(code)))
    .replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'").replace(/&amp;/g, '&').trim()
}

function text(xml, tag) {
  return decodeXml(blocks(xml, tag)[0] || '')
}

function attribute(xml, tag, name) {
  const match = String(xml || '').match(new RegExp(`<${escapeRegExp(tag)}\\b[^>]*\\b${escapeRegExp(name)}=["']([^"']*)["']`, 'i'))
  return decodeXml(match?.[1] || '')
}

function number(value) {
  const parsed = Number(String(value ?? '').replace(/\s/g, '').replace(',', '.'))
  return Number.isFinite(parsed) ? Math.round(parsed * 100) / 100 : 0
}

function date(value) {
  return String(value || '').match(/\d{4}-\d{2}-\d{2}/)?.[0] || null
}

function guid(value) {
  return String(value || '').trim().replace(/^\{|\}$/g, '').toLowerCase() || null
}

function vatAmount(row) {
  const summary = blocks(row, 'SouhrnDPH')[0] || ''
  return ['DPH0', 'DPH5', 'DPH22'].reduce((sum, tag) => sum + number(text(summary, tag)), 0)
}

function currency(row) {
  const foreign = blocks(row, 'Valuty')[0] || ''
  const code = text(foreign, 'Mena') || text(foreign, 'Typ') || 'CZK'
  return /^[A-Z]{3}$/.test(code.toUpperCase()) ? code.toUpperCase() : 'CZK'
}

export function parseMoneyReceivedInvoicesXml(xml) {
  const source = String(xml || '').replace(/^\uFEFF/, '').trim()
  if (!/<MoneyData\b/i.test(source)) throw new Error('Soubor není nativní XML export Money S3.')

  const invoiceBlocks = blocks(source, 'FaktPrij')
  if (!invoiceBlocks.length) throw new Error('XML neobsahuje žádné přijaté faktury FaktPrij.')

  const rows = invoiceBlocks.map((row, index) => {
    const supplier = blocks(row, 'DodOdb')[0] || ''
    const paymentBlock = blocks(row, 'Uhrada')[0] || ''
    const total = number(text(row, 'Celkem'))
    const vat = vatAmount(row)
    const internalNumber = text(row, 'Doklad') || `MONEY-${index + 1}`
    const documentNumber = text(row, 'PrijatDokl') || text(row, 'VarSymbol') || internalNumber
    const remaining = number(text(row, 'PriUhrZbyv'))
    const mainGuid = guid(text(row, 'GUID')) || `number:${internalNumber.toLowerCase()}`
    const bankAccount = text(supplier, 'Ucet') || null
    const bankCode = text(supplier, 'KodBanky') || null
    return {
      money_guid: mainGuid,
      money_internal_number: internalNumber,
      money_series: text(row, 'Rada') || null,
      money_series_number: Number(text(row, 'CisRada') || 0) || null,
      money_partner_guid: guid(text(supplier, 'GUID')),
      supplier_name: text(supplier, 'ObchNazev') || text(supplier, 'FaktNazev') || 'Neznámý dodavatel',
      supplier_company_id: text(supplier, 'ICO') || null,
      supplier_tax_id: text(supplier, 'DIC') || null,
      document_number: documentNumber,
      document_type: text(row, 'Dobropis') === '1' ? 'credit_note' : 'invoice',
      description: text(row, 'Popis') || null,
      issue_date: date(text(row, 'Vystaveno')),
      taxable_date: date(text(row, 'PlnenoDPH')) || date(text(row, 'DatUcPr')),
      due_date: date(text(row, 'Splatno')),
      received_date: date(text(row, 'Doruceno')),
      currency: currency(row),
      exchange_rate: 1,
      net_amount: Math.round((total - vat) * 100) / 100,
      vat_amount: vat,
      total_amount: total,
      remaining_amount: remaining,
      paid_date: Math.abs(remaining) < 0.01 ? date(text(paymentBlock, 'Datum')) : null,
      variable_symbol: text(row, 'VarSymbol') || null,
      bank_account: bankAccount,
      bank_code: bankCode,
      payment_method: paymentBlock.includes('<') ? null : decodeXml(paymentBlock) || null,
    }
  })

  const warnings = []
  const withoutCompanyId = rows.filter((row) => !row.supplier_company_id).length
  const withoutSupplierDocument = rows.filter((row) => row.document_number === row.money_internal_number).length
  const zeroAmount = rows.filter((row) => row.total_amount === 0).length
  if (withoutCompanyId) warnings.push(`${withoutCompanyId} dokladům chybí IČ dodavatele.`)
  if (withoutSupplierDocument) warnings.push(`${withoutSupplierDocument} dokladům chybí číslo dodavatele nebo variabilní symbol.`)
  if (zeroAmount) warnings.push(`${zeroAmount} dokladů má nulovou celkovou částku.`)

  return {
    format: 'money_s3_received_invoices',
    agenda_id: attribute(source, 'MoneyData', 'ICAgendy') || null,
    accounting_year_start: date(attribute(source, 'MoneyData', 'HospRokOd')),
    accounting_year_end: date(attribute(source, 'MoneyData', 'HospRokDo')),
    exported_at: date(attribute(source, 'MoneyData', 'ExpDate')),
    rows,
    warnings,
    summary: {
      invoices: rows.length,
      credit_notes: rows.filter((row) => row.document_type === 'credit_note').length,
      unpaid: rows.filter((row) => Math.abs(row.remaining_amount) >= 0.01).length,
      zero_amount: zeroAmount,
      total_amount: Math.round(rows.reduce((sum, row) => sum + row.total_amount, 0) * 100) / 100,
      remaining_amount: Math.round(rows.reduce((sum, row) => sum + row.remaining_amount, 0) * 100) / 100,
    },
  }
}

export async function sha256Hex(buffer) {
  const digest = await crypto.subtle.digest('SHA-256', buffer)
  return Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, '0')).join('')
}
