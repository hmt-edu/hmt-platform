const { chromium } = require('playwright');const fs=require('fs');
(async()=>{
 const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium_headless_shell-1194/chrome-linux/headless_shell'});
 const p=await b.newPage({viewport:{width:1440,height:1000}});
 await p.route(/fonts\.(googleapis|gstatic)\.com/,r=>r.abort());
 await p.goto('http://127.0.0.1:8765/TS01x.dc.html',{waitUntil:'load'}); await p.waitForTimeout(800);
 const r=await p.evaluate(()=>{const g=s=>{const e=document.querySelector(s);return e?e.outerHTML:null};
  const m=document.querySelector('.hmt-main');return {kids:Array.from(m.children).map(c=>c.className+'|'+c.tagName), header:g('.hmt-header'),toolbar:g('.hmt-toolbar'),chiprow:g('.ix-chiprow'),fbar:Array.from(document.querySelectorAll('.hmt-fbar')).map(e=>e.outerHTML.slice(0,1500))}});
 fs.writeFileSync('k1i/ts01dom.json',JSON.stringify(r,null,1));console.log(r.kids);
 await b.close();})();
