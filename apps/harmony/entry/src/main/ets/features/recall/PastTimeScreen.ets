const PRESETS: string[] = [
  '昨天',
  '上个星期',
  '几个月前',
  '去年这个时候',
  '去年夏天',
  '几年前',
  '大学时光',
  '刚工作那会儿',
  '少年时代',
  '小时候',
];

/**
 * Time picker for the "past" branch. Verbatim preset list from
 * `apps/web/src/pages/PastTime.tsx`.
 */
@Component
export struct PastTimeScreen {
  @State picked: string = '';
  @State custom: string = '';
  private onNext: (timeMark: string) => void = () => {};
  private onBack: () => void = () => {};

  private get mark(): string {
    const trimmed = this.custom.trim();
    return trimmed.length > 0 ? trimmed : this.picked;
  }

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
        Text('那是什么时候的事？')
          .fontSize(22)
          .fontColor('#ffffff')
        Text('不需要精确的日期，\n一个模糊的印象就足够了。')
          .fontSize(13)
          .fontColor('#8b87a6')
          .margin({ top: 12 })
      }
      .margin({ top: 24, bottom: 32 })

      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
        ForEach(PRESETS, (preset: string) => {
          Text(preset)
            .padding({ left: 14, right: 14, top: 8, bottom: 8 })
            .margin({ right: 8, bottom: 8 })
            .borderRadius(20)
            .fontColor(this.picked === preset && this.custom.trim().length === 0 ? '#050608' : '#c9befc')
            .backgroundColor(this.picked === preset && this.custom.trim().length === 0 ? '#c9befc' : 'rgba(139,124,246,0.15)')
            .onClick(() => {
              this.picked = preset;
              this.custom = '';
            })
        })
      }
      .width('100%')
      .padding({ left: 24, right: 24 })
      .margin({ bottom: 28 })

      TextInput({ placeholder: '或者用自己的话描述，比如「高三的雨季」', text: this.custom })
        .onChange((value: string) => {
          this.custom = value;
        })
        .width('90%')
        .height(48)
        .padding(12)
        .backgroundColor('rgba(255,255,255,0.05)')
        .fontColor('#ffffff')

      Button('回到那时')
        .width('90%')
        .height(48)
        .margin({ top: 26 })
        .backgroundColor('#8b7cf6')
        .fontColor('#ffffff')
        .enabled(this.mark.length > 0)
        .opacity(this.mark.length > 0 ? 1.0 : 0.5)
        .onClick(() => {
          const value = this.mark;
          if (value.length > 0) {
            this.onNext(value);
          }
        })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#050608')
  }
}
