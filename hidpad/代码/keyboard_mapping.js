/* Physical keyboard keys, independent of layout and Shift/Caps Lock. */
((root) => {
  'use strict';
  const defaults={1:['ArrowUp','KeyW'],2:['ArrowDown','KeyS'],4:['ArrowLeft','KeyA'],8:['ArrowRight','KeyD'],
    16:['KeyJ'],32:['KeyK'],64:['KeyL'],128:['KeyI'],256:['KeyQ'],512:['KeyO'],1024:['KeyE'],2048:['KeyU'],4096:['KeyF'],8192:['KeyG'],16384:[],32768:['Escape']};
  const oldDefaults={...defaults,16:['Enter','Space'],32:['Escape'],64:[],128:[],256:[],512:[],4096:['ShiftLeft','ShiftRight'],8192:[],32768:['Home']};
  for (const bit of [1024,2048,16384]) delete oldDefaults[bit];
  const storageKey='holocubic.remote.keyboard.v1';
  function create(storage) {
    let bindings=JSON.parse(JSON.stringify(defaults));
    try {
      const saved=JSON.parse(storage?.getItem(storageKey) || 'null');
      const oldDefaultSaved=saved?.version===1 && saved.bindings && Object.keys(oldDefaults).every(bit=>
        JSON.stringify(saved.bindings[bit])===JSON.stringify(oldDefaults[bit]));
      if (saved && [1,2].includes(saved.version) && saved.bindings && !oldDefaultSaved) {
        const seen=new Set();
        for (const bit of Object.keys(defaults)) {
          const keys=saved.version===1 && [1024,2048].includes(Number(bit)) && !saved.bindings[bit]?.length
            ? defaults[bit].filter(code=>!Object.values(saved.bindings).some(keys=>Array.isArray(keys) && keys.includes(code)))
            : saved.bindings[bit];
          bindings[bit]=Array.isArray(keys)?keys.filter(code=>{
            if (typeof code!=='string' || !/^[A-Za-z][A-Za-z0-9]{0,39}$/.test(code) || seen.has(code)) return false;
            seen.add(code); return true;
          }).slice(0,8):[];
        }
      }
    } catch { /* Missing or inaccessible storage keeps the defaults. */ }
    function persist() {
      try { storage?.setItem(storageKey,JSON.stringify({version:2,bindings})); return !!storage; }
      catch { return false; }
    }
    return {
      keys:bit=>[...(bindings[bit] || [])],
      bitFor:code=>Number(Object.keys(bindings).find(bit=>bindings[bit].includes(code))) || 0,
      bind(bit,code) {
        if (!Object.hasOwn(defaults,bit) || typeof code!=='string' || !/^[A-Za-z][A-Za-z0-9]{0,39}$/.test(code)) throw new Error('Invalid binding');
        const previous=[];
        for (const [other,keys] of Object.entries(bindings)) {
          if (Number(other)!==Number(bit) && keys.includes(code)) previous.push(Number(other));
          bindings[other]=keys.filter(key=>key!==code);
        }
        bindings[bit]=[code];
        return {previous,saved:persist()};
      },
      clear(bit) { bindings[bit]=[]; return persist(); },
      reset() { bindings=JSON.parse(JSON.stringify(defaults)); return persist(); },
    };
  }
  function label(code) {
    const names={ArrowUp:'↑',ArrowDown:'↓',ArrowLeft:'←',ArrowRight:'→',Space:'空格',Escape:'Esc',
      ShiftLeft:'左 Shift',ShiftRight:'右 Shift',ControlLeft:'左 Ctrl',ControlRight:'右 Ctrl',
      AltLeft:'左 Alt',AltRight:'右 Alt',MetaLeft:'左 Win/⌘',MetaRight:'右 Win/⌘',
      NumpadEnter:'数字区 Enter',Backspace:'退格',CapsLock:'大写锁定'};
    return names[code] || code.replace(/^Key/,'').replace(/^Digit/,'').replace(/^Numpad/,'数字区 ');
  }
  root.RemoteKeymap={create,label};
})(globalThis);
