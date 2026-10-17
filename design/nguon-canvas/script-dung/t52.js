const { chromium } = require('playwright');
(async()=>{const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium_headless_shell-1194/chrome-linux/headless_shell'});
for (const n of ['K3','TS02','TS17']){
const p=await b.newPage({viewport:{width:1440,height:1000}});await p.route(/fonts\./,r=>r.abort());
await p.goto('http://127.0.0.1:8765/V_'+n+'.dc.html');await p.waitForTimeout(1000);
console.log(n,JSON.stringify(await p.evaluate(()=>{const xs=Array.from(document.querySelectorAll('.hmt-step'));const x=xs.find(a=>a.getAttribute('aria-current')==='step')||xs[0];const cs=getComputedStyle(x);const sp=x.querySelector('span');return {cls:x.className,bg:cs.backgroundColor,col:cs.color,fw:cs.fontWeight,fill:cs.webkitTextFillColor,sh:cs.textShadow,ff:cs.fontFamily.slice(0,30),fs:cs.fontSize,span:sp?getComputedStyle(sp).color:null,html:x.outerHTML.slice(0,260),css:Array.from(document.styleSheets).length}})));}
await b.close();})();
