const { chromium } = require('playwright');
(async()=>{
 const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium_headless_shell-1194/chrome-linux/headless_shell'});
 for (const n of ['TS01','TS01b','TS07_K1','TS07_K2','TS11_K5','TS11b','TS16']) {
 const p=await b.newPage({viewport:{width:1440,height:1000}});
 await p.route(/fonts\.(googleapis|gstatic)\.com/,r=>r.abort());
 await p.goto('http://127.0.0.1:8765/'+n+'a.dc.html',{waitUntil:'load'}); await p.waitForTimeout(800);
 const info=await p.evaluate(()=>{const t=s=>(document.querySelector(s)?.textContent||'').replace(/\s+/g,' ').trim();
  const bt=Array.from(document.querySelectorAll('.hmt-pagehead button, .hmt-pagehead .hmt-btn, .hmt-toolbar button, .hmt-facets button')).map(e=>(e.getAttribute('aria-label')||e.textContent).replace(/\s+/g,' ').trim()).filter(Boolean);
  const ph=document.querySelector('input[type=search],input.hmt-input')?.placeholder;
  const chips=Array.from(document.querySelectorAll('.hmt-chip-f, .ix-chiprow .hmt-chip')).map(e=>e.textContent.replace(/\s+/g,' ').trim());
  const pager=document.body.textContent.match(/\d+–\d+ \/ \d+/);
  return {title:t('h1'),ph,btns:bt.join(' | '),chips,pager:pager&&pager[0],hasBulk:!!document.querySelector('.hmt-fbar'),dateF:t('.hmt-toolbar > span button, .hmt-toolbar > span')};});
 console.log(n,JSON.stringify(info,null,0));
 await p.screenshot({path:'k1i/aud_'+n+'.png',clip:{x:236,y:52,width:1204,height:200}}); await p.close(); }
 await b.close();})();
