# Proposal

## Why

The first iOS slice proved the toolchain and local journal, but does not reproduce MILO's HarmonyOS product. The user requires every product page and important state to be compared through actual paired screenshots, with complete interaction parity and a coherent aesthetic improvement.

## What Changes

- Freeze the current HarmonyOS working-tree reference by source and signed-build hashes, then capture its actual pages; older store screenshots are historical only.
- Replace the simplified iOS single-screen prototype with the complete HarmonyOS navigation, mood/word selection, present/past capture, guided conversation, diary, timeline, detail, cards, login, account and AI settings experience.
- Preserve shared MILO assets, copy, product semantics and offline recovery. Improve spacing, typography, materials, contrast and native safe-area/keyboard behavior without replacing the brand or removing pages.
- Add a page/state parity ledger with paired real screenshots, device/data provenance, explicit acceptable platform differences, missing coverage and independent visual findings.
- Make full scenario and screenshot coverage required for final acceptance. A successful build, a few screenshots or the earlier pilot gate cannot approve this broader milestone.

## Capabilities

### New Capabilities

- `ios-product-parity`: Complete native product journeys and data behavior equivalent to the frozen HarmonyOS reference.
- `cross-platform-visual-acceptance`: Source-bound, page/state-complete paired screenshot review with measurable fidelity, accessibility and aesthetic criteria.

### Modified Capabilities

None. The prior offline pilot remains a historical, narrower milestone; this change expands product acceptance without rewriting its evidence.

## Impact

`apps/ios` native app, portable models/persistence, assets, interaction tests and verification scripts; new reference evidence and parity documentation. The current HarmonyOS working tree is the authoritative reference and must be preserved. Release signing, App Store submission and purchases are separate actions; external account configuration or owner-only operations must be recorded as blocked rather than simulated in production. True physical-device validation remains distinct from simulator evidence.

## 2026-09-29 user-authorized scope amendment

The current reference is the actual public Web experience at https://milo.huangtangai.top/app, per the user's explicit direction; do not launch HarmonyOS. Preserve the prior Harmony evidence as historical. Develop only in /Users/hut/Projects/milo. The current phase restores Web starfield/touch motion and page semantics while improving native iOS controls, retains all 53 native state checks, and records Web-absent native states separately without fabricating reference screenshots. See docs/visual-parity/web-native-plan-2026-09-29.md for the reviewed implementation and acceptance plan. This amendment supersedes the prior requirement to use a sibling worktree or to obtain new Harmony runtime captures for this phase; real account/device release claims remain separate.
