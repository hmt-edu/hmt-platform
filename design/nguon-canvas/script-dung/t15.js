const { chromium } = require('playwright');
(async()=>{
 const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium_headless_shell-1194/chrome-linux/headless_shell'});
 for (const [n,f] of [['TS01r','a'],['TS11_K5r','b'],['TS11br','c']]) {
 const p=await b.newPage({viewport:{width:1440,height:1000}});
 await p.route(/fonts\.(googleapis|gstatic)\.com/,r=>r.abort());
 await p.goto('http://127.0.0.1:8765/'+n+'.dc.html',{waitUntil:'load'}); await p.waitForTimeout(800);
 await p.screenshot({path:'k1i/tb_'+f+'.png',clip:{x:236,y:52,width:1204,height:330}}); await p.close(); }
 await b.close();})();
