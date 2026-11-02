import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import fs from 'node:fs';
const source=fs.readFileSync(new URL('../entry/src/main/resources/rawfile/experience/map-runtime.js',import.meta.url),'utf8');
function setup(online=false) {
  const timers=new Map(), store=new Map(), scripts=[], layers=[];
  let id=0, svgRemoved=false, event;
  const badge={textContent:''}, svg={remove(){svgRemoved=true;}};
  const host={prepend(layer){layers.push(layer);},querySelector(selector){return selector==='#atlasSvg'?svg:null;}};
  const context={
    mode:'map',selectedRoute:-1,city:'全部',map:null,
    localStorage:{getItem:k=>store.get(k),setItem:(k,v)=>store.set(k,v)},
    mapPage(){},show(next){context.mode=next;},searchPOI(){},sheet(){},closeSheet(){},toast(){},
    location:{reload(){}},
    setTimeout(fn){const key=++id;timers.set(key,fn);return key;},clearTimeout(key){timers.delete(key);},
    document:{
      head:{appendChild(script){scripts.push(script);}},
      createElement(){return {style:{},isConnected:true,remove(){this.isConnected=false;}};},
      querySelector(selector){if(selector==='#map')return host;if(selector==='#map .badge')return badge;return null;}
    },
    BMap:{Map:class {addEventListener(name,fn){if(name==='tilesloaded')event=fn;}centerAndZoom(){}enableScrollWheelZoom(){}clearOverlays(){}},Point:class {}}
  };
  context.window=context;
  if(!online)store.set('hh-map-mode','offline');
  if(online){store.set('hh-map-mode','online');store.set('hh-baidu-ak','test-browser-key');}
  vm.createContext(context); vm.runInContext(source,context);
  return {context,timers,scripts,layers,badge,svgRemoved:()=>svgRemoved,event:()=>event?.()};
}
test('explicit offline mode never initiates online map',()=>{
  const x=setup();x.context.loadBaidu();assert.equal(x.layers.length,0);assert.equal(x.scripts.length,0);
});
test('atlas stays visible until tilesloaded; timeout preserves it',async()=>{
  const x=setup(true);x.context.loadBaidu();await new Promise(resolve => setImmediate(resolve));
  assert.equal(x.layers.length,1);assert.equal(x.svgRemoved(),false);
  assert.equal(x.layers[0].style.opacity,undefined);
  for(const fn of [...x.timers.values()])fn();
  assert.equal(x.layers[0].isConnected,false);assert.equal(x.svgRemoved(),false);assert.equal(x.context.map,null);
});
test('successful tiles switch to real map only after rendering',async()=>{
  const x=setup(true);x.context.loadBaidu();await new Promise(resolve => setImmediate(resolve));x.event();
  assert.equal(x.svgRemoved(),true);assert.equal(x.layers[0].style.opacity,'1');assert.ok(x.context.map);
});
test('late tile callback cannot replace the next page',async()=>{
  const x=setup(true);x.context.loadBaidu();await new Promise(resolve => setImmediate(resolve));x.context.show('footprints');x.event();
  assert.equal(x.svgRemoved(),false);assert.equal(x.context.map,null);
});
test('network script failure leaves offline atlas available',async()=>{
  const x=setup(true);delete x.context.BMap;x.context.loadBaidu();
  assert.equal(x.scripts.length,1);x.scripts[0].onerror();
  await new Promise(resolve => setImmediate(resolve));await new Promise(resolve => setImmediate(resolve));await new Promise(resolve => setImmediate(resolve));
  assert.equal(x.svgRemoved(),false);assert.equal(x.context.map,null);
});
