import assert from 'node:assert/strict'
import fs from 'node:fs'
import vm from 'node:vm'
const html = fs.readFileSync('mobile.html', 'utf8')
const products = [{id:206,sku:'SOCO-PROTEIN-COKOLADA-45',name:'Protein chocolate'}, {id:205,sku:'SOCO-PROTEIN-VANILKA-45',name:'Protein vanilla'}]
const slot = {id:2212,machine_id:123,product_sku:products[0].sku,capacity_units:10,current_units:10,target_units:10,substitution_policy:'approved_list',allowed_substitutes:'SKU SOCO-PROTEIN-VANILKA-45'}
const ctx = vm.createContext({state:{products},normalizeText:x=>String(x).toLowerCase(),getFoodPlanogramChange:()=>null,getFoodProductFamily:()=>'',isFoodExpiryExpired:()=>false,getFoodDemandTargetQuantity:s=>s.target_units,getFoodDailySales:()=>1,getFoodTransferReservedByBatch:()=>new Map(),getFoodSlotDraft:()=>({fillItems:[],preparedQuantity:0,pickedQuantity:0}),getFoodAvailableVehicleQuantity:(d,stop,slot,id)=>d.vehicleStock[id]||0,escapeHtml:x=>String(x)})
for(const [a,b] of [['getFoodPlanningSlot','allocateFoodFillFromVehicleBatches'],['getFoodSlotProductOptions','getFoodSlotComposition'],['getFoodRouteAllocatedQuantity','getRouteStopUrgency'],['getFoodPickSuggestion','prefillFoodRecommendedPicks'],['renderFoodAvailableReplacement','refreshFoodMachineTotals']]){
 const start=html.indexOf('    function '+a+'(')
 const end=html.indexOf('    '+(b==='getRouteStopUrgency'?'async ':'')+'function '+b+'(',start)
 assert.ok(start>=0&&end>start)
 vm.runInContext(html.slice(start,end),ctx)
}
const detail={draft:{slots:{}},vehicleStock:{205:37,206:0},routePlanningContext:{loaded:true,routeSlots:[slot],stopOrderByMachine:new Map([['123',0]])}}
assert.equal(ctx.getFoodPickSuggestion(detail,1,slot).quantity,0)
detail.draft.slots[2212]={actualBefore:0}
let result=ctx.getFoodPickSuggestion(detail,1,slot)
assert.equal(result.product.id,205)
assert.equal(result.quantity,10,'Physical zero must reopen a formerly full slot and allocate its replacement')
assert.equal(slot.current_units,10,'Keep original evidence for inventory correction')
assert.match(ctx.renderFoodAvailableReplacement(detail,1,slot),/machine-use-suggestion/)
detail.vehicleStock[205]=3
assert.equal(ctx.getFoodPickSuggestion(detail,1,slot).quantity,3)
detail.vehicleStock[205]=0
assert.equal(ctx.renderFoodAvailableReplacement(detail,1,slot),'')
detail.vehicleStock[205]=37
assert.equal(ctx.getFoodPickSuggestion(detail,1,{...slot,substitution_policy:'exact'}).quantity,0)
detail.draft.slots[2212]={actualBefore:10}
assert.equal(ctx.getFoodPickSuggestion(detail,1,slot).quantity,0)
detail.draft.slots[2212]={actualBefore:0,accepted:true}
assert.equal(ctx.getFoodRequiredFillQuantity(slot,detail),0,'Accepted draft must not reopen a completed fill')
console.log('PASS: actual stock drives replacement demand/allocation, stock limits, exact policy, visible action, original evidence preserved')
