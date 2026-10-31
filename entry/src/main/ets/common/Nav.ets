import { router } from '@kit.ArkUI';
import { ContentRepo } from '../service/ContentRepo';

export interface RouteParam {
  id?: string;
  kw?: string;
  era?: string;
  city?: string;
  type?: string;
  siteId?: string;
  noteId?: string;
  goodsId?: string;
  courseId?: string;
  eventId?: string;
  tab?: number;
  colorKey?: string;
  from?: string;
}

export function goAssistant(): void {
  router.pushUrl({ url: 'pages/AssistantPage' });
}

// 半屏助手卡片的唯一开关：首页右上角「问」和右下角悬浮球改的是同一个状态，
// 弹出的是同一个 FloatingAssistant，所以从哪儿进都看得到同一份记录。
export function openAssistantSheet(): void {
  AppStorage.setOrCreate('assistantSheet', true);
}

export function closeAssistantSheet(): void {
  AppStorage.setOrCreate('assistantSheet', false);
}

// 首页和地图页各挂了一个悬浮助手实例，同一时刻只让"当前页"那个弹卡片。
export function claimAssistant(tag: string): void {
  AppStorage.setOrCreate('assistantOwner', tag);
  AppStorage.setOrCreate('assistantSheet', false);
}

export function goDetail(id: string): void {
  let p: RouteParam = { id: id };
  router.pushUrl({ url: 'pages/DetailPage', params: p });
}

export function goList(kw: string, era: string, city: string, type: string): void {
  let p: RouteParam = { kw: kw, era: era, city: city, type: type };
  router.pushUrl({ url: 'pages/ListPage', params: p });
}

export function goNote(siteId: string, noteId: string): void {
  let p: RouteParam = { siteId: siteId, noteId: noteId };
  router.pushUrl({ url: 'pages/NoteEditPage', params: p });
}

export function goArchive(tab: number): void {
  let p: RouteParam = { tab: tab };
  router.pushUrl({ url: 'pages/ArchivePage', params: p });
}

export function goGoods(id: string): void {
  let p: RouteParam = { goodsId: id };
  router.pushUrl({ url: 'pages/GoodsDetailPage', params: p });
}

export function goCourses(): void {
  router.pushUrl({ url: 'pages/CoursePage' });
}

export function goPlayer(courseId: string): void {
  let p: RouteParam = { courseId: courseId };
  router.pushUrl({ url: 'pages/PlayerPage', params: p });
}

export function goPottery(): void {
  router.pushUrl({ url: 'pages/PotteryPage' });
}

export function goActivity(eventId: string): void {
  let p: RouteParam = { eventId: eventId };
  router.pushUrl({ url: 'pages/ActivityPage', params: p });
}

export function goSync(): void {
  router.pushUrl({ url: 'pages/SyncPage' });
}

// 首页「签到」：河道示意图上点一个点盖一个章
export function goCheckin(): void {
  router.pushUrl({ url: 'pages/CheckinPage' });
}

// 首页「规划我的行程」：选年代/城市，把遗址顺河排成一条线
export function goRoute(): void {
  router.pushUrl({ url: 'pages/RoutePage' });
}

// 首页「颜色工坊」：一个颜色对应一类文物；colorKey 带上时落地先选中那一色
export function goColor(colorKey: string): void {
  let p: RouteParam = { colorKey: colorKey };
  router.pushUrl({ url: 'pages/ColorPage', params: p });
}

// 「创意工坊」单独模块：默认页顶栏切工坊、选教程；tab 0 陶艺 / 1 颜色 / 2 教程
export function goStudio(tab: number): void {
  let p: RouteParam = { tab: tab };
  router.pushUrl({ url: 'pages/StudioPage', params: p });
}

// 地图导览：ArkWeb 承载的手绘导览。type 取 map / travel / model / footprints，
// 缺省 map；地图页内保留发现·建筑·展览·打卡·餐饮·文创·卫生间·游客服务八类筛选
export function goExperience(type: string): void {
  let p: RouteParam = { type: type };
  router.pushUrl({ url: 'pages/ExperiencePage', params: p });
}

// 地图标记里的真实全景（云上龙门 / 开封铁塔），需联网
export function goPanorama(id: string): void {
  let p: RouteParam = { id: id };
  router.pushUrl({ url: 'pages/PanoramaPage', params: p });
}

// 彩蛋：连点头像 5 次后出现的「河工面板」，把同步状态机和各表行数摊开看
export function goEngineer(): void {
  router.pushUrl({ url: 'pages/EngineerPage' });
}

// 边侧栏「重看引河」：guideSeen 已由 StudioStore.redoGuide() 清掉
export function goGuide(): void {
  router.pushUrl({ url: 'pages/GuidePage' });
}

export function goTopic(): void {
  router.pushUrl({ url: 'pages/TopicPage' });
}

// from 记录来源，结果页据此决定返回后露出哪个入口
export function goQuiz(from: string): void {
  let p: RouteParam = { from: from };
  router.pushUrl({ url: 'pages/QuizPage', params: p });
}

export function goBack(): void {
  router.back();
}

// 专题类引用（文创 / 课程 / 活动）的落点：
// 文创市集在首页的「文创」页签，课程有独立页，活动没有列表页就跳最近一场排期。
// type 由 AiService 按知识库文档名前缀判定，遗址类不走这里。
export function goTopicSection(type: string): void {
  if (type === 'courses') {
    goCourses();
    return;
  }
  if (type === 'events') {
    let next = ContentRepo.get().upcomingEvents(1);
    if (next.length > 0) {
      goActivity(next[0].id);
    }
    return;
  }
  if (type === 'goods') {
    switchTab(1);
    // 从助手页/地图页跳过来时退回主框架，让「文创」页签露出来；已在首页则原地切换
    router.back({ url: 'pages/Index' });
  }
}

export function openDrawer(): void {
  AppStorage.setOrCreate('drawerOpen', true);
}

export function closeDrawer(): void {
  AppStorage.setOrCreate('drawerOpen', false);
}

export function switchTab(idx: number): void {
  AppStorage.setOrCreate('mainTab', idx);
}

export function params(): RouteParam {
  return router.getParams() as RouteParam;
}
