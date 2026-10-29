// 启动页 Aurora 渐变：故宫红 #9E292F 与米黄 #F4E6CD / 暖橙 #DEAA79 三团光在背景缓慢互漂。
// 光团一律用径向渐变画（边缘自己淡出），不用 blur——blur 会被组件方框裁出硬边。
@Component
export struct AuroraSplash {
  @State phase: boolean = false;

  startAnimation(): void {
    animateTo({
      duration: 9000, iterations: -1, playMode: PlayMode.Alternate, curve: Curve.EaseInOut
    }, (): void => {
      this.phase = true;
    });
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#F4E6CD')

      // 故宫红：从左上压向右下
      Column()
        .width(780)
        .height(780)
        .borderRadius(390)
        .radialGradient({
          center: ['50%', '50%'], radius: 390,
          colors: [['rgba(158,41,47,0.92)', 0], ['rgba(158,41,47,0.46)', 0.55], ['rgba(158,41,47,0)', 1]]
        })
        .translate({ x: this.phase ? 150 : -220, y: this.phase ? -250 : 140 })

      // 暖橙：与红团反向游动，两团交叠处就是"极光"的那道过渡
      Column()
        .width(640)
        .height(640)
        .borderRadius(320)
        .radialGradient({
          center: ['50%', '50%'], radius: 320,
          colors: [['rgba(222,170,121,0.95)', 0], ['rgba(222,170,121,0.5)', 0.5], ['rgba(222,170,121,0)', 1]]
        })
        .translate({ x: this.phase ? -180 : 210, y: this.phase ? 220 : -240 })

      // 米白高光：托住中央那四个字
      Column()
        .width(480)
        .height(480)
        .borderRadius(240)
        .radialGradient({
          center: ['50%', '50%'], radius: 240,
          colors: [['rgba(250,240,222,0.82)', 0], ['rgba(250,240,222,0)', 1]]
        })
        .translate({ x: this.phase ? 70 : -130, y: this.phase ? -70 : 190 })

      Column({ space: 24 }) {
        Text('黄河续响')
          .fontSize(42)
          .fontWeight(FontWeight.Medium)
          .fontColor('#68282A')
          .letterSpacing(this.phase ? 12 : 5)
          .opacity(this.phase ? 1 : 0.72)
        Text('循河而行 · 文明回响')
          .fontSize(14)
          .fontColor('#956B50')
          .letterSpacing(4)
      }
    }
    .width('100%')
    .height('100%')
    .clip(true)
    .onAppear((): void => {
      this.startAnimation();
    })
  }
}
