const fs=require('fs'),vm=require('vm'),assert=require('assert/strict');
const html=fs.readFileSync('machines.html','utf8');
function source(name){const start=html.indexOf('    function '+name+'(');assert(start>=0);const end=html.indexOf('\n    function ',start+10);return html.slice(start,end);}
const ctx={console,escapeHtml:s=>String(s??'').replaceAll('<','&lt;'),findCatalogProduct:()=>null,planogramMachineIdInput:{value:'22'},planogramCoffeeProductIdInput:{value:''}};
const fields=new Proxy({}, {get(t,k){return t[k]??(t[k]={value:'',checked:false})}});ctx.document={getElementById:id=>fields[id]};vm.createContext(ctx);
for(const f of ['getCoffeeButtonPayload','getTelemetrySlotPayloadFromCoffeeButton','coffeePlanogramLayout','renderCoffeePlanogram'])vm.runInContext(source(f),ctx);
fields.slotCode.value='1';fields.slotProductName.value='Káva';fields.slotPrice.value='10';fields.slotCustomerPrice.value='0';fields.slotSettlementType.value='subsidy_receivable';fields.slotSubsidyAmount.value='9.92';fields.slotSubsidyPayer.value='Partner';
let p=ctx.getCoffeeButtonPayload();assert.equal(p.customer_price_czk,0);assert.equal(p.settlement_amount_czk,9.92);assert.equal(p.settlement_partner,'Partner');assert.equal(p.settlement_billing_enabled,false);
let m=ctx.getTelemetrySlotPayloadFromCoffeeButton(p);assert.equal(m.subsidy_billing_enabled,false);assert.equal(m.subsidy_amount_czk,9.92);assert.equal(m.subsidy_payer,'Partner');
fields.slotSubsidyBillingEnabled.checked=true;p=ctx.getCoffeeButtonPayload();m=ctx.getTelemetrySlotPayloadFromCoffeeButton(p);assert.equal(m.subsidy_billing_enabled,true);assert.equal(m.subsidy_amount_czk,9.92);
fields.slotSettlementType.value='none';p=ctx.getCoffeeButtonPayload();m=ctx.getTelemetrySlotPayloadFromCoffeeButton(p);assert.equal(m.subsidy_billing_enabled,false);assert.equal(m.subsidy_amount_czk,0);
const fixture=ctx.renderCoffeePlanogram([],Array.from({length:24},(_,i)=>({id:i+1,machine_id:22,selection_code:String(i+1),sale_price_czk:10,customer_price_czk:i===0?0:10,product_name:'Nápoj '+(i+1)})),{id:22});
fs.writeFileSync('/tmp/coffee-preview.html',`<html><head><style>${html.match(/<style>([\s\S]*?)<\/style>/)[1]}</style></head><body>${fixture}<script>${source('refreshCoffeeSelection').split('    // With no partner')[0]}</script></body></html>`);
assert(fixture.includes('Cena nápoje 10 Kč · zákazník 0 Kč'));assert.equal((fixture.match(/data-coffee-select=/g)||[]).length,24);
console.log('PASS: explicit zero price, billing off/on preserves rate and partner, legacy billing mirror, 24 selectable choices and differing-price display');

fields.coffeeSubsidyMode.value='inherit';assert.equal(ctx.getCoffeeButtonPayload().subsidy_mode,'inherit');
fields.coffeeSubsidyMode.value='none';assert.equal(ctx.getCoffeeButtonPayload().subsidy_mode,'none');
assert(html.includes('getTelemetrySlotPayloadFromCoffeeButton(savedButton)'), 'Mirror must use server-resolved inherited amount');
console.log('PASS: subsidy modes survive editor payload; mirror uses authoritative saved rule');
