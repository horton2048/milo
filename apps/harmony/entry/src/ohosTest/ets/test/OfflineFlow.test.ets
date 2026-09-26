import { describe, expect, it } from '@ohos/hypium';
import {
  FallbackGuide,
  fallbackDiary,
  moodWord,
  transcriptToText,
} from '../../../main/ets/features/conversation/FallbackGuide';
import { type ChatMessage, type Draft } from '../../../main/ets/core/model/Domain';
import {
  initialRecallState,
  RecallEvents,
  transition,
  type RecallState,
} from '../../../main/ets/core/flow/RecallMachine';

const EXPECTED_OPENING =
  '闭上眼睛，我们轻轻回到「去年夏天」。不着急，先告诉我——那段时间里，最先浮现在你眼前的，是怎样的一个画面？';

const EXPECTED_STEPS: string[] = [
  '嗯，我听到了。在那个画面里，你正在经历什么？是一段困难的时刻，还是一段开心的日子？',
  '为什么会是那样呢？当时的你，处在怎样的背景里——身边有谁，生活正发生着什么？',
  '如果回到那一天，你觉得它对今天的你来说，有什么特别的意义？',
  '现在的你，还走在当时选择的那条路上吗？如果是，是什么让你坚持了下来；如果不是，中间发生了什么样的改变？',
  '谢谢你愿意说出这些。关于那段时光，还有什么想补充的吗？如果没有了，可以点击下方「沉淀这段回忆」，我们把它写成一篇属于你的日记。',
];

const USER_ANSWERS: string[] = [
  '阳光很刺眼，蝉鸣很响',
  '是期末结束后的那个下午',
  '我和最好的朋友骑车去了河边',
  '那天让我知道什么叫纯粹的快乐',
  '现在回想起来，那条路我一直走到今天',
];

function driveToChat(): RecallState {
  let state = initialRecallState();
  state = transition(state, RecallEvents.selectMood('calm'));
  state = transition(state, RecallEvents.classify('past'));
  state = transition(state, RecallEvents.setTimeMark('去年夏天'));
  return state;
}

function offlineFlowSuite() {
  describe('offlineFlowTest', () => {
    it('walks the home → past → chat flow on a single state machine', 0, () => {
      const home = initialRecallState();
      expect(home.screen.name).assertEqual('home');

      const classify = transition(home, RecallEvents.selectMood('calm'));
      expect(classify.screen.name).assertEqual('classify');

      const past = transition(classify, RecallEvents.classify('past'));
      expect(past.screen.name).assertEqual('past-time');

      const chat = transition(past, RecallEvents.setTimeMark('去年夏天'));
      expect(chat.screen.name).assertEqual('chat');
      expect(chat.draft.timeMark).assertEqual('去年夏天');
      expect(chat.draft.kind).assertEqual('past');
    });

    it('replays the scripted opening and five guide replies verbatim', 0, () => {
      const guide = new FallbackGuide('去年夏天');
      expect(guide.opening()).assertEqual(EXPECTED_OPENING);

      for (let index = 0; index < EXPECTED_STEPS.length; index += 1) {
        expect(guide.next()).assertEqual(EXPECTED_STEPS[index]);
      }
      expect(guide.isWrappingUp()).assertTrue();
    });

    it('runs the full offline trip and saves a first-person diary', 0, () => {
      const state = driveToChat();
      const guide = new FallbackGuide(state.draft.timeMark ?? '过去的某一天');

      const transcript: ChatMessage[] = [{ role: 'ai', text: guide.opening(), ts: 1 }];
      for (let index = 0; index < USER_ANSWERS.length; index += 1) {
        transcript.push({ role: 'user', text: USER_ANSWERS[index], ts: index + 2 });
        transcript.push({ role: 'ai', text: guide.next(), ts: index + 100 });
      }

      const draft: Draft = {
        mood: state.draft.mood,
        kind: state.draft.kind,
        timeMark: state.draft.timeMark,
        transcript: transcript,
        diaryEnabled: true,
      };

      const diary = fallbackDiary(draft);
      // 第一人称
      expect(diary.indexOf('我') >= 0).assertTrue();
      expect(diary.indexOf('心情有些') >= 0).assertTrue();
      expect(diary.indexOf('去年夏天') >= 0).assertTrue();
      for (let index = 0; index < USER_ANSWERS.length; index += 1) {
        expect(diary.indexOf(USER_ANSWERS[index]) >= 0).assertTrue();
      }
      // 没有 AI 旁白
      expect(diary.indexOf('引导者') < 0).assertTrue();
      expect(diary.indexOf('回响') < 0).assertTrue();

      const formatted = transcriptToText(transcript);
      expect(formatted.split('\n').length).assertEqual(transcript.length);
    });

    it('moodWord returns the catalogue label for known emotion ids', 0, () => {
      expect(moodWord(0, 'calm')).assertEqual('平静');
      expect(moodWord(2, 'bright')).assertEqual('明亮');
      expect(moodWord(-3, 'sad')).assertEqual('悲伤');
    });

    it('moodWord falls back to the valence bucket when no emotion id is set', 0, () => {
      expect(moodWord(0)).assertEqual('平静');
      expect(moodWord(3)).assertEqual('雀跃');
      expect(moodWord(-2)).assertEqual('低落');
    });
  });
}

export default function offlineFlowTest() {
  offlineFlowSuite();
}
