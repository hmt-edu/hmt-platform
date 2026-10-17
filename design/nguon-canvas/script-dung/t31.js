const { chromium } = require('playwright');
(async()=>{
 const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium_headless_shell-1194/chrome-linux/headless_shell'});
 const errs=[]; const mk=async f=>{const p=await b.newPage({viewport:{width:1440,height:1000}}); p.on('pageerror',e=>errs.push(f+': '+e.message)); await p.route(/fonts\.(googleapis|gstatic)\.com/,r=>r.abort()); await p.goto('http://127.0.0.1:8765/'+f,{waitUntil:'load'}); await p.waitForTimeout(800); return p;};
 for (const n of ['TS01','TS01b','TS03','TS06','TS07_K1','TS09','TS13','TS15','TS16','TS17']) { const p=await mk('V_'+n+'.dc.html'); await p.close(); }
 console.log('load errs',errs);
 // K3
 let p=await mk('V_K3.dc.html');
 const acts=()=>p.evaluate(()=>Array.from(document.querySelectorAll('.hmt-act')).map(a=>a.innerText.replace(/\s+/g,' ').slice(0,110)));
 console.log(await acts());
 await p.click('.hmt-act >> nth=0 >> button:has-text("Hoàn thành")'); await p.waitForTimeout(200); console.log('done',await acts(), await p.textContent('[role=status]'));
 await p.click('[role=status] button'); await p.waitForTimeout(200); console.log('undo',await acts());
 await p.click('.hmt-act >> nth=0 >> button:has-text("Huỷ")'); await p.waitForTimeout(200); console.log('ask',await acts());
 await p.click('.hmt-act >> nth=0 >> button:has-text("PH báo bận")'); await p.waitForTimeout(200); console.log('huy',await acts());
 await p.screenshot({path:'scripts/k1i/u4.png'});
 await p.click('.hmt-act >> nth=0 >> button:has-text("Mở lại")'); await p.waitForTimeout(200); console.log('reopen',await acts(), await p.evaluate(()=>document.querySelector('.hmt-csec-t')&&Array.from(document.querySelectorAll('.hmt-csec-t')).map(e=>e.innerText).join('|')));
 // TS02
 p=await mk('V_TS02.dc.html');
 const a2=()=>p.evaluate(()=>Array.from(document.querySelectorAll('.hmt-act')).map(a=>a.innerText.replace(/\s+/g,' ').slice(0,100)));
 console.log('TS02',await a2());
 await p.click('.hmt-act >> nth=0 >> button:has-text("Hoàn thành")'); await p.waitForTimeout(200); console.log(await a2(), await p.textContent('.ix-toast'));
 await p.click('.ix-toast button'); await p.waitForTimeout(200); console.log('undo',await a2());
 await p.click('.hmt-act >> nth=0 >> button:has-text("Huỷ")'); await p.waitForTimeout(200); await p.click('.ix-ap .hmt-pills button >> nth=1'); await p.click('.ix-ap button[data-a=ok]'); await p.waitForTimeout(200); console.log('huy',await a2());
 await p.click('.hmt-act >> nth=0 >> button:has-text("Mở lại")'); await p.waitForTimeout(200); console.log('reopen',await a2(), await p.evaluate(()=>Array.from(document.querySelectorAll('.hmt-csec-t')).map(e=>e.innerText).filter(t=>/HOẠT/.test(t))));
 console.log(errs); await b.close();})();
