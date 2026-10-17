const { chromium } = require('playwright');
(async()=>{
 const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium_headless_shell-1194/chrome-linux/headless_shell'});
 const errs=[]; const mk=async f=>{const p=await b.newPage({viewport:{width:1440,height:1000}}); p.on('pageerror',e=>errs.push(f+': '+e.message)); await p.route(/fonts\.(googleapis|gstatic)\.com/,r=>r.abort()); await p.goto('http://127.0.0.1:8765/'+f,{waitUntil:'load'}); await p.waitForTimeout(900); return p;};
 // LIST
 let p=await mk('TS11bU.dc.html');
 const st=()=>p.evaluate(()=>Array.from(document.querySelectorAll('tbody tr:not(.ghead)')).filter(r=>r.offsetParent).slice(0,3).map(r=>r.children[6].innerText.trim()+'|'+r.children[7].innerText.trim().replace(/\s+/g,'/')));
 console.log('list0',await st());
 await p.click('tbody tr:not(.ghead):visible >> nth=0 >> button:has-text("Hoàn thành")');
 await p.waitForTimeout(200); console.log('after done',await st(), await p.textContent('.ix-toast'));
 await p.click('.ix-toast button'); await p.waitForTimeout(200); console.log('after undo',await st());
 await p.click('tbody tr:not(.ghead):visible >> nth=0 >> button:has-text("Huỷ")'); await p.waitForTimeout(200);
 console.log('dlg',await p.evaluate(()=>!!document.querySelector('.ix-ap')));
 await p.click('.ix-ap button[data-a=ok]'); console.log('err',await p.evaluate(()=>!!document.querySelector('.ix-ap .ix-err')));
 await p.click('.ix-ap .hmt-pills button >> nth=0'); await p.click('.ix-ap button[data-a=ok]'); await p.waitForTimeout(200);
 console.log('after huy',await st());
 await p.click('tbody tr:not(.ghead):visible >> nth=0 >> button:has-text("Mở lại")'); await p.waitForTimeout(200); console.log('after reopen',await st());
 await p.click('tbody tr:not(.ghead):visible >> nth=0 >> td:nth-child(3) a'); await p.waitForTimeout(200); console.log('detail log',await p.evaluate(()=>document.querySelector('.ix-ev').innerText.replace(/\s+/g,' ').slice(-260)));
 await p.screenshot({path:'scripts/k1i/u1.png'});
 // KANBAN
 p=await mk('TS11cU.dc.html');
 console.log('kan cols',await p.evaluate(()=>Array.from(document.querySelectorAll('.hmt-kcol')).map(c=>c.getAttribute('data-st')+':'+c.querySelectorAll('.hmt-kcard').length+' reopen:'+c.querySelectorAll('[data-act="Mở lại"]').length)));
 await p.click('.hmt-kcol[data-st="Huỷ"] [data-act="Mở lại"] >> nth=0'); await p.waitForTimeout(250);
 console.log('after reopen',await p.evaluate(()=>Array.from(document.querySelectorAll('.hmt-kcol')).map(c=>c.getAttribute('data-st')+':'+c.querySelectorAll('.hmt-kcard').length)));
 await p.click('.hmt-kcol[data-st="Chưa làm"] [data-act="Hoàn thành"] >> nth=0'); await p.waitForTimeout(250);
 console.log('after done',await p.evaluate(()=>Array.from(document.querySelectorAll('.hmt-kcol')).map(c=>c.getAttribute('data-st')+':'+c.querySelectorAll('.hmt-kcard').length)), await p.textContent('.ix-toast'));
 await p.screenshot({path:'scripts/k1i/u2.png'});
 // K5
 p=await mk('K5U.dc.html');
 const evs=await p.evaluate(()=>Array.from(document.querySelectorAll('.hmt-ev')).filter(e=>e.offsetParent).map(e=>e.className+'|'+(e.getAttribute('title')||'').slice(0,30)));
 console.log('k5 evs',evs.length, evs.filter(x=>/done|cancel/.test(x)).slice(0,2));
 await p.click('.hmt-ev.hmt-ev-done:visible >> nth=0',{timeout:4000}).catch(e=>console.log('no done ev')); await p.waitForTimeout(200);
 console.log('menu done',await p.evaluate(()=>{const m=document.querySelector('.hmt-calv .hmt-menu');return m.style.display+'|'+Array.from(m.querySelectorAll('button')).filter(b=>b.offsetParent).map(b=>b.innerText.trim()).join(',')}));
 await p.click('.hmt-calv .hmt-menu >> text=Mở lại lịch hẹn'); await p.waitForTimeout(250);
 console.log('after reopen evs',await p.evaluate(()=>Array.from(document.querySelectorAll('.hmt-ev')).filter(e=>e.offsetParent).filter(e=>/done|cancel/.test(e.className)).length));
 await p.screenshot({path:'scripts/k1i/u3.png'});
 console.log(errs); await b.close();})();
