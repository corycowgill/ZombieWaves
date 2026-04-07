// WorldMapView.swift
// ProjectAshfall
//
// World map showing district nodes connected by paths, fog of war,
// district info on tap, and mission launch controls.

import SwiftUI

// MARK: - World Map View

struct WorldMapView: View {
    @EnvironmentObject var gameState: GameStateManager

    @State private var selectedDistrict: District?
    @State private var mapOffset: CGSize = .zero
    @State private var mapScale: CGFloat = 1.0

    private let nodeSpacing: CGFloat = 100
    private let nodeRadius: CGFloat = 28

    var body: some View {
        ZStack {
            AshfallColors.background.ignoresSafeArea()

            // Map content with pan/zoom
            mapContent
                .scaleEffect(mapScale)
                .offset(mapOffset)
                .gesture(dragGesture)
                .gesture(magnificationGesture)

            VStack {
                topBar
                Spacer()

                if let district = selectedDistrict {
                    districtInfoPanel(district)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: selectedDistrict?.id)
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button(action: {
                gameState.returnToBase()
                AudioManager.shared.hapticLight()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                    Text("Base")
                }
                .font(AshfallFonts.body())
                .foregroundColor(AshfallColors.accent)
            }

            Spacer()

            Text("WORLD MAP")
                .font(AshfallFonts.heading(16))
                .foregroundColor(AshfallColors.textPrimary)
                .tracking(3)

            Spacer()

            // Placeholder for symmetry
            Color.clear.frame(width: 60, height: 1)
        }
        .padding(.horizontal, AshfallTheme.screenPadding)
        .padding(.top, 12)
    }

    // MARK: - Map Content

    private var mapContent: some View {
        ZStack {
            // Connection paths
            ForEach(gameState.districts, id: \.id) { district in
                ForEach(district.connectedTo, id: \.self) { connectedId in
                    if let target = gameState.districts.first(where: { $0.id == connectedId }) {
                        pathLine(from: district, to: target)
                    }
                }
            }

            // District nodes
            ForEach(gameState.districts, id: \.id) { district in
                districtNode(district)
                    .position(nodePosition(for: district))
            }
        }
        .frame(width: 700, height: 600)
    }

    // MARK: - Path Lines

    private func pathLine(from source: District, to target: District) -> some View {
        let start = nodePosition(for: source)
        let end = nodePosition(for: target)
        let bothVisible = source.isUnlocked || target.isUnlocked

        return Path { path in
            path.move(to: start)
            path.addLine(to: end)
        }
        .stroke(
            bothVisible ? AshfallColors.textSecondary.opacity(0.4) : AshfallColors.fog.opacity(0.15),
            style: StrokeStyle(lineWidth: 2, dash: bothVisible ? [] : [6, 4])
        )
    }

    // MARK: - District Node

    private func districtNode(_ district: District) -> some View {
        let isSelected = selectedDistrict?.id == district.id
        let isCurrent = district.id == gameState.currentDistrict

        return ZStack {
            // Fog of war overlay for locked districts
            if !district.isUnlocked {
                Circle()
                    .fill(AshfallColors.fog.opacity(0.7))
                    .frame(width: nodeRadius * 2.4, height: nodeRadius * 2.4)
                    .blur(radius: 8)
            }

            // Node circle
            Circle()
                .fill(nodeColor(for: district))
                .frame(width: nodeRadius * 2, height: nodeRadius * 2)
                .overlay(
                    Circle()
                        .stroke(
                            isSelected ? AshfallColors.accent : nodeBorderColor(for: district),
                            lineWidth: isSelected ? 3 : 1.5
                        )
                )
                .shadow(
                    color: isCurrent ? AshfallColors.accent.opacity(0.5) : .clear,
                    radius: 8
                )

            // Threat level indicator
            if district.isUnlocked {
                VStack(spacing: 2) {
                    Image(systemName: nodeIcon(for: district))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(district.isCleared ? AshfallColors.health : AshfallColors.textPrimary)

                    Text("\(district.threatLevel)")
                        .font(AshfallFonts.caption(9))
                        .foregroundColor(threatColor(district.threatLevel))
                }
            } else {
                Image(systemName: "questionmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AshfallColors.textSecondary.opacity(0.4))
            }

            // Current location pulse
            if isCurrent {
                Circle()
                    .stroke(AshfallColors.accent.opacity(0.3), lineWidth: 2)
                    .frame(width: nodeRadius * 2.8, height: nodeRadius * 2.8)
                    .scaleEffect(isSelected ? 1.1 : 1.0)
                    .animation(
                        .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                        value: isSelected
                    )
            }

            // District name
            Text(district.name)
                .font(AshfallFonts.caption(9))
                .foregroundColor(
                    district.isUnlocked ? AshfallColors.textSecondary : AshfallColors.textSecondary.opacity(0.3)
                )
                .multilineTextAlignment(.center)
                .frame(width: 90)
                .offset(y: nodeRadius + 14)
        }
        .onTapGesture {
            guard district.isUnlocked else {
                AudioManager.shared.hapticWarning()
                return
            }
            selectedDistrict = (selectedDistrict?.id == district.id) ? nil : district
            AudioManager.shared.hapticLight()
        }
    }

    // MARK: - District Info Panel

    private func districtInfoPanel(_ district: District) -> some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(district.name)
                        .font(AshfallFonts.heading(20))
                        .foregroundColor(AshfallColors.textPrimary)

                    HStack(spacing: 12) {
                        Label("Threat: \(district.threatLevel)", systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(threatColor(district.threatLevel))

                        if district.isCleared {
                            Label("Cleared", systemImage: "checkmark.seal.fill")
                                .foregroundColor(AshfallColors.health)
                        }
                    }
                    .font(AshfallFonts.caption())
                }

                Spacer()

                Button(action: { selectedDistrict = nil }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(AshfallColors.textSecondary)
                }
            }

            Text(district.description)
                .font(AshfallFonts.body(14))
                .foregroundColor(AshfallColors.textSecondary)

            // Rewards preview
            if !district.rewards.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Potential Rewards")
                        .font(AshfallFonts.caption())
                        .foregroundColor(AshfallColors.textSecondary)

                    HStack(spacing: 16) {
                        ForEach(Array(district.rewards.keys.sorted()), id: \.self) { key in
                            if let amount = district.rewards[key] {
                                HStack(spacing: 4) {
                                    Image(systemName: resourceIcon(key))
                                        .foregroundColor(resourceColor(key))
                                        .font(.system(size: 12))
                                    Text("\(amount)")
                                        .font(AshfallFonts.mono(13))
                                        .foregroundColor(AshfallColors.textPrimary)
                                }
                            }
                        }
                    }
                }
            }

            // Deploy button
            if !district.isCleared {
                Button(action: {
                    gameState.currentDistrict = district.id
                    gameState.enterCombat()
                    AudioManager.shared.hapticMedium()
                }) {
                    HStack {
                        Image(systemName: "figure.walk")
                        Text("Launch Mission")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(16)
        .ashfallPanel()
        .padding(.horizontal, AshfallTheme.screenPadding)
        .padding(.bottom, 16)
    }

    // MARK: - Gestures

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                mapOffset = value.translation
            }
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                mapScale = min(max(value, 0.6), 2.0)
            }
    }

    // MARK: - Helpers

    private func nodePosition(for district: District) -> CGPoint {
        CGPoint(
            x: CGFloat(district.gridX) * nodeSpacing + 50,
            y: CGFloat(district.gridY) * nodeSpacing + 50
        )
    }

    private func nodeColor(for district: District) -> Color {
        if !district.isUnlocked { return AshfallColors.fog }
        if district.isCleared { return AshfallColors.health.opacity(0.2) }
        if district.id == gameState.currentDistrict { return AshfallColors.accent.opacity(0.3) }
        return AshfallColors.surface
    }

    private func nodeBorderColor(for district: District) -> Color {
        if !district.isUnlocked { return AshfallColors.fog.opacity(0.3) }
        if district.isCleared { return AshfallColors.health.opacity(0.5) }
        return AshfallColors.surfaceLight
    }

    private func nodeIcon(for district: District) -> String {
        if district.isCleared { return "checkmark" }
        if district.id == gameState.currentDistrict { return "house.fill" }
        return "mappin.circle.fill"
    }

    private func threatColor(_ level: Int) -> Color {
        switch level {
        case 1...2: return AshfallColors.health
        case 3...4: return AshfallColors.gold
        case 5...6: return AshfallColors.accent
        case 7...8: return AshfallColors.ember
        default:    return AshfallColors.danger
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
