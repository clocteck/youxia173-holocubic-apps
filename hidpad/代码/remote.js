(() => {
  'use strict';
  const $ = id => document.getElementById(id);
  const buttons = [...document.querySelectorAll('[data-bit]')];
  let storage;
  try { storage=window.localStorage; } catch { /* Session-only mapping remains available. */ }
  const keymap=RemoteKeymap.create(storage);
  const buttonKeys={1:'up',2:'down',4:'left',8:'right',16:'a',32:'b',64:'x',128:'y',256:'lb',512:'rb',1024:'l3',2048:'r3',4096:'view',8192:'menu',16384:'share',32768:'home'};
  const COPY={
    'zh-CN':{language:'语言',followDevice:'跟随设备',title:'网页手柄',author:'作者：游侠173',pageTitle:'HoloCubic 网页手柄',connect:'接管手柄',disconnect:'退出接管',intro:'接管后，用下方按钮控制设备当前应用。',edit:'键盘改键',editDone:'完成改键',reset:'恢复默认',cancelBind:'取消本次绑定',clearBind:'清除该键绑定',hintIdle:'点击“键盘改键”，再点手柄按钮并按下要绑定的键。',hintEdit:'点击要修改的手柄按钮，再按下键盘上的键。',unbound:'未绑定',clickToBind:'，点击改键',setting:'正在设置 {0}：请按下要绑定的键，或点击取消。',unknownKey:'无法识别这个键，请换一个键。',cannotBind:'无法绑定这个键，请换一个键。',bound:'{0} 已绑定 {1}{2}。{3}可继续点击其他按钮。',moved:'，已从 {0} 移除此键',saved:'已自动保存。',sessionOnly:'当前会话有效，浏览器无法保存。',cleared:'{0} 的键盘绑定已清除。{1}',resetDone:'已恢复默认键盘映射。{0}',statusIdle:'未接管',statusActive:'网页已接管',statusRecover:'正在恢复连接',taking:'正在接管…',taken:'已接管，可操作下方按键。',takeFailed:'接管失败，请再试一次。',released:'已退出接管，实体手柄恢复控制。',blur:'页面失去焦点，已自动松开。需要时重新接管。',hidden:'页面已进入后台，已退出接管。',deviceBusy:'设备暂时无法响应',back:'返回启动器',padHint:'支持多指同时按、长按与松开。每个按钮下方显示键盘绑定，可自定义并自动保存在当前浏览器。LB/RB 为肩键，L3/R3 为摇杆按下；View 对应 SELECT，Menu 对应 START。黄金矿工：A 放钩，↓ 使用炸药，View 退出。',sessionHint:'接管期间，实体蓝牙手柄暂停输入；退出接管后恢复。关闭页面、切到后台或断线后会自动松开。仅控制已支持手柄的应用。',reading:'正在读取设备…',current:'当前：{0}',launcher:'启动器',offline:'设备暂时无法连接',chooseApp:'选择应用',open:'打开',pickFirst:'先选择要打开的应用。',opening:'正在打开应用。',openFailed:'打开失败，请确认设备已连接。',backFailed:'返回失败，请确认设备已连接。',settingsLink:'蓝牙手柄设置',readyNote:'设备 IP 即开即用',padLabel:'手柄按键',up:'上',down:'下',left:'左',right:'右',a:'A',b:'B',x:'X',y:'Y',lb:'LB',rb:'RB',l3:'L3',r3:'R3',view:'View',menu:'Menu',share:'Share',home:'Home',listSep:'、'},
    'zh-TW':{language:'語言',followDevice:'跟隨裝置',title:'網頁手把',author:'作者：遊俠173',pageTitle:'HoloCubic 網頁手把',connect:'接管手把',disconnect:'退出接管',intro:'接管後，用下方按鈕控制裝置目前的應用。',edit:'鍵盤改鍵',editDone:'完成改鍵',reset:'恢復預設',cancelBind:'取消這次綁定',clearBind:'清除此鍵綁定',hintIdle:'點選「鍵盤改鍵」，再點手把按鈕並按下要綁定的鍵。',hintEdit:'點選要修改的手把按鈕，再按下鍵盤上的鍵。',unbound:'未綁定',clickToBind:'，點選改鍵',setting:'正在設定 {0}：請按下要綁定的鍵，或點選取消。',unknownKey:'無法辨識這個鍵，請換一個鍵。',cannotBind:'無法綁定這個鍵，請換一個鍵。',bound:'{0} 已綁定 {1}{2}。{3}可繼續點選其他按鈕。',moved:'，已從 {0} 移除此鍵',saved:'已自動儲存。',sessionOnly:'目前工作階段有效，瀏覽器無法儲存。',cleared:'{0} 的鍵盤綁定已清除。{1}',resetDone:'已恢復預設鍵盤對應。{0}',statusIdle:'未接管',statusActive:'網頁已接管',statusRecover:'正在恢復連線',taking:'正在接管…',taken:'已接管，可操作下方按鍵。',takeFailed:'接管失敗，請再試一次。',released:'已退出接管，實體手把恢復控制。',blur:'頁面失去焦點，已自動鬆開。需要時重新接管。',hidden:'頁面已進入背景，已退出接管。',deviceBusy:'裝置暫時無法回應',back:'返回啟動器',padHint:'支援多指同時按、長按與鬆開。每個按鈕下方顯示鍵盤綁定，可自訂並自動儲存在目前瀏覽器。LB/RB 為肩鍵，L3/R3 為搖桿按下；View 對應 SELECT，Menu 對應 START。黃金礦工：A 放鉤，↓ 使用炸藥，View 退出。',sessionHint:'接管期間，實體藍牙手把暫停輸入；退出接管後恢復。關閉頁面、切到背景或斷線後會自動鬆開。僅控制已支援手把的應用。',reading:'正在讀取裝置…',current:'目前：{0}',launcher:'啟動器',offline:'裝置暫時無法連線',chooseApp:'選擇應用',open:'開啟',pickFirst:'先選擇要開啟的應用。',opening:'正在開啟應用。',openFailed:'開啟失敗，請確認裝置已連線。',backFailed:'返回失敗，請確認裝置已連線。',settingsLink:'藍牙手把設定',readyNote:'裝置 IP 開啟即可使用',padLabel:'手把按鍵',up:'上',down:'下',left:'左',right:'右',a:'A',b:'B',x:'X',y:'Y',lb:'LB',rb:'RB',l3:'L3',r3:'R3',view:'View',menu:'Menu',share:'Share',home:'Home',listSep:'、'},
    en:{language:'Language',followDevice:'Device language',title:'Web Pad',author:'Author: youxia173',pageTitle:'HoloCubic Web Pad',connect:'Take control',disconnect:'Release',intro:'After taking control, use the buttons below to play the current app.',edit:'Edit keys',editDone:'Done',reset:'Reset',cancelBind:'Cancel binding',clearBind:'Clear this key',hintIdle:'Choose Edit keys, click a pad button, then press a keyboard key.',hintEdit:'Click a pad button, then press the keyboard key to bind.',unbound:'Unbound',clickToBind:', click to rebind',setting:'Binding {0}: press a key, or click cancel.',unknownKey:'That key was not recognized. Try another.',cannotBind:'Cannot bind that key. Try another.',bound:'{0} is bound to {1}{2}. {3}You can bind another button.',moved:', removed from {0}',saved:'Saved in this browser. ',sessionOnly:'Kept for this visit only. ',cleared:'Cleared the keyboard binding for {0}. {1}',resetDone:'Restored the default keyboard mapping. {0}',statusIdle:'Not in control',statusActive:'Web pad active',statusRecover:'Reconnecting',taking:'Taking control…',taken:'In control. Use the buttons below.',takeFailed:'Could not take control. Try again.',released:'Released. The Bluetooth controller can play again.',blur:'The page lost focus and the buttons were released. Take control again when you return.',hidden:'The page moved to the background and released control.',deviceBusy:'The device did not respond',back:'Back to launcher',padHint:'Several fingers, holds, and releases all work. Each button shows its keyboard binding, saved in this browser. LB/RB are shoulders, L3/R3 are stick clicks. View is SELECT and Menu is START. In Gold Miner, A drops the hook, Down uses dynamite, and View exits.',sessionHint:'While this page has control, the Bluetooth controller is paused. Closing the page, switching away, or losing the connection releases every button. Only apps that already read the controller will respond.',reading:'Reading the device…',current:'Now: {0}',launcher:'Launcher',offline:'Cannot reach the device',chooseApp:'Choose an app',open:'Open',pickFirst:'Choose an app first.',opening:'Opening the app.',openFailed:'Could not open it. Check that the device is connected.',backFailed:'Could not return. Check that the device is connected.',settingsLink:'Bluetooth controller',readyNote:'Open this page on the device IP',padLabel:'Controller',up:'Up',down:'Down',left:'Left',right:'Right',a:'A',b:'B',x:'X',y:'Y',lb:'LB',rb:'RB',l3:'L3',r3:'R3',view:'View',menu:'Menu',share:'Share',home:'Home',listSep:', '},
    ja:{language:'言語',followDevice:'デバイスの設定',title:'ウェブパッド',author:'作者：youxia173',pageTitle:'HoloCubic ウェブパッド',connect:'操作を開始',disconnect:'操作を終了',intro:'操作を開始すると、下のボタンで今のアプリを操作できます。',edit:'キー変更',editDone:'変更完了',reset:'初期化',cancelBind:'この割り当てを取消',clearBind:'このキーを解除',hintIdle:'「キー変更」を押し、パッドのボタンを選んでからキーボードのキーを押します。',hintEdit:'変更するパッドのボタンを押し、割り当てるキーを押します。',unbound:'未設定',clickToBind:'、クリックで変更',setting:'{0} を設定中：キーを押すか、キャンセルを押してください。',unknownKey:'このキーは認識できません。別のキーを試してください。',cannotBind:'このキーは割り当てできません。別のキーを試してください。',bound:'{0} を {1} に割り当てました{2}。{3}ほかのボタンも続けて設定できます。',moved:'。{0} から外しました',saved:'このブラウザに保存しました。',sessionOnly:'この表示中だけ有効です。',cleared:'{0} のキーボード割り当てを解除しました。{1}',resetDone:'キーボード割り当てを初期化しました。{0}',statusIdle:'未操作',statusActive:'ウェブ操作中',statusRecover:'再接続中',taking:'操作を開始しています…',taken:'操作できます。下のボタンを使ってください。',takeFailed:'開始できませんでした。もう一度試してください。',released:'操作を終了しました。Bluetooth コントローラーが使えます。',blur:'ページが非アクティブになり、ボタンを離しました。戻ったら再度開始してください。',hidden:'ページが背面に移ったため、操作を終了しました。',deviceBusy:'デバイスが応答しません',back:'ランチャーへ戻る',padHint:'複数の指、長押し、離す操作に対応します。各ボタンの下にキーボード割り当てを表示し、このブラウザに保存します。LB/RB は肩ボタン、L3/R3 はスティック押し込みです。View は SELECT、Menu は START です。ゴールドマイナーでは A でフック、↓ で爆弾、View で終了です。',sessionHint:'このページが操作中は、Bluetooth コントローラーの入力を止めます。ページを閉じる、背面に移る、接続が切れるとすべてのボタンを離します。コントローラー対応のアプリだけが反応します。',reading:'デバイスを読み込み中…',current:'現在：{0}',launcher:'ランチャー',offline:'デバイスに接続できません',chooseApp:'アプリを選択',open:'開く',pickFirst:'先にアプリを選択してください。',opening:'アプリを開いています。',openFailed:'開けませんでした。デバイスの接続を確認してください。',backFailed:'戻れませんでした。デバイスの接続を確認してください。',settingsLink:'Bluetooth コントローラー',readyNote:'デバイスの IP で開けます',padLabel:'コントローラー',up:'上',down:'下',left:'左',right:'右',a:'A',b:'B',x:'X',y:'Y',lb:'LB',rb:'RB',l3:'L3',r3:'R3',view:'View',menu:'Menu',share:'Share',home:'Home',listSep:'、'}
  };
  let languageChoice='device', deviceLanguage='zh-CN', lang='zh-CN', messageKey='intro', messageArgs=[];
  try { languageChoice=localStorage.getItem('hidpad.language')||'device'; } catch { /* Follow the device until the browser allows storage. */ }
  if (languageChoice!=='device' && !COPY[languageChoice]) languageChoice='device';
  function t(key,...args){let value=(COPY[lang]&&COPY[lang][key])||COPY['zh-CN'][key]||key;args.forEach((arg,index)=>{value=value.replaceAll(`{${index}}`,arg);});return value;}
  function buttonName(bit){return t(buttonKeys[bit]||'a');}
  let editMode=false, mappingTarget=null;
  for (const button of buttons) {
    const bit=Number(button.dataset.bit);
    button.setAttribute('aria-label',buttonName(bit));
    const binding=document.createElement('span'); binding.className='key-binding'; binding.setAttribute('aria-hidden','true');
    button.append(binding);
  }
  function renderBindings() {
    for (const button of buttons) {
      const bit=Number(button.dataset.bit),keys=keymap.keys(bit).map(RemoteKeymap.label);
      button.querySelector('.key-binding').textContent=keys.join(' / ') || t('unbound');
      button.title=`${buttonName(bit)}: ${keys.join(' / ') || t('unbound')}${editMode?t('clickToBind'):''}`;
      button.classList.toggle('awaiting',bit===mappingTarget);
    }
    $('editMapping').textContent=editMode?t('editDone'):t('edit');
    $('editMapping').setAttribute('aria-pressed',String(editMode));
    $('cancelMapping').hidden=mappingTarget===null;
    $('clearMapping').hidden=mappingTarget===null;
  }
  function mappingHint(text) { $('mappingHint').textContent=text; }
  function cancelCapture() {
    mappingTarget=null; renderBindings();
    mappingHint(editMode?t('hintEdit'):t('hintIdle'));
  }
  const client = globalThis.crypto?.randomUUID?.() || `web-${Date.now()}-${Math.random().toString(36).slice(2)}`;
  let seq=0, active=false, ready=false, generation=0, queue=Promise.resolve(), inFlight=0, lastMask=0, lastRefresh=0, renewing=false;
  const held=new Map(), releaseTimers=new Map();
  let chineseNames={};
  const endpoint='/hidpad/api/remote';
  function show(key,...args) { messageKey=key; messageArgs=args; $('message').textContent=t(key,...args); }
  function ui() {
    $('status').textContent=active?(ready?t('statusActive'):t('statusRecover')):t('statusIdle');
    $('status').classList.toggle('active',active);
    $('connect').disabled=active; $('disconnect').disabled=!active;
    for (const button of buttons) {
      button.disabled=!editMode && (!active || !ready);
      button.classList.toggle('pressed',(lastMask & Number(button.dataset.bit))!==0);
    }
  }
  function clearHeld() {
    for (const timer of releaseTimers.values()) clearTimeout(timer);
    releaseTimers.clear(); held.clear(); lastMask=0;
  }
  async function jsonRequest(url,options={},timeout=5000) {
    const controller=new AbortController(),timer=setTimeout(()=>controller.abort(),timeout);
    try {
      const response=await fetch(url,{cache:'no-store',...options,signal:controller.signal});
      const result=await response.json();
      if (!response.ok || result.ok===false) throw new Error(result.error || t('deviceBusy'));
      return result;
    } finally { clearTimeout(timer); }
  }
  function releaseBeacon() {
    const body=JSON.stringify({client,seq:++seq,buttons:0,release:true});
    if (navigator.sendBeacon) navigator.sendBeacon(endpoint,new Blob([body],{type:'application/json'}));
    else fetch(endpoint,{method:'POST',body,headers:{'Content-Type':'application/json'},keepalive:true}).catch(()=>{});
  }
  function stop(message) {
    const wasActive=active; active=false; ready=false; generation++; clearHeld(); ui();
    if (wasActive) releaseBeacon();
    cancelCapture();
    if (message) show(message);
  }
  function scheduleRenew() {
    if (renewing || !active) return;
    renewing=true;
    const finish=()=>{ renewing=false; };
    send(lastMask,{takeover:true,quiet:true}).catch(error=>{
      if (!active || !String(error.message||'').includes('released buttons')) return;
      return send(0,{takeover:true,quiet:true}).then(()=>{ if (active && lastMask) return send(lastMask); });
    }).then(finish,finish);
  }
  function send(mask,extra={}) {
    const version=generation,doc={client,seq:++seq,buttons:mask,...extra};
    inFlight++;
    const job=queue.then(async()=>{
      if (version!==generation) return;
      const result=await jsonRequest(endpoint,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(doc)});
      if (version!==generation) return;
      if (extra.takeover) {
        active=true; ready=true; ui();
        if (!extra.quiet) { $('connect').blur(); show('taken'); }
      }
      return result;
    });
    queue=job.catch(()=>{});
    return job.catch(error=>{
      console.warn('Web controller request failed:',error.message);
      const message=String(error.message||'');
      const lost=message.includes('expired') || message.includes('another session');
      if (version===generation && active && lost && !extra.takeover) scheduleRenew();
      throw error;
    }).finally(()=>{ inFlight--; });
  }
  function update() {
    let mask=0;
    for (const entry of held.values()) mask|=entry.bit;
    if (mask===lastMask) return;
    lastMask=mask; ui();
    if (active) send(mask).catch(()=>{});
  }
  function press(id,bit) {
    if (editMode || !active || !ready || held.has(id)) return;
    held.set(id,{bit,at:performance.now()}); update();
  }
  function release(id) {
    const entry=held.get(id);
    if (!entry || releaseTimers.has(id)) return;
    // A brief tap must remain visible to apps polling the controller every 40–50ms.
    const delay=Math.max(0,110-(performance.now()-entry.at));
    releaseTimers.set(id,setTimeout(()=>{ releaseTimers.delete(id); held.delete(id); update(); },delay));
  }
  for (const button of buttons) {
    button.addEventListener('pointerdown',event=>{
      if (editMode) return;
      if (!active || event.button!==0) return;
      event.preventDefault(); button.setPointerCapture(event.pointerId);
      press(`p${event.pointerId}`,Number(button.dataset.bit));
    });
    for (const name of ['pointerup','pointercancel','lostpointercapture'])
      button.addEventListener(name,event=>{ event.preventDefault(); release(`p${event.pointerId}`); });
    button.addEventListener('contextmenu',event=>event.preventDefault());
    // Keyboard and assistive-technology activation of a focused button.
    button.addEventListener('click',event=>{
      if (editMode) {
        mappingTarget=Number(button.dataset.bit); renderBindings();
        mappingHint(t('setting', buttonName(mappingTarget)));
        return;
      }
      if (event.detail===0 && active) { const id=`click-${++seq}`; press(id,Number(button.dataset.bit)); release(id); }
    });
  }
  function editable(target) { return target && (target.isContentEditable || /INPUT|SELECT|TEXTAREA|BUTTON/.test(target.tagName)); }
  window.addEventListener('keydown',event=>{
    if (editMode && mappingTarget!==null) {
      event.preventDefault(); event.stopImmediatePropagation();
      if (event.repeat) return;
      if (!event.code || event.code==='Unidentified') { mappingHint(t('unknownKey')); return; }
      try {
        const target=mappingTarget,result=keymap.bind(target,event.code);
        mappingTarget=null; renderBindings(); document.activeElement?.blur();
        const moved=result.previous.length?t('moved', result.previous.map(buttonName).join(t('listSep'))):'';
        mappingHint(t('bound', buttonName(target), RemoteKeymap.label(event.code), moved, result.saved?t('saved'):t('sessionOnly')));
      } catch { mappingHint(t('cannotBind')); }
      return;
    }
    const bit=keymap.bitFor(event.code);
    if (editMode || !active || !bit || editable(event.target)
      || (event.ctrlKey && !event.code.startsWith('Control'))
      || (event.metaKey && !event.code.startsWith('Meta'))
      || (event.altKey && !event.code.startsWith('Alt'))) return;
    event.preventDefault(); if (!event.repeat) press(`k${event.code}`,bit);
  },true);
  window.addEventListener('keyup',event=>{
    if (held.has(`k${event.code}`)) { event.preventDefault(); release(`k${event.code}`); }
  });
  $('editMapping').onclick=()=>{
    clearHeld(); if (active) send(0).catch(()=>{});
    editMode=!editMode; cancelCapture(); ui(); $('editMapping').blur();
  };
  $('cancelMapping').onclick=cancelCapture;
  $('clearMapping').onclick=()=>{
    if (mappingTarget===null) return;
    const target=mappingTarget,saved=keymap.clear(target); cancelCapture();
    mappingHint(t('cleared', buttonName(target), saved?t('saved'):t('sessionOnly')));
  };
  $('resetMapping').onclick=()=>{
    clearHeld(); if (active) send(0).catch(()=>{});
    const saved=keymap.reset(); cancelCapture(); ui(); $('resetMapping').blur();
    mappingHint(t('resetDone', saved?t('saved'):t('sessionOnly')));
  };
  $('connect').onclick=()=>{
    generation++; clearHeld(); ui(); $('connect').disabled=true; show('taking');
    send(0,{takeover:true}).catch(()=>{ if (!active) { ui(); show('takeFailed'); } });
  };
  $('disconnect').onclick=()=>stop('released');
  window.addEventListener('blur',()=>stop('blur'));
  window.addEventListener('pagehide',()=>stop());
  document.addEventListener('visibilitychange',()=>{ if (document.hidden) stop('hidden'); });
  setInterval(()=>{ if (active && !renewing && inFlight===0) send(lastMask).catch(()=>{}); },400);
  async function refreshApps() {
    lastRefresh=Date.now();
    try {
      const [state,localized]=await Promise.all([
        jsonRequest('/api/system/state'),
        jsonRequest('/hidpad/api/app-names').catch(()=>null)
      ]);
      if (localized?.names) chineseNames=localized.names;
      const localizedName=id=>{
        const entry=chineseNames[id];
        if (entry && typeof entry==='object') return entry[lang] || entry['zh-CN'] || entry.en || id;
        if ((lang==='zh-CN' || lang==='zh-TW') && typeof entry==='string' && entry) return entry;
        return '';
      };
      const appName=app=>localizedName(app.id) || (lang==='ja'&&app.name_ja) || (lang==='en'&&app.name_en) || (lang==='zh-TW'&&(app.name_zh_tw||app.name_zh_hant)) || app.name_zh_cn || app.name_zh || app.name || app.id;
      $('current').textContent=t('current', state.current_app?appName(state.current_app):t('launcher'));
      const apps=(state.apps || []).filter(app=>!app.kind || app.kind==='app');
      const select=$('apps'), selected=select.value;
      const signature=lang+JSON.stringify(apps.map(app=>[app.id,appName(app)]));
      if (select.dataset.signature!==signature) {
        select.replaceChildren(new Option(t('chooseApp'),''));
        for (const app of apps) select.add(new Option(appName(app),app.id));
        select.value=selected; select.dataset.signature=signature;
      }
      select.setAttribute('aria-label', t('chooseApp'));
    } catch { $('current').textContent=t('offline'); }
  }
  $('launch').onclick=async()=>{
    const id=$('apps').value; if (!id) { show('pickFirst'); return; }
    try { clearHeld(); ui(); if (active) await send(0); await jsonRequest(`/api/system/launch?id=${encodeURIComponent(id)}`,{method:'POST'}); show('opening'); setTimeout(refreshApps,500); }
    catch { show('openFailed'); }
  };
  $('backLauncher').onclick=async()=>{
    try { clearHeld(); ui(); if (active) await send(0); await jsonRequest('/api/system/exit',{method:'POST'}); setTimeout(refreshApps,500); }
    catch { show('backFailed'); }
  };
  function applyLanguage() {
    const choice=languageChoice==='device'?deviceLanguage:languageChoice;
    lang=COPY[choice]?choice:'zh-CN';
    document.documentElement.lang=lang;
    document.title=t('pageTitle');
    document.querySelectorAll('[data-t]').forEach(el=>{ el.textContent=t(el.dataset.t); });
    document.querySelectorAll('[data-aria]').forEach(el=>el.setAttribute('aria-label', t(el.dataset.aria)));
    $('language').value=languageChoice;
    $('language').setAttribute('aria-label', t('language'));
    if (messageKey) $('message').textContent=t(messageKey, ...messageArgs);
    mappingHint(mappingTarget!==null?t('setting', buttonName(mappingTarget)):(editMode?t('hintEdit'):t('hintIdle')));
    for (const button of buttons) button.setAttribute('aria-label', buttonName(Number(button.dataset.bit)));
    renderBindings();
    ui();
    if (lastRefresh) refreshApps();
  }
  $('language').onchange=()=>{
    languageChoice=$('language').value;
    try { localStorage.setItem('hidpad.language', languageChoice); } catch { /* The choice still applies to this page. */ }
    applyLanguage();
  };
  renderBindings(); ui(); applyLanguage();
  jsonRequest('/hidpad/api/state').then(state=>{
    if (COPY[state.language]) deviceLanguage=state.language;
    applyLanguage();
  }).catch(()=>{});
  refreshApps(); setInterval(()=>{
    if (!active && Date.now()-lastRefresh>5000) refreshApps();
  },1000);
})();
