const { chromium } = require('playwright');
(async()=>{
 const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium_headless_shell-1194/chrome-linux/headless_shell'});
 const p=await b.newPage({viewport:{width:1440,height:1000}}); await p.route(/fonts\.(googleapis|gstatic)\.com/,r=>r.abort());
 await p.goto('http://127.0.0.1:8765/V_TS15.dc.html',{waitUntil:'load'}); await p.waitForTimeout(900);
 await p.click('#hs-add'); await p.click('#hs-name'); await p.keyboard.type('Bao'); console.log('type',await p.inputValue('#hs-name'));
 await p.fill('#hs-name','Le Gia Bao'); console.log('fill',await p.inputValue('#hs-name'));
 console.log('ro',await p.evaluate(()=>document.querySelector('#hs-name').readOnly));
 await p.click('.hmt-dialog-f .hmt-btn-primary'); await p.waitForTimeout(200); console.log(await p.textContent('.ix-toast'));
 await b.close();})();
