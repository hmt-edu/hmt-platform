const { chromium } = require('playwright');
(async()=>{
 const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium_headless_shell-1194/chrome-linux/headless_shell'});
 for (const n of ['TS01','TS07_K1','TS11b','TS16']) {
 const p=await b.newPage({viewport:{width:1440,height:1000}});
 await p.route(/fonts\.(googleapis|gstatic)\.com/,r=>r.abort());
 await p.goto('http://127.0.0.1:8765/'+n+'a.dc.html',{waitUntil:'load'}); await p.waitForTimeout(800);
 const before=await p.evaluate(()=>/Đã chọn/.test(document.body.innerText));
 await p.click('tbody input[type=checkbox] >> nth=0',{force:true}); await p.waitForTimeout(250);
 const t=await p.evaluate(()=>{const m=document.body.innerText.match(/Đã chọn[^\n]*/);const bar=Array.from(document.querySelectorAll('button')).filter(b=>b.offsetParent&&/Assign|Hoàn thành hàng|Gán|Xếp lịch|Huỷ phiếu|Xuất đã chọn|Bỏ chọn/.test(b.textContent)).map(b=>b.textContent.trim());return {m:m&&m[0],bar}});
 console.log(n,before,JSON.stringify(t)); await p.close(); }
 await b.close();})();
