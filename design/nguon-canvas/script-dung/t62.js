const { chromium } = require('playwright');
(async()=>{const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium_headless_shell-1194/chrome-linux/headless_shell'});
const p=await b.newPage({viewport:{width:1440,height:1000}});await p.route(/fonts\./,r=>r.abort());
await p.goto('http://127.0.0.1:8765/V_TS16.dc.html');await p.waitForTimeout(1000);
console.log(await p.evaluate(()=>{const w=document.querySelector('.hmt-table-wrap');const t=w.querySelector('table');return JSON.stringify({ww:w.clientWidth,sw:w.scrollWidth,tw:t.offsetWidth,ov:getComputedStyle(w).overflowX,ths:[...t.querySelectorAll('th')].map(x=>x.innerText.trim()+':'+Math.round(x.getBoundingClientRect().width))})}));await b.close();})();
