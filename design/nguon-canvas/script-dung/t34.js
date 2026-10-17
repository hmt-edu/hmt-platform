const { chromium } = require('playwright');
(async()=>{
 const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium_headless_shell-1194/chrome-linux/headless_shell'});
 const p=await b.newPage({viewport:{width:1440,height:1000}}); await p.route(/fonts\.(googleapis|gstatic)\.com/,r=>r.abort());
 await p.goto('http://127.0.0.1:8765/V_TS18.dc.html',{waitUntil:'load'}); await p.waitForTimeout(900);
 console.log(await p.evaluate(()=>document.querySelectorAll('.hmt-dialog input[type=time]').length));
 await p.fill('.hmt-dialog input[type=time]','20:00'); console.log(await p.inputValue('.hmt-dialog input[type=time]'));
 await p.focus('.hmt-dialog input[type=time]'); await p.keyboard.type('2030'); console.log(await p.inputValue('.hmt-dialog input[type=time]'));
 await b.close();})();
