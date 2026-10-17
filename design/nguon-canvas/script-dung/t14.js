const { chromium } = require('playwright');
(async()=>{
 const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium_headless_shell-1194/chrome-linux/headless_shell'});
 const p=await b.newPage({viewport:{width:1440,height:1000}}); const errs=[]; p.on('pageerror',e=>errs.push(e.message));
 await p.route(/fonts\.(googleapis|gstatic)\.com/,r=>r.abort());
 await p.goto('http://127.0.0.1:8765/TS11_K5r.dc.html',{waitUntil:'load'}); await p.waitForTimeout(800);
 await p.click('.hmt-ev-meet >> nth=0'); await p.waitForTimeout(200); await p.screenshot({path:'k1i/k5_c.png'});
 await p.click('.hmt-menu [data-open]'); console.log(await p.textContent('.ix-toast'));
 await p.click('.hmt-ev-email >> nth=0'); await p.click('.hmt-menu >> text=Hoàn thành'); console.log('done',await p.evaluate(()=>document.querySelectorAll('.hmt-ev-done').length), errs); await b.close();})();
