import { type DiaryEntry, type StickerTemplateId } from '../../core/model/Domain';
import { moodWord } from '../conversation/FallbackGuide';
import { MoodPlanet } from '../mood/MoodPlanet';

interface TemplateMeta {
  id: StickerTemplateId;
  name: string;
  tone: string;
}

const TEMPLATES: TemplateMeta[] = [
  { id: 'planet-letter', name: '星球信笺', tone: '柔和' },
  { id: 'orbit-theatre', name: '轨道剧场', tone: '深邃' },
];

/**
 * Stub card screen. Renders a minimal sticker preview; full sticker rendering
 * (pixel-faithful) lands in Task 6 alongside `CardRenderer`.
 */
@Component
export struct CardScreen {
  @Prop selected: StickerTemplateId = 'planet-letter';
  entry: DiaryEntry | undefined = undefined;
  onSelect: (template: StickerTemplateId) => void = () => {};
  onDone: () => void = () => {};
  onHome: () => void = () => {};

  build() {
    Column() {
      Row() {
        Button('← 完成')
          .backgroundColor(Color.Transparent)
          .fontColor('#c9befc')
          .fontSize(13)
          .onClick(() => this.onDone())
      }
      .width('100%')
      .padding({ left: 16, top: 16, bottom: 8 })

      Column() {
        Text('MILO MEMORY')
          .fontSize(11)
          .fontColor('#8b87a6')
        Text('你的情绪卡片')
          .fontSize(22)
          .fontColor('#ffffff')
          .margin({ top: 6 })
        Text('把这颗星球，分享给今天的世界。')
          .fontSize(13)
          .fontColor('#8b87a6')
          .margin({ top: 6 })
      }
      .margin({ top: 12, bottom: 24 })

      if (this.entry !== undefined && this.entry.mood.emotionId !== undefined) {
        Column() {
          MoodPlanet({ moodId: this.entry.mood.emotionId, planetSize: 200 })
          Text(this.entry.kind === 'past' ? (this.entry.timeMark ?? '过去的某一天') : '此刻')
            .fontSize(16)
            .fontColor('#ffffff')
            .margin({ top: 16 })
          Text(moodWord(this.entry.mood.valence, this.entry.mood.emotionId))
            .fontSize(13)
            .fontColor('#c9befc')
            .margin({ top: 4 })
        }
        .width('90%')
        .padding(24)
        .borderRadius(20)
        .backgroundColor('rgba(255,255,255,0.04)')
        .margin({ bottom: 24 })
      }

      Row({ space: 12 }) {
        ForEach(TEMPLATES, (template: TemplateMeta) => {
          Column() {
            Text(template.id === this.selected ? '●' : '○')
              .fontColor(template.id === this.selected ? '#8b7cf6' : '#8b87a6')
              .fontSize(10)
            Text(template.name)
              .fontSize(13)
              .fontColor('#ffffff')
              .margin({ top: 6 })
            Text(template.tone)
              .fontSize(11)
              .fontColor('#8b87a6')
              .margin({ top: 2 })
          }
          .layoutWeight(1)
          .padding(12)
          .borderRadius(12)
          .backgroundColor(template.id === this.selected ? 'rgba(139,124,246,0.15)' : 'rgba(255,255,255,0.04)')
          .onClick(() => this.onSelect(template.id))
        })
      }
      .width('90%')
      .margin({ bottom: 24 })

      Button('回到首页')
        .width('90%')
        .height(48)
        .backgroundColor('#8b7cf6')
        .fontColor('#ffffff')
        .onClick(() => this.onHome())
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#050608')
  }
}
