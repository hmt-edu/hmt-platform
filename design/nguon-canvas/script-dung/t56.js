const { chromium } = require('playwright');
(async()=>{const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium_headless_shell-1194/chrome-linux/headless_shell'});
const p=await b.newPage({viewport:{width:1440,height:1000}});p.on('pageerror',e=>console.log('ERR',e.stack.split('\n').slice(0,4).join(' | ')));await p.route(/fonts\./,r=>r.abort());
await p.goto('http://127.0.0.1:8765/V_TS16b.dc.html');await p.waitForTimeout(1000);console.log('loaded');
await p.click('.hmt-kcol[data-st="Nháp"] [data-go] >> nth=0');await p.waitForTimeout(300);
console.log(await p.$$eval('.hmt-kcol',c=>c.map(x=>x.getAttribute('data-st')+':'+x.querySelectorAll('.hmt-kcard').length)));
console.log(await p.$$eval('tbody tr',r=>r.map(x=>x.children[12]&&x.innerText.replace(/\s+/g,' ').slice(-30))));
await b.close();})();
