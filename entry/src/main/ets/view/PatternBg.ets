// 底层水纹贴图：一笔描出、按周期平铺的波纹线，透明度压得很低，
// 再整体往下慢速漂移一个周期（26vp）循环播放，接缝看不出来。
// 动效只有这一层在动，内容层保持安静，避免花哨。
@Component
export struct PatternBg {
  @State dy: number = 0;
  private cmd: string = '';

  aboutToAppear(): void {
    this.cmd = buildWaves();
    animateTo({
      duration: 11000,
      curve: Curve.Linear,
      iterations: -1,
      playMode: PlayMode.Normal
    }, (): void => {
      this.dy = 26;
    });
  }

  build() {
    Stack() {
      Path()
        .width('100%')
        .height(988)
        .commands(this.cmd)
        .stroke('#B98D4F')
        .strokeWidth(1)
        .fill(Color.Transparent)
        .opacity(0.09)
    }
    .width('100%')
    .height('100%')
    .translate({ y: this.dy - 26 })
    .hitTestBehavior(HitTestMode.None)
  }
}

// 行距 26、列距 44，奇数行错半格；从 -26 起笔，保证下漂一个周期后顶部不露空。
function buildWaves(): string {
  let out = '';
  let row = 0;
  for (let y = -26; y <= 962; y += 26) {
    let x0 = row % 2 === 0 ? -12 : 10;
    for (let x = x0; x < 420; x += 44) {
      out += `M${x} ${y} q11 -8 22 0 q11 8 22 0 `;
    }
    row += 1;
  }
  return out;
}
