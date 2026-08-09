import assert from 'node:assert/strict';
import { readFileSync, lstatSync, realpathSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import test from 'node:test';

const projectRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const bundledSdk = '/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony';

test('hvigorw prepares the bundled API 24 SDK layout before invoking Hvigor', () => {
  const result = spawnSync(join(projectRoot, 'hvigorw'), ['--version'], {
    cwd: projectRoot,
    encoding: 'utf8'
  });

  assert.equal(result.status, 0, result.stderr || result.stdout);
  const apiLink = join(projectRoot, '.deveco-sdk', '24');
  assert.equal(lstatSync(apiLink).isSymbolicLink(), true);
  assert.equal(realpathSync(apiLink), bundledSdk);
  assert.equal(
    readFileSync(join(projectRoot, 'local.properties'), 'utf8'),
    `sdk.dir=${join(projectRoot, '.deveco-sdk')}\n`
  );
});

test('root page renders the centered MILO smoke shell on the dark background', () => {
  const source = readFileSync(
    join(projectRoot, 'entry', 'src', 'main', 'ets', 'pages', 'Index.ets'),
    'utf8'
  );

  for (const contract of [
    "Text('MILO')",
    '.fontSize(28)',
    '.fontWeight(FontWeight.Medium)',
    "Text('回到过去的某一天')",
    '.fontSize(16)',
    ".width('100%')",
    ".height('100%')",
    '.justifyContent(FlexAlign.Center)',
    ".backgroundColor('#050608')"
  ]) {
    assert.ok(source.includes(contract), `Missing smoke-shell contract: ${contract}`);
  }
});

test('start window matches the root background in every system color mode', () => {
  const moduleProfile = JSON.parse(
    readFileSync(join(projectRoot, 'entry', 'src', 'main', 'module.json5'), 'utf8')
  );
  assert.equal(
    moduleProfile.module.abilities[0].startWindowBackground,
    '$color:start_window_background'
  );

  const startWindowColors = ['base', 'dark'].map((variant) => {
    const resource = JSON.parse(
      readFileSync(
        join(
          projectRoot,
          'entry',
          'src',
          'main',
          'resources',
          variant,
          'element',
          'color.json'
        ),
        'utf8'
      )
    );
    return resource.color.find(({ name }) => name === 'start_window_background')?.value;
  });

  assert.deepEqual(startWindowColors, ['#050608', '#050608']);
});
