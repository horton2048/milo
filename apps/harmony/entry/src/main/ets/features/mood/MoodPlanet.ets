import {
  getMoodAsset,
  moodAssetSheetLeftPercent,
  MOOD_SHEET_HEIGHT,
  MOOD_SHEET_PANEL_COUNT,
  MOOD_SHEET_WIDTH,
} from '../../core/model/MoodAssets';
import { MOODS, type MoodId } from '../../core/model/Moods';

/**
 * Renders a single mood planet by clipping one panel out of its source sheet.
 *
 * Layout mirrors `apps/web/src/components/MoodPlanetImage.tsx`:
 *  - The viewport is `width × (width * 2700 / 1748)`.
 *  - The inner image is rendered at three times the viewport width so a single
 *    1748×2700 panel fills the visible area.
 *  - The image is shifted horizontally by `moodAssetSheetLeftPercent(asset)` of
 *    the viewport width to land the requested panel inside the clip rectangle.
 */
@Component
export struct MoodPlanet {
  @Prop moodId: MoodId = 'calm';
  @Prop width: number = 120;

  private get asset() {
    return getMoodAsset(this.moodId);
  }

  private get panelViewportHeight(): number {
    return this.width * (MOOD_SHEET_HEIGHT / MOOD_SHEET_WIDTH);
  }

  private get innerImageWidth(): number {
    return this.width * MOOD_SHEET_PANEL_COUNT;
  }

  private get innerImageHeight(): number {
    return this.panelViewportHeight;
  }

  private get offsetX(): number {
    const asset = this.asset;
    if (asset === undefined) {
      return 0;
    }
    return (moodAssetSheetLeftPercent(asset) / 100) * this.width;
  }

  private get label(): string {
    for (let index = 0; index < MOODS.length; index += 1) {
      const mood = MOODS[index];
      if (mood.id === this.moodId && mood.labels.length > 0) {
        return mood.labels[0];
      }
    }
    return this.moodId;
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.asset !== undefined) {
        if (this.asset.sheet === 'mood_sheet_01') {
          Image($r('app.media.mood_sheet_01'))
            .width(this.innerImageWidth)
            .height(this.innerImageHeight)
            .offset({ x: this.offsetX, y: 0 })
            .interpolation(ImageInterpolation.High)
            .objectFit(ImageFit.Fill)
            .draggable(false)
        } else if (this.asset.sheet === 'mood_sheet_02') {
          Image($r('app.media.mood_sheet_02'))
            .width(this.innerImageWidth)
            .height(this.innerImageHeight)
            .offset({ x: this.offsetX, y: 0 })
            .interpolation(ImageInterpolation.High)
            .objectFit(ImageFit.Fill)
            .draggable(false)
        } else if (this.asset.sheet === 'mood_sheet_03') {
          Image($r('app.media.mood_sheet_03'))
            .width(this.innerImageWidth)
            .height(this.innerImageHeight)
            .offset({ x: this.offsetX, y: 0 })
            .interpolation(ImageInterpolation.High)
            .objectFit(ImageFit.Fill)
            .draggable(false)
        } else if (this.asset.sheet === 'mood_sheet_04') {
          Image($r('app.media.mood_sheet_04'))
            .width(this.innerImageWidth)
            .height(this.innerImageHeight)
            .offset({ x: this.offsetX, y: 0 })
            .interpolation(ImageInterpolation.High)
            .objectFit(ImageFit.Fill)
            .draggable(false)
        } else {
          Image($r('app.media.mood_sheet_05'))
            .width(this.innerImageWidth)
            .height(this.innerImageHeight)
            .offset({ x: this.offsetX, y: 0 })
            .interpolation(ImageInterpolation.High)
            .objectFit(ImageFit.Fill)
            .draggable(false)
        }
      }
    }
    .width(this.width)
    .height(this.panelViewportHeight)
    .clip(true)
    .accessibilityText(this.label + '情绪星球')
    .accessibilityMode(AccessibilityMode.Basic)
  }
}