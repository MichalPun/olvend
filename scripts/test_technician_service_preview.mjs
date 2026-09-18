import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
const html=readFileSync('technician-mobile.html','utf8');
for(const match of html.matchAll(/<script[^>]*>([\s\S]*?)<\/script>/g))new vm.SourceTextModule(match[1]);
const detail={innerHTML:''};
let stockReads=0;
const state={attendance:null,tasks:[],activeTask:{sourceType:'service_request',id:152,title:'Telefonní hlášení – dohledat automat',subtitle:'',done:false,raw:{id:152,title:'Telefonní hlášení – dohledat automat',description:'Závada: nevydává nápoj\nZpětný kontakt: 123456789\n<script>bad()</script>',status:'new',created_at:'2026-09-17T07:53:12Z'}}};
state.tasks=[state.activeTask];
const context=vm.createContext({state,Date,console,$:()=>detail,locationOf:()=>null,machineOf:()=>null,taskTypeLabel:()=>'Servis',serviceForm:()=>'<form>Zápis servisu</form>',isShiftRunning:()=>state.attendance?.status==='open',taskKey:(type,id)=>`${type}:${id}`,loadServiceStock:async()=>{stockReads++},show:()=>{},supabase:{from(){throw Error('Unexpected database write/read during preview')}}});
vm.runInContext(html.split('\n').find(line=>line.includes('const esc =')),context);
vm.runInContext(html.slice(html.indexOf('function renderServiceReport('),html.indexOf('function serviceForm(')),context);
for(const status of ['new','in_progress']){
 state.activeTask.raw.status=status;context.renderDetail();
 assert.match(detail.innerHTML,/Zpětný kontakt: 123456789/);
 assert.match(detail.innerHTML,/&lt;script&gt;/);assert.doesNotMatch(detail.innerHTML,/<script>/);
 assert.match(detail.innerHTML,/white-space:pre-wrap/);
 assert.doesNotMatch(detail.innerHTML,/data-start-service|<form>/);
 assert.match(detail.innerHTML,/data-nav="start"/);
}
vm.runInContext(html.slice(html.indexOf('async function openTask('),html.indexOf('async function saveService(')),context);
await context.openTask('service_request:152');assert.equal(stockReads,0);
await assert.rejects(context.startService(),/nejdřív zahajte směnu/);
state.attendance={status:'open'};state.activeTask.raw.status='new';context.renderDetail();assert.match(detail.innerHTML,/data-start-service/);
state.activeTask.raw.status='in_progress';context.renderDetail();assert.match(detail.innerHTML,/<form>/);
await context.openTask('service_request:152');assert.equal(stockReads,1);
state.activeTask.done=true;context.renderDetail();assert.match(detail.innerHTML,/Zpětný kontakt: 123456789/);
assert.match(html.split('data-screen="start"')[1].split('</section>')[0],/data-nav="tasks"/);
console.log('PASS: full escaped report, pre-shift read-only preview, no preview database mutations, explicit work guard, active-shift actions, completed report');
