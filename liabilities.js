import {supabase} from './supabase.js'
import {parseMoneyLiabilitiesXml,sha256Hex} from './money-liabilities-core.mjs?v=20261121finance-liabilities-v1'

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
let liabilities=[],orders=[],bank=[],activeTab='liabilities',importState={file:null,parsed:null,sha:null}

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
  const rows=liabilities.filter(r=>(!q||`${r.internal_number} ${r.description}`.toLowerCase().includes(q))&&(!status||r.payment_status===status)&&(!category||r.category===category))
  $('liabilityBody').innerHTML=rows.length?rows.map(r=>`<tr><td><span class="cell-main">${escapeHtml(r.internal_number)}</span><span class="cell-sub">Money S3</span></td><td><span class="cell-main">${escapeHtml(r.description)}</span></td><td>${date(r.due_date)}</td><td>${escapeHtml(r.category)}</td><td class="money">${money(r.total_amount,r.currency)}</td><td class="money">${money(r.actual_remaining_amount,r.currency)}</td><td class="money">${money(r.ordered_amount,r.currency)}</td><td class="money">${money(r.orderable_remaining_amount,r.currency)}</td><td>${badge(paymentMap,r.payment_status)}</td><td>${badge(accountingMap,r.accounting_status)}</td></tr>`).join(''):'<tr><td colspan="10"><div class="empty">Pro zvolené filtry tu nejsou žádné závazky.</div></td></tr>'
}
function renderOrders(){$('orderBody').innerHTML=orders.length?orders.map(r=>`<tr><td><span class="cell-main">${escapeHtml(r.batch_number)}</span><span class="cell-sub">${escapeHtml(r.bank_provider)}</span></td><td>${date(r.requested_execution_date)}</td><td>${integer(r.payment_count)}</td><td class="money">${money(r.total_amount,r.currency)}</td><td>${badge(orderMap,r.status)}</td></tr>`).join(''):'<tr><td colspan="5"><div class="empty">Zatím nejsou evidované žádné platební příkazy.</div></td></tr>'}
function renderBank(){
  $('bankRange').textContent=bank.length?`${date(bank[bank.length-1].booked_on)}–${date(bank[0].booked_on)}`:'—'
  $('bankBody').innerHTML=bank.length?bank.map(r=>`<tr><td>${date(r.booked_on)}</td><td><span class="cell-main">${escapeHtml(r.counterparty_name||'—')}</span><span class="cell-sub">${escapeHtml(r.counterparty_account||'')}</span></td><td>${escapeHtml(r.variable_symbol||'—')}</td><td>${escapeHtml(r.message||'—')}</td><td class="money" style="color:${Number(r.amount)<0?'#b42318':'#067647'}">${money(r.amount,r.currency)}</td></tr>`).join(''):'<tr><td colspan="5"><div class="empty">Zatím nejsou importované bankovní pohyby.</div></td></tr>'
}
function renderAll(){renderMetrics();renderLiabilities();renderOrders();renderBank()}
async function load(){
  if(preview){liabilities=[{internal_number:'ZA26250',description:'Vyúčtování mzdy – říjen 2026',category:'Mzdy a lidé',due_date:'2026-11-20',currency:'CZK',total_amount:29463,actual_remaining_amount:29463,ordered_amount:29463,orderable_remaining_amount:0,bank_confirmed_amount:0,payment_status:'ordered',accounting_status:'not_prepared'}];orders=[{batch_number:'MONEY-2026-11-21-01',bank_provider:'raiffeisenbank',requested_execution_date:'2026-11-21',payment_count:1,total_amount:29463,currency:'CZK',status:'awaiting_bank_confirmation'}];bank=[];renderAll();setStatus('Vývojový náhled je připravený.','success','Ukázková data');return}
  try{
    const [{data:l,error:le},{data:o,error:oe},{data:b,error:be}]=await Promise.all([
      supabase.from('finance_liability_overview_v1').select('*').order('due_date',{ascending:false}),
      supabase.from('finance_payment_batches').select('*').order('requested_execution_date',{ascending:false}),
      supabase.from('finance_bank_transactions').select('*').order('booked_on',{ascending:false}).limit(200)
    ])
    if(le)throw le;if(oe)throw oe;if(be)throw be
    liabilities=l||[];orders=o||[];bank=b||[]
    const categories=[...new Set(liabilities.map(r=>r.category).filter(Boolean))].sort((a,b)=>a.localeCompare(b,'cs'))
    $('categoryFilter').innerHTML='<option value="">Všechny kategorie</option>'+categories.map(x=>`<option>${escapeHtml(x)}</option>`).join('')
    renderAll();setStatus('Závazky a bankovní pohyby jsou aktuální.','success',`${integer(liabilities.length)} závazků · ${integer(bank.length)} posledních pohybů`)
  }catch(error){console.error(error);setStatus(`Data se nepodařilo načíst: ${error.message}`,'error')}
}
function openImport(){importState={file:null,parsed:null,sha:null};$('xmlFile').value='';['previewCount','previewOpen','previewOrdered','previewOrderable'].forEach(id=>$(id).textContent='—');$('previewNote').style.display='none';$('importRun').disabled=true;$('importModal').classList.add('show')}
function closeImport(){$('importModal').classList.remove('show')}
async function previewFile(){const file=$('xmlFile').files?.[0];if(!file)return;try{const buffer=await file.arrayBuffer(),parsed=parseMoneyLiabilitiesXml(new TextDecoder('utf-8').decode(buffer));importState={file,parsed,sha:await sha256Hex(buffer)};$('previewCount').textContent=integer(parsed.summary.liabilities);$('previewOpen').textContent=money(parsed.summary.actual_remaining_amount);$('previewOrdered').textContent=money(parsed.summary.ordered_amount);$('previewOrderable').textContent=money(parsed.summary.orderable_remaining_amount);$('previewNote').style.display='block';$('previewNote').innerHTML=`<strong>${escapeHtml(file.name)}</strong><br>Export ${escapeHtml(parsed.exported_at||'—')} · SHA-256 ${escapeHtml(importState.sha.slice(0,12))}…`;$('importRun').disabled=false}catch(error){setStatus(`XML nelze načíst: ${error.message}`,'error')}}
async function runImport(){if(!importState.parsed)return;const button=$('importRun'),chunks=[];for(let i=0;i<importState.parsed.rows.length;i+=75)chunks.push(importState.parsed.rows.slice(i,i+75));button.disabled=true;try{for(let i=0;i<chunks.length;i++){button.textContent=`Načítám ${i+1}/${chunks.length}…`;if(preview)continue;const {error}=await supabase.rpc('finance_import_money_liabilities_v1',{p_rows:chunks[i],p_file_name:importState.file.name,p_file_sha256:importState.sha,p_exported_at:importState.parsed.exported_at,p_total_rows:importState.parsed.rows.length,p_is_final:i===chunks.length-1});if(error)throw error}closeImport();await load();setStatus(`Načteno ${integer(importState.parsed.rows.length)} závazků z Money S3.`,'success','Bez MD/D a bez duplicit')}catch(error){setStatus(`Import se nezdařil: ${error.message}`,'error')}finally{button.disabled=false;button.textContent='Načíst do evidence'}}

document.querySelectorAll('[data-tab]').forEach(btn=>btn.addEventListener('click',()=>{activeTab=btn.dataset.tab;document.querySelectorAll('[data-tab]').forEach(x=>x.classList.toggle('active',x===btn));$('liabilityPanel').style.display=activeTab==='liabilities'?'block':'none';$('orderPanel').style.display=activeTab==='orders'?'block':'none';$('bankPanel').style.display=activeTab==='bank'?'block':'none'}))
;['searchInput','statusFilter','categoryFilter'].forEach(id=>$(id).addEventListener(id==='searchInput'?'input':'change',renderLiabilities))
$('importBtn').addEventListener('click',openImport);$('importClose').addEventListener('click',closeImport);$('importCancel').addEventListener('click',closeImport);$('xmlFile').addEventListener('change',previewFile);$('importRun').addEventListener('click',runImport);$('importModal').addEventListener('click',e=>{if(e.target===$('importModal'))closeImport()})
if(window.OlvendSidebar){window.OlvendSidebar.initMobileNav($('mobileNavShell'));window.OlvendSidebar.setActive('liabilities')}
load()
