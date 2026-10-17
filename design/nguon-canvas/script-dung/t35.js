const { chromium } = require('playwright');
(async()=>{
 const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium_headless_shell-1194/chrome-linux/headless_shell'});
 const errs=[]; const p=await b.newPage({viewport:{width:1440,height:1000}}); p.on('pageerror',e=>errs.push(e.message)); await p.route(/fonts\.(googleapis|gstatic)\.com/,r=>r.abort());
 await p.goto('http://127.0.0.1:8765/V_TS15.dc.html',{waitUntil:'load'}); await p.waitForTimeout(900);
 await p.screenshot({path:'scripts/k1i/u6.png'});
 await p.click('#hs-add'); await p.waitForTimeout(150);
 console.log('after add',await p.evaluate(()=>[document.querySelector('#hs-name').value,document.querySelector('#hs-name').readOnly,document.querySelector('#hs-cls').innerText,document.querySelector('#hs-add').innerText]));
 await p.click('.hmt-dialog-f .hmt-btn-primary'); await p.waitForTimeout(200); console.log('empty->',await p.textContent('.ix-toast'));
 await p.fill('#hs-name','Lê Gia Bảo'); await p.click('#hs-cls'); await p.waitForTimeout(150);
 console.log('opts',await p.evaluate(()=>Array.from(document.querySelectorAll('.ix-pop .hmt-opt')).slice(0,3).map(x=>x.innerText)));
 await p.click('.ix-pop .hmt-opt >> nth=4'); await p.waitForTimeout(100);
 await p.screenshot({path:'scripts/k1i/u7.png'});
 await p.click('.hmt-dialog-f .hmt-btn-primary'); await p.waitForTimeout(200); console.log('ok->',await p.textContent('.ix-toast'));
 await p.reload(); await p.waitForTimeout(700); await p.click('#hs-add'); await p.click('#hs-add'); console.log('back',await p.evaluate(()=>[document.querySelector('#hs-name').value,document.querySelector('#hs-cls').innerText]));
 console.log(errs); await b.close();})();
