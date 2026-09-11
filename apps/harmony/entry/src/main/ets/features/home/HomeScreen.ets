import { MOODS, type MoodId } from '../../core/model/Moods';
import { MILO_COLORS, MILO_TYPOGRAPHY } from '../../core/theme/MiloTheme';
import { MoodOrbitCarousel } from '../mood/MoodOrbitCarousel';
import { Starfield } from '../mood/Starfield';
import { moodWord } from '../conversation/FallbackGuide';

/**
 * First stop in the recall flow. Echo-style orbit carousel sits at the
 * center of a deterministic starfield; tap any tick or label to pick a mood.
 */
@Component
export struct HomeScreen {
  @Prop entryCount: number = 0;
  onSelectMood: (moodId: MoodId) => void = () => {};
  onOpenTimeline: () => void = () => {};

  build() {
    Stack() {
      Starfield({ count: 120, seed: 0x5a17c0fe, color: '#ffffff' })

      Column() {
        Row() {
          Text('Milo-米洛')
            .fontColor(MILO_COLORS.inkDim)
            .fontSize(MILO_TYPOGRAPHY.eyebrowSize)
          Blank()
          Button(this.entryCount > 0 ? `回忆 · ${this.entryCount}` : '回忆')
            .backgroundColor(Color.Transparent)
            .fontColor(MILO_COLORS.inkDim)
            .fontSize(MILO_TYPOGRAPHY.eyebrowSize)
            .onClick(() => this.onOpenTimeline())
        }
        .width('100%')
        .padding({ left: 24, right: 24, top: 16, bottom: 8 })

        Text('此刻，你感受到的是？')
          .fontSize(MILO_TYPOGRAPHY.titleSize)
          .fontColor(MILO_COLORS.ink)
          .margin({ top: 16, bottom: 4 })
        Text('点选最贴近的一颗星，我们陪你继续')
          .fontSize(MILO_TYPOGRAPHY.subtitleSize)
          .fontColor(MILO_COLORS.inkHint)
          .margin({ bottom: 16 })

        Blank()
        MoodOrbitCarousel({
          onSelect: (index: number) => {
            const mood = MOODS[index];
            this.onSelectMood(mood.id);
          },
        })
        Blank()

        Text(moodWord(0, 'calm'))
          .fontSize(MILO_TYPOGRAPHY.bodySize)
          .fontColor(MILO_COLORS.inkDim)
          .margin({ bottom: 24 })
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(MILO_COLORS.bg)
  }
}
