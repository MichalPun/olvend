import fs from 'node:fs'
import assert from 'node:assert/strict'
import { createRequire } from 'node:module'

const require = createRequire(import.meta.url)
const playwright = process.env.CODEX_NODE_MODULES
  ? require(`${process.env.CODEX_NODE_MODULES}/playwright`)
  : require('playwright')
const { chromium } = playwright

const baseUrl = process.env.CONTROL_TEST_URL || 'http://127.0.0.1:18771'
const employeeId = '11111111-1111-1111-1111-111111111111'
const desktopSource = fs.readFileSync(new URL('../controlling.html', import.meta.url), 'utf8')
const mobileSource = fs.readFileSync(new URL('../mobile-control.html', import.meta.url), 'utf8')
const sqlSource = fs.readFileSync(new URL('../database/control_routes_v55.sql', import.meta.url), 'utf8')
const adjustmentSqlSource = fs.readFileSync(new URL('../database/control_adjustments_v56.sql', import.meta.url), 'utf8')

assert.doesNotMatch(desktopSource, /\.from\(['"]route_plans['"]\)/)
assert.doesNotMatch(desktopSource, /\.from\(['"]route_plan_stops['"]\)/)
assert.doesNotMatch(mobileSource, /\.from\(['"]route_plans['"]\)/)
assert.doesNotMatch(mobileSource, /\.from\(['"]route_plan_stops['"]\)/)
assert.doesNotMatch(sqlSource, /references\s+public\.route_plans/i)
assert.doesNotMatch(sqlSource, /references\s+public\.route_plan_stops/i)
assert.doesNotMatch(adjustmentSqlSource, /(?:update|insert\s+into|delete\s+from)\s+public\.route_plans/i)
assert.doesNotMatch(adjustmentSqlSource, /(?:update|insert\s+into|delete\s+from)\s+public\.route_plan_stops/i)

const mockModule = `
const employeeId = '11111111-1111-1111-1111-111111111111';
const employees = [{id:employeeId,name:'Michal',surname:'Punčochář',email:'michal@example.cz',active:true}];
const locations = [{id:10,name:'ViaPharma Ostrava',address:'Roháčova 89',city:'Ostrava',latitude:49.83,longitude:18.28}];
const machines = [
  {id:45,location_id:10,name:'Luce X2',machine_type:'coffee',brand:'Rheavendors',model:'Luce X2',evidence_number:45},
  {id:28,location_id:10,name:'Snack',machine_type:'food',brand:'Necta',model:'Snakky',evidence_number:28}
];
const stop = {id:501,location_id:10,stop_order:1,status:'planned',location_name_snapshot:'ViaPharma Ostrava',address_snapshot:'Roháčova 89',city_snapshot:'Ostrava',control_route_machines:[{id:601,machine_id:45,machine_kind:'coffee',status:'planned',evidence_number_snapshot:45,machine_name_snapshot:'Luce X2',checklist_config:{},snapshot:{}},{id:602,machine_id:28,machine_kind:'food',status:'planned',evidence_number_snapshot:28,machine_name_snapshot:'Snack',checklist_config:{},snapshot:{}}]};
const route = {id:101,name:'Kontrolní trasa Ostrava',control_type:'regular',planned_date:'2026-10-20',planned_start_time:'08:00:00',status:'published',instructions:'Ověřit čistotu a skutečnost.',checklist_config:{},rule_config:{photo_for_high:true,critical_stops_machine:true,show_last_completed_visit:true},employees:employees[0],control_route_stops:[stop]};
const foodSlot = {id:1,slot_code:'45',product_name:'Havlík tyčinky',product_sku:'HAVLIK',price_czk:25,current_units:6,capacity_units:8,sort_order:45};
const coffeeContainer = {id:3,container_code:'Z1',product_name:'Káva',product_sku:'KAVA',current_quantity:800,capacity_quantity:1500,unit:'g',sort_order:1};
const dataFor = table => {
  if(table==='employee_directory') return employees;
  if(table==='locations') return locations;
  if(table==='machines') return machines;
  if(table==='control_routes') return [route];
  if(table==='control_findings') return [];
  if(table==='route_machine_visits') return [{machine_id:45,completed_at:'2026-10-19T15:05:00+02:00',status:'completed',employees:{name:'David',surname:'Boudný'}},{machine_id:28,completed_at:'2026-10-19T15:10:00+02:00',status:'completed',employees:{name:'David',surname:'Boudný'}}];
  if(table==='machine_planogram_slots') return [foodSlot];
  if(table==='machine_coffee_buttons') return [{id:2,selection_code:'1',product_name:'Espresso',product_sku:'ESP',sale_price_czk:16,sort_order:1}];
  if(table==='machine_coffee_containers') return [coffeeContainer];
  return [];
};
function query(table){let rows=dataFor(table);const q={select(){return q},eq(){return q},in(){return q},not(){return q},order(){return q},limit(){return q},match(){return q},is(){return q},update(){return q},insert(){return q},single(){return Promise.resolve({data:Array.isArray(rows)?(rows[0]||{id:701}):rows,error:null})},maybeSingle(){return Promise.resolve({data:null,error:null})},then(ok,bad){return Promise.resolve({data:rows,error:null,count:table==='control_findings'?0:null}).then(ok,bad)}};return q}
export const supabase = {rpc(name,args){if(name==='current_employee_id')return Promise.resolve({data:employeeId,error:null});if(name==='create_control_route_v55')return Promise.resolve({data:102,error:null});if(name==='start_control_route_v55'){route.status='in_progress';return Promise.resolve({data:null,error:null})}if(name==='complete_control_route_v55'){route.status='completed';return Promise.resolve({data:null,error:null})}if(name==='apply_control_machine_adjustment_v56'){if(args.p_target_kind==='food_slot'&&args.p_adjustment_type==='price')foodSlot.price_czk=args.p_after_value.price_czk;if(args.p_target_kind==='food_slot'&&args.p_adjustment_type==='stock')foodSlot.current_units=args.p_after_value.current_units;if(args.p_target_kind==='coffee_container'&&args.p_adjustment_type==='stock')coffeeContainer.current_quantity=args.p_after_value.current_quantity;return Promise.resolve({data:{status:'applied'},error:null})}return Promise.resolve({data:null,error:null})},from:query,storage:{from(){return {upload:async()=>({data:{},error:null})}}},auth:{getSession:async()=>({data:{session:{user:{id:'auth'}}},error:null})}};
export async function syncOfflineRequests(){return {pending:0,synced:0}}
export function getOfflineRequestCount(){return 0}
`

const browser = await chromium.launch({
  headless: true,
  ...(process.env.CONTROL_BROWSER_PATH ? { executablePath: process.env.CONTROL_BROWSER_PATH } : {})
})
try {
  const page = await browser.newPage({ viewport: { width: 1440, height: 1000 } })
  await page.route('**/supabase.js*', route => route.fulfill({ status: 200, contentType: 'application/javascript', body: mockModule }))
  await page.route('**/pwa.js*', route => route.fulfill({ status: 200, contentType: 'application/javascript', body: '' }))
  await page.route('**/sidebar.js*', route => route.fulfill({ status: 200, contentType: 'application/javascript', body: '' }))
  await page.goto(`${baseUrl}/controlling.html`, { waitUntil: 'domcontentloaded' })
  await page.getByRole('heading', { name: 'Kontrolní trasy' }).waitFor()
  assert.match(await page.locator('#tableWrap').innerText(), /Kontrolní trasa Ostrava/)
  await page.locator('#newBtn').click()
  await page.locator('#employee').selectOption(employeeId)
  await page.locator('#nextBtn').click()
  await page.locator('[data-add="10"]').click()
  await page.locator('#nextBtn').click()
  await page.locator('#nextBtn').click()
  await page.locator('#nextBtn').click()
  assert.match(await page.locator('#review').innerText(), /Oddělení tras/)
  await page.locator('#publishBtn').click()
  await page.locator('#formStatus.success').waitFor()

  const mobile = await browser.newPage({ viewport: { width: 430, height: 900 } })
  await mobile.route('**/supabase.js*', route => route.fulfill({ status: 200, contentType: 'application/javascript', body: mockModule }))
  await mobile.route('**/pwa.js*', route => route.fulfill({ status: 200, contentType: 'application/javascript', body: '' }))
  await mobile.goto(`${baseUrl}/mobile-control.html`, { waitUntil: 'domcontentloaded' })
  await mobile.getByText('Kontrolní trasa Ostrava').waitFor()
  assert.equal(await mobile.locator('.app').evaluate(element => getComputedStyle(element).backgroundColor), 'rgb(247, 249, 252)')
  await mobile.locator('[data-open-route="101"]').click()
  await mobile.locator('[data-open-stop="501"]').click()
  assert.equal(await mobile.locator('[data-complete-stop]').count(), 0)
  assert.equal(await mobile.locator('[data-check]').first().isEnabled(), false)
  await mobile.locator('#backBtn').click()
  await mobile.locator('[data-start-route]').click()
  await mobile.locator('[data-open-stop="501"]').click()
  assert.match(await mobile.locator('#stopContent').innerText(), /Poslední skutečně dokončená obsluha/)
  assert.match(await mobile.locator('#stopContent').innerText(), /David Boudný/)
  await mobile.locator('[data-open-machine="602"]').click()
  assert.match(await mobile.locator('#machineContent').innerText(), /Teplota chlazení/)
  assert.match(await mobile.locator('#machineContent').innerText(), /Havlík tyčinky/)
  await mobile.locator('[data-adjust-target="food_slot:1"]').click()
  await mobile.locator('#adjustmentValue').fill('30')
  await mobile.locator('#saveAdjustment').click()
  await mobile.locator('#adjustmentModal').waitFor({ state: 'hidden' })
  assert.match(await mobile.locator('#machineContent').innerText(), /30 Kč/)
  console.log('Control routes module: UI and separation checks OK')
} finally {
  await browser.close()
}
