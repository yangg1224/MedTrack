import SwiftUI

// MARK: - Design tokens (cool theme, matching prototype defaults)

extension Color {
    static let dsBackground = Color(hex: "#F1F4F6")
    static let dsCard       = Color.white
    static let dsLine       = Color(hex: "#DBE3E8")
    static let dsInk        = Color(hex: "#1A2230")
    static let dsInk2       = Color(hex: "#475668")
    static let dsInk3       = Color(hex: "#8594A4")
    static let dsAccent     = Color(hex: "#3D7CA8")
    static let dsAccentSoft = Color(hex: "#E1ECF4")
    static let dsSuccess    = Color(hex: "#4A8E78")
    static let dsWarning    = Color(hex: "#D69A3A")
    static let dsDanger     = Color(hex: "#B84A3A")

    // Pill color palette — cycled by medication index
    static let pillPalette: [Color] = [
        Color(hex: "#D86A4C"),
        Color(hex: "#E8B04D"),
        Color(hex: "#7BA87A"),
        Color(hex: "#CBD8E4"),
        Color(hex: "#C9A8E0"),
    ]

    init(hex: String) {
        var h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        if h.count == 3 { h = h.map { "\($0)\($0)" }.joined() }
        var n: UInt64 = 0
        Scanner(string: h).scanHexInt64(&n)
        self.init(
            .sRGB,
            red:   Double((n >> 16) & 0xFF) / 255,
            green: Double((n >> 8)  & 0xFF) / 255,
            blue:  Double( n        & 0xFF) / 255,
            opacity: 1
        )
    }
}

// MARK: - Text scale (Large, matching prototype's 1.15×)
let dsScale: CGFloat = 1.15

// MARK: - Pill shape

enum PillShapeType: String, CaseIterable {
    case oval, round, capsule

    static func forIndex(_ i: Int) -> PillShapeType {
        let s: [PillShapeType] = [.oval, .round, .oval, .capsule, .round]
        return s[i % s.count]
    }
}

// MARK: - Shared components

struct ProgressRingView: View {
    let value: Double   // 0…1
    var size: CGFloat = 74

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.dsLine, lineWidth: 6)
            Circle()
                .trim(from: 0, to: max(0, min(1, value)))
                .stroke(Color.dsAccent,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.6), value: value)
        }
        .frame(width: size, height: size)
    }
}

struct PillShapeView: View {
    let color: Color
    let shape: PillShapeType
    var scale: CGFloat = 1

    var body: some View {
        Group {
            switch shape {
            case .oval:
                Ellipse()
                    .fill(color)
                    .frame(width: 26 * scale, height: 16 * scale)
            case .round:
                Circle()
                    .fill(color)
                    .frame(width: 22 * scale, height: 22 * scale)
            case .capsule:
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [color, color.opacity(0.65)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 28 * scale, height: 14 * scale)
            }
        }
        .shadow(color: .black.opacity(0.14), radius: 1, x: 0, y: 1)
    }
}

struct PillBoxIllustrationView: View {
    let connected: Bool

    private let dotColors: [Color?] = [
        Color(hex: "#D86A4C"), Color(hex: "#E8B04D"), Color(hex: "#7BA87A"), nil,
        nil, nil, nil, nil,
    ]

    var body: some View {
        RoundedRectangle(cornerRadius: 22)
            .fill(
                LinearGradient(
                    colors: [Color(hex: "#FBF6EE"), Color(hex: "#F3EAD8")],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .overlay {
                // 4 × 2 slot grid
                VStack(spacing: 5) {
                    ForEach(0..<2, id: \.self) { row in
                        HStack(spacing: 5) {
                            ForEach(0..<4, id: \.self) { col in
                                let idx = row * 4 + col
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(hex: "#E5DCCB"))
                                    .overlay {
                                        if idx < dotColors.count,
                                           let c = dotColors[idx] {
                                            Circle().fill(c).frame(width: 8, height: 8)
                                        }
                                    }
                            }
                        }
                    }
                }
                .padding(14)
            }
            .overlay(alignment: .topTrailing) {
                Circle()
                    .fill(connected ? Color.dsSuccess : Color(hex: "#CFC3B0"))
                    .frame(width: 7, height: 7)
                    .shadow(color: connected ? Color.dsSuccess.opacity(0.6) : .clear,
                            radius: 4)
                    .padding([.top, .trailing], 10)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Color.dsLine, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 8)
            .frame(width: 220, height: 140)
    }
}
