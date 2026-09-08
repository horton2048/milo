# MILO HarmonyOS Data Flow

This document enumerates every category of user data handled by the HarmonyOS
Stage build (`apps/harmony`) and the `services/ai-gateway`. Each row lists
what is collected, when it is collected, where it lands, who processes it,
how long it is retained, and whether it ever leaves the device. Privacy
reviewers and release managers should treat this as the single source of
truth; if a new data category appears in code, add it here before merge.

| Category | Trigger | Local destination | Remote destination | Retention | Deletion | Processor | Leaves device |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Mood selection (valence + labels + `MoodId`) | User taps a mood on the orbit carousel | `EntryRepository` (in-memory + JSON file under app preferences) | None in normal flow | Until the entry is deleted or 30 days of inactivity | `EntryRepository.remove()` or app data clear | Device only | No |
| Time mark (`timeMark`) | User text-input on `PastTimeScreen` | `RecallSessionRepository` draft + persisted entries | None | Same as entry | Entry deletion | Device only | No |
| User transcript lines (`role: 'user'`) | User taps send in `ChatScreen` | Appended to `Draft.transcript`, persisted via `EntryRepository` | Sent to `/v1/recall/respond` when AI is enabled | Lifetime of the entry | Entry deletion | Device + `services/ai-gateway` + MiniMax (`api.minimax.chat`) | Yes (only when AI is enabled) |
| AI transcript lines (`role: 'ai'`) | AI reply or scripted guide | Appended to `Draft.transcript`, persisted with the entry | None | Lifetime of the entry | Entry deletion | Device only when scripted; device + gateway + MiniMax when AI | Yes (only when AI is enabled) |
| Diary body | AI diary generation OR local `fallbackDiary` | `DiaryEntry.diary` in repository | Sent to `/v1/recall/diary` when AI is enabled | Lifetime of the entry | Entry deletion | Same as user transcript | Yes (only when AI is enabled) |
| Microphone audio stream | User taps the voice button and grants `ohos.permission.MICROPHONE` | Never stored on disk; consumed by the recognizer in memory | Never sent off device | Stream lives only inside the recognition session | Session end / cancellation / denial | HarmonyOS `voiceRecognizer` (on-device by default for `zh-CN`) | No |
| Recognized Chinese text | Final recognizer callback | Merged into the active `input` field; never auto-sent | None | Cleared when the user submits or cancels | Discarded on session end | Device only | No |
| Rendered card bitmap | User taps "分享到系统" on the share preview | `ShareService` temp file under the app sandbox | Opened in the system share sheet | Removed after share attempt (success, cancel, or failure) | `ShareService.cleanup()` | Device + system share targets chosen by user | Only as far as the user shares |
| `requestId` (request correlation) | Every `/v1/recall/*` request | App-side log buffer | `x-request-id` header to gateway | Logs rotate on app restart | Log buffer clear | Device + gateway | Yes (header only, no payload) |
| Operational logs | Each `/v1/recall/*` call completes | In-memory request log on the gateway | Console + log file under `/var/log/milo-gateway` | 7 days rolling | Log rotate + cron | `services/ai-gateway` | Yes (no user content; only route + status + requestId) |
| App preferences (window background, theme tokens) | `aboutToAppear` of `Index` | Local preferences store | None | Until app data is cleared | App data clear | Device only | No |

## Notes

- **No device identifiers, contacts, location, or persistent device storage are
  collected.** The HarmonyOS manifest only requests `MICROPHONE` and the
  release pipeline does not request `ohos.permission.READ_MEDIA`,
  `ohos.permission.LOCATION`, or any identifier-granting scope.
- **The microphone permission is requested only when the user explicitly
  activates voice input.** It is never asked for at startup.
- **AI calls are best-effort.** Every AI endpoint is wrapped by
  `ConversationController` which falls back to local scripted replies on any
  failure; the user can always finish a memory without contacting the
  gateway.
- **No content leaves the device when AI is unavailable.** When the gateway
  rejects the request or the device is offline, all conversation text stays
  on device.
- **Logs never include user text.** `services/ai-gateway` request logging
  records `route`, `status`, and `requestId` only; `requestLog` tests assert
  that body content does not appear in serialized entries.