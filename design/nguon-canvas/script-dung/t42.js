const { chromium } = require('playwright');
(async()=>{
 const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium_headless_shell-1194/chrome-linux/headless_shell'});
 const p=await b.newPage({viewport:{width:1440,height:1000}}); await p.route(/fonts\.(googleapis|gstatic)\.com/,r=>r.abort());
 await p.goto('http://127.0.0.1:8765/V_TS15.dc.html',{waitUntil:'load'}); await p.waitForTimeout(900);
 console.log(await p.evaluate(()=>{const d=document.querySelector('.hmt-dialog');const r=d.getBoundingClientRect();return [r.top,r.height,d.scrollHeight]}));
 await p.screenshot({path:'scripts/k1i/u8.png'}); await b.close();})();
