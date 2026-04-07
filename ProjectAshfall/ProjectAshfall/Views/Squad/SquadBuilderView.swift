// SquadBuilderView.swift
// ProjectAshfall
//
// Squad assembly screen with 5 hero slots, formation selection,
// synergy/bond indicators, power rating, and deploy button.

import SwiftUI

// MARK: - Formation

enum Formation: String, CaseIterable {
    case standard  = "Standard"
    case defensive = "Defensive"
    case aggressive = "Aggressive"
    case flanking  = "Flanking"

    var description: String {
        switch self {
        case .standard:   return "Balanced positioning. No bonuses."
        case .defensive:  return "+15% Defense for front row."
        case .aggressive: return "+10% Attack for all. -5% Defense."
        case .flanking:   return "+20% Crit Rate for scouts."
        }
    }

    var icon: String {
        switch self {
        case .standard:   return "rectangle.split.3x3"
        case .defensive:  return "shield.fill"
        case .aggressive: return "flame.fill"
        case .flanking:   return "arrow.triangle.branch"
        }
    }
}

// MARK: - Squad Builder View

struct SquadBuilderView: View {
    @EnvironmentObject var gameState: GameStateManager

    @State private var squadSlots: [String?] = Array(repeating: nil, count: 5)
    @State private var selectedSlotIndex: Int?
    @State private var selectedFormation: Formation = .standard
    @State private var showHeroPicker = false
    @State private var draggedHeroId: String?

    private let maxSlots = AshfallTheme.maxSquadSize

    // Heroes assigned in squad
    private var assignedHeroes: [Hero] {
        squadSlots.compactMap { id in
            guard let id else { return nil }
            return gameState.heroes.first(where: { $0.id == id })
        }
    }

    // Heroes available to pick (not yet assigned)
    private var availableHeroes: [Hero] {
        gameState.heroes.filter { hero in
            !squadSlots.contains(hero.id)
        }
    }

    // Squad power
    private var totalPower: Int {
        assignedHeroes.reduce(0) { $0 + $1.power }
    }

    // Active bonds between assigned heroes
    private var activeBonds: [(Hero, HeroBond)] {
        var result: [(Hero, HeroBond)] = []
        for hero in assignedHeroes {
            for bond in hero.bonds {
                if assignedHeroes.contains(where: { $0.id == bond.partnerHeroId }) {
                    result.append((hero, bond))
                }
            }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    squadSlotsSection
                    formationSection
                    synergySection
                    powerSection
                    deployButton
                }
                .padding(AshfallTheme.screenPadding)
            }
            .background(AshfallColors.background.ignoresSafeArea())
            .navigationTitle("Squad Builder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .onAppear { loadCurrentSquad() }
            .sheet(isPresented: $showHeroPicker) {
                heroPickerSheet
            }
        }
    }

    // MARK: - Squad Slots

    private var squadSlotsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SQUAD ROSTER")
                .font(AshfallFonts.caption(12))
                .foregroundColor(AshfallColors.textSecondary)
                .tracking(2)

            HStack(spacing: 10) {
                ForEach(0..<maxSlots, id: \.self) { index in
                    slotView(index: index)
                }
            }
        }
    }

    private func slotView(index: Int) -> some View {
        let heroId = index < squadSlots.count ? squadSlots[index] : nil
        let hero = heroId.flatMap { id in gameState.heroes.first(where: { $0.id == id }) }
        let isSelected = selectedSlotIndex == index

        return VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(hero != nil ? AshfallColors.surface : AshfallColors.surface.opacity(0.4))
                    .frame(width: 60, height: 72)

                if let hero {
                    VStack(spacing: 2) {
                        Image(systemName: hero.role.icon)
                            .font(.system(size: 20))
                            .foregroundColor(AshfallColors.textPrimary)

                        Text("Lv.\(hero.level)")
                            .font(AshfallFonts.caption(9))
                            .foregroundColor(AshfallColors.accent)
                    }
                } else {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .light))
                        .foregroundColor(AshfallColors.textSecondary.opacity(0.4))
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        isSelected ? AshfallColors.accent : AshfallColors.surfaceLight.opacity(0.3),
                        lineWidth: isSelected ? 2 : 0.5
                    )
            )
            .onTapGesture {
                AudioManager.shared.hapticLight()
                if hero != nil {
                    // Tap occupied slot to deselect or remove
                    if isSelected {
                        squadSlots[index] = nil
                        selectedSlotIndex = nil
                    } else {
                        selectedSlotIndex = index
                    }
                } else {
                    selectedSlotIndex = index
                    showHeroPicker = true
                }
            }
            .onDrop(of: [.text], isTargeted: nil) { providers in
                handleDrop(providers: providers, targetIndex: index)
            }

            Text(hero?.name.split(separator: " ").first.map(String.init) ?? "Empty")
                .font(AshfallFonts.caption(9))
                .foregroundColor(hero != nil ? AshfallColors.textSecondary : AshfallColors.textSecondary.opacity(0.3))
                .lineLimit(1)
                .frame(width: 60)
        }
        .onDrag {
            if let heroId = squadSlots[index] {
                draggedHeroId = heroId
                return NSItemProvider(object: heroId as NSString)
            }
            return NSItemProvider()
        }
    }

    // MARK: - Formation

    private var formationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("FORMATION")
                .font(AshfallFonts.caption(12))
                .foregroundColor(AshfallColors.textSecondary)
                .tracking(2)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Formation.allCases, id: \.self) { formation in
                        formationCard(formation)
                    }
                }
            }
        }
    }

    private func formationCard(_ formation: Formation) -> some View {
        let isActive = selectedFormation == formation

        return Button(action: {
            selectedFormation = formation
            AudioManager.shared.hapticSelection()
        }) {
            VStack(spacing: 6) {
                Image(systemName: formation.icon)
                    .font(.system(size: 22))
                    .foregroundColor(isActive ? AshfallColors.accent : AshfallColors.textSecondary)

                Text(formation.rawValue)
                    .font(AshfallFonts.caption(11))
                    .foregroundColor(isActive ? AshfallColors.textPrimary : AshfallColors.textSecondary)
            }
            .frame(width: 80, height: 70)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isActive ? AshfallColors.accent.opacity(0.15) : AshfallColors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isActive ? AshfallColors.accent.opacity(0.5) : Color.clear, lineWidth: 1.5)
            )
        }
    }

    // MARK: - Synergy & Bonds

    private var synergySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SYNERGIES & BONDS")
                .font(AshfallFonts.caption(12))
                .foregroundColor(AshfallColors.textSecondary)
                .tracking(2)

            if activeBonds.isEmpty {
                HStack {
                    Image(systemName: "link")
                        .foregroundColor(AshfallColors.textSecondary.opacity(0.3))
                    Text("No active bonds. Pair bonded heroes for combat bonuses.")
                        .font(AshfallFonts.caption(12))
                        .foregroundColor(AshfallColors.textSecondary.opacity(0.5))
                }
                .padding(12)
                .ashfallCard()
            } else {
                ForEach(activeBonds, id: \.1.id) { hero, bond in
                    HStack(spacing: 8) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 12))
                            .foregroundColor(AshfallColors.danger)

                        if let partner = gameState.heroes.first(where: { $0.id == bond.partnerHeroId }) {
                            Text("\(hero.name) & \(partner.name)")
                                .font(AshfallFonts.body(13))
                                .foregroundColor(AshfallColors.textPrimary)
                        }

                        Spacer()

                        Text(bond.bondName)
                            .font(AshfallFonts.caption(11))
                            .foregroundColor(AshfallColors.accent)
                    }
                    .padding(10)
                    .ashfallCard()
                }
            }

            // Formation description
            Text(selectedFormation.description)
                .font(AshfallFonts.caption(12))
                .foregroundColor(AshfallColors.textSecondary)
                .italic()
        }
    }

    // MARK: - Power Rating

    private var powerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("SQUAD POWER")
                    .font(AshfallFonts.caption(11))
                    .foregroundColor(AshfallColors.textSecondary)
                    .tracking(1)

                Text("\(totalPower)")
                    .font(AshfallFonts.stat(28))
                    .foregroundColor(AshfallColors.accent)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(assignedHeroes.count)/\(maxSlots) Heroes")
                    .font(AshfallFonts.caption(12))
                    .foregroundColor(AshfallColors.textSecondary)

                // Role coverage
                HStack(spacing: 4) {
                    ForEach(HeroRole.allCases, id: \.self) { role in
                        let hasRole = assignedHeroes.contains(where: { $0.role == role })
                        Image(systemName: role.icon)
                            .font(.system(size: 11))
                            .foregroundColor(hasRole ? AshfallColors.accent : AshfallColors.textSecondary.opacity(0.2))
                    }
                }
            }
        }
        .padding(14)
        .ashfallCard()
    }

    // MARK: - Deploy Button

    private var deployButton: some View {
        Button(action: {
            gameState.activeSquad = squadSlots.compactMap { $0 }
            gameState.enterCombat()
            AudioManager.shared.hapticMedium()
        }) {
            HStack {
                Image(systemName: "figure.walk")
                Text("Deploy Squad")
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .opacity(assignedHeroes.isEmpty ? 0.4 : 1.0)
        .disabled(assignedHeroes.isEmpty)
    }

    // MARK: - Hero Picker Sheet

    private var heroPickerSheet: some View {
        NavigationStack {
            List(availableHeroes) { hero in
                Button(action: {
                    if let slot = selectedSlotIndex {
                        squadSlots[slot] = hero.id
                    }
                    showHeroPicker = false
                    AudioManager.shared.hapticLight()
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: hero.role.icon)
                            .font(.system(size: 18))
                            .foregroundColor(AshfallColors.accent)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(AshfallColors.surface))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(hero.name)
                                .font(AshfallFonts.body(15))
                                .foregroundColor(AshfallColors.textPrimary)

                            HStack(spacing: 8) {
                                Text(hero.role.rawValue)
                                    .font(AshfallFonts.caption(11))
                                    .foregroundColor(AshfallColors.accent)

                                Text("Lv.\(hero.level)")
                                    .font(AshfallFonts.caption(11))
                                    .foregroundColor(AshfallColors.textSecondary)
                            }
                        }

                        Spacer()

                        HStack(spacing: 3) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 10))
                            Text("\(hero.power)")
                                .font(AshfallFonts.mono(13))
                        }
                        .foregroundColor(AshfallColors.textSecondary)
                    }
                }
                .listRowBackground(AshfallColors.surface)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(AshfallColors.background.ignoresSafeArea())
            .navigationTitle("Select Hero")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showHeroPicker = false }
                        .foregroundColor(AshfallColors.accent)
                }
            }
        }
    }

    // MARK: - Helpers

    private func loadCurrentSquad() {
        for (index, heroId) in gameState.activeSquad.prefix(maxSlots).enumerated() {
            squadSlots[index] = heroId
        }
    }

    private func handleDrop(providers: [NSItemProvider], targetIndex: Int) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadObject(ofClass: NSString.self) { string, _ in
            guard let heroId = string as? String else { return }
            DispatchQueue.main.async {
                // Find source index
                if let sourceIndex = squadSlots.firstIndex(of: heroId) {
                    // Swap
                    let temp = squadSlots[targetIndex]
                    squadSlots[targetIndex] = squadSlots[sourceIndex]
                    squadSlots[sourceIndex] = temp
                } else {
                    squadSlots[targetIndex] = heroId
                }
                AudioManager.shared.hapticMedium()
            }
        }
        return true
    }
}
