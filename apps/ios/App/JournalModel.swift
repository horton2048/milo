import Foundation
import Observation
import MiloCore

@MainActor
@Observable
final class JournalModel {
    var draft = RecallDraft() {
        didSet {
            if draftReady, draftNeedsRecovery, draft != oldValue { editedDuringRecovery = true }
            persistDraft()
        }
    }
    private(set) var entries: [JournalEntry] = []
    var errorMessage: String?
    private(set) var isLoaded = false
    private(set) var isSaving = false
    var isThinking = false
    var guidanceNotice = ""
    var settingsReturnPage = "account"
    let account: AccountModel
    let temporaryExportDirectory: URL
    private(set) var recoveryBackupURL: URL?
    private let directory: URL
    private let repository: any JournalRepository
    private let draftRepository: JSONDraftRepository
    private var draftReady = false
    private var draftWritable = true
    private var draftNeedsRecovery = false
    private var editedDuringRecovery = false
    private var recoveredDraft: RecallDraft?
    private var conversationTask: Task<Void, Never>?
    private var generation = UUID()
    private enum GenerationKind { case opening, response, diary }
    private var generationKind: GenerationKind?
    private let aiCompletion: @MainActor ([AIMessage]) async throws -> String

    init(repository: any JournalRepository, directory: URL,
         aiCompletion: (@MainActor ([AIMessage]) async throws -> String)? = nil) {
        self.repository = repository
        self.directory = directory
        temporaryExportDirectory = Self.temporaryExportDirectory(for: directory)
        draftRepository = JSONDraftRepository(fileURL: directory.appendingPathComponent("draft.json"))
        let account = AccountModel(directory: directory)
        self.account = account
        self.aiCompletion = aiCompletion ?? { messages in try await account.completeAI(messages: messages) }
        reload()
        do { if let restored = try draftRepository.load() { draft = restored } }
        catch {
            draftWritable = false
            draftNeedsRecovery = true
            errorMessage = "未完成的回忆暂时无法读取，原文件已保留。请先导出已有记录，再重试。"
        }
        draftReady = true
    }
    var hasDraftRecoveryConflict: Bool { recoveredDraft != nil }
    static func temporaryExportDirectory(for directory: URL) -> URL {
        // Screenshot fixtures share the simulator container with the app. Their
        // exports and deletion checks must stay inside their own UUID store.
        let parts = directory.standardizedFileURL.pathComponents
        if let marker = parts.lastIndex(of: "MILO-UITests"), parts.indices.contains(marker + 1),
           UUID(uuidString: parts[marker + 1]) != nil {
            return directory.appendingPathComponent("TemporaryExports", isDirectory: true)
        }
        return FileManager.default.temporaryDirectory
    }
    var selectedEntry: JournalEntry? { entries.first { $0.id == draft.entryID } }
    var canFinishConversation: Bool {
        draft.transcript.contains { $0.role == .user } && draft.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isThinking
    }
    func reload() {
        do { entries = try repository.load(); isLoaded = true; errorMessage = nil }
        catch { isLoaded = false; errorMessage = "暂时无法读取回忆。原来的记录仍被保留，请稍后重试。" }
    }
    func go(_ page: String) {
        if draft.page == "chat" || draft.page == "diary" { cancelGeneration() }
        draft.page = page
    }
    func back() {
        cancelGeneration()
        if draft.page == "ai-settings" { draft.page = settingsReturnPage; return }
        draft.goBack()
    }
    func openSettings() { settingsReturnPage = draft.page; go("ai-settings") }
    func chooseKind(_ kind: String) { cancelGeneration(); draft.chooseKind(kind) }
    func openEntry(_ id: String) { draft.entryID = id; go("detail") }
    func startHome() { cancelGeneration(); draft = RecallDraft() }
    func returnHome() { go("home") }
    func beginMoodWords() {
        let mood = draft.mood
        cancelGeneration()
        var next = RecallDraft(mood: mood); next.page = "home-words"; draft = next
    }
    func setPendingTime(_ value: String) {
        if draft.timeMark != value.trimmingCharacters(in: .whitespacesAndNewlines) { cancelGeneration() }
        var next = draft
        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if next.timeMark != nil { next.transcript = []; next.diary = nil; next.inputText = "" }
            next.timeMark = nil
            next.pendingEntryID = nil
        } else { _ = next.selectTimeMark(value) }
        next.page = "past-time"; draft = next
    }
    func setAIEnabled(_ enabled: Bool) {
        draft.aiEnabled = enabled
        if !enabled {
            let pending = generationKind
            cancelGeneration()
            if pending == .opening, draft.page == "chat", draft.transcript.isEmpty {
                draft.transcript.append(TranscriptMessage(role: .ai, text: OfflineGuide.opening(mood: draft.mood, timeMark: draft.timeMark ?? "那段时光")))
            } else if pending == .response, draft.page == "chat", draft.transcript.last?.role == .user {
                draft.transcript.append(TranscriptMessage(role: .ai, text: OfflineGuide.respond(transcript: draft.transcript)))
            } else if pending == .diary, draft.page == "diary", draft.diaryEnabled, draft.diary == nil {
                draft.diary = OfflineGuide.diary(transcript: draft.transcript)
            }
            guidanceNotice = "正在使用本地引导"
        }
    }
    func retryStorage() {
        reload()
        do {
            let stored = try draftRepository.load()
            if draftNeedsRecovery {
                if editedDuringRecovery, let stored, stored != draft {
                    recoveredDraft = stored
                    errorMessage = "找到了之前的草稿。请选择继续当前内容，或恢复旧草稿；另一份会保留为备份。"
                    return
                }
                if editedDuringRecovery {
                    try draftRepository.save(draft)
                } else {
                    cancelGeneration()
                    replaceDraftWithoutWriting(stored ?? RecallDraft())
                }
                finishDraftRecovery()
            } else {
                // After a write failure the in-memory draft is newer than disk.
                // A readable file alone does not mean that those edits were saved.
                try draftRepository.save(draft)
            }
            draftWritable = true
        } catch { errorMessage = "草稿仍无法恢复或保存，原文件和当前输入均已保留，请稍后重试。" }
    }
    @discardableResult
    func resolveDraftRecovery(keepCurrent: Bool) -> Bool {
        guard let recoveredDraft else { return false }
        do {
            guard try draftRepository.load() == recoveredDraft else {
                self.recoveredDraft = nil
                errorMessage = "旧草稿已发生变化，请重试读取后再选择。"
                return false
            }
            let backupDirectory = directory.appendingPathComponent("RecoveredDrafts", isDirectory: true)
            try FileManager.default.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
            let backup = backupDirectory.appendingPathComponent("draft-\(UUID().uuidString).json")
            if keepCurrent {
                // Preserve the original envelope bytes, including formatting.
                let original = try Data(contentsOf: draftRepository.fileURL)
                try original.write(to: backup, options: .atomic)
                recoveryBackupURL = backup
                try draftRepository.save(draft)
            } else {
                try JSONDraftRepository(fileURL: backup).save(draft)
                recoveryBackupURL = backup
                try draftRepository.save(recoveredDraft)
                cancelGeneration()
                replaceDraftWithoutWriting(recoveredDraft)
            }
            finishDraftRecovery()
            errorMessage = isLoaded ? nil : "暂时无法读取回忆。原来的记录仍被保留，请稍后重试。"
            return true
        } catch {
            errorMessage = "草稿备份或恢复没有完成。两份内容仍被保留，请重试。"
            return false
        }
    }
    private func replaceDraftWithoutWriting(_ value: RecallDraft) {
        draftReady = false; draft = value; draftReady = true
    }
    private func finishDraftRecovery() {
        draftNeedsRecovery = false
        editedDuringRecovery = false
        recoveredDraft = nil
        draftWritable = true
    }
    func startConversation(time: String) {
        cancelGeneration()
        guard draft.selectTimeMark(time) else { return }
        guard draft.transcript.isEmpty else { return }
        let fallback = OfflineGuide.opening(mood: draft.mood, timeMark: draft.timeMark ?? "那段时光")
        guard draft.aiEnabled else {
            draft.transcript.append(TranscriptMessage(role: .ai, text: fallback))
            guidanceNotice = "正在使用本地引导"
            return
        }
        let messages = [AIMessage(role: .system, content: chatInstruction + "用一句温柔的中文问候开启回忆，问一个具体的小问题。"),
                        AIMessage(role: .user, content: "我想记录这份感受。")]
        requestConversationReply(messages: messages, fallback: fallback, kind: .opening)
    }
    func send() {
        let text = draft.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isThinking else { return }
        draft.transcript.append(TranscriptMessage(role: .user, text: text))
        draft.inputText = ""
        if !draft.aiEnabled || OfflineGuide.wantsToPause(text) {
            draft.transcript.append(TranscriptMessage(role: .ai, text: OfflineGuide.respond(transcript: draft.transcript)))
            guidanceNotice = "正在使用本地引导"
            return
        }
        let conversation = Array(draft.transcript.suffix(24))
        let messages = [AIMessage(role: .system, content: chatInstruction)]
            + conversation.map { AIMessage(role: $0.role == .user ? .user : .assistant, content: $0.text) }
        requestConversationReply(messages: messages, fallback: OfflineGuide.respond(transcript: draft.transcript), kind: .response)
    }
    private var chatInstruction: String {
        "你是MILO，温柔简短地陪用户回忆。一次只问一个问题，回答不超过48字。不要诊断、不虚构用户经历。用户情绪：\(draft.mood.title)\(draft.labels.joined(separator: "、"))，时间：\(draft.timeMark ?? "过去")。用户说先这样或暂停时尊重停止。"
    }
    private func requestConversationReply(messages: [AIMessage], fallback: String, kind: GenerationKind) {
        cancelGeneration()
        let current = generation
        let time = draft.timeMark
        let conversation = draft.transcript
        isThinking = true
        generationKind = kind
        guidanceNotice = "正在连接 AI…"
        conversationTask = Task { [weak self] in
            guard let self else { return }
            defer { finishGeneration(current) }
            let reply: String
            let notice: String
            do {
                reply = try await aiCompletion(messages)
                notice = ""
            } catch {
                reply = fallback
                notice = "AI 暂时不可用，已切换本地引导"
            }
            guard !Task.isCancelled, current == generation, draft.page == "chat", draft.aiEnabled,
                  draft.timeMark == time, draft.transcript == conversation else { return }
            guidanceNotice = notice
            draft.transcript.append(TranscriptMessage(role: .ai, text: Self.shortReply(reply)))
        }
    }
    func prepareDiary() {
        guard canFinishConversation else { return }
        go("diary")
        ensureDiary()
    }
    func setDiaryEnabled(_ enabled: Bool) {
        draft.diaryEnabled = enabled
        if enabled { ensureDiary() }
        else {
            cancelGeneration()
            guidanceNotice = "将保留这段对话，不生成日记。"
        }
    }
    func editDiary(_ text: String) {
        // Also protect edits made outside the disabled editor (for example, a
        // restored draft) from a provider that returns after cancellation.
        if generationKind == .diary { cancelGeneration() }
        draft.diary = text
    }
    func ensureDiary() {
        guard draft.page == "diary", draft.diaryEnabled, draft.diary == nil, !isThinking else { return }
        let conversation = draft.transcript
        let fallback = OfflineGuide.diary(transcript: conversation)
        guard draft.aiEnabled, conversation.count <= 32 else {
            draft.diary = fallback
            guidanceNotice = conversation.count > 32 ? "对话较长，已用你的原话整理，可以继续修改。" : "已用你的原话整理，可以继续修改。"
            return
        }
        cancelGeneration()
        let current = generation
        let time = draft.timeMark
        let initialDiary = draft.diary
        isThinking = true; generationKind = .diary
        guidanceNotice = "正在将你的话整理成日记…"
        let messages = [AIMessage(role: .system, content: "你是MILO的回忆记录助手。仅使用用户真实说过的事实，整理为第一人称中文日记，200至500字，材料不足时可以更短。不虚构人物、事件、感觉或细节，不诊断、不说教、不写标题，只输出日记正文。回忆时间：\(time ?? "过去")。")]
            + conversation.filter { $0.role == .user }.map { AIMessage(role: .user, content: $0.text) }
        conversationTask = Task { [weak self] in
            guard let self else { return }
            defer { finishGeneration(current) }
            let text: String
            let notice: String
            do {
                text = try await aiCompletion(messages)
                notice = "已整理成日记，请读一读，也可以改一改。"
            } catch {
                text = fallback
                notice = "AI 暂时不可用，已用你的原话整理，可以继续修改。"
            }
            guard !Task.isCancelled, current == generation, draft.page == "diary", draft.diaryEnabled,
                  draft.aiEnabled, draft.timeMark == time, draft.transcript == conversation,
                  draft.diary == initialDiary else { return }
            let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
            draft.diary = clean.isEmpty ? fallback : clean
            guidanceNotice = notice
        }
    }
    @discardableResult
    func save() -> Bool {
        guard draftWritable else {
            errorMessage = hasDraftRecoveryConflict
                ? "找到了之前的草稿。请选择继续当前内容，或恢复旧草稿；另一份会保留为备份。"
                : "之前的草稿尚未恢复，请先重试读取。原文件和当前输入均已保留。"
            return false
        }
        guard isLoaded, !isSaving, !isThinking else { return false }
        isSaving = true; defer { isSaving = false }
        var recordWritten = false
        do {
            var pending = draft
            if pending.pendingEntryID == nil { pending.pendingEntryID = UUID().uuidString }
            try draftRepository.save(pending)
            draftReady = false; draft = pending; draftReady = true
            let entry = try pending.makeEntry(id: pending.pendingEntryID!)
            entries = try repository.save(entry)
            recordWritten = true
            var next = RecallDraft(); next.page = "card"; next.entryID = entry.id
            try draftRepository.save(next)
            draftReady = false; draft = next; draftReady = true
            errorMessage = nil
            return true
        } catch {
            errorMessage = recordWritten
                ? "回忆已保存，但草稿状态暂时未能更新。请重试，不会重复收藏。"
                : "这次没有保存成功。你写下的文字还在，可以再试一次。"
            return false
        }
    }

    func setTemplate(_ template: CardTemplate) {
        guard var entry = selectedEntry else { return }
        entry.stickerTemplate = template
        do { entries = try repository.save(entry) }
        catch { errorMessage = "卡片样式没有保存成功，请重试。" }
    }
    func deleteSelected() {
        guard let id = draft.entryID else { return }
        do { entries = try repository.delete(id: id); draft.entryID = nil; go("timeline") }
        catch { errorMessage = "没有删除成功，原回忆仍然保留。" }
    }
    func clearLocalData() -> Bool {
        // Account flow calls this only after the explicit local-delete confirmation or verified remote deletion.
        do {
            // Never erase a readable store before discovering an unsupported or
            // damaged companion file. Cleanup errors are surfaced, not ignored.
            _ = try repository.load()
            _ = try draftRepository.load()
            cancelGeneration()
            try clearTemporaryExports()
            let backups = directory.appendingPathComponent("RecoveredDrafts", isDirectory: true)
            try removeIfPresent(backups)
            entries = try repository.deleteAll()
            try draftRepository.clear()
            replaceDraftWithoutWriting(RecallDraft())
            finishDraftRecovery()
            recoveryBackupURL = nil
            isLoaded = true; errorMessage = nil
            return true
        } catch { errorMessage = "有部分本地内容未能清除，请重试。"; return false }
    }
    private func clearTemporaryExports() throws {
        let manager = FileManager.default
        let children: [URL]
        do { children = try manager.contentsOfDirectory(at: temporaryExportDirectory, includingPropertiesForKeys: nil) }
        catch let error as CocoaError where error.code == .fileReadNoSuchFile { return }
        for child in children {
            let name = child.lastPathComponent
            let isRecordExport = name.hasPrefix("MILO-Export-") && UUID(uuidString: String(name.dropFirst("MILO-Export-".count))) != nil
            if name == "MiloCardShares" || isRecordExport { try manager.removeItem(at: child) }
        }
    }
    private func removeIfPresent(_ url: URL) throws {
        do { try FileManager.default.removeItem(at: url) }
        catch let error as CocoaError where error.code == .fileNoSuchFile || error.code == .fileReadNoSuchFile { return }
    }
    func logout() { cancelGeneration(); draft.page = "home" }
    func exportJSON() -> Data? {
        do { return try DiaryExport.json(entries: entries) }
        catch { errorMessage = "导出失败，请稍后重试。"; return nil }
    }
    func exportMarkdown() -> String? { DiaryExport.markdown(entries: entries) }
    private static func shortReply(_ text: String) -> String {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count > 48 else { return clean }
        let prefix = String(clean.prefix(48))
        if let end = prefix.lastIndex(where: { "。！？!?".contains($0) }) { return String(prefix[...end]) }
        return String(prefix.prefix(47)) + "。"
    }
    private func cancelGeneration() {
        if isThinking { guidanceNotice = "" }
        generation = UUID(); conversationTask?.cancel(); conversationTask = nil; generationKind = nil; isThinking = false
    }
    private func finishGeneration(_ current: UUID) {
        guard current == generation else { return }
        conversationTask = nil; generationKind = nil; isThinking = false
    }
    private func persistDraft() {
        guard draftReady, draftWritable else { return }
        do { try draftRepository.save(draft) }
        catch { errorMessage = "草稿暂时未能保存。请保持应用打开，重试后再离开。" }
    }
}
