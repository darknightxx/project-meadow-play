(() => {
  const html = `<div id="city-ui" hidden>
    <header><div class="brand"><span class="eyebrow">MEADOWFALL · CITY STUDY 01</span><h1>เวียงธารหลิว</h1><p>เมืองใหม่ บนพื้นที่และตำแหน่งวาร์ปเดิม</p></div><button id="help-open" aria-label="วิธีเล่น">?</button></header>
    <nav aria-label="มุมสำรวจ"><button data-view="plaza" class="selected">ลานเมือง</button><button data-view="overview">ผังเมือง</button><button data-view="walk">เดินสำรวจ</button><button data-view="temple">วิหาร</button><button data-view="interior">ภายในวิหาร</button><button id="dusk">แสงเย็น</button></nav>
    <aside id="context"><strong id="area">เมืองหลัก</strong><span id="description">กด “เดินสำรวจ” เพื่อเริ่มที่จุดเกิดเดิม</span><span id="warp"></span></aside>
    <div id="actions"><button id="pray" hidden>ไหว้พระ</button><button id="donate" hidden>ตู้บริจาค</button></div>
    <div id="joystick" aria-label="ลากเพื่อเดิน"><div id="stick"></div></div><div id="look-hint">ลากฉากเพื่อมองรอบตัว</div>
    <footer><span>ฉากทดลองเดินสำรวจ · ยังไม่เชื่อมตัวละครและเซิร์ฟเวอร์เกม</span><small id="coords"></small></footer>
    <div id="toast" role="status"></div>
    <dialog id="help"><h2>สำรวจเมือง</h2><p>คอมพิวเตอร์: W A S D เดิน · ลากเมาส์บนฉากเพื่อมองรอบตัว</p><p>มือถือ: ลากวงกลมซ้ายเพื่อเดิน · ลากบนฉากด้านขวาเพื่อมอง</p><p>ภายในวิหารมีจุดไหว้และตู้บริจาคเหรียญทดลอง เดินเพื่อยกเลิกการไหว้ได้ทันที</p><p>วาร์ปทั้ง 5 จุดแสดงปลายทางเดิม แต่ฉากทดลองนี้ยังไม่ย้ายไปแผนที่อื่น ใช้เหรียญทดลองแยกจากบัญชีเกม</p><button class="primary" id="help-close">เริ่มสำรวจ</button><a href="../test-main/" target="_blank" rel="noopener">เปิดเกมหลัก</a></dialog>
    <dialog id="donation"><h2>ตู้บริจาค</h2><p>ร่วมทำบุญด้วยเหรียญทดลองในฉากนี้</p><p id="balance"></p><p class="muted">ไม่มีเงินจริง และไม่มีรางวัลเพิ่มพลัง</p><div class="dialog-actions"><button id="donation-cancel">กลับ</button><button class="primary" id="donation-confirm">บริจาค 10 เหรียญทดลอง</button></div></dialog>
  </div>`;
  document.body.insertAdjacentHTML('beforeend',html);
  const $=id=>document.getElementById(id);
  const send=(type,extra={})=>{if(typeof window.cityCommand==='function')window.cityCommand(JSON.stringify({type,...extra}));};
  let mode='overview', dusk=false, lastMessage='', readyAt=0;
  document.querySelectorAll('[data-view]').forEach(button=>button.addEventListener('click',()=>{send('view',{value:button.dataset.view});document.activeElement.blur();}));
  $('dusk').onclick=()=>{dusk=!dusk;send('dusk',{value:dusk});$('dusk').classList.toggle('selected',dusk);};
  $('help-open').onclick=()=>$('help').showModal();$('help-close').onclick=()=>$('help').close();
  $('pray').onclick=()=>send('pray');
  $('donate').onclick=()=>$('donation').showModal();
  $('donation-cancel').onclick=()=>$('donation').close();
  $('donation-confirm').onclick=()=>{send('donate');$('donation').close();};
  const joy=$('joystick'), stick=$('stick');let joyPointer=null;
  const moveJoy=e=>{const r=joy.getBoundingClientRect();let x=(e.clientX-r.left-r.width/2)/38,y=(e.clientY-r.top-r.height/2)/38;const length=Math.hypot(x,y);if(length>1){x/=length;y/=length;}stick.style.transform=`translate(${x*29}px,${y*29}px)`;send('move',{x,y});};
  joy.onpointerdown=e=>{e.preventDefault();joyPointer=e.pointerId;joy.setPointerCapture(e.pointerId);moveJoy(e);};
  joy.onpointermove=e=>{if(e.pointerId===joyPointer)moveJoy(e);};
  const stopJoy=()=>{joyPointer=null;stick.style.transform='';send('move',{x:0,y:0});};
  joy.onpointerup=stopJoy;joy.onpointercancel=stopJoy;joy.onlostpointercapture=stopJoy;
  window.addEventListener('blur',stopJoy);document.addEventListener('visibilitychange',()=>{if(document.hidden)stopJoy();});
  const canvas=document.getElementById('canvas');let look=null;
  canvas.addEventListener('pointerdown',e=>{if(mode!=='walk'||e.button!==0)return;look={id:e.pointerId,x:e.clientX,y:e.clientY};canvas.setPointerCapture(e.pointerId);});
  canvas.addEventListener('pointermove',e=>{if(!look||look.id!==e.pointerId)return;send('look',{x:e.clientX-look.x,y:e.clientY-look.y});look.x=e.clientX;look.y=e.clientY;});
  const stopLook=()=>look=null;canvas.addEventListener('pointerup',stopLook);canvas.addEventListener('pointercancel',stopLook);
  document.addEventListener('click',event=>{if(event.target.closest('button')&&!document.querySelector('dialog[open]'))canvas.focus();});
  setInterval(()=>{
    if(!window.cityReady)return;
    if(!readyAt){readyAt=performance.now();window.cityLoadMs=readyAt;$('city-ui').hidden=false;}
    if(!window.cityState)return;
    let s;try{s=JSON.parse(window.cityState);}catch{return;}
    mode=s.mode;window.cityTestState=s;
    document.querySelectorAll('[data-view]').forEach(b=>b.classList.toggle('selected',b.dataset.view===(s.inside?'interior':s.mode)));
    joy.hidden=mode!=='walk';$('look-hint').hidden=mode!=='walk';
    $('area').textContent=s.inside?'วิหาร · พระประธาน':s.mode==='walk'?'ลานเมือง · เดินสำรวจ':s.mode==='temple'?'วิหารบนลานชั้นบน':'ผังเมือง 160 × 160';
    $('description').textContent=s.prayer?'กำลังไหว้พระ · เดินเพื่อยกเลิก':s.inside?'เดินเข้าหาเสื่อเพื่อไหว้พระ · ตู้บริจาคอยู่ขวาประตู':s.mode==='walk'?'W A S D / วงกลมซ้ายเพื่อเดิน':'เลือกมุมสำรวจจากแถบด้านบน';
    $('coords').textContent=`${s.x.toFixed(1)}, ${s.z.toFixed(1)}`;
    $('pray').hidden=!s.canPray;$('pray').textContent=s.prayer?'ยกเลิกไหว้':'ไหว้พระ';$('donate').hidden=!s.canDonate;
    $('balance').textContent=`เหรียญทดลองคงเหลือ ${s.coins} · บริจาคแล้ว ${s.donations}`;$('donation-confirm').disabled=s.coins<10;
    $('warp').textContent=s.portal?`จุดวาร์ปเดิม → ${s.portal} (แสดงตำแหน่งในฉากทดลอง)`:'';
    if(s.message&&s.message!==lastMessage){lastMessage=s.message;$('toast').textContent=s.message;$('toast').classList.add('show');setTimeout(()=>$('toast').classList.remove('show'),2800);}
  },120);
})();
