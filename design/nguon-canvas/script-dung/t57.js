const { chromium } = require('playwright');
(async()=>{const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium_headless_shell-1194/chrome-linux/headless_shell'});
const p=await b.newPage({viewport:{width:1440,height:1000}});p.on('pageerror',e=>console.log('ERR',e.message));p.on('console',m=>console.log('LOG',m.text()));await p.route(/fonts\./,r=>r.abort());
await p.goto('http://127.0.0.1:8765/V_dbg.dc.html');await p.waitForTimeout(1000);

await p.click('.hmt-kcol[data-st="Nháp"] [data-go] >> nth=0');await p.waitForTimeout(300);await b.close();})();
