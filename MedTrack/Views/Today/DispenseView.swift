import SwiftUI

struct DispenseView: View {
    let record: DoseRecord
    let pillColor: Color
    let pillShape: PillShapeType
    let onDone: () -> Void

    @State private var step: Int = 0

    private var med: Medication? { record.medication }

    var body: some View {
        ZStack {
            Color.dsBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 6) {
                    Text("PillBox dispensing")
                        .font(.system(size: 13 * dsScale, weight: .semibold))
                        .foregroundStyle(Color.dsInk3)
                        .textCase(.uppercase)
                        .tracking(1.5)

                    Text(med?.name ?? "Medication")
                        .font(.system(size: 30 * dsScale, weight: .regular, design: .serif))
                        .foregroundStyle(Color.dsInk)
                }
                .padding(.top, 80)
                .padding(.bottom, 32)

                Spacer()

                // Animation canvas
                ZStack(alignment: .top) {
                    // Box
                    PillBoxIllustrationView(connected: true)
                        .frame(width: 200, height: 120)

                    // Dispense chute
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: "#2A2420"))
                        .frame(width: 40, height: 20)
                        .offset(y: 116)

                    // Falling pill
                    PillShapeView(color: pillColor, shape: pillShape, scale: 2.4)
                        .offset(y: pillYOffset)
                        .opacity(step >= 1 ? 1 : 0)
                        .animation(step >= 2 ? .easeIn(duration: 0.9) : .none, value: pillYOffset)
                        .animation(.easeIn(duration: 0.25), value: step >= 1)
                }
                .frame(width: 280, height: 280)

                // Tray
                Ellipse()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#EFE6D8"), Color(hex: "#E0D4BF")],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .frame(width: 240, height: 60)
                    .overlay(alignment: .center) {
                        if step >= 3 {
                            PillShapeView(color: pillColor, shape: pillShape, scale: 2.4)
                                .offset(y: 6)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .animation(.spring(), value: step >= 3)

                // Status text
                Text(stepText)
                    .font(.system(size: 17 * dsScale, weight: .medium))
                    .foregroundStyle(step == 3 ? Color.dsSuccess : Color.dsInk2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 28)
                    .animation(.default, value: step)

                Spacer()

                // CTA button
                Button(action: onDone) {
                    Text(step < 3 ? "Please wait…" : "I've taken it")
                        .font(.system(size: 20 * dsScale, weight: .semibold))
                        .foregroundStyle(step < 3 ? Color.dsInk3 : .white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 64)
                }
                .background(step < 3 ? Color.dsLine : Color.dsSuccess)
                .clipShape(Capsule())
                .disabled(step < 3)
                .padding(.horizontal, 24)
                .padding(.bottom, 44)
                .animation(.easeInOut(duration: 0.3), value: step)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { step = 1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { step = 2 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) { step = 3 }
        }
    }

    private var pillYOffset: CGFloat {
        step >= 2 ? 240 : 128
    }

    private var stepText: String {
        switch step {
        case 0: return "Preparing your dose…"
        case 1: return "Releasing compartment…"
        case 2: return "Dispensing…"
        default: return "✓ Ready to take — lift the pill from the tray"
        }
    }
}
