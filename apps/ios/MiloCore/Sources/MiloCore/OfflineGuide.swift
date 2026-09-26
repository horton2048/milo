import Foundation

public enum OfflineGuide {
    public static let timePresets = ["昨天", "上个星期", "几个月前", "去年这个时候", "去年夏天", "几年前", "大学时光", "刚工作那会儿", "少年时代", "小时候"]
    private static let steps = ["那一刻，你是什么感受？", "哪件小事让你记得最清楚？", "现在想起它，心里有什么变化？", "还有什么想说的？", "嗯，我在听。"]

    public static func opening(mood: Mood = .calm, timeMark: String) -> String {
        timeMark.count > 18 ? "那段时光里，你最先想起什么？" : "「\(timeMark)」，你最先想起什么？"
    }

    /// Call after appending the user's latest message. Restored transcripts
    /// determine progression, so no hidden step counter can lose its place.
    public static func respond(transcript: [TranscriptMessage]) -> String {
        let users = transcript.filter { $0.role == .user }
        guard let last = users.last else { return steps[0] }
        if wantsToPause(last.text) { return "好，先停在这里。" }
        if matches(last.text, pattern: "^(我)?(也|现在|有点)?(不知道|不知道怎么说|说不上来|想不起来|没什么|没啥)(了|吧)?$") {
            return "没关系，慢慢来。"
        }
        // A past pause advances to the final quiet prompt, like HarmonyOS.
        if users.dropLast().contains(where: { wantsToPause($0.text) }) { return steps.last! }
        return steps[min(max(0, users.count - 1), steps.count - 1)]
    }

    public static func wantsToPause(_ text: String) -> Bool {
        matches(text, pattern: "^(我)?(现在|今天|暂时|真的)?(不想说|不想聊|不说了|不聊了|先不说|先不聊|说不下去|聊不下去|先这样|就这样|到这里|算了|没了|没有了)(了|吧)?$")
    }

    public static func diary(transcript: [TranscriptMessage]) -> String {
        let lines = transcript.filter { $0.role == .user }.map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        return lines.isEmpty ? "今天的心情，先记在这里。" : lines.joined(separator: "\n\n")
    }

    public static func transcriptText(_ transcript: [TranscriptMessage]) -> String {
        transcript.map { "\($0.role == .user ? "我" : "回响")：\($0.text)" }.joined(separator: "\n")
    }

    private static func matches(_ text: String, pattern: String) -> Bool {
        let ignored = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "，,。.!！?？"))
        let compact = String(String.UnicodeScalarView(text.unicodeScalars.filter { !ignored.contains($0) }))
        return compact.range(of: pattern, options: .regularExpression) != nil
    }
}
