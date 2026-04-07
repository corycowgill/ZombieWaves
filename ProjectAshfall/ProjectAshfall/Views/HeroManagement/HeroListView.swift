// HeroListView.swift
// ProjectAshfall
//
// Scrollable hero roster with filter-by-role and sort options.
// Each hero is displayed as a styled card with portrait, role, level, and rank stars.

import SwiftUI

// MARK: - Sort Option

enum HeroSortOption: String, CaseIterable {
    case level = "Level"
    case power = "Power"
    case name  = "Name"
    case role  = "Role"
}

// MARK: - Hero List View

struct HeroListView: View {
    @EnvironmentObject var gameState: GameStateManager

    @State private var selectedRole: HeroRole?
    @State private var sortOption: HeroSortOption = .level
    @State private var selectedHero: Hero?

    private var filteredHeroes: [Hero] {
        var list = gameState.heroes
        if let role = selectedRole {
            list = list.filter { $0.role == role }
        }
        switch sortOption {
        case .level: list.sort { $0.level > $1.level }
        case .power: list.sort { $0.power > $1.power }
        case .name:  list.sort { $0.name < $1.name }
        case .role:  list.sort { $0.role.rawValue < $1.role.rawValue }
        }
        return list
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterBar
                    .padding(.horizontal, AshfallTheme.screenPadding)
                    .padding(.vertical, 8)

                sortBar
                    .padding(.horizontal, AshfallTheme.screenPadding)
                    .padding(.bottom, 8)

                ScrollView {
                    LazyVGrid(
                        columns: [
                            GridItem(.adaptive(minimum: 150, maximum: 180), spacing: 12)
                        ],
                        spacing: 12
                    ) {
                        ForEach(filteredHeroes) { hero in
                            NavigationLink(value: hero.id) {
                                heroCard(hero)
                            }
                        }
                    }
                    .padding(.horizontal, AshfallTheme.screenPadding)
                    .padding(.bottom, 20)
                }
            }
            .background(AshfallColors.background.ignoresSafeArea())
            .navigationTitle("Heroes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationDestination(for: String.self) { heroId in
                if let hero = gameState.heroes.first(where: { $0.id == heroId }) {
                    HeroDetailView(hero: hero)
                        .environmentObject(gameState)
                }
            }
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(label: "All", role: nil)
                ForEach(HeroRole.allCases, id: \.self) { role in
                    filterChip(label: role.rawValue, role: role)
                }
            }
        }
    }

    private func filterChip(label: String, role: HeroRole?) -> some View {
        let isActive = selectedRole == role

        return Button(action: {
            selectedRole = role
            AudioManager.shared.hapticSelection()
        }) {
            HStack(spacing: 4) {
                if let role {
                    Image(systemName: role.icon)
                        .font(.system(size: 11))
                }
                Text(label)
                    .font(AshfallFonts.caption(12))
            }
            .foregroundColor(isActive ? AshfallColors.textPrimary : AshfallColors.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                Capsule().fill(isActive ? AshfallColors.accent.opacity(0.3) : AshfallColors.surface)
            )
            .overlay(
                Capsule().stroke(isActive ? AshfallColors.accent.opacity(0.6) : AshfallColors.surfaceLight, lineWidth: 1)
            )
        }
    }

    // MARK: - Sort Bar

    private var sortBar: some View {
        HStack {
            Text("Sort by:")
                .font(AshfallFonts.caption())
                .foregroundColor(AshfallColors.textSecondary)

            Picker("Sort", selection: $sortOption) {
                ForEach(HeroSortOption.allCases, id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .tint(AshfallColors.accent)

            Spacer()

            Text("\(filteredHeroes.count) heroes")
                .font(AshfallFonts.caption())
                .foregroundColor(AshfallColors.textSecondary)
        }
    }

    // MARK: - Hero Card

    private func heroCard(_ hero: Hero) -> some View {
        VStack(spacing: 8) {
            // Portrait area
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [roleGradientColor(hero.role), AshfallColors.surface],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 100)

                // Role icon as portrait placeholder
                Image(systemName: hero.role.icon)
                    .font(.system(size: 36))
                    .foregroundColor(AshfallColors.textPrimary.opacity(0.8))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Level badge
                Text("Lv.\(hero.level)")
                    .font(AshfallFonts.caption(10))
                    .foregroundColor(AshfallColors.textPrimary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(AshfallColors.background.opacity(0.8)))
                    .padding(6)
            }
            .frame(height: 100)

            VStack(spacing: 4) {
                Text(hero.name)
                    .font(AshfallFonts.body(14))
                    .foregroundColor(AshfallColors.textPrimary)
                    .lineLimit(1)

                // Role label
                Text(hero.role.rawValue)
                    .font(AshfallFonts.caption(11))
                    .foregroundColor(AshfallColors.accent)

                // Star rank
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= hero.rank ? "star.fill" : "star")
                            .font(.system(size: 9))
                            .foregroundColor(
                                star <= hero.rank
                                    ? AshfallColors.rankStarFilled
                                    : AshfallColors.rankStarEmpty
                            )
                    }
                }

                // Power rating
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 9))
                    Text("\(hero.power)")
                        .font(AshfallFonts.mono(11))
                }
                .foregroundColor(AshfallColors.textSecondary)
            }
            .padding(.bottom, 8)
        }
        .ashfallCard()
    }

    // MARK: - Helpers

    private func roleGradientColor(_ role: HeroRole) -> Color {
        switch role {
        case .vanguard: return Color(red: 0.25, green: 0.35, blue: 0.55).opacity(0.6)
        case .marksman: return Color(red: 0.55, green: 0.30, blue: 0.15).opacity(0.6)
        case .medic:    return Color(red: 0.20, green: 0.50, blue: 0.30).opacity(0.6)
        case .engineer: return Color(red: 0.50, green: 0.40, blue: 0.15).opacity(0.6)
        case .scout:    return Color(red: 0.35, green: 0.20, blue: 0.50).opacity(0.6)
        }
    }
}
