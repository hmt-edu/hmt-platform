const { chromium } = require('playwright');
(async()=>{const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium_headless_shell-1194/chrome-linux/headless_shell'});
const p=await b.newPage({viewport:{width:1440,height:1000}});const er=[];p.on('pageerror',e=>er.push(e.message));await p.route(/fonts\./,r=>r.abort());
await p.goto('http://127.0.0.1:8765/V_TS15.dc.html');await p.waitForTimeout(900);
const btn=p.locator('.hmt-field:has(label:text-is("Người phụ trách")) button');await btn.click();
console.log(await p.$$eval('.ix-pop .hmt-opt',x=>x.map(a=>a.innerText)));await p.click('.ix-pop .hmt-opt >> nth=1');
console.log(await btn.innerText(),er);await p.screenshot({path:'scripts/k1i/t15g.png'});await b.close();})();
