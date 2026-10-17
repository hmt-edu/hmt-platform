const { chromium } = require('playwright');
(async()=>{
 const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium_headless_shell-1194/chrome-linux/headless_shell'});
 const p=await b.newPage({viewport:{width:1440,height:1000}}); const errs=[]; p.on('pageerror',e=>errs.push(e.message));
 await p.route(/fonts\.(googleapis|gstatic)\.com/,r=>r.abort());
 await p.goto('http://127.0.0.1:8765/TS13r.dc.html',{waitUntil:'load'}); await p.waitForTimeout(900);
 console.log('dialog',await p.evaluate(()=>Array.from(document.querySelectorAll('.hmt-dialog')).filter(d=>d.offsetParent).map(d=>d.getAttribute('aria-label')+'|'+d.innerText.replace(/\s+/g,' ').slice(0,120))));
 await p.keyboard.press('Escape'); await p.click('.hmt-dialog:visible button:has-text("Huỷ"), .hmt-dialog:visible [aria-label=Đóng]',{timeout:3000}).catch(()=>{}); await p.waitForTimeout(300);
 console.log('scrim visible',await p.evaluate(()=>Array.from(document.querySelectorAll('.hmt-scrim')).filter(d=>d.offsetParent&&getComputedStyle(d).display!=='none').length));
 await p.click('a[data-gw]:visible >> nth=0',{timeout:5000}).then(async()=>console.log(await p.textContent('.ix-toast'))).catch(e=>console.log('click fail'));
 await p.click('tbody tr:not(.ghead) td:nth-child(3) a:visible >> nth=0',{timeout:5000}).then(async()=>{await p.waitForTimeout(200);console.log('detail',await p.evaluate(()=>!!document.querySelector('.ix-ev')))}).catch(e=>console.log('click2 fail'));
 console.log(errs); await b.close();})();
