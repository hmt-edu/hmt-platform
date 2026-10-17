const { chromium } = require('playwright');
(async()=>{
 const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium_headless_shell-1194/chrome-linux/headless_shell'});
 const p=await b.newPage({viewport:{width:1440,height:1000}});
 const errs=[]; p.on('pageerror',e=>errs.push(e.message));
 await p.route(/fonts\.(googleapis|gstatic)\.com/,r=>r.abort());
 await p.goto('http://127.0.0.1:8765/TS11br.dc.html',{waitUntil:'load'}); await p.waitForTimeout(800);
 console.log('links',await p.evaluate(()=>document.querySelectorAll('a[data-gw]').length));
 await p.click('a[data-gw] >> nth=0'); console.log('toast',await p.textContent('.ix-toast'));
 await p.click('tbody tr:not(.ghead) td:nth-child(3) a >> nth=0'); await p.waitForTimeout(200);
 await p.screenshot({path:'k1i/ev_a.png'});
 await p.click('.ix-ev >> text=/^Mở cơ hội/'); console.log('toast2',await p.textContent('.ix-toast'), await p.evaluate(()=>!!document.querySelector('.ix-ev')));
 await p.click('tbody tr:not(.ghead) td:nth-child(3) a >> nth=1'); await p.keyboard.press('Escape'); console.log('esc closed',await p.evaluate(()=>!document.querySelector('.ix-ev')));
 await p.click('.hmt-toolbar >> text=Group By'); await p.click('.ix-pop >> text=Loại hoạt động'); await p.waitForTimeout(300);
 console.log('after group',await p.evaluate(()=>document.querySelectorAll('a[data-gw]').length));
 await p.click('a[data-gw]:visible >> nth=0'); console.log('toast3',await p.textContent('.ix-toast'));
 console.log('ERR',errs); await b.close();})();
