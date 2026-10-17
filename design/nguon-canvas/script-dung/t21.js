const { chromium } = require('playwright');
(async()=>{
 const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium_headless_shell-1194/chrome-linux/headless_shell'});
 const p=await b.newPage({viewport:{width:1440,height:1000}}); const errs=[]; p.on('pageerror',e=>errs.push(e.message));
 await p.route(/fonts\.(googleapis|gstatic)\.com/,r=>r.abort());
 await p.goto('http://127.0.0.1:8765/TS11_K5r.dc.html',{waitUntil:'load'}); await p.waitForTimeout(900);
 const vis=()=>p.evaluate(()=>document.querySelectorAll('.hmt-ev:not(.ix-off)').length);
 const hdr=()=>p.textContent('.hmt-calv-bar h2');
 const per=()=>p.textContent('.ix-tper');
 console.log('start',await vis(), await hdr(), await per());
 // custom filter via Filters > Lịch hẹn group > Quá hạn
 await p.click('.hmt-toolbar >> text=Filters'); await p.click('.ix-pop >> text=LỊCH HẸN'); await p.click('.ix-pop >> text=Hôm nay'); await p.keyboard.press('Escape');
 console.log('Hôm nay',await vis());
 await p.click('.ix-chiprow >> text=Xoá lọc'); console.log('cleared',await vis());
 await p.click('.hmt-calv-bar [aria-label="Sau"]'); console.log('next week',await vis(), await hdr(), await per());
 await p.click('.hmt-calv-bar >> text=Hôm nay'); console.log('today',await vis(), await hdr(), await per());
 await p.click('.hmt-calv-bar [aria-label="Trước"]'); console.log('prev',await vis(), await hdr(), await per());
 await p.click('.hmt-calv-bar >> text=Hôm nay');
 // period menu: choose a preset from toolbar
 await p.click('.ix-tper'); await p.waitForTimeout(200); console.log('per menu',(await p.evaluate(()=>Array.from(document.querySelectorAll('.ix-pop .hmt-opt, .ix-pop button')).slice(0,14).map(e=>e.textContent.trim()))).join('|'));
 await p.keyboard.press('Escape');
 // search
 await p.fill('.hmt-search input','Linh'); await p.waitForTimeout(250); console.log('search Linh',await vis()); await p.fill('.hmt-search input',''); await p.waitForTimeout(200);
 // group by
 await p.click('.hmt-toolbar >> text=Group By'); await p.click('.ix-pop >> text=Trạng thái'); await p.keyboard.press('Escape'); await p.waitForTimeout(300); console.log('group by',await vis(), await p.evaluate(()=>Array.from(document.querySelectorAll('.ix-chiprow .hmt-chip')).map(e=>e.textContent.trim())));
 await p.click('.ix-chiprow >> text=Xoá lọc'); await p.waitForTimeout(200); console.log('after clear',await vis());
 // event popup
 await p.click('.hmt-ev-meet >> nth=0'); await p.waitForTimeout(150);
 console.log('popup',await p.textContent('.hmt-calv .hmt-menu b'), '|', (await p.textContent('.hmt-calv .hmt-menu [class*=primary]')).trim());
 await p.click('.hmt-calv .hmt-menu >> text=Hoàn thành'); console.log('done evs',await p.evaluate(()=>document.querySelectorAll('.hmt-ev-done').length));
 await p.click('.hmt-toolbar >> text=Filters'); await p.click('.ix-pop >> text=Thêm bộ lọc tuỳ chỉnh'); await p.waitForTimeout(250);
 console.log('cf dlg',await p.evaluate(()=>!!document.querySelector('.ix-cf')));
 await p.keyboard.press('Escape'); 
 console.log('cột hidden',await p.evaluate(()=>Array.from(document.querySelectorAll('.hmt-header .sz button')).filter(b=>b.offsetParent&&/^Cột/.test(b.textContent.trim())).length===0), 'pager hidden', await p.evaluate(()=>{const e=document.querySelector('.hmt-pager');return !e||!e.offsetParent}));
 console.log('ERR',errs); await b.close();})();
