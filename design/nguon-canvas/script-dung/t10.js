const { chromium } = require('playwright');
(async()=>{
 const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium_headless_shell-1194/chrome-linux/headless_shell'});
 const name=process.argv[2];
 const p=await b.newPage({viewport:{width:1440,height:1000}});
 const errs=[]; p.on('pageerror',e=>errs.push(e.message));
 await p.route(/fonts\.(googleapis|gstatic)\.com/,r=>r.abort());
 await p.goto('http://127.0.0.1:8765/'+name+'.dc.html',{waitUntil:'load'}); await p.waitForTimeout(800);
 await p.click('.hmt-toolbar >> text=Filters'); await p.click('.ix-pop >> text=Thêm bộ lọc tuỳ chỉnh'); await p.waitForTimeout(300);
 await p.click('.hmt-dialog:visible .hmt-select >> nth=0'); await p.waitForTimeout(300);
 console.log(await p.evaluate(()=>Array.from(document.querySelectorAll('.ix-pop .hmt-opt, .ix-pop .hmt-menu-h')).map(e=>e.textContent.trim())));
 await p.screenshot({path:'k1i/'+name+'_a.png'});
 console.log('ERR',errs); await b.close();})();
