const { chromium } = require('playwright');
(async()=>{const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium_headless_shell-1194/chrome-linux/headless_shell'});
const p=await b.newPage({viewport:{width:1440,height:1000}});await p.route(/fonts\./,r=>r.abort());
await p.goto('http://127.0.0.1:8765/V_TS17.dc.html');await p.waitForTimeout(900);
await p.click('[aria-label="Nút nghiệp vụ và Sub-stage"] button:has-text("Bắt đầu test")');await p.click('[aria-label="Nút nghiệp vụ và Sub-stage"] button:has-text("Nộp bài")');await p.waitForTimeout(200);
console.log(JSON.stringify(await p.$$eval('.hmt-step',xs=>xs.map(x=>{const c=getComputedStyle(x);return [x.innerText.trim(),c.backgroundColor,c.color,c.fontWeight]}))));
await (await p.$('.hmt-stage')).screenshot({path:'scripts/k1i/stage_TS17b.png'});await b.close();})();
