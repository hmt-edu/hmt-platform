const { chromium } = require('playwright');
(async()=>{const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium_headless_shell-1194/chrome-linux/headless_shell'});
const p=await b.newPage({viewport:{width:1440,height:1000}});p.on('pageerror',e=>console.log('ERR',e.stack.split('\n').slice(0,5).join(' | ')));await p.route(/fonts\./,r=>r.abort());
await p.goto('http://127.0.0.1:8765/V_TS16b.dc.html');await p.waitForTimeout(1000);console.log('loaded');
await p.click('.hmt-kcol[data-st="Đang test"] [data-more] >> nth=0');console.log('menu');await p.waitForTimeout(200);
await p.click('.ix-pop .hmt-opt:has-text("Huỷ phiếu")');console.log('opt');await p.waitForTimeout(200);
await p.click('.hmt-dialog [data-a=ok]');console.log('ok1');await p.fill('.hmt-dialog [data-req]','Test');await p.click('.hmt-dialog [data-a=ok]');console.log('ok2');await p.waitForTimeout(300);
await b.close();})();
