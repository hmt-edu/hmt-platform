const { chromium } = require('playwright');
(async()=>{const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium_headless_shell-1194/chrome-linux/headless_shell'});
const p=await b.newPage({viewport:{width:1440,height:1000}});const er=[];p.on('pageerror',e=>er.push(e.message));await p.route(/fonts\./,r=>r.abort());
await p.goto('http://127.0.0.1:8765/V_TS16.dc.html');await p.waitForTimeout(900);
await p.screenshot({path:'scripts/k1i/t16a.png'});

console.log('mine rows',await p.$$eval('tbody tr',r=>r.filter(x=>x.style.display!=='none').length));

const gb=p.locator('button:has-text("Group By"), button:has-text("Nhóm")').first();console.log(await gb.count());
console.log(er);await b.close();})();
