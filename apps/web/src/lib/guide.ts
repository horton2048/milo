import { moodLabel } from '../components/moodEmotionModel.ts'
import type { Draft, ChatMessage, MoodId } from '../types'

export function moodWord(valence: number, emotionId?: MoodId): string {
  return moodLabel(valence, emotionId)
}

/** 首轮发给 Codex 的角色设定 + 开场引导请求 */
export function buildOpeningPrompt(draft: Draft): string {
  const labels = draft.mood.labels.length ? draft.mood.labels.join('、') : '未具体命名'
  return [
    '你现在不是编程助手。你是「回响」——一位温柔、安静的回忆引导者。',
    '用户此刻的情绪与过去的某段时光有关，你的任务是通过对话，一步一步引导 ta 把当时的情景、困难、快乐、背景，以及那一天对现在的特别之处说出来。',
    '',
    '对话规则（务必遵守）：',
    '- 每次只问一个问题，问题要具体、轻柔，不评判；',
    '- 回复保持简短（1~3 句话），先简单回应用户说的内容，再提出下一个问题；',
    '- 不要使用列表、标题或 markdown 格式，只用自然的口语化中文；',
    '- 不要提及你是 AI 模型、不要谈论代码或工具；',
    '- 循着这样的脉络推进：当时的情景 → 遇到的困难或快乐 → 为什么会这样、当时的背景 → 那一天对今天的自己有什么特别 → 现在还在延续当时的路吗，如果变了，发生了什么。',
    '',
    `用户此刻的情绪：${moodWord(draft.mood.valence, draft.mood.emotionId)}（${labels}）。`,
    `ta 想回到的时光：「${draft.timeMark ?? '过去的某一天'}」。`,
    '',
    '现在，请说一句开场白，欢迎 ta 回到那段时光，并问出第一个问题。',
  ].join('\n')
}

/** 让 Codex 把对话沉淀为第一人称日记 */
export function buildDiaryPrompt(draft: Draft): string {
  const lines = draft.transcript
    .map((m) => `${m.role === 'user' ? '我' : '引导者'}：${m.text}`)
    .join('\n')
  return [
    '请根据下面这段回忆对话，以用户（“我”）的第一人称视角，写一篇感受日记。',
    '要求：',
    '- 完全用“我”的口吻，仿佛是我自己写下的；',
    '- 只使用对话中出现过的事实与感受，不要编造细节；',
    '- 温柔、真实、有画面感，200~400 字；',
    '- 不要使用标题、列表或 markdown，只输出日记正文；',
    `- 开头可以自然带出那段时光：「${draft.timeMark ?? '过去的某一天'}」。`,
    '',
    '对话记录：',
    lines,
  ].join('\n')
}

/** ACP 不可用时的脚本化引导（兜底） */
export class FallbackGuide {
  private step = 0
  private timeMark: string

  constructor(timeMark: string) {
    this.timeMark = timeMark
  }

  opening(): string {
    return `闭上眼睛，我们轻轻回到「${this.timeMark}」。不着急，先告诉我——那段时间里，最先浮现在你眼前的，是怎样的一个画面？`
  }

  next(): string {
    const steps = [
      '嗯，我听到了。在那个画面里，你正在经历什么？是一段困难的时刻，还是一段开心的日子？',
      '为什么会是那样呢？当时的你，处在怎样的背景里——身边有谁，生活正发生着什么？',
      '如果回到那一天，你觉得它对今天的你来说，有什么特别的意义？',
      '现在的你，还走在当时选择的那条路上吗？如果是，是什么让你坚持了下来；如果不是，中间发生了什么样的改变？',
      '谢谢你愿意说出这些。关于那段时光，还有什么想补充的吗？如果没有了，可以点击下方「沉淀这段回忆」，我们把它写成一篇属于你的日记。',
    ]
    const reply = steps[Math.min(this.step, steps.length - 1)]
    this.step++
    return reply
  }

  isWrappingUp(): boolean {
    return this.step >= 5
  }
}

/** 兜底：本地把对话拼成第一人称日记 */
export function fallbackDiary(draft: Draft): string {
  const userLines = draft.transcript.filter((m) => m.role === 'user').map((m) => m.text)
  const mark = draft.timeMark ?? '过去的某一天'
  const mood = moodWord(draft.mood.valence, draft.mood.emotionId)
  const body = userLines.join(' ')
  return (
    `今天，我的心情有些${mood}，思绪不自觉地飘回了${mark}。\n\n` +
    `${body}\n\n` +
    `把这些写下来之后，才发现那一天一直安静地住在我心里。谢谢当时的自己，也谢谢现在愿意回头看的自己。`
  )
}

export function transcriptToText(transcript: ChatMessage[]): string {
  return transcript.map((m) => `${m.role === 'user' ? '我' : '回响'}：${m.text}`).join('\n')
}
