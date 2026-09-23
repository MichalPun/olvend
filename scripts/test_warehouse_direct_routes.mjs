import fs from 'node:fs'
import vm from 'node:vm'
import assert from 'node:assert/strict'
const html = fs.readFileSync('mobile.html','utf8')
function extract(name) {
 const start=html.search(new RegExp(`    (?:async )?function ${name}\\(`))
 assert.ok(start>=0,name)
 const end=html.indexOf('\n    }',start)+6
 return html.slice(start,end)
}
const direct={id:1,vehicle_id:null,warehouse_id:1,route_payload:{stock_source_mode:'warehouse_direct',stock_source_name:'BLUČINA'},route_plan_stops:[{id:10}]}
const regular={id:2,vehicle_id:4,route_payload:{},route_plan_stops:[{id:20}]}
let current=direct
const locCalls=[]
const c={state:{routePlans:[direct,regular],employee:{id:'operator'},products:[]},getAssignedRoutePlan:()=>current,getCurrentVehicleId:()=>4,ensureStockLocation:async(...args)=>{locCalls.push(args);return args[0]==='warehouse'?100:200},escapeHtml:x=>x}
vm.createContext(c)
vm.runInContext(['getRouteStockPlan','isWarehouseDirectRoute','getRouteStockSource','getRouteStockLocation'].map(extract).join('\n'),c)
assert.equal(c.getRouteStockSource().type,'warehouse','direct route ignores another vehicle on attendance')
assert.equal(await c.getRouteStockLocation({stopId:10}),100)
assert.equal(await c.getRouteStockLocation({stopId:20}),200,'another route keeps vehicle source')
assert.throws(()=>c.getRouteStockSource({...direct,warehouse_id:null}),/vyžaduje sklad/)
assert.throws(()=>c.getRouteStockSource({...direct,vehicle_id:4}),/vyžaduje sklad/)
await assert.rejects(c.getRouteStockLocation({stopId:99}),/Nelze určit/)
current=regular;c.getCurrentVehicleId=()=>null
assert.throws(()=>c.getRouteStockSource(),/musí být nastavené/,'legacy unassigned route must not silently drain warehouse')
current=direct
// Execute the real FEFO movement builder against two source batches.
c.normalizeFoodExpiryDate=x=>x||''
c.getBalanceRecords=async id=>{assert.equal(id,100);return [{batch_id:1,quantity_on_hand:2,expiry_date:'2026-10-01'},{batch_id:2,quantity_on_hand:5,expiry_date:'2026-11-01'}]}
vm.runInContext(extract('moveStockPreservingBatches'),c)
const rows=await c.moveStockPreservingBatches({productId:8,quantity:4,fromStockLocationId:await c.getRouteStockLocation({stopId:10}),toStockLocationId:300,movementType:'fill_machine',referenceId:'visit-test'})
assert.equal(rows.length,2)
assert.deepEqual(Array.from(rows,x=>[x.from_stock_location_id,x.to_stock_location_id,x.batch_id,x.quantity_base_units]),[[100,300,1,2],[100,300,2,2]])
await assert.rejects(c.moveStockPreservingBatches({productId:8,quantity:8,fromStockLocationId:100,toStockLocationId:300,movementType:'fill_machine'}),/není dost/)
// Real coffee sync uses the same source, including reversal back to warehouse.
const detail={visitId:9,draft:{containers:{}},vehiclePackages:{8:5}}
let moved=0;let recorded=[]
Object.assign(c,{assertRouteVisitNotCorrected:async()=>{},getCoffeeDetail:()=>detail,getCoffeeActualPackages:()=>2,getCoffeeSelectableMaxPackages:()=>5,navigator:{onLine:true},getCoffeeVehicleStockQuantity:(x,n)=>n,loadCoffeeNetMovedQuantity:async()=>moved,getCoffeePackageBaseQuantity:()=>1,applyStockMovementsAtomically:async rows=>{recorded=rows},persistMobileSnapshot:()=>{}})
c.ensureStockLocation=async(type)=>type==='warehouse'?100:type==='machine'?300:200
c.getBalanceRecords=async()=>[{batch_id:1,quantity_on_hand:10,expiry_date:'2026-10-01'}]
vm.runInContext(extract('syncCoffeePackagesWithVehicle'),c)
await c.syncCoffeePackagesWithVehicle(10,{id:5,product_id:8,machine_id:3},2)
assert.equal(recorded[0].from_stock_location_id,100);assert.equal(recorded[0].to_stock_location_id,300)
moved=2;await c.syncCoffeePackagesWithVehicle(10,{id:5,product_id:8,machine_id:3},1)
assert.equal(recorded[0].from_stock_location_id,300);assert.equal(recorded[0].to_stock_location_id,100)
assert.match(html,/source_warehouse_id: stockSource.type === 'warehouse'/)
assert.match(html,/warehouse_id, planned_employee_id, execution_status/)
console.log('PASS: explicit warehouse selection, legacy/vehicle isolation, FEFO batches, insufficient stock, coffee transfer and reversal, waste warehouse linkage')
