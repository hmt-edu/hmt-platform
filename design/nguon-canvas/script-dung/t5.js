const { chromium } = require('playwright');
(async()=>{
 const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium_headless_shell-1194/chrome-linux/headless_shell'});
 const p=await b.newPage({viewport:{width:1440,height:1000}});
 const errs=[]; p.on('pageerror',e=>errs.push(e.message));
 await p.route(/fonts\.(googleapis|gstatic)\.com/,r=>r.abort());
 await p.goto('http://127.0.0.1:8765/TS07K1t.dc.html',{waitUntil:'load'}); await p.waitForTimeout(800);
 const O='k1i/h';
 await p.click('.hmt-toolbar >> text=Filters'); await p.waitForTimeout(200); await p.screenshot({path:O+'1.png'});
 await p.click('.ix-pop >> text=GIAI ĐOẠN'); await p.waitForTimeout(200); await p.click('.ix-pop >> text=L4 Khách hàng tiềm năng'); await p.waitForTimeout(300); await p.screenshot({path:O+'2.png'});
 await p.click('body',{position:{x:900,y:900}});
 await p.click('.hmt-toolbar >> text=Group By'); await p.waitForTimeout(200); await p.screenshot({path:O+'3.png'});
 await p.click('.ix-pop >> text=Source'); await p.waitForTimeout(300); await p.screenshot({path:O+'4.png'});
 await p.click('body',{position:{x:900,y:900}});
 await p.click('tbody a >> nth=0'); await p.waitForTimeout(300); await p.screenshot({path:O+'5.png'});
 console.log('ERR',errs); await b.close();})();
