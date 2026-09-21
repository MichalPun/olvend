import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
const html = fs.readFileSync('index.html', 'utf8');
const code = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)][0][1];
async function setup({hash='', stored=null, user={id:'fixture-user',email:'fixture@example.test'}, importFails=false, updateFails=false}={}) {
  const elements = new Map();
  const el = id => {
    if (!elements.has(id)) elements.set(id,{value:'',classList:{add(){}},style:{},textContent:'',disabled:false,checked:true,handlers:{},addEventListener(type,fn){this.handlers[type]=fn},reportValidity(){return !!this.value},reset(){this.resetCalled=true}});
    return elements.get(id);
  };
  const calls=[]; const storage=new Map(stored ? [['olvendPasswordRecoveryUser',stored]] : []);
  const location={hash,search:'',pathname:'/index.html',href:'https://olvend.onrender.com/index.html'+hash};
  const client={auth:{
    getSession:async()=>({data:{session:user?{user}:null}}),
    getUser:async()=>({data:{user},error:user?null:new Error('expired')}),
    onAuthStateChange:fn=>{calls.authEvent=fn},
    updateUser:async payload=>{calls.push(['update',payload]);return {error:updateFails?new Error('denied'):null}},
    signOut:async()=>{calls.push(['signOut']);return {}},
    resetPasswordForEmail:async(email,options)=>{calls.push(['reset',email,options]);return {}},
    signInWithPassword:async()=>({data:{user}})
  },from:()=>({select:()=>({eq:()=>({eq:()=>({maybeSingle:async()=>({data:{id:1,role:'operator'}})})})})})};
  const context=vm.createContext({URL,URLSearchParams,console,document:{getElementById:el},
    sessionStorage:{getItem:k=>storage.get(k)||null,setItem:(k,v)=>storage.set(k,v),removeItem:k=>storage.delete(k)},
    localStorage:{setItem:()=>{},removeItem:()=>{}},
    window:{location,history:{replaceState:()=>{calls.push(['cleanURL'])}},setTimeout:()=>0,clearTimeout:()=>{}},
    FormData:class{get(k){return el(k).value}}});
  const mod=new vm.SyntheticModule(['supabase'],function(){this.setExport('supabase',client)},{context});
  await mod.link(()=>{}); await mod.evaluate();
  await new vm.Script(code,{importModuleDynamically:async()=>{if(importFails)throw Error('network');return mod}}).runInContext(context);
  return {el,calls,storage,location};
}
let t=await setup({hash:'#type=recovery&access_token=fixture-not-a-real-token'});
assert.equal(t.el('recoveryForm').style.display,'grid');
assert.equal(t.el('savePasswordBtn').disabled,false);
assert.equal(t.location.href.includes('mobile.html'),false,'Recovery must not redirect to mobile');
assert.equal(t.el('recoveryEmail').textContent,'fixture@example.test');
t.el('newPassword').value='fixture-only-password';t.el('confirmPassword').value='mismatch';
await t.el('recoveryForm').handlers.submit({preventDefault(){}});
assert.equal(t.calls.filter(c=>c[0]==='update').length,0);
t.el('confirmPassword').value='fixture-only-password';
await t.el('recoveryForm').handlers.submit({preventDefault(){}});
assert.equal(t.calls.filter(c=>c[0]==='update').length,1);
assert.equal(t.storage.size,0);assert.equal(t.el('recoveryForm').resetCalled,true);
assert.match(t.el('statusLine').textContent,/Heslo je změněné/);
for(const opts of [{hash:'#type=recovery',user:null},{stored:'different-user'}]){
 t=await setup(opts);assert.equal(t.el('savePasswordBtn').disabled,true);assert.match(t.el('statusLine').textContent,/Odkaz není platný/);
}
t=await setup({stored:'fixture-user'});assert.equal(t.el('recoveryForm').style.display,'grid','Reload resumes recovery');
t=await setup({hash:'#error=access_denied&error_code=otp_expired'});assert.match(t.el('statusLine').textContent,/Odkaz není platný/);assert.ok(!t.location.href.includes('mobile.html'));
t=await setup({importFails:true});assert.match(t.el('statusLine').textContent,/nepodařilo načíst/);
t=await setup({user:null});t.el('email').value='fixture@example.test';await t.el('forgotPasswordBtn').handlers.click();
assert.equal(t.calls[0][0],'reset');assert.equal(t.calls[0][2].redirectTo,'https://olvend.onrender.com/index.html');
t=await setup();assert.equal(t.location.href,'mobile.html','Normal login redirect preserved');
t=await setup({hash:'#type=recovery',updateFails:true});t.el('newPassword').value=t.el('confirmPassword').value='fixture-only-password';await t.el('recoveryForm').handlers.submit({preventDefault(){}});assert.match(t.el('statusLine').textContent,/nepodařilo uložit/);assert.equal(t.el('savePasswordBtn').disabled,false);
console.log('PASS: recovery routing, expired links, identity binding, refresh, password validation/save failures, email redirect, unavailable scripts, normal login');
