import { type MoodId } from './Moods';

/**
 * Five original three-panel mood sheets, copied byte-for-byte from
 * `docs/superpowers/concepts/mood-orbs/*-transparent.png`. Reusing the
 * Web source files keeps the visual identity identical across platforms.
 */
export type MoodAssetSheetName =
  | 'mood_sheet_01'
  | 'mood_sheet_02'
  | 'mood_sheet_03'
  | 'mood_sheet_04'
  | 'mood_sheet_05';

/** Sheet indices used by `MoodPlanet`; matches the Web panel count. */
export type MoodAssetPanel = 0 | 1 | 2;

/** Sheet dimensions in source pixels; must mirror the Web constants. */
export const MOOD_SHEET_WIDTH = 1748;
export const MOOD_SHEET_HEIGHT = 2700;
export const MOOD_SHEET_PANEL_COUNT = 3;

/** Default Web panel focus offsets (-11 / 0 / +11 percent). */
export const MOOD_PANEL_FOCUS_OFFSETS: ReadonlyArray<number> = [-11, 0, 11];

/** All five sheet names, kept in numeric order for stable hashing. */
export const MOOD_ASSET_SHEETS: ReadonlyArray<MoodAssetSheetName> = [
  'mood_sheet_01',
  'mood_sheet_02',
  'mood_sheet_03',
  'mood_sheet_04',
  'mood_sheet_05',
];

export interface MoodAsset {
  readonly id: MoodId;
  readonly sheet: MoodAssetSheetName;
  readonly panel: MoodAssetPanel;
  /** Percent of sheet width the planet should be nudged to stay centred. */
  readonly focusOffsetPercent: number;
}

function moodAsset(
  id: MoodId,
  sheet: MoodAssetSheetName,
  panel: MoodAssetPanel,
  focusOffsetPercent: number = MOOD_PANEL_FOCUS_OFFSETS[panel],
): MoodAsset {
  return { id: id, sheet: sheet, panel: panel, focusOffsetPercent: focusOffsetPercent };
}

const MOOD_ASSETS: ReadonlyArray<MoodAsset> = [
  moodAsset('very-low', 'mood_sheet_01', 0),
  moodAsset('low', 'mood_sheet_01', 1),
  moodAsset('heavy', 'mood_sheet_01', 2),
  moodAsset('calm', 'mood_sheet_02', 0),
  moodAsset('okay', 'mood_sheet_02', 1),
  moodAsset('bright', 'mood_sheet_02', 2),
  moodAsset('joyful', 'mood_sheet_03', 0),
  moodAsset('lonely', 'mood_sheet_03', 1),
  moodAsset('sad', 'mood_sheet_03', 2),
  moodAsset('angry', 'mood_sheet_04', 0),
  moodAsset('afraid', 'mood_sheet_04', 1),
  moodAsset('disappointed', 'mood_sheet_04', 2),
  moodAsset('anxious', 'mood_sheet_05', 0, -9),
  moodAsset('aggrieved', 'mood_sheet_05', 1),
  moodAsset('embarrassed', 'mood_sheet_05', 2),
];

export function getMoodAsset(id: MoodId): MoodAsset | undefined {
  for (let index = 0; index < MOOD_ASSETS.length; index += 1) {
    const asset = MOOD_ASSETS[index];
    if (asset.id === id) {
      return asset;
    }
  }
  return undefined;
}

/**
 * Sheet left offset (in percent of full sheet width) to land the requested
 * panel inside the clipped viewport. Mirrors `apps/web/src/components/moodOrbAssets.ts`.
 */
export function moodAssetSheetLeftPercent(asset: MoodAsset): number {
  return asset.panel * -100 + asset.focusOffsetPercent;
}