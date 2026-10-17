const { chromium } = require('playwright');
(async()=>{const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium_headless_shell-1194/chrome-linux/headless_shell'});
for (const n of ['TS16b','TS16c','TS16']){
const p=await b.newPage({viewport:{width:1440,height:1000}});const er=[];p.on('pageerror',e=>er.push(e.message));await p.route(/fonts\./,r=>r.abort());
await p.goto('http://127.0.0.1:8765/V_'+n+'.dc.html');await p.waitForTimeout(1200);
await p.screenshot({path:'scripts/k1i/'+n+'.png'});console.log(n,er);}
await b.close();})();
