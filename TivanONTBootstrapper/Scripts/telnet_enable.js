(async function(){
  const result={ok:false, step:'enable_telnet', url:location.href, found:{}, warnings:[]};
  const sleep=ms=>new Promise(r=>setTimeout(r,ms));
  function norm(s){return String(s||'').toLowerCase().replace(/[\u200c_\-:.]+/g,' ').replace(/\s+/g,' ').trim();}
  function fire(e){['input','change','blur'].forEach(t=>e.dispatchEvent(new Event(t,{bubbles:true})));}
  function allDocs(){const out=[document]; document.querySelectorAll('iframe,frame').forEach(f=>{try{if(f.contentDocument)out.push(f.contentDocument)}catch(e){}}); return out;}
  const docs=allDocs(); function controls(sel){return docs.flatMap(d=>Array.from(d.querySelectorAll(sel)));}
  function key(e){return norm((e.id||'')+' '+(e.name||'')+' '+(e.value||'')+' '+(e.title||'')+' '+((e.closest('tr,td,div,label')||{}).innerText||''));}
  function check(e,v){if(!e||e.disabled)return false; if(!!e.checked!==v)e.click(); e.checked=v; fire(e); return !!e.checked===v;}
  const tel=controls('input[type=checkbox],input[type=radio]').find(e=>/telnet/.test(key(e)) && !/stelnet/.test(key(e)));
  if(tel){check(tel,true); result.found.telnet=key(tel).slice(0,90);} else result.warnings.push('Telnet checkbox not found');
  const ssh=controls('input[type=checkbox],input[type=radio]').find(e=>/(^| )ssh( |$)|stelnet/.test(key(e)));
  if(ssh){check(ssh,true); result.found.ssh=key(ssh).slice(0,90);}
  await sleep(300);
  const apply=docs.map(d=>d.getElementById('ButtonApply')).find(Boolean) || controls('button,input[type=button],input[type=submit]').find(e=>/buttonapply|apply|save|submit|ذخیره|اعمال/.test(key(e)));
  if(apply){apply.disabled=false; apply.click(); await sleep(700); result.found.apply=true;}
  result.ok=true; return JSON.stringify(result);
})();
