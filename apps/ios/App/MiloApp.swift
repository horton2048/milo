import SwiftUI
import MiloCore

@main
struct MiloApp: App {
    @State private var model = JournalModel(repository: AppStorage.makeRepository())

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if let appearance = UITestConfiguration.appearance {
                UITestJournalRoot(model: model)
                    .preferredColorScheme(appearance)
            } else {
                JournalView(model: model)
            }
            #else
            JournalView(model: model)
            #endif
        }
    }
}

enum AppStorage {
    static func makeRepository() -> any JournalRepository {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        var url = support.appendingPathComponent("MILO", isDirectory: true).appendingPathComponent("journal.json")
        #if DEBUG
        // Only test fixtures are configurable. No launch argument can reset personal data.
        if let id = UITestConfiguration.id {
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
private enum UITestConfiguration {
    static var id: UUID? {
        argument("--uitest-id").flatMap(UUID.init(uuidString:))
    }

    static var appearance: ColorScheme? {
        // Appearance control, like storage injection, requires a valid fixture ID.
        guard id != nil else { return nil }
        switch argument("--uitest-appearance") {
        case "Light": return .light
        case "Dark": return .dark
        default: return nil
        }
    }

    private static func argument(_ name: String) -> String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: name), arguments.indices.contains(index + 1) else {
            return nil
        }
        return arguments[index + 1]
    }
}

private struct UITestJournalRoot: View {
    let model: JournalModel
    @Environment(\.colorScheme) private var resolvedAppearance

    var body: some View {
        JournalView(model: model)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("uitest-appearance-root")
            // Read the resolved environment, not the requested launch argument.
            .accessibilityValue(resolvedAppearance == .dark ? "Dark" : "Light")
    }
}

private struct WriteFailingRepository: JournalRepository {
    let base: any JournalRepository
    func load() throws -> [JournalEntry] { try base.load() }
    func save(_ entry: JournalEntry) throws -> [JournalEntry] {
        throw CocoaError(.fileWriteNoPermission)
    }
}
#endif
