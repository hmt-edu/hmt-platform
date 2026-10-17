const { chromium } = require('playwright');
(async()=>{
 const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium_headless_shell-1194/chrome-linux/headless_shell'});
 const p=await b.newPage({viewport:{width:1440,height:1000}}); await p.route(/fonts\.(googleapis|gstatic)\.com/,r=>r.abort());
 await p.goto('http://127.0.0.1:8765/V_TS15.dc.html',{waitUntil:'load'}); await p.waitForTimeout(900);
 const g=()=>p.evaluate(()=>{const n=document.querySelector('#hs-name');return [n.value,n.readOnly,document.querySelectorAll('#hs-name').length]});
 await p.click('#hs-add'); console.log('1',await g()); await p.waitForTimeout(400); console.log('2',await g());
 await p.evaluate(()=>{window.__l=[];const n=document.querySelector('#hs-name');['focus','input','change','click','blur'].forEach(t=>n.addEventListener(t,e=>window.__l.push(t+':'+n.value)));});
 await p.click('#hs-name'); console.log('3',await g()); await p.keyboard.type('Ba'); console.log('4',await g(), await p.evaluate(()=>window.__l));
 await b.close();})();
