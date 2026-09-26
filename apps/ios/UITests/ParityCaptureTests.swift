import XCTest

/// Captures real production views with isolated synthetic stores. These are
/// candidates for comparison, never an automatic visual approval.
final class ParityCaptureTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }
    private let cases = [
        "login--email",
        "login--password",
        "login--code",
        "login--reset",
        "login--error",
        "home--mood-calm",
        "home--mood-joyful",
        "home--mood-low",
        "home--words-empty",
        "home--words-three",
        "classify--default",
        "now-note--empty",
        "now-note--written",
        "now-note--keyboard-long",
        "past-time--empty",
        "past-time--preset",
        "past-time--custom",
        "chat--opening",
        "chat--conversation",
        "chat--offline",
        "chat--keyboard",
        "chat--busy",
        "diary--enabled",
        "diary--disabled",
        "diary--editing",
        "diary--long",
        "timeline--empty",
        "timeline--populated",
        "detail--now",
        "detail--past",
        "detail--transcript-expanded",
        "detail--missing",
        "detail--delete-confirmation",
        "card--planet-letter",
        "card--orbit-theatre",
        "account--local",
        "account--remote",
        "account--password-form",
        "account--export",
        "account--delete-confirmation",
        "ai-settings--hosted",
        "ai-settings--personal",
        "ai-settings--missing-config",
        "ai-settings--consent",
        "ai-settings--connection-error",
        "home--words-three--large-text",
        "now-note--keyboard-long--large-text",
        "chat--conversation--large-text",
        "diary--long--large-text",
        "timeline--populated--large-text",
        "detail--transcript-expanded--large-text",
        "account--local--large-text",
        "ai-settings--personal--large-text"
    ]
    @MainActor func testRequiredPageStates() {
        for caseID in cases {
            let app = XCUIApplication()
            app.launchArguments = ["--uitest-id", UUID().uuidString, "--parity-case", caseID]
            app.launch()
            let root = app.otherElements["parity-root"]
            XCTAssertTrue(root.waitForExistence(timeout: 10), caseID)
            XCTAssertEqual(root.value as? String, caseID.hasSuffix("--large-text") ? "accessibility5" : "large", caseID)
            let state = caseID.components(separatedBy: "--")[1]
            if ["keyboard", "keyboard-long"].contains(state) {
                let fieldID = caseID.hasPrefix("chat") ? "chat-input" : "note-input"
                let field = parityProbe(fieldID, in: app)
                XCTAssertTrue(field.exists)
                if !app.keyboards.firstMatch.exists {
                    // Reach the editor before tapping. Avoid drags on ring controls.
                    for _ in 0..<8 {
                        if field.isHittable { break }
                        app.swipeUp(velocity: .slow)
                    }
                    field.tap()
                }
                XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), caseID)
                Thread.sleep(forTimeInterval: 0.4)
            }
            assertParityState(caseID, in: app)
            if caseID == "login--error" { XCTAssertTrue(parityProbe("login-error-message", in: app).isHittable) }
            // A modal's underlying page is not evidence of the modal state.
            if caseID.contains("confirmation") {
                attach(caseID + "--top", app: app)
                assertParityState(caseID, in: app)
                app.terminate(); continue
            }
            var remainingImages = 60
            if caseID.hasPrefix("now-note--keyboard-long") {
                captureEntireViewport(caseID, region: "page", identifier: "parity-scroll-journey-now-note", app: app, remainingImages: &remainingImages)
                parityAlignEditor(in: app)
                captureEntireViewport(caseID, region: "editor", identifier: "parity-scroll-note-editor", app: app, remainingImages: &remainingImages)
            } else {
                let probes = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "parity-scroll-")).allElementsBoundByIndex
                if let identifier = probes.first(where: { $0.identifier != "parity-scroll-note-editor" })?.identifier {
                    captureEntireViewport(caseID, region: "page", identifier: identifier, app: app, remainingImages: &remainingImages)
                } else {
                    XCTAssertFalse(app.scrollViews.firstMatch.exists, "A scrollable page requires measured coverage: \(caseID)")
                    attach(caseID + "--top", app: app)
                }
            }
            assertParityState(caseID, in: app)
            app.terminate()
        }
    }

    @MainActor private func captureEntireViewport(_ caseID: String, region: String, identifier: String, app: XCUIApplication, remainingImages: inout Int) {
        let prefix = caseID + (region == "editor" ? "--editor" : "")
        let keyboardRequired = caseID.contains("--keyboard")
        let edge = identifier != "parity-scroll-note-editor"
        var measured = parityViewport(identifier, in: app)
        // Focus and lazy layout may start inside the content. Measure, then return
        // through real gestures to the top before claiming top coverage.
        for _ in 0..<60 {
            if measured.offset <= 1 { break }
            let previous = measured.offset
            parityDrag(measured.frame, downward: true, in: app, edge: edge)
            measured = parityViewport(identifier, in: app)
            XCTAssertLessThan(measured.offset, previous - 0.5, "Cannot reach top: \(caseID)")
        }
        XCTAssertLessThanOrEqual(measured.offset, 1, "Top was not reached: \(caseID)")
        XCTAssertGreaterThan(remainingImages, 0)
        if keyboardRequired { XCTAssertTrue(app.keyboards.firstMatch.exists) }
        attach(prefix + "--top", app: app, metrics: measured, region: region, probe: identifier)
        remainingImages -= 1
        var finished = measured.maxOffset <= 1
        var step = 0
        while !finished && remainingImages > 0 {
            step += 1
            let previous = measured
            // Even short overflowing pages need a real intermediate position.
            // Use a shorter first gesture, then verify its actual measured result.
            let distance = step == 1 ? min(measured.frame.height * 0.7, measured.maxOffset / 2) : nil
            parityDrag(measured.frame, downward: false, in: app, edge: edge, distance: distance)
            measured = parityViewport(identifier, in: app)
            // Store failed geometry too; a capture command must not silently
            // turn an unmeasured gap into successful visual coverage.
            if keyboardRequired { XCTAssertTrue(app.keyboards.firstMatch.exists) }
            attach(prefix + "--scroll-\(step)", app: app, metrics: measured, region: region, probe: identifier)
            remainingImages -= 1
            XCTAssertEqual(measured.frame.height, previous.frame.height, accuracy: 1, "Viewport changed during coverage: \(caseID)")
            XCTAssertGreaterThan(measured.offset, previous.offset + 0.5, "Scroll made no progress: \(caseID)")
            XCTAssertLessThanOrEqual(measured.offset - previous.offset, previous.frame.height * 0.9 + 1,
                                     "Uninspected gap between screenshots: \(caseID)")
            finished = measured.offset >= measured.maxOffset - 1
        }
        XCTAssertTrue(finished, "60-image bound reached without actual bottom: \(caseID)")
        if caseID.hasPrefix("home--words") { XCTAssertTrue(app.buttons["confirm-words"].isHittable) }
        if caseID.hasPrefix("diary--long") { XCTAssertTrue(app.buttons["edit-diary"].isHittable) }
        if caseID.hasPrefix("detail--transcript-expanded") {
            XCTAssertTrue(app.staticTexts["米洛：那一刻，是什么让你记住了它？"].isHittable)
        }
        if caseID.hasPrefix("card--") {
            XCTAssertTrue(app.buttons["card-template-planet-letter"].isHittable)
            XCTAssertTrue(app.buttons["card-template-orbit-theatre"].isHittable)
        }
    }

    @MainActor private func attach(_ name: String, app: XCUIApplication, metrics: ParityMeasuredViewport? = nil, region: String = "page", probe: String? = nil) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
        let tree = XCTAttachment(string: app.debugDescription)
        tree.name = name + "--accessibility"; tree.lifetime = .keepAlways; add(tree)
        if let metrics {
            let evidence: [String: Any] = ["region": region, "probe": probe ?? "", "raw": metrics.raw, "scrollOffset": metrics.offset,
                "totalContentHeight": metrics.contentHeight, "viewportHeight": metrics.frame.height,
                "maxScrollOffset": metrics.maxOffset,
                "visibleFrame": ["x": metrics.frame.minX, "y": metrics.frame.minY,
                                 "width": metrics.frame.width, "height": metrics.frame.height]]
            let data = try! JSONSerialization.data(withJSONObject: evidence, options: [.sortedKeys, .prettyPrinted])
            let receipt = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
            receipt.name = name + "--geometry"; receipt.lifetime = .keepAlways; add(receipt)
        }
    }
}
