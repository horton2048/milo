import XCTest

struct ParityMeasuredViewport {
    let raw: [String: Double]
    let frame: CGRect
    let contentHeight: Double
    let offset: Double
    var maxOffset: Double { max(0, contentHeight - frame.height) }
}

@MainActor func parityProbe(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
    app.descendants(matching: .any).matching(identifier: identifier).firstMatch
}

@MainActor func parityValues(_ identifier: String, in app: XCUIApplication) -> [String: Double] {
    let probe = parityProbe(identifier, in: app)
    XCTAssertTrue(probe.exists || probe.waitForExistence(timeout: 5), "Missing live geometry: \(identifier)")
    for _ in 0..<25 {
        if let value = probe.value as? String, let data = value.data(using: .utf8),
           let values = try? JSONDecoder().decode([String: Double].self, from: data), !values.isEmpty {
            return values
        }
        Thread.sleep(forTimeInterval: 0.1)
    }
    XCTFail("No actual geometry was published by \(identifier): \(probe.value ?? "nil")")
    return [:]
}

private func measuredRect(_ values: [String: Double]) -> CGRect {
    CGRect(x: values["frameX"] ?? 0, y: values["frameY"] ?? 0,
           width: values["frameWidth"] ?? 0, height: values["frameHeight"] ?? 0)
}

@MainActor func parityViewport(_ identifier: String, in app: XCUIApplication) -> ParityMeasuredViewport {
    let raw = parityValues(identifier, in: app)
    let full = measuredRect(raw)
    let topInset = max(0, raw["insetTop"] ?? 0)
    let bottomInset = max(0, raw["insetBottom"] ?? 0)
    // SwiftUI's container/frame already excludes its contentInsets; its
    // visibleRect reports the larger underlying scroll bounds. UIKit bounds
    // are different and still need adjustedContentInset removed.
    let isTextView = raw["isUIKitTextView"] == 1
    var frame = isTextView
        ? CGRect(x: full.minX, y: full.minY + topInset,
                 width: full.width, height: max(0, full.height - topInset - bottomInset))
        : full
    frame = frame.intersection(measuredRect(parityValues("parity-viewport", in: app)))
    if identifier == "parity-scroll-note-editor" {
        let outer = parityValues("parity-scroll-journey-now-note", in: app)
        frame = frame.intersection(measuredRect(outer))
    }
    let keyboard = app.keyboards.firstMatch
    if keyboard.exists, keyboard.frame.minY > frame.minY {
        frame.size.height = min(frame.height, keyboard.frame.minY - frame.minY)
    }
    // Fixed actions can have frames inside a ScrollView's large AX bounds.
    // Public scroll insets usually already exclude them; use the actual control
    // as an additional upper bound rather than trusting AX scroll bounds.
    for id in ["save-now", "save-past", "save-card", "card-home", "open-card"] {
        let button = app.buttons[id]
        if button.exists, button.isHittable, button.frame.minY > frame.minY,
           button.frame.minY < frame.maxY {
            frame.size.height = button.frame.minY - frame.minY
        }
    }
    XCTAssertFalse(frame.isNull, identifier)
    XCTAssertGreaterThan(frame.height, 30, "No usable scroll viewport: \(identifier)")
    XCTAssertLessThanOrEqual(raw["contentWidth"] ?? 0, (raw["containerWidth"] ?? full.width) + 1,
                             "Horizontal content escapes the viewport: \(identifier)")
    XCTAssertLessThanOrEqual(raw["contentWidth"] ?? 0, frame.width + 1,
                             "Content is clipped by the safe horizontal viewport: \(identifier)")
    let externalTopClip = frame.minY - full.minY - (isTextView ? topInset : 0)
    let offset = (raw["offsetY"] ?? 0) + topInset + externalTopClip
    return ParityMeasuredViewport(raw: raw, frame: frame,
                                  contentHeight: raw["contentHeight"] ?? 0, offset: max(0, offset))
}

@MainActor func parityDrag(_ frame: CGRect, downward: Bool, in app: XCUIApplication, edge: Bool, distance: Double? = nil) {
    let x = edge ? frame.minX + min(12, frame.width * 0.04) : frame.midX
    let startY = downward ? frame.minY + frame.height * 0.15 : frame.maxY - frame.height * 0.15
    let movement = min(frame.height * 0.7, max(12, distance ?? frame.height * 0.7))
    let endY = startY + (downward ? movement : -movement)
    let start = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x, dy: startY))
    let end = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x, dy: endY))
    start.press(forDuration: 0.08, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.2)
    Thread.sleep(forTimeInterval: 0.25)
}

@MainActor func parityAlignEditor(in app: XCUIApplication) {
    for _ in 0..<10 {
        let outer = parityViewport("parity-scroll-journey-now-note", in: app)
        let inner = measuredRect(parityValues("parity-scroll-note-editor", in: app))
        if outer.frame.insetBy(dx: -1, dy: -1).contains(inner) { return }
        let delta = inner.minY < outer.frame.minY
            ? outer.frame.minY - inner.minY + 2
            : outer.frame.maxY - inner.maxY - 2
        let move = max(-outer.frame.height * 0.65, min(outer.frame.height * 0.65, delta))
        let startY = move > 0 ? outer.frame.minY + 10 : outer.frame.maxY - 10
        let start = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: outer.frame.minX + 12, dy: startY))
        let end = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: outer.frame.minX + 12, dy: startY + move))
        start.press(forDuration: 0.08, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.2)
        Thread.sleep(forTimeInterval: 0.25)
    }
    XCTFail("The complete editor could not be aligned inside the measured outer viewport")
}
