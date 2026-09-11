import { type MoodState } from '../../core/model/Domain';
import { MoodPlanet } from '../mood/MoodPlanet';

/**
 * Note input for the "now" branch. A planet echoes the picked mood; the note
 * is optional.
 */
@Component
export struct NowNoteScreen {
  @State note: string = '';
  mood: MoodState = { valence: 0, labels: [] };
  onSave: (note: string) => void = () => {};
  onBack: () => void = () => {};

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
        Text('记下此刻')
          .fontSize(22)
          .fontColor('#ffffff')
        Text('一句话就够了，甚至可以什么都不写。')
          .fontSize(13)
          .fontColor('#8b87a6')
          .margin({ top: 10 })
      }
      .margin({ top: 24, bottom: 32 })

      if (this.mood.emotionId !== undefined) {
        MoodPlanet({ moodId: this.mood.emotionId, planetSize: 120 })
      }

      TextArea({ placeholder: '此刻想说点什么吗…（可留空）', text: this.note })
        .onChange((value: string) => {
          this.note = value;
        })
        .width('90%')
        .height(120)
        .margin({ top: 24 })
        .padding(12)
        .backgroundColor('rgba(255,255,255,0.05)')
        .fontColor('#ffffff')

      Button('收藏这一刻')
        .width('90%')
        .height(48)
        .margin({ top: 22 })
        .backgroundColor('#8b7cf6')
        .fontColor('#ffffff')
        .onClick(() => this.onSave(this.note.trim()))
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#050608')
  }
}
