import SwiftUI
import UIKit
import MiloCore

enum MiloTheme {
    static let background = Color(red: 5/255, green: 6/255, blue: 8/255)
    static let surface = Color(red: 15/255, green: 15/255, blue: 21/255)
    static let ink = Color.white
    static let dim = Color(red: 201/255, green: 190/255, blue: 252/255)
    static let hint = Color(red: 139/255, green: 135/255, blue: 166/255)
    static let accent = Color(red: 139/255, green: 124/255, blue: 246/255)
    static let rose = Color(red: 240/255, green: 166/255, blue: 202/255)
    static func serif(_ size: CGFloat, relativeTo style: Font.TextStyle = .title2) -> Font {
        .custom("SongtiSC-Regular", size: size, relativeTo: style)
    }
}

struct MiloBackground: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var burstPoint: CGPoint?
    @State private var burstStartedAt = Date.distantPast
    private var freezeMotion: Bool {
        #if DEBUG
        if ParityFixture.id != nil { return true }
        #endif
        return reduceMotion || scenePhase != .active
    }
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                MiloTheme.background
                Ellipse().fill(MiloTheme.accent.opacity(0.045))
                    .frame(width: geometry.size.width * 1.1, height: geometry.size.height * 0.56)
                    .blur(radius: 65).offset(x: -80, y: -100)
                SwiftUI.TimelineView(.animation(minimumInterval: 1.0 / 30, paused: freezeMotion)) { timeline in
                    let time = freezeMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                    let burstAge = timeline.date.timeIntervalSince(burstStartedAt)
                    let burst = freezeMotion ? 0 : burstAmount(at: burstAge)
                    Canvas { context, size in
                        let count = max(18, Int(size.width * size.height / 4200))
                        for index in 0..<count {
                            let phase = Double(index) * 1.731
                            let driftX = sin(time * 0.06 + phase) * 1.3
                            let driftY = cos(time * 0.05 + phase) * 1.7
                            var x = Double((index * 7919 + 137) % 10000) / 10000 * size.width + driftX
                            var y = Double((index * 3571 + 631) % 10000) / 10000 * size.height + driftY
                            let radius = index % 5 == 0 ? 0.8 : 0.45
                            var opacity = (index % 3 == 0 ? 0.33 : 0.16) + sin(time * 0.35 + phase) * 0.06
                            if let point = burstPoint, burst > 0 {
                                let dx = x - point.x, dy = y - point.y
                                let distance = hypot(dx, dy)
                                if distance > 0.001 && distance < 170 {
                                    let falloff = 1 - distance / 170
                                    let displacement = 36 * falloff * falloff * burst
                                    x += dx / distance * displacement
                                    y += dy / distance * displacement
                                    opacity *= 1 - 0.45 * falloff * burst
                                }
                            }
                            context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: radius * 2, height: radius * 2)), with: .color(MiloTheme.dim.opacity(opacity)))
                        }
                    }
                }
            }.contentShape(Rectangle())
                .onTapGesture { location in
                    guard !freezeMotion else { return }
                    burstPoint = location; burstStartedAt = .now
                }
        }.ignoresSafeArea().allowsHitTesting(!freezeMotion).accessibilityHidden(true)
    }
    private func burstAmount(at age: TimeInterval) -> Double {
        guard age >= 0, age < 1.06 else { return 0 }
        if age < 0.3 { return 1 - pow(1 - age / 0.3, 3) }
        if age < 0.42 { return 1 }
        let progress = (age - 0.42) / 0.64
        return 1 - progress * progress * (3 - 2 * progress)
    }
}

struct MiloPrimaryButton: View {
    let title: String
    var action: () -> Void
    @Environment(\.isEnabled) private var isEnabled
    var body: some View {
        Button(action: action) {
            Text(title).font(.body.weight(.medium)).tracking(1.2)
                .multilineTextAlignment(.center).padding(.horizontal, 18).padding(.vertical, 15)
                .frame(maxWidth: .infinity, minHeight: 52)
                .foregroundStyle(.white)
                .background(LinearGradient(colors: [MiloTheme.accent.opacity(0.85), MiloTheme.rose.opacity(0.72)], startPoint: .topLeading, endPoint: .bottomTrailing), in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.28), lineWidth: 0.7))
                .shadow(color: MiloTheme.accent.opacity(isEnabled ? 0.23 : 0), radius: 20, y: 8)
        }.buttonStyle(MiloPressStyle()).opacity(isEnabled ? 1 : 0.38)
    }
}

struct MiloGlassButton: View {
    let title: String
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(.body).foregroundStyle(MiloTheme.dim)
                .padding(.horizontal, 18).padding(.vertical, 13).frame(maxWidth: .infinity, minHeight: 48)
                .background(LinearGradient(colors: [.white.opacity(0.12), .white.opacity(0.025)], startPoint: .top, endPoint: .bottom), in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.14), lineWidth: 0.7))
        }.buttonStyle(MiloPressStyle())
    }
}

struct MiloPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct MiloBackButton: View {
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.left").font(.system(size: 16, weight: .light))
                .foregroundStyle(MiloTheme.dim).frame(width: 44, height: 44)
                .background(.white.opacity(0.035), in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.09), lineWidth: 0.7))
        }.buttonStyle(.plain).accessibilityLabel("返回").accessibilityIdentifier("back")
    }
}

struct MiloPageHeader: View {
    let title: String
    var subtitle: String? = nil
    var back: () -> Void
    var body: some View {
        VStack(spacing: 16) {
            HStack { MiloBackButton(action: back); Spacer() }
            VStack(spacing: 10) {
                Text(title).font(MiloTheme.serif(24)).foregroundStyle(MiloTheme.ink)
                if let subtitle { Text(subtitle).font(.subheadline).foregroundStyle(MiloTheme.hint) }
            }.multilineTextAlignment(.center).frame(maxWidth: .infinity)
        }.padding(.top, 12)
    }
}

extension View {
    func miloPanel(padding: CGFloat = 20) -> some View {
        self.padding(padding).background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.10), lineWidth: 0.7))
    }
}

struct MoodPlanet: View {
    let mood: Mood
    var size: CGFloat
    @Environment(\.displayScale) private var displayScale
    private var atlas: (Int, Int, CGFloat) {
        switch mood.rawValue {
        case "very-low": (1, 0, -0.11)
        case "low": (1, 1, 0)
        case "heavy": (1, 2, 0.11)
        case "calm": (2, 0, -0.11)
        case "okay": (2, 1, 0)
        case "bright": (2, 2, 0.11)
        case "joyful": (3, 0, -0.11)
        case "lonely": (3, 1, 0)
        case "sad": (3, 2, 0.11)
        case "angry": (4, 0, -0.11)
        case "afraid": (4, 1, 0)
        case "disappointed": (4, 2, 0.11)
        case "anxious": (5, 0, -0.09)
        case "aggrieved": (5, 1, 0)
        default: (5, 2, 0.11)
        }
    }
    var body: some View {
        let art = atlas
        Group {
            if let image = MoodPlanetCropCache.image(sheet: art.0, panel: art.1,
                                                    focusOffset: art.2, size: size,
                                                    displayScale: displayScale) {
                Image(uiImage: image).renderingMode(.original)
                    .resizable().interpolation(.high)
            } else {
                Color.clear
            }
        }
            .frame(width: size, height: size * 2700 / 1748)
            .accessibilityHidden(true)
    }
}

/// Rasterize only a new mood/size combination, using the UIKit image path also
/// used by the card artwork. Starfield ticks and ring movement reuse this image.
@MainActor
private enum MoodPlanetCropCache {
    private static let images: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 30
        cache.totalCostLimit = 24 * 1024 * 1024
        return cache
    }()

    static func image(sheet: Int, panel: Int, focusOffset: CGFloat,
                      size: CGFloat, displayScale: CGFloat) -> UIImage? {
        guard size.isFinite, size > 0 else { return nil }
        let scale = displayScale.isFinite ? max(1, displayScale) : 1
        let key = "\(sheet)/\(panel)/\(focusOffset)/\(size)/\(scale)" as NSString
        if let cached = images.object(forKey: key) { return cached }
        guard let source = UIImage(named: "mood_sheet_0\(sheet)", in: .main, compatibleWith: nil) else { return nil }
        let height = size * 2700 / 1748
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = scale
        format.preferredRange = .standard
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: height), format: format)
        let cropped = renderer.image { _ in
            source.draw(in: CGRect(x: size * (-CGFloat(panel) + focusOffset), y: 0,
                                   width: size * 3, height: height))
        }
        let cost = cropped.cgImage.map { $0.bytesPerRow * $0.height } ?? 0
        images.setObject(cropped, forKey: key, cost: cost)
        return cropped
    }
}
