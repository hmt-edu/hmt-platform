const { chromium } = require('playwright');const fs=require('fs');
(async()=>{const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium_headless_shell-1194/chrome-linux/headless_shell'});
async function open(n){fs.copyFileSync('p5a/project/'+n+'.dc.html','render/V_'+n+'.dc.html');const p=await b.newPage({viewport:{width:1440,height:1000}});p.on('pageerror',e=>console.log('ERR',n,e.message.slice(0,150)));await p.route(/fonts\./,r=>r.abort());await p.goto('http://127.0.0.1:8765/V_'+n+'.dc.html');await p.waitForTimeout(1200);return p;}
let p=await open('BH05_nhap');
await p.click('.hmt-tab[data-tab=t1]');
console.log('rows k2',await p.evaluate(()=>document.querySelector('[data-sched] tbody').innerText.replace(/\s+/g,' ')));
await p.selectOption('[data-term]','k3');await p.waitForTimeout(300);
console.log('rows k3',await p.evaluate(()=>document.querySelector('[data-sched] tbody').innerText.replace(/\s+/g,' ')));
await p.selectOption('[data-term]','');await p.waitForTimeout(300);
console.log('rows 1',await p.evaluate(()=>document.querySelector('[data-sched] tbody').innerText.replace(/\s+/g,' ')),await p.evaluate(()=>document.querySelector('.ix-toast').textContent));
p=await open('BH08_luan_phien');console.log('dlg',await p.evaluate(()=>getComputedStyle(document.querySelector('[data-dlg=bh08]')).display));
await b.close();})();
