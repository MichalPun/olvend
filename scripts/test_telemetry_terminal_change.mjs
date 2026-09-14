import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import { stripTypeScriptTypes } from 'node:module';
const source=fs.readFileSync('backend/supabase/functions/gp-vendsoft-telemetry/index.ts','utf8');
const code=stripTypeScriptTypes(source.replace(/^import .*\n/, '').split('Deno.serve(')[0]);
const context=vm.createContext({console,Response,Map,Set,Date});
vm.runInContext(code,context);
async function scenario(previousDevice,resetDeviceBaseline,previousCount=10,nextCount=263) {
  const writes=[];
  const client={from(table){let filters={};return {select(){return this},eq(k,v){filters[k]=v;return this},maybeSingle(){return Promise.resolve({data:table==='telemetry_dex_ingests'?{device_id:previousDevice}:{last_total_count:previousCount,last_ingest_id:1}})},then(resolve){resolve({data:table==='machine_planogram_slots'?[{id:1,slot_code:'1',product_name:'Coffee',customer_price_czk:12}]:[]})},upsert(row){if(table==='telemetry_sales_events') {assert.equal(row[0].quantity,1);throw new Error('VALID_NEXT_SALE');} writes.push({table,row});return Promise.resolve({error:null})}}}};
  const result=await context.applyPlanogramDepletion(client,{provider:'IMA',machineId:66,ingestId:2,deviceId:'602224',resetDeviceBaseline,counters:[{selection:'1',count_total:nextCount}],eventAt:'2026-09-14T11:31:49Z',previousPaymentCounters:{},paymentCounters:{},previousPaymentCredit:{}});
  return {writes,result};
}
for (const reset of [false,true]) {
  const {writes,result}=await scenario('602227',reset);
  assert.equal(writes.length,1,'terminal change must only write counter baseline');
  assert.equal(writes[0].row.last_total_count,263);
  assert.equal(result.applied[0].vend_delta,0);
  assert.equal(result.applied[0].baseline_initialized,true);
}
const replay=await scenario('602224',false,263,263);
assert.equal(replay.result.applied.length,0,'identical report must not create sales');
assert.equal(replay.writes.length,1);
await assert.rejects(scenario('602224',false,263,264), /VALID_NEXT_SALE/);
console.log('OK: terminal switch, retry after state overwrite, and identical-report replay');
