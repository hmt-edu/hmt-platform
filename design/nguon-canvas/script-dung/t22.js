const { chromium } = require('playwright');
(async()=>{
 const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium_headless_shell-1194/chrome-linux/headless_shell'});
 const p=await b.newPage({viewport:{width:1440,height:1000}}); const errs=[]; p.on('pageerror',e=>errs.push(e.message));
 await p.route(/fonts\.(googleapis|gstatic)\.com/,r=>r.abort());
 await p.goto('http://127.0.0.1:8765/TS11cr.dc.html',{waitUntil:'load'}); await p.waitForTimeout(900);
 const cols=()=>p.evaluate(()=>Array.from(document.querySelectorAll('.hmt-kcol')).map(c=>c.getAttribute('data-st')+':'+c.querySelectorAll('.hmt-kcard').length));
 console.log('cols',await cols(), await p.evaluate(()=>Array.from(document.querySelectorAll('.ix-chiprow .hmt-chip')).map(e=>e.textContent.trim())));
 await p.screenshot({path:'k1i/k11c_a.png'});
 await p.click('.hmt-kbar i.bad'); await p.waitForTimeout(250); console.log('after bar bad',await cols(), await p.evaluate(()=>Array.from(document.querySelectorAll('.ix-chiprow .hmt-chip')).map(e=>e.textContent.trim())));
 await p.click('.ix-chiprow >> text=Xoá lọc'); await p.waitForTimeout(250);
 // drag first Chưa làm card to Hoàn thành
 const card=p.locator('.hmt-kcol[data-st="Chưa làm"] .hmt-kcard').first(); const tgt=p.locator('.hmt-kcol[data-st="Hoàn thành"]');
 await card.dragTo(tgt); await p.waitForTimeout(250); console.log('dialog',await p.evaluate(()=>!!document.querySelector('.ix-kd')));
 await p.click('.ix-kd >> text=/^Hoàn thành$/ >> nth=-1'); await p.waitForTimeout(150); console.log('empty-err',await p.evaluate(()=>!!document.querySelector('.ix-kd .ix-err')));
 await p.fill('.ix-kd textarea','PH đồng ý'); await p.click('.ix-kd button[data-a=ok]'); await p.waitForTimeout(300); console.log('after done',await cols());
 await p.screenshot({path:'k1i/k11c_b.png'});
 await p.locator('.hmt-kcol[data-st="Hoàn thành"] .hmt-kcard').first().dragTo(p.locator('.hmt-kcol[data-st="Huỷ"]')); await p.waitForTimeout(200); console.log('toast',await p.textContent('.ix-toast'));
 await p.click('.hmt-kcard a[data-ttl] >> nth=0'); await p.waitForTimeout(200); console.log('detail',await p.evaluate(()=>!!document.querySelector('.ix-ev')));
 await p.keyboard.press('Escape');
 await p.click('.hmt-toolbar >> text=Filters'); await p.waitForTimeout(150); console.log('filters',await p.evaluate(()=>!!document.querySelector('.ix-pop'))); await p.keyboard.press('Escape');
 console.log('ERR',errs);
 for (const n of ['TS11br','TS11_K5r']) { const q2=await b.newPage({viewport:{width:1440,height:1000}}); q2.on('pageerror',e=>errs.push(n+e.message)); await q2.route(/fonts\.(googleapis|gstatic)\.com/,r=>r.abort()); await q2.goto('http://127.0.0.1:8765/'+n+'.dc.html',{waitUntil:'load'}); await q2.waitForTimeout(700); console.log(n, await q2.evaluate(()=>Array.from(document.querySelectorAll('.hmt-seg-ic button')).map(b=>b.getAttribute('aria-label')+(b.getAttribute('aria-pressed')==='true'?'*':'')).join(','))); await q2.click('[aria-label=Kanban]'); console.log(await q2.textContent('.ix-toast')); }
 console.log('ERR2',errs); await b.close();})();
