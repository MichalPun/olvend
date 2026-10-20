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
const economicsSqlSource = fs.readFileSync(new URL('../database/control_economics_v57.sql', import.meta.url), 'utf8')
const operationsSqlSource = fs.readFileSync(new URL('../database/control_operations_v58.sql', import.meta.url), 'utf8')
const protocolSource = fs.readFileSync(new URL('../control-route-protocol.html', import.meta.url), 'utf8')

assert.doesNotMatch(desktopSource, /\.from\(['"]route_plans['"]\)/)
assert.doesNotMatch(desktopSource, /\.from\(['"]route_plan_stops['"]\)/)
assert.doesNotMatch(mobileSource, /\.from\(['"]route_plans['"]\)/)
assert.doesNotMatch(mobileSource, /\.from\(['"]route_plan_stops['"]\)/)
assert.doesNotMatch(sqlSource, /references\s+public\.route_plans/i)
assert.doesNotMatch(sqlSource, /references\s+public\.route_plan_stops/i)
assert.doesNotMatch(adjustmentSqlSource, /(?:update|insert\s+into|delete\s+from)\s+public\.route_plans/i)
assert.doesNotMatch(adjustmentSqlSource, /(?:update|insert\s+into|delete\s+from)\s+public\.route_plan_stops/i)
assert.match(economicsSqlSource, /get_control_economics_v57/i)
assert.match(economicsSqlSource, /get_control_price_scenarios_v57/i)
assert.match(mobileSource, /Ekonomika lokality/)
assert.match(mobileSource, /Při poklesu prodejů o 5 %/)
assert.match(operationsSqlSource, /register_control_machine_photo_v58/i)
assert.match(operationsSqlSource, /apply_control_price_change_v58/i)
assert.match(operationsSqlSource, /save_control_price_label_request_v58/i)
assert.match(operationsSqlSource, /get_control_route_protocol_v58/i)
assert.match(operationsSqlSource, /swap_control_planogram_slots_v58/i)
assert.match(operationsSqlSource, /save_control_finding_v58/i)
assert.match(mobileSource, /Stav při odjezdu/)
assert.match(mobileSource, /Cenovky a lišty/)
assert.match(mobileSource, /Rentabilní od/)
assert.match(protocolSource, /NÁVŠTĚVNÍ PROTOKOL/)
assert.match(protocolSource, /Vytisknout \/ uložit PDF/)

const mockModule = `
const employeeId = '11111111-1111-1111-1111-111111111111';
const employees = [{id:employeeId,name:'Michal',surname:'Punčochář',email:'michal@example.cz',role:'operator',active:true},{id:'22222222-2222-2222-2222-222222222222',name:'Lukáš',surname:'Urbánek',email:'lukas@example.cz',role:'technik',active:true}];
const locations = [{id:10,name:'ViaPharma Ostrava',address:'Roháčova 89',city:'Ostrava',latitude:49.83,longitude:18.28}];
const machines = [
  {id:45,location_id:10,name:'Luce X2',machine_type:'coffee',brand:'Rheavendors',model:'Luce X2',evidence_number:45},
  {id:28,location_id:10,name:'Snack',machine_type:'food',brand:'Necta',model:'Snakky',evidence_number:28}
];
const stop = {id:501,location_id:10,stop_order:1,status:'planned',location_name_snapshot:'ViaPharma Ostrava',address_snapshot:'Roháčova 89',city_snapshot:'Ostrava',control_route_machines:[{id:601,machine_id:45,machine_kind:'coffee',status:'planned',evidence_number_snapshot:45,machine_name_snapshot:'Luce X2',checklist_config:{},snapshot:{}},{id:602,machine_id:28,machine_kind:'food',status:'planned',evidence_number_snapshot:28,machine_name_snapshot:'Snack',checklist_config:{},snapshot:{}}]};
const route = {id:101,name:'Kontrolní trasa Ostrava',control_type:'regular',planned_date:'2026-10-20',planned_start_time:'08:00:00',status:'published',instructions:'Ověřit čistotu a skutečnost.',checklist_config:{},rule_config:{photo_for_high:true,critical_stops_machine:true,show_last_completed_visit:true},employees:employees[0],control_route_stops:[stop]};
const foodSlot = {id:1,slot_code:'45',product_name:'Havlík tyčinky',product_sku:'HAVLIK',price_czk:25,current_units:6,capacity_units:8,sort_order:45};
const foodSlot2 = {id:4,slot_code:'48',product_name:'Pistácie',product_sku:'PISTACIE',price_czk:39,current_units:2,capacity_units:8,sort_order:48};
const coffeeContainer = {id:3,container_code:'Z1',product_name:'Káva',product_sku:'KAVA',current_quantity:800,capacity_quantity:1500,unit:'g',sort_order:1};
const thresholds = [
  {machine_kind:'food',minimum_monthly_revenue_czk:8000,target_monthly_revenue_czk:10000,note:'Potravinový automat'},
  {machine_kind:'coffee',minimum_monthly_revenue_czk:6000,target_monthly_revenue_czk:8000,note:'Kávový automat'}
];
let labelRequest = null;
let departureUploaded = false;
let preparedPriceApplied = false;
const dataFor = table => {
  if(table==='employee_directory') return employees;
  if(table==='employees') return employees;
  if(table==='locations') return locations;
  if(table==='machines') return machines;
  if(table==='control_routes') return [route];
  if(table==='control_findings') return [];
  if(table==='control_check_results') return [{id:801,control_route_id:101,control_route_stop_id:501,control_route_machine_id:null,scope:'place',item_key:'place_cleanliness',item_label:'Čistota místa a okolí',status:'ok'}];
  if(table==='route_machine_visits') return [{machine_id:45,completed_at:'2026-10-19T15:05:00+02:00',status:'completed',employees:{name:'David',surname:'Boudný'}},{machine_id:28,completed_at:'2026-10-19T15:10:00+02:00',status:'completed',employees:{name:'David',surname:'Boudný'}}];
  if(table==='machine_planogram_slots') return [foodSlot,foodSlot2];
  if(table==='machine_coffee_buttons') return [{id:2,selection_code:'1',product_name:'Espresso',product_sku:'ESP',sale_price_czk:16,sort_order:1}];
  if(table==='machine_coffee_containers') return [coffeeContainer];
  if(table==='control_economic_thresholds') return thresholds;
  if(table==='machine_price_label_request_items') return [{request_id:'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',target_type:'food_slot',target_record_id:1,slot_code:'45',product_name:'Havlík tyčinky',price_czk:30}];
  return [];
};
function query(table){let rows=dataFor(table);const q={select(){return q},eq(){return q},in(){return q},not(){return q},order(){return q},limit(){return q},range(){return Promise.resolve({data:rows,error:null})},match(){return q},is(){return q},update(){return q},insert(){return q},single(){return Promise.resolve({data:Array.isArray(rows)?(rows[0]||{id:701}):rows,error:null})},maybeSingle(){return Promise.resolve({data:null,error:null})},then(ok,bad){return Promise.resolve({data:rows,error:null,count:table==='control_findings'?0:null}).then(ok,bad)}};return q}
export const supabase = {rpc(name,args){if(name==='current_employee_id')return Promise.resolve({data:employeeId,error:null});if(name==='create_control_route_v55')return Promise.resolve({data:102,error:null});if(name==='start_control_route_v55'){route.status='in_progress';return Promise.resolve({data:null,error:null})}if(name==='complete_control_route_v55'){route.status='completed';return Promise.resolve({data:null,error:null})}if(name==='get_control_economics_v57')return Promise.resolve({data:[{machine_id:45,evidence_number:45,machine_kind:'coffee',minimum_monthly_revenue_czk:6000,target_monthly_revenue_czk:8000,current_month_revenue_czk:4300,projected_month_revenue_czk:7000,previous_month_revenue_czk:6500,trailing_30_days_revenue_czk:6800,units_30_days:300,latest_sale_at:'2026-10-19T15:00:00+02:00',data_quality:'fresh',evaluation_status:'watch'},{machine_id:28,evidence_number:28,machine_kind:'food',minimum_monthly_revenue_czk:8000,target_monthly_revenue_czk:10000,current_month_revenue_czk:7000,projected_month_revenue_czk:11500,previous_month_revenue_czk:9500,trailing_30_days_revenue_czk:10000,units_30_days:400,latest_sale_at:'2026-10-19T15:00:00+02:00',data_quality:'fresh',evaluation_status:'good'}],error:null});if(name==='get_control_price_scenarios_v57')return Promise.resolve({data:[{control_route_machine_id:601,machine_id:45,change_count:0,changes:[]},{control_route_machine_id:602,machine_id:28,change_count:1,current_30_days_revenue_czk:10000,price_effect_no_volume_change_czk:1000,scenario_no_decline_czk:11000,scenario_volume_minus_5_czk:10450,scenario_volume_minus_10_czk:9900,break_even_volume_loss_percent:9.1,data_quality:'ready',changes:[{selection_code:'45',product_name:'Havlík tyčinky',old_price_czk:25,new_price_czk:30,units_30_days:200,monthly_effect_czk:1000,source:'Dnešní kontrola'}]}],error:null});if(name==='get_control_revenue_trend_v58')return Promise.resolve({data:args.p_machine_ids.flatMap(machine_id=>['2026-05-01','2026-06-01','2026-07-01','2026-08-01','2026-09-01','2026-10-01'].map((month_start,index)=>({machine_id,month_start,revenue_czk:5000+index*700}))),error:null});if(name==='get_control_machine_workflow_v58')return Promise.resolve({data:{pending_price_changes:args.p_control_route_machine_id===602?[{id:'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',slot_code:'45',product_name:'Havlík tyčinky',old_price_czk:25,new_price_czk:30,label_printed_at:'2026-10-20T07:00:00+02:00'}]:[],label_request:null,departure_photos:[]},error:null});if(name==='save_control_price_label_request_v58')return Promise.resolve({data:{ok:true,request_id:'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',request_code:'CEN-TEST',assigned_employee:'Lukáš Urbánek'},error:null});if(name==='apply_control_price_change_v58')return Promise.resolve({data:{ok:true},error:null});if(name==='register_control_machine_photo_v58')return Promise.resolve({data:9,error:null});if(name==='update_control_economic_threshold_v57'){const row=thresholds.find(x=>x.machine_kind===args.p_machine_kind);row.minimum_monthly_revenue_czk=args.p_minimum_monthly_revenue_czk;row.target_monthly_revenue_czk=args.p_target_monthly_revenue_czk;return Promise.resolve({data:row,error:null})}if(name==='apply_control_machine_adjustment_v56'){if(args.p_target_kind==='food_slot'&&args.p_adjustment_type==='price')foodSlot.price_czk=args.p_after_value.price_czk;if(args.p_target_kind==='food_slot'&&args.p_adjustment_type==='stock')foodSlot.current_units=args.p_after_value.current_units;if(args.p_target_kind==='coffee_container'&&args.p_adjustment_type==='stock')coffeeContainer.current_quantity=args.p_after_value.current_quantity;return Promise.resolve({data:{status:'applied'},error:null})}return Promise.resolve({data:null,error:null})},from:query,storage:{from(){return {upload:async()=>({data:{},error:null}),createSignedUrl:async()=>({data:{signedUrl:'https://example.test/photo.jpg'},error:null})}}},auth:{getSession:async()=>({data:{session:{user:{id:'auth'}}},error:null})}};
export async function syncOfflineRequests(){return {pending:0,synced:0}}
export function getOfflineRequestCount(){return 0}
`

const protocolMockModule = `
export const supabase = {
  rpc: async () => ({data:{route:{id:101,name:'Kontrolní trasa Ostrava',planned_date:'2026-10-20',status:'completed',employee:'Michal Punčochář',completed_at:'2026-10-20T14:00:00+02:00'},stops:[{id:501,stop_order:1,status:'completed',location_name:'ViaPharma Ostrava',address:'Roháčova 89',city:'Ostrava',completed_at:'2026-10-20T13:50:00+02:00'}],machines:[{id:602,stop_id:501,machine_kind:'food',status:'completed',evidence_number:28,machine_name:'Snack'}],checks:[{stop_id:501,machine_id:602,item_label:'Kontrola cen na automatu',status:'ok',note:'Ceny fyzicky ověřeny'}],findings:[],adjustments:[],label_requests:[{stop_id:501,machine_id:602,request_code:'CEN-TEST',status:'requested',issue_types:['Chybí lišta'],assigned_employee:'Lukáš Urbánek',technical_job_id:77}],photos:[{stop_id:501,machine_id:602,photo_type:'departure',storage_path:'101/501/photo.jpg',created_at:'2026-10-20T13:45:00+02:00'}]},error:null}),
  storage:{from(){return {createSignedUrl:async()=>({data:{signedUrl:'https://example.test/photo.jpg'},error:null})}}}
};
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
  await page.locator('#economicsBtn').click()
  assert.equal(await page.locator('#foodMinimum').inputValue(), '8000')
  assert.equal(await page.locator('#coffeeTarget').inputValue(), '8000')
  await page.locator('#closeEconomicsBtn').click()
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
  assert.match(await mobile.locator('#stopContent').innerText(), /Ekonomika lokality/)
  assert.match(await mobile.locator('#stopContent').innerText(), /Odhad měsíce/)
  assert.match(await mobile.locator('#stopContent').innerText(), /Poslední skutečně dokončená obsluha/)
  assert.match(await mobile.locator('#stopContent').innerText(), /David Boudný/)
  assert.equal(await mobile.locator('[data-check-card="place_cleanliness"] [data-check="ok"]').getAttribute('class'), 'ok selected')
  await mobile.locator('[data-open-machine="602"]').click()
  assert.match(await mobile.locator('#machineContent').innerText(), /Výkon automatu/)
  assert.match(await mobile.locator('#machineContent').innerText(), /Rentabilní od 8 000 Kč/)
  assert.match(await mobile.locator('#machineContent').innerText(), /Vývoj tržeb/)
  assert.match(await mobile.locator('#machineContent').innerText(), /Dopad změn cen/)
  assert.match(await mobile.locator('#machineContent').innerText(), /Při poklesu prodejů o 5 %/)
  assert.match(await mobile.locator('#machineContent').innerText(), /Připravené provozní úkoly/)
  assert.match(await mobile.locator('#machineContent').innerText(), /Kontrola cen na automatu/)
  assert.match(await mobile.locator('#machineContent').innerText(), /Cenovky a lišty/)
  assert.match(await mobile.locator('#machineContent').innerText(), /Stav při odjezdu/)
  assert.match(await mobile.locator('#machineContent').innerText(), /Teplota chlazení/)
  assert.match(await mobile.locator('#machineContent').innerText(), /Havlík tyčinky/)
  await mobile.locator('[data-open-labels]').click()
  await mobile.getByText('Chybí nebo je poškozená cenovková lišta', { exact: true }).click()
  assert.equal(await mobile.locator('#labelAssignee').inputValue(), '22222222-2222-2222-2222-222222222222')
  assert.match(await mobile.locator('#labelAssignmentHint').innerText(), /servisní zásah/)
  await mobile.locator('#labelAssignee').selectOption(employeeId)
  await mobile.locator('#saveLabels').click()
  assert.match(await mobile.locator('#labelStatus').innerText(), /nutné předat technikovi/)
  await mobile.locator('#labelAssignee').selectOption('22222222-2222-2222-2222-222222222222')
  await mobile.locator('[data-label-item]').first().check()
  await mobile.locator('#saveLabels').click()
  await mobile.locator('#labelModal').waitFor({ state: 'hidden' })
  await mobile.locator('[data-open-swap]').click()
  assert.equal(await mobile.locator('#swapFrom option').count(), 2)
  await mobile.locator('#cancelSwap').click()
  await mobile.locator('[data-check-card="food_planogram"] [data-check="finding"]').click()
  await mobile.locator('#findingResolution').selectOption('task')
  assert.equal(await mobile.locator('#findingAssignee').inputValue(), employeeId)
  assert.equal(await mobile.locator('#findingAssigneeLabel').isVisible(), true)
  await mobile.locator('#cancelFinding').click()
  await mobile.locator('[data-adjust-target="food_slot:1"]').click()
  await mobile.locator('#adjustmentValue').fill('30')
  await mobile.locator('#saveAdjustment').click()
  await mobile.locator('#adjustmentModal').waitFor({ state: 'hidden' })
  assert.match(await mobile.locator('#machineContent').innerText(), /30 Kč/)

  const protocol = await browser.newPage({ viewport: { width: 1100, height: 900 } })
  await protocol.route('**/supabase.js*', route => route.fulfill({ status: 200, contentType: 'application/javascript', body: protocolMockModule }))
  await protocol.goto(`${baseUrl}/control-route-protocol.html?route=101`, { waitUntil: 'domcontentloaded' })
  await protocol.getByRole('heading', { name: 'Kontrolní trasa Ostrava' }).waitFor()
  assert.match(await protocol.locator('#content').innerText(), /NÁVŠTĚVNÍ PROTOKOL/)
  assert.match(await protocol.locator('#content').innerText(), /Lukáš Urbánek/)
  assert.match(await protocol.locator('#content').innerText(), /Kontrola cen na automatu/)
  console.log('Control routes module: UI and separation checks OK')
} finally {
  await browser.close()
}
