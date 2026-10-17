const { chromium } = require('playwright');
(async()=>{const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium_headless_shell-1194/chrome-linux/headless_shell'});
const p=await b.newPage({viewport:{width:1440,height:1000}});p.on('pageerror',e=>console.log('ERR',e.message));await p.route(/fonts\./,r=>r.abort());
await p.goto('http://127.0.0.1:8765/V_TS16c.dc.html');await p.waitForTimeout(1000);
await p.mouse.click(505,440);await p.waitForTimeout(400);await p.screenshot({path:'audit/n_pop.png',clip:{x:300,y:350,width:700,height:300}});await b.close();})();
