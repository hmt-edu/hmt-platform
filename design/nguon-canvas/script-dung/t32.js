const { chromium } = require('playwright');
(async()=>{
 const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium_headless_shell-1194/chrome-linux/headless_shell'});
 const errs=[]; const p=await b.newPage({viewport:{width:1440,height:1000}}); p.on('pageerror',e=>errs.push(e.message)); await p.route(/fonts\.(googleapis|gstatic)\.com/,r=>r.abort());
 await p.goto('http://127.0.0.1:8765/V_TS15.dc.html',{waitUntil:'load'}); await p.waitForTimeout(900);
 const v=()=>p.evaluate(()=>Array.from(document.querySelectorAll('.hmt-dialog input')).map(i=>i.value).join(' '));
 console.log('init',await v());
 await p.click('.hmt-dialog .hmt-pills[aria-label="Chọn nhanh ngày"] button:has-text("Hôm nay")'); await p.waitForTimeout(100); console.log('hôm nay',await v());
 await p.click('.hmt-dialog .hmt-pills[aria-label="Chọn nhanh ngày"] button:has-text("T2 19/10")'); await p.click('.hmt-dialog .hmt-pills[aria-label="Chọn nhanh giờ bắt đầu"] button:has-text("09:00")'); await p.waitForTimeout(100); console.log('T2 9h',await v());
 await p.fill('[data-r=h]','20:00'); console.log('after fill',await v()); await p.click('.hmt-dialog .hmt-pills[aria-label="Chọn nhanh ngày"] button:has-text("CN 18/10")'); await p.waitForTimeout(100); console.log('dirty keeps',await v());
 await p.click('.hmt-dialog-f .hmt-btn-primary'); await p.waitForTimeout(200); console.log('toast',await p.textContent('.ix-toast'));
 await p.screenshot({path:'scripts/k1i/u5.png'}); console.log(errs); await b.close();})();
