import Foundation
import Observation
import MiloCore

@MainActor
@Observable
final class JournalModel {
    var mood: Mood = .calm
    var note = ""
    private(set) var entries: [JournalEntry] = []
    private(set) var errorMessage: String?
    private(set) var isLoaded = false
    private(set) var isSaving = false
    private let repository: any JournalRepository

    init(repository: any JournalRepository) {
        self.repository = repository
        reload()
    }

    func reload() {
        do {
            let loaded = try repository.load()
            entries = loaded
            isLoaded = true
            errorMessage = nil
        } catch {
            isLoaded = false
            errorMessage = "暂时无法读取回忆。原来的记录仍被保留，请稍后重试。"
        }
    }

    @discardableResult
    func save() -> Bool {
        guard isLoaded, !isSaving else { return false }
        isSaving = true
        defer { isSaving = false }
        do {
            entries = try repository.save(JournalEntry(mood: mood, note: note))
            note = ""
            errorMessage = nil
            return true
        } catch {
            errorMessage = "这次没有保存成功。你写下的文字还在，可以再试一次。"
            return false
        }
    }
}
