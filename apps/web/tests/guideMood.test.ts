import assert from 'node:assert/strict'
import test from 'node:test'
import { moodWord } from '../src/lib/guide.ts'

test('moodWord preserves a named discrete emotion and legacy valence fallback', () => {
  assert.equal(moodWord(-2, 'angry'), '愤怒')
  assert.equal(moodWord(-2), '低落')
})
