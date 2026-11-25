import {supabase} from './supabase.js'
import {parseMoneyLiabilitiesXml,sha256Hex} from './money-liabilities-core.mjs?v=20261121finance-liability-payees-v2'

const $=id=>document.getElementById(id)
const preview=new URL(location.href).searchParams.get('preview')==='1'
const money=(v,c='CZK')=>new Intl.NumberFormat('cs-CZ',{style:'currency',currency:c,maximumFractionDigits:2}).format(Number(v||0))
const integer=v=>new Intl.NumberFormat('cs-CZ').format(Number(v||0))
const date=v=>v?new Intl.DateTimeFormat('cs-CZ').format(new Date(`${v}T12:00:00`)):'—'
const escapeHtml=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]))
const paymentMap={unpaid:['Neuhrazeno','warn'],ordered:['V příkazu','violet'],partially_paid:['Částečně','warn'],paid:['Uhrazeno','good'],overpaid:['Přeplatek','info'],cancelled:['Nulový doklad','']}
const accountingMap={not_prepared:['Nepředáno',''],prepared:['Připraveno','info'],downloaded:['Staženo účetní','violet'],booked:['Zaúčtováno','good'],returned:['Vráceno','bad']}
const orderMap={draft:['Koncept',''],ready:['Připraven','info'],uploaded:['Nahrán','violet'],awaiting_authorization:['Čeká na autorizaci','warn'],authorized:['Autorizován','info'],awaiting_bank_confirmation:['Čeká na banku','warn'],processed:['Proveden','good'],cancelled:['Zrušen','bad']}
const badge=(map,value)=>{const x=map[value]||[value||'—',''];return `<span class="badge ${x[1]}">${escapeHtml(x[0])}</span>`}
const bankStateMap={review:['Ke kontrole','warn'],partial_review:['Částečně spárováno','info'],matched:['Spárováno','good'],income:['Příjem','violet']}
let liabilities=[],orders=[],bank=[],invoiceTargets=[],activeTab='liabilities',activeBankRow=null,importState={file:null,parsed:null,sha:null}

const normalizedDigits=value=>String(value||'').replace(/\D/g,'').replace(/^0+/,'')
const accountKey=value=>{const parts=String(value||'').split('/');return `${normalizedDigits(parts[0].split('-').pop())}/${normalizedDigits(parts[1])}`}
const bankTargets=row=>Array.isArray(row.matched_targets)?row.matched_targets:[]
const targetRemaining=(row,kind)=>Math.max(0,Number(kind==='invoice'?row.operational_remaining_amount:row.bank_unconfirmed_amount||0))
function candidateScore(row,kind,tx=activeBankRow){
  if(!tx)return 0
  let score=0
  const txAmount=Number(tx.remaining_to_match||Math.abs(Number(tx.amount||0)))
  const remaining=targetRemaining(row,kind)
  if(Math.abs(remaining-txAmount)<.01)score+=60
  if(normalizedDigits(row.variable_symbol)&&normalizedDigits(row.variable_symbol)===normalizedDigits(tx.variable_symbol))score+=80
  if(accountKey(row.bank_account)!=='/'&&accountKey(row.bank_account)===accountKey(`${tx.counterparty_account||''}/${tx.counterparty_bank_code||''}`))score+=55
  const targetName=String(kind==='invoice'?row.supplier_name:row.payee_name||row.description||'').toLowerCase()
  if(targetName&&String(tx.counterparty_name||'').toLowerCase().includes(targetName.slice(0,8)))score+=20
  return score
}

function setStatus(text,type='',meta='Money S3 + Raiffeisenbank'){$('statusText').textContent=text;$('statusMeta').textContent=meta;$('statusStrip').className=`status-strip ${type}`.trim()}
function renderMetrics(){
  const open=liabilities.reduce((s,r)=>s+Math.max(0,Number(r.actual_remaining_amount||0)),0)
  const ordered=liabilities.reduce((s,r)=>s+Math.max(0,Number(r.ordered_amount||0)),0)
  const orderable=liabilities.reduce((s,r)=>s+Math.max(0,Number(r.orderable_remaining_amount||0)),0)
  const confirmed=liabilities.reduce((s,r)=>s+Math.max(0,Number(r.bank_confirmed_amount||0)),0)
  $('metricOpen').textContent=money(open);$('metricOpenNote').textContent=`${integer(liabilities.filter(r=>Number(r.actual_remaining_amount)>.01).length)} otevřených závazků`
  $('metricOrdered').textContent=money(ordered);$('metricOrderedNote').textContent=`${integer(liabilities.filter(r=>Number(r.ordered_amount)>.01).length)} dokladů čeká na banku`
  $('metricOrderable').textContent=money(orderable);$('metricOrderableNote').textContent=`${integer(liabilities.filter(r=>Number(r.orderable_remaining_amount)>.01).length)} dokladů bez příkazu`
  $('metricBank').textContent=money(confirmed);$('metricBankNote').textContent=`${integer(liabilities.filter(r=>Number(r.bank_confirmed_amount)>.01).length)} závazků s bankovním důkazem`
  $('metricAccounting').textContent=integer(liabilities.filter(r=>r.accounting_status==='prepared').length)
}
function renderLiabilities(){
  const q=$('searchInput').value.trim().toLowerCase(),status=$('statusFilter').value,category=$('categoryFilter').value
  const rows=liabilities.filter(r=>(!q||`${r.internal_number} ${r.description} ${r.payee_name||''} ${r.bank_account||''} ${r.variable_symbol||''}`.toLowerCase().includes(q))&&(!status||r.payment_status===status)&&(!category||r.category===category))
  $('liabilityBody').innerHTML=rows.length?rows.map(r=>`<tr><td><span class="cell-main">${escapeHtml(r.internal_number)}</span><span class="cell-sub">Money S3</span></td><td><span class="cell-main">${escapeHtml(r.payee_name||r.description)}</span><span class="cell-sub">${r.payee_name?escapeHtml(r.description):''}</span></td><td>${date(r.due_date)}</td><td>${escapeHtml(r.category)}</td><td class="money">${money(r.total_amount,r.currency)}</td><td class="money">${money(r.actual_remaining_amount,r.currency)}</td><td class="money">${money(r.ordered_amount,r.currency)}</td><td class="money">${money(r.orderable_remaining_amount,r.currency)}</td><td>${badge(paymentMap,r.payment_status)}</td><td>${badge(accountingMap,r.accounting_status)}</td></tr>`).join(''):'<tr><td colspan="10"><div class="empty">Pro zvolené filtry tu nejsou žádné závazky.</div></td></tr>'
  $('liabilityVisibleCount').textContent=integer(rows.length)
  $('liabilityVisibleTotal').textContent=money(rows.reduce((sum,row)=>sum+Number(row.total_amount||0),0))
  $('liabilityVisibleOpen').textContent=money(rows.reduce((sum,row)=>sum+Math.max(0,Number(row.actual_remaining_amount||0)),0))
}
function renderOrders(){$('orderBody').innerHTML=orders.length?orders.map(r=>`<tr><td><span class="cell-main">${escapeHtml(r.batch_number)}</span><span class="cell-sub">${escapeHtml(r.bank_provider)}</span></td><td>${date(r.requested_execution_date)}</td><td>${integer(r.payment_count)}</td><td class="money">${money(r.total_amount,r.currency)}</td><td>${badge(orderMap,r.status)}</td></tr>`).join(''):'<tr><td colspan="5"><div class="empty">Zatím nejsou evidované žádné platební příkazy.</div></td></tr>'}
function renderBank(){
  const q=$('bankSearchInput').value.trim().toLowerCase(),state=$('bankStateFilter').value
  const latestRow=bank[0],latestKey=latestRow?.source_file_sha256||latestRow?.statement_number||latestRow?.booked_on
  const isLatest=row=>(row.source_file_sha256||row.statement_number||row.booked_on)===latestKey
  const allReviewRows=bank.filter(r=>['review','partial_review'].includes(r.match_state))
  const reviewRows=allReviewRows.filter(isLatest)
  const footerReviewRows=state==='review_all'?allReviewRows:reviewRows
  const rows=bank.filter(r=>{
    const stateMatch=state==='all'||(state==='review_latest'&&['review','partial_review'].includes(r.match_state)&&isLatest(r))||(state==='review_all'&&['review','partial_review'].includes(r.match_state))||(state==='matched'&&r.match_state==='matched')||(state==='income'&&r.match_state==='income')
    const text=`${r.counterparty_name||''} ${r.counterparty_account||''} ${r.variable_symbol||''} ${r.message||''}`.toLowerCase()
    return stateMatch&&(!q||text.includes(q))
  })
  $('bankRange').textContent=rows.length?`${date(rows[rows.length-1].booked_on)}–${date(rows[0].booked_on)}`:'—'
  $('bankReviewCount').textContent=integer(reviewRows.length);$('bankReviewCount').hidden=!reviewRows.length
  $('bankVisibleCount').textContent=integer(rows.length)
  $('bankReviewFooterCount').textContent=integer(footerReviewRows.length)
  $('bankReviewAmount').textContent=money(footerReviewRows.reduce((sum,row)=>sum+Number(row.remaining_to_match||0),0))
  $('bankBody').innerHTML=rows.length?rows.map(r=>{
    const targets=bankTargets(r)
    const targetMarkup=targets.length?`<div class="bank-match-targets">${targets.map(target=>`<div class="bank-match-target"><span class="badge good">${escapeHtml(target.number||'Doklad')}</span><small>${escapeHtml(target.name||'')} · ${money(target.amount,r.currency)}</small>${target.method==='manual'?`<button class="btn ghost small bank-unmatch-button" type="button" data-unmatch-id="${Number(target.match_id)}">Zrušit</button>`:''}</div>`).join('')}</div>`:`<span class="badge ${bankStateMap[r.match_state]?.[1]||''}">${escapeHtml(bankStateMap[r.match_state]?.[0]||'—')}</span>${r.review_reason?`<small class="bank-review-reason">${escapeHtml(r.review_reason)}</small>`:''}`
    const canMatch=['review','partial_review'].includes(r.match_state)
    return `<tr class="${r.match_state==='review'?'bank-review-row':r.match_state==='partial_review'?'bank-review-row partial':''}"><td>${date(r.booked_on)}</td><td><span class="cell-main">${escapeHtml(r.counterparty_name||'—')}</span><span class="cell-sub">${escapeHtml([r.counterparty_account,r.counterparty_bank_code].filter(Boolean).join('/'))}</span></td><td><span class="cell-main">VS ${escapeHtml(r.variable_symbol||'—')}</span><span class="cell-sub">${escapeHtml(r.message||'Bez zprávy')}</span></td><td class="money" style="color:${Number(r.amount)<0?'#b42318':'#067647'}">${money(r.amount,r.currency)}${r.match_state==='partial_review'?`<span class="cell-sub">zbývá ${money(r.remaining_to_match,r.currency)}</span>`:''}</td><td>${targetMarkup}</td><td>${canMatch?`<button class="btn small" type="button" data-match-bank="${Number(r.id)}">${r.match_state==='partial_review'?'Dopárovat':'Spárovat'}</button>`:''}</td></tr>`
  }).join(''):`<tr><td colspan="6"><div class="empty">${state.startsWith('review')?'Žádné bankovní platby nyní nečekají na kontrolu.':'Pro zvolený filtr nejsou žádné pohyby.'}</div></td></tr>`
}
function targetRows(kind){return kind==='invoice'?invoiceTargets:liabilities}
function targetLabel(row,kind){
  const number=kind==='invoice'?row.internal_number:row.internal_number
  const name=kind==='invoice'?row.supplier_name:row.payee_name||row.description
  const vs=row.variable_symbol?` · VS ${row.variable_symbol}`:''
  return `${number} · ${name||'Bez názvu'} · zbývá ${money(targetRemaining(row,kind),row.currency)}${vs}`
}
function renderTargetOptions(){
  const kind=$('bankTargetKind').value,q=$('bankTargetSearch').value.trim().toLowerCase(),current=$('bankTargetSelect').value
  const rows=targetRows(kind).filter(row=>targetRemaining(row,kind)>.009&&(!q||`${row.internal_number||''} ${kind==='invoice'?row.supplier_name||'':row.payee_name||row.description||''} ${row.variable_symbol||''} ${row.bank_account||''} ${row.total_amount||''}`.toLowerCase().includes(q))).sort((a,b)=>candidateScore(b,kind)-candidateScore(a,kind)||String(a.due_date||'').localeCompare(String(b.due_date||''))).slice(0,250)
  $('bankTargetSelect').innerHTML=rows.map(row=>`<option value="${Number(row.id)}">${candidateScore(row,kind)>=60?'★ ':''}${escapeHtml(targetLabel(row,kind))}</option>`).join('')
  if(current&&rows.some(row=>String(row.id)===current))$('bankTargetSelect').value=current
  if(!$('bankTargetSelect').value&&rows.length)$('bankTargetSelect').value=String(rows[0].id)
  updateTargetHint()
}
function selectedTarget(){const kind=$('bankTargetKind').value,id=Number($('bankTargetSelect').value);return targetRows(kind).find(row=>Number(row.id)===id)}
function updateTargetHint(){
  const row=selectedTarget(),kind=$('bankTargetKind').value
  if(!row){$('bankTargetHint').textContent='Pro toto hledání není žádný otevřený doklad.';return}
  const remaining=targetRemaining(row,kind),txRemaining=Number(activeBankRow?.remaining_to_match||0),suggested=Math.min(remaining,txRemaining)
  if(!$('bankMatchAmount').value||Number($('bankMatchAmount').value)>remaining+.01||Number($('bankMatchAmount').value)>txRemaining+.01)$('bankMatchAmount').value=suggested.toFixed(2)
  $('bankTargetHint').innerHTML=`<strong>Vybraný doklad:</strong> ${escapeHtml(targetLabel(row,kind))}<br>Z bankovní platby lze ještě přiřadit ${money(txRemaining,activeBankRow?.currency)}.`
}
function openBankMatch(row){
  activeBankRow=row
  $('bankMatchTransaction').innerHTML=`<div><span>Datum</span><strong>${date(row.booked_on)}</strong></div><div><span>Protistrana</span><strong>${escapeHtml(row.counterparty_name||'—')}</strong></div><div><span>VS</span><strong>${escapeHtml(row.variable_symbol||'—')}</strong></div><div><span>Zbývá přiřadit</span><strong>${money(row.remaining_to_match,row.currency)}</strong></div>`
  $('bankTargetSearch').value='';$('bankMatchNote').value='';$('bankMatchAmount').value=Number(row.remaining_to_match||0).toFixed(2)
  const bestInvoice=invoiceTargets.filter(r=>targetRemaining(r,'invoice')>.009).sort((a,b)=>candidateScore(b,'invoice',row)-candidateScore(a,'invoice',row))[0]
  const bestLiability=liabilities.filter(r=>targetRemaining(r,'liability')>.009).sort((a,b)=>candidateScore(b,'liability',row)-candidateScore(a,'liability',row))[0]
  $('bankTargetKind').value=candidateScore(bestLiability||{},'liability',row)>candidateScore(bestInvoice||{},'invoice',row)?'liability':'invoice'
  renderTargetOptions();$('bankMatchModal').classList.add('show');$('bankTargetSearch').focus()
}
function closeBankMatch(){$('bankMatchModal').classList.remove('show');activeBankRow=null}
async function saveBankMatch(){
  const target=selectedTarget(),button=$('bankMatchSave'),amount=Number($('bankMatchAmount').value)
  if(!activeBankRow||!target){setStatus('Vyberte konkrétní doklad.','error');return}
  if(!Number.isFinite(amount)||amount<=0){setStatus('Zadejte platnou částku párování.','error');return}
  button.disabled=true;button.textContent='Ukládám…'
  try{
    if(preview){closeBankMatch();return}
    const {error}=await supabase.rpc('finance_manual_match_bank_transaction_v1',{p_bank_transaction_id:activeBankRow.id,p_target_kind:$('bankTargetKind').value,p_target_id:target.id,p_amount:amount,p_note:$('bankMatchNote').value.trim()||null})
    if(error)throw error
    closeBankMatch();await load();activeTab='bank';showActiveTab();setStatus('Bankovní platba byla spárována a zůstatky dokladu jsou přepočítané.','success','Ruční potvrzení')
  }catch(error){console.error(error);setStatus(`Párování se nepodařilo: ${error.message}`,'error')}
  finally{button.disabled=false;button.textContent='Potvrdit spárování'}
}
async function rejectManualMatch(matchId){
  if(!confirm('Opravdu zrušit toto ruční párování? Bankovní pohyb se vrátí do fronty ke kontrole.'))return
  try{
    if(!preview){const {error}=await supabase.rpc('finance_reject_manual_bank_match_v1',{p_match_id:matchId});if(error)throw error}
    await load();setStatus('Ruční párování bylo zrušeno a platba je znovu ke kontrole.','success','Bez změny bankovního originálu')
  }catch(error){console.error(error);setStatus(`Párování nelze zrušit: ${error.message}`,'error')}
}
function showActiveTab(){
  document.querySelectorAll('[data-tab]').forEach(button=>button.classList.toggle('active',button.dataset.tab===activeTab))
  $('liabilityPanel').style.display=activeTab==='liabilities'?'block':'none';$('orderPanel').style.display=activeTab==='orders'?'block':'none';$('bankPanel').style.display=activeTab==='bank'?'block':'none'
}
function renderAll(){renderMetrics();renderLiabilities();renderOrders();renderBank()}
async function load(){
  if(preview){liabilities=[{id:1,internal_number:'ZA-DEMO-01',description:'Ukázkový závazek',payee_name:'DEMO příjemce',category:'Ostatní závazky',due_date:'2026-11-20',currency:'CZK',total_amount:2500,actual_remaining_amount:2500,bank_unconfirmed_amount:2500,ordered_amount:2500,orderable_remaining_amount:0,bank_confirmed_amount:0,payment_status:'ordered',accounting_status:'not_prepared'}];invoiceTargets=[{id:2,internal_number:'FP-DEMO-01',supplier_name:'DEMO dodavatel',document_number:'DEMO-2026-01',due_date:'2026-11-22',currency:'CZK',total_amount:1234.56,operational_remaining_amount:1234.56,variable_symbol:'20260001',bank_account:'123456789/0100'}];orders=[{batch_number:'DEMO-2026-01',bank_provider:'raiffeisenbank',requested_execution_date:'2026-11-21',payment_count:1,total_amount:2500,currency:'CZK',status:'awaiting_bank_confirmation'}];bank=[{id:1,booked_on:'2026-11-16',counterparty_name:'DEMO dodavatel',counterparty_account:'123456789',counterparty_bank_code:'0100',variable_symbol:'20260001',message:'Ukázková úhrada',amount:-1234.56,currency:'CZK',matched_amount:0,remaining_to_match:1234.56,match_state:'review',review_reason:'Nebyl nalezen jediný doklad se shodným VS, účtem a částkou.',matched_targets:[]}];renderAll();setStatus('Vývojový náhled je připravený.','success','Smyšlená demo data');return}
  try{
    const [{data:l,error:le},{data:o,error:oe},{data:b,error:be},{data:review,error:re},{data:invoices,error:ie}]=await Promise.all([
      supabase.from('finance_liability_overview_v1').select('*').order('due_date',{ascending:false}),
      supabase.from('finance_payment_batches').select('*').order('requested_execution_date',{ascending:false}),
      supabase.from('finance_bank_transaction_overview_v1').select('*').order('booked_on',{ascending:false}).order('id',{ascending:false}).limit(500),
      supabase.from('finance_bank_transaction_overview_v1').select('*').in('match_state',['review','partial_review']).order('booked_on',{ascending:false}).order('id',{ascending:false}),
      supabase.from('finance_received_invoice_overview_v1').select('id,internal_number,supplier_name,document_number,due_date,currency,total_amount,operational_remaining_amount,variable_symbol,bank_account,payment_status').gt('operational_remaining_amount',.009).order('due_date',{ascending:false})
    ])
    if(le)throw le;if(oe)throw oe;if(be)throw be;if(re)throw re;if(ie)throw ie
    liabilities=l||[];orders=o||[];invoiceTargets=invoices||[]
    bank=[...new Map([...(review||[]),...(b||[])].map(row=>[row.id,row])).values()].sort((a,b)=>String(b.booked_on).localeCompare(String(a.booked_on))||Number(b.id)-Number(a.id))
    const categories=[...new Set(liabilities.map(r=>r.category).filter(Boolean))].sort((a,b)=>a.localeCompare(b,'cs'))
    $('categoryFilter').innerHTML='<option value="">Všechny kategorie</option>'+categories.map(x=>`<option>${escapeHtml(x)}</option>`).join('')
    const latestKey=bank[0]?.source_file_sha256||bank[0]?.statement_number||bank[0]?.booked_on
    const latestReviewCount=bank.filter(row=>['review','partial_review'].includes(row.match_state)&&(row.source_file_sha256||row.statement_number||row.booked_on)===latestKey).length
    renderAll();setStatus('Závazky a bankovní pohyby jsou aktuální.','success',`${integer(latestReviewCount)} plateb z posledního výpisu ke kontrole`)
  }catch(error){console.error(error);setStatus(`Data se nepodařilo načíst: ${error.message}`,'error')}
}
function openImport(){importState={file:null,parsed:null,sha:null};$('xmlFile').value='';['previewCount','previewOpen','previewOrdered','previewOrderable'].forEach(id=>$(id).textContent='—');$('previewNote').style.display='none';$('importRun').disabled=true;$('importModal').classList.add('show')}
function closeImport(){$('importModal').classList.remove('show')}
async function previewFile(){const file=$('xmlFile').files?.[0];if(!file)return;try{const buffer=await file.arrayBuffer(),parsed=parseMoneyLiabilitiesXml(new TextDecoder('utf-8').decode(buffer));importState={file,parsed,sha:await sha256Hex(buffer)};$('previewCount').textContent=integer(parsed.summary.liabilities);$('previewOpen').textContent=money(parsed.summary.actual_remaining_amount);$('previewOrdered').textContent=money(parsed.summary.ordered_amount);$('previewOrderable').textContent=money(parsed.summary.orderable_remaining_amount);$('previewNote').style.display='block';$('previewNote').innerHTML=`<strong>${escapeHtml(file.name)}</strong><br>Export ${escapeHtml(parsed.exported_at||'—')} · SHA-256 ${escapeHtml(importState.sha.slice(0,12))}…`;$('importRun').disabled=false}catch(error){setStatus(`XML nelze načíst: ${error.message}`,'error')}}
async function runImport(){if(!importState.parsed)return;const button=$('importRun'),chunks=[];for(let i=0;i<importState.parsed.rows.length;i+=75)chunks.push(importState.parsed.rows.slice(i,i+75));button.disabled=true;try{for(let i=0;i<chunks.length;i++){button.textContent=`Načítám ${i+1}/${chunks.length}…`;if(preview)continue;const {error}=await supabase.rpc('finance_import_money_liabilities_v1',{p_rows:chunks[i],p_file_name:importState.file.name,p_file_sha256:importState.sha,p_exported_at:importState.parsed.exported_at,p_total_rows:importState.parsed.rows.length,p_is_final:i===chunks.length-1});if(error)throw error}closeImport();await load();setStatus(`Načteno ${integer(importState.parsed.rows.length)} závazků z Money S3.`,'success','Bez MD/D a bez duplicit')}catch(error){setStatus(`Import se nezdařil: ${error.message}`,'error')}finally{button.disabled=false;button.textContent='Načíst do evidence'}}

document.querySelectorAll('[data-tab]').forEach(btn=>btn.addEventListener('click',()=>{activeTab=btn.dataset.tab;showActiveTab();if(activeTab==='bank'){$('bankStateFilter').value='review_latest';renderBank()}}))
;['searchInput','statusFilter','categoryFilter'].forEach(id=>$(id).addEventListener(id==='searchInput'?'input':'change',renderLiabilities))
$('resetLiabilityFiltersBtn').addEventListener('click',()=>{$('searchInput').value='';$('statusFilter').value='';$('categoryFilter').value='';renderLiabilities();$('searchInput').focus()})
$('bankSearchInput').addEventListener('input',renderBank);$('bankStateFilter').addEventListener('change',renderBank)
$('resetBankFiltersBtn').addEventListener('click',()=>{$('bankSearchInput').value='';$('bankStateFilter').value='review_latest';renderBank();$('bankSearchInput').focus()})
$('bankBody').addEventListener('click',event=>{const matchButton=event.target.closest('[data-match-bank]'),unmatchButton=event.target.closest('[data-unmatch-id]');if(matchButton){const row=bank.find(item=>Number(item.id)===Number(matchButton.dataset.matchBank));if(row)openBankMatch(row)}else if(unmatchButton)rejectManualMatch(Number(unmatchButton.dataset.unmatchId))})
$('bankTargetKind').addEventListener('change',renderTargetOptions);$('bankTargetSearch').addEventListener('input',renderTargetOptions);$('bankTargetSelect').addEventListener('change',updateTargetHint)
$('bankMatchClose').addEventListener('click',closeBankMatch);$('bankMatchCancel').addEventListener('click',closeBankMatch);$('bankMatchSave').addEventListener('click',saveBankMatch);$('bankMatchModal').addEventListener('click',event=>{if(event.target===$('bankMatchModal'))closeBankMatch()})
$('importBtn').addEventListener('click',openImport);$('importClose').addEventListener('click',closeImport);$('importCancel').addEventListener('click',closeImport);$('xmlFile').addEventListener('change',previewFile);$('importRun').addEventListener('click',runImport);$('importModal').addEventListener('click',e=>{if(e.target===$('importModal'))closeImport()})
if(window.OlvendSidebar){window.OlvendSidebar.initMobileNav($('mobileNavShell'));window.OlvendSidebar.setActive('liabilities')}
load()
