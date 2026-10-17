const { chromium } = require('playwright');
(async()=>{
 const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium_headless_shell-1194/chrome-linux/headless_shell'});
 const p=await b.newPage({viewport:{width:1440,height:1000}}); const errs=[]; p.on('pageerror',e=>errs.push(e.message));
 await p.route(/fonts\.(googleapis|gstatic)\.com/,r=>r.abort());
 await p.goto('http://127.0.0.1:8765/TS11cr.dc.html',{waitUntil:'load'}); await p.waitForTimeout(900);
 const cols=()=>p.evaluate(()=>Array.from(document.querySelectorAll('.hmt-kcol')).map(c=>c.getAttribute('data-st')+':'+c.querySelectorAll('.hmt-kcard').length).join(' '));
 console.log('init',await cols());
 await p.click('.hmt-kbar i.bad'); await p.waitForTimeout(250); console.log('bad',await cols(), await p.evaluate(()=>document.querySelector('.hmt-facets, .ix-chiprow')?.innerText.replace(/\s+/g,' ')));
 await p.screenshot({path:'k1i/k11c_c.png',clip:{x:236,y:52,width:1204,height:420}});
 console.log('ERR',errs); await b.close();})();
