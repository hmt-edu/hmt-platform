const { chromium } = require('playwright');
(async()=>{
 const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium_headless_shell-1194/chrome-linux/headless_shell'});
 const p=await b.newPage({viewport:{width:1440,height:1000}});
 await p.route(/fonts\.(googleapis|gstatic)\.com/,r=>r.abort());
 await p.goto('http://127.0.0.1:8765/TS11br.dc.html',{waitUntil:'load'}); await p.waitForTimeout(800);
 await p.click('.hmt-toolbar >> text=Group By'); await p.click('.ix-pop >> text=Loại hoạt động'); await p.waitForTimeout(500);
 console.log(await p.evaluate(()=>({tables:document.querySelectorAll('table').length, gw:document.querySelectorAll('a[data-gw]').length, vis:Array.from(document.querySelectorAll('a[data-gw]')).filter(a=>a.offsetParent).length, codes:Array.from(document.querySelectorAll('.hmt-code')).filter(a=>a.offsetParent).map(a=>a.tagName).join(',') })));
 await p.keyboard.press('Escape'); await p.click('text=Gọi điện >> nth=-1').catch(()=>{}); await p.click('.ghead >> text=Gọi điện'); await p.waitForTimeout(300); console.log('vis after expand',await p.evaluate(()=>Array.from(document.querySelectorAll('a[data-gw]')).filter(a=>a.offsetParent).length)); await p.click('a[data-gw]:visible >> nth=0'); console.log(await p.textContent('.ix-toast')); await b.close();})();
