const { chromium } = require('playwright');
(async()=>{const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium_headless_shell-1194/chrome-linux/headless_shell'});
for(const n of process.argv.slice(3)){const p=await b.newPage({viewport:{width:1440,height:1000}});
await p.route(/fonts\.(googleapis|gstatic)\.com/,r=>r.abort());
await p.goto('http://127.0.0.1:8765/'+n+'.dc.html');await p.waitForTimeout(600);
await p.getByText(process.argv[2],{exact:false}).first().click();await p.waitForTimeout(500);
await p.screenshot({path:process.env.OUT+'/'+n+'_tab.png'});await p.close();}
await b.close();})();
