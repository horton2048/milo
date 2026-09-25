# MILO for iPhone — Specdrive pilot

Native SwiftUI first milestone: choose one of seven moods, write an optional present-moment note, save locally, and read it in history/detail after restarting. This is an offline vertical slice, not full parity with the web/HarmonyOS apps. Past-memory conversation, AI, accounts, sync, export and release signing are separate future milestones.

## Open and run

Open `Milo.xcodeproj` in full Xcode with Swift 6.1 or later and an installed iOS 17+ simulator. Select the **Milo** scheme and an iPhone simulator. Simulator builds need no Apple Developer membership or signing credentials. The checked-in project is ready to open; regenerate from `project.yml` with XcodeGen 2.46+ only after changing project configuration.

```sh
# From the repository root
swift test --package-path apps/ios/MiloCore
node apps/ios/scripts/verify.mjs xcode-preflight
node apps/ios/scripts/verify.mjs build
node apps/ios/scripts/verify.mjs ui-test
```

The portable package pins Apple's open-source Swift Testing 6.2.4 as a **test-only** dependency because Command Line Tools on the pilot Mac did not include the Testing module. `Package.resolved` pins transitive dependencies. The app's business logic has no network or third-party runtime service.

The app stores versioned JSON in its own Application Support directory, writes atomically, and never replaces unreadable data with an empty journal. This milestone does not import another client's files. Debug UI-test launch arguments can only select UUID-named test stores; they cannot reset the personal journal.

## Verify with the updated Specdrive

The project-local framework is in `.agents/skills/specdrive`. Its provenance file records the source repository and exact installed file hashes. OpenSpec 1.13.2 is pinned in this directory's npm manifest; it is planning tooling, not the app build system.

```sh
npm ci --prefix apps/ios --ignore-scripts
node .agents/skills/specdrive/scripts/specdrive.mjs init apps/ios/specdrive.config.json --project . --state apps/ios/.specdrive/my-run
node .agents/skills/specdrive/scripts/specdrive.mjs run apps/ios/.specdrive/my-run
node .agents/skills/specdrive/scripts/specdrive.mjs gate apps/ios/.specdrive/my-run
```

Resume the same run with `run`; it reuses only current passing evidence. Config changes require a new state directory while old evidence remains intact. `status` is readable JSON; `gate` exits 0 only when all configured required checks are current and passed. Failed checks return 1 and blocked checks return 78. Do not delete/reset state to hide failed attempts.

Missing Xcode or an iPhone simulator deliberately blocks native checks; passing macOS tests is **not** iOS verification. A GitHub macOS workflow also runs the same manifest on branch `codex/ios-specdrive-pilot` and uploads `ios-specdrive-evidence` for independent review. After native checks pass, the job waits at most ten minutes for a review receipt on the separate `codex/ios-visual-receipts` branch. It then resumes the same run and executes the full gate; missing, stale or rejected review cannot produce a successful job. The final evidence is uploaded separately as `ios-specdrive-final-evidence`.

## Visual evidence

Six UI tests cover behavior and attach screenshots for normal text, long Chinese text, the software keyboard, accessibility text sizes, and light/dark appearance to the `.xcresult` bundle. The workflow exports attachments. For local runs, an independent reviewer must inspect them and create `apps/ios/evidence/visual-review.json` containing:

```json
{
  "verdict": "pass",
  "reviewer": "actual-reviewer-identifier",
  "reviewedAt": "actual-review-time",
  "sourceHash": "output-of-node-apps/ios/scripts/verify.mjs-source-hash",
  "bundle": "absolute-path-from-evidence/ui-test.json",
  "checks": {
    "keyboardReachable": true,
    "longChineseText": true,
    "accessibilityText": true,
    "lightAppearance": true,
    "darkAppearance": true
  },
  "screenshots": ["absolute-path-to-reviewed-light-image", "absolute-path-to-reviewed-dark-image"]
}
```

This shape is documentation, not a passing receipt. Do not create it before observing actual results. Keep the actual screenshots and result bundle inside `apps/ios/evidence`; external paths are rejected. The runner fingerprints this directory as well as source inputs so deleting/changing a reviewed image invalidates acceptance. Receipts provide traceability, not cryptographic proof of reviewer identity.

For cloud runs, the reviewer publishes `receipt.json` on `codex/ios-visual-receipts`, identifying the exact run ID, head commit, application source hash, result bundle name, and SHA-256 of each reviewed screenshot. `scripts/await-review.mjs` validates that transport receipt before creating the local shape above. The CI token has read-only access; the workflow cannot approve its own screenshots. A receipt for another run is never reused. An independent agent review is engineering evidence, not the user's design approval.

Current scope and remaining tasks live in `openspec/changes/ios-offline-journal`. Local raw logs and build outputs are ignored; publish only the curated verification report. Never include personal diary data or signing material in evidence.
