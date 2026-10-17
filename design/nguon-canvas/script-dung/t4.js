const { chromium } = require('playwright');const fs=require('fs');
(async()=>{
 const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium_headless_shell-1194/chrome-linux/headless_shell'});
 const p=await b.newPage({viewport:{width:1440,height:1000}});
 await p.route(/fonts\.(googleapis|gstatic)\.com/,r=>r.abort());
 await p.goto('http://127.0.0.1:8765/TS01x.dc.html',{waitUntil:'load'}); await p.waitForTimeout(800);
 const O='k1i/g';
 await p.click('.hmt-toolbar >> text=Filters'); await p.click('text=LỊCH HẸN'); await p.waitForTimeout(200); await p.click('text=GIAI ĐOẠN'); await p.waitForTimeout(200); await p.screenshot({path:O+'1.png'});
 await p.click('text=Thêm bộ lọc tuỳ chỉnh'); await p.waitForTimeout(300); await p.screenshot({path:O+'2.png'});
 await p.click('body',{position:{x:900,y:900}});
 await p.click('.hmt-toolbar >> text=Group By'); await p.click('text=Ngày tạo >> nth=-1'); await p.waitForTimeout(300); await p.screenshot({path:O+'3.png'});
 await b.close();})();
