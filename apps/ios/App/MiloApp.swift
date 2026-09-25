import SwiftUI
import MiloCore

@main
struct MiloApp: App {
    @State private var model = JournalModel(repository: AppStorage.makeRepository())

    var body: some Scene {
        WindowGroup {
            JournalView(model: model)
        }
    }
}

enum AppStorage {
    static func makeRepository() -> any JournalRepository {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        var url = support.appendingPathComponent("MILO", isDirectory: true).appendingPathComponent("journal.json")
        #if DEBUG
        // Only test fixtures are configurable. No launch argument can reset personal data.
        if let index = ProcessInfo.processInfo.arguments.firstIndex(of: "--uitest-id"),
           ProcessInfo.processInfo.arguments.indices.contains(index + 1),
           let id = UUID(uuidString: ProcessInfo.processInfo.arguments[index + 1]) {
            url = support.appendingPathComponent("MILO-UITests", isDirectory: true)
                .appendingPathComponent(id.uuidString).appendingPathComponent("journal.json")
            let repository = JSONJournalRepository(fileURL: url)
            if ProcessInfo.processInfo.arguments.contains("--uitest-corrupt") {
                try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try? Data("broken journal fixture".utf8).write(to: url)
            }
            if ProcessInfo.processInfo.arguments.contains("--uitest-write-failure") {
                return WriteFailingRepository(base: repository)
            }
            return repository
        }
        #endif
        return JSONJournalRepository(fileURL: url)
    }
}

#if DEBUG
private struct WriteFailingRepository: JournalRepository {
    let base: any JournalRepository
    func load() throws -> [JournalEntry] { try base.load() }
    func save(_ entry: JournalEntry) throws -> [JournalEntry] {
        throw CocoaError(.fileWriteNoPermission)
    }
}
#endif
