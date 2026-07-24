(async function(){
  const USER='__WEB_USER__';
  const PASS='__WEB_PASS__';
  const result={ok:false, step:'login', url:location.href, warnings:[], found:{}};
  const sleep=ms=>new Promise(r=>setTimeout(r,ms));
  function norm(s){return String(s||'').toLowerCase().replace(/[_\-:.]+/g,' ').replace(/\s+/g,' ').trim();}
  function fire(e){['input','change','keyup','blur'].forEach(t=>e.dispatchEvent(new Event(t,{bubbles:true})));}
  function setv(e,v){if(!e)return false; e.focus&&e.focus(); e.value=v; fire(e); return true;}
  function allDocs(){const out=[document]; document.querySelectorAll('iframe,frame').forEach(f=>{try{if(f.contentDocument)out.push(f.contentDocument)}catch(e){}}); return out;}
  function controls(sel){return allDocs().flatMap(d=>Array.from(d.querySelectorAll(sel)).filter(e=>e.offsetParent!==null || e.type==='hidden' || sel.includes('input')));}
  function key(e){return norm((e.id||'')+' '+(e.name||'')+' '+(e.placeholder||'')+' '+(e.title||'')+' '+(e.value||'')+' '+((e.closest('td,div,tr,label')||{}).innerText||''));}
  let user=controls('input').find(e=>/user|account|login|name/.test(key(e)) && !/password|pass/.test(key(e)) && !['hidden','button','submit','checkbox','radio'].includes((e.type||'').toLowerCase()));
  let pass=controls('input').find(e=>(e.type||'').toLowerCase()==='password' || /password|passwd|pass/.test(key(e)));
  if(!user){user=controls('input').find(e=>!['hidden','button','submit','checkbox','radio','password'].includes((e.type||'').toLowerCase()));}
  if(!pass){return JSON.stringify({...result,error:'Password input not found', inputs:controls('input').slice(0,20).map(e=>key(e))});}
  setv(user,USER); setv(pass,PASS);
  result.found.user=user.id||user.name||'field';
  result.found.pass=pass.id||pass.name||'field';
  await sleep(250);
  let btn=controls('button,input[type=button],input[type=submit]').find(e=>/login|log in|submit|sign|ورود|تایید|apply/.test(key(e)));
  if(!btn && pass.form){btn=pass.form.querySelector('input[type=submit],button,input[type=button]');}
  if(!btn){
    pass.dispatchEvent(new KeyboardEvent('keydown',{key:'Enter',bubbles:true}));
    result.warnings.push('Login button not found; Enter sent');
  } else {
    btn.disabled=false;
    btn.click();
    result.found.button=btn.id||btn.name||btn.value||btn.innerText||'button';
  }
  result.ok=true;
  return JSON.stringify(result);
})();
