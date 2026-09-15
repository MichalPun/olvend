import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {stripTypeScriptTypes} from 'node:module';
const source=fs.readFileSync('supabase/functions/gp-vendsoft-telemetry/index.ts','utf8');
const context=vm.createContext({console,Response,Map,Set,Date});
vm.runInContext(stripTypeScriptTypes(source.replace(/^import .*\n/,'').split('Deno.serve(')[0],{mode:'transform'}),context);
assert.equal(context.terminalCounterUnitPrice(10,5000,12,8000),15);
assert.equal(context.terminalCounterUnitPrice(10,5000,12,5000),0);
assert.equal(context.terminalCounterUnitPrice(10,5000,1,1000),null);
assert.equal(context.terminalCounterUnitPrice(10,null,12,8000),null);
assert.equal(context.terminalCounterUnitPrice(10,5000,10,5000),null);
assert.equal(context.terminalCounterUnitPrice(10,5000,11,1000),null);
async function sale(value) {
 let saved;
 const client={from(table){return {select(){return this},eq(){return this},maybeSingle(){return Promise.resolve({data:table==='telemetry_dex_ingests'?{device_id:'x',raw_dex:'PA1*1*99\nPA2*10*5000'}:{last_total_count:10,last_ingest_id:1}})},then(resolve){resolve({data:[{id:1,slot_code:'1',product_name:'Coffee',customer_price_czk:5}]})},upsert(row){if(table==='telemetry_sales_events'){saved=row[0];throw Error('captured')}return Promise.resolve({})}}}};
 await assert.rejects(context.applyPlanogramDepletion(client,{provider:'IMA',machineId:1,ingestId:2,deviceId:'x',counters:[{selection:'1',count_total:11,value_total:value}],eventAt:'2026-09-15T19:00:00Z',previousPaymentCounters:{cashless:{quantity:10,amount:5000}},paymentCounters:{cashless:{quantity:11,amount:6500}}}),/captured/);
 return saved;
}
const known=await sale(6500);assert.equal(known.total_amount_czk,15);assert.equal(known.unit_price_czk,15);assert.equal(known.terminal_unit_price_czk,15);assert.equal(known.planogram_unit_price_czk,5);assert.equal(known.price_source,'dex_counter_delta');
const missing=await sale(null);assert.equal(missing.unit_price_czk,5);assert.equal(missing.total_amount_czk,null);assert.equal(missing.price_source,'planogram_estimate');
const html=fs.readFileSync('machines.html','utf8');
const start=html.indexOf('    function renderTerminalPriceChecks('),end=html.indexOf('    async function savePlanogramSlot',start);
const ui=vm.createContext({escapeHtml:String,formatDateTime:String});vm.runInContext(html.slice(start,end),ui);
const warning=ui.renderTerminalPriceChecks([{slot_code:'1',product_name:'Coffee',customer_price_czk:5}],[{selection_code:'1',terminal_unit_price_czk:15,price_source:'dex_counter_delta'}],false);assert.match(warning,/Rozdílná cena/);assert.match(warning,/open/);
assert.match(ui.renderTerminalPriceChecks([{slot_code:'1'}],[],false),/Cenu nelze ověřit/);
console.log('Terminal price priority, reset/missing safeguards and price warning tests passed');
