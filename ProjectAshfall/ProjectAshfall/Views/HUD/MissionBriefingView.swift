// MissionBriefingView.swift
// ProjectAshfall
//
// Pre-mission briefing overlay displaying mission name, type, difficulty,
// objectives, reward preview, recommended squad power, and enemy silhouettes.

import SwiftUI

// MARK: - Mission Data

struct MissionObjective: Identifiable {
    let id = UUID()
    let description: String
    let isOptional: Bool
}

struct MissionData {
    var name: String
    var type: MissionType
    var difficulty: Int                   // 1-10
    var objectives: [MissionObjective]
    var rewards: [String: Int]
    var recommendedPower: Int
    var enemyCount: Int
    var districtName: String

    enum MissionType: String {
        case assault   = "Assault"
        case defense   = "Defense"
        case recon     = "Recon"
        case rescue    = "Rescue"
        case scavenge  = "Scavenge"
        case boss      = "Boss"

        var icon: String {
            switch self {
            case .assault:  return "burst.fill"
            case .defense:  return "shield.fill"
            case .recon:    return "binoculars.fill"
            case .rescue:   return "figure.walk"
            case .scavenge: return "shippingbox.fill"
            case .boss:     return "flame.fill"
            }
        }

        var color: Color {
            switch self {
            case .assault:  return AshfallColors.ember
            case .defense:  return AshfallColors.shield
            case .recon:    return AshfallColors.electronics
            case .rescue:   return AshfallColors.health
            case .scavenge: return AshfallColors.gold
            case .boss:     return AshfallColors.danger
            }
        }
    }

    static let placeholder = MissionData(
        name: "Clear the Sector",
        type: .assault,
        difficulty: 3,
        objectives: [
            MissionObjective(description: "Eliminate all hostiles in the area", isOptional: false),
            MissionObjective(description: "Secure the supply cache", isOptional: false),
            MissionObjective(description: "Find the survivor's journal", isOptional: true),
        ],
        rewards: ["scrap": 120, "food": 40, "electronics": 15],
        recommendedPower: 850,
        enemyCount: 4,
        districtName: "Industrial Sector"
    )
}

// MARK: - Mission Briefing View

struct MissionBriefingView: View {
    @EnvironmentObject var gameState: GameStateManager

    let mission: MissionData
    var onBegin: () -> Void
    var onBack: () -> Void

    @State private var revealProgress: CGFloat = 0

    var body: some View {
        ZStack {
            // Dark cinematic background
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 20)

                scrollContent

                Spacer()

                bottomButtons
                    .padding(.bottom, 24)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                revealProgress = 1
            }
        }
    }

    // MARK: - Scroll Content

    private var scrollContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AshfallTheme.sectionSpacing) {
                headerSection
                difficultySection
                objectivesSection
                enemyPreviewSection
                rewardsSection
                squadPowerSection
            }
            .padding(.horizontal, AshfallTheme.screenPadding)
            .opacity(Double(revealProgress))
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 10) {
            // Mission type badge
            HStack(spacing: 6) {
                Image(systemName: mission.type.icon)
                    .font(.system(size: 12, weight: .bold))
                Text(mission.type.rawValue.uppercased())
                    .font(AshfallFonts.caption(11))
                    .tracking(2)
            }
            .foregroundColor(mission.type.color)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(mission.type.color.opacity(0.15))
            )
            .overlay(
                Capsule()
                    .stroke(mission.type.color.opacity(0.4), lineWidth: 1)
            )

            // Mission name
            Text(mission.name)
                .font(AshfallFonts.title(28))
                .foregroundColor(AshfallColors.textPrimary)
                .multilineTextAlignment(.center)

            // Location
            HStack(spacing: 4) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 12))
                Text(mission.districtName)
                    .font(AshfallFonts.caption(13))
            }
            .foregroundColor(AshfallColors.textSecondary)

            // Decorative divider
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, mission.type.color.opacity(0.5), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)
                .padding(.horizontal, 40)
        }
    }

    // MARK: - Difficulty

    private var difficultySection: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16))
                .foregroundColor(difficultyColor)

            VStack(alignment: .leading, spacing: 2) {
                Text("Difficulty")
                    .font(AshfallFonts.caption(11))
                    .foregroundColor(AshfallColors.textSecondary)

                HStack(spacing: 4) {
                    ForEach(1...10, id: \.self) { level in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(level <= mission.difficulty ? difficultyColor : AshfallColors.surface)
                            .frame(width: 16, height: 8)
                    }
                }
            }

            Spacer()

            Text(difficultyLabel)
                .font(AshfallFonts.heading(14))
                .foregroundColor(difficultyColor)
        }
        .padding(14)
        .ashfallCard()
    }

    private var difficultyColor: Color {
        switch mission.difficulty {
        case 1...2: return AshfallColors.health
        case 3...4: return AshfallColors.gold
        case 5...6: return AshfallColors.accent
        case 7...8: return AshfallColors.ember
        default:    return AshfallColors.danger
        }
    }

    private var difficultyLabel: String {
        switch mission.difficulty {
        case 1...2: return "Easy"
        case 3...4: return "Moderate"
        case 5...6: return "Hard"
        case 7...8: return "Extreme"
        default:    return "Lethal"
        }
    }

    // MARK: - Objectives

    private var objectivesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Objectives", icon: "list.bullet.clipboard.fill")

            ForEach(mission.objectives) { objective in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: objective.isOptional ? "diamond" : "checkmark.circle")
                        .font(.system(size: 14))
                        .foregroundColor(objective.isOptional ? AshfallColors.gold : AshfallColors.accent)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(objective.description)
                            .font(AshfallFonts.body(14))
                            .foregroundColor(AshfallColors.textPrimary)

                        if objective.isOptional {
                            Text("BONUS")
                                .font(AshfallFonts.caption(9))
                                .foregroundColor(AshfallColors.gold)
                                .tracking(1)
                        }
                    }
                }
            }
        }
        .padding(14)
        .ashfallCard()
    }

    // MARK: - Enemy Preview

    private var enemyPreviewSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Hostiles", icon: "person.crop.circle.badge.exclamationmark.fill")

            HStack(spacing: 14) {
                ForEach(0..<min(mission.enemyCount, 6), id: \.self) { index in
                    enemySilhouette(index: index)
                }

                if mission.enemyCount > 6 {
                    VStack(spacing: 2) {
                        Text("+\(mission.enemyCount - 6)")
                            .font(AshfallFonts.mono(14))
                            .foregroundColor(AshfallColors.danger)
                        Text("more")
                            .font(AshfallFonts.caption(9))
                            .foregroundColor(AshfallColors.textDim)
                    }
                }

                Spacer()
            }
        }
        .padding(14)
        .ashfallCard()
    }

    private func enemySilhouette(index: Int) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(AshfallColors.danger.opacity(0.1))
                .frame(width: 44, height: 52)

            VStack(spacing: 2) {
                // Head
                Circle()
                    .fill(AshfallColors.danger.opacity(0.35))
                    .frame(width: 14, height: 14)

                // Body
                RoundedRectangle(cornerRadius: 3)
                    .fill(AshfallColors.danger.opacity(0.25))
                    .frame(width: 18, height: 22)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AshfallColors.danger.opacity(0.2), lineWidth: 0.5)
        )
    }

    // MARK: - Rewards

    private var rewardsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Rewards", icon: "gift.fill")

            HStack(spacing: 16) {
                ForEach(Array(mission.rewards.keys.sorted()), id: \.self) { key in
                    if let amount = mission.rewards[key] {
                        VStack(spacing: 4) {
                            Image(systemName: resourceIcon(key))
                                .font(.system(size: 18))
                                .foregroundColor(resourceColor(key))

                            Text("+\(amount)")
                                .font(AshfallFonts.mono(13))
                                .foregroundColor(AshfallColors.textPrimary)

                            Text(key.capitalized)
                                .font(AshfallFonts.caption(9))
                                .foregroundColor(AshfallColors.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }

            // XP reward
            HStack(spacing: 6) {
                Image(systemName: "star.fill")
                    .font(.system(size: 12))
                    .foregroundColor(AshfallColors.gold)
                Text("+100 Commander XP")
                    .font(AshfallFonts.caption(12))
                    .foregroundColor(AshfallColors.gold)
            }
            .padding(.top, 4)
        }
        .padding(14)
        .ashfallCard()
    }

    // MARK: - Squad Power

    private var squadPowerSection: some View {
        let currentPower = gameState.heroes
            .filter { gameState.activeSquad.contains($0.id) }
            .reduce(0) { $0 + $1.power }
        let isReady = currentPower >= mission.recommendedPower

        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Recommended Power")
                    .font(AshfallFonts.caption(11))
                    .foregroundColor(AshfallColors.textSecondary)

                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 14))
                    Text("\(mission.recommendedPower)")
                        .font(AshfallFonts.stat(18))
                }
                .foregroundColor(AshfallColors.textPrimary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("Your Squad")
                    .font(AshfallFonts.caption(11))
                    .foregroundColor(AshfallColors.textSecondary)

                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 14))
                    Text("\(currentPower)")
                        .font(AshfallFonts.stat(18))
                }
                .foregroundColor(isReady ? AshfallColors.health : AshfallColors.danger)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(AshfallColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            isReady ? AshfallColors.health.opacity(0.3) : AshfallColors.danger.opacity(0.3),
                            lineWidth: 1
                        )
                )
        )
    }

    // MARK: - Bottom Buttons

    private var bottomButtons: some View {
        HStack(spacing: 16) {
            Button(action: {
                AudioManager.shared.hapticLight()
                onBack()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
            }
            .buttonStyle(SecondaryButtonStyle())

            Button(action: {
                AudioManager.shared.hapticMedium()
                onBegin()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "figure.walk")
                    Text("Begin Mission")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(.horizontal, AshfallTheme.screenPadding)
    }

    // MARK: - Helpers

    private func sectionLabel(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(AshfallColors.accent)
            Text(title)
                .font(AshfallFonts.heading(15))
                .foregroundColor(AshfallColors.textPrimary)
        }
    }

    private func resourceIcon(_ key: String) -> String {
        switch key {
        case "food":        return "leaf.fill"
        case "water":       return "drop.fill"
        case "fuel":        return "fuelpump.fill"
        case "scrap":       return "gearshape.fill"
        case "electronics": return "cpu"
        case "medicine":    return "cross.case.fill"
        default:            return "questionmark"
        }
    }

    private func resourceColor(_ key: String) -> Color {
        switch key {
        case "food":        return AshfallColors.food
        case "water":       return AshfallColors.water
        case "fuel":        return AshfallColors.fuel
        case "scrap":       return AshfallColors.scrap
        case "electronics": return AshfallColors.electronics
        case "medicine":    return AshfallColors.medicine
        default:            return AshfallColors.textSecondary
        }
    }
}
