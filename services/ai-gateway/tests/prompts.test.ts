import test from 'node:test';
import assert from 'node:assert/strict';
import { buildDiaryPrompt, buildOpeningPrompt } from '../src/prompts.js';
import type { DraftSummary } from '../src/contracts.js';

const OPENING_HEADER = [
  '你现在不是编程助手。你是「回响」——一位温柔、安静的回忆引导者。',
  '用户此刻的情绪与过去的某段时光有关，你的任务是通过对话，一步一步引导 ta 把当时的情景、困难、快乐、背景，以及那一天对现在的特别之处说出来。',
  '',
].join('\n');

test('opening prompt keeps the exact web header and uses the mood label', () => {
  const draft: DraftSummary = {
    mood: { valence: 0, labels: ['平静'], emotionId: 'calm' },
    timeMark: '去年夏天',
    transcript: [],
  };
  const text = buildOpeningPrompt(draft);
  assert.ok(text.startsWith(OPENING_HEADER));
  assert.ok(text.includes('平静'));
  assert.ok(text.includes('去年夏天'));
  assert.ok(text.includes('第一个问题'));
});

test('opening prompt falls back to the valence bucket when no emotion id is set', () => {
  const draft: DraftSummary = {
    mood: { valence: 3, labels: [] },
    timeMark: undefined,
    transcript: [],
  };
  const text = buildOpeningPrompt(draft);
  assert.ok(text.includes('雀跃'));
  assert.ok(text.includes('过去的某一天'));
  assert.ok(text.includes('未具体命名'));
});

test('diary prompt labels user lines as 我 and AI lines as 引导者', () => {
  const draft: DraftSummary = {
    mood: { valence: 0, labels: ['平静'] },
    timeMark: '去年夏天',
    transcript: [
      { role: 'ai', text: '欢迎回来', ts: 1 },
      { role: 'user', text: '那天是雨季', ts: 2 },
    ],
  };
  const text = buildDiaryPrompt(draft);
  assert.ok(text.includes('引导者：欢迎回来'));
  assert.ok(text.includes('我：那天是雨季'));
  assert.ok(text.includes('去年夏天'));
});