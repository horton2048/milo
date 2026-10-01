import { describe, expect, it } from '@ohos/hypium';
import { initialRecallState, RecallEvents, transition } from '../../../main/ets/core/flow/RecallMachine';

export default function recallMachineTest() {
  describe('recallMachineTest', () => {
    it('routes a past draft through time and chat', 0, () => {
      let state = initialRecallState();
      state = transition(state, RecallEvents.selectMood('calm'));
      state = transition(state, RecallEvents.classify('past'));
      expect(state.screen.name).assertEqual('past-time');
      state = transition(state, RecallEvents.setTimeMark('去年夏天'));
      expect(state.screen.name).assertEqual('chat');
      expect(state.draft.timeMark).assertEqual('去年夏天');
    });

    it('routes a current draft to note editing', 0, () => {
      let state = initialRecallState();
      state = transition(state, RecallEvents.selectMood('bright'));
      state = transition(state, RecallEvents.classify('now'));
      state = transition(state, RecallEvents.setNote('窗外有光'));
      expect(state.screen.name).assertEqual('now-note');
      expect(state.draft.kind).assertEqual('now');
      expect(state.draft.note).assertEqual('窗外有光');
    });

    it('retains the draft when backing through recall screens', 0, () => {
      let state = initialRecallState();
      state = transition(state, RecallEvents.selectMood('sad'));
      state = transition(state, RecallEvents.classify('past'));
      state = transition(state, RecallEvents.setTimeMark('去年冬天'));
      state = transition(state, RecallEvents.appendMessage('user', '下雪的晚上', 1));
      state = transition(state, RecallEvents.back());
      expect(state.screen.name).assertEqual('past-time');
      expect(state.draft.mood.emotionId).assertEqual('sad');
      expect(state.draft.timeMark).assertEqual('去年冬天');
      expect(state.draft.transcript[0].text).assertEqual('下雪的晚上');
    });

    it('returns the identical state for invalid forward events', 0, () => {
      const state = initialRecallState();
      const next = transition(state, RecallEvents.classify('past'));
      expect(next === state).assertTrue();
    });

    it('clears a populated draft only on reset', 0, () => {
      let state = initialRecallState();
      state = transition(state, RecallEvents.selectMood('anxious'));
      state = transition(state, RecallEvents.classify('past'));
      state = transition(state, RecallEvents.setTimeMark('昨天'));
      state = transition(state, RecallEvents.appendMessage('ai', '我在听', 2));
      state = transition(state, RecallEvents.reset());
      expect(state.screen.name).assertEqual('home');
      expect(state.draft.mood.valence).assertEqual(0);
      expect(state.draft.mood.labels.length).assertEqual(0);
      expect(state.draft.mood.emotionId === undefined).assertTrue();
      expect(state.draft.transcript.length).assertEqual(0);
      expect(state.draft.diaryEnabled).assertTrue();
    });

    it('canonicalizes time marks and rejects whitespace-only marks', 0, () => {
      let state = initialRecallState();
      state = transition(state, RecallEvents.selectMood('calm'));
      state = transition(state, RecallEvents.classify('past'));
      const rejected = transition(state, RecallEvents.setTimeMark('  \n  '));
      expect(rejected === state).assertTrue();
      state = transition(state, RecallEvents.setTimeMark('  去年夏天  '));
      expect(state.screen.name).assertEqual('chat');
      expect(state.draft.timeMark).assertEqual('去年夏天');
    });

    it('preserves diary enablement changes across diary navigation', 0, () => {
      let state = initialRecallState();
      state = transition(state, RecallEvents.selectMood('calm'));
      state = transition(state, RecallEvents.classify('past'));
      state = transition(state, RecallEvents.setTimeMark('昨天'));
      state = transition(state, RecallEvents.setDiary('初稿'));
      state = transition(state, RecallEvents.setDiaryEnabled(false));
      expect(state.draft.diaryEnabled).assertFalse();
      state = transition(state, RecallEvents.setDiaryEnabled(true));
      state = transition(state, RecallEvents.back());
      expect(state.draft.diaryEnabled).assertTrue();
      expect(state.draft.diary).assertEqual('初稿');
    });

    it('rejects valid payload events on the wrong screen', 0, () => {
      const state = initialRecallState();
      const next = transition(state, RecallEvents.setTimeMark('昨天'));
      expect(next === state).assertTrue();
    });

    it('rejects an empty detail entry identifier', 0, () => {
      let state = initialRecallState();
      state = transition(state, RecallEvents.openTimeline());
      const next = transition(state, RecallEvents.openDetail(''));
      expect(next === state).assertTrue();
    });
  });
}
