# MILO HarmonyOS

Bundle name: `com.milo.echoes`

This is an Empty Ability Stage-model ArkTS application generated from the DevEco Studio 6.1 official project, module, and ability templates. The root ability loads `pages/Index`.

## Toolchain

- DevEco Studio 6.1.1, build `DS-243.24978.46.36.611300`
- OpenHarmony SDK API 24 Release `6.1.1.125`: ArkTS/Ets, Js, Native, Previewer, and Toolchains
- Node.js `v18.20.1`
- OHPM `6.1.2.285`
- Hvigor `6.24.4`
- HDC `3.2.0d`
- JetBrains Runtime `21.0.8` (`JBR-21.0.8+9-1038.71-jcef`)

The reproducible wrapper expects DevEco Studio at `/Applications/DevEco-Studio.app/Contents` unless `DEVECO_STUDIO_HOME` is set. It uses DevEco's bundled Node, Hvigor, JBR, HDC, and OpenHarmony SDK; no system Java is required. Because the app-bundled SDK stores API 24 components in a flat directory, the wrapper creates an ignored `.deveco-sdk/24` compatibility link and regenerates ignored `local.properties` before every invocation.

## Install dependencies

```bash
/Applications/DevEco-Studio.app/Contents/tools/ohpm/bin/ohpm install --all
```

The generated `oh-package-lock.json5` pins `@ohos/hypium` 1.0.28 and `@ohos/hamock` 1.0.0.

## Build and test

```bash
./hvigorw clean
./hvigorw assembleHap
./hvigorw test
/Applications/DevEco-Studio.app/Contents/tools/node/bin/node --test tests/shell-contract.test.mjs
```

The unsigned debug HAP is generated at `entry/build/default/outputs/default/entry-default-unsigned.hap`. Signing must remain local and is intentionally not committed.
