import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { XMLParser } from 'https://esm.sh/fast-xml-parser@4.5.3'
import {
  CATEGORY_KEYS, applyRules, matchProduct, matchSupplier, normalizeExtraction,
  normalizeText, outputText, validateExtraction
} from '../_shared/finance-ai/core.mjs'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') || ''
const SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || ''
const OPENAI_API_KEY = Deno.env.get('OPENAI_API_KEY') || ''
const MODEL = Deno.env.get('OPENAI_FINANCE_MODEL') || 'gpt-6.2-astra'
const INPUT_COST_PER_MILLION = Number(Deno.env.get('OPENAI_FINANCE_INPUT_COST_PER_MILLION') || 0)
const OUTPUT_COST_PER_MILLION = Number(Deno.env.get('OPENAI_FINANCE_OUTPUT_COST_PER_MILLION') || 0)
const admin = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { persistSession: false, autoRefreshToken: false } })

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS'
}

function json(value: unknown, status = 200) {
  return new Response(JSON.stringify(value), { status, headers: { ...cors, 'Content-Type': 'application/json; charset=utf-8' } })
}

function dataUrl(mime: string, bytes: Uint8Array) {
  let binary = ''
  const chunk = 0x8000
  for (let i = 0; i < bytes.length; i += chunk) binary += String.fromCharCode(...bytes.subarray(i, i + chunk))
  return `data:${mime};base64,${btoa(binary)}`
}

function safeDate(value: unknown) {
  const text = String(value || '')
  return /^\d{4}-\d{2}-\d{2}$/.test(text) ? text : null
}

function uniqueKey(prefix: string, invoiceId: number, suffix = 'document') {
  return `${prefix}:${invoiceId}:${suffix}`
}

const xmlParser = new XMLParser({ ignoreAttributes:false, attributeNamePrefix:'', removeNSPrefix:true, trimValues:true, parseTagValue:false })
const first = (value:any) => Array.isArray(value) ? value[0] : value
const xmlValue = (value:any) => {
  const node=first(value)
  if (node == null) return null
  if (typeof node === 'object') return node['#text'] == null ? null : String(node['#text']).trim()
  return String(node).trim()
}
const xmlNumber = (value:any) => {
  const parsed=Number(String(xmlValue(value) ?? '').replace(/\s/g,'').replace(',','.'))
  return Number.isFinite(parsed) ? parsed : null
}
const xmlArray = (value:any) => value == null ? [] : Array.isArray(value) ? value : [value]

function parseIsdoc(xml:string) {
  const parsed=xmlParser.parse(xml)
  const invoice=first(parsed?.Invoice || parsed?.InvoiceDocument || parsed?.CreditNote)
  if (!invoice || typeof invoice!=='object') throw new Error('V XML není platná ISDOC faktura.')
  const supplier=first(invoice.AccountingSupplierParty),party=first(supplier?.Party || supplier)
  const partyName=first(party?.PartyName),legal=first(party?.PartyLegalEntity),identification=first(party?.PartyIdentification)
  const taxScheme=first(party?.PartyTaxScheme),payment=first(invoice.PaymentMeans),accounts=first(payment?.PaymentMeansAccounts)
  const account=first(accounts?.PaymentMeansAccount || payment?.PaymentMeansAccount || accounts)
  const monetary=first(invoice.LegalMonetaryTotal || invoice.MonetaryTotal),taxTotal=first(invoice.TaxTotal)
  const rawLines=xmlArray(invoice.InvoiceLines?.InvoiceLine || invoice.InvoiceLine || invoice.CreditNoteLines?.CreditNoteLine || invoice.CreditNoteLine)
  const lines=rawLines.map((raw:any,index:number)=>{
    const line=first(raw)||{},item=first(line.Item)||{},qty=first(line.InvoicedQuantity || line.CreditedQuantity)
    const sellers=first(item.SellersItemIdentification),catalogue=first(item.CatalogueItemIdentification)
    const tax=first(line.ClassifiedTaxCategory || item.ClassifiedTaxCategory),lineTax=first(line.TaxTotal)
    const net=xmlNumber(line.LineExtensionAmount),vat=xmlNumber(lineTax?.TaxAmount),rate=xmlNumber(tax?.Percent)
    const quantity=xmlNumber(qty)
    return {
      line_number:index+1,source_line_id:xmlValue(line.ID),supplier_item_code:xmlValue(sellers?.ID),ean:xmlValue(catalogue?.ID),
      description:xmlValue(item.Description) || xmlValue(item.Name) || `Položka ${index+1}`,
      quantity:quantity ?? 0,unit_code:qty?.unitCode || null,unit_price_net:xmlNumber(line.UnitPrice || line.Price?.PriceAmount),
      net_amount:net ?? 0,vat_rate:rate,vat_amount:vat ?? (net != null && rate != null ? net*rate/100 : 0),
      total_amount:xmlNumber(line.LineExtensionAmountTaxInclusive) ?? ((net ?? 0)+(vat ?? 0)),
      lot_code:null,best_before_date:null,use_by_date:null
    }
  }).filter((line:any)=>line.description || line.quantity || line.total_amount)
  const documentTypeCode=xmlValue(invoice.InvoiceTypeCode || invoice.CreditNoteTypeCode)
  return {
    document_type:parsed?.CreditNote || ['381','383'].includes(String(documentTypeCode||'')) ? 'credit_note' : 'invoice',
    supplier_name:xmlValue(partyName?.Name) || xmlValue(party?.Name),
    supplier_company_id:xmlValue(legal?.CompanyID) || xmlValue(identification?.ID),
    supplier_tax_id:xmlValue(taxScheme?.CompanyID),document_number:xmlValue(invoice.ID),
    issue_date:xmlValue(invoice.IssueDate),taxable_date:xmlValue(invoice.TaxPointDate),due_date:xmlValue(invoice.DueDate),
    currency:xmlValue(invoice.ForeignCurrencyCode || invoice.DocumentCurrencyCode || invoice.CurrencyCode || invoice.LocalCurrencyCode) || 'CZK',
    exchange_rate:xmlNumber(invoice.CurrRate || invoice.ExchangeRate) ?? 1,
    net_amount:xmlNumber(monetary?.TaxExclusiveAmount),vat_amount:xmlNumber(taxTotal?.TaxAmount),
    total_amount:xmlNumber(monetary?.PayableAmount || monetary?.TaxInclusiveAmount),
    bank_account:xmlValue(account?.ID),bank_code:xmlValue(account?.BankCode),iban:xmlValue(account?.IBAN),swift:xmlValue(account?.BIC || account?.SWIFT),
    variable_symbol:xmlValue(invoice.VariableSymbol || payment?.PaymentReference),payment_message:xmlValue(payment?.PaymentMessage),lines
  }
}

function mergeExactDocument(ai:any,exact:any) {
  const merged={...ai}
  for (const key of ['document_type','supplier_name','supplier_company_id','supplier_tax_id','document_number','issue_date','taxable_date','due_date','currency','exchange_rate','net_amount','vat_amount','total_amount','bank_account','bank_code','iban','swift','variable_symbol','payment_message']) {
    if (exact[key] !== null && exact[key] !== undefined && exact[key] !== '') merged[key]=exact[key]
  }
  if (exact.lines?.length) merged.lines=exact.lines.map((line:any,index:number)=>({
    ...line,category_key:ai.lines?.[index]?.category_key || ai.category_key || null,confidence:100,
    warnings:ai.lines?.[index]?.warnings || []
  }))
  merged.warnings=[...(ai.warnings || []),'Částky a položky byly převzaty přesným parserem ISDOC/XML.']
  return normalizeExtraction(merged)
}

async function authorize(req: Request) {
  const token = String(req.headers.get('Authorization') || '').replace(/^Bearer\s+/i, '')
  if (!token) throw Object.assign(new Error('Přihlášení je povinné.'), { status: 401 })
  if (token === SERVICE_KEY) return { user:{ id:'service_role' }, employee:{ id:null,role:'service_role',active:true } }
  const { data: { user }, error } = await admin.auth.getUser(token)
  if (error || !user) throw Object.assign(new Error('Přihlášení není platné.'), { status: 401 })
  const { data: employee } = await admin.from('employees').select('id,role,active').eq('auth_user_id', user.id).maybeSingle()
  if (!employee || employee.active === false || !/(admin|manager|manaž|manaz|vedouc|majitel|finance)/i.test(String(employee.role || ''))) {
    throw Object.assign(new Error('Pro zpracování finančních dokladů nemáte oprávnění.'), { status: 403 })
  }
  return { user, employee }
}

const lineSchema = {
  type: 'object', additionalProperties: false,
  properties: {
    line_number: { type: 'integer' }, source_line_id: { type: ['string','null'] },
    supplier_item_code: { type: ['string','null'] }, ean: { type: ['string','null'] },
    description: { type: 'string' }, quantity: { type: 'number' }, unit_code: { type: ['string','null'] },
    unit_price_net: { type: ['number','null'] }, net_amount: { type: 'number' },
    vat_rate: { type: ['number','null'] }, vat_amount: { type: 'number' }, total_amount: { type: 'number' },
    category_key: { type: ['string','null'], enum: [...CATEGORY_KEYS, null] },
    lot_code: { type: ['string','null'] }, best_before_date: { type: ['string','null'] }, use_by_date: { type: ['string','null'] },
    confidence: { type: 'number' }, warnings: { type: 'array', items: { type: 'string' } }
  },
  required: ['line_number','source_line_id','supplier_item_code','ean','description','quantity','unit_code','unit_price_net','net_amount','vat_rate','vat_amount','total_amount','category_key','lot_code','best_before_date','use_by_date','confidence','warnings']
}

const extractionSchema = {
  type: 'object', additionalProperties: false,
  properties: {
    document_type: { type: 'string', enum: ['invoice','credit_note','advance_invoice','other'] },
    supplier_name: { type: 'string' }, supplier_company_id: { type: ['string','null'] }, supplier_tax_id: { type: ['string','null'] },
    document_number: { type: 'string' }, issue_date: { type: ['string','null'] }, taxable_date: { type: ['string','null'] }, due_date: { type: ['string','null'] },
    currency: { type: 'string' }, exchange_rate: { type: 'number' }, net_amount: { type: 'number' }, vat_amount: { type: 'number' }, total_amount: { type: 'number' },
    bank_account: { type: ['string','null'] }, bank_code: { type: ['string','null'] }, iban: { type: ['string','null'] }, swift: { type: ['string','null'] },
    variable_symbol: { type: ['string','null'] }, payment_message: { type: ['string','null'] },
    category_key: { type: 'string', enum: CATEGORY_KEYS }, subcategory_key: { type: ['string','null'] },
    operational_summary: { type: 'string' }, period_from: { type: ['string','null'] }, period_to: { type: ['string','null'] },
    target_kind: { type: ['string','null'], enum: ['warehouse','vehicle','machine','location','technical_job','general',null] },
    target_hint: { type: ['string','null'] }, requires_physical_receipt: { type: 'boolean' },
    confidence: { type: 'number' }, warnings: { type: 'array', items: { type: 'string' } },
    lines: { type: 'array', items: lineSchema }
  },
  required: ['document_type','supplier_name','supplier_company_id','supplier_tax_id','document_number','issue_date','taxable_date','due_date','currency','exchange_rate','net_amount','vat_amount','total_amount','bank_account','bank_code','iban','swift','variable_symbol','payment_message','category_key','subcategory_key','operational_summary','period_from','period_to','target_kind','target_hint','requires_physical_receipt','confidence','warnings','lines']
}

async function directoryContext() {
  const [categories, rules, suppliers, mappings, products, locations, vehicles, machines, technicalJobs, warehouses, stockLocations, commitments, settings] = await Promise.all([
    admin.from('finance_categories_v2').select('category_key,label,description,default_action_type,requires_operational_target,requires_physical_receipt').eq('active', true).order('sort_order'),
    admin.from('finance_ai_rules_v2').select('id,name,scope,priority,matcher,outcome,auto_execute,active,verified_at').eq('active', true).order('priority').limit(500),
    admin.from('purchase_suppliers').select('id,name,company_id,tax_id,default_due_days,active').eq('active', true).limit(1000),
    admin.from('supplier_product_mappings').select('id,supplier_id,product_id,supplier_item_code,ean,supplier_item_name,invoice_unit_code,base_units_per_invoice_unit,last_unit_price,active').eq('active', true).limit(5000),
    admin.from('products').select('id,name,sku,ean,base_unit,product_category,usage_type,purchase_price,expiry_tracking_mode,requires_batch_tracking,active').eq('active', true).limit(5000),
    admin.from('locations').select('id,name,city,address,active').eq('active', true).limit(1000),
    admin.from('vehicles').select('id,name,plate,brand,model,active').eq('active', true).limit(250),
    admin.from('machines').select('id,evidence_number,name,location_id,active,status').eq('active', true).neq('status','removed').limit(1500),
    admin.from('technical_jobs').select('id,title,machine_id,location_id,status,planned_date,active').eq('active',true).not('status','in','(closed,cancelled)').limit(500),
    admin.from('warehouses').select('id,name,code,city,active').eq('active', true).limit(100),
    admin.from('stock_locations').select('id,name,warehouse_id,location_type,active').eq('active', true).eq('location_type', 'warehouse').limit(250),
    admin.from('finance_recurring_commitments_v2').select('id,name,commitment_type,supplier_name,supplier_company_id,contract_reference,category_key,amount,currency,next_due_on,active,auto_match_document').eq('active', true).limit(500),
    admin.from('finance_ai_settings_v2').select('*').eq('id',true).maybeSingle()
  ])
  for (const result of [categories,rules,suppliers,mappings,products,locations,vehicles,machines,technicalJobs,warehouses,stockLocations,commitments,settings]) if (result.error) throw result.error
  return {
    categories: categories.data || [], rules: rules.data || [], suppliers: suppliers.data || [], mappings: mappings.data || [],
    products: products.data || [], locations: locations.data || [], vehicles: vehicles.data || [], machines:machines.data || [], technicalJobs:technicalJobs.data || [], warehouses: warehouses.data || [],
    stockLocations: stockLocations.data || [], commitments: commitments.data || [], settings:settings.data || {maximum_attempts:3}
  }
}

async function extractDocument(file: Blob, queue: any, context: any) {
  if (!OPENAI_API_KEY) throw new Error('Na serveru chybí OPENAI_API_KEY.')
  if (file.size > 25 * 1024 * 1024) throw new Error('Doklad je větší než bezpečný limit 25 MB.')
  const bytes = new Uint8Array(await file.arrayBuffer())
  const mime = queue.mime_type || file.type || 'application/octet-stream'
  const compactContext = {
    categories: context.categories,
    verified_rules: context.rules.filter((rule: any) => rule.verified_at || rule.auto_execute).slice(0, 150),
    vehicles: context.vehicles.map((row: any) => ({ id:row.id,name:row.name,plate:row.plate })),
    machines: context.machines.slice(0,500).map((row:any)=>({id:row.id,evidence_number:row.evidence_number,name:row.name,location_id:row.location_id})),
    warehouses: context.warehouses.map((row: any) => ({ id:row.id,name:row.name,code:row.code })),
    locations: context.locations.slice(0, 300).map((row: any) => ({ id:row.id,name:row.name,city:row.city }))
  }
  let exactDocument:any=null
  const content: any[] = [{
    type:'input_text',
    text:`Zpracuj přijatý provozní doklad firmy OLMIKA/OLVEND. Neprováděj účetní MD/D ani předkontace. Vrať pouze fakta z dokladu, provozní kategorii a návrh cíle. Nic si nevymýšlej; nečitelné nebo chybějící hodnoty nech null/prázdné a přidej varování. Kategorie a známý kontext: ${JSON.stringify(compactContext)}`
  }]
  if (/^image\//i.test(mime)) content.push({ type:'input_image', image_url:dataUrl(mime,bytes), detail:'high' })
  else if (/xml|isdoc|text/i.test(mime) || /\.(xml|isdoc)$/i.test(queue.file_name || '')) {
    const xml=new TextDecoder(/1250/i.test(queue.encoding || '') ? 'windows-1250' : 'utf-8').decode(bytes)
    try {
      exactDocument=parseIsdoc(xml)
      content.push({type:'input_text',text:`Toto je přesně parsovaný ISDOC. Neměň fakta ani částky; pouze doplň provozní kategorii, cíl a shrnutí: ${JSON.stringify(exactDocument)}`})
    } catch (error) {
      if (/\.isdoc$/i.test(queue.file_name || '')) throw error
      content.push({ type:'input_text', text:xml })
    }
  } else content.push({ type:'input_file', filename:queue.file_name || 'doklad.pdf', file_data:dataUrl(mime,bytes), detail:'high' })

  const requestBody={model:MODEL,store:false,instructions:'Jsi přesný dokumentový pracovník české firmy. Extrahuj doklad a navrhni pouze provozní zařazení. Účetnictví řeší samostatně účetní. Částky a identifikátory opisuj doslova a nejistotu přiznej.',input:[{role:'user',content}],text:{format:{type:'json_schema',name:'olvend_finance_document',strict:true,schema:extractionSchema}}}
  let response:Response|null=null,payload:any=null,attempts=0
  const maximumAttempts=Number(context.settings?.maximum_attempts||3)
  while(attempts<maximumAttempts){
    attempts+=1
    response=await fetch('https://api.openai.com/v1/responses',{method:'POST',headers:{Authorization:`Bearer ${OPENAI_API_KEY}`,'Content-Type':'application/json'},body:JSON.stringify(requestBody)})
    payload=await response.json().catch(()=>({}))
    if(response.ok)break
    if(![408,409,429,500,502,503,504].includes(response.status)||attempts>=maximumAttempts)throw Object.assign(new Error(payload?.error?.message||`AI služba vrátila chybu ${response.status}.`),{attempts})
    await new Promise(resolve=>setTimeout(resolve,Math.min(3000,500*attempts*attempts)))
  }
  const text = outputText(payload)
  if (!text) throw new Error('AI nevrátila vytěžený doklad.')
  const aiDocument=normalizeExtraction(JSON.parse(text))
  return {document:exactDocument?mergeExactDocument(aiDocument,exactDocument):aiDocument,providerRequestId:payload.id||null,usage:payload.usage||{},attempts}
}

function bestTarget(hint: string | null, rows: any[], fields: string[]) {
  const wanted = normalizeText(hint)
  if (!wanted) return null
  const matches = rows.filter(row => fields.some(field => {
    const candidate = normalizeText(row[field])
    return candidate.length > 0 && (candidate.includes(wanted) || wanted.includes(candidate))
  }))
  return matches.length === 1 ? matches[0] : null
}

async function upsertInvoice(queue: any, extraction: any, context: any) {
  const sourceProvider = queue.source_kind === 'email' ? 'email' : queue.source_kind === 'api' ? 'api' : 'manual'
  const supplier = matchSupplier(extraction, context.suppliers)
  const applied = applyRules(extraction, context.rules)
  const categoryDefinition=context.categories.find((row:any)=>row.category_key===applied.category_key)
  const checks = validateExtraction(applied)
  if (checks.errors.some((message: string) => /nenulová částka/.test(message))) {
    throw new Error(checks.errors.join(' '))
  }
  const duplicateQuery = admin.from('finance_received_invoices').select('id,internal_number').eq('document_number', applied.document_number).eq('total_amount', applied.total_amount).or(`source_queue_id.is.null,source_queue_id.neq.${queue.id}`).limit(2)
  if (applied.supplier_company_id) duplicateQuery.eq('supplier_company_id', applied.supplier_company_id)
  else duplicateQuery.ilike('supplier_name', applied.supplier_name)
  const { data: duplicates } = await duplicateQuery

  const invoicePayload = {
    source_provider:sourceProvider, source_external_id:queue.sha256, source_event_id:queue.mail_message_id || null,
    source_received_at:queue.discovered_at || new Date().toISOString(), source_payload:{ queue_id:queue.id, subject:queue.subject, sender:queue.sender_address },
    supplier_name:applied.supplier_name || 'Neznámý dodavatel', supplier_company_id:applied.supplier_company_id, supplier_tax_id:applied.supplier_tax_id,
    document_number:applied.document_number || `NEURCENO-${queue.id}`, document_type:applied.document_type,
    issue_date:safeDate(applied.issue_date), taxable_date:safeDate(applied.taxable_date), due_date:safeDate(applied.due_date),
    currency:applied.currency, exchange_rate:applied.exchange_rate, net_amount:applied.net_amount, vat_amount:applied.vat_amount, total_amount:applied.total_amount,
    bank_account:applied.bank_account, bank_code:applied.bank_code, iban:applied.iban, swift:applied.swift, variable_symbol:applied.variable_symbol,
    payment_message:applied.payment_message, category:context.categories.find((row:any)=>row.category_key===applied.category_key)?.label || applied.category_key,
    category_key:applied.category_key, subcategory_key:applied.subcategory_key, operational_summary:applied.operational_summary,
    document_period_from:safeDate(applied.period_from), document_period_to:safeDate(applied.period_to),
    extraction_confidence:applied.confidence, extraction_warnings:[...checks.errors,...checks.warnings],
    processing_state:'extracting', requires_physical_receipt:Boolean(applied.requires_physical_receipt || categoryDefinition?.requires_physical_receipt),
    duplicate_of_invoice_id:duplicates?.[0]?.id || null, ai_model:MODEL, ai_last_run_at:new Date().toISOString(), source_queue_id:queue.id,
    status:'new', updated_at:new Date().toISOString()
  }
  let { data: invoice, error } = await admin.from('finance_received_invoices').upsert(invoicePayload,{ onConflict:'source_provider,source_external_id' }).select('*').single()
  if (error) throw error

  await admin.from('finance_ai_questions_v2').update({ status:'superseded' }).eq('invoice_id',invoice.id).eq('status','open')
  const completed = await admin.from('finance_ai_actions_v2').select('id').eq('invoice_id',invoice.id).eq('status','completed').limit(1)
  if (completed.data?.length) throw new Error('Doklad s již provedenou provozní akcí nelze znovu vytěžit.')
  await admin.from('finance_ai_actions_v2').delete().eq('invoice_id',invoice.id).neq('status','completed')
  await admin.from('finance_invoice_lines_v2').delete().eq('invoice_id',invoice.id)

  if (queue.storage_path) {
    await admin.from('finance_invoice_attachments').upsert({
      invoice_id:invoice.id,kind:'original',storage_bucket:'finance-private',storage_path:queue.storage_path,
      file_name:queue.file_name,mime_type:queue.mime_type,size_bytes:queue.size_bytes || 0,sha256:queue.sha256,immutable:true
    },{ onConflict:'invoice_id,sha256' })
  }

  if (!supplier && applied.supplier_name && applied.confidence >= 90) {
    const created = await admin.from('purchase_suppliers').insert({
      name:applied.supplier_name,company_id:applied.supplier_company_id,tax_id:applied.supplier_tax_id,active:true,
      note:`Automaticky založeno z dokladu ${applied.document_number}; ověřit při první kontrole.`
    }).select('*').single()
    if (!created.error) context.suppliers.push(created.data)
  }
  const activeSupplier = supplier || matchSupplier(applied, context.suppliers)

  const lineRows:any[] = []
  const unresolved:any[] = []
  for (const line of applied.lines) {
    const match = matchProduct(line,context.mappings,context.products,activeSupplier?.id)
    lineRows.push({
      invoice_id:invoice.id,line_number:line.line_number,source_line_id:line.source_line_id,supplier_item_code:line.supplier_item_code,ean:line.ean,
      description:line.description,quantity:line.quantity,unit_code:line.unit_code,unit_price_net:line.unit_price_net,net_amount:line.net_amount,
      vat_rate:line.vat_rate,vat_amount:line.vat_amount,total_amount:line.total_amount,category_key:line.category_key || applied.category_key,
      product_id:match.product?.id || null,supplier_mapping_id:match.mapping?.id || null,
      base_units_per_invoice_unit:Number(match.mapping?.base_units_per_invoice_unit || 1),lot_code:line.lot_code,
      best_before_date:safeDate(line.best_before_date),use_by_date:safeDate(line.use_by_date),confidence:Math.min(line.confidence,match.product ? match.confidence : line.confidence),
      warnings:[...(line.warnings || []),...(!match.product && applied.requires_physical_receipt ? ['Položka není spárovaná se skladovou kartou.'] : [])],raw_payload:line
    })
  }
  let savedLines:any[]=[]
  if (lineRows.length) {
    const saved = await admin.from('finance_invoice_lines_v2').insert(lineRows).select('*')
    if (saved.error) throw saved.error
    savedLines=saved.data || []
  }

  const questions:any[]=[]
  if (!applied.document_number) questions.push({ question_key:'document_number',question:'Jaké je číslo tohoto dokladu?',explanation:'Číslo dokladu se nepodařilo bezpečně přečíst.',answer_type:'text',options:[],blocking:true })
  if (applied.category_key==='other' || applied.confidence<80) questions.push({
    question_key:'document_category',question:'Do jaké provozní kategorie tento doklad patří?',
    explanation:checks.warnings.join(' ') || 'AI nemá dostatečnou jistotu.',answer_type:'choice',
    options:context.categories.filter((row:any)=>!['goods','fleet','premises'].includes(row.category_key)).map((row:any)=>({ value:row.category_key,label:row.label })),
    suggested_answer:{ value:applied.category_key },blocking:true,
    rule_matcher:{ supplier_company_id:applied.supplier_company_id,supplier_name_contains:applied.supplier_name },
    rule_outcome:{ category_key:'$answer' }
  })
  if (duplicates?.length) questions.push({
    question_key:'duplicate',question:`Je doklad duplicitou ${duplicates[0].internal_number}?`,
    explanation:'Stejný dodavatel, číslo dokladu a částka už v OLVENDU existují.',answer_type:'boolean',options:[{value:true,label:'Ano, je to duplicita'},{value:false,label:'Ne, je to nový doklad'}],blocking:true
  })
  for (const line of savedLines) if (applied.requires_physical_receipt && !line.product_id) {
    const words=normalizeText(line.description).split(' ').filter((word:string)=>word.length>3)
    const candidates=context.products.filter((product:any)=>words.some((word:string)=>normalizeText(product.name).includes(word))).slice(0,20)
    questions.push({
      invoice_id:invoice.id,line_id:line.id,question_key:`line_product_${line.id}`,
      question:`Jaká skladová karta odpovídá položce „${line.description}“?`,
      explanation:'Po odpovědi si OLVEND vazbu na kód dodavatele zapamatuje.',answer_type:'entity',
      options:candidates.map((row:any)=>({value:row.id,label:row.name,meta:row.sku || row.base_unit})),blocking:true,
      rule_matcher:{ supplier_company_id:applied.supplier_company_id,supplier_item_code:line.supplier_item_code,line_description_contains:line.description },
      rule_outcome:{ product_id:'$answer' }
    })
    unresolved.push(line)
  }

  const category = context.categories.find((row:any)=>row.category_key===applied.category_key)
  const actions:any[]=[]
  if (category?.default_action_type==='stock_receipt' || applied.requires_physical_receipt) {
    const hintedWarehouse=bestTarget(applied.target_hint,context.warehouses,['name','code'])
    const stockLocation=context.stockLocations.find((row:any)=>String(row.id)===String(applied.stock_location_id||'')) || context.stockLocations.find((row:any)=>String(row.warehouse_id)===String(hintedWarehouse?.id)) || (context.stockLocations.length===1 ? context.stockLocations[0] : null)
    if (!stockLocation) questions.push({
      invoice_id:invoice.id,question_key:'receipt_warehouse',question:'Na který sklad máme zboží přijmout?',
      explanation:'Doklad neobsahuje jednoznačný cílový sklad.',answer_type:'entity',
      options:context.stockLocations.map((row:any)=>({value:row.id,label:row.name})),blocking:true,
      rule_matcher:{supplier_company_id:applied.supplier_company_id},rule_outcome:{stock_location_id:'$answer'}
    })
    actions.push({
      invoice_id:invoice.id,action_type:'stock_receipt',status:unresolved.length || !stockLocation ? 'waiting_input':'waiting_delivery',
      title:'Přijmout zboží na sklad',description:'Po potvrzení fyzického doručení vytvoří skladové pohyby, šarže a aktualizuje nákupní ceny.',
      requires_confirmation:true,idempotency_key:uniqueKey('stock_receipt',invoice.id),payload:{
        supplier_id:activeSupplier?.id || null,stock_location_id:stockLocation?.id || null,warehouse_id:stockLocation?.warehouse_id || null,
        lines:savedLines.map((line:any)=>({line_id:line.id,line_number:line.line_number,product_id:line.product_id,stock_location_id:stockLocation?.id || null,
          quantity_base_units:Number(line.quantity)*Number(line.base_units_per_invoice_unit || 1),unit_cost:line.unit_price_net == null ? null : Number(line.unit_price_net)/Number(line.base_units_per_invoice_unit || 1),
          lot_code:line.lot_code,best_before_date:line.best_before_date,use_by_date:line.use_by_date}))
      }
    })
  } else if (category?.default_action_type==='vehicle_expense') {
    const vehicle=context.vehicles.find((row:any)=>String(row.id)===String(applied.vehicle_id||'')) || bestTarget(applied.target_hint,context.vehicles,['name','plate','brand','model'])
    if (!vehicle) questions.push({
      invoice_id:invoice.id,question_key:'vehicle_target',question:'Ke kterému vozidlu tento náklad patří?',
      explanation:'Bez vozidla nelze PHM nebo servis správně zapsat.',answer_type:'entity',
      options:context.vehicles.map((row:any)=>({value:row.id,label:`${row.name} · ${row.plate}`})),blocking:true,
      rule_matcher:{supplier_company_id:applied.supplier_company_id},rule_outcome:{vehicle_id:'$answer'}
    })
    actions.push({ invoice_id:invoice.id,action_type:'vehicle_expense',status:vehicle?'ready':'waiting_input',title:'Zapsat náklad vozidla',
      description:'Vytvoří provozní náklad ve vozovém parku.',requires_confirmation:!applied.applied_rule_ids?.length,
      idempotency_key:uniqueKey('vehicle_expense',invoice.id),payload:{vehicle_id:vehicle?.id || null,vehicle_label:vehicle?`${vehicle.name} · ${vehicle.plate}`:null,vehicle_category:applied.category_key==='fuel'?'fuel_card':applied.category_key==='vehicle_insurance'?'insurance':'repair'} })
  } else if (category?.default_action_type==='service_link') {
    const machine=context.machines.find((row:any)=>String(row.id)===String(applied.machine_id||'')) || bestTarget(applied.target_hint,context.machines,['evidence_number','name'])
    actions.push({ invoice_id:invoice.id,action_type:'service_link',status:machine?'ready':'waiting_input',title:'Přiřadit servisní náklad',description:'Propojí doklad s automatem nebo technickým zásahem.',requires_confirmation:!applied.applied_rule_ids?.length,idempotency_key:uniqueKey('service_link',invoice.id),payload:{machine_id:machine?.id || null,machine_label:machine?`EV${machine.evidence_number||machine.id} · ${machine.name||'automat'}`:null} })
    if (!machine) questions.push({invoice_id:invoice.id,question_key:'service_target',question:'Ke kterému automatu nebo servisnímu zásahu doklad patří?',explanation:'Doklad je servisní, ale cíl není jednoznačný.',answer_type:'entity',options:context.machines.slice(0,200).map((row:any)=>({value:row.id,label:`EV${row.evidence_number||row.id} · ${row.name||'automat'}`})),blocking:true,rule_matcher:{supplier_company_id:applied.supplier_company_id},rule_outcome:{machine_id:'$answer'}})
  } else {
    const location=context.locations.find((row:any)=>String(row.id)===String(applied.location_id||'')) || bestTarget(applied.target_hint,context.locations,['name','city','address'])
    if(category?.requires_operational_target&&!location)questions.push({invoice_id:invoice.id,question_key:'location_target',question:'Ke které provozovně nebo lokalitě tento náklad patří?',explanation:'Kategorie vyžaduje provozní cíl, aby byl náklad užitečný pro řízení firmy.',answer_type:'entity',options:context.locations.map((row:any)=>({value:row.id,label:`${row.name}${row.city?` · ${row.city}`:''}`})),blocking:true,rule_matcher:{supplier_company_id:applied.supplier_company_id},rule_outcome:{location_id:'$answer'}})
    actions.push({ invoice_id:invoice.id,action_type:'record_cost',status:category?.requires_operational_target&&!location?'waiting_input':'ready',title:'Zapsat provozní náklad',description:'Zařadí náklad do živého finančního přehledu OLVENDU.',requires_confirmation:!applied.applied_rule_ids?.length,idempotency_key:uniqueKey('record_cost',invoice.id),payload:{category_key:applied.category_key,target_kind:applied.target_kind,target_hint:applied.target_hint,location_id:location?.id||null,location_label:location?`${location.name}${location.city?` · ${location.city}`:''}`:null} })
  }

  await admin.rpc('finance_materialize_recurring_v2',{p_until:new Date(Date.now()+120*86400000).toISOString().slice(0,10)})
  const due = applied.due_date ? new Date(applied.due_date) : null
  const obligation = context.commitments.find((row:any) => {
    const supplierMatch=(applied.supplier_company_id && String(row.supplier_company_id||'')===String(applied.supplier_company_id)) || normalizeText(row.supplier_name)===normalizeText(applied.supplier_name)
    return supplierMatch && row.currency===applied.currency && Math.abs(Number(row.amount)-Math.abs(applied.total_amount))<=Math.max(5,Math.abs(applied.total_amount)*0.02)
  })
  if (obligation) {
    let expectedQuery=admin.from('finance_expected_obligations_v2').select('id,due_date').eq('commitment_id',obligation.id).in('status',['expected','document_missing']).limit(24)
    if (due) {
      const from=new Date(due.getTime()-35*86400000).toISOString().slice(0,10)
      const until=new Date(due.getTime()+35*86400000).toISOString().slice(0,10)
      expectedQuery=expectedQuery.gte('due_date',from).lte('due_date',until)
    }
    const expected=await expectedQuery
    const nearest=(expected.data || []).sort((a:any,b:any)=>due ? Math.abs(due.getTime()-new Date(a.due_date).getTime())-Math.abs(due.getTime()-new Date(b.due_date).getTime()) : String(a.due_date).localeCompare(String(b.due_date)))[0]
    if (nearest) await admin.rpc('finance_match_expected_obligation_v2',{p_invoice_id:invoice.id,p_obligation_id:nearest.id,p_confidence:98})
  }

  if (questions.length) {
    const rows=questions.map(q=>({invoice_id:invoice.id,...q}))
    const inserted=await admin.from('finance_ai_questions_v2').insert(rows)
    if (inserted.error) throw inserted.error
  }
  let insertedActions:any[]=[]
  if (actions.length) {
    const inserted=await admin.from('finance_ai_actions_v2').insert(actions).select('id,action_type,requires_confirmation,status')
    if (inserted.error) throw inserted.error
    insertedActions=inserted.data || []
  }
  let state = questions.length ? 'waiting_answer' : actions.some(a=>a.action_type==='stock_receipt') ? 'waiting_delivery' : actions.length ? 'ready_to_execute' : 'accountant_ready'
  const { error:updateError }=await admin.from('finance_received_invoices').update({processing_state:state,status:state==='accountant_ready'?'handoff_ready':'approval',handoff_status:state==='accountant_ready'?'ready':'not_ready',updated_at:new Date().toISOString()}).eq('id',invoice.id)
  if (updateError) throw updateError
  await admin.from('finance_document_intake_queue').update({status:'invoice_created',invoice_id:invoice.id,extraction_confidence:applied.confidence,extracted_payload:applied,warnings:[...checks.errors,...checks.warnings],processed_at:new Date().toISOString(),error_message:null}).eq('id',queue.id)
  await admin.from('finance_invoice_events').insert({invoice_id:invoice.id,event_type:'ai_document_processed',to_status:state,note:applied.operational_summary,metadata:{model:MODEL,questions:questions.length,actions:actions.length,applied_rule_ids:applied.applied_rule_ids || []}})
  if (!questions.length) {
    for (const action of insertedActions.filter((row:any)=>row.status==='ready' && !row.requires_confirmation && row.action_type!=='stock_receipt')) {
      const executed=await admin.rpc('finance_execute_action_v2',{p_action_id:action.id,p_confirmed:false,p_note:'Automaticky provedeno podle ověřeného pravidla OLVENDU.'})
      if (executed.error || executed.data?.ok===false) throw executed.error || new Error(executed.data?.error || 'Automatická provozní akce selhala.')
    }
    const recalculated=await admin.rpc('finance_recalculate_state_v2',{p_invoice_id:invoice.id})
    if (!recalculated.error && recalculated.data) state=recalculated.data
  }
  return { invoice_id:invoice.id,internal_number:invoice.internal_number,state,questions:questions.length,actions:actions.length,warnings:[...checks.errors,...checks.warnings] }
}

Deno.serve(async req => {
  if (req.method==='OPTIONS') return new Response('ok',{headers:cors})
  if (req.method!=='POST') return json({error:'Method not allowed.'},405)
  let queueId=0,runId=0,startedAt=Date.now()
  try {
    await authorize(req)
    const input=await req.json().catch(()=>({}))
    if (input.action==='health') return json({ok:true,model:MODEL,openai_configured:Boolean(OPENAI_API_KEY)})
    queueId=Number(input.queue_id)
    if (!Number.isFinite(queueId) || queueId<=0) return json({error:'queue_id je povinné.'},400)
    const queueResult=await admin.from('finance_document_intake_queue').select('*').eq('id',queueId).single()
    if (queueResult.error) throw queueResult.error
    const queue=queueResult.data
    await admin.from('finance_document_intake_queue').update({status:'extracting',processing_started_at:new Date().toISOString(),error_message:null}).eq('id',queue.id)
    const download=await admin.storage.from('finance-private').download(queue.storage_path)
    if (download.error || !download.data) throw download.error || new Error('Originální soubor se nepodařilo načíst.')
    const context=await directoryContext()
    const run=await admin.from('finance_ai_runs_v2').insert({queue_id:queue.id,model:MODEL,status:'running'}).select('id').single()
    if(run.error)throw run.error
    runId=run.data.id
    const extracted=await extractDocument(download.data,queue,context)
    const result=await upsertInvoice(queue,extracted.document,context)
    const inputTokens=Number(extracted.usage?.input_tokens||0),outputTokens=Number(extracted.usage?.output_tokens||0)
    const estimatedCost=(inputTokens/1_000_000*INPUT_COST_PER_MILLION)+(outputTokens/1_000_000*OUTPUT_COST_PER_MILLION)
    await admin.from('finance_ai_runs_v2').update({invoice_id:result.invoice_id,status:'completed',provider_request_id:extracted.providerRequestId,input_tokens:inputTokens,output_tokens:outputTokens,total_tokens:Number(extracted.usage?.total_tokens||inputTokens+outputTokens),estimated_cost_usd:estimatedCost||null,latency_ms:Date.now()-startedAt,attempt_count:extracted.attempts,completed_at:new Date().toISOString()}).eq('id',runId)
    return json({ok:true,...result,usage:{input_tokens:inputTokens,output_tokens:outputTokens,estimated_cost_usd:estimatedCost||null}})
  } catch (error) {
    const message=error instanceof Error?error.message:'Neznámá chyba.'
    const status=Number((error as any)?.status || 500)
    if(queueId)await admin.from('finance_document_intake_queue').update({status:'failed',error_message:message,processed_at:new Date().toISOString()}).eq('id',queueId)
    if(runId)await admin.from('finance_ai_runs_v2').update({status:'failed',error_message:message,latency_ms:Date.now()-startedAt,attempt_count:Number((error as any)?.attempts||1),completed_at:new Date().toISOString()}).eq('id',runId)
    return json({error:message},status)
  }
})
