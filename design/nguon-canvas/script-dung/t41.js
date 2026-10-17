const { chromium } = require('playwright');
(async()=>{
 const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium_headless_shell-1194/chrome-linux/headless_shell'});
 const p=await b.newPage({viewport:{width:1440,height:1000}}); await p.route(/fonts\.(googleapis|gstatic)\.com/,r=>r.abort());
 p.on('console',m=>console.log('console:',m.text().slice(0,200)));
 await p.goto('http://127.0.0.1:8765/V_TS15.dc.html',{waitUntil:'load'}); await p.waitForTimeout(900);
 await p.click('#hs-add');
 await p.evaluate(()=>{window.__n=document.querySelector('#hs-name');});
 await p.click('#hs-name'); await p.keyboard.type('B');
 console.log(await p.evaluate(()=>[window.__n.isConnected, window.__n.value, window.__n===document.querySelector('#hs-name'), document.querySelector('#hs-name').value, document.querySelectorAll('#hs-name').length, window.__n.getAttribute('value'), window.__n.hasAttribute('readonly')]));
 await b.close();})();
