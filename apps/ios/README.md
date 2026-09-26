# MILO for iPhone

Native SwiftUI implementation of the HarmonyOS MILO product: mood and descriptor rings, present/past memory journeys, offline guidance, diary editing, collection/detail, two card templates, local account entry and AI settings.

**Full cross-platform acceptance is still in progress.** Current scope, actual results and external blockers are in [PARITY-STATUS.md](PARITY-STATUS.md). The source-bound 53-case screenshot ledger and comparison contract are in [the visual parity documentation](../../docs/visual-parity/README.md).

Open `Milo.xcodeproj` with Xcode and an iPhone simulator. Minimum deployment is iOS 17; Swift 6.1+ is required by the portable test package. Use the **Milo** scheme. The local owner entry is `milo`. Remote AGC login reports missing configuration until a real iOS provider is integrated; synthetic screenshot identities never count as remote authentication.

```sh
# Run from repository root
npm ci --prefix apps/ios --ignore-scripts
xcodegen generate --spec apps/ios/project.yml
swift test --package-path apps/ios/MiloCore
apps/ios/scripts/test-journal-ai.sh
node --test apps/ios/tests/parity-evidence.test.mjs
node .agents/skills/specdrive/scripts/specdrive.mjs init apps/ios/specdrive.parity.json --project .
# Use the returned state directory for run/status/gate and every repair resume.
```

The app keeps device-local records and atomic JSON drafts in Application Support. Schema 1 remains readable and migrates on successful writes; unknown future or corrupted data blocks rewriting. Personal API keys are bound to account/provider/HTTPS destination in Keychain and excluded from exports. Every AI failure has a local fallback.

`specdrive.parity.json` is the current full-product manifest. Missing screenshot pairs or actual account integration blocks final acceptance. The previous `specdrive.config.json`, `verify.mjs` and pilot reports document the earlier offline slice; their six screenshots cannot approve the expanded product.

The portable package pins Apple's Swift Testing only for tests. Production business logic has no third-party runtime dependency. Original HarmonyOS mood artwork is reused byte-for-byte. Source assets, implementation, project configuration, tests and verification scripts are fingerprinted alongside actual builds; never copy a passing receipt onto changed code.

Raw `.xcresult` bundles, simulator stores and signing/service credentials stay local or in controlled CI artifacts. Do not publish personal diary data.
