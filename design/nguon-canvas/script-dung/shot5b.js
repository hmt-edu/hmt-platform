// usage: node shot.js NAME [NAME...]  (copies from live15/project, screenshots full page)
const { chromium } = require('playwright');const fs=require('fs');
(async()=>{const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium_headless_shell-1194/chrome-linux/headless_shell'});
for(const n of process.argv.slice(2)){fs.copyFileSync('p5b/project/'+n+'.dc.html','render/V_'+n+'.dc.html');
const p=await b.newPage({viewport:{width:1440,height:1000}});const errs=[];p.on('pageerror',e=>errs.push(e.message.slice(0,150)));p.on('console',m=>{if(m.type()==='error')errs.push('c:'+m.text().slice(0,150))});await p.route(/fonts\./,r=>r.abort());
await p.goto('http://127.0.0.1:8765/V_'+n+'.dc.html');await p.waitForTimeout(1600);
await p.screenshot({path:'audit/q_'+n+'.png',fullPage:true});console.log(n,JSON.stringify(errs));await p.close();}
await b.close();})();
