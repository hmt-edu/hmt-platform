const { chromium } = require('playwright');
(async()=>{
 const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium_headless_shell-1194/chrome-linux/headless_shell'});
 const p=await b.newPage({viewport:{width:1440,height:1000}}); await p.route(/fonts\.(googleapis|gstatic)\.com/,r=>r.abort());
 await p.goto('http://127.0.0.1:8765/V_TS15.dc.html',{waitUntil:'load'}); await p.waitForTimeout(900);
 await p.click('#hs-add');
 await p.evaluate(()=>{const d=Object.getOwnPropertyDescriptor(HTMLInputElement.prototype,'value');window.__s=[];Object.defineProperty(HTMLInputElement.prototype,'value',{get(){return d.get.call(this)},set(v){if(this.id==='hs-name')window.__s.push(String(v)+' @ '+new Error().stack.split('\n').slice(2,5).join(' | '));d.set.call(this,v)}});
  const n=document.querySelector('#hs-name'); new MutationObserver(m=>window.__s.push('mut '+m.map(x=>x.type+x.attributeName).join())).observe(n,{attributes:true});
  new MutationObserver(m=>window.__s.push('parent mut '+m.length)).observe(n.parentElement,{childList:true});});
 await p.click('#hs-name'); await p.keyboard.type('Ba');
 console.log(await p.evaluate(()=>window.__s.join('\n')), await p.evaluate(()=>[document.querySelector('#hs-name').value, document.querySelector('#hs-name').className, document.activeElement.id]));
 await b.close();})();
