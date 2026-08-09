@Entry
@Component
struct Index {
  build() {
    Column() {
      Text('MILO')
        .fontSize(28)
        .fontWeight(FontWeight.Medium)
      Text('回到过去的某一天')
        .fontSize(16)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#050608')
  }
}
