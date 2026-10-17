const { chromium } = require('playwright');
(async()=>{const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium_headless_shell-1194/chrome-linux/headless_shell'});
const p=await b.newPage({viewport:{width:1440,height:1000}});await p.route(/fonts\./,r=>r.abort());
await p.goto('http://127.0.0.1:8765/V_TS17.dc.html');await p.waitForTimeout(900);
console.log(await p.$$eval('.hmt-rbar-l > button',x=>x.map(b=>b.innerText.trim())));
await p.click('.hmt-rbar-l > button:has-text("Sửa")');await p.waitForTimeout(200);
console.log(await p.$$eval('.hmt-rbar-l > button',x=>x.map(b=>b.innerText.trim())), await p.$$eval('.hmt-sbtn b',x=>x.map(b=>b.innerText)));
await p.screenshot({path:'scripts/k1i/t17d.png'});await b.close();})();
