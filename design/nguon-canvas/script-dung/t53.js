const { chromium } = require('playwright');
(async()=>{const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium_headless_shell-1194/chrome-linux/headless_shell'});
for (const n of ['K3','TS02','TS17']){
const p=await b.newPage({viewport:{width:1440,height:1000}});await p.route(/fonts\./,r=>r.abort());
await p.goto('http://127.0.0.1:8765/V_'+n+'.dc.html');await p.waitForTimeout(1000);
await p.screenshot({path:'scripts/k1i/full_'+n+'.png',clip:{x:236,y:50,width:800,height:330}});}
await b.close();})();
