const ATLAS_W = 1024, ATLAS_H = 1536;
let selectedPOI = '', focusTimer = 0, flatMap = false;
const routes = [
  {name:'快速文化巡游',desc:'三处文化地标 · 长卷浏览顺序',ids:['hangu','longmen','emperors']},
  {name:'五城文明长卷',desc:'五城串联 · 文化主题展示，非步行线路',ids:['hangu','longmen','emperors','iron-tower','qicheng']},
  {name:'无障碍路线演示',desc:'示例入口 → 示例坡道 → 商都文化入口；待实测，非通行指引',ids:['entry-demo','ramp-demo','shangdu'],demo:true},
  {name:'亲子博物馆之旅',desc:'三个博物馆文化入口 · 非实时展讯',ids:['miaodigou','erlitou','shangdu']},
  {name:'古建与石刻',desc:'函谷关、龙门与铁塔 · 主题阅读线路',ids:['hangu','longmen','iron-tower']}
];
function getPOI(id) { return mapPOIs.find(p => p.id === id); }
function pois() {
  if (selectedRoute >= 0) return routes[selectedRoute].ids.map(getPOI).filter(Boolean);
  return mapPOIs.filter(p => (city === '全部' || city === p.city) &&
    (['发现','打卡'].includes(category) ? p.cat === '建筑' : p.cat === category));
}
function switchCategory(c) {
  clearTimeout(focusTimer); selectedPOI = ''; selectedRoute = -1; category = c;
  closeSheet(); mapPage();
  document.querySelector('.tabs .active')?.scrollIntoView({behavior:'smooth',block:'nearest',inline:'center'});
}
function marker(p, i) {
  const symbol = {建筑:'⌂',展览:'▤',餐饮:'♨',文创:'▣',卫生间:'WC',游客服务:'i'}[p.cat];
  const label = p.name, width = Math.max(138, label.length * 24 + 30);
  return `<g class="pin ${p.demo?'service-pin':''}" transform="translate(${p.x},${p.y})" data-id="${p.id}" tabindex="0" role="button" aria-label="${esc(label)}" onclick="poi('${p.id}')" onkeydown="if(event.key==='Enter'||event.key===' ')poi('${p.id}')">
    <g class="pin-pop" style="animation-delay:${i*65}ms">
      <ellipse cy="13" rx="26" ry="8" fill="#3b4d4433"/>
      <path d="M-25-48 A32 32 0 1 1 50 0 L0 8Z" fill="${p.demo?'#648b80':'#aa8246'}" stroke="#fffaf0" stroke-width="6"/>
      <text x="0" y="-36" text-anchor="middle" fill="white" style="font-size:27px">${symbol}</text>
      <rect x="${-width/2}" y="14" width="${width}" height="39" rx="18" fill="#fffbee" stroke="#d6c5a6" stroke-width="2"/>
      <text x="0" y="41" text-anchor="middle" fill="#504637" style="font-size:23px;font-weight:600">${esc(label)}</text>
      ${p.panorama?'<g transform="translate(25,-86)"><rect width="78" height="30" rx="15" fill="#247d79"/><text x="39" y="21" text-anchor="middle" fill="white" style="font-size:20px">360°</text></g>':''}
    </g></g>`;
}
function svgMap(night=false,mini=false) {
  const points = mini ? mapPOIs.filter(p=>p.cat==='建筑') : pois();
  const line = selectedRoute >= 0 ? pois().map(p=>`${p.x},${p.y}`).join(' ') : '';
  return `<svg id="atlasSvg" viewBox="0 0 ${ATLAS_W} ${ATLAS_H}" aria-label="黄河文化手绘长卷，艺术布局非地理坐标">
    <g id="mapScene" transform="translate(${offset.x},${offset.y}) scale(${scale})">
      <image href="atlas.png" width="${ATLAS_W}" height="${ATLAS_H}"/>
      ${flatMap?'<rect width="1024" height="1536" fill="#fff9ec" opacity=".72"/>':''}
      <polyline points="${line}" stroke="#fff8df" stroke-width="16" fill="none" stroke-linejoin="round"/>
      <polyline class="path" points="${line}" stroke="#a83b36" stroke-width="9" fill="none" stroke-linejoin="round"/>
      ${points.map(marker).join('')}
    </g></svg>`;
}
function mapPage() {
  map = null;
  app.innerHTML = `<div class="atlas-shell"><nav class="tabs" aria-label="地图分类">${cats.map(c=>`<button class="${c===category?'active':''}" onclick="switchCategory('${c}')">${c}</button>`).join('')}</nav>
    <div class="atlas-search"><select aria-label="选择城市" onchange="city=this.value;selectedRoute=-1;resetAtlas()">${['全部',...cities].map(c=>`<option ${c===city?'selected':''}>${c}</option>`).join('')}</select><input id="search" placeholder="寻一处文化地标" onkeydown="if(event.key==='Enter')searchPOI()"><button aria-label="搜索地点" onclick="searchPOI()">⌕</button></div>
    <div class="map atlas-map" id="map"><div class="badge">手绘文化长卷 · 艺术布局，非导航${selectedRoute>=0?' · '+routes[selectedRoute].name:''}</div>${svgMap()}
      <div class="atlas-title"><small>沿 河 而 行</small><b>黄河续响平台</b><span>五城 · 一脉文明</span></div>
      <div class="tools"><button onclick="atlasIntro()">简介</button><button onclick="flatMap=!flatMap;mapPage()">${flatMap?'手绘':'淡化'}</button><button onclick="show('footprints')">足迹</button><button onclick="saved()">收藏</button></div>
      <div class="zoom-tools"><button aria-label="放大地图" onclick="zoom(1.3)">＋</button><button aria-label="缩小地图" onclick="zoom(1/1.3)">－</button><button aria-label="复位地图" onclick="resetAtlas()">⌖</button></div>
      <button class="routeBtn" onclick="routeList()">游览<br>路线</button>
      <div class="map-caption" aria-live="polite">${category} · ${pois().length} 个${['餐饮','文创','卫生间','游客服务'].includes(category)?'示例服务点':'文化标记'}</div>
    </div><div id="results"></div>
    ${category==='发现'?'<div class="discover-strip"><button onclick="poi(\'longmen\')"><b>云上龙门</b><span>360° 实拍漫游 ›</span></button><button onclick="show(\'footprints\')"><b>黄河明信片</b><span>收藏旅行的片刻 ›</span></button></div>':''}</div>`;
  attachPan();
  if (!pois().length) document.querySelector('#results').innerHTML='<p class="empty-map">此城市暂无该类标记，试试“全部”或其他分类。</p>';
  if (selectedRoute < 0 && localStorage.getItem('hh-baidu-ak')) loadBaidu();
}
function applyTransform(animate=false) {
  const g=document.querySelector('#mapScene'); if(!g)return;
  g.style.transition=animate&&!matchMedia('(prefers-reduced-motion: reduce)').matches?'transform 650ms cubic-bezier(.22,.68,0,1)':'none';
  g.setAttribute('transform',`translate(${offset.x},${offset.y}) scale(${scale})`);
}
function resetAtlas() { clearTimeout(focusTimer); selectedPOI='';scale=1;offset={x:0,y:0};mapPage(); }
function zoom(n) {
  if(map){map.setZoom(map.getZoom()+(n>1?1:-1));return;}
  const next=Math.max(1,Math.min(3.2,scale*n)),ratio=next/scale;
  offset={x:ATLAS_W/2-(ATLAS_W/2-offset.x)*ratio,y:ATLAS_H/2-(ATLAS_H/2-offset.y)*ratio};
  scale=next;applyTransform(true);
}
function attachPan() {
  const el=document.querySelector('#atlasSvg'); if(!el)return;
  const pointers=new Map();let drag=null,pinch=null;
  const pos=e=>{const pt=new DOMPoint(e.clientX,e.clientY);return pt.matrixTransform(el.getScreenCTM().inverse());};
  el.onpointerdown=e=>{if(e.target.closest('.pin'))return;clearTimeout(focusTimer);let p=pos(e);pointers.set(e.pointerId,p);el.setPointerCapture(e.pointerId);drag={p,offset:{...offset}};if(pointers.size===2){let [a,b]=[...pointers.values()];pinch={distance:Math.hypot(a.x-b.x,a.y-b.y),scale,offset:{...offset},mid:{x:(a.x+b.x)/2,y:(a.y+b.y)/2}}}};
  el.onpointermove=e=>{if(!pointers.has(e.pointerId))return;let p=pos(e);pointers.set(e.pointerId,p);if(pointers.size===2&&pinch){let[a,b]=[...pointers.values()],mid={x:(a.x+b.x)/2,y:(a.y+b.y)/2};scale=Math.max(1,Math.min(3.2,pinch.scale*Math.hypot(a.x-b.x,a.y-b.y)/pinch.distance));let ratio=scale/pinch.scale;offset={x:mid.x-(pinch.mid.x-pinch.offset.x)*ratio,y:mid.y-(pinch.mid.y-pinch.offset.y)*ratio}}else if(drag){offset={x:drag.offset.x+p.x-drag.p.x,y:drag.offset.y+p.y-drag.p.y}}applyTransform()};
  el.onpointerup=el.onpointercancel=e=>{pointers.delete(e.pointerId);pinch=null;drag=null};
  el.onwheel=e=>{e.preventDefault();zoom(e.deltaY<0?1.1:1/1.1)};
}
function poi(id) {
  const p=getPOI(id);if(!p)return;
  clearTimeout(focusTimer);selectedPOI=id;scale=1.65;offset={x:ATLAS_W*.45-p.x*scale,y:ATLAS_H*.36-p.y*scale};applyTransform(true);
  focusTimer=setTimeout(()=>{if(mode!=='map'||selectedPOI!==id)return;poiDetail(p)},matchMedia('(prefers-reduced-motion: reduce)').matches?0:420);
}
function poiDetail(p) {
  const source=mapSources[p.source];
  sheet(`<div class="poi-heading"><small>${esc(p.city)} / ${esc(p.cat)} ${p.demo?'· 展示服务点':'· 文化地标'}</small><h2>${esc(p.name)}</h2></div>
    <p>${esc(p.intro||'这是为演示导览交互设置的服务点，尚未对应真实商户或设施。')}</p>
    <p class="muted">${p.demo?'位置与名称均为示意，请勿据此寻找服务设施。':'地标名称与简介依据公开资料整理；插画与位置经过艺术编排。'}</p>
    ${p.panorama?`<button class="pano-open" onclick="openPanorama('${p.panorama}')">360° 真实实景 · 点击进入 ↗</button><p class="muted">${esc(panoramas[p.panorama].credit)} 需联网。</p>`:'<p class="pano-unavailable">暂无可用的真实全景；待接入实拍素材。</p>'}
    <div class="row"><button onclick="toggleFavorite('${p.id}')">${favorites.includes(p.id)?'取消收藏':'收藏地标'}</button><button onclick="checkin('${p.id}')">记录足迹</button></div>
    ${source?`<details><summary>资料来源</summary><p>${esc(source.name)}<br><span class="source-url">${esc(source.url)}</span><br>核对日期：2026-10-29</p></details>`:''}`);
}
function toggleFavorite(id){favorites=favorites.includes(id)?favorites.filter(x=>x!==id):[...favorites,id];persist();poiDetail(getPOI(id))}
function saved(){sheet('<h2>收藏地标</h2>'+favorites.map(getPOI).filter(Boolean).map(p=>`<button class="saved-place" onclick="closeSheet();city='全部';category='${p.cat}';mapPage();poi('${p.id}')">${esc(p.city)} · ${esc(p.name)} ›</button>`).join('')+(!favorites.map(getPOI).filter(Boolean).length?'<p>还没有收藏地标。</p>':''))}
function searchPOI(){const q=document.querySelector('#search').value.trim();if(map){new BMapGL.LocalSearch(map,{renderOptions:{map,autoViewport:true}}).search((city==='全部'?'河南':city)+' '+q);return}const found=mapPOIs.filter(p=>(city==='全部'||p.city===city)&&(p.name+p.city).includes(q));sheet('<h2>寻找文化地标</h2>'+found.map(p=>`<button class="saved-place" onclick="closeSheet();category='${p.cat}';selectedRoute=-1;mapPage();poi('${p.id}')">${esc(p.city)} · ${esc(p.name)} ›</button>`).join('')+(!found.length?'<p>没有匹配地点，试试其他关键词。</p>':''))}
function routeList(){sheet('<h2>游览路线</h2><small>文化长卷浏览顺序，不代表实地道路或距离。</small>'+routes.map((r,i)=>`<div class="route"><div><b>${r.name}</b><p class="muted">${r.desc}</p></div><button onclick="selectRoute(${i})">查看</button></div>`).join('')+'<button onclick="if(window.Native)Native.journey();else toast(\'在鸿蒙应用中创建行程\')">＋ 创建我的行程</button>')}
function selectRoute(i){if(!routes[i])return;selectedRoute=i;selectedPOI='';category='建筑';city='全部';scale=1;offset={x:0,y:0};closeSheet();show('map');if(routes[i].demo){scale=2.3;offset={x:ATLAS_W/2-350*scale,y:ATLAS_H*.44-880*scale};applyTransform(true);toast('无障碍路线仅供演示，尚未核验通行条件')}}
function atlasIntro(){sheet('<h2>一卷看见黄河文明</h2><p>函谷关、龙门石窟、炎黄二帝塑像、开封铁塔与戚城遗址，在山水手绘中串联起五城记忆。</p><p>点分类，标记依次浮现；点地标，地图居中放大。带 360° 标签的地点可联网进入公开实拍全景。</p><p class="muted">山水与建筑外形经艺术化处理，可用于行前的文化浏览与路线构思。</p><button onclick="closeSheet()">开始探索</button>')}
function openPanorama(id){const p=panoramas[id];if(!p)return;if(window.Native?.panorama){Native.panorama(id);return}sheet(`<h2>${esc(p.title)}</h2><p>${esc(p.credit)}</p><p>在原站查看可保留完整全景操作及作者信息。</p><a class="pano-link" href="${esc(p.url)}" target="_blank" rel="noopener noreferrer">打开真实全景 ↗</a>`)}
function travel(){category='发现';city='全部';mapPage()}
function footprintMap(){
  const lit=new Set(records.map(r=>r.city));
  return `<svg class="footprint-map" viewBox="0 0 1024 1536" aria-label="黄河五城足迹，文化节点示意"><defs><radialGradient id="litGlow"><stop stop-color="#60f2e0" stop-opacity=".85"/><stop offset="1" stop-color="#60f2e0" stop-opacity="0"/></radialGradient></defs><image href="atlas.png" width="1024" height="1536" opacity=".23"/><rect width="1024" height="1536" fill="#061f30" opacity=".3"/>${mapPOIs.filter(p=>p.cat==='建筑').map(p=>`<g role="button" tabindex="0" aria-label="记录${p.city}足迹" onclick="city='${p.city}';addRecord()" onkeydown="if(event.key==='Enter'){city='${p.city}';addRecord()}">${lit.has(p.city)?`<circle class="lit-halo" cx="${p.x}" cy="${p.y}" r="150" fill="url(#litGlow)"/>`:''}<circle cx="${p.x}" cy="${p.y}" r="${lit.has(p.city)?28:18}" fill="${lit.has(p.city)?'#5df1df':'#607780'}" stroke="#c7e0da" stroke-width="3"/><text x="${p.x}" y="${p.y+65}" text-anchor="middle" fill="white" font-size="38">${p.city}</text></g>`).join('')}</svg>`;
}
function loadBaidu(){if(window.BMapGL?.Map)return initBaidu();if(document.querySelector('#baiduScript'))return;let s=document.createElement('script');s.id='baiduScript';s.src='https://api.map.baidu.com/api?v=4.0&type=webgl&ak='+encodeURIComponent(localStorage.getItem('hh-baidu-ak'))+'&callback=initBaidu';s.onerror=()=>{s.remove();toast('在线地图暂不可用，保留手绘展示')};document.head.append(s)}
function initBaidu(){if(mode!=='map'||selectedRoute>=0)return;const el=document.querySelector('#map');if(!el)return;try{el.querySelector('svg')?.remove();el.querySelector('.atlas-title')?.remove();el.querySelector('.badge').textContent='百度地图 · '+(city==='全部'?'河南':city);el.insertAdjacentHTML('afterbegin','<div id="realMap" style="height:100%;width:100%"></div>');map=new BMapGL.Map('realMap');map.centerAndZoom(city==='全部'?'河南':city,city==='全部'?7:13);map.enableScrollWheelZoom(true);const q={发现:'文化景点',建筑:'文化遗址',展览:'博物馆',打卡:'旅游景点',餐饮:'餐厅',文创:'文创商店',卫生间:'公共厕所',游客服务:'游客中心'}[category];new BMapGL.LocalSearch(map,{renderOptions:{map,autoViewport:true}}).search((city==='全部'?'河南':city)+' '+q)}catch(e){map=null;el.querySelector('#realMap')?.remove();el.insertAdjacentHTML('afterbegin',svgMap());el.querySelector('.badge').textContent='手绘展示 · 在线地图初始化失败';attachPan();toast('已恢复手绘展示，请检查地图配置')}}
