import SwiftUI
import MiloCore

struct ClassifyView: View {
    let model: JournalModel
    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                MiloPageHeader(title: "这份感受，来自哪里？", subtitle: "此刻，还是过去？", back: model.back)
                VStack(spacing: 18) {
                    choice("它属于此刻", subtitle: "记下现在的心情", past: false) { model.chooseKind("now") }
                    choice("它来自过去", subtitle: "聊聊想起的那段时光", past: true) { model.chooseKind("past") }
                }.padding(.top, 8)
            }.padding(.horizontal, 24).padding(.bottom, 28)
        }.parityScrollMetrics("journey-classify")
    }
    private func choice(_ title: String, subtitle: String, past: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 10) {
                    Text(title).font(MiloTheme.serif(21)).foregroundStyle(past ? MiloTheme.dim : .white)
                    Text(subtitle).font(.subheadline).foregroundStyle(MiloTheme.dim)
                }
                Spacer(minLength: 8)
                Image(systemName: past ? "sparkles" : "sun.horizon").font(.title3.weight(.ultraLight)).foregroundStyle(MiloTheme.dim.opacity(0.55))
            }.padding(24).frame(maxWidth: .infinity, minHeight: 114, alignment: .leading)
                .background(past ? MiloTheme.accent.opacity(0.09) : .white.opacity(0.05), in: RoundedRectangle(cornerRadius: 28))
                .overlay(RoundedRectangle(cornerRadius: 28).stroke(past ? MiloTheme.accent.opacity(0.40) : .white.opacity(0.09), lineWidth: 0.8))
        }.buttonStyle(MiloPressStyle()).accessibilityIdentifier(past ? "choose-past" : "choose-now")
    }
}

struct NowNoteView: View {
    @Bindable var model: JournalModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var preferredEditorHeight: CGFloat = 120
    @FocusState private var editing: Bool
    private let editorBottom = "note-editor-bottom"
    var body: some View {
        // The inset reduces this proposal before the editor height is calculated,
        // so the native editor fits above both the keyboard and the save bar.
        GeometryReader { viewport in
            ScrollViewReader { reader in
                ScrollView {
                    VStack(spacing: 24) {
                        MiloPageHeader(title: "记下此刻", subtitle: "想写多少都可以", back: model.back)
                        MoodPlanet(mood: model.draft.mood, size: 120)
                        noteEditor(height: editorHeight(in: viewport.size.height))
                            .id(editorBottom)
                        Text(model.draft.labels.joined(separator: " · ")).font(.caption).foregroundStyle(MiloTheme.hint)
                    }.padding(.horizontal, 28).padding(.bottom, 24)
                }.parityScrollMetrics("journey-now-note")
                    .scrollDismissesKeyboard(.never)
                    .onChange(of: editing) { _, focused in
                        if focused { revealEditor(using: reader) }
                    }
                    .onChange(of: viewport.size) { _, _ in
                        if editing { revealEditor(using: reader) }
                    }
                    .onChange(of: dynamicTypeSize) { _, _ in
                        if editing { revealEditor(using: reader) }
                    }
            }
        }.safeAreaInset(edge: .bottom) {
            MiloPrimaryButton(title: "收藏这一刻") { editing = false; model.save() }
                .disabled(!model.isLoaded || model.isSaving).accessibilityIdentifier("save-now")
                .padding(.horizontal, 24).padding(.vertical, 14).background(MiloTheme.background)
        }.toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完成编辑") { editing = false }.accessibilityIdentifier("note-editor-done")
            }
        }
    }
    private func noteEditor(height: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $model.draft.note)
                .font(.body).foregroundStyle(MiloTheme.ink)
                .scrollContentBackground(.hidden).scrollDismissesKeyboard(.never)
                .focused($editing)
                .accessibilityLabel("此刻的感受（选填）").accessibilityIdentifier("note-input")
                .parityTextMetrics("note-editor")
            if model.draft.note.isEmpty {
                Text("此刻的感受…（选填）").font(.body).foregroundStyle(MiloTheme.hint)
                    .padding(.horizontal, 5).padding(.top, 8)
                    .allowsHitTesting(false).accessibilityHidden(true)
            }
        }.frame(height: height).miloPanel(padding: 18)
    }
    private func editorHeight(in availableHeight: CGFloat) -> CGFloat {
        // Reserve the panel's 36 points of padding and a small visible margin.
        let capacity = max(1, availableHeight - 48)
        return editing ? capacity : min(preferredEditorHeight, capacity)
    }
    private func revealEditor(using reader: ScrollViewProxy) {
        // Wait for focus/keyboard layout, never move the outer page on each key.
        Task { @MainActor in
            await Task.yield()
            guard editing else { return }
            reader.scrollTo(editorBottom, anchor: .bottom)
        }
    }
}

struct PastTimeView: View {
    @Bindable var model: JournalModel
    @State private var picked = ""
    @State private var custom = ""
    private let presets = ["昨天", "上个星期", "几个月前", "去年这个时候", "去年夏天", "几年前", "大学时光", "刚工作那会儿", "少年时代", "小时候"]
    private var mark: String { custom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? picked : custom.trimmingCharacters(in: .whitespacesAndNewlines) }
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                MiloPageHeader(title: "那是什么时候的事？", subtitle: "大概的时间就好", back: model.back)
                FlowLayout(spacing: 10) {
                    ForEach(presets, id: \.self) { preset in
                        Button { picked = preset; custom = "" } label: {
                            Text(preset).font(.subheadline).foregroundStyle(MiloTheme.dim)
                                .padding(.horizontal, 18).padding(.vertical, 12)
                                .background(MiloTheme.accent.opacity(mark == preset ? 0.22 : 0.04), in: Capsule())
                                .overlay(Capsule().stroke(mark == preset ? MiloTheme.accent.opacity(0.8) : .white.opacity(0.1), lineWidth: 0.8))
                        }.buttonStyle(.plain).accessibilityIdentifier("time-\(preset)")
                            .accessibilityAddTraits(mark == preset ? [.isSelected] : [])
                    }
                }
                TextField("比如，高三的雨季", text: $custom).font(.body).foregroundStyle(MiloTheme.ink)
                    .padding(18).background(.white.opacity(0.05), in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.1), lineWidth: 0.7)).accessibilityIdentifier("custom-time")
            }.padding(.horizontal, 28).padding(.bottom, 24)
        }.parityScrollMetrics("journey-past-time")
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) {
                MiloPrimaryButton(title: "回到那时") { model.startConversation(time: mark) }
                    .disabled(mark.isEmpty).accessibilityIdentifier("start-chat")
                    .padding(.horizontal, 24).padding(.vertical, 14).background(MiloTheme.background.opacity(0.93))
            }.onAppear {
                if let time = model.draft.timeMark { if presets.contains(time) { picked = time } else { custom = time } }
            }.onChange(of: mark) { _, value in model.setPendingTime(value) }
    }
}

struct ChatView: View {
    @Bindable var model: JournalModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var speech = SpeechInputModel()
    @State private var speechPrefix = ""
    private var aiBinding: Binding<Bool> { Binding(get: { model.draft.aiEnabled }, set: { model.setAIEnabled($0) }) }
    @FocusState private var editing: Bool
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                MiloBackButton(action: model.back)
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.draft.timeMark ?? "那段时光").font(.caption).foregroundStyle(MiloTheme.hint)
                    Text(model.draft.aiEnabled ? "回响" : "引导").font(MiloTheme.serif(24)).foregroundStyle(MiloTheme.ink)
                }
                Spacer(minLength: 8)
                Toggle("AI", isOn: aiBinding).font(.caption).fixedSize().accessibilityIdentifier("chat-ai-toggle")
            }.padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 10)
            if !model.guidanceNotice.isEmpty {
                guidanceNotice
            }
            ScrollViewReader { reader in
                ScrollView {
                    LazyVStack(spacing: 18) {
                        ForEach(Array(model.draft.transcript.enumerated()), id: \.offset) { index, message in
                            HStack(alignment: .top, spacing: 14) {
                                if message.role == .user { Spacer(minLength: 40) }
                                VStack(alignment: .leading, spacing: 7) {
                                    if message.role == .ai { Text("MILO").font(.system(size: 10)).tracking(2).foregroundStyle(MiloTheme.hint) }
                                    Text(message.text).font(.body).lineSpacing(7).foregroundStyle(MiloTheme.ink)
                                        .padding(18).background(message.role == .user ? MiloTheme.accent.opacity(0.15) : .white.opacity(0.045), in: RoundedRectangle(cornerRadius: 23))
                                        .overlay(RoundedRectangle(cornerRadius: 23).stroke(.white.opacity(0.075), lineWidth: 0.7))
                                }
                                if message.role == .ai { Spacer(minLength: 35) }
                            }.id(index).accessibilityIdentifier("message-\(index)")
                        }
                        if model.isThinking { HStack { ProgressView().tint(MiloTheme.dim); Text("回响正在靠近…").font(.caption).foregroundStyle(MiloTheme.hint); Spacer() } }
                        Color.clear.frame(height: 1).id("bottom")
                    }.padding(.horizontal, 24).padding(.vertical, 20)
                }.parityScrollMetrics("journey-chat")
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: model.draft.transcript.count) { _, _ in withAnimation { reader.scrollTo("bottom", anchor: .bottom) } }
            }
            composer
        }.onDisappear { speech.stop() }
            .onChange(of: speech.transcript) { _, text in
                guard !text.isEmpty else { return }
                model.draft.inputText = speechPrefix + (speechPrefix.isEmpty ? "" : "\n") + text
            }
    }
    private var guidanceNotice: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    Text(model.guidanceNotice).font(.caption).foregroundStyle(MiloTheme.dim)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("AI 设置", action: model.openSettings).font(.caption)
                        .frame(minHeight: 44)
                }.frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack {
                    Text(model.guidanceNotice).font(.caption).foregroundStyle(MiloTheme.dim)
                    Spacer(minLength: 4)
                    Button("AI 设置", action: model.openSettings).font(.caption)
                }
            }
        }.padding(.horizontal, 24).padding(.vertical, 8)
    }
    private var composer: some View {
        VStack(spacing: 10) {
            if let error = speech.errorMessage { Text(error).font(.caption).foregroundStyle(MiloTheme.dim).frame(maxWidth: .infinity, alignment: .leading) }
            HStack(alignment: .bottom, spacing: 8) {
                TextField("说说那一刻…", text: $model.draft.inputText, axis: .vertical)
                    .lineLimit(1...6).font(.body).foregroundStyle(MiloTheme.ink).focused($editing)
                    .disabled(speech.isRecording)
                    .padding(14).background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 22)).accessibilityIdentifier("chat-input")
                Button {
                    if speech.isRecording { speech.stop() }
                    else { editing = false; speechPrefix = model.draft.inputText; Task { await speech.start() } }
                } label: {
                    Image(systemName: speech.isRecording ? "stop.circle.fill" : "mic").font(.title3).frame(width: 44, height: 48)
                }.accessibilityLabel(speech.isRecording ? "停止录音" : "语音输入").disabled(model.isThinking)
                Button { speech.stop(); model.send() } label: {
                    Image(systemName: "arrow.up").font(.body.weight(.medium)).foregroundStyle(.white).frame(width: 44, height: 44)
                        .background(MiloTheme.accent.opacity(0.75), in: Circle())
                }.disabled(model.isThinking || model.draft.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || speech.isRecording)
                    .accessibilityLabel("发送").accessibilityIdentifier("send-message")
            }
            if model.canFinishConversation && !speech.isRecording {
                MiloPrimaryButton(title: "保存这段回忆") { editing = false; model.prepareDiary() }.accessibilityIdentifier("finish-chat")
            }
        }.padding(.horizontal, 20).padding(.vertical, 12).background(MiloTheme.background.opacity(0.97))
    }
}

struct DiaryView: View {
    @Bindable var model: JournalModel
    @State private var editing = false
    @FocusState private var editorFocused: Bool
    private var diaryText: Binding<String> { Binding(get: { model.draft.diary ?? "" }, set: { model.editDiary($0) }) }
    private var diaryEnabled: Binding<Bool> { Binding(get: { model.draft.diaryEnabled }, set: { model.setDiaryEnabled($0) }) }
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                MiloPageHeader(title: "显影这段回忆", subtitle: "读一读，也可以改一改", back: model.back)
                if !model.guidanceNotice.isEmpty { Text(model.guidanceNotice).font(.caption).foregroundStyle(MiloTheme.dim).frame(maxWidth: .infinity, alignment: .leading).padding(12).background(MiloTheme.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 12)) }
                Toggle(isOn: diaryEnabled) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("沉淀为日记").font(.body).foregroundStyle(MiloTheme.ink)
                        Text("关闭后只保留对话").font(.caption).foregroundStyle(MiloTheme.hint)
                    }
                }.miloPanel().accessibilityIdentifier("diary-toggle")
                if model.draft.diaryEnabled {
                    if model.isThinking {
                        HStack(spacing: 12) {
                            ProgressView().tint(MiloTheme.dim)
                            Text("回忆正在慢慢显影…").font(.subheadline).foregroundStyle(MiloTheme.dim)
                        }.frame(maxWidth: .infinity, minHeight: 150).miloPanel(padding: 24).accessibilityIdentifier("diary-generating")
                    } else { Group {
                        if editing {
                            TextField("写下这段回忆", text: diaryText, axis: .vertical).lineLimit(10...30)
                                .focused($editorFocused).accessibilityIdentifier("diary-editor")
                        } else { Text(model.draft.diary ?? "").frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled).accessibilityIdentifier("diary-content") }
                    }.font(MiloTheme.serif(17, relativeTo: .body)).foregroundStyle(MiloTheme.ink).lineSpacing(14).miloPanel(padding: 24) }
                    Button(editing ? "完成编辑" : "编辑日记") { editing.toggle(); editorFocused = editing }.font(.body).foregroundStyle(MiloTheme.dim).frame(minHeight: 44)
                        .disabled(model.isThinking).accessibilityIdentifier("edit-diary")
                }
            }.padding(.horizontal, 24).padding(.bottom, 28)
        }.parityScrollMetrics("journey-diary")
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) {
                MiloPrimaryButton(title: "收进回忆") { editorFocused = false; editing = false; model.save() }
                    .disabled(!model.isLoaded || model.isSaving || model.isThinking).accessibilityIdentifier("save-past")
                    .padding(.horizontal, 24).padding(.vertical, 14).background(MiloTheme.background)
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成编辑") { editorFocused = false; editing = false }
                }
            }
            .onAppear {
                model.ensureDiary()
                #if DEBUG
                if model.account.fixtureState == "editing" { editing = true }
                #endif
            }
            .onChange(of: model.isThinking) { _, thinking in if thinking { editing = false; editorFocused = false } }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 10
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(width: proposal.width ?? 340, subviews: subviews).size
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(width: bounds.width, subviews: subviews)
        for (index, point) in result.points.enumerated() { subviews[index].place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y), proposal: .unspecified) }
    }
    private func arrange(width: CGFloat, subviews: Subviews) -> (size: CGSize, points: [CGPoint]) {
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        var points: [CGPoint] = []
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            points.append(CGPoint(x: x, y: y)); x += size.width + spacing; rowHeight = max(rowHeight, size.height)
        }
        return (CGSize(width: width, height: y + rowHeight), points)
    }
}
