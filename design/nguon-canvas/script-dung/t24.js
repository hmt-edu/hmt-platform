const { chromium } = require('playwright');
(async()=>{
 const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium_headless_shell-1194/chrome-linux/headless_shell'});
 for (const n of ['TS11br','TS11cr','TS11_K5r']) {
 const p=await b.newPage({viewport:{width:1440,height:1000}}); const errs=[]; p.on('pageerror',e=>errs.push(e.message));
 await p.route(/fonts\.(googleapis|gstatic)\.com/,r=>r.abort());
 await p.goto('http://127.0.0.1:8765/'+n+'.dc.html',{waitUntil:'load'}); await p.waitForTimeout(900);
 const st=()=>p.evaluate(()=>({chips:Array.from(document.querySelectorAll('.ix-chiprow .hmt-chip')).map(e=>e.textContent.trim()),per:document.querySelector('.ix-tper')?.textContent.trim(),ovd:(()=>{const e=document.querySelector('.ix-ovd');return e&&e.style.display!=='none'?e.textContent.trim():null})(),rows:Array.from(document.querySelectorAll('tbody tr')).filter(r=>!r.classList.contains('ghead')&&r.style.display!=='none').length,cards:document.querySelectorAll('.hmt-kcard').length,evs:document.querySelectorAll('.hmt-ev:not(.ix-off)').length}));
 console.log(n,JSON.stringify(await st()));
 await p.screenshot({path:'k1i/def_'+n+'.png',clip:{x:236,y:52,width:1204,height:330}});
 if(await p.$('.ix-ovd button')&&await p.$eval('.ix-ovd',e=>e.style.display!=='none')){ await p.click('.ix-ovd button'); await p.waitForTimeout(250); console.log(' after Xem',JSON.stringify(await st())); }
 else { await p.click('.ix-chiprow .hmt-chip:has-text("Thời gian") button'); await p.waitForTimeout(250); console.log(' after chip x',JSON.stringify(await st())); }
 console.log(' ERR',errs); await p.close(); }
 await b.close();})();
