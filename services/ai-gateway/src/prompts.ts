import type { DraftSummary } from './contracts.js';

const VALENCE_LABEL: Record<number, string> = {
  [-3]: '非常低落',
  [-2]: '低落',
  [-1]: '有些沉',
  [0]: '平静',
  [1]: '还不错',
  [2]: '明亮',
  [3]: '雀跃',
};

function moodWord(valence: number, emotionId?: string): string {
  if (emotionId !== undefined) {
    const label = labelForEmotionId(emotionId);
    if (label !== undefined) return label;
  }
  return VALENCE_LABEL[valence] ?? '平静';
}

function labelForEmotionId(id: string): string | undefined {
  const known: Record<string, string> = {
    'very-low': '非常低落',
    'low': '低落',
    'heavy': '有些沉',
    'calm': '平静',
    'okay': '还不错',
    'bright': '明亮',
    'joyful': '雀跃',
    'lonely': '孤独',
    'sad': '悲伤',
    'angry': '愤怒',
    'afraid': '害怕',
    'disappointed': '失望',
    'anxious': '焦虑',
    'aggrieved': '委屈',
    'embarrassed': '尴尬',
  };
  return known[id];
}

/** Verbatim port of `buildOpeningPrompt` in `apps/web/src/lib/guide.ts`. */
export function buildOpeningPrompt(draft: DraftSummary): string {
  const labels = draft.mood.labels.length > 0 ? draft.mood.labels.join('、') : '未具体命名';
  const lines: string[] = [
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
  ];
  return lines.join('\n');
}

/** Verbatim port of `buildDiaryPrompt` in `apps/web/src/lib/guide.ts`. */
export function buildDiaryPrompt(draft: DraftSummary): string {
  const lines: string[] = draft.transcript.map((m) => `${m.role === 'user' ? '我' : '引导者'}：${m.text}`);
  const transcript = lines.join('\n');
  return [
    '请根据下面这段回忆对话，以用户（"我"）的第一人称视角，写一篇感受日记。',
    '要求：',
    '- 完全用"我"的口吻，仿佛是我自己写下的；',
    '- 只使用对话中出现过的事实与感受，不要编造细节；',
    '- 温柔、真实、有画面感，200~400 字；',
    '- 不要使用标题、列表或 markdown，只输出日记正文；',
    `- 开头可以自然带出那段时光：「${draft.timeMark ?? '过去的某一天'}」。`,
    '',
    '对话记录：',
    transcript,
  ].join('\n');
}
