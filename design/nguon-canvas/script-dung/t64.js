const { chromium } = require('playwright');
(async()=>{const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium_headless_shell-1194/chrome-linux/headless_shell'});
for(const n of ['TS02','TS03','TS06','TS15','TS16','TS16b','TS16c','TS17']){const p=await b.newPage({viewport:{width:1440,height:1000}});p.on('pageerror',e=>console.log('ERR',n,e.message));await p.route(/fonts\./,r=>r.abort());
await p.goto('http://127.0.0.1:8765/V_'+n+'.dc.html');await p.waitForTimeout(900);await p.screenshot({path:'audit/f_'+n+'.png'});await p.close();}
await b.close();})();
