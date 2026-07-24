(async function(){
  const USER='__PPPOE_USER__';
  const PASS='__PPPOE_PASS__';
  const VLAN='__VLAN__';
  const CLEANUP=__CLEANUP__;
  const result={ok:false, step:'wan', url:location.href, warnings:[], selected:{}, found:{}};
  const sleep=ms=>new Promise(r=>setTimeout(r,ms));
  function norm(s){return String(s||'').toLowerCase().replace(/[\u200c_\-:./]+/g,' ').replace(/\s+/g,' ').trim();}
  function canon(s){return norm(s).replace(/tr 069/g,'tr069').replace(/[^a-z0-9]+/g,'_').replace(/^_+|_+$/g,'');}
  function fire(e){['input','change','keyup','blur'].forEach(t=>e.dispatchEvent(new Event(t,{bubbles:true})));}
  function setv(e,v){if(!e)return false; e.focus&&e.focus(); e.value=v; fire(e); return true;}
  function allDocs(){const out=[document]; document.querySelectorAll('iframe,frame').forEach(f=>{try{if(f.contentDocument)out.push(f.contentDocument)}catch(e){}}); return out;}
  const docs=allDocs();
  function controls(sel){return docs.flatMap(d=>Array.from(d.querySelectorAll(sel)));}
  function rowText(e){return norm(((e.closest('tr,tbody,table,div')||{}).innerText||'')+' '+(e.id||'')+' '+(e.name||'')+' '+(e.value||'')+' '+(e.title||''));}
  function key(e){return rowText(e)+' '+norm((e.placeholder||'')+' '+(e.getAttribute('aria-label')||''));}
  function check(e,v){if(!e||e.disabled)return false; if(!!e.checked!==v)e.click(); e.checked=v; fire(e); return !!e.checked===v;}
  function findInput(words){return controls('input,textarea').find(e=>{const t=(e.type||'').toLowerCase(); return !['hidden','button','submit','checkbox','radio','file'].includes(t) && words.every(w=>key(e).includes(w));});}
  function findCheckbox(words){return controls('input[type=checkbox]').find(e=>words.every(w=>key(e).includes(w)));}
  function chooseSelect(sel, words){if(!sel)return null; const opts=Array.from(sel.options||[]); const o=opts.find(o=>words.every(w=>norm(o.text+' '+o.value).includes(w))); if(o){sel.value=o.value; fire(sel); return o.text||o.value;} return null;}
  function clickChoice(words, all){let cand=controls('input[type=radio],input[type=checkbox],button,input[type=button],a').map(e=>({e,t:key(e)})).filter(x=>all?words.every(w=>x.t.includes(w)):words.some(w=>x.t.includes(w))); if(!cand.length)return null; cand.sort((a,b)=>a.t.length-b.t.length); const e=cand[0].e; if(e.type==='radio'||e.type==='checkbox')check(e,true); else e.click(); return cand[0].t;}
  if(CLEANUP){
    const rows=controls('tr').filter(r=>/yaraacs|800|tr069|tr 069|pppoe/.test(norm(r.innerText||'')));
    for(const r of rows.slice(0,6)){
      const t=norm(r.innerText||'');
      const del=Array.from(r.querySelectorAll('input,button,a')).find(e=>/delete|remove|del|حذف/.test(key(e)));
      const cb=r.querySelector('input[type=checkbox]');
      if(cb && /yaraacs|800|tr069|tr 069/.test(t)){check(cb,true); result.warnings.push('Duplicate/old WAN row selected for delete: '+t.slice(0,80));}
      if(del && /yaraacs|800/.test(t)){del.click(); result.warnings.push('Delete clicked for duplicate WAN row'); await sleep(800);}
    }
    const globalDel=controls('input,button,a').find(e=>/delete|remove|del|حذف/.test(key(e)));
    if(globalDel && result.warnings.some(w=>/selected/.test(w))){globalDel.click(); await sleep(1200);}
  }
  let add=controls('input,button,a').find(e=>/new|add|create|wan.*add|افزودن|جدید/.test(key(e)) && !/delete|remove/.test(key(e)));
  if(add){add.disabled=false; add.click(); result.found.add=key(add).slice(0,80); await sleep(1700);}
  let routeSel=controls('select').find(s=>Array.from(s.options||[]).some(o=>/route/.test(norm(o.text+' '+o.value))));
  result.selected.route=chooseSelect(routeSel,['route']) || clickChoice(['route','wan'],true) || clickChoice(['route'],false) || 'default';
  await sleep(500);
  let pppSel=controls('select').find(s=>Array.from(s.options||[]).some(o=>/pppoe/.test(norm(o.text+' '+o.value))));
  result.selected.pppoe=chooseSelect(pppSel,['pppoe']) || clickChoice(['pppoe'],false);
  if(!result.selected.pppoe)return JSON.stringify({...result,error:'PPPoE control not found'});
  await sleep(700);
  const wanted='tr069_voip_internet';
  let serviceSel=controls('select').find(s=>Array.from(s.options||[]).some(o=>{const c=canon((o.text||'')+'_'+(o.value||'')); return c.includes('tr069')&&c.includes('voip')&&c.includes('internet');}));
  if(serviceSel){const o=Array.from(serviceSel.options).find(o=>{const c=canon((o.text||'')+'_'+(o.value||''));return c.includes('tr069')&&c.includes('voip')&&c.includes('internet');}); if(o){serviceSel.value=o.value; fire(serviceSel); result.selected.service=canon(o.text||o.value);}}
  if(result.selected.service!==wanted){['tr069','voip','internet'].forEach(w=>{const c=controls('input[type=checkbox],input[type=radio]').find(e=>canon(key(e)).includes(w)); if(c)check(c,true);}); result.selected.service='tr069_voip_internet_controls';}
  const en=findCheckbox(['enable','wan']); if(en){check(en,true); result.found.enableWan=true;}
  const vlanEn=findCheckbox(['vlan'])||findCheckbox(['enable','vlan']); if(vlanEn){check(vlanEn,true); result.found.vlanEnable=true;}
  let vlan=findInput(['vlan','id']) || controls('input').find(e=>/vlan.*id|vid/.test(key(e))&&!['checkbox','radio','button','submit','hidden'].includes((e.type||'').toLowerCase()));
  if(!vlan)return JSON.stringify({...result,error:'VLAN ID field not found'}); setv(vlan,VLAN); result.found.vlan=vlan.id||vlan.name||'field';
  const editable=controls('input,textarea').filter(e=>{const t=(e.type||'').toLowerCase();return !['checkbox','radio','button','submit','hidden','file'].includes(t)&&!e.disabled;});
  let u=editable.find(e=>!/client|dhcp|vendor|host|acs|connection/.test(key(e)) && /ppp.*user|user.*ppp|pppoe.*account|username|user name/.test(key(e)));
  if(!u)return JSON.stringify({...result,error:'PPPoE username field not found'}); setv(u,USER); result.found.pppoeUser=u.id||u.name||'field';
  let p=editable.find(e=>!/connection|acs|wifi|wlan|login/.test(key(e)) && /ppp.*pass|pass.*ppp|pppoe.*pass|password|passwd/.test(key(e)));
  if(!p)return JSON.stringify({...result,error:'PPPoE password field not found'}); setv(p,PASS); result.found.pppoePass=p.id||p.name||'field';
  const binding={lan:[],wlan:[],missing:[],disabled:[],unchecked:[]};
  for(let i=1;i<=16;i++){
    const id='IPv4BindLanList'+i;
    const e=docs.map(d=>d.getElementById(id)).find(Boolean) || controls('[name="IPv4BindLanList"]').filter(x=>x.type==='checkbox')[i-1];
    const label=i<=8?'LAN'+i:'SSID'+(i-8);
    if(!e){binding.missing.push(label);continue;} if(e.disabled){binding.disabled.push(label);continue;}
    if(check(e,true)){(i<=8?binding.lan:binding.wlan).push(label);} else binding.unchecked.push(label);
  }
  result.found.bindingControls=binding;
  const mtu=controls('input').find(e=>/mtu/.test(key(e))); if(mtu&&!String(mtu.value||'').trim())setv(mtu,'1492');
  window.__tivanWanMessages=[]; const oldAlert=window.alert; const oldConfirm=window.confirm; window.alert=m=>window.__tivanWanMessages.push(String(m||'')); window.confirm=m=>{window.__tivanWanMessages.push('CONFIRM: '+String(m||'')); return true;};
  const apply=docs.map(d=>d.getElementById('ButtonApply')).find(Boolean) || controls('button,input[type=button],input[type=submit]').find(e=>/buttonapply|apply|save|submit|ذخیره|اعمال/.test(key(e)));
  if(!apply)return JSON.stringify({...result,error:'Apply button not found'});
  apply.disabled=false; apply.click(); await sleep(800);
  result.messages=(window.__tivanWanMessages||[]).slice(0,20);
  result.ok=true; return JSON.stringify(result);
})();
