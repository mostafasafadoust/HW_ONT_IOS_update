(async function(){
  const ACS_URL='__ACS_URL__';
  const ACS_USER='__ACS_USER__';
  const ACS_PASS='__ACS_PASS__';
  const INTERVAL='__ACS_INTERVAL__';
  const result={ok:false, step:'acs', url:location.href, found:{}, warnings:[]};
  const sleep=ms=>new Promise(r=>setTimeout(r,ms));
  function norm(s){return String(s||'').toLowerCase().replace(/[\u200c_\-:.]+/g,' ').replace(/\s+/g,' ').trim();}
  function fire(e){['input','change','keyup','blur'].forEach(t=>e.dispatchEvent(new Event(t,{bubbles:true})));}
  function setv(e,v){if(!e)return false; e.focus&&e.focus(); e.value=v; fire(e); return true;}
  function allDocs(){const out=[document]; document.querySelectorAll('iframe,frame').forEach(f=>{try{if(f.contentDocument)out.push(f.contentDocument)}catch(e){}}); return out;}
  const docs=allDocs(); function controls(sel){return docs.flatMap(d=>Array.from(d.querySelectorAll(sel)));}
  function key(e){return norm((e.id||'')+' '+(e.name||'')+' '+(e.placeholder||'')+' '+(e.title||'')+' '+(e.value||'')+' '+((e.closest('tr,td,div,label')||{}).innerText||''));}
  function check(e,v){if(!e||e.disabled)return false; if(!!e.checked!==v)e.click(); e.checked=v; fire(e); return !!e.checked===v;}
  const enable=controls('input[type=checkbox]').find(e=>/enable.*tr|tr.*enable|cwmp|acs|inform/.test(key(e))); if(enable){check(enable,true); result.found.enable=true;}
  const edit=controls('input,textarea').filter(e=>{const t=(e.type||'').toLowerCase(); return !['hidden','button','submit','checkbox','radio','file'].includes(t)&&!e.disabled;});
  let url=edit.find(e=>/acs.*url|url.*acs|management.*url|server.*url|cwmp.*url/.test(key(e))) || edit.find(e=>/url/.test(key(e))&&!/connection.*request/.test(key(e)));
  let user=edit.find(e=>/acs.*user|user.*acs|cwmp.*user|username/.test(key(e))&&!/connection.*request|ppp|pppoe/.test(key(e)));
  let pass=edit.find(e=>/acs.*pass|pass.*acs|cwmp.*pass|password|passwd/.test(key(e))&&!/connection.*request|ppp|pppoe|wifi|wlan/.test(key(e)));
  let interval=edit.find(e=>/periodic.*inform.*interval|inform.*interval|interval/.test(key(e)));
  if(!url)return JSON.stringify({...result,error:'ACS URL field not found'}); setv(url,ACS_URL); result.found.url=url.id||url.name||'field';
  if(user){setv(user,ACS_USER); result.found.user=user.id||user.name||'field';} else result.warnings.push('ACS username field not found');
  if(pass){setv(pass,ACS_PASS); result.found.pass=pass.id||pass.name||'field';} else result.warnings.push('ACS password field not found');
  if(interval){setv(interval,INTERVAL); result.found.interval=interval.id||interval.name||'field';}
  await sleep(300);
  const apply=docs.map(d=>d.getElementById('ButtonApply')).find(Boolean) || controls('button,input[type=button],input[type=submit]').find(e=>/buttonapply|apply|save|submit|ذخیره|اعمال/.test(key(e)));
  if(!apply)return JSON.stringify({...result,error:'ACS Apply button not found'});
  window.__tivanAcsMessages=[]; window.alert=m=>window.__tivanAcsMessages.push(String(m||'')); window.confirm=m=>{window.__tivanAcsMessages.push('CONFIRM: '+String(m||'')); return true;};
  apply.disabled=false; apply.click(); await sleep(800);
  result.messages=(window.__tivanAcsMessages||[]).slice(0,20);
  result.ok=true; return JSON.stringify(result);
})();
