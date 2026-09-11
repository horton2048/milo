import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import test from 'node:test';

const projectRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const sdkRoot = '/Applications/DevEco-Studio.app/Contents/sdk';
const bundledSdk = join(sdkRoot, 'default');

test('hvigorw prepares the bundled API 24 SDK layout before invoking Hvigor', () => {
  const result = spawnSync(join(projectRoot, 'hvigorw'), ['--version'], {
    cwd: projectRoot,
    encoding: 'utf8'
  });

  assert.equal(result.status, 0, result.stderr || result.stdout);
  assert.equal(
    readFileSync(join(projectRoot, 'local.properties'), 'utf8'),
    `sdk.dir=${sdkRoot}\n`
  );
  const sdkPkg = JSON.parse(readFileSync(join(bundledSdk, 'sdk-pkg.json'), 'utf8'));
  assert.equal(sdkPkg.data.apiVersion, '24');
  assert.equal(sdkPkg.data.platformVersion, '6.1.1');
  for (const component of ['ets', 'js', 'native', 'previewer', 'toolchains']) {
    assert.ok(
      existsSync(join(bundledSdk, 'openharmony', component, 'oh-uni-package.json')),
      `Missing OpenHarmony API 24 component: ${component}`
    );
  }
});

test('root page wires the complete recall flow on the dark background', () => {
  const source = readFileSync(
    join(projectRoot, 'entry', 'src', 'main', 'ets', 'pages', 'Index.ets'),
    'utf8'
  );

  for (const contract of [
    'HomeScreen({',
    'ClassifyScreen({',
    'NowNoteScreen({',
    'PastTimeScreen({',
    'ChatScreen({',
    'DiaryScreen({',
    'TimelineScreen({',
    'DetailScreen({',
    'CardScreen({',
    ".width('100%')",
    ".height('100%')",
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
  assert.ok(
    moduleProfile.module.requestPermissions.some(({ name }) => name === 'ohos.permission.INTERNET'),
    'The native AI gateway client requires the INTERNET permission'
  );
});
