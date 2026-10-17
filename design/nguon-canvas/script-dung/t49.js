const { chromium } = require('playwright');
(async()=>{const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium_headless_shell-1194/chrome-linux/headless_shell'});
for (const n of ['K3','TS17','TS09']){
const p=await b.newPage({viewport:{width:1440,height:1000}});await p.route(/fonts\./,r=>r.abort());
await p.goto('http://127.0.0.1:8765/V_'+n+'.dc.html');await p.waitForTimeout(1000);
const r=await p.evaluate(()=>{const st=document.querySelector('.hmt-stage');if(!st)return null;return Array.from(st.querySelectorAll('.hmt-step')).slice(0,3).map(x=>{const c=getComputedStyle(x);return [x.innerText.trim().slice(0,12),c.backgroundColor,c.color,c.fontWeight,c.height,x.getAttribute('aria-current')||'',x.className]})});
console.log(n,JSON.stringify(r));
const el=await p.$('.hmt-stage');if(el) await el.screenshot({path:'scripts/k1i/stage_'+n+'.png'});}
await b.close();})();
