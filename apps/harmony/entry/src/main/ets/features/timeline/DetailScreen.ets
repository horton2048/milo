import { type ChatMessage, type DiaryEntry, type MoodId } from '../../core/model/Domain';
import { moodWord } from '../conversation/FallbackGuide';
import { MoodPlanet } from '../mood/MoodPlanet';

function formatDate(ts: number): string {
  const d = new Date(ts);
  return `${d.getFullYear()} 年 ${d.getMonth() + 1} 月 ${d.getDate()} 日`;
}

@Component
export struct DetailScreen {
  @State showChat: boolean = false;
  private entry: DiaryEntry | undefined = undefined;
  private onCard: (entryId: string) => void = () => {};
  private onBack: () => void = () => {};
  private onRemove: (entryId: string) => void = () => {};

  build() {
    Column() {
      Row() {
        Button('← 回忆长廊')
          .backgroundColor(Color.Transparent)
          .fontColor('#c9befc')
          .fontSize(13)
          .onClick(() => this.onBack())
        Blank()
        if (this.entry !== undefined) {
          Text(formatDate(this.entry.createdAt))
            .fontColor('#c9befc')
            .fontSize(12)
        }
        Blank()
        Button('放下')
          .backgroundColor(Color.Transparent)
          .fontColor('#8b87a6')
          .fontSize(13)
          .onClick(() => {
            if (this.entry !== undefined) {
              this.onRemove(this.entry.id);
            }
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 8 })

      if (this.entry === undefined) {
        Text('这段回忆已经飘走了。')
          .fontColor('#8b87a6')
          .margin({ top: 100 })
      } else {
        Column() {
          Text(this.entry.kind === 'past' ? (this.entry.timeMark ?? '过去的某一天') : '此刻')
            .fontSize(22)
            .fontColor('#ffffff')
          Text(
            `${moodWord(this.entry.mood.valence, this.entry.mood.emotionId)}` +
              (this.entry.mood.labels.length > 0 ? ` · ${this.entry.mood.labels.join(' · ')}` : '')
          )
            .fontSize(13)
            .fontColor('#8b87a6')
            .margin({ top: 6 })
        }
        .margin({ top: 16, bottom: 24 })

        if (this.entry.mood.emotionId !== undefined) {
          MoodPlanet({ moodId: this.entry.mood.emotionId as MoodId, planetSize: 110 })
        }

        if (this.entry.diary !== undefined && this.entry.diary.length > 0) {
          Text(this.entry.diary)
            .width('90%')
            .padding(16)
            .backgroundColor('rgba(255,255,255,0.04)')
            .fontColor('#ffffff')
            .fontSize(14)
            .lineHeight(22)
            .margin({ top: 24, bottom: 12 })
        } else if (this.entry.note !== undefined && this.entry.note.length > 0) {
          Text(this.entry.note)
            .width('90%')
            .padding(16)
            .backgroundColor('rgba(255,255,255,0.04)')
            .fontColor('#ffffff')
            .fontSize(14)
            .lineHeight(22)
            .margin({ top: 24, bottom: 12 })
        }

        if (this.entry.transcript !== undefined && this.entry.transcript.length > 0) {
          Button(this.showChat ? '收起当时的对话' : '看看当时的对话')
            .backgroundColor(Color.Transparent)
            .fontColor('#c9befc')
            .fontSize(14)
            .margin({ top: 12, bottom: 12 })
            .onClick(() => {
              this.showChat = !this.showChat;
            })
          if (this.showChat) {
            Column({ space: 12 }) {
              ForEach(this.entry.transcript, (message: ChatMessage) => {
                Text(message.text)
                  .padding(12)
                  .borderRadius(14)
                  .backgroundColor(message.role === 'user' ? 'rgba(139,124,246,0.20)' : 'rgba(255,255,255,0.06)')
                  .fontColor('#ffffff')
                  .fontSize(14)
                  .maxLines(20)
                  .constraintSize({ maxWidth: '82%' })
              })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .margin({ bottom: 18 })
          }
        }

        Button('生成回忆卡片')
          .width('90%')
          .height(48)
          .backgroundColor('#8b7cf6')
          .fontColor('#ffffff')
          .onClick(() => {
            this.onCard(this.entry!.id);
          })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#050608')
  }
}
