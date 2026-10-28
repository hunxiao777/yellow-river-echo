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

export function goTopic(): void {
  router.pushUrl({ url: 'pages/TopicPage' });
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
