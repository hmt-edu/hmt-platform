const { chromium } = require('playwright');
(async()=>{
 const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium_headless_shell-1194/chrome-linux/headless_shell'});
 const p=await b.newPage({viewport:{width:1440,height:1000}}); await p.route(/fonts\.(googleapis|gstatic)\.com/,r=>r.abort());
 for (const f of ['TS13','TS06','TS03']) { await p.goto('http://127.0.0.1:8765/'+f+'.dc.html',{waitUntil:'load'}); await p.waitForTimeout(800);
  const r=await p.evaluate(()=>{const out=[];document.querySelectorAll('.hmt-dialog input[type=text],.hmt-dialog input:not([type]),.hmt-dialog input[type=time]').forEach(i=>out.push(i.type+':'+i.getAttribute('value')+':'+(i.getAttribute('aria-label')||'')));return out});
  console.log(f,r);
  const sel=await p.evaluate(()=>{const i=document.querySelector('.hmt-dialog input[type=text],.hmt-dialog input:not([type])');return i?(i.id||i.getAttribute('aria-label')):null});
  if (sel) { const loc=p.locator('.hmt-dialog input[type=text], .hmt-dialog input:not([type])').first(); await loc.fill('xyz'); console.log(f,'fill->',await loc.inputValue()); }
 }
 await b.close();})();
