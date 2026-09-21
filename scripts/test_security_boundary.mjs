import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

for (const name of fs.readdirSync('.').filter(name => name.endsWith('.html'))) {
  for (const script of fs.readFileSync(name,'utf8').matchAll(/<script[^>]*>([\s\S]*?)<\/script>/g)) new vm.SourceTextModule(script[1]);
}
for (const name of ['supabase.js','secure-files.js']) new vm.SourceTextModule(fs.readFileSync(name,'utf8'));
const {privateStoragePath,installPrivateFileLinks}=await import('../secure-files.js');
const origin='https://example.supabase.co';
assert.deepEqual(privateStoragePath(`${origin}/storage/v1/object/public/shift-documents/a%20b.pdf`,origin),{bucket:'shift-documents',path:'a b.pdf'});
assert.equal(privateStoragePath('https://attacker.test/storage/v1/object/public/shift-documents/a.pdf',origin),null);
assert.equal(privateStoragePath(`${origin}/storage/v1/object/public/payroll-payslips/a.pdf`,origin),null);
const attrs={href:`${origin}/storage/v1/object/public/shift-documents/test.pdf`};
const element={tagName:'A',nodeType:1,getAttribute:key=>attrs[key],setAttribute:(key,value)=>attrs[key]=value,querySelectorAll:()=>[]};
globalThis.document={documentElement:element};globalThis.window={setInterval:()=>{}};
globalThis.MutationObserver=class{observe(){}};
let signed=0;
installPrivateFileLinks({storage:{from:bucket=>({createSignedUrl:async(path,seconds)=>{signed++;assert.equal(bucket,'shift-documents');assert.equal(path,'test.pdf');assert.equal(seconds,600);return {data:{signedUrl:'https://signed.test/file'}}}})}},origin);
await new Promise(resolve=>setTimeout(resolve,0));assert.equal(attrs.href,'https://signed.test/file');assert.equal(signed,1);
const html=fs.readFileSync('machine-qr.html','utf8');
const start=html.indexOf('async function loadMachineByQr('),end=html.indexOf('async function submitPublicRequest',start);
const context=vm.createContext({supabase:{rpc:async()=>({data:{machine:{id:58},location:{name:'Test'}}}),from:()=>{throw Error('Anonymous QR must not read tables')}},session:null,machine:null,location:null,openRequests:[]});
vm.runInContext(html.slice(start,end),context);
await context.loadMachineByQr('test-token');assert.equal(context.machine.id,58);assert.equal(context.openRequests.length,0);
for (const test of [{session:null,active:false,redirect:true},{session:{user:{id:'test'}},active:false,redirect:true},{session:{user:{id:'test'}},active:true,redirect:false}]) {
  let redirect=null;
  const client={auth:{getSession:async()=>({data:{session:test.session}}),signOut:async()=>({})},rpc:async()=>({data:test.active})};
  const sandbox=vm.createContext({window:{location:{pathname:'/machines.html',replace:url=>{redirect=url}},setTimeout:()=>{}}});
  const module=new vm.SourceTextModule(fs.readFileSync('supabase.js','utf8'),{context:sandbox});
  await module.link(specifier => specifier.includes('supabase-js')
    ? new vm.SyntheticModule(['createClient'],function(){this.setExport('createClient',()=>client)},{context:sandbox})
    : new vm.SyntheticModule(['installPrivateFileLinks'],function(){this.setExport('installPrivateFileLinks',()=>{})},{context:sandbox}));
  if(test.redirect)await assert.rejects(module.evaluate());else await module.evaluate();
  assert.equal(redirect,test.redirect?'index.html':null);
}
console.log('PASS: application syntax, private file origin/path handling and signed links, anonymous QR uses restricted RPC only');

await import('./test_password_recovery.mjs');

await import('./test_technician_open_services.mjs');
await import('./test_technician_service_preview.mjs');
