import { supabase } from './supabase.js'

const $ = (id) => document.getElementById(id)
const preview = new URL(location.href).searchParams.get('preview') === '1'
const money = (value) => new Intl.NumberFormat('cs-CZ',{style:'currency',currency:'CZK',maximumFractionDigits:2}).format(Number(value || 0))
const date = (value) => value ? new Intl.DateTimeFormat('cs-CZ').format(new Date(`${value}T12:00:00`)) : '—'
const escapeHtml = (value) => String(value ?? '').replace(/[&<>"']/g,(char)=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[char]))

const demoDocuments = [
  {id:1,number:'PF26-00479',supplier:'Microsoft Ireland Operations Ltd.',file:'E0400P9N8K.pdf',taxable:'2026-11-16',category:'Software · licence Microsoft 365',center:'Správa',net:12980,vat:0,total:12980,payment:'Uhrazeno'},
  {id:2,number:'PF26-00476',supplier:'T-Mobile Czech Republic a.s.',file:'9211008844.pdf',taxable:'2026-11-14',category:'Telekomunikace · mobilní služby',center:'Správa',net:18460,vat:3876.60,total:22336.60,payment:'Uhrazeno'},
  {id:3,number:'PF26-00472',supplier:'ALZA.cz a.s.',file:'FV-12688421.pdf',taxable:'2026-11-10',category:'Technika · náhradní díly',center:'Technický úsek',net:24680,vat:5182.80,total:29862.80,payment:'Uhrazeno'},
  {id:4,number:'PF26-00469',supplier:'UNIQA pojišťovna, a.s.',file:'P-2026-4811.pdf',taxable:'2026-11-08',category:'Pojištění vozidel',center:'Vozový park',net:38200,vat:0,total:38200,payment:'Příkaz vytvořen'},
]

let documents = [], packageData = null, selected = new Set()

function setStatus(text,type='',meta='Přístup pouze k účetním podkladům'){
  $('statusText').textContent=text;$('statusMeta').textContent=meta;$('statusStrip').className=`status-strip ${type}`.trim()
}

function render(){
  const net=documents.reduce((sum,row)=>sum+row.net,0),vat=documents.reduce((sum,row)=>sum+row.vat,0)
  $('metricReady').textContent=packageData?.document_count??documents.length
  $('metricNet').textContent=money(packageData?.net_total??net)
  $('metricVat').textContent=money(packageData?.vat_total??vat)
  $('metricAccepted').textContent=packageData?.status==='accepted'?(packageData.document_count||documents.length):0
  $('metricReturned').textContent=documents.filter((row)=>row.status==='returned').length
  $('documentBody').innerHTML=documents.length?documents.map((row)=>`<tr class="${selected.has(row.id)?'selected':''}"><td><input class="check row-check" data-id="${row.id}" type="checkbox" ${selected.has(row.id)?'checked':''}></td><td><span class="cell-main">${escapeHtml(row.number)}</span></td><td><span class="cell-main">${escapeHtml(row.supplier)}</span><span class="cell-sub">${escapeHtml(row.file)}</span></td><td>${date(row.taxable)}</td><td>${escapeHtml(row.category)}</td><td>${escapeHtml(row.center)}</td><td class="money">${money(row.net)}</td><td class="money">${money(row.vat)}</td><td class="money">${money(row.total)}</td><td><span class="badge ${row.payment==='Uhrazeno'?'good':'violet'}">${escapeHtml(row.payment)}</span></td></tr>`).join(''):'<tr><td colspan="10"><div class="empty">Žádný balíček zatím není připravený.</div></td></tr>'
  document.querySelectorAll('.row-check').forEach((element)=>element.addEventListener('change',()=>{element.checked?selected.add(Number(element.dataset.id)):selected.delete(Number(element.dataset.id));render()}))
  $('selectAll').checked=documents.length>0&&selected.size===documents.length
}

async function downloadBatch(){
  if(preview){setStatus('Náhled balíčku UCT-2026-11-01 je připraven; v ostrém provozu se stáhne podepsaný ZIP.','success','Náhled · bez vytvoření souboru');return}
  if(!packageData?.storage_path)throw new Error('Pro tento balíček zatím není připravený soubor ke stažení.')
  const {data,error}=await supabase.storage.from('finance-private').createSignedUrl(packageData.storage_path,300);if(error)throw error
  if(data?.signedUrl)location.href=data.signedUrl
}

function openReturn(){if(!preview)return;if(!selected.size){setStatus('Nejdřív vyberte doklady, které chcete vrátit.','error');return}$('returnModal').classList.add('show')}
function closeReturn(){$('returnModal').classList.remove('show')}

$('selectAll').addEventListener('change',()=>{selected=$('selectAll').checked?new Set(documents.map((row)=>row.id)):new Set();render()})
$('downloadReadyBtn').addEventListener('click',()=>downloadBatch().catch((error)=>setStatus(error.message,'error')))
$('acceptBatchBtn').addEventListener('click',()=>{if(preview)setStatus('Převzetí balíčku bylo potvrzeno v náhledu.','success','Náhled · bez zápisu')})
$('returnSelectedBtn').addEventListener('click',openReturn);$('returnClose').addEventListener('click',closeReturn);$('returnCancel').addEventListener('click',closeReturn)
$('returnConfirm').addEventListener('click',()=>{const reason=$('returnReason').value.trim();if(!reason){setStatus('Doplňte důvod vrácení.','error');return}closeReturn();setStatus(`${selected.size} doklady byly v náhledu vráceny k doplnění.`,'success',reason);selected.clear();render()})

async function initialize(){
  if(preview)document.querySelectorAll('a[href="received-invoices.html"]').forEach((link)=>{link.href='received-invoices.html?preview=1'})
  if(!preview)document.querySelectorAll('[data-preview-only]').forEach((element)=>element.remove())
  if(window.OlvendSidebar){window.OlvendSidebar.initMobileNav($('mobileNavShell'));window.OlvendSidebar.setActive('accountant-portal')}
  if(preview){documents=[...demoDocuments];packageData={document_count:17,net_total:1047340,vat_total:193884.60,status:'ready'};render();setStatus('Vývojový náhled portálu účetní je připravený.','success','Ukázková data · omezený přístup');return}

  const {data:scope,error}=await supabase.rpc('finance_portal_scope_v1');if(error)throw error
  if(scope==='accountant'){
    document.querySelector('.sidebar')?.remove();document.querySelector('.layout').style.gridTemplateColumns='minmax(0,1fr)';$('mobileNavShell').remove()
  }
  const {data:latest,error:packageError}=await supabase.from('finance_accounting_packages').select('*').neq('status','draft').order('period_end',{ascending:false}).limit(1).maybeSingle();if(packageError)throw packageError
  if(latest){
    const {data:payload,error:payloadError}=await supabase.rpc('finance_get_accounting_package_v1',{p_package_id:latest.id});if(payloadError)throw payloadError
    packageData=payload?.package||latest
    documents=(payload?.documents||[]).map((row)=>({id:row.id,number:row.internal_number,supplier:row.supplier_name,file:row.attachment?.file_name||'—',taxable:row.taxable_date,category:row.accountant_note||'Manažerská evidence',center:row.cost_center||'—',net:Number(row.net_amount||0),vat:Number(row.vat_amount||0),total:Number(row.total_amount||0),payment:row.payment_status==='paid'?'Uhrazeno':'Neuhrazeno',status:row.status}))
  }
  render();$('downloadReadyBtn').disabled=!packageData?.storage_path;$('acceptBatchBtn').disabled=true;$('returnSelectedBtn').disabled=true
  setStatus(latest?'Účetní balíček je aktuální.':'Žádný balíček zatím není připravený.','success','Přístup pouze k účetním podkladům')
}

initialize().catch((error)=>{documents=[];packageData=null;render();setStatus(`Portál se nepodařilo načíst: ${error.message}`,'error')})
