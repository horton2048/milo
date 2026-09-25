import Foundation

public struct JournalEntry: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    /// Milliseconds since the Unix epoch, matching the existing MILO contract.
    public let createdAt: Double
    public let mood: Mood
    public let note: String
    public var kind: String { "now" }
    public var diaryEnabled: Bool { false }

    public init(
        id: String = UUID().uuidString,
        createdAt: Double = Date().timeIntervalSince1970 * 1_000,
        mood: Mood,
        note: String
    ) {
        self.id = UUID(uuidString: id)?.uuidString ?? id
        self.createdAt = createdAt
        self.mood = mood
        self.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var preview: String { note.isEmpty ? "（一次安静的记录）" : note }

    private enum CodingKeys: String, CodingKey {
        case id, createdAt, kind, mood, note, diaryEnabled
    }

    private struct StoredMood: Codable {
        let valence: Int
        let labels: [String]
        let emotionId: Mood
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try values.decode(String.self, forKey: .kind)
        let diaryEnabled = try values.decode(Bool.self, forKey: .diaryEnabled)
        let storedMood = try values.decode(StoredMood.self, forKey: .mood)
        guard kind == "now", !diaryEnabled else {
            throw JournalError.invalidEntry("unsupported record kind")
        }
        // This milestone has no label editor or foreign-client import. Reject
        // unsupported labels instead of silently dropping them on the next save.
        guard storedMood.valence == storedMood.emotionId.valence, storedMood.labels.isEmpty else {
            throw JournalError.invalidEntry("inconsistent or unsupported mood")
        }
        self.init(
            id: try values.decode(String.self, forKey: .id),
            createdAt: try values.decode(Double.self, forKey: .createdAt),
            mood: storedMood.emotionId,
            note: try values.decode(String.self, forKey: .note)
        )
        try validate()
    }

    public func encode(to encoder: any Encoder) throws {
        try validate()
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id)
        try values.encode(createdAt, forKey: .createdAt)
        try values.encode(kind, forKey: .kind)
        try values.encode(StoredMood(valence: mood.valence, labels: [], emotionId: mood), forKey: .mood)
        try values.encode(note, forKey: .note)
        try values.encode(diaryEnabled, forKey: .diaryEnabled)
    }

    func validate() throws {
        guard let uuid = UUID(uuidString: id), uuid.uuidString == id else {
            throw JournalError.invalidEntry("invalid UUID")
        }
        // Bounds are explicit: 1970-01-01 through the final millisecond of
        // year 9999. No wall-clock comparison, so clock changes are harmless.
        guard createdAt.isFinite, (0...253_402_300_799_999).contains(createdAt) else {
            throw JournalError.invalidEntry("invalid creation time")
        }
    }
}
