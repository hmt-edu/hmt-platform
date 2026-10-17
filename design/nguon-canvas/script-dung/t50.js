const { chromium } = require('playwright');
(async()=>{const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium_headless_shell-1194/chrome-linux/headless_shell'});
for (const n of ['K3','TS17']){
const p=await b.newPage({viewport:{width:1440,height:1000}});await p.route(/fonts\./,r=>r.abort());
await p.goto('http://127.0.0.1:8765/V_'+n+'.dc.html');await p.waitForTimeout(1000);
console.log(n,JSON.stringify(await p.evaluate(()=>{const x=document.querySelector('.hmt-step[aria-current="step"]');const c=getComputedStyle(x);return [c.backgroundColor,c.color,c.fontWeight,c.backgroundImage.slice(0,80),x.outerHTML.slice(0,200),document.documentElement.getAttribute('data-theme'),getComputedStyle(document.documentElement).getPropertyValue('--primary-contrast')]})));}
await b.close();})();
