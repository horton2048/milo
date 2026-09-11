import { MoodId, MoodState } from './Domain';

export { MoodId, MoodState };

export interface MoodDefinition {
  readonly id: MoodId;
  readonly valence: number;
  readonly labels: ReadonlyArray<string>;
  readonly emotionId: MoodId;
}

export const MOODS: ReadonlyArray<MoodDefinition> = [
  { id: 'very-low', valence: -3, labels: ['非常低落'], emotionId: 'very-low' },
  { id: 'low', valence: -2, labels: ['低落'], emotionId: 'low' },
  { id: 'heavy', valence: -1, labels: ['有些沉'], emotionId: 'heavy' },
  { id: 'calm', valence: 0, labels: ['平静'], emotionId: 'calm' },
  { id: 'okay', valence: 1, labels: ['还不错'], emotionId: 'okay' },
  { id: 'bright', valence: 2, labels: ['明亮'], emotionId: 'bright' },
  { id: 'joyful', valence: 3, labels: ['雀跃'], emotionId: 'joyful' },
  { id: 'lonely', valence: -2, labels: ['孤独'], emotionId: 'lonely' },
  { id: 'sad', valence: -3, labels: ['悲伤'], emotionId: 'sad' },
  { id: 'angry', valence: -2, labels: ['愤怒'], emotionId: 'angry' },
  { id: 'afraid', valence: -2, labels: ['害怕'], emotionId: 'afraid' },
  { id: 'disappointed', valence: -2, labels: ['失望'], emotionId: 'disappointed' },
  { id: 'anxious', valence: -1, labels: ['焦虑'], emotionId: 'anxious' },
  { id: 'aggrieved', valence: -2, labels: ['委屈'], emotionId: 'aggrieved' },
  { id: 'embarrassed', valence: -1, labels: ['尴尬'], emotionId: 'embarrassed' },
];

export function moodStateForId(id: MoodId): MoodState | undefined {
  for (let index = 0; index < MOODS.length; index += 1) {
    const mood = MOODS[index];
    if (mood.id === id) {
      return {
        valence: mood.valence,
        labels: mood.labels.slice(),
        emotionId: mood.emotionId,
      };
    }
  }
  return undefined;
}

/**
 * Home dial order, mirroring the web build's `ECHO_SELECTOR_MOOD_IDS`:
 * calm in the middle, each side progressing outward by intensity.
 */
const ECHO_SELECTOR_MOOD_IDS: ReadonlyArray<MoodId> = [
  'joyful',
  'bright',
  'okay',
  'calm',
  'heavy',
  'low',
  'very-low',
];

function selectorMood(id: MoodId): MoodDefinition {
  for (let index = 0; index < MOODS.length; index += 1) {
    const mood = MOODS[index];
    if (mood.id === id) {
      return mood;
    }
  }
  return MOODS[3];
}

export const ECHO_SELECTOR_MOODS: ReadonlyArray<MoodDefinition> = ECHO_SELECTOR_MOOD_IDS.map(
  (id: MoodId): MoodDefinition => selectorMood(id),
);
