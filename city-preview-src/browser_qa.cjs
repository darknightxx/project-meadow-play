const {chromium,webkit}=require('/tmp/city-browser/node_modules/playwright');
const fs=require('fs'),assert=require('assert');
(async()=>{
 const report={checks:[],errors:[],scope:'Linux CI emulation only; not physical iOS/Android performance.'};
 const browser=await chromium.launch({headless:true,args:['--use-gl=angle','--use-angle=swiftshader','--enable-webgl','--ignore-gpu-blocklist']});
 const page=await browser.newPage({viewport:{width:1280,height:720}});
 page.on('console',m=>{if(m.type()==='error')report.errors.push(m.text());});page.on('pageerror',e=>report.errors.push(e.message));
 await page.goto('http://127.0.0.1:8765/');await page.waitForFunction(()=>window.cityReady&&window.cityTestState,{timeout:120000});
 const state=()=>page.evaluate(()=>window.cityTestState);
 const click=name=>page.getByRole('button',{name,exact:true}).click();
 const walk=async(key,ms)=>{await page.keyboard.down(key);await page.waitForTimeout(ms);await page.keyboard.up(key);await page.waitForTimeout(350);};
 const shot=name=>page.screenshot({path:`city-preview-reports/web-${name}.jpg`,type:'jpeg',quality:86});
 const pass=name=>report.checks.push({name,pass:true});
 pass('web_engine_and_scene_load');report.load_ms=await page.evaluate(()=>window.cityLoadMs);await shot('overview');
 await click('เดินสำรวจ');await page.waitForFunction(()=>window.cityTestState.mode==='walk');
 const before=(await state()).z;
 await page.locator('#canvas').focus();await page.keyboard.down('KeyS');
 try {await page.waitForFunction(z=>window.cityTestState.z>z+.3,before,{timeout:30000});}
 catch(error){fs.writeFileSync('city-preview-reports/keyboard-diagnostic.json',JSON.stringify(await page.evaluate(()=>({state:window.cityTestState,focus:document.activeElement.id,canvas:[document.querySelector('canvas').width,document.querySelector('canvas').height],compressed:window.cityCompressedEngine})),null,2));throw error;}
 finally {await page.keyboard.up('KeyS');}
 pass('keyboard_movement');
 await click('ภายในวิหาร');await page.waitForFunction(()=>window.cityTestState.inside);await shot('interior');
 await click('ตู้บริจาค');assert.equal((await state()).coins,100);await click('กลับ');assert.equal((await state()).coins,100);
 await click('ตู้บริจาค');await click('บริจาค 10 เหรียญทดลอง');await page.waitForFunction(()=>window.cityTestState.coins===90);pass('donation_confirmation_cancel_and_commit');
 await page.keyboard.down('KeyW');await page.waitForFunction(()=>window.cityTestState.canPray,{},{timeout:20000});await page.keyboard.up('KeyW');await click('ไหว้พระ');await page.waitForFunction(()=>window.cityTestState.prayer);
 await walk('KeyS',200);await page.waitForFunction(()=>!window.cityTestState.prayer);pass('prayer_and_movement_cancel');
 await click('เดินสำรวจ');await page.keyboard.down('KeyW');await page.waitForFunction(()=>window.cityTestState.z<80,{},{timeout:20000});await page.waitForTimeout(1000);await page.keyboard.up('KeyW');assert((await state()).z>=79.4);pass('fountain_blocks_walking');
 await page.setViewportSize({width:800,height:360});await page.waitForTimeout(600);await shot('mobile-landscape');
 assert(!(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth)));
 const joy=await page.locator('#joystick').boundingBox();assert(joy&&joy.width>0);
 await page.mouse.move(joy.x+joy.width/2,joy.y+joy.height/2);await page.mouse.down();await page.mouse.move(joy.x+joy.width/2+30,joy.y+joy.height/2);await page.waitForTimeout(600);await page.mouse.up();
 await page.waitForTimeout(350);const stopped=await state();await page.waitForTimeout(650);const ended=await state();assert(Math.hypot(ended.x-stopped.x,ended.z-stopped.z)<.1);pass('landscape_layout_and_joystick_release');
 await page.setViewportSize({width:390,height:844});await page.waitForTimeout(500);await shot('mobile-portrait');assert(!(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth)));pass('portrait_layout');
 await browser.close();
 try{const safari=await webkit.launch({headless:true});const p=await safari.newPage({viewport:{width:800,height:360},isMobile:true,hasTouch:true,deviceScaleFactor:2});await p.goto('http://127.0.0.1:8765/');await p.waitForFunction(()=>window.cityReady,{timeout:60000});pass('webkit_scene_load');await safari.close();}
 catch(e){report.checks.push({name:'webkit_scene_load',pass:false,status:'BLOCKED',reason:String(e).slice(0,500)});}
 fs.writeFileSync('city-preview-reports/browser-qa.json',JSON.stringify(report,null,2));
 assert.equal(report.errors.filter(x=>/SCRIPT ERROR|Failed to load|Parse Error/i.test(x)).length,0,JSON.stringify(report.errors));
})().catch(error=>{fs.writeFileSync('city-preview-reports/browser-failure.txt',String(error.stack||error));console.error(error);process.exit(1);});

