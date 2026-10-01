# Spec Delta

## Purpose

Provide an iPhone MILO experience that preserves the current HarmonyOS product's complete navigation, emotional expression, durable memories and account/settings behavior while respecting native iOS controls.

## ADDED Requirements

### Requirement: Complete navigation and mood expression
The iOS product SHALL expose the same 12 page families and 13 principal views as the frozen HarmonyOS reference: login, mood orbit, descriptor orbit, classify, now note, past time, chat, diary, timeline, detail, cards, account and AI settings. The seven primary mood positions, original planet assets, twelve descriptors and maximum three selections MUST retain their meaning and order. The default brand appearance SHALL be the reference's dark starfield.

#### Scenario: Choose and revise a feeling
- **WHEN** a user selects a mood, enters the descriptor ring, selects up to three words, returns to mood selection and enters again
- **THEN** prior descriptors are cleared, the focused and selected words remain legible, and continuing leads to the present/past choice.

### Requirement: Present and past journeys complete offline
The app SHALL allow an empty or written present note to save and open its card. Past memories SHALL choose a preset or custom time, converse, optionally form and edit a diary, and save to a card. AI failures MUST preserve user input and fall back to concise local prompts; a local diary MUST only use user-provided facts. Back navigation and unfinished input SHALL remain recoverable.

#### Scenario: Present memory and restart
- **WHEN** a user saves a present note and restarts the app
- **THEN** the memory appears in the timeline and detail with the same mood, words and content.

#### Scenario: Past memory without network
- **WHEN** a user chooses a time, responds to local guidance, edits a diary and saves offline
- **THEN** the conversation and selected diary content persist, the card opens, and the memory remains readable after restart.

#### Scenario: Interrupted expression
- **WHEN** the app terminates with unsent conversation text or an unfinished diary
- **THEN** the isolated user's draft restores; changing the past-time context resets only context-dependent content.

### Requirement: Collection and card behavior
The app SHALL provide empty/populated timeline, full detail, transcript expansion, deletion with safe recovery/confirmation, both planet-letter and orbit-theatre card templates, persistent template selection and working native image/share export. Markdown/JSON export SHALL include memories and exclude credentials.

#### Scenario: Inspect and export a memory
- **WHEN** a user opens a past memory, expands its transcript, switches card templates and exports
- **THEN** the saved template is retained, the native export contains the selected memory, and no API key or account credential is included.

### Requirement: Account and AI settings are honest and functional
The app SHALL reproduce login forms, owner-local entry, account/avatar controls and AI settings. Production remote authentication MUST use an actual supported provider configured for the iOS bundle, never a simulated success. HTTPS personal-provider settings SHALL bind consent and Keychain credentials to account and destination, reset consent on destination changes, and preserve offline functionality. Hosted membership preview SHALL remain non-purchasable until a real entitlement service exists.

#### Scenario: Credentials and missing configuration
- **WHEN** a user changes the provider destination or remote authentication is not configured
- **THEN** destination consent is requested again, keys are not copied into plaintext settings, and unavailable remote actions clearly report their condition without fabricating login or connectivity.

#### Scenario: Account operations
- **WHEN** a real account operation fails or a user cancels deletion
- **THEN** personal entries and credentials are not silently erased; local-owner operation and remote-provider verification remain separately evidenced.

### Requirement: Existing records remain intact
The expanded store SHALL read the iOS pilot's schema-1 now records, preserve all supported content during migration, and retain original bytes when decoding or writing fails. Unknown future versions MUST block destructive rewriting.

#### Scenario: Upgrade and storage failure
- **WHEN** an existing pilot record is loaded and a new richer record is saved, or a write fails
- **THEN** the old record survives unchanged in meaning and a failed write leaves the original file and unsaved input intact.

## 2026-09-29 user-authorized scope amendment

The current reference is the actual public Web experience at https://milo.huangtangai.top/app, per the user's explicit direction; do not launch HarmonyOS. Preserve the prior Harmony evidence as historical. Develop only in /Users/hut/Projects/milo. The current phase restores Web starfield/touch motion and page semantics while improving native iOS controls, retains all 53 native state checks, and records Web-absent native states separately without fabricating reference screenshots. See docs/visual-parity/web-native-plan-2026-09-29.md for the reviewed implementation and acceptance plan. This amendment supersedes the prior requirement to use a sibling worktree or to obtain new Harmony runtime captures for this phase; real account/device release claims remain separate.

## ADDED Requirements

### Requirement: Account settings affect actual behavior
The iOS client SHALL expose login and account settings through normal navigation and SHALL apply saved AI defaults to new memories and explicitly saved settings to the active conversation. Restored drafts SHALL preserve their existing per-conversation choice. A password reset that succeeds before sign-in fails SHALL return to password sign-in with accurate status. Remote sign-out cleanup failure SHALL NOT trap a user in the local account; unsuccessful local cleanup SHALL remain an error.

#### Scenario: Saved AI default and active request
- **WHEN** the user disables AI and saves settings during an active request, then starts a new memory or restarts
- **THEN** the old request cannot mutate the conversation, the new memory uses the saved default, and a restored draft retains its recorded choice

#### Scenario: Reset succeeded before sign-in failed
- **WHEN** the service resets the password but subsequent password sign-in fails
- **THEN** the user sees that the password changed and can retry password login without reusing the consumed reset code

#### Scenario: Offline exit
- **WHEN** remote sign-out cleanup fails while local session storage is writable
- **THEN** the app returns to login and retains the user's local memories and draft content

### Requirement: Simulator installation is launchable and identifiable
The delivered simulator build SHALL launch from its normal home-screen icon using Xcode-generated signing and SHALL include a compiled opaque MILO AppIcon. Repeated cold launch and foreground/background transitions SHALL preserve the current account and records without unexpected exits. A successful build alone MUST NOT be reported as installation acceptance.

#### Scenario: Restore a previously broken installation
- **WHEN** a simulator installation is replaced after signing-related launch failure
- **THEN** installed bytes match the verified build, icon launch reaches login or the retained journal, and repeated cold launches succeed without deleting production data

#### Scenario: Native secure storage
- **WHEN** isolated personal credentials are saved, read and removed in the simulator test environment
- **THEN** actual Keychain operations succeed with Xcode-supported signing and failures are not replaced by plaintext or simulated success
