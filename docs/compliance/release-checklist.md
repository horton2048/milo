# MILO HarmonyOS Release Checklist

Reviewers should run every step in order. Do not skip the live-device
section — automated tests cannot exercise the HarmonyOS speech recognizer
or the system share sheet.

## 0. Pre-flight

- [ ] The repository is clean: `git status --short` reports only intended
      changes (or nothing at all).
- [ ] No real API keys, signing material, HAP artifacts, or
      `local.properties` are tracked. See **scan** section below.
- [ ] Huawei developer account, AppGallery Connect identity, signing
      material, privacy-policy URL, and MiniMax deployment secret are all
      supplied **by the user** — never invented or hard-coded.

## 1. Fresh install

- [ ] Uninstall any previous MILO build on the device.
- [ ] Install the freshly built HAP from `apps/harmony/build/default/outputs/default/entry-default-signed.hap` (or the unsigned variant when no signing config is present).
- [ ] Launch the app. The start window background must match
      `apps/harmony/entry/src/main/resources/base/element/color.json`
      (`start_window_background`).
- [ ] The orbit carousel animates and `HomeScreen` shows entry count `0`.

## 2. Privacy policy entry

- [ ] Tap the privacy link in the About card.
- [ ] The page opens in the system browser pointed at the URL provided in
      the release manifest. No data is sent until the user records anything.

## 3. Now branch — quick capture

- [ ] Pick any mood on the orbit carousel.
- [ ] Choose "现在" → enter text → tap "收进回忆".
- [ ] Verify the entry appears on the Timeline screen with the correct
      valence, labels, and note.

## 4. Past branch — AI recall

- [ ] Pick a mood → choose "过去" → enter a time mark.
- [ ] On the chat screen, the AI opening greeting is requested via
      `POST /v1/recall/open`. With a live `MINIMAX_API_KEY` the AI reply
      appears within 5 s; otherwise the scripted fallback shows the
      `FallbackGuide.opening()` line.
- [ ] Send a reply. Verify the AI/script indicator switches to
      "回响" / "引导" accordingly.
- [ ] Trigger a forced failure (point the gateway at an invalid URL or
      `kill` the gateway mid-session) → the controller flips to the script
      and a recoverable notice ("AI 暂时不可用，已切换到引导式回响。")
      appears.

## 5. Past branch — diary

- [ ] Finish the scripted dialogue until "✦ 沉淀这段回忆" appears.
- [ ] The diary screen either shows AI-generated text or the local
      `fallbackDiary(...)` output. The user can edit before saving.
- [ ] Save → verify the entry persists across app restart and shows the
      edited diary on the detail screen.

## 6. Forced offline

- [ ] Toggle airplane mode on the device.
- [ ] Repeat the past flow; the script should run end-to-end without ever
      surfacing a network error to the user.
- [ ] Verify no requests hit the gateway (`tail` the request log) — every
      call must end with `OFFLINE` and the UI must show the recovery notice.

## 7. Timeline / detail

- [ ] Open Timeline → tap a memory → Detail screen renders the diary,
      time mark, and mood asset.
- [ ] Card preview thumbnail matches the selected sticker template.

## 8. Microphone denial

- [ ] Tap the voice button → when the permission prompt appears, choose
      "拒绝".
- [ ] The chat input remains usable; typing still composes messages.
- [ ] No crash, no blocked flow, no retry storm.

## 9. Card generation & share

- [ ] On the share preview screen, tap "✦ 分享到系统".
- [ ] The system share sheet appears. Picking a target delivers the
      rendered PNG.
- [ ] Cancel the share sheet → preview returns without error.
- [ ] Force a share failure (deny share permission) → the screen shows
      the failure notice and `ShareService.cleanup()` still removes the
      temp file.

## 10. Local-data deletion

- [ ] Long-press an entry on the Timeline → confirm removal.
- [ ] Verify the entry disappears and the in-memory `EntryRepository`
      list no longer references it.
- [ ] Clear app data via system settings → confirm no residual mood,
      transcript, or diary bytes remain on disk.

## 11. Disclosures

MILO is a **personal diary and recall tool**, not a mental-health diagnostic
or therapeutic service. The AI feature uses **MiniMax** (`api.minimax.chat`)
as the third-party processor for conversation and diary text. No personal
data is sold or used for training by MILO; MiniMax's data usage is governed
by their own privacy terms and the contract between the operator and
MiniMax.

## 12. Sign-off

- [ ] All steps pass on at least one physical HarmonyOS device running the
      same HarmonyOS version listed in `apps/harmony/build-profile.json5`.
- [ ] All automated test commands listed in `apps/harmony/README.md` pass
      green.
- [ ] The user has approved the final HAP before submission to
      AppGallery Connect.