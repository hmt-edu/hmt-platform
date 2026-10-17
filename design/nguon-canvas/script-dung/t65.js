const { chromium } = require('playwright');
(async()=>{const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium_headless_shell-1194/chrome-linux/headless_shell'});
const p=await b.newPage({viewport:{width:1440,height:1000}});p.on('pageerror',e=>console.log('ERR',e.message));await p.route(/fonts\./,r=>r.abort());
await p.goto('http://127.0.0.1:8765/V_TS16.dc.html');
for(const t of [300,900,1500,3000]){await p.waitForTimeout(t==300?300:t-(t==900?300:t==1500?900:1500));console.log(t,await p.$$eval('tbody tr',r=>r.filter(x=>x.style.display!='none').length), await p.$$eval('tbody tr',r=>r.length));}
await b.close();})();
