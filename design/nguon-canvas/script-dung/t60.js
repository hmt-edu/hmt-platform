const { chromium } = require('playwright');
(async()=>{const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium_headless_shell-1194/chrome-linux/headless_shell'});
for(const n of ['TS16','TS16b','TS16c']){const p=await b.newPage({viewport:{width:1440,height:1000}});p.on('pageerror',e=>console.log('ERR',n,e.message));await p.route(/fonts\./,r=>r.abort());
await p.goto('http://127.0.0.1:8765/V_'+n+'.dc.html');await p.waitForTimeout(1000);
const cnt=async()=>n=='TS16'?await p.$$eval('tbody tr',r=>r.filter(x=>x.style.display!='none'&&!x.classList.contains('ghead')).length):n=='TS16b'?await p.$$eval('.hmt-kcard',r=>r.length):await p.$$eval('[data-code],.hmt-cal-ev,[data-ev]',r=>r.length);
console.log(n,'all',await cnt());
for(const t of ['Tôi tạo','Tôi phụ trách']){await p.evaluate(x=>[...document.querySelectorAll('.hmt-pills[aria-label="Của tôi"] button')].find(e=>e.textContent==x).click(),''+t+'');await p.waitForTimeout(300);console.log(n,t,await cnt());await p.evaluate(x=>[...document.querySelectorAll('.hmt-pills[aria-label="Của tôi"] button')].find(e=>e.textContent==x).click(),''+t+'');await p.waitForTimeout(200);}
await p.evaluate(x=>[...document.querySelectorAll('.hmt-pills[aria-label="Của tôi"] button')].find(e=>e.textContent==x).click(),'Tôi tạo');await p.evaluate(x=>[...document.querySelectorAll('.hmt-pills[aria-label="Của tôi"] button')].find(e=>e.textContent==x).click(),'Tôi phụ trách');await p.waitForTimeout(300);console.log(n,'both',await cnt());
await p.evaluate(x=>[...document.querySelectorAll('.hmt-pills[aria-label="Của tôi"] button')].find(e=>e.textContent==x).click(),'Tôi tạo');await p.evaluate(x=>[...document.querySelectorAll('.hmt-pills[aria-label="Của tôi"] button')].find(e=>e.textContent==x).click(),'Tôi phụ trách');await p.waitForTimeout(300);
await p.screenshot({path:'audit/n_'+n+'.png'});await p.close();}
await b.close();})();
