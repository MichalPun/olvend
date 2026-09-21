import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
const html=readFileSync('technician-mobile.html','utf8');
for(const match of html.matchAll(/<script[^>]*>([\s\S]*?)<\/script>/g))new vm.SourceTextModule(match[1]);
const context=vm.createContext({Intl,Date,state:{employee:{id:'tech'},plan:[]},today:'2026-09-15'});
vm.runInContext(html.slice(html.indexOf('function serviceDone('),html.indexOf('function buildTasks(')),context);
const old={id:140,status:'assigned',assigned_employee_id:'tech',created_at:'2026-09-14T14:28:23Z',due_date:'2026-09-14'};
assert.equal(context.serviceBelongsToToday(old),true,'Yesterday’s open service remains visible');
assert.equal(context.serviceBelongsToToday({...old,due_date:null}),true);
assert.equal(context.serviceBelongsToToday({...old,due_date:'2026-09-16'}),false);
for(const status of ['done','cancelled','blocked'])assert.equal(context.serviceBelongsToToday({...old,status}),false);
assert.equal(context.serviceBelongsToToday({...old,assigned_employee_id:null}),false,'Do not import all historic unassigned work');
assert.equal(context.jobBelongsToToday({...old,planned_date:'2026-09-14'}),true);
assert.equal(context.jobBelongsToToday({...old,planned_date:'2026-09-16'}),false);
assert.equal(context.jobBelongsToToday({...old,status:'closed',planned_date:'2026-09-14'}),false);
const start=html.split('data-screen="start"')[1].split('</section>')[0];
assert.match(start,/data-nav="new-service"/);
const create=html.slice(html.indexOf('async function createService('),html.indexOf('function renderToday('));
assert.doesNotMatch(create,/startShift\(|from\('attendance/);
assert.doesNotMatch(create,/show\('today'\)/);
const elements=new Map();const element=key=>{if(!elements.has(key))elements.set(key,{classList:{toggle(){}},dataset:{}});return elements.get(key)};
const ui=vm.createContext({state:{attendance:null},$:element,$$:()=>[],window:{scrollTo(){}}});
vm.runInContext(html.slice(html.indexOf('function show(screen)'),html.indexOf('\n',html.indexOf('function show(screen)'))),ui);
ui.show('new-service');assert.equal(element('#headerTitle').textContent,'Nový servis');assert.equal(element('#nav').hidden,true);
ui.show('today');assert.equal(element('#headerTitle').textContent,'Zahájení směny');
console.log('PASS: overdue service/job visibility, terminal statuses, future scheduling, pre-shift creation/navigation, module syntax');

// The complete list must retain rows excluded from the day plan.
const fixtures=[
 {...old,id:1,assigned_employee_id:null,due_date:null},
 {...old,id:2,due_date:'2026-09-20'},
 {...old,id:3,status:'blocked'},
 {...old,id:4,status:'done',resolved_at:'2026-09-14T12:00:00Z'},
 {...old,id:5}
];
const output=new Map();const node=key=>{if(!output.has(key))output.set(key,{});return output.get(key)};
const tasks=vm.createContext({Intl,Date,state:{employee:{id:'tech'},plan:[],services:fixtures,jobs:[{...old,id:7,job_type:'transfer',planned_date:'2026-09-20'}],filter:'all'},today:'2026-09-15',locationOf:()=>null,machineOf:()=>null,taskKey:(type,id)=>`${type}:${id}`,$:node,taskCard:item=>String(item.id)});
vm.runInContext(html.slice(html.indexOf('function serviceDone('),html.indexOf('function taskTypeLabel(')),tasks);
tasks.buildTasks();assert.equal(tasks.state.allTasks.length,6);assert.equal(tasks.state.allTasks[0].done,false,'Unfinished work is listed before history');assert.deepEqual(Array.from(tasks.state.tasks,item=>item.id),[5]);
vm.runInContext(html.slice(html.indexOf('function renderTasks()'),html.indexOf('function renderEnd()')),tasks);
for(const [filter,count] of [['all',6],['today',1],['service',5],['transport',1],['done',2]]){
 tasks.state.filter=filter;tasks.renderTasks();assert.equal(node('#taskCount').textContent,String(count),filter);
}
// Opening a task outside today's plan must resolve from the full list.
Object.assign(tasks,{renderDetail:()=>{},show:()=>{},isShiftRunning:()=>false});
vm.runInContext(html.slice(html.indexOf('async function openTask('),html.indexOf('async function startService(')),tasks);
await tasks.openTask('service_request:2');assert.equal(tasks.state.activeTask.id,2);
const paging=vm.createContext({});vm.runInContext(html.slice(html.indexOf('async function loadAllTaskRows('),html.indexOf('async function loadData(')),paging);
const pages=[];const loaded=await paging.loadAllTaskRows(()=>({range:async(start,end)=>{pages.push([start,end]);return{data:Array.from({length:start===0?500:2},(_,i)=>({id:start+i})),error:null}}}));assert.equal(loaded.data.length,502);assert.deepEqual(pages,[[0,499],[500,999]]);
const failed=await paging.loadAllTaskRows(()=>({range:async()=>({data:null,error:{message:'denied'}})}));assert.equal(failed.data,null);assert.equal(failed.error.message,'denied');
console.log('PASS: all/date/type filters, old unassigned/future/blocked/completed tasks, detail opening and pagination');
