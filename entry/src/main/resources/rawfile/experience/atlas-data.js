// These are illustration anchors, not geographic coordinates.
const cities = ['三门峡', '洛阳', '郑州', '开封', '濮阳'];
const mapSources = {
  hangu: { name: '灵宝市人民政府 · 函谷关', url: 'https://www.lingbao.gov.cn/16031/616500000/1265843.html' },
  longmen: { name: '龙门石窟景区官网', url: 'https://www.lmsk.cn/' },
  zhengzhou: { name: '郑州市政府 · 黄河文化公园', url: 'https://www.zhengzhou.gov.cn/view42202/6498075.jhtml' },
  kaifeng: { name: '河南日报／豫台视窗 · 开封铁塔', url: 'https://ytsc.rootinhenan.gov.cn/sitesources/ytsc/page_pc/hnly/fjms/article1980770f75f1439fa97ea7bd644e17d0.html' },
  qicheng: { name: '豫台视窗 · 戚城遗址', url: 'https://ytsc.rootinhenan.gov.cn/sitesources/ytsc/page_pc/hnly/fjms/article683e56795f2b40aeb6efad34a6f4875e.html' },
  museums: { name: '文化和旅游部 · 黄河文化博物馆群', url: 'https://www.mct.gov.cn/wlbphone/wlbydd/xxfb/qglb/hn/202410/t20241023_955851.html' }
};
const panoramas = {
  longmen: { title:'云上龙门 · 官方全景漫游', url:'https://demo4.museumcloud.com.cn/vrs/01', credit:'龙门石窟研究院；由景区官网“全景龙门”链接提供。实拍历史影像，非实时画面。' },
  kaifeng: { title:'开封铁塔 · 实拍全景', url:'https://www.360cities.net/zh/image/kaifeng-tower-park-4-henan?pano_detail=true&portfolio_view=false', credit:'360Cities / Jacky Cheng；2007 年拍摄。以原站页面查看，图片版权归作者，非实时画面。' }
};
const mapPOIs = [
  { id:'hangu', name:'函谷关', city:'三门峡', cat:'建筑', x:260, y:245, source:'hangu', intro:'位于灵宝的历史文化景区，以关隘文化和老子文化为主题。公开资料列有函谷关城楼、太初宫、道德天书等景点。', demo:false },
  { id:'longmen', name:'龙门石窟', city:'洛阳', cat:'建筑', x:800, y:495, source:'longmen', panorama:'longmen', intro:'龙门石窟位于洛阳，景区包括西山石窟、东山石窟、香山寺和白园。可从官方“云上龙门”进入实拍全景漫游。', demo:false },
  { id:'emperors', name:'炎黄二帝塑像', city:'郑州', cat:'建筑', x:285, y:795, source:'zhengzhou', intro:'郑州黄河文化公园的代表性景观。公园位于黄河之滨，公开资料还列有五龙峰、岳山寺、大禹山、星海湖等景区。', demo:false },
  { id:'iron-tower', name:'开封铁塔', city:'开封', cat:'建筑', x:790, y:1110, source:'kaifeng', panorama:'kaifeng', intro:'建于北宋皇祐元年（1049 年）的琉璃塔。褐色琉璃砖呈铁色，是开封具有代表性的历史建筑。', demo:false },
  { id:'qicheng', name:'戚城遗址', city:'濮阳', cat:'建筑', x:285, y:1350, source:'qicheng', intro:'濮阳的全国重点文物保护单位，地上可见古城残垣，地下保存多个历史时期的遗存。图中土垣为艺术化表现。', demo:false },
  { id:'miaodigou', name:'庙底沟仰韶文化博物馆', city:'三门峡', cat:'展览', x:345, y:345, source:'museums', intro:'河南黄河文化博物馆群中的文化展示场馆，聚焦仰韶文化。此处提供场馆文化入口，不发布未经核验的临展与开放时间。', demo:false },
  { id:'erlitou', name:'二里头夏都遗址博物馆', city:'洛阳', cat:'展览', x:695, y:610, source:'museums', intro:'位于洛阳的遗址博物馆，是了解早期王朝文化的窗口。长卷位置仅用于展示，不表示与龙门石窟相邻。', demo:false },
  { id:'shangdu', name:'郑州商都遗址博物院', city:'郑州', cat:'展览', x:435, y:905, source:'museums', intro:'河南黄河文化博物馆群中的文化展示场馆。可结合郑州商都遗址了解商代都城文化。', demo:false },
  { id:'tea-demo', name:'河畔茶歇·示意', city:'郑州', cat:'餐饮', x:525, y:780, demo:true },
  { id:'food-demo', name:'古城食集·示意', city:'开封', cat:'餐饮', x:610, y:1080, demo:true },
  { id:'cafe-demo', name:'山间小馆·示意', city:'洛阳', cat:'餐饮', x:615, y:430, demo:true },
  { id:'gift-demo', name:'黄河文创·示意', city:'郑州', cat:'文创', x:420, y:660, demo:true },
  { id:'book-demo', name:'河洛书屋·示意', city:'洛阳', cat:'文创', x:750, y:660, demo:true },
  { id:'craft-demo', name:'宋韵工坊·示意', city:'开封', cat:'文创', x:820, y:1215, demo:true },
  { id:'wc-zz-demo', name:'卫生间·示意', city:'郑州', cat:'卫生间', x:410, y:845, demo:true },
  { id:'wc-ly-demo', name:'卫生间·示意', city:'洛阳', cat:'卫生间', x:590, y:550, demo:true },
  { id:'wc-kf-demo', name:'卫生间·示意', city:'开封', cat:'卫生间', x:640, y:1190, demo:true },
  { id:'entry-demo', name:'参观入口·示意', city:'郑州', cat:'游客服务', x:260, y:925, demo:true },
  { id:'ramp-demo', name:'无障碍坡道·示意', city:'郑州', cat:'游客服务', x:350, y:875, demo:true },
  { id:'service-demo', name:'游客中心·示意', city:'郑州', cat:'游客服务', x:565, y:900, demo:true },
  { id:'help-demo', name:'游客驿站·示意', city:'三门峡', cat:'游客服务', x:460, y:250, demo:true }
];
