import { describe, expect, it } from '@ohos/hypium';
import { initialRecallState, transition } from '../../../main/ets/core/flow/RecallMachine';

export default function recallMachineTest() {
  describe('recallMachineTest', () => {
    it('routes a past draft through time and chat', 0, () => {
      let state = initialRecallState();
      state = transition(state, { type: 'SELECT_MOOD', moodId: 'calm' });
      state = transition(state, { type: 'CLASSIFY', kind: 'past' });
      expect(state.screen.name).assertEqual('past-time');
      state = transition(state, { type: 'SET_TIME_MARK', value: '去年夏天' });
      expect(state.screen.name).assertEqual('chat');
      expect(state.draft.timeMark).assertEqual('去年夏天');
    });

    it('routes a current draft to note editing', 0, () => {
      let state = initialRecallState();
      state = transition(state, { type: 'SELECT_MOOD', moodId: 'bright' });
      state = transition(state, { type: 'CLASSIFY', kind: 'now' });
      state = transition(state, { type: 'SET_NOTE', value: '窗外有光' });
      expect(state.screen.name).assertEqual('now-note');
      expect(state.draft.kind).assertEqual('now');
      expect(state.draft.note).assertEqual('窗外有光');
    });

    it('retains the draft when backing through recall screens', 0, () => {
      let state = initialRecallState();
      state = transition(state, { type: 'SELECT_MOOD', moodId: 'sad' });
      state = transition(state, { type: 'CLASSIFY', kind: 'past' });
      state = transition(state, { type: 'SET_TIME_MARK', value: '去年冬天' });
      state = transition(state, { type: 'APPEND_MESSAGE', message: { role: 'user', text: '下雪的晚上', ts: 1 } });
      state = transition(state, { type: 'BACK' });
      expect(state.screen.name).assertEqual('past-time');
      expect(state.draft.mood.emotionId).assertEqual('sad');
      expect(state.draft.timeMark).assertEqual('去年冬天');
      expect(state.draft.transcript[0].text).assertEqual('下雪的晚上');
    });

    it('returns the identical state for invalid forward events', 0, () => {
      const state = initialRecallState();
      const next = transition(state, { type: 'CLASSIFY', kind: 'past' });
      expect(next === state).assertTrue();
    });

    it('clears a populated draft only on reset', 0, () => {
      let state = initialRecallState();
      state = transition(state, { type: 'SELECT_MOOD', moodId: 'anxious' });
      state = transition(state, { type: 'CLASSIFY', kind: 'past' });
      state = transition(state, { type: 'SET_TIME_MARK', value: '昨天' });
      state = transition(state, { type: 'APPEND_MESSAGE', message: { role: 'ai', text: '我在听', ts: 2 } });
      state = transition(state, { type: 'RESET' });
      expect(state.screen.name).assertEqual('home');
      expect(state.draft.mood.valence).assertEqual(0);
      expect(state.draft.mood.labels.length).assertEqual(0);
      expect(state.draft.mood.emotionId === undefined).assertTrue();
      expect(state.draft.transcript.length).assertEqual(0);
      expect(state.draft.diaryEnabled).assertTrue();
    });
  });
}
