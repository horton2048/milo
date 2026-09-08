import { MOODS, type MoodDefinition, type MoodId } from '../../core/model/Moods';
import { MoodPlanet } from '../mood/MoodPlanet';

/**
 * First stop in the recall flow. Lays out the fifteen mood planets in a grid
 * and reports the chosen mood to the caller.
 */
@Component
export struct HomeScreen {
  @Prop entryCount: number = 0;
  private onSelectMood: (moodId: MoodId) => void = () => {};
  private onOpenTimeline: () => void = () => {};

  build() {
    Column() {
      Row() {
        Text('Milo-米洛')
          .fontColor('#c9befc')
          .fontSize(13)
        Blank()
        Button(this.entryCount > 0 ? `回忆 · ${this.entryCount}` : '回忆')
          .backgroundColor(Color.Transparent)
          .fontColor('#c9befc')
          .fontSize(13)
          .onClick(() => this.onOpenTimeline())
      }
      .width('100%')
      .padding({ left: 24, right: 24, top: 16, bottom: 8 })

      Text('此刻，你感受到的是？')
        .fontSize(22)
        .fontColor('#ffffff')
        .margin({ top: 32, bottom: 8 })
      Text('点选最贴近的一颗星，我们陪你继续')
        .fontSize(13)
        .fontColor('#8b87a6')
        .margin({ bottom: 24 })

      Grid() {
        ForEach(MOODS as Array<MoodDefinition>, (mood: MoodDefinition) => {
          GridItem() {
            Column() {
              MoodPlanet({ moodId: mood.id, planetSize: 88 })
              Text(mood.labels[0])
                .fontSize(12)
                .fontColor('#c9befc')
                .margin({ top: 8 })
            }
            .onClick(() => this.onSelectMood(mood.id))
            .padding(8)
          }
        })
      }
      .columnsTemplate('1fr 1fr 1fr')
      .columnsGap(12)
      .rowsGap(12)
      .padding({ left: 24, right: 24 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#050608')
  }
}
