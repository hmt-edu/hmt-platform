const { chromium } = require('playwright');
(async()=>{
 const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium_headless_shell-1194/chrome-linux/headless_shell'});
 for (const n of ['TS01','TS01b','TS07_K1','TS07_K2','TS11_K5','TS11b','TS16']) {
 const p=await b.newPage({viewport:{width:1440,height:1000}});
 await p.route(/fonts\.(googleapis|gstatic)\.com/,r=>r.abort());
 await p.goto('http://127.0.0.1:8765/'+n+'a.dc.html',{waitUntil:'load'}); await p.waitForTimeout(800);
 const r={};
 const hasChk=await p.$('tbody input[type=checkbox]');
 if(hasChk){ await hasChk.click({force:true}).catch(()=>{}); await p.waitForTimeout(200); r.bulk=await p.evaluate(()=>{const f=document.querySelector('.hmt-fbar');return f?getComputedStyle(f).display+'|'+f.textContent.replace(/\s+/g,' ').trim().slice(0,80):'none'}); } else r.bulk='no-checkbox';
 await p.click('.hmt-toolbar >> text=Filters').catch(()=>{}); await p.waitForTimeout(250);
 r.filters=await p.evaluate(()=>{const e=document.querySelector('.ix-pop');return e?e.textContent.replace(/\s+/g,' ').trim().slice(0,90):'no popup; toast='+(document.querySelector('.ix-toast')?.textContent||'')});
 await p.keyboard.press('Escape');
 console.log(n,JSON.stringify(r)); await p.close(); }
 await b.close();})();
