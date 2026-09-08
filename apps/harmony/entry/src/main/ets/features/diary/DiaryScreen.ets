import { type Draft } from '../../core/model/Domain';
import { fallbackDiary } from '../conversation/FallbackGuide';

/**
 * First-person diary generated from the past-branch transcript. In offline
 * mode we use `fallbackDiary`; when an AI gateway is wired up, replace the
 * `aboutToAppear` body with a streaming call. The user can edit before save.
 */
@Component
export struct DiaryScreen {
  @State diaryOn: boolean = true;
  @State diary: string = '';
  @State generating: boolean = true;
  @State editing: boolean = false;
  private draft: Draft = { mood: { valence: 0, labels: [] }, transcript: [], diaryEnabled: true };
  private onSave: (diary: string | undefined, enabled: boolean) => void = () => {};
  private onBack: () => void = () => {};

  aboutToAppear(): void {
    this.generating = true;
    this.diary = this.diaryOn ? fallbackDiary(this.draft) : '';
    this.generating = false;
  }

  build() {
    Column() {
      Row() {
        Button('← 返回对话')
          .backgroundColor(Color.Transparent)
          .fontColor('#c9befc')
          .fontSize(13)
          .onClick(() => this.onBack())
        Blank()
        Text(this.draft.timeMark ?? '')
          .fontColor('#c9befc')
          .fontSize(12)
        Blank()
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 8 })

      Column() {
        Text('显影这段回忆')
          .fontSize(22)
          .fontColor('#ffffff')
        Text('我们把刚才的对话，写成了一篇属于你的日记。')
          .fontSize(13)
          .fontColor('#8b87a6')
          .margin({ top: 8 })
      }
      .margin({ top: 16, bottom: 20 })

      Row() {
        Column() {
          Text('沉淀为日记')
            .fontSize(14)
            .fontColor('#ffffff')
          Text('以你的视角书写；关闭则只保留对话记录')
            .fontSize(11)
            .fontColor('#8b87a6')
            .margin({ top: 4 })
        }
        .layoutWeight(1)
        Button(this.diaryOn ? '●' : '○')
          .width(48)
          .height(28)
          .backgroundColor(this.diaryOn ? '#8b7cf6' : 'rgba(255,255,255,0.10)')
          .fontColor('#ffffff')
          .onClick(() => {
            this.diaryOn = !this.diaryOn;
            if (this.diaryOn && this.diary.length === 0) {
              this.diary = fallbackDiary(this.draft);
            }
          })
      }
      .width('90%')
      .padding(16)
      .borderRadius(14)
      .backgroundColor('rgba(255,255,255,0.04)')
      .margin({ bottom: 18 })

      if (this.diaryOn) {
        if (this.editing) {
          TextArea({ text: this.diary })
            .onChange((value: string) => {
              this.diary = value;
            })
            .width('90%')
            .height(220)
            .padding(12)
            .backgroundColor('rgba(255,255,255,0.05)')
            .fontColor('#ffffff')
            .margin({ bottom: 12 })
        } else if (this.generating && this.diary.length === 0) {
          Text('回忆正在显影…')
            .fontColor('#8b87a6')
            .margin({ bottom: 12 })
        } else {
          Text(this.diary)
            .width('90%')
            .padding(16)
            .backgroundColor('rgba(255,255,255,0.04)')
            .fontColor('#ffffff')
            .fontSize(14)
            .lineHeight(22)
            .margin({ bottom: 12 })
        }

        if (!this.generating) {
          Button(this.editing ? '完成编辑' : '修改一下措辞')
            .backgroundColor(Color.Transparent)
            .fontColor('#c9befc')
            .fontSize(14)
            .margin({ bottom: 12 })
            .onClick(() => {
              this.editing = !this.editing;
            })
        }
      }

      Button('收进回忆')
        .width('90%')
        .height(48)
        .backgroundColor('#8b7cf6')
        .fontColor('#ffffff')
        .enabled(!this.diaryOn || !this.generating)
        .opacity((!this.diaryOn || !this.generating) ? 1.0 : 0.5)
        .onClick(() => {
          this.onSave(this.diaryOn ? this.diary : undefined, this.diaryOn);
        })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#050608')
  }
}
