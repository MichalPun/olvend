import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
const source=fs.readFileSync('purchases.html','utf8');
for(const match of source.matchAll(/<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)<\/script>/gi)) {
 if(!match[1].trim())continue;
 if(/^\s*import\s/m.test(match[1]))new vm.SourceTextModule(match[1]);else new vm.Script(match[1]);
}
const helper=source.slice(source.indexOf('    function setWarehouseBalances('),source.indexOf('    async function loadAllPurchaseOrderItems('));
let failPage=false;
const rows=Array.from({length:1100},(_,i)=>({id:i+1,stock_location_id:1,product_id:i<1000?1:2,quantity_on_hand:i===1099?-1:1}));
const calls=[];
const supabase={from(name){assert.equal(name,'stock_location_balances');return{select(columns){assert.match(columns,/stock_locations!inner/);return this},eq(k,v){assert.equal(k,'stock_locations.location_type');assert.equal(v,'warehouse');return this},neq(k,v){assert.equal(k,'quantity_on_hand');assert.equal(v,0);return this},order(k){assert.equal(k,'id');return this},range(from,to){calls.push([from,to]);return Promise.resolve(failPage&&from===500?{error:new Error('offline')}:{data:rows.slice(from,to+1),error:null})}}}};
const ctx=vm.createContext({supabase,Map,Number,String,warehouses:[{id:1,active:true}],stockLocations:[{id:1,warehouse_id:1,active:true,name:'Blučina'}],normalizeText:s=>s.toLowerCase(),warehouseBalancesByProduct:new Map()});
vm.runInContext(helper,ctx);
let result=await ctx.loadAllWarehouseBalances();assert.equal(result.data.length,1100);assert.equal(calls.length,3);
ctx.setWarehouseBalances(result.data);assert.equal(ctx.warehouseBalancesByProduct.get('2'),98,'late batches and negative corrections must be summed');
failPage=true;result=await ctx.loadAllWarehouseBalances();assert.equal(result.data,null,'partial data must not be mistaken for zero stock');assert.ok(result.error);
console.log('OK: warehouse pagination beyond 1000 rows, batch totals, negative corrections and failed-page handling');
