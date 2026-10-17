const { chromium } = require('playwright');
(async()=>{
 const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium_headless_shell-1194/chrome-linux/headless_shell'});
 const p=await b.newPage({viewport:{width:1440,height:1000}}); const errs=[]; p.on('pageerror',e=>errs.push(e.message));
 await p.route(/fonts\.(googleapis|gstatic)\.com/,r=>r.abort());
 await p.goto('http://127.0.0.1:8765/TS11_K5r.dc.html',{waitUntil:'load'}); await p.waitForTimeout(900);
 const vis=()=>p.evaluate(()=>document.querySelectorAll('.hmt-ev:not(.ix-off)').length);
 console.log('start',await vis(), await p.evaluate(()=>Array.from(document.querySelectorAll('.ix-chiprow .hmt-chip')).map(e=>e.textContent.trim())));
 await p.screenshot({path:'k1i/k5n_a.png'});
 await p.click('.hmt-toolbar >> text=Filters'); await p.waitForTimeout(250); await p.screenshot({path:'k1i/k5n_b.png'});
 console.log('ERR',errs); await b.close();})();
