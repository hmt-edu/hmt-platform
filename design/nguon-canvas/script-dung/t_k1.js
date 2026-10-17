const { chromium } = require('playwright');
(async()=>{
 const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium_headless_shell-1194/chrome-linux/headless_shell'});
 const p=await b.newPage({viewport:{width:1440,height:1000}});
 const errs=[]; p.on('pageerror',e=>errs.push(e.message)); p.on('console',m=>{if(m.type()==='error')errs.push(m.text())});
 await p.route(/fonts\.(googleapis|gstatic)\.com/,r=>r.abort());
 await p.goto('http://127.0.0.1:8765/K1i.dc.html',{waitUntil:'load'}); await p.waitForTimeout(800);
 const O='k1i/';
 await p.screenshot({path:O+'0.png'});
 await p.click('text=Filters'); await p.waitForTimeout(200); await p.screenshot({path:O+'1.png'});
 await p.click('.ix-pop >> text=Website'); await p.waitForTimeout(200); await p.screenshot({path:O+'2.png'});
 await p.click('body',{position:{x:900,y:900}});
 await p.click('text=Group By'); await p.click('.ix-pop >> text=Cơ sở'); await p.waitForTimeout(200); await p.screenshot({path:O+'3.png'});
 await p.click('text=Tất cả thời gian'); await p.click('.ix-pop >> text=Tháng này'); await p.waitForTimeout(200);
 await p.click('tbody a >> nth=0'); await p.waitForTimeout(200); await p.screenshot({path:O+'4.png'});
 console.log('ERR',errs);
 await b.close();
})();
