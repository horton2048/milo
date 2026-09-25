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
    func testWrittenNotePersistsAcrossRelaunch() {
        let id = UUID().uuidString
        let app = launch(id: id)
        app.buttons["mood-bright"].tap()
        let editor = app.textViews["note-input"]
        editor.tap()
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
    func testWriteFailureKeepsDraftAndCanRecover() {
        let id = UUID().uuidString
        let app = launch(id: id, extra: ["--uitest-write-failure"])
        let editor = app.textViews["note-input"]
        editor.tap()
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
    func testLongNoteAndLargeTextScreenshots() {
        for appearance in ["Light", "Dark"] {
            let app = launch(extra: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL", "-AppleInterfaceStyle", appearance])
            let editor = app.textViews["note-input"]
            for _ in 0..<5 where !editor.isHittable { app.swipeUp() }
            editor.tap()
            let text = String(repeating: "今天慢慢走了一段路，风很温柔。", count: 12)
            editor.typeText(text)
            XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "The software keyboard must actually be shown for the reachability check")
            XCTAssertTrue(app.buttons["save-entry"].isHittable)
            let keyboardShot = XCTAttachment(screenshot: app.screenshot())
            keyboardShot.name = "capture-large-text-keyboard-\(appearance)"
            keyboardShot.lifetime = .keepAlways
            add(keyboardShot)
            app.buttons["save-entry"].tap()
            let entry = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "entry-")).firstMatch
            XCTAssertTrue(entry.waitForExistence(timeout: 5))
            entry.tap()
            XCTAssertEqual(app.staticTexts["entry-note"].label, text)
            let detailShot = XCTAttachment(screenshot: app.screenshot())
            detailShot.name = "detail-large-text-\(appearance)"
            detailShot.lifetime = .keepAlways
            add(detailShot)
            app.terminate()
        }
    }
}
