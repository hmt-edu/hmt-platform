const { chromium } = require('playwright');
(async()=>{
 const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium_headless_shell-1194/chrome-linux/headless_shell'});
 const p=await b.newPage({viewport:{width:1440,height:1000}});
 const errs=[]; p.on('pageerror',e=>errs.push(e.message));
 await p.route(/fonts\.(googleapis|gstatic)\.com/,r=>r.abort());
 await p.goto('http://127.0.0.1:8765/TS07K1t.dc.html',{waitUntil:'load'}); await p.waitForTimeout(800);
 const O='k1i/n';
 await p.screenshot({path:O+'0.png'});
 await p.click('button:has-text("Assign")'); await p.click('.ix-pop >> text=Lê Mai Anh'); await p.waitForTimeout(200); await p.screenshot({path:O+'1.png'});
 await p.click('text=Group By'); await p.click('.ix-pop >> text=Stage'); await p.click('button:has-text("Filters")'); await p.click('.ix-pop >> text=Website'); await p.waitForTimeout(200); await p.screenshot({path:O+'2.png'});
 await p.click('button:has-text("Xoá lọc")'); await p.waitForTimeout(200); await p.screenshot({path:O+'3.png'});
 console.log('ERR',errs); await b.close();})();
