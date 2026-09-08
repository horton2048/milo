# MILO HarmonyOS Permission Matrix

Every permission declared in `apps/harmony/entry/src/main/module.json5` must
have a matching entry here. A permission with no implementation is treated as
an audit failure.

| Permission | Used by feature | Request moment | Denial behaviour | User-facing explanation | Official API |
| --- | --- | --- | --- | --- | --- |
| `ohos.permission.MICROPHONE` | Voice input button in `ChatScreen` (planned; not yet wired into the default UI) | Only when the user taps the voice input control. Never at startup, never pre-emptively. | Speech input is unavailable; text entry remains fully functional. The `SpeechInput` state machine treats denial as a normal outcome and never throws. | "用于在「回响」时录入你的声音，方便你口述回忆。" (`mic_reason` in `string.json`) | `@ohos.ai.speechRecognizer` (HarmonyOS SpeechKit) with `locale = zh-CN` |

## Unrequested by design

The following capabilities appear in some competing diary apps but are
**deliberately not** requested by MILO:

- **Microphone background listening.** Voice capture only runs while the
  chat screen is foregrounded; the session is torn down on cancel or dispose.
- **Location.** Not required for emotion capture or recall.
- **Contacts.** No social features; we never read or sync the address book.
- **Storage / media library.** The rendered card image is written to an
  app-owned sandbox temp file (`ShareService.preview`); it never touches
  public media folders and is cleaned up after the share completes.
- **Device identifiers.** No `UDID`, `OAID`, or advertising-id reads. The
  gateway's `requestId` is generated client-side and used only for log
  correlation, not for device fingerprinting.
- **Camera.** Not used.
- **Push / notification permissions.** Not requested.

## How to verify

```bash
# Inspect the manifest directly:
cat apps/harmony/entry/src/main/module.json5 | grep -A 2 requestPermissions

# Confirm permission prompts only fire on user activation:
rg -n 'atManager.requestPermissionsFromUser' apps/harmony
```

The unit test suite (`SystemAdapters.test.ets`) covers the denial path:
`SpeechInput.begin()` returns `state === 'denied'` without throwing when
the injected `SpeechPlatform.checkPermission()` reports `denied`, so the
rest of the conversation flow stays usable.