const { chromium } = require('playwright');const fs=require('fs');
const B=['TS01','TS01b','TS02','TS03','TS06','TS07_K1','TS07_K2','TS08_K3','TS09','TS11_K5','TS11b','TS11c','TS13','TS15','TS16','TS16b','TS16c','TS17'];
(async()=>{const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium_headless_shell-1194/chrome-linux/headless_shell'});
const out={};
for(const n of B){const p=await b.newPage({viewport:{width:1440,height:1000}});const errs=[];p.on('pageerror',e=>errs.push(e.message.slice(0,80)));await p.route(/fonts\./,r=>r.abort());
await p.goto('http://127.0.0.1:8765/V_'+n+'.dc.html');await p.waitForTimeout(1200);
await p.screenshot({path:'audit/'+n+'.png'});
out[n]=await p.evaluate(()=>{
 const vis=e=>{const r=e.getBoundingClientRect();const s=getComputedStyle(e);return r.width>0&&r.height>0&&s.display!='none'&&s.visibility!='hidden'};
 const cs=e=>{const s=getComputedStyle(e),r=e.getBoundingClientRect();return {h:Math.round(r.height),w:Math.round(r.width),fs:s.fontSize,fw:s.fontWeight,rad:s.borderRadius,bg:s.backgroundColor,c:s.color,bd:s.border.slice(0,40),ff:s.fontFamily.split(',')[0]}};
 const res={els:{}};
 const sel='button,[role=button],.hmt-btn,.hmt-chip,.hmt-seg>*,th,.hmt-badge,.hmt-tag,.hmt-status,a';
 document.querySelectorAll(sel).forEach(e=>{if(!vis(e))return;const t=(e.innerText||'').trim().replace(/\s+/g,' ');if(!t||t.length>22)return;(res.els[t]=res.els[t]||[]).push(cs(e))});
 res.title=[...document.querySelectorAll('h1,h2,.hmt-title,[class*=title]')].filter(vis).slice(0,3).map(e=>(e.innerText||'').trim().slice(0,40)+' | '+JSON.stringify(cs(e)));
 res.body=cs(document.body);
 return res});
out[n].errs=errs;await p.close();}
fs.writeFileSync('audit/data.json',JSON.stringify(out));await b.close();})();
