const { chromium } = require('playwright');const fs=require('fs');
(async()=>{
 const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium_headless_shell-1194/chrome-linux/headless_shell'});
 const p=await b.newPage({viewport:{width:1440,height:1000}});
 await p.route(/fonts\.(googleapis|gstatic)\.com/,r=>r.abort());
 await p.goto('http://127.0.0.1:8765/TS01x.dc.html',{waitUntil:'load'}); await p.waitForTimeout(800);
 const O='k1i/f';
 await p.click('.hmt-toolbar >> text=Filters'); await p.waitForTimeout(300); await p.screenshot({path:O+'1.png'});
 const html=await p.evaluate(()=>{const e=document.querySelector('.hmt-menu,.ix-pop');return e?e.outerHTML:document.body.innerHTML.slice(-3000)});
 fs.writeFileSync('k1i/filters.html',html);
 await p.keyboard.press('Escape'); await p.click('body',{position:{x:900,y:900}});
 await p.click('.hmt-toolbar >> text=Group By'); await p.waitForTimeout(300); await p.screenshot({path:O+'2.png'});
 const h2=await p.evaluate(()=>{const e=document.querySelector('.hmt-menu,.ix-pop');return e?e.outerHTML:''});
 fs.writeFileSync('k1i/groupby.html',h2);
 await b.close();})();
