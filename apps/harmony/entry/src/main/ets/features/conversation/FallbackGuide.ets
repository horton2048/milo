import { type ChatMessage, type Draft, type MoodId } from '../../core/model/Domain';
import { MOODS } from '../../core/model/Moods';

/**
 * Returns the human label for a mood state. Mirrors the web
 * `moodLabel(valence, emotionId)` lookup in `apps/web/src/components/moodEmotionModel.ts`.
 */
export function moodWord(valence: number, emotionId?: MoodId): string {
  if (emotionId !== undefined) {
    for (let index = 0; index < MOODS.length; index += 1) {
      const mood = MOODS[index];
      if (mood.id === emotionId) {
        return mood.labels[0];
      }
    }
  }
  if (valence === -3) return '非常低落';
  if (valence === -2) return '低落';
  if (valence === -1) return '有些沉';
  if (valence === 0) return '平静';
  if (valence === 1) return '还不错';
  if (valence === 2) return '明亮';
  if (valence === 3) return '雀跃';
  return '平静';
}

/**
 * Scripted fallback guide used when the AI gateway is unavailable.
 * Verbatim port of `apps/web/src/lib/guide.ts` so the offline tone matches
 * the web build.
 */
export class FallbackGuide {
  private step: number = 0;
  private timeMark: string;

  constructor(timeMark: string) {
    this.timeMark = timeMark;
  }

  opening(): string {
    return `闭上眼睛，我们轻轻回到「${this.timeMark}」。不着急，先告诉我——那段时间里，最先浮现在你眼前的，是怎样的一个画面？`;
  }

  next(): string {
    const steps: string[] = [
      '嗯，我听到了。在那个画面里，你正在经历什么？是一段困难的时刻，还是一段开心的日子？',
      '为什么会是那样呢？当时的你，处在怎样的背景里——身边有谁，生活正发生着什么？',
      '如果回到那一天，你觉得它对今天的你来说，有什么特别的意义？',
      '现在的你，还走在当时选择的那条路上吗？如果是，是什么让你坚持了下来；如果不是，中间发生了什么样的改变？',
      '谢谢你愿意说出这些。关于那段时光，还有什么想补充的吗？如果没有了，可以点击下方「沉淀这段回忆」，我们把它写成一篇属于你的日记。',
    ];
    const reply = steps[Math.min(this.step, steps.length - 1)];
    this.step += 1;
    return reply;
  }

  isWrappingUp(): boolean {
    return this.step >= 5;
  }

  /** Test seam: return the current step count. */
  currentStep(): number {
    return this.step;
  }

  /** Test seam: restore a previously persisted step count. */
  restoreStep(step: number): void {
    this.step = step;
  }
}

/**
 * Stitch a first-person diary from the user's transcript lines.
 * Mirrors `fallbackDiary(draft)` from the web build.
 */
export function fallbackDiary(draft: Draft): string {
  const userLines: string[] = [];
  for (let index = 0; index < draft.transcript.length; index += 1) {
    const message = draft.transcript[index];
    if (message.role === 'user') {
      userLines.push(message.text);
    }
  }
  const mark = draft.timeMark ?? '过去的某一天';
  const mood = moodWord(draft.mood.valence, draft.mood.emotionId);
  const body = userLines.join(' ');
  return (
    `今天，我的心情有些${mood}，思绪不自觉地飘回了${mark}。\n\n` +
    `${body}\n\n` +
    `把这些写下来之后，才发现那一天一直安静地住在我心里。谢谢当时的自己，也谢谢现在愿意回头看的自己。`
  );
}

/** Format a transcript as `我：…` / `回响：…` lines. */
export function transcriptToText(transcript: ChatMessage[]): string {
  const parts: string[] = [];
  for (let index = 0; index < transcript.length; index += 1) {
    const message = transcript[index];
    const who = message.role === 'user' ? '我' : '回响';
    parts.push(`${who}：${message.text}`);
  }
  return parts.join('\n');
}
