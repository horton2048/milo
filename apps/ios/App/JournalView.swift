import SwiftUI
import MiloCore

struct JournalView: View {
    @Bindable var model: JournalModel
    @State private var showHistory = false
    @FocusState private var writing: Bool
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("MILO").font(.caption.weight(.semibold)).tracking(6).foregroundStyle(.secondary)
                        Text("此刻，你还好吗？").font(.largeTitle.bold())
                        Text("不必整理好心情，也可以来这里。").foregroundStyle(.secondary)
                    }
                    .padding(.top, 12)

                    MoodPlanet(mood: model.mood)
                        .frame(maxWidth: .infinity)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("当前心情：\(model.mood.title)")

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 10)], spacing: 10) {
                        ForEach(Mood.allCases) { mood in
                            Button {
                                model.mood = mood
                            } label: {
                                Text(mood.title).font(.subheadline.weight(.medium))
                                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                                    .foregroundStyle(model.mood == mood ? Color.white : primaryInk)
                                    .background(model.mood == mood ? Color.purple.opacity(0.8) : cardFill, in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("mood-\(mood.rawValue)")
                            .accessibilityAddTraits(model.mood == mood ? .isSelected : [])
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("记下此刻").font(.headline)
                            Spacer()
                            Text("写一句，或留空").font(.caption).foregroundStyle(.secondary)
                        }
                        TextEditor(text: $model.note)
                            .frame(minHeight: 150)
                            .scrollContentBackground(.hidden)
                            .padding(12)
                            .background(cardFill, in: RoundedRectangle(cornerRadius: 22))
                            .focused($writing)
                            .accessibilityLabel("此刻的记录")
                            .accessibilityIdentifier("note-input")
                    }

                    if let error = model.errorMessage {
                        VStack(alignment: .leading, spacing: 10) {
                            Label(error, systemImage: "exclamationmark.circle")
                                .foregroundStyle(.orange)
                                .accessibilityIdentifier("storage-error")
                            if !model.isLoaded {
                                Button("重新读取") { model.reload() }
                                    .accessibilityIdentifier("retry-load")
                            }
                        }
                    }
                    Label("记录只保存在这台设备上", systemImage: "lock")
                        .font(.caption).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 24).padding(.bottom, 20)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(CosmicBackground())
            .safeAreaInset(edge: .bottom) {
                Button {
                    if model.save() { writing = false; showHistory = true }
                } label: {
                    Label("收藏这一刻", systemImage: "sparkle")
                        .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 17)
                }
                .buttonStyle(.borderedProminent).tint(.purple)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .disabled(!model.isLoaded || model.isSaving)
                .accessibilityIdentifier("save-entry")
                .padding(.horizontal, 24).padding(.vertical, 10)
                .background(.ultraThinMaterial)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { writing = false; showHistory = true } label: {
                        Label("回忆长廊", systemImage: "clock.arrow.circlepath")
                    }
                    .accessibilityIdentifier("open-history")
                }
                #if os(iOS)
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") { writing = false }
                }
                #endif
            }
            .navigationDestination(isPresented: $showHistory) {
                HistoryView(model: model)
            }
        }
        .tint(.purple)
    }

    private var primaryInk: Color { scheme == .dark ? Color(red: 0.92, green: 0.9, blue: 1) : .primary }
    private var cardFill: Color { scheme == .dark ? .white.opacity(0.07) : .purple.opacity(0.06) }
}

private struct HistoryView: View {
    var model: JournalModel

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                if !model.isLoaded {
                    ContentUnavailableView("暂时无法读取回忆", systemImage: "exclamationmark.circle", description: Text("原来的记录仍被保留，请返回后重试。"))
                } else if model.entries.isEmpty {
                    ContentUnavailableView("这里还很安静", systemImage: "moon.stars", description: Text("你收藏的每一刻，会在这里相遇。"))
                        .accessibilityIdentifier("empty-history")
                }
                ForEach(model.entries) { entry in
                    NavigationLink {
                        EntryDetailView(entry: entry)
                    } label: {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Circle().fill(entry.mood.color).frame(width: 9, height: 9)
                                Text(entry.mood.title).font(.subheadline.weight(.semibold))
                                Spacer()
                                Text(entry.date, style: .date).font(.caption).foregroundStyle(.secondary)
                            }
                            Text(entry.note.isEmpty ? "（一次安静的记录）" : entry.note)
                                .font(.body).lineLimit(3).multilineTextAlignment(.leading)
                            Text("此刻 · 查看记录  →").font(.caption).foregroundStyle(.secondary)
                        }
                        .foregroundStyle(.primary)
                        .padding(20).frame(maxWidth: .infinity, alignment: .leading)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("entry-\(entry.id)")
                }
            }.padding(24)
        }
        .background(CosmicBackground())
        .navigationTitle("回忆长廊")
    }
}

private struct EntryDetailView: View {
    let entry: JournalEntry
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                MoodPlanet(mood: entry.mood).frame(maxWidth: .infinity)
                Text(entry.date, format: .dateTime.year().month().day().hour().minute())
                    .font(.subheadline).foregroundStyle(.secondary)
                Text(entry.note.isEmpty ? "（一次安静的记录）" : entry.note)
                    .font(.title3).lineSpacing(8).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("entry-note")
                Label("这一刻，已经被好好收藏。", systemImage: "sparkle")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(24)
        }
        .background(CosmicBackground())
        .navigationTitle("一刻回忆")
    }
}

private struct MoodPlanet: View {
    let mood: Mood
    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().fill(mood.color.opacity(0.18)).frame(width: 160, height: 160).blur(radius: 15)
                Ellipse().stroke(mood.color.opacity(0.35), lineWidth: 1)
                    .frame(width: 188, height: 60).rotationEffect(.degrees(-24))
                Circle().fill(RadialGradient(colors: [.white.opacity(0.9), mood.color, mood.color.opacity(0.35), .black.opacity(0.9)], center: .topLeading, startRadius: 0, endRadius: 150))
                    .frame(width: 112, height: 112)
                    .overlay(Circle().stroke(.white.opacity(0.15), lineWidth: 1))
            }.frame(height: 170)
            Text(mood.title).font(.title2.weight(.medium))
        }
    }
}

private struct CosmicBackground: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        ZStack {
            LinearGradient(colors: scheme == .dark ? [Color(red: 0.025, green: 0.025, blue: 0.065), Color(red: 0.07, green: 0.05, blue: 0.16)] : [Color(red: 0.98, green: 0.97, blue: 1), Color(red: 0.94, green: 0.93, blue: 0.99)], startPoint: .top, endPoint: .bottom)
            Canvas { context, size in
                for index in 0..<65 {
                    let x = Double((index * 79 + 13) % 997) / 997 * size.width
                    let y = Double((index * 151 + 43) % 991) / 991 * size.height
                    let radius = index % 7 == 0 ? 2.0 : 1.0
                    context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: radius, height: radius)), with: .color(.purple.opacity(scheme == .dark ? 0.4 : 0.13)))
                }
            }
        }.ignoresSafeArea().accessibilityHidden(true)
    }
}

private extension JournalEntry {
    var date: Date { Date(timeIntervalSince1970: createdAt / 1_000) }
}

private extension Mood {
    var color: Color {
        switch self {
        case .joyful: Color(red: 1, green: 0.68, blue: 0.3)
        case .bright: Color(red: 1, green: 0.62, blue: 0.7)
        case .okay: Color(red: 0.64, green: 0.8, blue: 0.76)
        case .calm: Color(red: 0.65, green: 0.61, blue: 0.9)
        case .heavy: Color(red: 0.48, green: 0.58, blue: 0.77)
        case .low: Color(red: 0.47, green: 0.48, blue: 0.7)
        case .veryLow: Color(red: 0.38, green: 0.39, blue: 0.52)
        }
    }
}
