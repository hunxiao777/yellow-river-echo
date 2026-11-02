// AK 由用户在「底图」面板自行配置，只存本机 localStorage；仓库不内置密钥。
if (!localStorage.getItem('hh-map-mode')) localStorage.setItem('hh-map-mode', 'online');
// Keep the local atlas until real 2D tiles are rendered. No WebGL requirement.
let mapLoadPromise = null, mapEpoch = 0, mapTimeout = 0;
const baseMapPage = mapPage;
function mapMessage(message) {
  const el = document.querySelector('#map .badge');
  if (el) el.textContent = message;
}
function stopOnlineMap() {
  mapEpoch++;
  clearTimeout(mapTimeout);
  if (map && typeof map.clearOverlays === 'function') map.clearOverlays();
  map = null;
}
mapPage = function() {
  stopOnlineMap();
  baseMapPage();
  const tools = document.querySelector('#map .tools');
  if (tools) tools.insertAdjacentHTML('beforeend', '<button onclick="settings()">底图</button>');
};
loadBaidu = function() {
  if (localStorage.getItem('hh-map-mode') !== 'online' || selectedRoute >= 0) return;
  if (!localStorage.getItem('hh-baidu-ak')) {
    mapMessage('离线文化长卷 · 在线地图尚未配置'); return;
  }
  const epoch = mapEpoch;
  mapMessage('正在连接二维地图 · 可先浏览离线长卷');
  if (!mapLoadPromise) {
    mapLoadPromise = new Promise((resolve, reject) => {
      if (window.BMap?.Map) { resolve(); return; }
      const script = document.createElement('script');
      let settled = false;
      const fail = () => {
        if (settled) return; settled = true; clearTimeout(timer);
        script.remove(); reject(new Error('地图服务超时或网络不可用'));
      };
      const timer = setTimeout(fail, 12000);
      window.hhBaidu2DReady = () => {
        if (settled) return; settled = true; clearTimeout(timer);
        if (window.BMap?.Map) resolve(); else reject(new Error('地图密钥未通过校验'));
      };
      script.id = 'baidu2dScript';
      script.src = 'https://api.map.baidu.com/api?v=3.0&ak=' +
        encodeURIComponent(localStorage.getItem('hh-baidu-ak')) + '&callback=hhBaidu2DReady';
      script.onerror = fail;
      document.head.appendChild(script);
    }).catch(error => { mapLoadPromise = null; throw error; });
  }
  mapLoadPromise.then(() => {
    if (epoch === mapEpoch && ['map','travel'].includes(mode)) initBaidu();
  }).catch(() => {
    if (epoch === mapEpoch) mapMessage('在线地图未连接 · 离线长卷可用，点“底图”重试');
  });
};
initBaidu = function() {
  const host = document.querySelector('#map');
  if (!host || !['map','travel'].includes(mode) || selectedRoute >= 0 || !window.BMap?.Map) return;
  const epoch = mapEpoch;
  const layer = document.createElement('div');
  layer.id = 'realMap';
  layer.style.cssText = 'position:absolute;inset:0;opacity:0;pointer-events:none';
  host.prepend(layer);
  let candidate;
  const fallback = () => {
    if (epoch !== mapEpoch) return;
    clearTimeout(mapTimeout);
    layer.remove(); map = null;
    mapMessage('在线瓦片未就绪 · 已保留离线长卷，点“底图”重试');
  };
  try {
    candidate = new BMap.Map(layer);
    mapTimeout = setTimeout(fallback, 12000);
    candidate.addEventListener('tilesloaded', () => {
      if (epoch !== mapEpoch || !layer.isConnected) return;
      clearTimeout(mapTimeout);
      map = candidate;
      host.querySelector('#atlasSvg')?.remove();
      host.querySelector('.atlas-title')?.remove();
      layer.style.opacity = '1'; layer.style.pointerEvents = 'auto';
      mapMessage('百度二维地图 · ' + (city === '全部' ? '黄河沿线' : city));
    });
    const centers = {'三门峡':[111.206,34.779],'洛阳':[112.46,34.625],'郑州':[113.632,34.754],'开封':[114.314,34.802],'濮阳':[115.035,35.767]};
    const center = centers[city] || [113.4,34.9];
    candidate.centerAndZoom(new BMap.Point(center[0], center[1]), city === '全部' ? 8 : 12);
    candidate.enableScrollWheelZoom(true);
  } catch (error) { fallback(); }
};
settings = function() {
  sheet('<h2>选择地图</h2><p>离线文化长卷可直接用于模拟器演示，支持缩放、地点、收藏和路线。</p>' +
    '<button onclick="useOfflineMap()">使用离线长卷</button><h3>在线二维地图</h3>' +
    '<p>无需 WebGL。网络和百度浏览器 AK 校验通过后显示真实底图。</p>' +
    '<input id="ak" placeholder="百度浏览器 AK" autocomplete="off"><p><button onclick="saveAK()">连接 / 重试</button></p>' +
    '<small>浏览器 AK 的 Referer 白名单需允许 https://huanghe.example/ 。连接失败不会清空离线地图。</small>');
  document.querySelector('#ak').value = localStorage.getItem('hh-baidu-ak') || '';
};
function useOfflineMap() {
  localStorage.setItem('hh-map-mode','offline'); closeSheet(); mapPage();
}
saveAK = function() {
  const key = document.querySelector('#ak').value.trim();
  if (!/^[\w-]{10,128}$/.test(key)) { toast('请输入有效的浏览器 AK'); return; }
  if (key !== localStorage.getItem('hh-baidu-ak') && window.BMap?.Map) {
    localStorage.setItem('hh-baidu-ak',key); localStorage.setItem('hh-map-mode','online'); location.reload(); return;
  }
  localStorage.setItem('hh-baidu-ak',key); localStorage.setItem('hh-map-mode','online');
  closeSheet(); mapPage();
};
const atlasSearch = searchPOI;
searchPOI = function() {
  if (!map) { atlasSearch(); return; }
  const query = document.querySelector('#search').value.trim();
  if (query) new BMap.LocalSearch(map,{renderOptions:{map,autoViewport:true}}).search((city === '全部' ? '河南' : city) + ' ' + query);
};
const baseShow = show;
show = function(next) { if (next !== 'map' && next !== 'travel') stopOnlineMap(); baseShow(next); };
window.startExperience = m => show(m || 'map');
