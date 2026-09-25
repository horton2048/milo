# Tasks

## 1. Scope and framework setup

- [x] 1.1 Review the four planning artifacts independently and record any corrections and approval in review.md; validate using OpenSpec strict validation.
- [x] 1.2 Install the updated Specdrive project-local skill, record its provenance, and verify its tests and manifest validation.

## 2. Portable journal core

- [x] 2.1 Implement the seven moods and versioned local journal repository; verify trimming, blank records, identity upsert and deterministic ordering with Swift tests.
- [x] 2.2 Verify persistence across new repository instances, injected write/read errors, malformed data and unsupported versions; show original bytes remain unchanged.

## 3. Native iPhone app

- [x] 3.1 Implement capture, history and detail with accessible identifiers and failure recovery; build the iPhone simulator target successfully.
- [ ] 3.2 Add UI tests for mood/note save and relaunch, blank note, empty history and write/read failures; run on an iPhone simulator and retain xcresult.
- [ ] 3.3 Verify keyboard/save reachability, long Chinese text and accessibility text sizing in light/dark appearance using simulator screenshots and review evidence.

## 4. Framework integration evidence

- [x] 4.1 Execute the real Specdrive manifest and preserve per-check logs, current source fingerprints and explicit platform blocked states where applicable.
- [x] 4.2 Forward-test runner resume, stale evidence invalidation and failure caps in an isolated fixture; verify the full gate refuses incomplete iOS evidence.
- [ ] 4.3 Independently review the final diff, report actual results and limitations, and archive only if every required milestone check passes.
