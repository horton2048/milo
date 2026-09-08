# MILO HarmonyOS

Bundle name: `com.milo.echoes`

Stage-model ArkTS application that mirrors the MILO web diary/recall
experience for HarmonyOS devices. Architecture, screen flow, and AI
fallback contract are identical to the web build; only the render layer
changes. See `docs/superpowers/plans/2026-08-08-harmonyos-native-replica.md`
for the multi-platform strategy and `docs/compliance/` for the release
artifacts.

## Toolchain

- DevEco Studio 6.1.1, build `DS-243.24978.46.36.611300`
- OpenHarmony SDK API 24 Release `6.1.1.125`: ArkTS/Ets, Js, Native, Previewer, and Toolchains
- Node.js `v18.20.1`
- OHPM `6.1.2.285`
- Hvigor `6.24.4`
- HDC `3.2.0d`
- JetBrains Runtime `21.0.8` (`JBR-21.0.8+9-1038.71-jcef`)

The reproducible wrapper expects DevEco Studio at `/Applications/DevEco-Studio.app/Contents` unless `DEVECO_STUDIO_HOME` is set. It uses DevEco's bundled Node, Hvigor, JBR, HDC, and OpenHarmony SDK; no system Java is required. Because the app-bundled SDK stores API 24 components in a flat directory, the wrapper creates an ignored `.deveco-sdk/24` compatibility link and regenerates ignored `local.properties` before every invocation.

## Source layout

```
entry/src/main/ets
├── core/
│   ├── data/         # MapKVStorage + EntryRepository + RecallSessionRepository
│   ├── flow/         # RecallMachine state machine
│   ├── model/        # Domain types, Moods, MoodAssets
│   ├── network/      # AiGatewayClient + typed HTTP transport
│   ├── system/       # SpeechInput, Haptics, CardRenderer, ShareService
│   └── theme/        # MiloTheme tokens
├── features/
│   ├── conversation/ # ChatScreen, ConversationController, FallbackGuide
│   ├── diary/        # DiaryScreen
│   ├── home/         # HomeScreen
│   ├── mood/         # MoodOrbitCarousel + gesture model
│   ├── recall/       # ClassifyScreen, NowNoteScreen, PastTimeScreen
│   ├── share/        # ShareCardScreen
│   └── timeline/     # TimelineScreen, DetailScreen, CardScreen
└── pages/Index.ets   # Root navigation + draft hydration
```

Tests live in `entry/src/ohosTest/ets/test/` and are wired in
`entry/src/test/List.test.ets`. The test suite covers domain types, the
recall state machine, repositories, the offline fallback flow, the
mood-orbit swipe model, the AI gateway client, the conversation
controller, the system adapters, and the card renderer contract.

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

## Verification matrix

Run from the repo root after every release candidate:

```bash
npm test                       # 133 web tests
npm run build                  # web build to apps/web/dist
npm -w services/ai-gateway test
npm -w services/ai-gateway run build
cd apps/harmony && ./hvigorw clean && ./hvigorw test && ./hvigorw assembleHap
```

Last verified locally:

- `npm test` — 133 / 133 pass
- `npm -w services/ai-gateway test` — 15 / 15 pass
- `./hvigorw test` — all Hypium suites green (Domain, RecallMachine, MoodAssets, EntryRepository, OfflineFlow, MoodSwipeModel, ConversationController, SystemAdapters, CardRenderer, plus the LocalUnit boilerplate)
- `./hvigorw assembleHap` — `BUILD SUCCESSFUL`

## Compliance and release

- `docs/compliance/data-flow.md` — every data category, trigger, retention, and processor
- `docs/compliance/permissions.md` — `ohos.permission.MICROPHONE` matrix
- `docs/compliance/release-checklist.md` — reviewer test path (fresh install → privacy → now → past AI → forced offline → share → deletion)

MILO uses **MiniMax** (`api.minimax.chat`) as the AI processor for chat and
diary generation. The local `FallbackGuide` and `fallbackDiary` paths cover
every AI failure so the diary flow always completes offline. The product
is a personal diary and recall tool, **not** a mental-health diagnosis or
treatment service.