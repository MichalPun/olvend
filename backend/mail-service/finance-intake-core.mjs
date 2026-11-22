const compact = value => String(value ?? '').replace(/\u00a0/g, ' ').replace(/[ \t]+/g, ' ').trim()
const digits = value => String(value ?? '').replace(/\D/g, '')

export function normalizeMatchKey(value) {
  return String(value ?? '').normalize('NFKD').replace(/[\u0300-\u036f]/g, '').replace(/[^a-zA-Z0-9]/g, '').toLowerCase()
}

const AUTO_EVIDENCE_VERSION = '2026-11-v1'

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

const OLMIKA_COMPANY_ID = '04579968'
const OLMIKA_TAX_ID = 'CZ04579968'

function cleanedDocumentNumber(value) {
  const candidate=compact(value).replace(/\.(pdf|isdocx?|xml)$/i,'').replace(/^[#:]+|[.,;:]+$/g,'')
  if (!candidate || !/\d/.test(candidate)) return null
  const key=normalizeMatchKey(candidate)
  if ([normalizeMatchKey(OLMIKA_COMPANY_ID),normalizeMatchKey(OLMIKA_TAX_ID)].includes(key)) return null
  return /^(dodavatel|odberatel|supplier|customer|olmika)$/i.test(key) ? null : candidate
}

function moneyAfterLabels(text, labels) {
  for (const label of labels) {
    const regex=new RegExp(`${label}[^\\d-]{0,36}(-?\\d[\\d \\u00a0.]*[,.]\\d{2})(?!\\d)\\s*(?:Kč|CZK|EUR|USD)?`,'i')
    const raw=text.match(regex)?.[1]
    if(!raw)continue
    const parsed=amount(raw)
    if (parsed!=null) return parsed
  }
  return null
}

function supplierName(text) {
  const lines=String(text||'').split(/\n|\t/).map(compact).filter(Boolean)
  const own=/\bOLMIKA\b/i
  const usable=value=>{
    const clean=compact(value).replace(/^(dodavatel|supplier|prod[aá]vaj[ií]c[ií])\s*[:\-]?\s*/i,'')
    if (!clean || own.test(clean) || /^(i[čc]o?|di[čc]|adresa|s[ií]dlo|bankovn[ií]|telefon|e-?mail)\b/i.test(clean)) return null
    return /(s\.?\s*r\.?\s*o\.?|a\.?\s*s\.?|spol\.?\s+s\.?\s*r\.?\s*o\.?|k\.?\s*s\.?|v\.?\s*o\.?\s*s\.?|gmbh|ltd\.?|limited|inc\.?|se)(?:$|[\s,])/i.test(clean) ? clean : null
  }
  for (let index=0;index<lines.length;index+=1) {
    if (!/^(dodavatel|supplier|prod[aá]vaj[ií]c[ií])\b/i.test(lines[index])) continue
    const inline=usable(lines[index])
    if (inline) return inline
    for (const line of lines.slice(index+1,index+6)) { const candidate=usable(line); if(candidate)return candidate }
  }
  for (const line of lines.slice(0,Math.min(lines.length,60))) { const candidate=usable(line); if(candidate)return candidate }
  return null
}

function supplierIdentifiers(text) {
  const source=String(text||'')
  const labeledCompanyIds=[...source.matchAll(/\b(?:I[ČC]O?|ICO)\s*[:#]?\s*(\d{8})\b/gi)].map(match=>match[1]).filter(value=>value!==OLMIKA_COMPANY_ID)
  const labeledTaxIds=[...source.matchAll(/\b(?:DI[ČC]|VAT(?:\s+ID)?)\s*[:#]?\s*([A-Z]{2}[A-Z0-9]{8,14})\b/gi)].map(match=>match[1].replace(/\s/g,'').toUpperCase())
  const visibleTaxIds=[...source.matchAll(/\b([A-Z]{2}\d{8,14})\b/g)].map(match=>match[1].toUpperCase())
  const supplierTaxId=[...labeledTaxIds,...visibleTaxIds].find(value=>value!==OLMIKA_TAX_ID)||null
  const companyIdFromTax=supplierTaxId?.match(/^CZ(\d{8})$/)?.[1]||null
  return {supplier_company_id:companyIdFromTax||labeledCompanyIds[0]||null,supplier_tax_id:supplierTaxId}
}

function moneyValues(value) {
  return [...String(value||'').matchAll(/-?\d[\d \u00a0.]*[,.]\d{2}(?!\d)/g)].map(match=>amount(match[0])).filter(value=>value!=null)
}

function balancedTaxTriple(values) {
  let best=null
  for(let first=0;first<values.length;first+=1)for(let second=first+1;second<values.length;second+=1)for(let totalIndex=0;totalIndex<values.length;totalIndex+=1){
    if(totalIndex===first||totalIndex===second)continue
    const a=Math.abs(values[first]),b=Math.abs(values[second]),total=Math.abs(values[totalIndex])
    const balanceError=Math.abs(a+b-total)
    if(a<=0||b<=0||total<=Math.max(a,b)||Math.min(a,b)/total<0.01||balanceError>0.6)continue
    const candidate={net_amount:Math.max(a,b),vat_amount:Math.min(a,b),total_amount:total,balance_error:balanceError}
    if(!best||candidate.balance_error<best.balance_error-0.001||(Math.abs(candidate.balance_error-best.balance_error)<=0.001&&candidate.total_amount>best.total_amount))best=candidate
  }
  if(!best)return null
  const {balance_error,...result}=best
  return result
}

function taxSummary(text) {
  const lines=String(text||'').split('\n')
  const candidates=[]
  for(let index=0;index<lines.length;index+=1){
    if(!/(sazba\s+dph|z[aá]klad.*(?:v[yý][šs]e\s+dph|d\s*p\s*h)|rozpis\s+dph|\bcelkem\b)/i.test(lines[index]))continue
    const window=lines.slice(Math.max(0,index-16),Math.min(lines.length,index+10)).join('\n')
    const candidate=balancedTaxTriple(moneyValues(window))
    if(candidate)candidates.push(candidate)
  }
  return candidates.sort((a,b)=>b.total_amount-a.total_amount)[0]||null
}

function labeledDate(text, labels) {
  for (const label of labels) {
    const match = text.match(new RegExp(`${label}[^\\d]{0,24}(\\d{1,2}[.\\/-]\\d{1,2}[.\\/-]\\d{2,4})`,'i'))
    const parsed = isoDate(match?.[1])
    if (parsed) return parsed
  }
  return null
}

function groupedInvoiceDates(text) {
  const source=String(text||'')
  const start=source.search(/datum\s+uskute[čc]n[eě]n[ií].{0,30}pln[eě]n[ií]/i)
  if(start<0)return null
  const window=source.slice(start,start+420)
  if(!/datum\s+vystaven[ií]/i.test(window)||!/datum\s+splatnosti/i.test(window))return null
  const dates=[...window.matchAll(/\b\d{1,2}[.\/-]\d{1,2}[.\/-]\d{2,4}\b/g)].map(match=>isoDate(match[0])).filter(Boolean).slice(0,3)
  if(dates.length<3)return null
  const counts=new Map(dates.map(value=>[value,dates.filter(item=>item===value).length]))
  const repeated=[...counts.entries()].find(([,count])=>count>=2)?.[0]
  if(!repeated)return null
  const due=[...dates].sort().at(-1)
  const issue=new Date(`${repeated}T12:00:00Z`),dueDate=new Date(`${due}T12:00:00Z`)
  if(dueDate<issue||(dueDate-issue)>180*24*60*60*1000)return null
  return {issue_date:repeated,taxable_date:repeated,due_date:due}
}

function labeledAmount(text) {
  const labels = [
    'celkem\\s+k\\s+[uú]hrad[ěe]','částka\\s+k\\s+[uú]hrad[ěe]','k\\s+[uú]hrad[ěe]',
    'grand\\s+total','total\\s+due','celkem\\s+s\\s+dph','celkem'
  ]
  for (const label of labels) {
    const regex = new RegExp(`${label}[^\\d-]{0,30}(-?\\d[\\d \\u00a0.]*[,.]\\d{2})(?!\\d)\\s*(?:Kč|CZK|EUR|USD)?`,'i')
    const parsed = amount(text.match(regex)?.[1])
    if (parsed != null && parsed !== 0) return parsed
  }
  return null
}

function hasMaterialPrepayment(text) {
  const source=String(text||'')
  if(/odpo[čc]et\s+z[aá]lohy/i.test(source))return true
  const paid=source.match(/uhrazeno\s+z[aá]lohou[^\d-]{0,36}(-?\d[\d \u00a0.]*[,.]\d{2})/i)
  return paid ? Math.abs(amount(paid[1])||0)>0.01 : /uhrazeno\s+z[aá]lohou/i.test(source)
}

export function classifyDocument(text, context = {}) {
  const source = `${context.file_name || ''} ${context.subject || ''} ${text || ''}`
  if (/upom[ií]n|reminder|v[yý]zva\s+k\s+[uú]hrad|overdue\s+notice/i.test(source)) return 'reminder'
  if (/dobropis|credit\s+note/i.test(source)) return 'credit_note'
  if (/z[aá]lohov[aá]\s+faktura|proforma/i.test(source)) return 'advance_invoice'
  if (/rozvaha|v[yý]sledovka|da[nň]ov[eé]\s+p[řr]izn[aá]n[ií]|\bDPPO\b|[uú][čc]etn[ií]\s+z[aá]v[eě]rka/i.test(source)) return 'accounting_report'
  if (/r[aá]mcov[aá]\s+smlouva|smlouva\s+o|contract/i.test(source)) return 'contract'
  if (/spl[aá]tkov[yý]\s+kalend[aá][řr]|payment\s+schedule/i.test(source)) return 'payment_schedule'
  if (/faktura|invoice|da[nň]ov[yý]\s+doklad/i.test(source.slice(0,1800))) return 'invoice'
  if (/dodac[ií]\s+list|delivery\s+note/i.test(source)) return 'delivery_note'
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

export function extractInvoiceTextLineItems(text = '') {
  const result=[]
  const unitPattern='(?:ks|kg|g|l|ml|bal|balení|kart|krab|sada|m)'
  const rowPattern=new RegExp(`^(-?\\d[\\d \\u00a0.]*[,.]\\d{2})\\s+(.+?)\\s+([A-Z0-9][A-Z0-9./_-]{0,20})\\s+(${unitPattern})\\s+(\\d{1,2}(?:[,.]\\d+)?)\\s+(\\d[\\d \\u00a0.]*[,.]\\d{3})\\s+(-?\\d[\\d \\u00a0.]*[,.]\\d{2})\\s+(-?\\d[\\d \\u00a0.]*[,.]\\d{2})$`,'i')
  for(const rawLine of String(text||'').split(/\r?\n/)){
    const line=compact(rawLine),match=line.match(rowPattern)
    if(!match)continue
    const unitPrice=amount(match[1]),quantity=amount(match[6]),vatRate=amount(match[5]),firstTotal=amount(match[7]),secondTotal=amount(match[8])
    if([unitPrice,quantity,vatRate,firstTotal,secondTotal].some(value=>value==null)||quantity<=0||unitPrice<=0||vatRate<0||vatRate>30)continue
    const net=Math.min(Math.abs(firstTotal),Math.abs(secondTotal)),gross=Math.max(Math.abs(firstTotal),Math.abs(secondTotal))
    const expectedNet=quantity*unitPrice,expectedGross=net*(1+vatRate/100)
    if(Math.abs(expectedNet-net)>Math.max(1,net*0.02)||Math.abs(expectedGross-gross)>Math.max(1,gross*0.02))continue
    result.push({
      description:compact(match[2]),supplier_item_code:compact(match[3]),unit_code:compact(match[4]).toLowerCase(),
      quantity,unit_price:unitPrice,vat_rate:vatRate,net_amount:Math.round(net*100)/100,
      vat_amount:Math.round((gross-net)*100)/100,total_amount:Math.round(gross*100)/100,source:'money_s3_text_row'
    })
  }
  return result.slice(0,250)
}

export function looksLikeItemizedInvoice(text = '') {
  return /(ozna[čc]en[ií]\s+dod[aá]vky|popis\s+polo[žz]ky|katalog).{0,100}(po[čc]et|mno[žz]stv[ií]).{0,100}(cena\s+za|jednotkov[aá]\s+cena)/is.test(String(text||''))
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
  const documentNumberCandidates = [firstMatch(source,[
    /(?:faktura|daňový\s+doklad)(?:\s+(?:vydan[aá]|přijat[aá]))?(?:\s+(?:č(?:íslo)?\.?|number|no\.?))?\s*[:#]?\s*([A-Z0-9][A-Z0-9./_-]{3,35})/i,
    /(?:invoice)(?:\s+(?:number|no\.?|#))?\s*[:#]?\s*([A-Z0-9][A-Z0-9./_-]{3,35})/i,
    /(?:číslo\s+dokladu|doklad\s+č\.?)\s*[:#]?\s*([A-Z0-9][A-Z0-9./_-]{3,35})/i
  ]),firstMatch(context.file_name || '',[/\b(\d{6,14}(?:[\/_-]\d{1,8})?)\b/i]),firstMatch(`${context.file_name || ''} ${context.subject || ''}`,[
    /(?:faktura|invoice)[^A-Z0-9]{0,20}([A-Z0-9][A-Z0-9./_-]{3,35})/i,
    /\b(\d{6,14}(?:[\/_-]\d{1,8})?)\b/i
  ])]
  const documentNumber=documentNumberCandidates.map(cleanedDocumentNumber).find(Boolean)||null
  const variableSymbol = digits(firstMatch(source,[/variabiln[ií]\s+symbol\s*[:#]?\s*([0-9][0-9 .\/-]{2,20})/i,/\bVS\s*[:#]\s*([0-9][0-9 .\/-]{2,20})/i])).slice(0,10) || null
  const iban = firstMatch(source,[/\bIBAN\s*[:#]?\s*(CZ\s*\d{2}(?:\s*\d){20})/i,/\bIBAN\s*[:#]?\s*([A-Z]{2}\s*\d{2}(?:\s*[A-Z0-9]){11,26})(?:\n|$)/i])?.replace(/\s/g,'').toUpperCase() || null
  const accountRaw = firstMatch(source,[/(?:číslo\s+účtu|bankovní\s+účet|účet)\s*[:#]?\s*((?:\d{1,6}-)?\d{2,10}\s*\/\s*\d{4})/i,/(?:bankovní\s+účet)[^\n]*\n\s*((?:\d{1,6}-)?\d{2,10}\s+\d{4})/i,/\b((?:\d{1,6}-)?\d{2,10}\s+\d{4})\s+Číslo\s+účtu/i,/\b((?:\d{1,6}-)?\d{2,10}\s*\/\s*\d{4})\b/])
  const account = accountRaw ? (accountRaw.includes('/')?accountRaw:accountRaw.replace(/\s+(\d{4})$/,'/$1')).replace(/\s/g,'') : null
  const summary=['invoice','credit_note'].includes(documentClass)?taxSummary(source):null
  let totalAmount = summary?.total_amount??labeledAmount(source)
  let netAmount=moneyAfterLabels(source,['celkem\\s+bez\\s+dph','z[aá]klad\\s+dan[ěe]\\s+celkem','tax\\s+exclusive\\s+amount','subtotal'])
  let vatAmount=moneyAfterLabels(source,['dph\\s+celkem','da[nň]\\s+celkem','celkov[aá]\\s+v[yý][šs]e\\s+dph','tax\\s+amount','vat\\s+total'])
  if(summary){netAmount=summary.net_amount;vatAmount=summary.vat_amount;totalAmount=summary.total_amount}
  if (totalAmount!=null&&netAmount!=null&&vatAmount==null) vatAmount=Math.round((totalAmount-netAmount)*100)/100
  if (totalAmount!=null&&vatAmount!=null&&netAmount==null) netAmount=Math.round((totalAmount-vatAmount)*100)/100
  if (totalAmount!=null&&netAmount!=null&&vatAmount!=null&&Math.abs(netAmount+vatAmount-totalAmount)>1) { netAmount=null;vatAmount=null }
  const currency = /\bEUR\b|€/.test(source) ? 'EUR' : /\bUSD\b|\$/.test(source) ? 'USD' : 'CZK'
  const groupedDates=groupedInvoiceDates(source)
  const issueDate = groupedDates?.issue_date||labeledDate(source,['(?:datum\\s+)?vystaven[ií]','vystaveno','issue\\s+date'])
  const taxableDate = groupedDates?.taxable_date||labeledDate(source,['datum\\s+uskutečněn[ií].{0,12}plněn[ií]','duzp','tax\\s+date'])
  const dueDate = groupedDates?.due_date||labeledDate(source,['datum\\s+splatnosti','splatnost','due\\s+date'])
  const documentType = documentClass==='credit_note'?'credit_note':documentClass==='advance_invoice'?'advance_invoice':documentClass==='invoice'?'invoice':'other'
  const supplier=supplierName(String(text||'')),identifiers=supplierIdentifiers(source)
  const warnings = []
  if (!supplier&&['invoice','credit_note','advance_invoice'].includes(documentClass)) warnings.push('Chybí dodavatel')
  if (!documentNumber) warnings.push('Chybí číslo dokladu')
  if (totalAmount == null) warnings.push('Chybí celková částka')
  if (totalAmount!=null&&netAmount==null&&vatAmount==null&&['invoice','credit_note'].includes(documentClass)) warnings.push('Základ a DPH je potřeba ověřit')
  if (!account && !iban) warnings.push('Chybí bankovní účet')
  if (!issueDate) warnings.push('Chybí datum vystavení')
  if (!dueDate) warnings.push('Chybí datum splatnosti')
  if (hasMaterialPrepayment(source)) warnings.push('Doklad obsahuje vyúčtování zálohy; úhradu je potřeba ověřit')
  const recognized = [documentNumber,totalAmount,account||iban,variableSymbol,dueDate,supplier,netAmount!=null||vatAmount!=null,identifiers.supplier_company_id||identifiers.supplier_tax_id].filter(value=>value!=null&&value!==false).length
  return {
    document_number:documentNumber,document_type:documentType,document_class:documentClass,
    reference_numbers:[...new Set([documentNumber,variableSymbol,...referenceNumbers(`${source} ${context.file_name||''} ${context.subject||''}`)].filter(Boolean))],
    issue_date:issueDate,taxable_date:taxableDate,due_date:dueDate,
    supplier_name:supplier,...identifiers,
    currency,net_amount:netAmount,vat_amount:vatAmount,total_amount:totalAmount,bank_account:account,iban,variable_symbol:variableSymbol,
    confidence:Math.min(98,25 + recognized * 10),warnings,text_excerpt:source.slice(0,12000)
  }
}

function validIsoDate(value) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(String(value || ''))) return null
  const date = new Date(`${value}T12:00:00Z`)
  return Number.isNaN(date.getTime()) ? null : date
}

function invoiceKeyMatches(extracted, invoice) {
  const sourceKeys=[extracted?.document_number,extracted?.variable_symbol].map(normalizeMatchKey).filter(key=>key.length>=5)
  const invoiceKeys=[invoice?.document_number,invoice?.variable_symbol,invoice?.money_internal_number].map(normalizeMatchKey).filter(key=>key.length>=5)
  if (!sourceKeys.some(key=>invoiceKeys.includes(key))) return false
  return Math.abs(Math.abs(Number(invoice?.total_amount || 0))-Math.abs(Number(extracted?.total_amount || 0)))<=1
}

export function assessAutoEvidence(extracted, invoices = [], context = {}) {
  const reasons=[]
  const requiredText=(value)=>String(value || '').trim()
  const total=Number(extracted?.total_amount),net=Number(extracted?.net_amount),vat=Number(extracted?.vat_amount)
  const issueDate=validIsoDate(extracted?.issue_date),dueDate=validIsoDate(extracted?.due_date)
  const receivedAt=context.received_at ? new Date(context.received_at) : null
  if (extracted?.document_class!=='invoice') reasons.push('Automaticky se evidují pouze běžné faktury')
  if (Number(extracted?.confidence || 0)<95) reasons.push('Jistota vytěžení je nižší než 95 %')
  if (!requiredText(extracted?.supplier_name)) reasons.push('Chybí dodavatel')
  if (!requiredText(extracted?.supplier_company_id) && !requiredText(extracted?.supplier_tax_id)) reasons.push('Chybí jednoznačný identifikátor dodavatele')
  if (normalizeMatchKey(extracted?.document_number).length<4) reasons.push('Chybí použitelné číslo dokladu')
  if (!Number.isFinite(total) || total<=0) reasons.push('Celková částka není kladná a jednoznačná')
  if (!Number.isFinite(net) || !Number.isFinite(vat) || Math.abs(net+vat-total)>1) reasons.push('Rozpad základu, DPH a celku není vyvážený')
  if (!issueDate) reasons.push('Chybí platné datum vystavení')
  if (!dueDate) reasons.push('Chybí platné datum splatnosti')
  if (issueDate&&dueDate&&dueDate<issueDate) reasons.push('Datum splatnosti je před datem vystavení')
  if (issueDate&&receivedAt&&!Number.isNaN(receivedAt.getTime())) {
    const deltaDays=(issueDate-receivedAt)/(24*60*60*1000)
    if (deltaDays>31 || deltaDays< -550) reasons.push('Datum vystavení je mimo bezpečné období vůči přijetí e-mailu')
  }
  if (!requiredText(extracted?.bank_account) && !requiredText(extracted?.iban)) reasons.push('Chybí účet dodavatele')
  if (!/^[A-Z]{3}$/.test(requiredText(extracted?.currency))) reasons.push('Měna není jednoznačná')
  if (String(extracted?.extraction_method || '').includes('ocr') && Number(extracted?.ocr_confidence || 0)<75) reasons.push('OCR má jistotu nižší než 75 %')
  if ((extracted?.warnings || []).length) reasons.push(...extracted.warnings.map(value=>String(value)))
  if (invoices.some(invoice=>invoiceKeyMatches(extracted,invoice))) reasons.push('Doklad se shoduje s fakturou, která už je v evidenci')
  return {version:AUTO_EVIDENCE_VERSION,eligible:reasons.length===0,reasons:[...new Set(reasons)]}
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
