// ResourceBarView.swift
// ProjectAshfall
//
// Compact horizontal resource HUD showing six core resources with icons,
// counts, and expandable production-rate details. Animates count changes.

import SwiftUI

// MARK: - Resource Bar View

struct ResourceBarView: View {
    @EnvironmentObject var gameState: GameStateManager

    @State private var isExpanded = false

    private var resources: [(key: String, label: String, icon: String, color: Color, amount: Int, rate: Int)] {
        [
            ("food",        "Food",        "leaf.fill",         AshfallColors.food,        gameState.economy.food,        +8),
            ("water",       "Water",       "drop.fill",         AshfallColors.water,       gameState.economy.water,       +5),
            ("fuel",        "Fuel",        "fuelpump.fill",     AshfallColors.fuel,        gameState.economy.fuel,        +2),
            ("scrap",       "Scrap",       "gearshape.fill",    AshfallColors.scrap,       gameState.economy.scrap,       +12),
            ("electronics", "Electronics", "cpu",               AshfallColors.electronics, gameState.economy.electronics, +1),
            ("medicine",    "Medicine",    "cross.case.fill",   AshfallColors.medicine,    gameState.economy.medicine,    +3),
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            // Compact bar
            HStack(spacing: 10) {
                ForEach(resources, id: \.key) { res in
                    resourcePill(res)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AshfallColors.surface.opacity(0.92))
                    .shadow(color: .black.opacity(0.5), radius: 6, y: 2)
            )
            .onTapGesture {
                withAnimation(AshfallTheme.animationStandard) {
                    isExpanded.toggle()
                }
                AudioManager.shared.hapticLight()
            }

            // Expanded production rates
            if isExpanded {
                expandedPanel
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.horizontal, AshfallTheme.screenPadding)
    }

    // MARK: - Resource Pill

    private func resourcePill(_ res: (key: String, label: String, icon: String, color: Color, amount: Int, rate: Int)) -> some View {
        HStack(spacing: 4) {
            Image(systemName: res.icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(res.color)

            Text("\(res.amount)")
                .font(AshfallFonts.mono(11))
                .foregroundColor(AshfallColors.textPrimary)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.4), value: res.amount)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Expanded Panel

    private var expandedPanel: some View {
        VStack(spacing: 8) {
            ForEach(resources, id: \.key) { res in
                HStack {
                    Image(systemName: res.icon)
                        .font(.system(size: 14))
                        .foregroundColor(res.color)
                        .frame(width: 20)

                    Text(res.label)
                        .font(AshfallFonts.body(14))
                        .foregroundColor(AshfallColors.textPrimary)

                    Spacer()

                    Text("\(res.amount)")
                        .font(AshfallFonts.stat(16))
                        .foregroundColor(AshfallColors.textPrimary)
                        .contentTransition(.numericText())

                    rateLabel(res.rate)
                        .frame(width: 50, alignment: .trailing)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(AshfallColors.surface.opacity(0.95))
                .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
        )
        .padding(.horizontal, 4)
        .padding(.top, 4)
    }

    private func rateLabel(_ rate: Int) -> some View {
        let sign = rate >= 0 ? "+" : ""
        let color = rate > 0 ? AshfallColors.food : (rate < 0 ? AshfallColors.danger : AshfallColors.textDim)
        return Text("\(sign)\(rate)/m")
            .font(AshfallFonts.caption(11))
            .foregroundColor(color)
    }
}
