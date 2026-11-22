import { supabase } from './supabase.js'
import { mailApi } from './mail-api.js'
import { parseMoneyReceivedInvoicesXml, sha256Hex } from './money-received-invoices-core.mjs?v=20261121money-import-v2'

const $ = (id) => document.getElementById(id)
const preview = new URL(location.href).searchParams.get('preview') === '1'
const today = new Date(); today.setHours(12,0,0,0)
const money = (value, currency = 'CZK') => new Intl.NumberFormat('cs-CZ', { style:'currency', currency, maximumFractionDigits:2 }).format(Number(value || 0))
const integer = (value) => new Intl.NumberFormat('cs-CZ').format(Number(value || 0))
const date = (value) => value ? new Intl.DateTimeFormat('cs-CZ').format(new Date(`${value}T12:00:00`)) : '—'
const escapeHtml = (value) => String(value ?? '').replace(/[&<>"']/g, (char) => ({ '&':'&amp;', '<':'&lt;', '>':'&gt;', '"':'&quot;', "'":'&#39;' }[char]))

const demoRows = [
  { id:1, internal_number:'PF26-00481', supplier_name:'JIPOCAR TRANSPORT, s.r.o.', supplier_id:'46964821', document_number:'202611384', issue_date:'2026-11-18', taxable_date:'2026-11-18', due_date:'2026-11-25', category:'PHM a vozidla', cost_center:'Vozový park', net_amount:18640, vat_amount:3914.40, total_amount:22554.40, variable_symbol:'202611384', bank_account:'123456789/5500', status:'ready_for_payment', payment_status:'unpaid', owner:'Michal Punčochář', confidence:99, source:'pracovní e-mail', attachment_name:'202611384.pdf', approval:'Schváleno 20. 11. Michalem', note:'Tankování a provoz vozidel.' },
  { id:2, internal_number:'PF26-00480', supplier_name:'CROCUS CZ s.r.o.', supplier_id:'26211719', document_number:'FV-2026-8821', issue_date:'2026-11-17', taxable_date:'2026-11-17', due_date:'2026-11-21', category:'Zboží a materiál', cost_center:'BLUČINA', net_amount:84250, vat_amount:12637.50, total_amount:96887.50, variable_symbol:'20268821', bank_account:'2108876543/2700', status:'approval', payment_status:'unpaid', stock_receipt_status:'needs_mapping', owner:'Vedoucí skladu', confidence:96, source:'E-mail + AI', attachment_name:'FV-2026-8821.isdoc', approval:'Čeká na věcnou kontrolu skladu', note:'Zkontrolovat množství proti příjemce.' },
  { id:3, internal_number:'PF26-00479', supplier_name:'Microsoft Ireland Operations Ltd.', supplier_id:'IE8256796U', document_number:'E0400P9N8K', issue_date:'2026-11-16', taxable_date:'2026-11-16', due_date:'2026-11-16', category:'Software a služby', cost_center:'Správa', net_amount:12980, vat_amount:0, total_amount:12980, variable_symbol:'', bank_account:'IBAN IE12••••8890', status:'handoff_ready', payment_status:'paid', owner:'Michal Punčochář', confidence:94, source:'E-mail + AI', attachment_name:'E0400P9N8K.pdf', approval:'Připraveno pro účetní · reverse charge', note:'Režim reverse charge; účetní kontrola DPH.' },
  { id:4, internal_number:'PF26-00478', supplier_name:'EG.D, a.s.', supplier_id:'28085400', document_number:'4600911251', issue_date:'2026-11-12', taxable_date:'2026-11-10', due_date:'2026-11-19', category:'Nájem a energie', cost_center:'Provozovna', net_amount:31840, vat_amount:6686.40, total_amount:38526.40, variable_symbol:'4600911251', bank_account:'100005321/0100', status:'ready_for_payment', payment_status:'unpaid', owner:'Michal Punčochář', confidence:99, source:'pracovní e-mail', attachment_name:'4600911251.pdf', approval:'Schváleno · nebylo vloženo do dávky', note:'Po splatnosti 2 dny.' },
  { id:5, internal_number:'PF26-00477', supplier_name:'TECH servis Morava s.r.o.', supplier_id:'05598731', document_number:'TS-260491', issue_date:'2026-11-19', taxable_date:'2026-11-19', due_date:'2026-12-03', category:'Servis a technika', cost_center:'Technický úsek', net_amount:42700, vat_amount:8967, total_amount:51667, variable_symbol:'260491', bank_account:'2901887412/2010', status:'new', payment_status:'unpaid', owner:'Technický úsek', confidence:82, source:'E-mail + AI', attachment_name:'TS-260491-scan.pdf', approval:'Nízká jistota bankovního účtu', note:'Ověřit účet proti registru plátců DPH.' },
  { id:6, internal_number:'PF26-00474', supplier_name:'BARBERA Caffè Czech s.r.o.', supplier_id:'27746275', document_number:'2026/000319', issue_date:'2026-11-11', taxable_date:'2026-11-11', due_date:'2026-11-25', category:'Zboží a materiál', cost_center:'BLUČINA', net_amount:137400, vat_amount:16488, total_amount:153888, variable_symbol:'2026000319', bank_account:'2401885102/2010', status:'in_payment_batch', payment_status:'ordered', owner:'Vedoucí skladu', confidence:98, source:'pracovní e-mail', attachment_name:'2026-000319.pdf', approval:'Dávka HP-2026-0118 · čeká na banku', note:'Příjem zboží spárován.' },
]

let rows = [], intakeRows = [], stockLocations = [], stockProducts = [], activeAllocations = [], activeTab = 'open', activeIntakeTab = 'review', selected = new Set(), activeRow = null, activeIntakeRow = null
let moneyImport = { file:null, parsed:null, sha256:null }
let productMappingAllocationId = null
const statusMap = { new:['Nová','info'], approval:['Ke schválení','warn'], ready_for_payment:['K platbě','good'], in_payment_batch:['V příkazu','violet'], settled:['Uhrazeno','good'], overdue:['Po splatnosti','bad'], handoff_ready:['Pro účetní','good'], exported:['Uzavřeno','good'], rejected:['Vráceno','bad'], cancelled:['Nulový doklad',''] }
const paymentMap = { unpaid:['Neuhrazeno','warn'], ordered:['Příkaz vytvořen','violet'], paid:['Zaplaceno','good'], partially_paid:['Částečně','warn'], cancelled:['Bez úhrady',''] }
const accountingMap = { not_prepared:['Nepředáno účetní',''], prepared:['Připraveno účetní','info'], downloaded:['Staženo účetní','violet'], booked:['Zaúčtováno účetní','good'], returned:['Vráceno účetní','bad'] }
const stockMap = { not_applicable:['Bez příjmu',''], needs_mapping:['Spárovat položky','warn'], ready:['Příjem připraven','info'], ordered:['Čeká na sklad','violet'], received:['Naskladněno','good'], blocked:['Příjem blokován','bad'] }
const documentClassMap={invoice:'Faktura',credit_note:'Dobropis',advance_invoice:'Zálohová faktura',delivery_note:'Dodací list',reminder:'Upomínka',payment_schedule:'Splátkový kalendář',accounting_report:'Účetní výkaz',contract:'Smlouva',other:'Jiný dokument'}
const intakeStatusMap={queued:['Čeká na vytěžení','info'],extracting:['Vytěžuji','violet'],needs_review:['Ke kontrole','warn'],invoice_created:['Přiřazeno','good'],ignored:['Ignorováno',''],failed:['Chyba','bad']}

function setStatus(text, type = '', meta = 'Zdroj: pracovní e-mail') { $('statusText').textContent = text; $('statusMeta').textContent = meta; $('statusStrip').className = `status-strip ${type}`.trim() }
function badge(map, value) { const item = map[value] || [value || '—','']; return `<span class="badge ${item[1]}">${escapeHtml(item[0])}</span>` }
function daysTo(value) { return value ? Math.ceil((new Date(`${value}T12:00:00`) - today) / 86400000) : Number.POSITIVE_INFINITY }
function dayWord(value) { const days=Math.abs(value);return days===1?'den':days>=2&&days<=4?'dny':'dnů' }
function dueMarkup(row) { if(!row.due_date)return '<span class="deadline warn">Bez data</span><span class="cell-sub">Doplnit splatnost</span>'; const days = daysTo(row.due_date); const cls = row.payment_status === 'paid' ? '' : days < 0 ? 'bad' : days <= 7 ? 'warn' : ''; const note = row.payment_status === 'paid' ? 'Uhrazeno' : days < 0 ? `${Math.abs(days)} ${dayWord(days)} po splatnosti` : days === 0 ? 'Dnes' : `Za ${days} ${dayWord(days)}`; return `<span class="deadline ${cls}">${date(row.due_date)}</span><span class="cell-sub">${note}</span>` }

function matchesTab(row) {
  if (activeTab === 'all') return true
  if (activeTab === 'open') return Number(row.operational_remaining_amount ?? row.money_remaining_amount ?? (row.payment_status==='paid'?0:row.total_amount)) > .01
  if (activeTab === 'new') return row.status === 'new'
  if (activeTab === 'approval') return row.status === 'approval'
  if (activeTab === 'payment') return ['ready_for_payment','in_payment_batch'].includes(row.status)
  if (activeTab === 'paid') return row.payment_status === 'paid'
  if (activeTab === 'accounting') return ['prepared','downloaded','booked','returned'].includes(row.accounting_status)
  return true
}

function filteredRows() {
  const query = $('searchInput').value.trim().toLowerCase(); const category = $('categoryFilter').value; const owner = $('ownerFilter').value; const due = $('dueFilter').value
  return rows.filter((row) => matchesTab(row) && (!query || `${row.internal_number} ${row.document_number} ${row.supplier_name} ${row.variable_symbol}`.toLowerCase().includes(query)) && (!category || row.category === category) && (!owner || row.owner === owner) && (!due || (due === 'overdue' ? daysTo(row.due_date) < 0 && row.payment_status !== 'paid' : daysTo(row.due_date) >= 0 && daysTo(row.due_date) <= Number(due))))
}

function renderMetrics() {
  $('metricNew').textContent = intakeRows.filter((r)=>r.status==='needs_review').length; $('metricReview').textContent = rows.filter((r) => r.status === 'approval').length
  $('metricReady').textContent = money(rows.filter((r) => r.status === 'ready_for_payment').reduce((s,r) => s + Number(r.operational_remaining_amount ?? r.money_remaining_amount ?? r.total_amount), 0))
  $('metricOverdue').textContent = money(rows.filter((r) => Number(r.operational_remaining_amount ?? r.money_remaining_amount ?? 0) > .01 && daysTo(r.due_date) < 0).reduce((s,r) => s + Number(r.operational_remaining_amount ?? r.money_remaining_amount ?? 0), 0))
  $('metricAccountant').textContent = rows.filter((r) => ['prepared','downloaded','booked','returned'].includes(r.accounting_status)).length
}

function matchesIntakeTab(row){
  if(activeIntakeTab==='all')return true
  if(activeIntakeTab==='review')return row.status==='needs_review'
  if(activeIntakeTab==='processing')return ['queued','extracting'].includes(row.status)
  if(activeIntakeTab==='assigned')return row.status==='invoice_created'
  if(activeIntakeTab==='ignored')return row.status==='ignored'
  if(activeIntakeTab==='failed')return row.status==='failed'
  return true
}

function filteredIntakeRows(){
  const query=$('intakeSearchInput').value.trim().toLowerCase(),documentClass=$('intakeClassFilter').value
  return intakeRows.filter((row)=>{
    const payload=row.extracted_payload||{}
    const haystack=`${row.file_name||''} ${row.sender_address||''} ${row.subject||''} ${payload.document_number||''} ${payload.variable_symbol||''}`.toLowerCase()
    return matchesIntakeTab(row)&&(!query||haystack.includes(query))&&(!documentClass||row.document_class===documentClass)
  })
}

function intakeTimestamp(value){return value?new Intl.DateTimeFormat('cs-CZ',{dateStyle:'short',timeStyle:'short'}).format(new Date(value)):'—'}
function fileGlyph(row){if(/pdf/i.test(row.mime_type||row.file_name||''))return ['PDF','pdf'];if(/image/i.test(row.mime_type||''))return ['IMG','image'];if(/xml|isdoc/i.test(row.mime_type||row.file_name||''))return ['XML','xml'];return ['DOC','document']}
function renderIntakeCounts(){
  const count=(statuses)=>intakeRows.filter((row)=>statuses.includes(row.status)).length
  const review=count(['needs_review'])
  $('intakeReviewCount').textContent=`${review} ke kontrole`
  $('intakeTabReviewCount').textContent=review
  $('intakeTabProcessingCount').textContent=count(['queued','extracting'])
  $('intakeTabAssignedCount').textContent=count(['invoice_created'])
  $('intakeTabIgnoredCount').textContent=count(['ignored'])
  $('intakeTabFailedCount').textContent=count(['failed'])
  $('intakeTabAllCount').textContent=intakeRows.length
}

function renderIntake(){
  renderIntakeCounts()
  const visible=filteredIntakeRows()
  $('intakeBody').innerHTML=visible.length?visible.map((row)=>{
    const payload=row.extracted_payload||{},warnings=[...(Array.isArray(row.warnings)?row.warnings:[]),...((payload.auto_evidence?.reasons||[]).filter(reason=>!(row.warnings||[]).includes(reason)))],received=row.message_received_at||row.discovered_at
    const amountValue=payload.total_amount==null?'—':money(payload.total_amount,payload.currency||'CZK')
    const warningItems=row.error_message?[row.error_message,...warnings]:warnings
    const warningMarkup=warningItems.length?`<div class="intake-warnings">${warningItems.slice(0,2).map((item)=>`<span>${escapeHtml(item)}</span>`).join('')}${warningItems.length>2?`<small>+${warningItems.length-2} další</small>`:''}</div>`:'<span class="intake-ok">Bez upozornění</span>'
    const [glyph,glyphClass]=fileGlyph(row)
    return `<tr data-intake-id="${row.id}" class="${row.status==='needs_review'?'review-row':row.status==='failed'?'failed-row':''}"><td><div class="intake-file"><span class="intake-file-icon ${glyphClass}">${glyph}</span><div><span class="cell-main">${escapeHtml(row.file_name)}</span><span class="cell-sub">${escapeHtml(row.sender_address||'Neznámý odesílatel')} · ${Math.max(1,Math.round(Number(row.size_bytes||0)/1024)).toLocaleString('cs-CZ')} kB</span></div></div></td><td><span class="cell-main">${escapeHtml(documentClassMap[row.document_class]||'Nerozpoznáno')}</span><span class="cell-sub">${escapeHtml(payload.document_number||payload.variable_symbol||row.subject||'Bez čísla dokladu')}</span>${row.extraction_confidence!=null?`<span class="intake-confidence">Jistota ${Math.round(Number(row.extraction_confidence))} %</span>`:''}</td><td><span class="cell-main">${amountValue}</span><span class="cell-sub">Splatnost ${date(payload.due_date)}</span></td><td>${warningMarkup}</td><td><span class="cell-main">${intakeTimestamp(received)}</span><span class="cell-sub">${escapeHtml(row.subject||'Bez předmětu')}</span></td><td>${badge(intakeStatusMap,row.status)}</td><td><button class="btn ${row.status==='needs_review'?'':'secondary'} small open-intake" data-id="${row.id}" type="button">${row.status==='needs_review'?'Zkontrolovat':'Detail'}</button></td></tr>`
  }).join(''):`<tr><td colspan="7"><div class="empty">${activeIntakeTab==='review'?'Žádný dokument nyní nečeká na ruční kontrolu.':'Pro zvolený stav a filtry tu nejsou žádné dokumenty.'}</div></td></tr>`
  document.querySelectorAll('.open-intake').forEach((button)=>button.addEventListener('click',()=>openIntakeDrawer(Number(button.dataset.id))))
  document.querySelectorAll('tr[data-intake-id]').forEach((row)=>row.addEventListener('dblclick',()=>openIntakeDrawer(Number(row.dataset.intakeId))))
}

function intakeInput(id,label,value='',type='text',extra=''){
  return `<label class="intake-field"><span>${label}</span><input class="field-control" id="${id}" type="${type}" value="${escapeHtml(value??'')}" ${extra}></label>`
}

function openIntakeDrawer(id){
  activeIntakeRow=intakeRows.find((row)=>row.id===id);if(!activeIntakeRow)return
  const row=activeIntakeRow,payload=row.extracted_payload||{},warnings=[...(Array.isArray(row.warnings)?row.warnings:[]),...((payload.auto_evidence?.reasons||[]).filter(reason=>!(row.warnings||[]).includes(reason)))],lineItems=Array.isArray(payload.line_items)?payload.line_items:[]
  const assignedInvoice=rows.find((invoice)=>invoice.id===row.invoice_id)
  const canDecide=row.status==='needs_review',canReopen=['ignored','failed'].includes(row.status)&&!row.invoice_id
  const canCreate=canDecide&&['invoice','credit_note','advance_invoice'].includes(row.document_class)
  const isReminder=row.document_class==='reminder'
  $('intakeDrawerEyebrow').textContent=badge(intakeStatusMap,row.status).replace(/<[^>]*>/g,'')
  $('intakeDrawerTitle').textContent=row.file_name
  $('intakeDrawerSubtitle').textContent=`${row.sender_address||'Neznámý odesílatel'} · ${intakeTimestamp(row.message_received_at||row.discovered_at)}`
  const invoiceOptions=rows.map((invoice)=>`<option value="${invoice.id}" ${invoice.id===row.invoice_id?'selected':''}>${escapeHtml(invoice.internal_number||'Bez čísla')} · ${escapeHtml(invoice.supplier_name)} · ${escapeHtml(invoice.document_number)} · ${money(invoice.total_amount,invoice.currency)}</option>`).join('')
  const classOptions=Object.entries(documentClassMap).map(([value,label])=>`<option value="${value}" ${value===row.document_class?'selected':''}>${label}</option>`).join('')
  const warningMarkup=(row.error_message||warnings.length)?`<div class="intake-review-warnings"><strong>Co je potřeba ověřit</strong>${[row.error_message,...warnings].filter(Boolean).map((item)=>`<div>• ${escapeHtml(item)}</div>`).join('')}</div>`:'<div class="notice"><strong>Automatická kontrola nenašla upozornění.</strong> Před založením přesto porovnejte údaje s originálem.</div>'
  const specialNotice=isReminder?'<div class="notice" style="border-color:#fedf89;background:#fffaeb;color:#93370d"><strong>Toto je upomínka.</strong> Novou fakturu z ní nezakládáme. Přiřaďte ji k původní faktuře, nebo ji ignorujte.</div>':lineItems.length?`<div class="notice"><strong>Položkový doklad:</strong> rozpoznáno ${lineItems.length} položek. Po založení faktury budou čekat na spárování se skladovými kartami; nic se automaticky nenaskladní.</div>`:''
  const excerpt=payload.text_excerpt?`<details class="intake-excerpt"><summary>Rozpoznaný text dokumentu</summary><pre>${escapeHtml(payload.text_excerpt)}</pre></details>`:''
  const extractionNote=payload.extraction_method?.includes('ocr')?`OCR ${Math.round(Number(payload.ocr_confidence||0))} % · `:payload.extraction_method==='pdf_text'?'Textová vrstva · ':''
  $('intakeDrawerBody').innerHTML=`<div class="intake-review-top"><button class="btn secondary" id="intakeOpenOriginalBtn" type="button">Otevřít originál</button><span>${extractionNote}SHA-256 ${escapeHtml((row.sha256||'').slice(0,16))}… · soubor je uložen beze změny</span></div>${warningMarkup}${specialNotice}<div class="intake-form-grid">${intakeInput('intakeSupplierName','Dodavatel',payload.supplier_name||'')}${intakeInput('intakeSupplierCompanyId','IČO dodavatele',payload.supplier_company_id||'','text','inputmode="numeric"')}${intakeInput('intakeSupplierTaxId','DIČ dodavatele',payload.supplier_tax_id||'')}${intakeInput('intakeDocumentNumber','Číslo dokladu',payload.document_number||'')}<label class="intake-field"><span>Typ dokumentu</span><select class="field-control" id="intakeDocumentClass">${classOptions}</select></label>${intakeInput('intakeTotalAmount','Celkem',payload.total_amount??'','number','step="0.01"')}${intakeInput('intakeNetAmount','Bez DPH',payload.net_amount??'','number','step="0.01"')}${intakeInput('intakeVatAmount','DPH',payload.vat_amount??'','number','step="0.01"')}${intakeInput('intakeCurrency','Měna',payload.currency||'CZK','text','maxlength="3"')}${intakeInput('intakeVariableSymbol','Variabilní symbol',payload.variable_symbol||'','text','inputmode="numeric"')}${intakeInput('intakeIssueDate','Datum vystavení',payload.issue_date||'','date')}${intakeInput('intakeTaxableDate','DUZP',payload.taxable_date||'','date')}${intakeInput('intakeDueDate','Splatnost',payload.due_date||'','date')}${intakeInput('intakeBankAccount','Bankovní účet',payload.bank_account||'')}${intakeInput('intakeIban','IBAN',payload.iban||'')}${intakeInput('intakeCategory','Kategorie','')}${intakeInput('intakeCostCenter','Středisko','')}</div><label class="intake-field intake-field-wide"><span>Poznámka k rozhodnutí</span><textarea class="field-control" id="intakeReviewNote" rows="2" placeholder="Volitelné zdůvodnění nebo poznámka pro další kontrolu"></textarea></label><div class="intake-attach-box"><label class="intake-field intake-field-wide"><span>Přiřadit k existující faktuře</span><select class="field-control" id="intakeTargetInvoice"><option value="">Vyberte fakturu…</option>${invoiceOptions}</select></label>${assignedInvoice?`<div class="notice"><strong>Přiřazeno:</strong> ${escapeHtml(assignedInvoice.internal_number)} · ${escapeHtml(assignedInvoice.supplier_name)}</div>`:''}</div>${excerpt}`
  $('intakeOpenOriginalBtn').addEventListener('click',()=>openIntakeOriginal().catch((error)=>setStatus(error.message,'error')))
  $('intakeIgnoreBtn').hidden=!canDecide
  $('intakeReopenBtn').hidden=!canReopen
  $('intakeAttachBtn').hidden=!canDecide
  $('intakeCreateBtn').hidden=!canCreate
  $('intakeCreateBtn').textContent='Založit a předat ke schválení'
  $('intakeDocumentClass').addEventListener('change',(event)=>{$('intakeCreateBtn').hidden=!canDecide||!['invoice','credit_note','advance_invoice'].includes(event.target.value)})
  $('intakeDrawerBackdrop').classList.add('show')
}

function closeIntakeDrawer(){$('intakeDrawerBackdrop').classList.remove('show');activeIntakeRow=null}
async function openIntakeOriginal(){
  if(!activeIntakeRow?.storage_path)throw new Error('Originální soubor nemá uloženou cestu.')
  const {data,error}=await supabase.storage.from('finance-private').createSignedUrl(activeIntakeRow.storage_path,300)
  if(error)throw error
  window.open(data.signedUrl,'_blank','noopener')
}

function intakeFormValues(){
  return {supplier_name:$('intakeSupplierName')?.value.trim()||'',supplier_company_id:$('intakeSupplierCompanyId')?.value.trim()||'',supplier_tax_id:$('intakeSupplierTaxId')?.value.trim().toUpperCase()||'',document_number:$('intakeDocumentNumber')?.value.trim()||'',document_class:$('intakeDocumentClass')?.value||activeIntakeRow?.document_class,total_amount:$('intakeTotalAmount')?.value||'',net_amount:$('intakeNetAmount')?.value||'',vat_amount:$('intakeVatAmount')?.value||'',currency:$('intakeCurrency')?.value.trim().toUpperCase()||'CZK',variable_symbol:$('intakeVariableSymbol')?.value.trim()||'',issue_date:$('intakeIssueDate')?.value||'',taxable_date:$('intakeTaxableDate')?.value||'',due_date:$('intakeDueDate')?.value||'',bank_account:$('intakeBankAccount')?.value.trim()||'',iban:$('intakeIban')?.value.trim()||'',category:$('intakeCategory')?.value.trim()||'',cost_center:$('intakeCostCenter')?.value.trim()||'',reason:$('intakeReviewNote')?.value.trim()||''}
}

async function reviewIntake(action){
  if(!activeIntakeRow)return
  const row=activeIntakeRow,invoiceId=Number($('intakeTargetInvoice')?.value||0)||null,values=intakeFormValues()
  if(action==='attach'&&!invoiceId)throw new Error('Vyberte fakturu, ke které se má dokument přiřadit.')
  if(preview){row.status=action==='ignore'?'ignored':action==='reopen'?'needs_review':'invoice_created';closeIntakeDrawer();renderAll();setStatus('Rozhodnutí bylo v náhledu uloženo.','success');return}
  const {data,error}=await supabase.rpc('finance_review_intake_document_v1',{p_queue_id:row.id,p_action:action,p_invoice_id:invoiceId,p_values:values})
  if(error)throw error
  closeIntakeDrawer();await load()
  const message=action==='create'?`Byla založena faktura ${data?.internal_number||''} a čeká na schválení.`:action==='attach'?'Dokument byl přiřazen k existující faktuře.':action==='ignore'?'Dokument byl ignorován. Lze ho kdykoliv vrátit ke kontrole.':'Dokument je znovu ve frontě ke kontrole.'
  setStatus(message,'success','Originální příloha zůstala bezpečně uložená')
}

function renderTable() {
  const visible = filteredRows()
  $('invoiceBody').innerHTML = visible.length ? visible.map((row) => `<tr data-id="${row.id}" class="${selected.has(row.id) ? 'selected' : ''}"><td><input class="check row-check" data-id="${row.id}" type="checkbox" ${selected.has(row.id) ? 'checked' : ''}></td><td><span class="cell-main">${escapeHtml(row.internal_number)}</span><span class="cell-sub">${escapeHtml(row.document_number)} · VS ${escapeHtml(row.variable_symbol || '—')}</span></td><td><span class="cell-main">${escapeHtml(row.supplier_name)}</span><span class="cell-sub">IČ ${escapeHtml(row.supplier_id || '—')} · ${row.source_provider==='money_s3'?'<b>Money S3</b> · ':''}${escapeHtml(row.attachment_name || 'bez originálu')}</span></td><td>${date(row.issue_date)}<span class="cell-sub">DUZP ${date(row.taxable_date)}</span></td><td>${dueMarkup(row)}</td><td><span class="cell-main">${escapeHtml(row.category || 'Nezařazeno')}</span><span class="cell-sub">${badge(stockMap,row.stock_receipt_status||'not_applicable')}</span></td><td class="money">${money(row.net_amount,row.currency)}</td><td class="money">${money(row.total_amount,row.currency)}</td><td>${badge(statusMap,row.payment_status !== 'paid' && daysTo(row.due_date) < 0 ? 'overdue' : row.status)}</td><td>${badge(paymentMap,row.payment_status)}</td><td><button class="btn ghost small open-row" data-id="${row.id}" type="button">Detail</button></td></tr>`).join('') : '<tr><td colspan="11"><div class="empty">Pro zvolené filtry tu nejsou žádné faktury.</div></td></tr>'
  document.querySelectorAll('.row-check').forEach((el) => el.addEventListener('change', () => toggleSelection(Number(el.dataset.id), el.checked)))
  document.querySelectorAll('.open-row').forEach((el) => el.addEventListener('click', () => openDrawer(Number(el.dataset.id)).catch(error=>setStatus(error.message,'error'))))
  document.querySelectorAll('tbody tr[data-id]').forEach((el) => el.addEventListener('dblclick', () => openDrawer(Number(el.dataset.id)).catch(error=>setStatus(error.message,'error'))))
  $('selectAll').checked = visible.length > 0 && visible.every((row) => selected.has(row.id)); updateSelectionBar()
}

function updateSelectionBar() { const count = selected.size; $('selectionBar').classList.toggle('show', count > 0); $('selectionText').textContent = `${count} ${count === 1 ? 'vybraná faktura' : count < 5 ? 'vybrané faktury' : 'vybraných faktur'}` }
function toggleSelection(id, checked) { checked ? selected.add(id) : selected.delete(id); renderTable() }

function compatibleProduct(line,product){const invoiceUnit=String(line.unit_code||'').toLowerCase(),baseUnit=String(product.base_unit||'').toLowerCase();return invoiceUnit===baseUnit||[['kg','g'],['g','kg'],['l','ml'],['ml','l']].some(([from,to])=>invoiceUnit===from&&baseUnit===to)}
function productOptionLabel(product){return `${product.name}${product.sku?` · ${product.sku}`:''} · skladově ${product.base_unit}`}
function stockQuantityLabel(line,product){if(!product||!line.stock_quantity_base_units)return 'Po uložení se zobrazí množství pro sklad.';return `${Number(line.stock_quantity_base_units).toLocaleString('cs-CZ',{maximumFractionDigits:3})} ${product.base_unit} na sklad`}
function stockActionMarkup(stockStatus){
  const locationOptions=stockLocations.map(item=>`<option value="${item.id}">${escapeHtml(item.name)}</option>`).join('')
  if(stockStatus==='ready')return `<div class="notice" style="border-color:#abefc6;background:#ecfdf3;color:#067647"><strong>Všechny položky jsou spárované.</strong> Vyberte cílový sklad a připravte příjemku. Zásoba se zatím nezmění.<div class="row-actions" style="margin-top:10px"><select class="field-control" id="drawerStockLocation">${locationOptions}</select><button class="btn small" id="prepareStockReceiptBtn" type="button">Připravit příjemku</button></div></div>`
  if(stockStatus==='ordered')return `<div class="notice"><strong>Příjemka čeká na sklad.</strong> Běžné položky lze potvrdit zde; zboží se šarží nebo expirací se dokončí ve Skladových příjmech.<div class="row-actions" style="margin-top:10px"><button class="btn small" id="confirmStockReceiptBtn" type="button">Potvrdit naskladnění</button><a class="btn secondary small" href="purchases.html?view=received">Otevřít Skladové příjmy</a></div></div>`
  if(stockStatus==='needs_mapping')return '<div class="notice" style="border-color:#fedf89;background:#fffaeb;color:#93370d"><strong>Položková faktura:</strong> vyberte u každého řádku skladovou kartu, případně založte novou. Do skladu se zatím nic nezapsalo.</div>'
  if(stockStatus==='received')return '<div class="notice" style="border-color:#abefc6;background:#ecfdf3;color:#067647"><strong>Naskladněno:</strong> příjemka byla potvrzena a skladové pohyby jsou zapsané.</div>'
  return ''
}
function renderStockMapping(){
  const host=$('stockMappingHost');if(!host||!activeRow)return
  const editable=['needs_mapping','ready'].includes(activeRow.stock_receipt_status)
  if(!activeAllocations.length){host.innerHTML='<div class="stock-mapping-empty">Faktura nemá vytěžené skladové položky.</div>';return}
  host.innerHTML=`<section class="stock-mapping"><div class="stock-mapping-head"><div><h3>Položky faktury a sklad</h3><p>Spárování se zapamatuje podle dodavatele a jeho kódu pro příští faktury.</p></div><span class="badge ${activeAllocations.every(line=>line.product_id)?'good':'warn'}">${activeAllocations.filter(line=>line.product_id).length}/${activeAllocations.length} spárováno</span></div><div class="stock-mapping-list">${activeAllocations.map((line)=>{
    const selectedProduct=stockProducts.find(product=>String(product.id)===String(line.product_id));const compatible=stockProducts.filter(product=>compatibleProduct(line,product));const options=compatible.map(product=>`<option value="${product.id}" ${String(product.id)===String(line.product_id)?'selected':''}>${escapeHtml(productOptionLabel(product))}</option>`).join('')
    return `<article class="stock-mapping-row" data-allocation-id="${line.id}"><div class="stock-line-main"><strong>${escapeHtml(line.description)}</strong><span>Kód dodavatele ${escapeHtml(line.supplier_item_code||'—')} · ${Number(line.quantity||0).toLocaleString('cs-CZ',{maximumFractionDigits:3})} ${escapeHtml(line.unit_code||'')} · ${money(line.total_amount,activeRow.currency)}</span></div><div class="stock-line-control"><select class="field-control stock-product-select" ${editable?'':'disabled'}><option value="">Vyberte skladovou kartu…</option>${options}</select><small>${escapeHtml(stockQuantityLabel(line,selectedProduct))}</small></div>${editable?`<div class="stock-line-actions"><label><input class="remember-mapping" type="checkbox" checked> Zapamatovat pro dodavatele</label><div><button class="btn secondary small create-product-from-line" type="button">+ Nová karta</button><button class="btn small save-line-mapping" type="button" ${line.product_id?'':'disabled'}>Uložit párování</button></div></div>`:`<div class="stock-line-readonly">${selectedProduct?`<span class="badge good">${escapeHtml(selectedProduct.name)}</span>`:'<span class="badge warn">Bez skladové karty</span>'}</div>`}</article>`
  }).join('')}</div></section>`
  host.querySelectorAll('.stock-product-select').forEach(select=>select.addEventListener('change',()=>{select.closest('.stock-mapping-row').querySelector('.save-line-mapping').disabled=!select.value}))
  host.querySelectorAll('.save-line-mapping').forEach(button=>button.addEventListener('click',()=>saveInvoiceLineMapping(Number(button.closest('.stock-mapping-row').dataset.allocationId)).catch(error=>setStatus(error.message,'error'))))
  host.querySelectorAll('.create-product-from-line').forEach(button=>button.addEventListener('click',()=>openProductMappingModal(Number(button.closest('.stock-mapping-row').dataset.allocationId))))
}

async function openDrawer(id) {
  activeRow = rows.find((row) => row.id === id); if (!activeRow) return
  $('drawerTitle').textContent = `${activeRow.internal_number} · ${activeRow.supplier_name}`; $('drawerSubtitle').textContent = `${activeRow.document_number} · ${money(activeRow.total_amount,activeRow.currency)}`
  const stockStatus=activeRow.stock_receipt_status||'not_applicable'
  $('drawerBody').innerHTML = `<div class="detail-grid"><div class="detail"><span>Typ dokumentu</span><strong>${escapeHtml(documentClassMap[activeRow.document_class]||'Faktura')}</strong></div><div class="detail"><span>Originál</span><strong>${escapeHtml(activeRow.attachment_name || 'Bez originálu')}</strong></div><div class="detail"><span>Stav platby</span><strong>${badge(paymentMap,activeRow.payment_status)}</strong></div><div class="detail"><span>Skutečně zbývá</span><strong>${money(activeRow.operational_remaining_amount ?? activeRow.money_remaining_amount ?? 0)}</strong></div><div class="detail"><span>Potvrzeno bankou</span><strong>${money(activeRow.bank_confirmed_amount || 0)}</strong></div><div class="detail"><span>Stav skladu</span><strong>${badge(stockMap,stockStatus)}</strong></div><div class="detail"><span>Stav účetní</span><strong>${badge(accountingMap,activeRow.accounting_status || 'not_prepared')}</strong></div><div class="detail"><span>Bankovní účet</span><strong>${escapeHtml(activeRow.bank_account || 'Doplnit')}</strong></div><div class="detail"><span>Variabilní symbol</span><strong>${escapeHtml(activeRow.variable_symbol || '—')}</strong></div><div class="detail"><span>Celkem</span><strong>${money(activeRow.total_amount)}</strong></div></div>${stockActionMarkup(stockStatus)}${stockStatus!=='not_applicable'?'<div id="stockMappingHost"><div class="stock-mapping-empty">Načítám položky faktury…</div></div>':''}<div class="notice"><strong>Oddělené stavy:</strong> platební příkaz není úhrada, upomínka není nová faktura a faktura sama bez potvrzené příjemky nemění sklad.</div><div><h3 style="font-size:13px">Auditní stopa</h3><div class="timeline"><div class="timeline-row"><strong>Přijato ze zdroje ${escapeHtml(activeRow.source)}</strong>Originální soubor uložen beze změny a opatřen otiskem.</div><div class="timeline-row"><strong>Evidence platby: ${escapeHtml(activeRow.payment_evidence || 'Money S3')}</strong>${activeRow.bank_last_payment_at?`Poslední potvrzení bankou ${date(activeRow.bank_last_payment_at)}`:'Bankovní potvrzení zatím není dostupné.'}</div><div class="timeline-row"><strong>${escapeHtml(activeRow.approval)}</strong>${escapeHtml(activeRow.owner || 'Bez odpovědné osoby')}</div></div></div>`
  $('prepareStockReceiptBtn')?.addEventListener('click',()=>prepareStockReceipt().catch(error=>setStatus(error.message,'error')))
  $('confirmStockReceiptBtn')?.addEventListener('click',()=>confirmStockReceipt().catch(error=>setStatus(error.message,'error')))
  $('drawerBackdrop').classList.add('show')
  if(stockStatus!=='not_applicable'){
    if(preview){activeAllocations=[{id:201,invoice_id:activeRow.id,line_number:1,description:'White chocolate vending 1 kg',quantity:72,unit_code:'kg',unit_price:200,supplier_item_code:'980',product_id:null,stock_relevant:true,stock_quantity_base_units:null,total_amount:16128},{id:202,invoice_id:activeRow.id,line_number:2,description:'Čaj Lemon 1 kg',quantity:45,unit_code:'kg',unit_price:200,supplier_item_code:'652/A',product_id:null,stock_relevant:true,stock_quantity_base_units:null,total_amount:10080}];renderStockMapping();return}
    const requestedInvoiceId=activeRow.id
    const {data,error}=await supabase.from('finance_invoice_allocations').select('id,invoice_id,line_number,description,quantity,unit_code,unit_price,supplier_item_code,ean,product_id,stock_relevant,stock_quantity_base_units,net_amount,vat_amount,total_amount').eq('invoice_id',requestedInvoiceId).eq('stock_relevant',true).order('line_number')
    if(error)throw error
    if(activeRow?.id!==requestedInvoiceId)return
    activeAllocations=data||[];renderStockMapping()
  }
}

async function saveInvoiceLineMapping(allocationId){
  const row=document.querySelector(`.stock-mapping-row[data-allocation-id="${allocationId}"]`),productId=Number(row?.querySelector('.stock-product-select')?.value||0),remember=Boolean(row?.querySelector('.remember-mapping')?.checked)
  if(!productId)throw new Error('Vyberte skladovou kartu.');const invoiceId=activeRow?.id
  if(preview){const line=activeAllocations.find(item=>item.id===allocationId),product=stockProducts.find(item=>item.id===productId);line.product_id=productId;line.stock_quantity_base_units=line.quantity;activeRow.stock_receipt_status=activeAllocations.every(item=>item.product_id)?'ready':'needs_mapping';renderStockMapping();setStatus(`Náhled: položka byla spárována s kartou ${product?.name||''}.`,'success');return}
  const {data,error}=await supabase.rpc('finance_map_invoice_line_v1',{p_allocation_id:allocationId,p_product_id:productId,p_remember_for_supplier:remember});if(error)throw error
  await load();await openDrawer(invoiceId);setStatus(`Položka byla spárována: ${data?.product_name||'skladová karta'}.`,'success',data?.stock_receipt_status==='ready'?'Všechny položky jsou připravené k vytvoření příjemky':'Pokračujte další položkou')
}

function openProductMappingModal(allocationId){
  const line=activeAllocations.find(item=>item.id===allocationId);if(!line)return
  productMappingAllocationId=allocationId;$('mappingProductName').value=line.description||'';$('mappingProductSku').value='';$('mappingProductBaseUnit').value=['ks','kg','g','l','ml'].includes(String(line.unit_code||'').toLowerCase())?String(line.unit_code).toLowerCase():'kg';$('mappingProductCategory').value='ingredient';$('mappingProductSource').textContent=`Dodavatelský kód ${line.supplier_item_code||'—'} · ${Number(line.quantity||0).toLocaleString('cs-CZ',{maximumFractionDigits:3})} ${line.unit_code||''}`;$('mappingProductModal').classList.add('show')
}
function closeProductMappingModal(){$('mappingProductModal').classList.remove('show');productMappingAllocationId=null}
async function createAndMapProduct(){
  if(!productMappingAllocationId)return;const invoiceId=activeRow?.id,button=$('mappingProductCreate');button.disabled=true
  try{if(preview){const name=$('mappingProductName').value.trim();if(!name)throw new Error('Doplňte název skladové karty.');const product={id:Date.now(),name,sku:$('mappingProductSku').value.trim()||null,base_unit:$('mappingProductBaseUnit').value,product_category:$('mappingProductCategory').value};stockProducts.push(product);const line=activeAllocations.find(item=>item.id===productMappingAllocationId);line.product_id=product.id;line.stock_quantity_base_units=line.quantity;activeRow.stock_receipt_status=activeAllocations.every(item=>item.product_id)?'ready':'needs_mapping';closeProductMappingModal();renderStockMapping();setStatus(`Náhled: skladová karta ${name} byla založena a spárována.`,'success');return}const {data,error}=await supabase.rpc('finance_create_and_map_invoice_product_v1',{p_allocation_id:productMappingAllocationId,p_name:$('mappingProductName').value.trim(),p_sku:$('mappingProductSku').value.trim()||null,p_base_unit:$('mappingProductBaseUnit').value,p_product_category:$('mappingProductCategory').value});if(error)throw error;closeProductMappingModal();await load();await openDrawer(invoiceId);setStatus(`Skladová karta ${data?.product_name||''} byla založena a spárována.`,'success',data?.stock_receipt_status==='ready'?'Všechny položky jsou připravené k vytvoření příjemky':'Pokračujte další položkou')}finally{button.disabled=false}
}

async function prepareStockReceipt(){if(!activeRow)return;const locationId=Number($('drawerStockLocation')?.value||0);if(!locationId)throw new Error('Vyberte cílový sklad.');const {error}=await supabase.rpc('finance_prepare_purchase_receipt_v1',{p_invoice_id:activeRow.id,p_stock_location_id:locationId});if(error)throw error;closeDrawer();await load();setStatus('Skladová příjemka byla připravena. Zásoba se změní až po potvrzení příjmu.','success')}
async function confirmStockReceipt(){if(!activeRow)return;const {error}=await supabase.rpc('finance_confirm_stock_receipt_v1',{p_invoice_id:activeRow.id});if(error)throw error;closeDrawer();await load();setStatus('Položky byly naskladněny a příjemka je potvrzená.','success')}

function closeDrawer() { $('drawerBackdrop').classList.remove('show'); activeRow = null; activeAllocations=[] }
function paymentCandidates() { const picked = rows.filter((row) => selected.has(row.id)); return (picked.length ? picked : rows.filter((row) => row.status === 'ready_for_payment')).filter((row) => row.payment_status === 'unpaid') }
function openBatch() { const ids=rows.filter((row)=>selected.has(row.id)).map((row)=>row.id);location.href=`payment-orders.html${ids.length?`?invoices=${ids.join(',')}`:''}` }
function closeBatch() { $('batchModal').classList.remove('show') }

function openMoneyImport(){moneyImport={file:null,parsed:null,sha256:null};$('moneyXmlFile').value='';$('moneyPreviewCount').textContent='—';$('moneyPreviewUnpaid').textContent='—';$('moneyPreviewCredits').textContent='—';$('moneyPreviewTotal').textContent='—';$('moneyImportWarnings').innerHTML='';$('moneyImportPreview').style.display='none';$('moneyImportRun').disabled=true;$('moneyImportRun').textContent='Načíst do evidence';$('moneyImportModal').classList.add('show')}
function closeMoneyImport(){if($('moneyImportRun').disabled&&$('moneyImportRun').textContent.includes('Načítám'))return;$('moneyImportModal').classList.remove('show')}
async function previewMoneyFile(){const file=$('moneyXmlFile').files?.[0];if(!file)return;const button=$('moneyImportRun');button.disabled=true;setStatus('Kontroluji Money XML…');try{const buffer=await file.arrayBuffer();const parsed=parseMoneyReceivedInvoicesXml(new TextDecoder('utf-8').decode(buffer));moneyImport={file,parsed,sha256:await sha256Hex(buffer)};$('moneyPreviewCount').textContent=integer(parsed.summary.invoices);$('moneyPreviewUnpaid').textContent=integer(parsed.summary.unpaid);$('moneyPreviewCredits').textContent=integer(parsed.summary.credit_notes);$('moneyPreviewTotal').textContent=money(parsed.summary.total_amount);$('moneyImportWarnings').innerHTML=parsed.warnings.length?`<div class="notice" style="border-color:#fedf89;background:#fffaeb;color:#93370d">${parsed.warnings.map(escapeHtml).join('<br>')}</div>`:'<div class="notice">Soubor je připravený bez upozornění.</div>';$('moneyImportPreview').style.display='block';$('moneyImportPreview').innerHTML=`<strong>${escapeHtml(file.name)}</strong><br>Účetní rok ${escapeHtml(parsed.accounting_year_start||'—')} až ${escapeHtml(parsed.accounting_year_end||'—')} · export ${escapeHtml(parsed.exported_at||'—')} · SHA-256 ${escapeHtml(moneyImport.sha256.slice(0,12))}…`;button.disabled=false;setStatus(`Money XML obsahuje ${integer(parsed.summary.invoices)} přijatých faktur.`,'success','Náhled · zatím bez zápisu')}
catch(error){moneyImport={file:null,parsed:null,sha256:null};$('moneyImportWarnings').innerHTML=`<div class="notice" style="border-color:#fecdca;background:#fff5f5;color:#b42318">${escapeHtml(error.message)}</div>`;setStatus(`Money XML nelze načíst: ${error.message}`,'error')}}
async function runMoneyImport(){if(!moneyImport.parsed||!moneyImport.file)return;const button=$('moneyImportRun');button.disabled=true;const chunks=[];for(let i=0;i<moneyImport.parsed.rows.length;i+=75)chunks.push(moneyImport.parsed.rows.slice(i,i+75));let processed=0,matched=0;try{for(let index=0;index<chunks.length;index+=1){button.textContent=`Načítám ${index+1}/${chunks.length}…`;const isFinal=index===chunks.length-1;if(preview){processed+=chunks[index].length;continue}const {data,error}=await supabase.rpc('finance_import_money_received_invoices_v3',{p_rows:chunks[index],p_file_name:moneyImport.file.name,p_file_sha256:moneyImport.sha256,p_exported_at:moneyImport.parsed.exported_at,p_total_rows:moneyImport.parsed.rows.length,p_is_final:isFinal});if(error)throw error;processed+=Number(data?.processed||0);matched+=Number(data?.matched_attachments||0)}$('moneyImportModal').classList.remove('show');activeTab='open';document.querySelectorAll('[data-tab]').forEach((item)=>item.classList.toggle('active',item.dataset.tab==='open'));await load();setStatus(`Načteno ${integer(processed)} faktur z Money S3.`, 'success', `${integer(matched)} e-mailových příloh automaticky spárováno`)}catch(error){setStatus(`Import Money se nezdařil: ${error.message}`,'error','Dosud zpracované dávky lze bezpečně načíst znovu')}finally{button.disabled=false;button.textContent='Načíst do evidence'}}

async function createBatch() {
  const items = paymentCandidates(); if (!items.length) return
  if (preview) { items.forEach((row) => { row.status = 'in_payment_batch'; row.payment_status = 'ordered' }); selected.clear(); closeBatch(); renderAll(); setStatus(`Platební dávka HP-2026-0119 byla připravena pro ${items.length} plateb.`, 'success', 'Náhled · čeká na autorizaci v bance'); return }
  const { data, error } = await supabase.rpc('finance_create_payment_batch_v1', { p_invoice_ids:items.map((row) => row.id), p_debtor_account:$('debtorAccountSelect').value }); if (error) throw error
  closeBatch(); selected.clear(); await load(); setStatus(`Platební dávka ${data?.batch_number || ''} byla vytvořena.`, 'success', 'Čeká na autorizaci v bance')
}

function renderAll() { renderMetrics(); renderIntake(); renderTable() }
function missingSchema(error) { return /finance_received|schema cache|does not exist|could not find/i.test(String(error?.message || error || '')) }
async function load() {
  if (preview) { rows = [...demoRows]; stockLocations=[{id:1,name:'BLUČINA'}];stockProducts=[{id:101,name:'White chocolate vending 1 kg',sku:'WC-1KG',base_unit:'kg',product_category:'ingredient'},{id:102,name:'Čaj Lemon 1 kg',sku:'TEA-LEMON',base_unit:'kg',product_category:'ingredient'}];intakeRows=[{id:1,file_name:'faktura-2026-118.pdf',mime_type:'application/pdf',size_bytes:184220,sender_address:'dodavatel@example.cz',subject:'Faktura 2026-118',message_received_at:new Date().toISOString(),discovered_at:new Date().toISOString(),status:'needs_review',document_class:'invoice',extraction_confidence:83,sha256:'a'.repeat(64),storage_path:'preview/faktura.pdf',warnings:['Chybí dodavatel'],extracted_payload:{document_number:'2026-118',total_amount:12540,currency:'CZK',due_date:'2026-11-30',variable_symbol:'2026118',text_excerpt:'Faktura č. 2026-118\nCelkem k úhradě 12 540,00 Kč'}}]; renderAll(); setStatus('Vývojový náhled knihy přijatých faktur je připravený.', 'success', 'Ukázková data · bez zápisu'); return }
  try { const [{data,error},{data:intake,error:intakeError},{data:locations,error:locationError},{data:products,error:productError}] = await Promise.all([supabase.from('finance_received_invoice_overview_v1').select('*').order('due_date',{ascending:true}),supabase.from('finance_document_intake_queue').select('id,file_name,mime_type,size_bytes,sender_address,subject,message_received_at,discovered_at,processed_at,status,error_message,document_class,extraction_confidence,extracted_payload,warnings,invoice_id,storage_path,sha256').order('discovered_at',{ascending:false}).limit(250),supabase.from('stock_locations').select('id,name').eq('location_type','warehouse').eq('active',true).order('name'),supabase.from('products').select('id,name,sku,base_unit,product_category').eq('active',true).order('name')]); if (error) throw error;if(intakeError)throw intakeError;if(locationError)throw locationError;if(productError)throw productError; rows = (data || []).map((row)=>({...row,supplier_id:row.supplier_company_id,confidence:row.extraction_confidence??0,source:row.source_provider,approval:row.approved_at?'Schváleno v OLVENDU':'Čeká na kontrolu'}));intakeRows=intake||[];stockLocations=locations||[];stockProducts=products||[]; renderAll(); setStatus('Přijaté faktury jsou aktuální.','success',`${intakeRows.filter((row)=>row.status==='needs_review').length} ke kontrole · ${rows.length} faktur v evidenci`) }
  catch (error) { console.error(error); rows = []; intakeRows=[]; renderAll(); setStatus(missingSchema(error) ? 'Databázové závazkové jádro zatím není nasazené.' : `Faktury se nepodařilo načíst: ${error.message}`,'error','Ukázková data se v ostrém provozu nezobrazují') }
}

async function updateInvoice(id,patch,successText){
  if(preview){Object.assign(rows.find((row)=>row.id===id)||{},patch);renderAll();setStatus(successText,'success');return}
  const {error}=await supabase.from('finance_received_invoices').update({...patch,updated_at:new Date().toISOString()}).eq('id',id)
  if(error)throw error
  await load();setStatus(successText,'success')
}

document.querySelectorAll('[data-tab]').forEach((button) => button.addEventListener('click', () => { activeTab = button.dataset.tab; document.querySelectorAll('[data-tab]').forEach((item) => item.classList.toggle('active',item === button)); selected.clear(); renderTable() }))
document.querySelectorAll('[data-intake-tab]').forEach((button)=>button.addEventListener('click',()=>{activeIntakeTab=button.dataset.intakeTab;document.querySelectorAll('[data-intake-tab]').forEach((item)=>item.classList.toggle('active',item===button));renderIntake()}))
;['searchInput','categoryFilter','dueFilter','ownerFilter'].forEach((id) => $(id).addEventListener(id === 'searchInput' ? 'input' : 'change',renderTable))
;$('intakeSearchInput').addEventListener('input',renderIntake);$('intakeClassFilter').addEventListener('change',renderIntake);$('intakeRefreshBtn').addEventListener('click',()=>load())
$('selectAll').addEventListener('change',() => { filteredRows().forEach((row) => $('selectAll').checked ? selected.add(row.id) : selected.delete(row.id)); renderTable() })
$('drawerClose').addEventListener('click',closeDrawer); $('drawerBackdrop').addEventListener('click',(event) => { if (event.target === $('drawerBackdrop')) closeDrawer() })
$('mappingProductClose').addEventListener('click',closeProductMappingModal);$('mappingProductCancel').addEventListener('click',closeProductMappingModal);$('mappingProductModal').addEventListener('click',(event)=>{if(event.target===$('mappingProductModal'))closeProductMappingModal()});$('mappingProductCreate').addEventListener('click',()=>createAndMapProduct().catch(error=>setStatus(error.message,'error')))
$('intakeDrawerClose').addEventListener('click',closeIntakeDrawer);$('intakeDrawerBackdrop').addEventListener('click',(event)=>{if(event.target===$('intakeDrawerBackdrop'))closeIntakeDrawer()})
$('intakeIgnoreBtn').addEventListener('click',()=>reviewIntake('ignore').catch((error)=>setStatus(error.message,'error')));$('intakeReopenBtn').addEventListener('click',()=>reviewIntake('reopen').catch((error)=>setStatus(error.message,'error')));$('intakeAttachBtn').addEventListener('click',()=>reviewIntake('attach').catch((error)=>setStatus(error.message,'error')));$('intakeCreateBtn').addEventListener('click',()=>reviewIntake('create').catch((error)=>setStatus(error.message,'error')))
$('drawerApprove').addEventListener('click',() => { if (!activeRow) return; const row=activeRow; closeDrawer(); updateInvoice(row.id,{status:'ready_for_payment',approved_at:new Date().toISOString()},`${row.internal_number} je připravena k platbě.`).catch((error)=>setStatus(error.message,'error')) })
$('drawerReturn').addEventListener('click',() => { if (!activeRow) return; const row=activeRow; closeDrawer(); updateInvoice(row.id,{status:'rejected'},`${row.internal_number} byla vrácena k doplnění.`).catch((error)=>setStatus(error.message,'error')) })
$('batchBtn').addEventListener('click',openBatch); $('newBatchTopBtn').addEventListener('click',openBatch); $('batchClose').addEventListener('click',closeBatch); $('batchCancel').addEventListener('click',closeBatch); $('batchCreate').addEventListener('click',() => createBatch().catch((error) => setStatus(error.message,'error')))
$('moneyImportBtn').addEventListener('click',openMoneyImport);$('moneyImportClose').addEventListener('click',closeMoneyImport);$('moneyImportCancel').addEventListener('click',closeMoneyImport);$('moneyImportModal').addEventListener('click',(event)=>{if(event.target===$('moneyImportModal'))closeMoneyImport()});$('moneyXmlFile').addEventListener('change',previewMoneyFile);$('moneyImportRun').addEventListener('click',runMoneyImport)
$('approveBtn').addEventListener('click',async() => { const ids=[...selected];if(!ids.length)return;try{if(preview){rows.filter((row)=>selected.has(row.id)).forEach((row)=>{row.status='ready_for_payment'})}else{const {error}=await supabase.from('finance_received_invoices').update({status:'ready_for_payment',approved_at:new Date().toISOString(),updated_at:new Date().toISOString()}).in('id',ids);if(error)throw error;await load()}selected.clear();renderAll();setStatus(`${ids.length} doklady byly schváleny.`,'success')}catch(error){setStatus(error.message,'error')}})
$('assignBtn').addEventListener('click',() => setStatus('Hromadné přiřazení bude navázané na seznam odpovědných osob.','success'))
$('syncBtn').addEventListener('click',async()=>{const button=$('syncBtn');button.disabled=true;button.textContent='Synchronizuji…';setStatus('Načítám nové přílohy z fakturace@olmika.cz…');try{if(!preview)await mailApi('/finance/sync',{method:'POST',timeoutMs:120000});await load()}catch(error){setStatus(`Synchronizace se nezdařila: ${error.message}`,'error','Zkontrolujte napojení schránky')}finally{button.disabled=false;button.textContent='Synchronizovat e-mail'}})
if (window.OlvendSidebar) { window.OlvendSidebar.initMobileNav($('mobileNavShell')); window.OlvendSidebar.setActive('received-invoices') }
if (preview) document.querySelectorAll('a[href="accountant-portal.html"]').forEach((link) => { link.href = 'accountant-portal.html?preview=1' })
load()
