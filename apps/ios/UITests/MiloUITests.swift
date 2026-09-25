import XCTest

final class MiloUITests: XCTestCase {
    @MainActor
    private func launch(id: String = UUID().uuidString, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-id", id] + extra
        app.launch()
        XCTAssertTrue(app.buttons["open-history"].waitForExistence(timeout: 10))
        return app
    }

    @MainActor
    func testWrittenNotePersistsAcrossRelaunch() throws {
        let id = UUID().uuidString
        let app = launch(id: id)
        app.buttons["mood-bright"].tap()
        let editor = try focusEditor(in: app)
        editor.typeText("  今天散步很开心  ")
        app.buttons["save-entry"].tap()
        XCTAssertTrue(app.staticTexts["今天散步很开心"].waitForExistence(timeout: 5))
        app.terminate()
        app.launch()
        app.buttons["open-history"].tap()
        let note = app.staticTexts["今天散步很开心"]
        XCTAssertTrue(note.waitForExistence(timeout: 5))
        note.tap()
        XCTAssertEqual(app.staticTexts["entry-note"].label, "今天散步很开心")
        XCTAssertTrue(app.staticTexts["明亮"].exists)
    }

    @MainActor
    func testBlankNoteAndEmptyHistory() {
        let app = launch()
        app.buttons["open-history"].tap()
        XCTAssertTrue(app.staticTexts["这里还很安静"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["save-entry"].tap()
        XCTAssertTrue(app.staticTexts["（一次安静的记录）"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testWriteFailureKeepsDraftAndCanRecover() throws {
        let id = UUID().uuidString
        let app = launch(id: id, extra: ["--uitest-write-failure"])
        let editor = try focusEditor(in: app)
        editor.typeText("失败也别丢掉这句话")
        app.buttons["save-entry"].tap()
        XCTAssertTrue(app.otherElements["storage-error"].exists || app.staticTexts["storage-error"].exists)
        XCTAssertEqual(editor.value as? String, "失败也别丢掉这句话")
        app.terminate()
        app.launchArguments = ["--uitest-id", id]
        app.launch()
        app.buttons["open-history"].tap()
        XCTAssertTrue(app.staticTexts["这里还很安静"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testCorruptDataRemainsBlockedAfterRelaunch() {
        let id = UUID().uuidString
        let app = launch(id: id, extra: ["--uitest-corrupt"])
        XCTAssertFalse(app.buttons["save-entry"].isEnabled)
        XCTAssertTrue(app.buttons["retry-load"].exists)
        app.terminate()
        // Remove corruption injection; the existing file must still be unreadable.
        app.launchArguments = ["--uitest-id", id]
        app.launch()
        XCTAssertTrue(app.buttons["retry-load"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["save-entry"].isEnabled)
        app.buttons["retry-load"].tap()
        XCTAssertFalse(app.buttons["save-entry"].isEnabled)
    }

    @MainActor
    func testLongNoteAndLargeTextScreenshots() throws {
        var lightKeyboardImage: Data?
        var lightDetailImage: Data?
        for appearance in ["Light", "Dark"] {
            let app = launch(extra: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL", "--uitest-appearance", appearance])
            assertResolvedAppearance(appearance, in: app)
            let editor = try focusEditor(in: app)
            let text = String(repeating: "今天慢慢走了一段路，风很温柔。", count: 12)
            editor.typeText(text)
            XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "The software keyboard must actually be shown for the reachability check")
            XCTAssertTrue(app.buttons["save-entry"].isHittable)
            let keyboardImage = app.screenshot()
            assertDistinctAppearanceImage(keyboardImage, comparedWith: &lightKeyboardImage)
            let keyboardShot = XCTAttachment(screenshot: keyboardImage)
            keyboardShot.name = "capture-large-text-keyboard-\(appearance)"
            keyboardShot.lifetime = .keepAlways
            add(keyboardShot)
            app.buttons["save-entry"].tap()
            let entry = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "entry-")).firstMatch
            XCTAssertTrue(entry.waitForExistence(timeout: 5))
            entry.tap()
            XCTAssertEqual(app.staticTexts["entry-note"].label, text)
            assertResolvedAppearance(appearance, in: app)
            let detailImage = app.screenshot()
            assertDistinctAppearanceImage(detailImage, comparedWith: &lightDetailImage)
            let detailShot = XCTAttachment(screenshot: detailImage)
            detailShot.name = "detail-large-text-\(appearance)"
            detailShot.lifetime = .keepAlways
            add(detailShot)
            app.terminate()
        }
    }

    @MainActor
    func testNormalSizeHomeScreenshots() {
        var lightImage: Data?
        for appearance in ["Light", "Dark"] {
            let app = launch(extra: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL", "--uitest-appearance", appearance])
            assertResolvedAppearance(appearance, in: app)
            let image = app.screenshot()
            assertDistinctAppearanceImage(image, comparedWith: &lightImage)
            let screenshot = XCTAttachment(screenshot: image)
            screenshot.name = "home-standard-text-\(appearance)"
            screenshot.lifetime = .keepAlways
            add(screenshot)
            app.terminate()
        }
    }

    @MainActor
    private func assertResolvedAppearance(_ appearance: String, in app: XCUIApplication) {
        let root = app.otherElements["uitest-appearance-root"]
        XCTAssertTrue(root.waitForExistence(timeout: 5), "The debug appearance fixture must be active")
        let applied = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", appearance), object: root)
        XCTAssertEqual(XCTWaiter.wait(for: [applied], timeout: 5), .completed, "SwiftUI must resolve the requested appearance before capturing evidence")
    }

    @MainActor
    private func assertDistinctAppearanceImage(_ image: XCUIScreenshot, comparedWith lightImage: inout Data?) {
        let bytes = image.pngRepresentation
        if let light = lightImage {
            // Different bytes alone cannot prove appearance: clocks and cursors also
            // change. Keep the resolved-scheme check and independent visual review.
            XCTAssertNotEqual(bytes, light, "Light and Dark evidence must not be identical screenshots")
        } else {
            lightImage = bytes
        }
    }

    /// `isHittable` alone can include a TextEditor obscured by a safe-area inset.
    /// Scroll the outer gutter, then tap only the editor's unobscured intersection.
    @MainActor
    private func focusEditor(in app: XCUIApplication) throws -> XCUIElement {
        let editor = app.textViews["note-input"]
        let scroll = app.scrollViews["capture-scroll"]
        let save = app.buttons["save-entry"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        XCTAssertTrue(scroll.waitForExistence(timeout: 5))

        for _ in 0..<20 {
            let top = max(scroll.frame.minY, app.navigationBars.firstMatch.frame.maxY) + 12
            let bottom = min(scroll.frame.maxY, save.frame.minY) - 12
            let viewport = CGRect(x: scroll.frame.minX + 12, y: top,
                                  width: max(0, scroll.frame.width - 24), height: max(0, bottom - top))
            let visibleEditor = editor.frame.intersection(viewport)
            if !visibleEditor.isNull, visibleEditor.width >= 100, visibleEditor.height >= 100 {
                point(in: app, x: visibleEditor.midX, y: visibleEditor.midY).tap()
                XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "Tapping the visible editor must focus it, not save an empty record")
                XCTAssertTrue(editor.exists, "Focusing must keep the capture screen open")
                return editor
            }
            // Stay outside the editor's own scroll surface and above the save bar.
            let x = scroll.frame.minX + 6
            point(in: app, x: x, y: viewport.maxY - 16)
                .press(forDuration: 0.05, thenDragTo: point(in: app, x: x, y: viewport.minY + 16))
        }
        XCTFail("The editor never became visibly reachable above the save action")
        return try XCTUnwrap(nil as XCUIElement?)
    }

    @MainActor
    private func point(in app: XCUIApplication, x: CGFloat, y: CGFloat) -> XCUICoordinate {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
            .withOffset(CGVector(dx: x - app.frame.minX, dy: y - app.frame.minY))
    }
}
