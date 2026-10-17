const { chromium } = require('playwright');
(async()=>{
 const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium_headless_shell-1194/chrome-linux/headless_shell'});
 const p=await b.newPage({viewport:{width:1440,height:1000}}); await p.route(/fonts\.(googleapis|gstatic)\.com/,r=>r.abort());
 await p.goto('http://127.0.0.1:8765/V_TS13.dc.html',{waitUntil:'load'}); await p.waitForTimeout(900);
 await p.click('.hmt-dialog:visible textarea >> nth=0'); await p.keyboard.type('abc'); console.log('ta',await p.inputValue('.hmt-dialog:visible textarea >> nth=0'));
 await p.fill('#gw-in','xyz'); console.log('gw',await p.inputValue('#gw-in'));
 await b.close();})();
