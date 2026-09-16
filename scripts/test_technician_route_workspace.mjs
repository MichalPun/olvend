import assert from 'node:assert/strict'
import fs from 'node:fs'
import vm from 'node:vm'
const tech=fs.readFileSync('technician-mobile.html','utf8')
const mobile=fs.readFileSync('mobile.html','utf8')
for(const html of [tech,mobile])for(const m of html.matchAll(/<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)<\/script>/gi))if(m[1].trim())new vm.SourceTextModule(m[1])
const code=tech.slice(tech.indexOf('    function pendingRoutes('),tech.indexOf('    function renderToday('))
const elements=new Map()
const el=s=>{if(!elements.has(s))elements.set(s,{classList:{contains:()=>false},getAttribute(){return this.src},contentWindow:{postMessage(m){messages.push(m)}}});return elements.get(s)}
let rows=[],failure=null,queries=[],messages=[],loads=0,screens=[]
const context=vm.createContext({state:{employee:{id:'tech'},attendance:{id:483,actual_start:'2026-09-16T04:11Z'},routes:[]},today:'2026-09-16',location:{origin:'https://example.test'},window:{addEventListener(){}},$:el,esc:x=>String(x),show:s=>screens.push(s),renderToday(){},renderTasks(){},renderEnd(){},message(){},loadData:async()=>{loads++},supabase:{from(t){queries.push(t);return {select(){return this},eq(k,v){queries.push([k,v]);return this},then(resolve){resolve({data:rows,error:failure})}}}}})
vm.runInContext(code,context)
rows=[{title:'OSRAM',execution_status:'assigned'}]
await assert.rejects(context.verifyRoutesBeforeEnd(),/OSRAM/)
rows=[{execution_status:'in_progress'}];await assert.rejects(context.verifyRoutesBeforeEnd(),/Nejdřív/)
rows=[{execution_status:'done'},{execution_status:'cancelled'},{execution_status:'draft'}];await context.verifyRoutesBeforeEnd()
failure={message:'offline'};await assert.rejects(context.verifyRoutesBeforeEnd(),/Nelze ověřit/)
assert.ok(queries.some(q=>Array.isArray(q)&&q[0]==='planned_employee_id'&&q[1]==='tech'))
assert.ok(queries.some(q=>Array.isArray(q)&&q[0]==='planning_date'&&q[1]==='2026-09-16'))
await context.navigateTechnician('route');assert.equal(el('#routeFrame').src,'mobile.html?workspace=technician-route')
await context.navigateTechnician('route');assert.equal(messages[0].type,'technician-route-resume')
el('.screen[data-screen="route"]').classList.contains=()=>true
await context.navigateTechnician('tasks');assert.equal(loads,1);assert.equal(screens.at(-1),'tasks')
assert.equal(el('#routeFrame').src,'mobile.html?workspace=technician-route','Service navigation must retain the refill document and draft')
context.state.attendance=null;await context.navigateTechnician('route');assert.equal(screens.at(-1),'start')
const end=tech.slice(tech.indexOf('async function endShift()'),tech.indexOf("document.addEventListener('click'"))
assert.ok(end.indexOf('await verifyRoutesBeforeEnd()')<end.indexOf("from('attendance_days').update"))
const hostMessages=[]
const child=vm.createContext({technicianRouteEmbedded:true,navigateTechnicianHost:s=>hostMessages.push(s)})
for(const name of ['startShift','endShift']){
 const start=mobile.indexOf(`async function ${name}()`),end=mobile.indexOf('\n    async function ',start+20)
 // Only exercise the embedded guard; the remaining workflow must never execute.
 const line=mobile.slice(start,mobile.indexOf('\n',mobile.indexOf('\n',start)+1))+'\n}'
 vm.runInContext(line,child);await child[name]()
}
assert.deepEqual(hostMessages,['start','end'])
assert.match(mobile,/event\.origin!==location\.origin\|\|event\.source!==window\.parent/)
console.log('PASS: route visibility integration, employee/date scope, pending-route and offline end guards, retained refill workspace, one shift owner, module syntax')
