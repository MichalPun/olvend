import { supabase } from './supabase.js'
import { mailApi } from './mail-api.js'

const $ = (id) => document.getElementById(id)
const preview = new URL(location.href).searchParams.get('preview') === '1'
const money = (value) => new Intl.NumberFormat('cs-CZ', { style:'currency', currency:'CZK', maximumFractionDigits:0 }).format(Number(value || 0))
const compactMoney = (value) => {
  const amount = Number(value || 0)
  if (Math.abs(amount) >= 1_000_000) return `${(amount / 1_000_000).toLocaleString('cs-CZ', { maximumFractionDigits:2 })} mil. Kč`
  if (Math.abs(amount) >= 1_000) return `${Math.round(amount / 1_000).toLocaleString('cs-CZ')} tis. Kč`
  return money(amount)
}
const integer = (value) => new Intl.NumberFormat('cs-CZ').format(Number(value || 0))
const percent = (value) => `${Number(value || 0).toLocaleString('cs-CZ', { minimumFractionDigits:1, maximumFractionDigits:1 })} %`
const escapeHtml = (value) => String(value ?? '').replace(/[&<>"']/g, (char) => ({ '&':'&amp;', '<':'&lt;', '>':'&gt;', '"':'&quot;', "'":'&#39;' }[char]))

const demo = {
  open_amount:684320, open_count:24, overdue_amount:48150, overdue_count:3, due_soon_amount:214870, due_soon_count:8,
  paid_amount:913460, paid_count:41, cost_net:1268840,
  company:{ revenue:2846000, gross_profit:1094000, gross_margin:38.4, opex:742000, operating_result:352000, plan_result:318000, cash:1624000 },
  performance:[
    ['Pro',2180,1902,278],['Led',2260,1986,274],['Úno',2315,2018,297],['Bře',2430,2086,344],['Dub',2375,2089,286],['Kvě',2510,2156,354],
    ['Čvn',2590,2222,368],['Čvc',2480,2184,296],['Srp',2610,2268,342],['Zář',2715,2351,364],['Říj',2625,2322,303],['Lis',2846,2494,352],
  ],
  cashflow:[['Dnes',1624],['28. 11.',1480],['5. 12.',1735],['12. 12.',1540],['19. 12.',1820],['26. 12.',1690],['2. 1.',1925],['9. 1.',1810]],
  bridge:[['Tržby',2846000,'total'],['Nákup zboží',-1752000,'negative'],['Hrubý zisk',1094000,'subtotal'],['Mzdy a lidé',-318000,'negative'],['Provoz a auta',-226000,'negative'],['Ostatní režie',-198000,'negative'],['Výsledek',352000,'result']],
  attention:[
    ['Po splatnosti','3 faktury · 48 150 Kč','Dvě faktury čekají na zařazení do dávky.','bad'],
    ['Náklady vozidel','+14 % proti plánu','Servis a PHM jsou o 31 800 Kč nad měsíčním plánem.','warn'],
    ['Hrubá marže','38,4 % · nad plánem','Kávové automaty drží vyšší marži než minulý měsíc.','good'],
    ['Cash-flow','Minimum 1,48 mil. Kč','V osmítýdenním výhledu zůstává rezerva bezpečná.','info'],
  ],
  pnl:[
    {label:'Tržby',kind:'group',plan:2700000,actual:2846000,ytd:27596000,ytdPlan:26400000},
    {label:'Potravinové automaty',kind:'detail',plan:1180000,actual:1245000,ytd:12118000,ytdPlan:11560000},
    {label:'Kávové automaty',kind:'detail',plan:960000,actual:1028000,ytd:9846000,ytdPlan:9410000},
    {label:'Prodej surovin a servis',kind:'detail',plan:360000,actual:348000,ytd:3412000,ytdPlan:3520000},
    {label:'Prodej a pronájem automatů',kind:'detail',plan:200000,actual:225000,ytd:2220000,ytdPlan:1910000},
    {label:'Přímé náklady',kind:'group',plan:-1665000,actual:-1752000,ytd:-16872000,ytdPlan:-16245000},
    {label:'Nákup prodaného zboží a surovin',kind:'detail',plan:-1540000,actual:-1624000,ytd:-15625000,ytdPlan:-15040000},
    {label:'Ostatní přímé náklady',kind:'detail',plan:-125000,actual:-128000,ytd:-1247000,ytdPlan:-1205000},
    {label:'Hrubý zisk',kind:'total',plan:1035000,actual:1094000,ytd:10724000,ytdPlan:10155000},
    {label:'Provozní náklady',kind:'group',plan:-717000,actual:-742000,ytd:-7148000,ytdPlan:-7024000},
    {label:'Mzdy a lidé',kind:'detail',plan:-310000,actual:-318000,ytd:-3056000,ytdPlan:-3020000},
    {label:'Vozidla, PHM a servis',kind:'detail',plan:-194000,actual:-226000,ytd:-2085000,ytdPlan:-1900000},
    {label:'Nájem, energie a provozovny',kind:'detail',plan:-126000,actual:-119000,ytd:-1189000,ytdPlan:-1236000},
    {label:'Software, administrativa a ostatní',kind:'detail',plan:-87000,actual:-79000,ytd:-818000,ytdPlan:-868000},
    {label:'Provozní výsledek',kind:'result',plan:318000,actual:352000,ytd:3576000,ytdPlan:3131000},
  ],
  workflow:[
    ['Převzato z pracovního e-mailu',6,'Přílohy z vyhrazené schránky čekají na automatickou a věcnou kontrolu','info'],
    ['Ke schválení',4,'Chybí středisko, kategorie nebo potvrzení odpovědné osoby','warn'],
    ['Připraveno k platbě',8,'Schválené doklady se správným bankovním účtem a splatností','good'],
    ['Čeká na spárování',2,'Platební příkaz odeslán, pohyb zatím není na výpisu','info'],
    ['Připraveno účetní',17,'Doklad, audit a informace o úhradě jsou kompletní','good'],
  ],
  integrations:[
    ['Pracovní e-mail','Webnode IMAP umí načítat zprávy i přílohy','good','Připojeno'],
    ['Dokumentový robot','Automatické zpracování PDF, ISDOC a fotografií','warn','Připravit'],
    ['Raiffeisenbank','Premium API / import XML výpisu','warn','Nastavit'],
    ['Money S3','Stínový import účetnictví · poslední 15. 11.','good','Čtení'],
  ],
  costs:[['Zboží a materiál',512400],['PHM a vozidla',224700],['Nájem a energie',196500],['Servis a technika',148240],['Software a služby',117000],['Ostatní',70000]],
  aging:[['Po splatnosti',48150,'bad'],['Dnes–7 dnů',214870,'amber'],['8–14 dnů',176300,'blue'],['15–30 dnů',168000,'violet'],['Později',77000,'green']],
}

let detailsCollapsed = false
let resultRows = []

function initializePeriods(){
  const formatter=new Intl.DateTimeFormat('cs-CZ',{month:'long',year:'numeric'})
  const current=new Date();current.setDate(1)
  $('periodSelect').innerHTML=Array.from({length:18},(_,index)=>{const month=new Date(current);month.setMonth(current.getMonth()-index);const value=`${month.getFullYear()}-${String(month.getMonth()+1).padStart(2,'0')}`;const label=formatter.format(month);return `<option value="${value}">${label.charAt(0).toUpperCase()+label.slice(1)}</option>`}).join('')
}

function setStatus(text,type='',meta='Provozní evidence OLVEND'){
  $('statusText').textContent=text
  $('statusMeta').textContent=meta
  $('statusStrip').className=`status-strip ${type}`.trim()
}

function renderPerformanceChart(rows){
  const width=900,height=280,left=54,right=22,top=22,bottom=42,plotW=width-left-right,plotH=height-top-bottom
  const max=Math.max(...rows.map((row)=>Math.max(row[1],row[2])),1)*1.12
  const step=plotW/rows.length,barW=Math.min(19,step*.28),y=(value)=>top+plotH-(value/max)*plotH
  const grid=[0,.25,.5,.75,1].map((ratio)=>{const value=max*ratio,py=y(value);return `<line x1="${left}" y1="${py}" x2="${width-right}" y2="${py}" class="chart-grid"/><text x="${left-9}" y="${py+4}" text-anchor="end" class="chart-axis">${Math.round(value/100)/10} mil.</text>`}).join('')
  const bars=rows.map((row,index)=>{const x=left+index*step+step/2;return `<rect x="${x-barW-2}" y="${y(row[1])}" width="${barW}" height="${top+plotH-y(row[1])}" rx="3" class="chart-bar revenue"><title>${escapeHtml(row[0])}: tržby ${compactMoney(row[1]*1000)}</title></rect><rect x="${x+2}" y="${y(row[2])}" width="${barW}" height="${top+plotH-y(row[2])}" rx="3" class="chart-bar costs"><title>${escapeHtml(row[0])}: náklady ${compactMoney(row[2]*1000)}</title></rect><text x="${x}" y="${height-18}" text-anchor="middle" class="chart-axis">${escapeHtml(row[0])}</text>`}).join('')
  const resultMax=Math.max(...rows.map((row)=>row[3]),1)*1.25,resultY=(value)=>top+plotH-(value/resultMax)*plotH
  const points=rows.map((row,index)=>`${left+index*step+step/2},${resultY(row[3])}`).join(' ')
  const dots=rows.map((row,index)=>`<circle cx="${left+index*step+step/2}" cy="${resultY(row[3])}" r="3.5" class="chart-dot"><title>${escapeHtml(row[0])}: výsledek ${compactMoney(row[3]*1000)}</title></circle>`).join('')
  $('performanceChart').innerHTML=`<svg viewBox="0 0 ${width} ${height}" role="img" aria-label="Tržby, náklady a provozní výsledek za posledních dvanáct měsíců">${grid}${bars}<polyline points="${points}" class="chart-line"/>${dots}</svg>`
}

function renderCashflow(rows){
  const width=720,height=220,left=48,right=20,top=20,bottom=42,plotW=width-left-right,plotH=height-top-bottom
  const values=rows.map((row)=>row[1]),min=Math.min(...values)*.9,max=Math.max(...values)*1.08
  const x=(index)=>left+(index/(rows.length-1))*plotW,y=(value)=>top+plotH-((value-min)/(max-min))*plotH
  const points=rows.map((row,index)=>`${x(index)},${y(row[1])}`).join(' '),area=`${left},${top+plotH} ${points} ${width-right},${top+plotH}`
  const grid=[0,.5,1].map((ratio)=>{const value=min+(max-min)*ratio,py=y(value);return `<line x1="${left}" y1="${py}" x2="${width-right}" y2="${py}" class="chart-grid"/><text x="${left-8}" y="${py+4}" text-anchor="end" class="chart-axis">${(value/1000).toLocaleString('cs-CZ',{maximumFractionDigits:1})}m</text>`}).join('')
  const labels=rows.map((row,index)=>`<text x="${x(index)}" y="${height-16}" text-anchor="middle" class="chart-axis">${escapeHtml(row[0])}</text><circle cx="${x(index)}" cy="${y(row[1])}" r="4" class="cash-dot"><title>${escapeHtml(row[0])}: ${compactMoney(row[1]*1000)}</title></circle>`).join('')
  $('cashflowChart').innerHTML=`<svg viewBox="0 0 ${width} ${height}" role="img" aria-label="Výhled zůstatku hotovosti na osm týdnů">${grid}<polygon points="${area}" class="cash-area"/><polyline points="${points}" class="cash-line"/>${labels}</svg>`
}

function renderBridge(rows){
  const max=Math.max(...rows.map((row)=>Math.abs(row[1])),1)
  $('resultBridge').innerHTML=rows.map((row)=>{const value=Number(row[1]),width=Math.max(8,Math.abs(value)/max*100);return `<div class="waterfall-row ${row[2]}"><div><span>${escapeHtml(row[0])}</span><strong class="${value<0?'negative':''}">${value<0?'− ':''}${money(Math.abs(value))}</strong></div><div class="waterfall-track"><span style="width:${width}%"></span></div></div>`}).join('')
}

function renderResultTable(rows){
  let index=0
  $('resultTableBody').innerHTML=rows.filter((row)=>!detailsCollapsed||row.kind!=='detail').map((row)=>{
    index+=1
    const variance=row.actual-row.plan,ytdVariance=row.ytd-row.ytdPlan,favorable=row.actual>=row.plan,completion=row.plan?row.actual/row.plan*100:0
    return `<tr class="${row.kind}" data-label="${escapeHtml(row.label)}"><td class="row-index">${index}</td><td class="sticky-label"><span class="sheet-row-label">${row.kind==='detail'?'<i></i>':''}${escapeHtml(row.label)}</span></td><td class="money">${money(row.plan)}</td><td class="money">${money(row.actual)}</td><td class="money variance ${favorable?'positive':'negative'}">${variance>0?'+':''}${money(variance)}</td><td class="money"><span class="completion ${Math.abs(completion)>=100?'good':''}">${percent(Math.abs(completion))}</span></td><td class="money">${money(row.ytd)}</td><td class="money">${money(row.ytdPlan)}</td><td class="money variance ${ytdVariance>=0?'positive':'negative'}">${ytdVariance>0?'+':''}${money(ytdVariance)}</td></tr>`
  }).join('')
}

function renderAttention(rows){
  $('attentionList').innerHTML=rows.map((row)=>`<div class="attention-row ${row[3]}"><span class="attention-marker"></span><div><strong>${escapeHtml(row[0])}</strong><small>${escapeHtml(row[2])}</small></div><b>${escapeHtml(row[1])}</b></div>`).join('')
}

function render(data){
  const company=data.company
  resultRows=data.pnl
  $('trendRevenue').textContent='+8,4 %';$('trendRevenue').className='trend good'
  $('trendGross').textContent='+3,1 %';$('trendGross').className='trend good'
  $('trendOpex').textContent='+4,7 %';$('trendOpex').className='trend warn'
  $('resultTrend').textContent='Nad plánem';$('resultTrend').className='trend good'
  $('trendCash').textContent='+12,6 %';$('trendCash').className='trend info'
  $('sheetFileName').textContent='OLVEND_Finance_2026.xlsx';$('sheetStatus').innerHTML='<span class="status-dot"></span>Ukázková data'
  $('metricRevenue').textContent=money(company.revenue)
  $('metricGrossProfit').textContent=money(company.gross_profit)
  $('metricMarginNote').textContent=`Hrubá marže ${percent(company.gross_margin)}`
  $('metricOpex').textContent=money(company.opex)
  $('metricOperatingResult').textContent=money(company.operating_result)
  $('metricResultNote').textContent=`Plán ${money(company.plan_result)} · +${money(company.operating_result-company.plan_result)}`
  $('metricCash').textContent=money(company.cash)
  $('resultVsPlan').textContent=`+${money(company.operating_result-company.plan_result)} proti plánu`
  $('metricOpen').textContent=money(data.open_amount);$('metricOpenNote').textContent=`${integer(data.open_count)} neuhrazených faktur`
  $('metricOverdue').textContent=money(data.overdue_amount);$('metricOverdueNote').textContent=`${integer(data.overdue_count)} faktury po splatnosti`
  $('metricDueSoon').textContent=money(data.due_soon_amount);$('metricDueSoonNote').textContent=`${integer(data.due_soon_count)} faktur do 7 dnů`
  $('metricPaid').textContent=money(data.paid_amount);$('metricPaidNote').textContent=`${integer(data.paid_count)} spárovaných úhrad`
  $('metricCosts').textContent=money(data.cost_net)
  renderPerformanceChart(data.performance);renderCashflow(data.cashflow);renderBridge(data.bridge);renderAttention(data.attention);renderResultTable(data.pnl)
  $('workflowList').innerHTML=data.workflow.map((row,index)=>`<div class="workflow-row ${row[3]}"><div class="workflow-icon">${index+1}</div><div><strong>${escapeHtml(row[0])}</strong><small>${escapeHtml(row[2])}</small></div><span class="badge ${row[3]}">${integer(row[1])}</span></div>`).join('')
  $('integrationList').innerHTML=data.integrations.map((row)=>`<div class="integration"><div><strong>${escapeHtml(row[0])}</strong><span>${escapeHtml(row[1])}</span></div><span class="badge ${row[2]}">${escapeHtml(row[3])}</span></div>`).join('')
  const maxCost=Math.max(...data.costs.map((row)=>row[1]),1)
  $('costChart').innerHTML=data.costs.map((row)=>`<div class="chart-row"><div class="chart-label"><span>${escapeHtml(row[0])}</span><strong>${money(row[1])}</strong></div><div class="bar"><span style="width:${row[1]/maxCost*100}%"></span></div></div>`).join('')
  const maxAging=Math.max(...data.aging.map((row)=>row[1]),1)
  $('agingTotal').textContent=money(data.aging.reduce((sum,row)=>sum+row[1],0))
  $('agingChart').innerHTML=data.aging.map((row)=>`<div class="chart-row"><div class="chart-label"><span>${escapeHtml(row[0])}</span><strong>${money(row[1])}</strong></div><div class="bar ${row[2]}"><span style="width:${row[1]/maxAging*100}%"></span></div></div>`).join('')
}

function emptyBlock(id,text){
  $(id).innerHTML=`<div class="empty">${escapeHtml(text)}</div>`
}

function renderLive(data){
  resultRows=[]
  ;['trendRevenue','trendGross','trendOpex','resultTrend','trendCash'].forEach((id)=>{$(id).textContent='Čeká na data';$(id).className='trend info'})
  $('sheetFileName').textContent='Čeká na import účetních dat';$('sheetStatus').innerHTML='<span class="status-dot"></span>Bez importovaných dat'
  $('metricRevenue').textContent='—';$('metricRevenueNote').textContent='Zdroj tržeb čeká na propojení'
  $('metricGrossProfit').textContent='—';$('metricMarginNote').textContent='Marže se zobrazí po propojení výnosů a nákladů'
  $('metricOpex').textContent='—';$('metricOperatingResult').textContent='—';$('metricResultNote').textContent='Výsledovka čeká na import z účetnictví'
  $('metricCash').textContent='—';$('resultVsPlan').textContent='Čeká na data'
  $('metricOpen').textContent=money(data.open_amount);$('metricOpenNote').textContent=`${integer(data.open_count)} neuhrazených faktur`
  $('metricOverdue').textContent=money(data.overdue_amount);$('metricOverdueNote').textContent=`${integer(data.overdue_count)} faktury po splatnosti`
  $('metricDueSoon').textContent=money(data.due_soon_amount);$('metricDueSoonNote').textContent=`${integer(data.due_soon_count)} faktur do 7 dnů`
  $('metricPaid').textContent=money(data.paid_amount);$('metricPaidNote').textContent=`${integer(data.paid_count)} spárovaných úhrad`
  $('metricCosts').textContent=money(data.cost_net)
  emptyBlock('performanceChart','Vývoj firmy se zobrazí po pravidelném importu výsledovky z účetnictví.')
  emptyBlock('resultBridge','Rozklad výsledku zatím nemá připojený účetní zdroj.')
  emptyBlock('cashflowChart','Výhled se doplní po připojení banky a splatností pohledávek.')
  emptyBlock('attentionList','Aktuálně nejsou dostupná propojená manažerská upozornění.')
  $('resultTableBody').innerHTML='<tr><td colspan="9"><div class="empty">Výsledovka zatím nemá importovaná účetní data.</div></td></tr>'
  emptyBlock('costChart','Rozpad nákladů vznikne z prvních zařazených přijatých faktur.')
  const open=Number(data.open_amount||0),overdue=Number(data.overdue_amount||0),soon=Number(data.due_soon_amount||0)
  const aging=[['Po splatnosti',overdue,'bad'],['Dnes–7 dnů',soon,'amber'],['Později',Math.max(0,open-overdue-soon),'blue']]
  const maxAging=Math.max(...aging.map((row)=>row[1]),1)
  $('agingTotal').textContent=money(open)
  $('agingChart').innerHTML=aging.map((row)=>`<div class="chart-row"><div class="chart-label"><span>${escapeHtml(row[0])}</span><strong>${money(row[1])}</strong></div><div class="bar ${row[2]}"><span style="width:${row[1]/maxAging*100}%"></span></div></div>`).join('')
  const workflow=[
    ['Nové dokumenty',data.new_count||0,'Přijaté dokumenty čekající na první kontrolu','info'],
    ['Ke schválení',data.approval_count||0,'Doklady čekající na věcné potvrzení','warn'],
    ['Připraveno k platbě',data.ready_count||0,'Schválené doklady před vytvořením dávky','good'],
    ['Čeká na spárování',data.ordered_count||0,'Platební příkaz bez potvrzené bankovní transakce','info'],
    ['Připraveno účetní',data.handoff_count||0,'Doklady připravené k předání','good'],
  ]
  $('workflowList').innerHTML=workflow.map((row,index)=>`<div class="workflow-row ${row[3]}"><div class="workflow-icon">${index+1}</div><div><strong>${escapeHtml(row[0])}</strong><small>${escapeHtml(row[2])}</small></div><span class="badge ${row[3]}">${integer(row[1])}</span></div>`).join('')
  const mailbox=data.mailbox||null
  const mailboxDetail=mailbox?.account
    ? `fakturace@olmika.cz · poslední synchronizace ${mailbox.account.last_sync_at?new Date(mailbox.account.last_sync_at).toLocaleString('cs-CZ'):'zatím neproběhla'} · ${Number(mailbox.stats?.statuses?.queued||0)} ve frontě`
    : 'Schránka fakturace@olmika.cz čeká na bezpečné připojení'
  const integrations=[
    ['Pracovní e-mail',mailboxDetail,mailbox?.account&&!mailbox.account.last_error?'good':'warn',mailbox?.account&&!mailbox.account.last_error?'Připojeno':'Nenapojeno'],
    ['Vytěžení dokumentů','PDF a ISDOC zatím čekají na zpracovatelský backend','warn','Nenapojeno'],
    ['Raiffeisenbank','Účet a bankovní synchronizace nejsou nastavené','warn','Nenapojeno'],
    ['Money S3','Výsledovka čeká na pravidelný datový import','warn','Nenapojeno'],
  ]
  $('integrationList').innerHTML=integrations.map((row)=>`<div class="integration"><div><strong>${escapeHtml(row[0])}</strong><span>${escapeHtml(row[1])}</span></div><span class="badge ${row[2]}">${escapeHtml(row[3])}</span></div>`).join('')
}

function missingSchema(error){return /finance_received|schema cache|does not exist|could not find/i.test(String(error?.message||error||''))}

async function load(){
  if(preview){render(demo);setStatus('Modernizovaný finanční cockpit je připravený k prohlédnutí.','success','Ukázková data · propojený model výsledku firmy');return}
  setStatus('Načítám finanční přehled…')
  try{
    const period=$('periodSelect').value
    const [{data,error},mailbox]=await Promise.all([
      supabase.rpc('get_finance_dashboard_v1',{p_month:`${period}-01`}),
      mailApi('/finance/account').catch(()=>({account:null,stats:{statuses:{}}}))
    ])
    if(error)throw error
    renderLive({ ...(data || {}), mailbox })
    setStatus('Finanční přehled je aktuální.','success','Závazky živě · výsledovka čeká na datové propojení')
  }catch(error){
    console.error(error);renderLive({})
    setStatus(missingSchema(error)?'Databázové závazkové jádro zatím není nasazené.':`Přehled se nepodařilo načíst: ${error.message}`,'error','Ukázková čísla se v ostrém provozu nezobrazují')
  }
}

$('refreshBtn').addEventListener('click',load)
$('periodSelect').addEventListener('change',load)
$('collapseRowsBtn').addEventListener('click',()=>{detailsCollapsed=!detailsCollapsed;$('collapseRowsBtn').textContent=detailsCollapsed?'Rozbalit skupiny':'Sbalit skupiny';if(resultRows.length)renderResultTable(resultRows)})
$('exportResultBtn').addEventListener('click',()=>setStatus('Export výsledovky bude navázaný na stejná živá data jako tento přehled.','success','Náhled · soubor se zatím nevytváří'))
document.querySelectorAll('.sheet-tabs button').forEach((button)=>button.addEventListener('click',()=>{document.querySelectorAll('.sheet-tabs button').forEach((item)=>item.classList.toggle('active',item===button));$('formulaOutput').textContent=button.textContent==='Výsledovka'?'= Tržby − přímé náklady − provozní náklady':`${button.textContent} · připravovaný list`}))
initializePeriods()
if(window.OlvendSidebar){window.OlvendSidebar.initMobileNav($('mobileNavShell'));window.OlvendSidebar.setActive('finance-overview')}
if(preview)document.querySelectorAll('a[href="received-invoices.html"]').forEach((link)=>{link.href='received-invoices.html?preview=1'})
load()
