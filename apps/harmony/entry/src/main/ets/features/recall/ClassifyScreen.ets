/**
 * Asks the user whether the current feeling is "now" or "from the past".
 * Verbatim copy of the two fork-card titles from `apps/web/src/pages/Classify.tsx`.
 */
@Component
export struct ClassifyScreen {
  private onNow: () => void = () => {};
  private onPast: () => void = () => {};
  private onBack: () => void = () => {};

  build() {
    Column() {
      Row() {
        Button('← 返回')
          .backgroundColor(Color.Transparent)
          .fontColor('#c9befc')
          .fontSize(13)
          .onClick(() => this.onBack())
      }
      .width('100%')
      .padding({ left: 16, top: 16, bottom: 8 })

      Column() {
        Text('这份感受，来自哪里？')
          .fontSize(22)
          .fontColor('#ffffff')
        Text('有没有强烈地想起某件事？')
          .fontSize(13)
          .fontColor('#8b87a6')
          .margin({ top: 12 })
      }
      .margin({ top: 32, bottom: 40 })

      Column({ space: 18 }) {
        Column() {
          Text('它属于此刻')
            .fontSize(17)
            .fontColor('#ffffff')
          Text('只是现在的一阵波动。轻轻记下来就好，不需要多说什么。')
            .fontSize(13)
            .fontColor('#8b87a6')
            .margin({ top: 6 })
        }
        .width('100%')
        .padding(20)
        .borderRadius(16)
        .backgroundColor('rgba(255,255,255,0.04)')
        .onClick(() => this.onNow())

        Column() {
          Text('它来自过去的某一天')
            .fontSize(17)
            .fontColor('#c9befc')
          Text('某段时光在敲门。跟我走，我们一起回去看看——那天发生了什么，你有多难过，或者有多开心。')
            .fontSize(13)
            .fontColor('#8b87a6')
            .margin({ top: 6 })
        }
        .width('100%')
        .padding(20)
        .borderRadius(16)
        .backgroundColor('rgba(139,124,246,0.10)')
        .onClick(() => this.onPast())
      }
      .padding({ left: 24, right: 24 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#050608')
  }
}
