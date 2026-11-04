@Component
export struct HeritageMotion {
  kind: number = 0;
  @Prop active: boolean = true;
  @State progress: number = 0;
  private timer: number = -1;
  aboutToAppear(): void {
    this.timer = setInterval((): void => {
      if (this.active) { this.progress = (this.progress + 0.001) % 1; }
    }, 50);
  }
  aboutToDisappear(): void { clearInterval(this.timer); }
  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.kind === 0) {
        Image($r('app.media.monk_silhouette')).width(15).height(25)
          .position({ x: (27 + this.progress * 27) + '%', y: (55 - this.progress * 19) + '%' })
          .opacity(Math.min(this.progress * 15, (1 - this.progress) * 15, 0.9))
        Image($r('app.media.monk_silhouette')).width(11).height(19)
          .position({ x: (22 + this.progress * 27) + '%', y: (59 - this.progress * 19) + '%' })
          .opacity(Math.min(this.progress * 15, (1 - this.progress) * 15, 0.65))
      }
    }.width('100%').height('100%').hitTestBehavior(HitTestMode.None)
  }
}
