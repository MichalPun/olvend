const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const html=fs.readFileSync(require('node:path').join(__dirname,'../issued-invoices.html'),'utf8');
function source(name){const re=new RegExp('    (?:async )?function '+name+'\\(');const start=html.search(re);assert(start>=0,name);const rest=html.slice(start);const end=rest.slice(5).search(/\n    (?:async )?function /);return end<0?rest:rest.slice(0,end+5);}
const ctx={console,Map,Set,Date,Number,crypto:require('node:crypto').webcrypto};
vm.createContext(ctx);
for(const name of ['normalizeText','roundMoney','normalizedPartnerProductName','partnerBillingSlotKey','externalReportDate','externalReportMonth','externalReportIso','normalizeExternalReportSelection','sha256Hex','parseExternalPartnerReport','roundingForTotal','partnerMachineLocationAt','filterPartnerTelemetryByLocation'])vm.runInContext(source(name),ctx);
(async()=>{
 const counts=[['6',12,5],['3',12,11],['14',14,16],['8',14,64],['13',14,23],['9',14,44],['18',20,101],['19',20,24],['11',14,5],['24',20,46],['10',14,7],['20',20,37],['22',20,29],['23',20,22],['21',20,18],['5',12,2],['1',12,17],['17',20,21],['2',12,2],['7',12,5],['15',14,5],['12',14,5],['4',12,6],['21',12,3],['8',15,1]];
 const headers=['ID trn.','Datum a čas','UID','Karta','Volba','Cena kon.','Příjmení','Jméno osoby'];
 const matrix=[headers];let id=0;const slots=new Map();
 for(const [selection,price,n] of counts){slots.set('1:'+selection,{product_name:'Drink '+selection,product_sku:selection});for(let i=0;i<n;i++)matrix.push([++id,'2026-09-10T10:00:00Z','terminal','card',selection,price,'Partner','']);}
 ctx.window={XLSX:{read:()=>({SheetNames:['Sheet'],Sheets:{Sheet:{}}}),utils:{sheet_to_json:()=>matrix}}};
 const setup={unitVatRate:21,partnerName:'Partner',externalReportFilter:{cardValue:'card',machineUids:{terminal:1}}};
 const file={size:100,name:'fixture.xlsx',arrayBuffer:async()=>new ArrayBuffer(0)};
 const parse=()=>ctx.parseExternalPartnerReport(file,setup,{value:'2026-09',label:'September'},{slotDetails:slots});
 const report=await parse();assert.equal(report.quantity,519);assert.equal(report.reportGrossAmount,8953);
 const gross=ctx.roundMoney(report.productBreakdown.reduce((sum,r)=>sum+r.netAmount+ctx.roundMoney(r.netAmount*.21),0));
 assert.equal(ctx.roundMoney(gross+ctx.roundingForTotal(gross,'integer')),8953);
 for(const r of report.productBreakdown){const stored=Number(r.rate.toFixed(6));assert.equal(ctx.roundMoney(r.quantity*stored),r.netAmount);}
 const oldGross=ctx.roundMoney(report.productBreakdown.reduce((sum,r)=>{const net=ctx.roundMoney(r.quantity*ctx.roundMoney(r.rate));return sum+net+ctx.roundMoney(net*.21)},0));assert.equal(Math.round(oldGross),8954);
 matrix.push(matrix[1]);await assert.rejects(parse,/duplicitní/);matrix.pop();
 const date=matrix[1][1];matrix[1][1]='2026-10-01T10:00:00Z';await assert.rejects(parse,/nepatří/);matrix[1][1]=date;
 ctx.partnerBillingMachines=[{id:66,location_id:120}];
 const transfers=[{machine_id:66,from_location_id:60,to_location_id:null,transferred_at:'2026-09-04T18:45:36Z'},{machine_id:66,from_location_id:null,to_location_id:120,transferred_at:'2026-09-13T16:13:00Z'}];
 const events=[{machine_id:66,source_event_at:'2026-09-03T12:00:00Z'},{machine_id:66,source_event_at:'2026-09-15T12:00:00Z'}];assert.equal(ctx.filterPartnerTelemetryByLocation(events,60,transfers).length,1);
 assert(html.includes('setup.billingMachineTypes.includes(machine?.machine_type)'));
 console.log('PASS: GP 519 transactions reconcile to 8953 CZK, persisted rates retain totals, duplicate/period checks and transfer boundaries preserved.');
})().catch(e=>{console.error(e);process.exit(1)});
