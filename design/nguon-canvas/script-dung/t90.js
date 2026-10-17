const { chromium } = require('playwright');const fs=require('fs');
(async()=>{const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium_headless_shell-1194/chrome-linux/headless_shell'});
async function open(n){fs.copyFileSync('p5a/project/'+n+'.dc.html','render/V_'+n+'.dc.html');const p=await b.newPage({viewport:{width:1440,height:1000}});p.on('pageerror',e=>console.log('ERR',n,e.message.slice(0,150)));await p.route(/fonts\./,r=>r.abort());await p.goto('http://127.0.0.1:8765/V_'+n+'.dc.html');await p.waitForTimeout(1200);return p;}
const vis=(p,id)=>p.evaluate(i=>getComputedStyle(document.querySelector('[data-dlg="'+i+'"]')).display,id);
let p=await open('BH05_duyet');
await p.click('button:has-text("Cho học trước")');console.log('bh09',await vis(p,'bh09'));await p.click('[data-dlg="bh09"] [data-dto]');console.log('after bat',await vis(p,'bh09'),await p.evaluate(()=>document.querySelector('.ix-toast').textContent));
await p.click('.hmt-tab[data-tab=t1]');console.log('tab1',await p.evaluate(()=>getComputedStyle(document.querySelector('[data-panel=t1]')).display));
p=await open('BH05_tran');await p.click('.hmt-rbar-l button:has-text("Từ chối")');console.log('bh07 reject pane',await vis(p,'bh07'),await p.evaluate(()=>getComputedStyle(document.querySelector('[data-dlg="bh07"] [data-pane=reject]')).display));
p=await open('BH05_nhap');await p.click('a:has-text("Đổi lớp") >> nth=0');console.log('bh08',await vis(p,'bh08'));
p=await open('BH02_gui');await p.click('.hmt-rbar-l button:has-text("Từ chối")');console.log('tuchoi',await vis(p,'tuchoi'));
p=await open('BH06');await p.fill('.hmt-search input','Hương');await p.waitForTimeout(600);console.log('rows after search',await p.evaluate(()=>Array.from(document.querySelectorAll('tbody tr')).filter(r=>getComputedStyle(r).display!=='none').length));
await b.close();})();
