// HeroDetailView.swift
// ProjectAshfall
//
// Full-screen hero detail showing portrait, stats, skill tree,
// gear slots, bond relationships, and level/rank-up controls.

import SwiftUI

// MARK: - Hero Detail View

struct HeroDetailView: View {
    @EnvironmentObject var gameState: GameStateManager
    @Environment(\.dismiss) private var dismiss

    let hero: Hero

    @State private var selectedTab: DetailTab = .stats
    @State private var showLevelUpConfirm = false

    enum DetailTab: String, CaseIterable {
        case stats = "Stats"
        case skills = "Skills"
        case gear = "Gear"
        case bonds = "Bonds"
        case story = "Story"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                headerSection
                tabSelector
                tabContent
            }
        }
        .background(AshfallColors.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var headerSection: some View {
        ZStack(alignment: .bottom) {
            // Gradient background
            LinearGradient(
                colors: [roleColor(hero.role).opacity(0.4), AshfallColors.background],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 260)

            VStack(spacing: 8) {
                // Portrait placeholder
                ZStack {
                    Circle()
                        .fill(roleColor(hero.role).opacity(0.3))
                        .frame(width: 120, height: 120)

                    Image(systemName: hero.role.icon)
                        .font(.system(size: 48))
                        .foregroundColor(AshfallColors.textPrimary)
                }
                .overlay(
                    Circle()
                        .stroke(AshfallColors.accent.opacity(0.4), lineWidth: 2)
                )

                Text(hero.name)
                    .font(AshfallFonts.title(26))
                    .foregroundColor(AshfallColors.textPrimary)

                HStack(spacing: 12) {
                    // Role
                    HStack(spacing: 4) {
                        Image(systemName: hero.role.icon)
                            .font(.system(size: 12))
                        Text(hero.role.rawValue)
                    }
                    .font(AshfallFonts.caption())
                    .foregroundColor(AshfallColors.accent)

                    // Level
                    Text("Level \(hero.level)")
                        .font(AshfallFonts.caption())
                        .foregroundColor(AshfallColors.textSecondary)

                    // Power
                    HStack(spacing: 3) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 10))
                        Text("\(hero.power)")
                    }
                    .font(AshfallFonts.caption())
                    .foregroundColor(AshfallColors.textSecondary)
                }

                // Star rank
                HStack(spacing: 3) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= hero.rank ? "star.fill" : "star")
                            .font(.system(size: 14))
                            .foregroundColor(
                                star <= hero.rank
                                    ? AshfallColors.rankStarFilled
                                    : AshfallColors.rankStarEmpty
                            )
                    }
                }
                .padding(.top, 2)
            }
            .padding(.bottom, 16)
        }
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(DetailTab.allCases, id: \.self) { tab in
                    Button(action: {
                        selectedTab = tab
                        AudioManager.shared.hapticSelection()
                    }) {
                        Text(tab.rawValue)
                            .font(AshfallFonts.body(14))
                            .foregroundColor(
                                selectedTab == tab ? AshfallColors.accent : AshfallColors.textSecondary
                            )
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .overlay(alignment: .bottom) {
                                if selectedTab == tab {
                                    Rectangle()
                                        .fill(AshfallColors.accent)
                                        .frame(height: 2)
                                }
                            }
                    }
                }
            }
        }
        .background(AshfallColors.surface)
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .stats:  statsTab
        case .skills: skillsTab
        case .gear:   gearTab
        case .bonds:  bondsTab
        case .story:  storyTab
        }
    }

    // MARK: Stats Tab

    private var statsTab: some View {
        VStack(spacing: 16) {
            // XP progress
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Experience")
                        .font(AshfallFonts.caption())
                        .foregroundColor(AshfallColors.textSecondary)
                    Spacer()
                    Text("\(hero.xp) / \(hero.xpForNextLevel)")
                        .font(AshfallFonts.mono(12))
                        .foregroundColor(AshfallColors.textSecondary)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(AshfallColors.surface)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(AshfallColors.accent)
                            .frame(width: geo.size.width * xpProgress)
                    }
                }
                .frame(height: 8)
            }
            .padding()
            .ashfallCard()

            // Core stats
            VStack(spacing: 10) {
                statRow(label: "Health", value: hero.maxHP, icon: "heart.fill", color: AshfallColors.health)
                statRow(label: "Attack", value: hero.attack, icon: "burst.fill", color: AshfallColors.ember)
                statRow(label: "Defense", value: hero.defense, icon: "shield.fill", color: AshfallColors.shield)
                statRow(label: "Speed", value: hero.speed, icon: "hare.fill", color: AshfallColors.accent)
                statRowDouble(label: "Crit Rate", value: hero.critRate, icon: "scope", color: AshfallColors.gold)
            }
            .padding()
            .ashfallCard()

            // Level up button
            Button(action: {
                levelUpHero()
            }) {
                HStack {
                    Image(systemName: "arrow.up.circle.fill")
                    Text("Level Up")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .opacity(canLevelUp ? 1.0 : 0.4)
            .disabled(!canLevelUp)
        }
        .padding(AshfallTheme.screenPadding)
    }

    private func statRow(label: String, value: Int, icon: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
                .frame(width: 24)

            Text(label)
                .font(AshfallFonts.body(14))
                .foregroundColor(AshfallColors.textSecondary)

            Spacer()

            Text("\(value)")
                .font(AshfallFonts.stat(16))
                .foregroundColor(AshfallColors.textPrimary)
        }
        .padding(.vertical, 4)
    }

    private func statRowDouble(label: String, value: Double, icon: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
                .frame(width: 24)

            Text(label)
                .font(AshfallFonts.body(14))
                .foregroundColor(AshfallColors.textSecondary)

            Spacer()

            Text(String(format: "%.0f%%", value * 100))
                .font(AshfallFonts.stat(16))
                .foregroundColor(AshfallColors.textPrimary)
        }
        .padding(.vertical, 4)
    }

    // MARK: Skills Tab

    private var skillsTab: some View {
        VStack(spacing: 12) {
            ForEach(hero.skills) { skill in
                HStack(spacing: 12) {
                    // Skill icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(skill.unlocked ? AshfallColors.accent.opacity(0.2) : AshfallColors.surface)
                            .frame(width: 48, height: 48)

                        Image(systemName: skill.unlocked ? "sparkle" : "lock.fill")
                            .font(.system(size: 18))
                            .foregroundColor(skill.unlocked ? AshfallColors.accent : AshfallColors.textSecondary.opacity(0.4))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(skill.name)
                                .font(AshfallFonts.body(15))
                                .foregroundColor(
                                    skill.unlocked ? AshfallColors.textPrimary : AshfallColors.textSecondary
                                )

                            if skill.unlocked {
                                Text("Lv.\(skill.level)/\(skill.maxLevel)")
                                    .font(AshfallFonts.caption(10))
                                    .foregroundColor(AshfallColors.accent)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(AshfallColors.accent.opacity(0.15)))
                            }
                        }

                        Text(skill.description)
                            .font(AshfallFonts.caption(12))
                            .foregroundColor(AshfallColors.textSecondary)
                            .lineLimit(2)

                        // Skill level progress
                        if skill.unlocked {
                            HStack(spacing: 2) {
                                ForEach(0..<skill.maxLevel, id: \.self) { i in
                                    Rectangle()
                                        .fill(i < skill.level ? AshfallColors.accent : AshfallColors.surface)
                                        .frame(height: 3)
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 2))
                        }
                    }

                    Spacer()
                }
                .padding(12)
                .ashfallCard()
            }
        }
        .padding(AshfallTheme.screenPadding)
    }

    // MARK: Gear Tab

    private var gearTab: some View {
        VStack(spacing: 12) {
            ForEach(hero.gear) { slot in
                HStack(spacing: 12) {
                    // Slot icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(slot.equippedItemName != nil ? AshfallColors.accent.opacity(0.15) : AshfallColors.surface)
                            .frame(width: 52, height: 52)

                        Image(systemName: gearIcon(for: slot.slotType))
                            .font(.system(size: 20))
                            .foregroundColor(
                                slot.equippedItemName != nil ? AshfallColors.accent : AshfallColors.textSecondary.opacity(0.4)
                            )
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(AshfallColors.surfaceLight, lineWidth: 0.5)
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(slot.slotType.capitalized)
                            .font(AshfallFonts.caption(11))
                            .foregroundColor(AshfallColors.textSecondary)

                        if let itemName = slot.equippedItemName {
                            Text(itemName)
                                .font(AshfallFonts.body(14))
                                .foregroundColor(AshfallColors.textPrimary)

                            HStack(spacing: 8) {
                                ForEach(Array(slot.statBonus.keys.sorted()), id: \.self) { stat in
                                    if let bonus = slot.statBonus[stat], bonus > 0 {
                                        Text("+\(bonus) \(stat.capitalized)")
                                            .font(AshfallFonts.caption(10))
                                            .foregroundColor(AshfallColors.health)
                                    }
                                }
                            }
                        } else {
                            Text("Empty Slot")
                                .font(AshfallFonts.body(14))
                                .foregroundColor(AshfallColors.textSecondary.opacity(0.5))
                        }
                    }

                    Spacer()

                    Button(action: {
                        AudioManager.shared.hapticLight()
                    }) {
                        Text(slot.equippedItemName != nil ? "Swap" : "Equip")
                            .font(AshfallFonts.caption())
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
                .padding(12)
                .ashfallCard()
            }
        }
        .padding(AshfallTheme.screenPadding)
    }

    // MARK: Bonds Tab

    private var bondsTab: some View {
        VStack(spacing: 12) {
            if hero.bonds.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "person.2.slash")
                        .font(.system(size: 40))
                        .foregroundColor(AshfallColors.textSecondary.opacity(0.3))
                    Text("No bonds discovered yet")
                        .font(AshfallFonts.body())
                        .foregroundColor(AshfallColors.textSecondary)
                    Text("Deploy heroes together in combat to build bonds.")
                        .font(AshfallFonts.caption())
                        .foregroundColor(AshfallColors.textSecondary.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 40)
            } else {
                ForEach(hero.bonds) { bond in
                    HStack(spacing: 12) {
                        // Partner icon
                        ZStack {
                            Circle()
                                .fill(AshfallColors.accent.opacity(0.15))
                                .frame(width: 48, height: 48)

                            Image(systemName: "person.fill")
                                .font(.system(size: 20))
                                .foregroundColor(AshfallColors.accent)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(bond.bondName)
                                .font(AshfallFonts.body(14))
                                .foregroundColor(AshfallColors.textPrimary)

                            if let partner = gameState.heroes.first(where: { $0.id == bond.partnerHeroId }) {
                                Text("with \(partner.name)")
                                    .font(AshfallFonts.caption(12))
                                    .foregroundColor(AshfallColors.textSecondary)
                            }

                            // Bond level hearts
                            HStack(spacing: 3) {
                                ForEach(1...5, id: \.self) { i in
                                    Image(systemName: i <= bond.bondLevel ? "heart.fill" : "heart")
                                        .font(.system(size: 10))
                                        .foregroundColor(i <= bond.bondLevel ? AshfallColors.danger : AshfallColors.textSecondary.opacity(0.3))
                                }
                            }
                        }

                        Spacer()
                    }
                    .padding(12)
                    .ashfallCard()
                }
            }
        }
        .padding(AshfallTheme.screenPadding)
    }

    // MARK: Story Tab

    private var storyTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Backstory")
                .font(AshfallFonts.heading(18))
                .foregroundColor(AshfallColors.textPrimary)

            Text(hero.backstory)
                .font(AshfallFonts.body(15))
                .foregroundColor(AshfallColors.textSecondary)
                .lineSpacing(4)

            Divider()
                .background(AshfallColors.surfaceLight)

            VStack(alignment: .leading, spacing: 8) {
                infoRow("Full Name", hero.name)
                infoRow("Role", hero.role.rawValue)
                infoRow("Rank", "\(hero.rank)-Star")
                infoRow("Recruitment", "Chapter 1 — Haven")
            }
        }
        .padding(AshfallTheme.screenPadding)
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(AshfallFonts.caption())
                .foregroundColor(AshfallColors.textSecondary)
                .frame(width: 100, alignment: .leading)
            Text(value)
                .font(AshfallFonts.body(14))
                .foregroundColor(AshfallColors.textPrimary)
        }
    }

    // MARK: - Helpers

    private var xpProgress: CGFloat {
        guard hero.xpForNextLevel > 0 else { return 0 }
        return CGFloat(hero.xp) / CGFloat(hero.xpForNextLevel)
    }

    private var canLevelUp: Bool {
        hero.xp >= hero.xpForNextLevel
    }

    private func levelUpHero() {
        guard canLevelUp else { return }
        if let idx = gameState.heroes.firstIndex(where: { $0.id == hero.id }) {
            gameState.heroes[idx].addXP(0)  // triggers level-up logic
            AudioManager.shared.hapticSuccess()
            AudioManager.shared.playSFX(named: "level_up", category: .ui)
        }
    }

    private func roleColor(_ role: HeroRole) -> Color {
        switch role {
        case .vanguard: return AshfallColors.shield
        case .marksman: return AshfallColors.ember
        case .medic:    return AshfallColors.health
        case .engineer: return AshfallColors.gold
        case .scout:    return Color.purple
        }
    }

    private func gearIcon(for slotType: String) -> String {
        switch slotType.lowercased() {
        case "weapon":    return "hammer.fill"
        case "armor":     return "shield.checkered"
        case "accessory": return "sparkle"
        default:          return "square.dashed"
        }
    }
}
