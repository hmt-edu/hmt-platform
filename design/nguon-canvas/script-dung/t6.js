const { chromium } = require('playwright');
(async()=>{
 const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium_headless_shell-1194/chrome-linux/headless_shell'});
 const p=await b.newPage({viewport:{width:1440,height:1000}});
 const errs=[]; p.on('pageerror',e=>errs.push(e.message));
 await p.route(/fonts\.(googleapis|gstatic)\.com/,r=>r.abort());
 await p.goto('http://127.0.0.1:8765/TS07K1t.dc.html',{waitUntil:'load'}); await p.waitForTimeout(800);
 await p.click('tbody a >> nth=0'); await p.waitForTimeout(300);
 console.log(await p.evaluate(()=>document.querySelector('.ix-toast')&&document.querySelector('.ix-toast').textContent));
 await p.click('button:has-text("Assign") >> nth=0'); await p.waitForTimeout(300); await p.screenshot({path:'k1i/i1.png'});
 await p.click('.hmt-toolbar >> text=Filters'); await p.click('.ix-pop >> text=Thêm bộ lọc tuỳ chỉnh'); await p.waitForTimeout(300); await p.screenshot({path:'k1i/i2.png'});
 console.log('ERR',errs); await b.close();})();
