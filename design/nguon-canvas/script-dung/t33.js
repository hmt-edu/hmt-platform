const { chromium } = require('playwright');
(async()=>{
 const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium_headless_shell-1194/chrome-linux/headless_shell'});
 const p=await b.newPage({viewport:{width:1440,height:1000}}); await p.route(/fonts\.(googleapis|gstatic)\.com/,r=>r.abort());
 await p.goto('http://127.0.0.1:8765/V_TS15.dc.html',{waitUntil:'load'}); await p.waitForTimeout(900);
 const v=()=>p.evaluate(()=>Array.from(document.querySelectorAll('.hmt-dialog input')).map(i=>i.value).join(' '));
 await p.evaluate(()=>{const r=document.querySelector('[data-r=h]'); r.value='20:00'; r.dispatchEvent(new Event('input',{bubbles:true}));});
 console.log(await v());
 await p.click('.hmt-dialog .hmt-pills[aria-label="Chọn nhanh ngày"] button:has-text("CN 18/10")'); await p.waitForTimeout(100); console.log(await v());
 await b.close();})();
