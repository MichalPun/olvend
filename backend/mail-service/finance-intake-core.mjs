const compact = value => String(value ?? '').replace(/\u00a0/g, ' ').replace(/[ \t]+/g, ' ').trim()
const digits = value => String(value ?? '').replace(/\D/g, '')

export function normalizeMatchKey(value) {
  return String(value ?? '').normalize('NFKD').replace(/[\u0300-\u036f]/g, '').replace(/[^a-zA-Z0-9]/g, '').toLowerCase()
}

function firstMatch(text, patterns) {
  for (const pattern of patterns) {
    const match = text.match(pattern)
    if (match?.[1]) return compact(match[1]).replace(/[.,;:]$/,'')
  }
  return null
}

function isoDate(value) {
  const match = String(value || '').match(/\b(\d{1,2})[.\/-](\d{1,2})[.\/-](\d{2,4})\b/)
  if (!match) return null
  const year = Number(match[3]) < 100 ? 2000 + Number(match[3]) : Number(match[3])
  const month = Number(match[2]), day = Number(match[1])
  const date = new Date(Date.UTC(year,month-1,day))
  if (date.getUTCFullYear() !== year || date.getUTCMonth() !== month-1 || date.getUTCDate() !== day) return null
  return `${year}-${String(month).padStart(2,'0')}-${String(day).padStart(2,'0')}`
}

function amount(value) {
  const cleaned = String(value || '').replace(/\u00a0/g,' ').replace(/[^0-9,.-]/g,'').replace(/\.(?=\d{3}(?:\D|$))/g,'').replace(',','.')
  const result = Number(cleaned)
  return Number.isFinite(result) ? Math.round(result * 100) / 100 : null
}

function labeledDate(text, labels) {
  for (const label of labels) {
    const match = text.match(new RegExp(`${label}[^\\d]{0,24}(\\d{1,2}[.\\/-]\\d{1,2}[.\\/-]\\d{2,4})`,'i'))
    const parsed = isoDate(match?.[1])
    if (parsed) return parsed
  }
  return null
}

function labeledAmount(text) {
  const labels = [
    'celkem\\s+k\\s+[uú]hrad[ěe]','částka\\s+k\\s+[uú]hrad[ěe]','k\\s+[uú]hrad[ěe]',
    'grand\\s+total','total\\s+due','celkem\\s+s\\s+dph','celkem'
  ]
  for (const label of labels) {
    const regex = new RegExp(`${label}[^\\d-]{0,30}(-?\\d[\\d \\u00a0.]*[,.]\\d{2})\\s*(?:Kč|CZK|EUR|USD)?`,'i')
    const parsed = amount(text.match(regex)?.[1])
    if (parsed != null && parsed !== 0) return parsed
  }
  return null
}

export function classifyDocument(text, context = {}) {
  const source = `${context.file_name || ''} ${context.subject || ''} ${text || ''}`
  if (/upom[ií]n|reminder|v[yý]zva\s+k\s+[uú]hrad|overdue\s+notice/i.test(source)) return 'reminder'
  if (/dobropis|credit\s+note/i.test(source)) return 'credit_note'
  if (/z[aá]lohov[aá]\s+faktura|proforma/i.test(source)) return 'advance_invoice'
  if (/dodac[ií]\s+list|delivery\s+note/i.test(source)) return 'delivery_note'
  if (/rozvaha|v[yý]sledovka|da[nň]ov[eé]\s+p[řr]izn[aá]n[ií]|\bDPPO\b|[uú][čc]etn[ií]\s+z[aá]v[eě]rka/i.test(source)) return 'accounting_report'
  if (/r[aá]mcov[aá]\s+smlouva|smlouva\s+o|contract/i.test(source)) return 'contract'
  if (/spl[aá]tkov[yý]\s+kalend[aá][řr]|payment\s+schedule/i.test(source)) return 'payment_schedule'
  if (/faktura|invoice|da[nň]ov[yý]\s+doklad/i.test(source)) return 'invoice'
  return 'other'
}

function referenceNumbers(text) {
  const matches = []
  const patterns = [
    /(?:faktura|invoice|doklad)(?:\s+(?:č(?:íslo)?\.?|number|no\.?|#))?\s*[:#]?\s*([A-Z0-9][A-Z0-9./_-]{3,35})/gi,
    /(?:variabiln[ií]\s+symbol|\bVS)\s*[:#]?\s*([0-9][0-9 .\/-]{2,20})/gi
  ]
  for (const pattern of patterns) for (const match of String(text || '').matchAll(pattern)) if (match[1]) matches.push(compact(match[1]).replace(/[.,;:]$/,''))
  return [...new Set(matches)]
}

const headerKey = value => normalizeMatchKey(value)
const cellAmount = value => amount(String(value || '').replace(/\s*(Kč|CZK|EUR|USD)\s*$/i,''))

export function extractInvoiceLineItems(tablePages = []) {
  const result=[]
  const tables=[]
  for (const page of tablePages || []) for (const table of page?.tables || []) if (Array.isArray(table)) tables.push(table)
  for (const table of tables) {
    const headerIndex=table.findIndex(row=>{const keys=(row||[]).map(headerKey);return keys.some(key=>/popis|nazev|polozka|description/.test(key))&&keys.some(key=>/mnozstvi|qty|quantity|pocet/.test(key))})
    if (headerIndex<0) continue
    const headers=table[headerIndex].map(headerKey)
    const indexOf=patterns=>headers.findIndex(key=>patterns.some(pattern=>pattern.test(key)))
    const descriptionIndex=indexOf([/popis/,/nazev/,/polozka/,/description/])
    const quantityIndex=indexOf([/mnozstvi/,/qty/,/quantity/,/pocet/])
    const unitIndex=indexOf([/^mj$/,/^jednotka$/,/^unit$/])
    const unitPriceIndex=indexOf([/jednotk.*cena/,/cena.*mj/,/unitprice/,/^cena$/])
    const totalIndex=indexOf([/celkem/,/total/])
    const codeIndex=indexOf([/kod/,/code/,/artikl/])
    const eanIndex=indexOf([/ean/,/barcode/])
    for (const row of table.slice(headerIndex+1)) {
      const description=compact(row?.[descriptionIndex])
      const quantity=cellAmount(row?.[quantityIndex])
      if (!description || quantity==null || quantity<=0) continue
      const item={description,quantity,unit_code:unitIndex>=0?compact(row?.[unitIndex])||null:null,unit_price:unitPriceIndex>=0?cellAmount(row?.[unitPriceIndex]):null,total_amount:totalIndex>=0?cellAmount(row?.[totalIndex]):null,supplier_item_code:codeIndex>=0?compact(row?.[codeIndex])||null:null,ean:eanIndex>=0?digits(row?.[eanIndex])||null:null}
      if (!item.ean) {
        const inlineEan=description.match(/\b(\d{8}|\d{12,14})\b/)?.[1]
        if (inlineEan)item.ean=inlineEan
      }
      result.push(item)
    }
  }
  return result.slice(0,250)
}

export function isLikelyInlineImage(row) {
  const name = String(row?.file_name || '').toLowerCase()
  const size = Number(row?.size_bytes || 0)
  if (!/\.(png|jpe?g|gif|webp)$/.test(name)) return false
  return size < 1500 || (size < 12000 && /(logo|pastedgraphic|image00\d|signature|podpis)/i.test(name))
}

export function extractInvoiceFields(text, context = {}) {
  const source = compact(String(text || '').replace(/\r/g,'\n').replace(/\n{2,}/g,'\n'))
  const documentClass=classifyDocument(source,context)
  const documentNumber = firstMatch(source,[
    /(?:faktura|daňový\s+doklad)(?:\s+(?:vydan[aá]|přijat[aá]))?(?:\s+(?:č(?:íslo)?\.?|number|no\.?))?\s*[:#]?\s*([A-Z0-9][A-Z0-9./_-]{3,35})/i,
    /(?:invoice)(?:\s+(?:number|no\.?|#))?\s*[:#]?\s*([A-Z0-9][A-Z0-9./_-]{3,35})/i,
    /(?:číslo\s+dokladu|doklad\s+č\.?)\s*[:#]?\s*([A-Z0-9][A-Z0-9./_-]{3,35})/i
  ]) || firstMatch(`${context.file_name || ''} ${context.subject || ''}`,[
    /(?:faktura|invoice)[^A-Z0-9]{0,20}([A-Z0-9][A-Z0-9./_-]{4,35})/i
  ])
  const variableSymbol = digits(firstMatch(source,[/variabiln[ií]\s+symbol\s*[:#]?\s*([0-9][0-9 .\/-]{2,20})/i,/\bVS\s*[:#]\s*([0-9][0-9 .\/-]{2,20})/i])).slice(0,10) || null
  const iban = firstMatch(source,[/\bIBAN\s*[:#]?\s*([A-Z]{2}\s*[0-9A-Z](?:\s*[0-9A-Z]){13,32})/i])?.replace(/\s/g,'').toUpperCase() || null
  const account = firstMatch(source,[/(?:číslo\s+účtu|bankovní\s+účet|účet)\s*[:#]?\s*((?:\d{1,6}-)?\d{2,10}\s*\/\s*\d{4})/i])?.replace(/\s/g,'') || null
  const totalAmount = labeledAmount(source)
  const currency = /\bEUR\b|€/.test(source) ? 'EUR' : /\bUSD\b|\$/.test(source) ? 'USD' : 'CZK'
  const issueDate = labeledDate(source,['datum\\s+vystaven[ií]','vystaveno','issue\\s+date'])
  const taxableDate = labeledDate(source,['datum\\s+uskutečněn[ií].{0,12}plněn[ií]','duzp','tax\\s+date'])
  const dueDate = labeledDate(source,['datum\\s+splatnosti','splatnost','due\\s+date'])
  const documentType = documentClass==='credit_note'?'credit_note':documentClass==='advance_invoice'?'advance_invoice':documentClass==='invoice'?'invoice':'other'
  const warnings = []
  if (!documentNumber) warnings.push('Chybí číslo dokladu')
  if (totalAmount == null) warnings.push('Chybí celková částka')
  if (!account && !iban) warnings.push('Chybí bankovní účet')
  if (!dueDate) warnings.push('Chybí datum splatnosti')
  const recognized = [documentNumber,totalAmount,account||iban,variableSymbol,dueDate].filter(value=>value!=null).length
  return {
    document_number:documentNumber,document_type:documentType,document_class:documentClass,
    reference_numbers:[...new Set([documentNumber,variableSymbol,...referenceNumbers(`${source} ${context.file_name||''} ${context.subject||''}`)].filter(Boolean))],
    issue_date:issueDate,taxable_date:taxableDate,due_date:dueDate,
    currency,total_amount:totalAmount,bank_account:account,iban,variable_symbol:variableSymbol,
    confidence:Math.min(95,35 + recognized * 12),warnings,text_excerpt:source.slice(0,8000)
  }
}

export function findUniqueInvoiceMatch(extracted, invoices = []) {
  const keys = [extracted?.document_number,extracted?.variable_symbol,...(extracted?.reference_numbers||[])].map(normalizeMatchKey).filter(key=>key.length>=5)
  if (!keys.length) return null
  const matches = invoices.filter(invoice => {
    const invoiceKeys = [invoice.document_number,invoice.variable_symbol,invoice.money_internal_number].map(normalizeMatchKey).filter(Boolean)
    if (!keys.some(key=>invoiceKeys.includes(key))) return false
    if (extracted.total_amount == null) return true
    return Math.abs(Math.abs(Number(invoice.total_amount || 0))-Math.abs(Number(extracted.total_amount))) < 1.01
  })
  return matches.length === 1 ? matches[0] : null
}
