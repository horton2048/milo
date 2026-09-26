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
