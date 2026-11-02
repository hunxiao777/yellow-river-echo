// 「观文物」查询库：随包只读的一批古代文物条目，按分类 / 年代 / 颜色三个维度筛。
// 名称取的是常见器类名（如「兽面纹铜鼎」「三彩马」），不指认某件馆藏实物；
// 一句话说明只讲这类器物的通识，不写具体出土与尺寸。
export interface Relic {
  id: string;
  name: string;
  cat: string;
  era: string;
  // 色键对应 Theme 的六色，卡面配色与「颜色」筛选共用
  palette: string;
  // ArtCover 程序化器形：pot jar ding tile stele tower cave scroll coin box bridge kiln
  shape: string;
  material: string;
  desc: string;
}

export interface ColorSeed {
  key: string;
  name: string;
}

// 分类：照数字文物库的常见门类收拢到十类以内
export const RELIC_CATS: string[] = ['陶瓷', '铜器', '玉石器', '金属器', '书画', '碑帖', '砖瓦', '造像', '文房'];

// 年代：从新石器到清，与文物条目对得上
export const RELIC_ERAS: string[] = ['新石器时代', '夏', '商', '西周', '春秋', '战国', '秦', '汉', '唐', '宋', '元', '明', '清'];

export const RELIC_COLORS: ColorSeed[] = [
  { key: 'yangshao', name: '红陶' },
  { key: 'longshan', name: '玄黑' },
  { key: 'xiashang', name: '青绿' },
  { key: 'zhou', name: '玉色' },
  { key: 'hantang', name: '赭黄' },
  { key: 'song', name: '天青' }
];

const RELICS: Relic[] = [
  { id: 'rl01', name: '鱼纹彩陶盆', cat: '陶瓷', era: '新石器时代', palette: 'yangshao', shape: 'pot',
    material: '泥质红陶', desc: '红陶衣上以黑彩绘鱼，是仰韶文化彩陶的常见母题。' },
  { id: 'rl02', name: '旋纹彩陶罐', cat: '陶瓷', era: '新石器时代', palette: 'yangshao', shape: 'jar',
    material: '泥质红陶', desc: '肩腹一圈圈旋涡纹，线条顺着器形转，像水在流。' },
  { id: 'rl03', name: '花瓣纹彩陶钵', cat: '陶瓷', era: '新石器时代', palette: 'yangshao', shape: 'pot',
    material: '细泥红陶', desc: '庙底沟系常见的花卉纹样，圆点与弧线勾出花瓣。' },
  { id: 'rl04', name: '蛋壳黑陶高柄杯', cat: '陶瓷', era: '新石器时代', palette: 'longshan', shape: 'pot',
    material: '渗碳黑陶', desc: '龙山黑陶的薄胎代表，壁薄如壳，黑里发亮。' },
  { id: 'rl05', name: '磨光黑陶鬶', cat: '陶瓷', era: '新石器时代', palette: 'longshan', shape: 'jar',
    material: '黑陶', desc: '三足掏空的盛器，口颈拉出长流，器表打磨过。' },
  { id: 'rl06', name: '素面玉璧', cat: '玉石器', era: '新石器时代', palette: 'zhou', shape: 'box',
    material: '青玉', desc: '扁圆中孔，光素无纹，是新石器至周常见的礼器形。' },
  { id: 'rl07', name: '兽面纹铜鼎', cat: '铜器', era: '商', palette: 'xiashang', shape: 'ding',
    material: '青铜', desc: '圆腹三足，腹部一圈兽面纹，是商代鼎的常见格局。' },
  { id: 'rl08', name: '饕餮纹铜爵', cat: '铜器', era: '夏', palette: 'xiashang', shape: 'ding',
    material: '青铜', desc: '前有流、后有尾、下三足的饮酒器，腰饰带状纹。' },
  { id: 'rl09', name: '嵌绿松石铜牌饰', cat: '铜器', era: '夏', palette: 'xiashang', shape: 'box',
    material: '青铜嵌绿松石', desc: '牌面以绿松石片拼出纹样，二里头一带出土过同类器。' },
  { id: 'rl10', name: '弦纹铜鬲', cat: '铜器', era: '商', palette: 'xiashang', shape: 'ding',
    material: '青铜', desc: '袋足炊器，颈上一圈弦纹，器壁铸得厚实。' },
  { id: 'rl11', name: '玉璋', cat: '玉石器', era: '商', palette: 'zhou', shape: 'box',
    material: '白玉', desc: '长条状端刃器，牙状分叉，礼玉里的常见一种。' },
  { id: 'rl12', name: '蟠螭纹编钟', cat: '铜器', era: '春秋', palette: 'zhou', shape: 'ding',
    material: '青铜', desc: '合瓦形钟体，枚区与蟠螭纹交错，成组悬挂敲击。' },
  { id: 'rl13', name: '玉柄铁剑', cat: '金属器', era: '西周', palette: 'xiashang', shape: 'box',
    material: '铁刃玉柄', desc: '剑身是铁、柄首是玉，金玉铁合铸的西周佩剑。' },
  { id: 'rl14', name: '错金银铜带钩', cat: '金属器', era: '战国', palette: 'hantang', shape: 'coin',
    material: '青铜错金银', desc: '束带用的钩器，钩身错出金银丝纹，细看才见工。' },
  { id: 'rl15', name: '云纹瓦当', cat: '砖瓦', era: '秦', palette: 'longshan', shape: 'tile',
    material: '灰陶', desc: '檐头挡水的圆形瓦头，四分界面里填云纹。' },
  { id: 'rl16', name: '画像砖', cat: '砖瓦', era: '汉', palette: 'hantang', shape: 'tile',
    material: '灰陶', desc: '砖面压印宴饮、车马等画面，是汉墓里的图像材料。' },
  { id: 'rl17', name: '鎏金摩羯纹银盘', cat: '金属器', era: '唐', palette: 'hantang', shape: 'coin',
    material: '银鎏金', desc: '宽折沿银盘，通体鎏金，盘心錾出卷草与摩羯纹。' },
  { id: 'rl18', name: '三彩马', cat: '陶瓷', era: '唐', palette: 'hantang', shape: 'jar',
    material: '铅釉陶', desc: '白陶胎上施黄绿褐三色釉，釉在火里互相浸流。' },
  { id: 'rl19', name: '三彩骆驼', cat: '陶瓷', era: '唐', palette: 'hantang', shape: 'pot',
    material: '铅釉陶', desc: '双峰驼背上搭着驮囊，釉色顺毛势流下来。' },
  { id: 'rl20', name: '唐人写经残卷', cat: '书画', era: '唐', palette: 'hantang', shape: 'scroll',
    material: '纸本墨书', desc: '硬黄纸上工整楷写，经卷边缘已磨出毛口。' },
  { id: 'rl21', name: '石窟大佛造像', cat: '造像', era: '唐', palette: 'xiashang', shape: 'cave',
    material: '石灰岩', desc: '依山凿出的坐佛，衣纹贴着身体一层层铺开。' },
  { id: 'rl22', name: '刻花白釉瓶', cat: '陶瓷', era: '宋', palette: 'song', shape: 'jar',
    material: '白瓷', desc: '化妆土上斜刀刻花，釉层在凹处积出深浅。' },
  { id: 'rl23', name: '天青釉莲式碗', cat: '陶瓷', era: '宋', palette: 'song', shape: 'pot',
    material: '青瓷', desc: '釉色取"雨过天青"一路，口沿压出莲瓣式。' },
  { id: 'rl24', name: '山水图卷', cat: '书画', era: '宋', palette: 'zhou', shape: 'scroll',
    material: '绢本水墨', desc: '平远一路的江山小景，墨色淡处像蒙着水汽。' },
  { id: 'rl25', name: '碑刻拓本册', cat: '碑帖', era: '宋', palette: 'longshan', shape: 'stele',
    material: '纸本墨拓', desc: '乌金拓墨色沉厚，字口一圈留白是拓工的讲究。' },
  { id: 'rl26', name: '青花缠枝纹梅瓶', cat: '陶瓷', era: '元', palette: 'song', shape: 'jar',
    material: '青花瓷', desc: '小口丰肩，钴料绘缠枝花，发色浓处带铁锈斑。' },
  { id: 'rl27', name: '石造像头像', cat: '造像', era: '元', palette: 'zhou', shape: 'tower',
    material: '汉白玉', desc: '面相方圆，螺发肉髻，石皮已风化出细裂纹。' },
  { id: 'rl28', name: '法帖汇刻拓册', cat: '碑帖', era: '明', palette: 'xiashang', shape: 'stele',
    material: '纸本墨拓', desc: '名家书迹上石汇刻，再一张一张拓下来装订成册。' },
  { id: 'rl29', name: '铜镇纸', cat: '文房', era: '明', palette: 'hantang', shape: 'box',
    material: '白铜', desc: '案头压纸的长条小器，素面打磨，两头微微下垂。' },
  { id: 'rl30', name: '端砚', cat: '文房', era: '清', palette: 'longshan', shape: 'box',
    material: '石砚', desc: '砚堂平整墨池浅开，石里带一点青花斑点。' }
];

export class RelicRepo {
  private static readonly inst: RelicRepo = new RelicRepo();
  static get(): RelicRepo {
    return RelicRepo.inst;
  }

  relics: Relic[] = RELICS;

  byId(id: string): Relic | undefined {
    return this.relics.find((r: Relic): boolean => r.id === id);
  }

  colorName(key: string): string {
    let c = RELIC_COLORS.find((x: ColorSeed): boolean => x.key === key);
    return c === undefined ? key : c.name;
  }

  // 三个维度都是「多选其一命中即可，未选视为不限」，再叠一层名称/材质关键词
  filtered(kw: string, cats: string[], eras: string[], colors: string[]): Relic[] {
    let k = kw.trim();
    return this.relics.filter((r: Relic): boolean => {
      if (cats.length > 0 && cats.indexOf(r.cat) < 0) {
        return false;
      }
      if (eras.length > 0 && eras.indexOf(r.era) < 0) {
        return false;
      }
      if (colors.length > 0 && colors.indexOf(r.palette) < 0) {
        return false;
      }
      if (k.length === 0) {
        return true;
      }
      return r.name.indexOf(k) >= 0 || r.material.indexOf(k) >= 0 ||
        r.cat.indexOf(k) >= 0 || r.era.indexOf(k) >= 0 || r.desc.indexOf(k) >= 0;
    });
  }
}
