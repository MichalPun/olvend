import { financeMailboxStatus, mailApi } from './mail-api.js?v=20261121finance-mail-status-v3'

const $ = id => document.getElementById(id)
const preview = new URL(location.href).searchParams.get('preview') === '1'
const form = $('mailboxForm')
let account = null

function setStatus(text,type='',meta='Heslo není dostupné ve webové aplikaci'){
  $('statusText').textContent=text;$('statusMeta').textContent=meta;$('statusStrip').className=`status-strip ${type}`.trim()
}
function dateTime(value){if(!value)return '—';const date=new Date(value);return Number.isNaN(date.getTime())?'—':date.toLocaleString('cs-CZ',{dateStyle:'short',timeStyle:'short'})}
function payload(){const data=new FormData(form);return{email_address:'fakturace@olmika.cz',display_name:String(data.get('display_name')||''),username:String(data.get('username')||''),password:String(data.get('password')||''),imap_host:String(data.get('imap_host')||''),imap_port:Number(data.get('imap_port')||993),imap_secure:data.get('imap_secure')==='on',sync_history_days:Number(data.get('sync_history_days')||90)}}
function render(result={}){
  account=result.account||account
  const statuses=result.stats?.statuses||{}
  $('metricConnection').textContent=account?'Připojeno':'Nenapojeno'
  $('metricConnectionNote').textContent=account?.email_address||'fakturace@olmika.cz'
  $('metricLastSync').textContent=dateTime(account?.last_sync_at)
  $('metricQueued').textContent=Number(statuses.queued||0)+Number(statuses.extracting||0)+Number(statuses.needs_review||0)
  $('metricProcessed').textContent=Number(statuses.invoice_created||0)
  $('metricFailed').textContent=Number(statuses.failed||0)
  $('metricErrorNote').textContent=account?.last_error||'Bez chyb'
  if(account){
    for(const key of ['display_name','username','imap_host','imap_port','sync_history_days'])if(form.elements[key])form.elements[key].value=account[key]??form.elements[key].value
    form.elements.imap_secure.checked=account.imap_secure!==false
  }
}
async function load(){
  if(preview){render({account:{email_address:'fakturace@olmika.cz',last_sync_at:new Date().toISOString(),imap_host:'imap.mail.webnode.com',imap_port:993,imap_secure:true,sync_history_days:90},stats:{statuses:{queued:4,invoice_created:12}}});setStatus('Vývojový náhled napojení je připravený.','success','Ukázkový stav · bez uložení hesla');return}
  try{const result=await financeMailboxStatus();render(result);setStatus(result.account?'Fakturační schránka je připojená.':'Schránka zatím není připojená.',result.account?'success':'',result.verified_by==='database'?'Stav ověřen přímo z databáze · automatická kontrola běží':'Automatická kontrola každých 5 minut')}
  catch(error){setStatus(`Stav schránky se nepodařilo načíst: ${error.message}`,'error')}
}
async function testConnection(){
  const button=$('testConnectionBtn');button.disabled=true;button.textContent='Testuji…';setStatus('Ověřuji přihlášení k Webnode IMAP…')
  try{if(preview){await new Promise(resolve=>setTimeout(resolve,250))}else await mailApi('/finance/account/test',{method:'POST',body:JSON.stringify(payload()),timeoutMs:75000});setStatus('Připojení funguje. Schránka je dostupná přes šifrovaný IMAP.','success')}
  catch(error){setStatus(`Připojení se nezdařilo: ${error.message}`,'error')}
  finally{button.disabled=false;button.textContent='Otestovat připojení'}
}
async function save(event){
  event.preventDefault();const button=form.querySelector('button[type="submit"]');button.disabled=true;button.textContent='Ukládám…';setStatus('Šifruji přístup a zapínám automatický příjem…')
  try{if(preview){setStatus('V náhledu se přístupové údaje neukládají.','success');return}const result=await mailApi('/finance/account',{method:'POST',body:JSON.stringify(payload()),timeoutMs:75000});form.elements.password.value='';render(result);setStatus('Schránka byla bezpečně připojena. První synchronizace běží na pozadí.','success','Automatická kontrola každých 5 minut')}
  catch(error){setStatus(`Schránku se nepodařilo připojit: ${error.message}`,'error')}
  finally{button.disabled=false;button.textContent='Bezpečně uložit a zapnout'}
}
async function syncNow(){
  const button=$('syncNowBtn');button.disabled=true;button.textContent='Synchronizuji…';setStatus('Načítám nové přílohy z fakturační schránky…')
  try{if(preview){await new Promise(resolve=>setTimeout(resolve,300));setStatus('Náhled synchronizace byl dokončen.','success');return}const result=await mailApi('/finance/sync',{method:'POST',timeoutMs:120000});account=result.account||account;render({account,stats:result.result?.stats});const queued=result.result?.queued||0;setStatus(`Synchronizace dokončena · ${queued} nových příloh.`, 'success', `${result.result?.duplicate||0} duplicit přeskočeno`)}
  catch(error){setStatus(`Synchronizace se nezdařila: ${error.message}`,'error')}
  finally{button.disabled=false;button.textContent='Synchronizovat nyní'}
}

$('testConnectionBtn').addEventListener('click',testConnection)
form.addEventListener('submit',save)
$('syncNowBtn').addEventListener('click',syncNow)
if(window.OlvendSidebar){window.OlvendSidebar.initMobileNav($('mobileNavShell'));window.OlvendSidebar.setActive('finance-settings')}
load()
