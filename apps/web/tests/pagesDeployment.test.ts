import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import test from 'node:test'

test('GitHub Pages builds assets for the renamed Milo repository', () => {
  const workflow = readFileSync('.github/workflows/deploy-pages.yml', 'utf8')

  assert.match(workflow, /npm run build -- --base=\/Milo\//)
  assert.doesNotMatch(workflow, /echoes-cosmic-mood/)
})
