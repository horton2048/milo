import { type DiaryEntry } from '../../core/model/Domain';
import { moodWord } from '../conversation/FallbackGuide';
import { MiloBackLink } from '../ui/MiloButtons';

function formatDate(ts: number): string {
  const d = new Date(ts);
  const month = String(d.getMonth() + 1);
  const day = String(d.getDate());
  const hours = String(d.getHours()).padStart(2, '0');
  const minutes = String(d.getMinutes()).padStart(2, '0');
  return `${month} 月 ${day} 日 ${hours}:${minutes}`;
}

function preview(entry: DiaryEntry): string {
  let text: string;
  if (entry.diary !== undefined && entry.diary.length > 0) {
    text = entry.diary;
  } else if (entry.note !== undefined && entry.note.length > 0) {
    text = entry.note;
  } else if (entry.transcript !== undefined) {
    const userLines: string[] = [];
    for (let index = 0; index < entry.transcript.length; index += 1) {
      const message = entry.transcript[index];
      if (message.role === 'user') {
        userLines.push(message.text);
      }
    }
    text = userLines.join(' ');
  } else {
    text = '';
  }
  if (text.length === 0) {
    return '（一次安静的记录）';
  }
  return text.length > 64 ? text.slice(0, 64) + '…' : text;
}

@Component
export struct TimelineScreen {
  @Prop entries: DiaryEntry[] = [];
  onOpen: (entryId: string) => void = () => {};
  onBack: () => void = () => {};

  build() {
    Column() {
      Row() {
        MiloBackLink({
          label: '← 此刻',
          onTap: () => this.onBack(),
        })
        Blank()
        Text('回忆长廊')
          .fontColor('#c9befc')
          .fontSize(13)
        Blank()
      }
      .width('100%')
      .padding({ left: 20, right: 16, top: 16, bottom: 8 })

      if (this.entries.length === 0) {
        Column() {
          Text('这里还很安静')
            .fontSize(22)
            .fontFamily('serif')
            .fontWeight(FontWeight.Medium)
            .fontColor('#ffffff')
          Text('当你收藏了第一段感受，\n它就会在这里亮起来。')
            .fontSize(13)
            .lineHeight(23.4)
            .fontColor('#8b87a6')
            .margin({ top: 12 })
            .textAlign(TextAlign.Center)
        }
        .margin({ top: 120 })
      } else {
        List({ space: 14 }) {
          ForEach(this.entries, (entry: DiaryEntry) => {
            ListItem() {
              Column() {
                Row({ space: 8 }) {
                  Text('●')
                    .fontColor('#8b7cf6')
                    .fontSize(10)
                  Text(formatDate(entry.createdAt))
                    .fontColor('#8b87a6')
                    .fontSize(12)
                  Text(entry.kind === 'past' ? (entry.timeMark ?? '过去') : '此刻')
                    .fontColor('#c9befc')
                    .fontSize(11)
                    .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                    .borderRadius(8)
                    .backgroundColor('rgba(139,124,246,0.15)')
                  Text(moodWord(entry.mood.valence, entry.mood.emotionId))
                    .fontColor('#c9befc')
                    .fontSize(11)
                }
                .margin({ bottom: 10 })
                Text(preview(entry))
                  .fontSize(14)
                  .fontColor('#c9befc')
                  .lineHeight(20)
              }
              .width('100%')
              .padding(18)
              .borderRadius(24)
              .backgroundColor('rgba(255,255,255,0.04)')
              .border({ width: 1, color: 'rgba(255,255,255,0.08)' })
              .onClick(() => this.onOpen(entry.id))
            }
          })
        }
        .layoutWeight(1)
        .width('100%')
        .padding({ left: 20, right: 20, top: 8, bottom: 16 })
      }
    }
    .width('100%')
    .height('100%')
  }
}
