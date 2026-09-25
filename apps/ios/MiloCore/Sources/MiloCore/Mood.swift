import Foundation

/// The current MILO selector's seven primary moods, in display order.
public enum Mood: String, Codable, CaseIterable, Identifiable, Sendable {
    case joyful
    case bright
    case okay
    case calm
    case heavy
    case low
    case veryLow = "very-low"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .joyful: "雀跃"
        case .bright: "明亮"
        case .okay: "还不错"
        case .calm: "平静"
        case .heavy: "有些沉"
        case .low: "低落"
        case .veryLow: "非常低落"
        }
    }

    public var valence: Int {
        switch self {
        case .joyful: 3
        case .bright: 2
        case .okay: 1
        case .calm: 0
        case .heavy: -1
        case .low: -2
        case .veryLow: -3
        }
    }
}
