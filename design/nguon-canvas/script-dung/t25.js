const { chromium } = require('playwright');
(async()=>{
 const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium_headless_shell-1194/chrome-linux/headless_shell'});
 const p=await b.newPage({viewport:{width:1440,height:1000}}); const errs=[]; p.on('pageerror',e=>errs.push(e.message));
 await p.route(/fonts\.(googleapis|gstatic)\.com/,r=>r.abort());
 await p.goto('http://127.0.0.1:8765/TS11br.dc.html',{waitUntil:'load'}); await p.waitForTimeout(800);
 await p.click('tbody tr:not(.ghead) >> nth=0 >> text=Dời'); await p.waitForTimeout(300);
 console.log(await p.evaluate(()=>{const d=document.querySelector('.hmt-dialog');return d?d.getAttribute('aria-label')+'|'+d.innerText.replace(/\s+/g,' ').slice(0,200):'none'}), await p.evaluate(()=>document.querySelector('.ix-toast')?.textContent));
 await p.screenshot({path:'k1i/doi.png'}); console.log(errs); await b.close();})();
