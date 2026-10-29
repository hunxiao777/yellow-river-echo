import { router } from '@kit.ArkUI';

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
  from?: string;
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

// 首页「颜色工坊」：一个颜色对应一类文物
export function goColor(): void {
  router.pushUrl({ url: 'pages/ColorPage' });
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
