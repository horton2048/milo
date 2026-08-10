import { ChatMessage, Draft, EntryKind, MoodId, Screen } from '../model/Domain';
import { moodStateForId } from '../model/Moods';

export interface RecallState {
  screen: Screen;
  draft: Draft;
}

export type RecallEventType =
  | 'SELECT_MOOD'
  | 'CLASSIFY'
  | 'SET_NOTE'
  | 'SET_TIME_MARK'
  | 'APPEND_MESSAGE'
  | 'SET_DIARY'
  | 'OPEN_TIMELINE'
  | 'OPEN_DETAIL'
  | 'BACK'
  | 'RESET';

export interface RecallEvent {
  type: RecallEventType;
  moodId?: MoodId;
  kind?: EntryKind;
  value?: string;
  message?: ChatMessage;
  entryId?: string;
}

export function initialRecallState(): RecallState {
  return {
    screen: { name: 'home' },
    draft: {
      mood: { valence: 0, labels: [] },
      transcript: [],
      diaryEnabled: true,
    },
  };
}

function copyDraft(draft: Draft): Draft {
  const transcript: ChatMessage[] = [];
  for (let index = 0; index < draft.transcript.length; index += 1) {
    const message = draft.transcript[index];
    transcript.push({ role: message.role, text: message.text, ts: message.ts });
  }
  return {
    mood: {
      valence: draft.mood.valence,
      labels: draft.mood.labels.slice(),
      emotionId: draft.mood.emotionId,
    },
    kind: draft.kind,
    timeMark: draft.timeMark,
    note: draft.note,
    transcript: transcript,
    diary: draft.diary,
    diaryEnabled: draft.diaryEnabled,
    stickerTemplate: draft.stickerTemplate,
  };
}

function withDraft(state: RecallState, screen: Screen, draft: Draft): RecallState {
  return { screen: screen, draft: draft };
}

function backScreen(state: RecallState): Screen | undefined {
  switch (state.screen.name) {
    case 'classify':
      return { name: 'home' };
    case 'now-note':
    case 'past-time':
      return { name: 'classify' };
    case 'chat':
      return { name: 'past-time' };
    case 'diary':
      return { name: 'chat' };
    case 'card':
    case 'detail':
      return { name: 'timeline' };
    case 'timeline':
      return { name: 'home' };
    default:
      return undefined;
  }
}

export function transition(state: RecallState, event: RecallEvent): RecallState {
  if (event.type === 'RESET') {
    return initialRecallState();
  }

  if (event.type === 'BACK') {
    const previous = backScreen(state);
    if (previous === undefined) {
      return state;
    }
    return withDraft(state, previous, copyDraft(state.draft));
  }

  if (event.type === 'SELECT_MOOD') {
    if (state.screen.name !== 'home' || event.moodId === undefined) {
      return state;
    }
    const mood = moodStateForId(event.moodId);
    if (mood === undefined) {
      return state;
    }
    return withDraft(state, { name: 'classify' }, {
      mood: mood,
      transcript: [],
      diaryEnabled: true,
    });
  }

  if (event.type === 'CLASSIFY') {
    if (state.screen.name !== 'classify' || state.draft.mood.emotionId === undefined || event.kind === undefined) {
      return state;
    }
    const draft = copyDraft(state.draft);
    draft.kind = event.kind;
    return withDraft(state, { name: event.kind === 'now' ? 'now-note' : 'past-time' }, draft);
  }

  if (event.type === 'SET_NOTE') {
    if (state.screen.name !== 'now-note' || state.draft.kind !== 'now' || event.value === undefined) {
      return state;
    }
    const draft = copyDraft(state.draft);
    draft.note = event.value;
    return withDraft(state, { name: 'now-note' }, draft);
  }

  if (event.type === 'SET_TIME_MARK') {
    if (state.screen.name !== 'past-time' || state.draft.kind !== 'past' || event.value === undefined || event.value.length === 0) {
      return state;
    }
    const draft = copyDraft(state.draft);
    draft.timeMark = event.value;
    return withDraft(state, { name: 'chat' }, draft);
  }

  if (event.type === 'APPEND_MESSAGE') {
    if (state.screen.name !== 'chat' || state.draft.kind !== 'past' || event.message === undefined) {
      return state;
    }
    const draft = copyDraft(state.draft);
    draft.transcript.push({
      role: event.message.role,
      text: event.message.text,
      ts: event.message.ts,
    });
    return withDraft(state, { name: 'chat' }, draft);
  }

  if (event.type === 'SET_DIARY') {
    if ((state.screen.name !== 'chat' && state.screen.name !== 'diary') || event.value === undefined) {
      return state;
    }
    const draft = copyDraft(state.draft);
    draft.diary = event.value;
    return withDraft(state, { name: 'diary' }, draft);
  }

  if (event.type === 'OPEN_TIMELINE') {
    if (state.screen.name !== 'home' && state.screen.name !== 'card') {
      return state;
    }
    return withDraft(state, { name: 'timeline' }, copyDraft(state.draft));
  }

  if (event.type === 'OPEN_DETAIL') {
    if (state.screen.name !== 'timeline' || event.entryId === undefined) {
      return state;
    }
    return withDraft(state, { name: 'detail', entryId: event.entryId }, copyDraft(state.draft));
  }

  return state;
}
