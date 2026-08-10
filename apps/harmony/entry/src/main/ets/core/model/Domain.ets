export type MoodId =
  | 'very-low'
  | 'low'
  | 'heavy'
  | 'calm'
  | 'okay'
  | 'bright'
  | 'joyful'
  | 'lonely'
  | 'sad'
  | 'angry'
  | 'afraid'
  | 'disappointed'
  | 'anxious'
  | 'aggrieved'
  | 'embarrassed';

export interface MoodState {
  valence: number;
  labels: string[];
  emotionId?: MoodId;
}

export type EntryKind = 'now' | 'past';

export type StickerTemplateId = 'planet-letter' | 'orbit-theatre';

export type ChatRole = 'user' | 'ai';

export interface ChatMessage {
  role: ChatRole;
  text: string;
  ts: number;
}

export interface DiaryEntry {
  id: string;
  createdAt: number;
  kind: EntryKind;
  mood: MoodState;
  timeMark?: string;
  note?: string;
  transcript?: ChatMessage[];
  diary?: string;
  diaryEnabled: boolean;
  stickerTemplate?: StickerTemplateId;
}

export type ScreenName =
  | 'home'
  | 'classify'
  | 'now-note'
  | 'past-time'
  | 'chat'
  | 'diary'
  | 'card'
  | 'timeline'
  | 'detail';

export interface Screen {
  name: ScreenName;
  entryId?: string;
}

export interface Draft {
  mood: MoodState;
  kind?: EntryKind;
  timeMark?: string;
  note?: string;
  transcript: ChatMessage[];
  diary?: string;
  diaryEnabled: boolean;
  stickerTemplate?: StickerTemplateId;
}
