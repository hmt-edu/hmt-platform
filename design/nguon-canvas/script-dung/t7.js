const { chromium } = require('playwright');
(async()=>{
 const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium_headless_shell-1194/chrome-linux/headless_shell'});
 const p=await b.newPage({viewport:{width:1440,height:1000}});
 await p.route(/fonts\.(googleapis|gstatic)\.com/,r=>r.abort());
 await p.goto('http://127.0.0.1:8765/TS01x.dc.html',{waitUntil:'load'}); await p.waitForTimeout(800);
 await p.click('.hmt-toolbar >> text=Filters'); await p.click('.ix-pop >> text=Thêm bộ lọc tuỳ chỉnh'); await p.waitForTimeout(300);
 await p.click('.hmt-dialog:visible .hmt-select >> nth=1'); await p.waitForTimeout(300); await p.screenshot({path:'k1i/j1.png'});
 await p.keyboard.press('Escape');
 await p.click('.hmt-dialog:visible .hmt-select >> nth=1'); await p.waitForTimeout(300); await p.screenshot({path:'k1i/j2.png'});
 await p.click('.hmt-dialog:visible .hmt-select >> nth=0'); await p.waitForTimeout(300); await p.screenshot({path:'k1i/j3.png'});
 await b.close();})();
