import XCTest

final class MiloUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    @MainActor
    private func launch(id: String = UUID().uuidString, extra: [String] = [], login: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-id", id] + extra
        app.launch()
        if login, app.textFields["login-email"].waitForExistence(timeout: 3) {
            app.textFields["login-email"].tap()
            app.textFields["login-email"].typeText("milo")
            app.buttons["login-submit"].tap()
        }
        return app
    }
    @MainActor private func enterNow(_ app: XCUIApplication) {
        XCTAssertTrue(app.buttons["confirm-mood"].waitForExistence(timeout: 10))
        app.buttons["confirm-mood"].tap()
        app.buttons["confirm-words"].tap()
        app.buttons["choose-now"].tap()
    }
    @MainActor private func input(_ id: String, in app: XCUIApplication) -> XCUIElement {
        let field = app.descendants(matching: .any).matching(identifier: id).firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        return field
    }
    @MainActor private func tap(_ id: String, in app: XCUIApplication) {
        let button = app.buttons[id]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        func visible() -> Bool {
            guard button.isHittable else { return false }
            if id.hasPrefix("card-template-") {
                let footer = app.buttons["save-card"]
                return footer.exists && button.frame.minY >= app.frame.minY + 8
                    && button.frame.maxY <= footer.frame.minY - 12
            }
            return true
        }
        for _ in 0..<10 {
            if visible() { break }
            // A card's header can move above the viewport after choosing a template.
            // Scroll toward the target instead of always moving further down the page.
            if button.frame.midY < app.frame.midY { app.swipeDown() }
            else { app.swipeUp() }
        }
        XCTAssertTrue(visible(), "The visible page must expose the complete \(id) action above fixed controls")
        button.tap()
    }
    @MainActor private func capture(_ name: String, in app: XCUIApplication) {
        let image = XCTAttachment(screenshot: app.screenshot())
        image.name = name; image.lifetime = .keepAlways; add(image)
    }

    @MainActor func testPresentJourneyAndRestartPersistence() {
        let app = launch()
        XCTAssertTrue(app.buttons["mood-bright"].waitForExistence(timeout: 10))
        app.buttons["mood-bright"].tap()
        enterNow(app)
        let note = input("note-input", in: app); note.tap(); note.typeText("今天散步很开心")
        tap("save-now", in: app)
        XCTAssertTrue(app.buttons["card-done"].waitForExistence(timeout: 5))
        tap("card-done", in: app)
        app.terminate(); app.launch()
        let entry = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "timeline.entry.")).firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 10)); entry.tap()
        XCTAssertEqual(app.staticTexts["detail.content"].label, "今天散步很开心")
        XCTAssertTrue(app.staticTexts["明亮"].exists)
        capture("journey-present-detail", in: app)
    }

    @MainActor func testPastOfflineJourneyDiaryEditAndTemplatePersistence() {
        let app = launch()
        tap("confirm-mood", in: app); tap("confirm-words", in: app); tap("choose-past", in: app)
        XCTAssertFalse(app.buttons["start-chat"].isEnabled)
        tap("time-去年夏天", in: app); tap("start-chat", in: app)
        let field = input("chat-input", in: app); field.tap(); field.typeText("我记得那天和朋友一起散步。")
        tap("send-message", in: app)
        XCTAssertTrue(app.buttons["finish-chat"].waitForExistence(timeout: 8))
        tap("finish-chat", in: app)
        XCTAssertTrue(app.staticTexts["diary-content"].label.contains("和朋友一起散步"))
        tap("edit-diary", in: app)
        let diary = input("diary-editor", in: app); diary.tap(); diary.typeText("我想记住这一天。")
        tap("save-past", in: app)
        tap("card-template-orbit-theatre", in: app)
        XCTAssertTrue(app.buttons["card-template-orbit-theatre"].isSelected)
        capture("journey-past-card-orbit", in: app)
        tap("card-done", in: app)
        app.terminate(); app.launch()
        let entry = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "timeline.entry.")).firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 10)); entry.tap()
        XCTAssertTrue(app.staticTexts["detail.content"].label.contains("我想记住这一天"))
        tap("toggle-transcript", in: app)
        XCTAssertTrue(app.staticTexts["我：我记得那天和朋友一起散步。"].waitForExistence(timeout: 5))
        tap("open-card", in: app)
        XCTAssertTrue(app.buttons["card-template-orbit-theatre"].isSelected)
    }

    @MainActor func testBlankNoteAndEmptyCollection() {
        let app = launch()
        tap("open-timeline", in: app)
        XCTAssertTrue(app.staticTexts["这里还很安静"].waitForExistence(timeout: 5))
        tap("back", in: app); enterNow(app); tap("save-now", in: app)
        XCTAssertTrue(app.buttons["card-done"].waitForExistence(timeout: 5))
        tap("card-done", in: app)
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "timeline.entry.")).count, 1)
    }

    @MainActor func testUnsentDraftRestoresAndChangingTimeClearsContext() {
        let app = launch()
        tap("confirm-mood", in: app); tap("confirm-words", in: app); tap("choose-past", in: app)
        tap("time-昨天", in: app); tap("start-chat", in: app)
        let field = input("chat-input", in: app); field.tap(); field.typeText("还没有说完的话")
        app.terminate(); app.launch()
        XCTAssertEqual(input("chat-input", in: app).value as? String, "还没有说完的话")
        tap("back", in: app); tap("time-小时候", in: app); tap("start-chat", in: app)
        XCTAssertFalse((input("chat-input", in: app).value as? String ?? "").contains("还没有说完"))
        XCTAssertTrue(app.staticTexts["「小时候」，你最先想起什么？"].exists)
    }

    @MainActor func testWriteFailureRetainsInputThenRecovers() {
        let id = UUID().uuidString
        let app = launch(id: id, extra: ["--uitest-write-failure"])
        enterNow(app)
        let field = input("note-input", in: app); field.tap(); field.typeText("失败也别丢掉这句话")
        tap("save-now", in: app)
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5))
        app.alerts.buttons["知道了"].tap()
        XCTAssertEqual(input("note-input", in: app).value as? String, "失败也别丢掉这句话")
        app.terminate(); app.launchArguments = ["--uitest-id", id]; app.launch()
        XCTAssertEqual(input("note-input", in: app).value as? String, "失败也别丢掉这句话")
        tap("save-now", in: app)
        XCTAssertTrue(app.buttons["card-done"].waitForExistence(timeout: 5))
    }

    @MainActor func testCorruptStoreCannotBeRewritten() {
        let id = UUID().uuidString
        let app = launch(id: id, extra: ["--uitest-corrupt"], login: false)
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5))
        app.alerts.buttons["知道了"].tap()
        let email = app.textFields["login-email"]; email.tap(); email.typeText("milo"); app.buttons["login-submit"].tap()
        enterNow(app)
        XCTAssertFalse(app.buttons["save-now"].isEnabled)
        app.terminate(); app.launchArguments = ["--uitest-id", id]; app.launch()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5))
        app.alerts.buttons["知道了"].tap()
        XCTAssertFalse(app.buttons["save-now"].isEnabled)
    }

    @MainActor func testLargeTextKeyboardKeepsSaveReachable() {
        let app = launch(extra: ["--parity-case", "now-note--keyboard-long--large-text"], login: false)
        let field = input("note-input", in: app)
        // Tap the editor's visible intersection above the fixed save action.
        let save = app.buttons["save-now"]
        let top = max(field.frame.minY, app.frame.minY + 110)
        let bottom = min(field.frame.maxY, save.frame.minY - 16)
        if bottom > top + 30 {
            app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: field.frame.midX, dy: (top + bottom) / 2)).tap()
        } else { app.swipeUp(); field.tap() }
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(save.isHittable)
        field.typeText("大字号输入也要保留下来。")
        XCTAssertTrue((field.value as? String ?? "").contains("大字号输入也要保留下来。"))
        let viewport = parityViewport("parity-scroll-note-editor", in: app)
        XCTAssertLessThanOrEqual(field.frame.maxY, save.frame.minY)
        XCTAssertEqual(viewport.raw["isFirstResponder"], 1)
        XCTAssertEqual(viewport.raw["selectionIsEmpty"], 1)
        XCTAssertGreaterThan(viewport.raw["caretHeight"] ?? 0, 0)
        XCTAssertGreaterThanOrEqual(viewport.raw["caretY"] ?? -1, viewport.frame.minY - 1)
        XCTAssertLessThanOrEqual((viewport.raw["caretY"] ?? 0) + (viewport.raw["caretHeight"] ?? 0), viewport.frame.maxY + 1)
        capture("now-note--keyboard-long--large-text--keyboard", in: app)
        save.tap()
        XCTAssertTrue(app.buttons["card-done"].waitForExistence(timeout: 5))
    }

    @MainActor func testDescriptorLimitAndReentryReset() {
        let app = launch()
        tap("confirm-mood", in: app)
        for index in 0...3 { tap("word-\(index)", in: app) }
        XCTAssertEqual((0..<12).filter { app.buttons["word-\($0)"].isSelected }.count, 3)
        tap("back", in: app); tap("confirm-mood", in: app)
        XCTAssertEqual((0..<12).filter { app.buttons["word-\($0)"].isSelected }.count, 0)
    }

    @MainActor func testBothCardTemplatesRenderForNativeShare() {
        for template in ["planet-letter", "orbit-theatre"] {
            let app = launch(extra: ["--parity-case", "card--" + template], login: false)
            tap("share-card", in: app)
            let sheet = app.descendants(matching: .any).matching(identifier: "card-share-sheet").firstMatch
            XCTAssertTrue(sheet.waitForExistence(timeout: 8), "A rendered PNG must reach native sharing for \(template)")
            capture("export-" + template + "-native-share", in: app)
            app.terminate()
        }
    }
    @MainActor func testLargeTextEditorTailRemainsVisibleAndPersists() {
        let app = launch(extra: ["--parity-case", "now-note--empty--large-text"], login: false)
        let field = input("note-input", in: app)
        for _ in 0..<6 { if field.isHittable { break }; app.swipeUp() }
        field.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        let text = Array(repeating: "今天慢慢走了一段路，风很温柔。我想记住这段安静的时间。", count: 3).joined(separator: "\n\n") + "\n这里是实际输入的最后一句。"
        field.typeText(text)
        XCTAssertEqual(field.value as? String, text)
        let viewport = parityViewport("parity-scroll-note-editor", in: app)
        XCTAssertEqual(viewport.raw["isFirstResponder"], 1)
        XCTAssertEqual(viewport.raw["selectionIsEmpty"], 1)
        XCTAssertGreaterThan(viewport.raw["caretHeight"] ?? 0, 0)
        XCTAssertGreaterThanOrEqual(viewport.raw["caretY"] ?? -1, viewport.frame.minY - 1)
        XCTAssertLessThanOrEqual((viewport.raw["caretY"] ?? 0) + (viewport.raw["caretHeight"] ?? 0), viewport.frame.maxY + 1)
        capture("large-text-editor-actual-tail", in: app)
        tap("note-editor-done", in: app)
        XCTAssertFalse(app.keyboards.firstMatch.exists)
        tap("save-now", in: app); tap("card-done", in: app)
        // Relaunch the same isolated store without rebuilding the screenshot fixture.
        app.terminate(); app.launchArguments = Array(app.launchArguments.prefix(2)); app.launch()
        if app.textFields["login-email"].waitForExistence(timeout: 3) {
            app.textFields["login-email"].tap(); app.textFields["login-email"].typeText("milo")
            app.buttons["login-submit"].tap()
        }
        let entry = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "timeline.entry.")).firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 10)); entry.tap()
        XCTAssertEqual(app.staticTexts["detail.content"].label, text)
    }

    @MainActor func testCardTemplateGeometryAndLoginErrorState() {
        for template in ["planet-letter", "orbit-theatre"] {
            let app = launch(extra: ["--parity-case", "card--" + template], login: false)
            XCTAssertTrue(app.buttons["save-card"].isHittable)
            XCTAssertTrue(app.buttons["card-home"].isHittable)
            let identifier = "parity-scroll-collection-card"
            var viewport = parityViewport(identifier, in: app)
            for _ in 0..<12 {
                if viewport.offset >= viewport.maxOffset - 1 { break }
                parityDrag(viewport.frame, downward: false, in: app, edge: true)
                viewport = parityViewport(identifier, in: app)
            }
            let first = app.buttons["card-template-planet-letter"]
            let second = app.buttons["card-template-orbit-theatre"]
            XCTAssertTrue(first.isHittable); XCTAssertTrue(second.isHittable)
            XCTAssertEqual(first.frame.minY, second.frame.minY, accuracy: 1)
            XCTAssertEqual(first.frame.width, second.frame.width, accuracy: 1)
            XCTAssertEqual(first.frame.height, second.frame.height, accuracy: 1)
            let heading = parityProbe("card-templates-heading", in: app)
            XCTAssertTrue(heading.exists)
            XCTAssertGreaterThanOrEqual(first.frame.minY, heading.frame.maxY + 6)
            for value in ["planet-letter", "orbit-theatre"] {
                let button = app.buttons["card-template-" + value]
                let preview = parityProbe("card-template-preview-" + value, in: app)
                XCTAssertTrue(preview.exists)
                XCTAssertTrue(button.frame.insetBy(dx: -1, dy: -1).contains(preview.frame))
                XCTAssertEqual(preview.frame.width / preview.frame.height, 1.6, accuracy: 0.03)
            }
            capture("repaired-template-layout-" + template, in: app)
            app.terminate()
        }
        let app = launch(extra: ["--parity-case", "login--error"], login: false)
        assertParityState("login--error", in: app)
        capture("repaired-login-error", in: app)
    }

}
