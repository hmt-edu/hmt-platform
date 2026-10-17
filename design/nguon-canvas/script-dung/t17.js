const { chromium } = require('playwright');
(async()=>{
 const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium_headless_shell-1194/chrome-linux/headless_shell'});
 for (const n of ['TS01','TS01b','TS07_K1','TS07_K2','TS11_K5','TS11b','TS16']) {
 const p=await b.newPage({viewport:{width:1440,height:1000}});
 await p.route(/fonts\.(googleapis|gstatic)\.com/,r=>r.abort());
 await p.goto('http://127.0.0.1:8765/'+n+'a.dc.html',{waitUntil:'load'}); await p.waitForTimeout(800);
 const info=await p.evaluate(()=>{
  const main=document.querySelector('.hmt-main')||document.body;
  const top=Array.from(main.querySelectorAll('button,input,a')).filter(e=>e.getBoundingClientRect().top<150&&e.getBoundingClientRect().left>236).map(e=>e.tagName==='INPUT'?'[search:'+e.placeholder+']':((e.getAttribute('aria-label')||e.textContent).replace(/\s+/g,' ').trim()));
  const ro=Array.from(document.querySelectorAll('.hmt-facets,.ix-chiprow')).map(e=>({cls:e.className,txt:e.textContent.replace(/\s+/g,' ').trim(),disp:getComputedStyle(e).display, h:e.getBoundingClientRect().height}));
  const seg=Array.from(document.querySelectorAll('.hmt-seg-ic button')).map(b=>b.getAttribute('aria-label')+(b.getAttribute('aria-pressed')==='true'?'*':''));
  return {top:top.join(' | '),ro,seg:seg.join(',')};});
 console.log(n,JSON.stringify(info)); await p.close(); }
 await b.close();})();
