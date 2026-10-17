const { chromium } = require('playwright');
(async()=>{
 const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium_headless_shell-1194/chrome-linux/headless_shell'});
 const p=await b.newPage({viewport:{width:1440,height:1000}}); const errs=[]; p.on('pageerror',e=>errs.push(e.message));
 await p.route(/fonts\.(googleapis|gstatic)\.com/,r=>r.abort());
 await p.goto('http://127.0.0.1:8765/TS11cr.dc.html',{waitUntil:'load'}); await p.waitForTimeout(900);
 const cols=()=>p.evaluate(()=>Array.from(document.querySelectorAll('.hmt-kcol')).map(c=>c.getAttribute('data-st')+':'+c.querySelectorAll('.hmt-kcard').length).join(' '));
 console.log(await cols());
 await p.screenshot({path:'k1i/k11d_a.png',clip:{x:236,y:200,width:1204,height:500}});
 await p.click('.hmt-kcard button[data-act=Dời] >> nth=0'); await p.waitForTimeout(300);
 console.log('doi dlg',await p.evaluate(()=>{const d=document.querySelector('.hmt-dialog');return d?d.getAttribute('aria-label')+'|'+d.innerText.replace(/\s+/g,' ').slice(0,160):'none; toast='+document.querySelector('.ix-toast')?.textContent}));
 await p.screenshot({path:'k1i/k11d_b.png'});
 await p.keyboard.press('Escape'); await p.evaluate(()=>{const d=document.querySelector('.hmt-scrim');d&&d.querySelector('button')&&d.querySelector('button').click()}); await p.waitForTimeout(200);
 await p.click('.hmt-kcard button[data-act="Hoàn thành"] >> nth=0'); await p.waitForTimeout(300); console.log('after Hoàn thành',await cols(), await p.evaluate(()=>document.querySelector('.ix-toast')?.textContent));
 await p.click('.hmt-kcard a[data-ttl] >> nth=1'); await p.waitForTimeout(200); console.log('detail btns',await p.evaluate(()=>Array.from(document.querySelectorAll('.ix-ev .hmt-dialog-f button')).map(b=>b.textContent.trim()).join('|')));
 await p.click('.ix-ev button[data-l="Dời"]'); await p.waitForTimeout(300); console.log('doi from detail',await p.evaluate(()=>{const d=document.querySelector('.hmt-dialog');return d?d.getAttribute('aria-label'):'none'}));
 console.log(errs); await b.close();})();
