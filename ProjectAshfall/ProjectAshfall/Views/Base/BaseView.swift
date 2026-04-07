// BaseView.swift
// ProjectAshfall
//
// Isometric base management view. Embeds a SpriteKit scene for the
// grid-rendered base with tappable buildings and animated survivors,
// overlaid with SwiftUI resource bars and building info panels.

import SwiftUI
import SpriteKit

// MARK: - Base View

struct BaseView: View {
    @EnvironmentObject var gameState: GameStateManager

    @State private var selectedBuilding: Building?
    @State private var showBuildMenu = false
    @State private var showUpgradeConfirm = false

    var body: some View {
        ZStack(alignment: .top) {
            // SpriteKit isometric scene
            SpriteView(scene: makeBaseScene())
                .ignoresSafeArea()

            // Top resource bar
            ResourceBarView()
                .environmentObject(gameState)
                .padding(.top, 4)

            // Bottom controls
            VStack {
                Spacer()

                if let building = selectedBuilding {
                    buildingInfoPanel(building)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                bottomToolbar
                    .padding(.bottom, 8)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: selectedBuilding?.id)
    }

    // MARK: - SpriteKit Scene

    private func makeBaseScene() -> BaseScene {
        let scene = BaseScene(size: CGSize(width: 800, height: 1200))
        scene.scaleMode = .aspectFill
        scene.buildings = gameState.base.buildings
        scene.survivorCount = gameState.base.survivorCount
        scene.onBuildingTapped = { buildingId in
            selectedBuilding = gameState.base.buildings.first(where: { $0.id == buildingId })
            AudioManager.shared.hapticLight()
        }
        return scene
    }

    // MARK: - Building Info Panel

    private func buildingInfoPanel(_ building: Building) -> some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(building.name)
                        .font(AshfallFonts.heading(18))
                        .foregroundColor(AshfallColors.textPrimary)

                    HStack(spacing: 6) {
                        Text(building.type.rawValue.capitalized)
                            .font(AshfallFonts.caption())
                            .foregroundColor(AshfallColors.accent)

                        Text("Level \(building.level)")
                            .font(AshfallFonts.caption())
                            .foregroundColor(AshfallColors.textSecondary)
                    }
                }

                Spacer()

                Button(action: { selectedBuilding = nil }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(AshfallColors.textSecondary)
                }
            }

            // Upgrade cost
            if !building.upgradeCost.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Upgrade Cost")
                        .font(AshfallFonts.caption())
                        .foregroundColor(AshfallColors.textSecondary)

                    HStack(spacing: 12) {
                        ForEach(Array(building.upgradeCost.keys.sorted()), id: \.self) { key in
                            if let amount = building.upgradeCost[key] {
                                HStack(spacing: 4) {
                                    resourceIcon(for: key)
                                    Text("\(amount)")
                                        .font(AshfallFonts.mono())
                                        .foregroundColor(
                                            gameState.economy.canAfford([key: amount])
                                                ? AshfallColors.textPrimary
                                                : AshfallColors.danger
                                        )
                                }
                            }
                        }
                    }
                }
            }

            HStack(spacing: 12) {
                Button(action: {
                    guard gameState.economy.canAfford(building.upgradeCost) else {
                        AudioManager.shared.hapticError()
                        return
                    }
                    gameState.economy.spend(building.upgradeCost)
                    gameState.base.upgradeBuilding(building.id)
                    selectedBuilding = gameState.base.buildings.first(where: { $0.id == building.id })
                    AudioManager.shared.hapticSuccess()
                    AudioManager.shared.playSFX(named: "build_complete", category: .ui)
                }) {
                    HStack {
                        Image(systemName: "arrow.up.circle.fill")
                        Text("Upgrade")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .opacity(gameState.economy.canAfford(building.upgradeCost) ? 1.0 : 0.5)

                Button(action: { selectedBuilding = nil }) {
                    Text("Close")
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .padding(16)
        .ashfallPanel()
        .padding(.horizontal, AshfallTheme.screenPadding)
    }

    // MARK: - Bottom Toolbar

    private var bottomToolbar: some View {
        HStack(spacing: 16) {
            toolbarButton(icon: "map.fill", label: "Map") {
                gameState.openWorldMap()
            }
            toolbarButton(icon: "person.3.fill", label: "Heroes") {
                // handled by navigation — placeholder
            }
            toolbarButton(icon: "hammer.fill", label: "Build") {
                showBuildMenu = true
            }
            toolbarButton(icon: "shield.fill", label: "Squad") {
                // handled by navigation — placeholder
            }
            toolbarButton(icon: "rectangle.portrait.and.arrow.right", label: "Menu") {
                gameState.returnToMainMenu()
            }
        }
        .padding(.horizontal, AshfallTheme.screenPadding)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AshfallColors.surface.opacity(0.95))
                .shadow(color: .black.opacity(0.5), radius: 8, y: -2)
        )
        .padding(.horizontal, AshfallTheme.screenPadding)
    }

    private func toolbarButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            AudioManager.shared.hapticLight()
            action()
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(label)
                    .font(AshfallFonts.caption(10))
            }
            .foregroundColor(AshfallColors.textSecondary)
            .frame(maxWidth: .infinity)
        }
    }

    private func resourceIcon(for key: String) -> some View {
        let (icon, color): (String, Color) = {
            switch key {
            case "food":        return ("leaf.fill", AshfallColors.food)
            case "water":       return ("drop.fill", AshfallColors.water)
            case "fuel":        return ("fuelpump.fill", AshfallColors.fuel)
            case "scrap":       return ("gearshape.fill", AshfallColors.scrap)
            case "electronics": return ("cpu", AshfallColors.electronics)
            case "medicine":    return ("cross.case.fill", AshfallColors.medicine)
            default:            return ("questionmark", AshfallColors.textSecondary)
            }
        }()

        return Image(systemName: icon)
            .font(.system(size: 12))
            .foregroundColor(color)
    }
}

// MARK: - Base SpriteKit Scene

final class BaseScene: SKScene {
    var buildings: [Building] = []
    var survivorCount: Int = 0
    var onBuildingTapped: ((String) -> Void)?

    // Isometric conversion constants
    private let tileWidth: CGFloat = 80
    private let tileHeight: CGFloat = 40
    private let gridSize = 7

    override func didMove(to view: SKView) {
        backgroundColor = UIColor(AshfallColors.background)
        anchorPoint = CGPoint(x: 0.5, y: 0.4)

        drawGrid()
        placeBuildings()
        spawnSurvivorWalkers()
        addAmbientEffects()
    }

    // MARK: Grid

    private func drawGrid() {
        for row in 0..<gridSize {
            for col in 0..<gridSize {
                let pos = isoPosition(col: col, row: row)
                let tile = createIsometricTile(at: pos, col: col, row: row)
                addChild(tile)
            }
        }
    }

    private func createIsometricTile(at position: CGPoint, col: Int, row: Int) -> SKShapeNode {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: tileHeight / 2))
        path.addLine(to: CGPoint(x: tileWidth / 2, y: 0))
        path.addLine(to: CGPoint(x: 0, y: -tileHeight / 2))
        path.addLine(to: CGPoint(x: -tileWidth / 2, y: 0))
        path.closeSubpath()

        let node = SKShapeNode(path: path)
        node.position = position
        node.fillColor = UIColor(red: 0.12, green: 0.11, blue: 0.09, alpha: 1)
        node.strokeColor = UIColor(red: 0.22, green: 0.20, blue: 0.18, alpha: 0.5)
        node.lineWidth = 0.5
        node.name = "tile_\(col)_\(row)"
        return node
    }

    private func isoPosition(col: Int, row: Int) -> CGPoint {
        let offsetCol = col - gridSize / 2
        let offsetRow = row - gridSize / 2
        let x = CGFloat(offsetCol - offsetRow) * (tileWidth / 2)
        let y = CGFloat(offsetCol + offsetRow) * (tileHeight / 2) * -1
        return CGPoint(x: x, y: y)
    }

    // MARK: Buildings

    private func placeBuildings() {
        for building in buildings {
            let pos = isoPosition(col: building.gridX, row: building.gridY)
            let node = createBuildingNode(building: building, at: pos)
            addChild(node)
        }
    }

    private func createBuildingNode(building: Building, at position: CGPoint) -> SKNode {
        let container = SKNode()
        container.position = position
        container.name = "building_\(building.id)"

        // Building body — simple isometric block
        let buildingHeight: CGFloat = CGFloat(20 + building.level * 8)
        let bodyPath = CGMutablePath()
        bodyPath.move(to: CGPoint(x: 0, y: tileHeight / 2 + buildingHeight))
        bodyPath.addLine(to: CGPoint(x: tileWidth / 2 - 8, y: buildingHeight))
        bodyPath.addLine(to: CGPoint(x: tileWidth / 2 - 8, y: 0))
        bodyPath.addLine(to: CGPoint(x: 0, y: -tileHeight / 2 + 4))
        bodyPath.addLine(to: CGPoint(x: -tileWidth / 2 + 8, y: 0))
        bodyPath.addLine(to: CGPoint(x: -tileWidth / 2 + 8, y: buildingHeight))
        bodyPath.closeSubpath()

        let body = SKShapeNode(path: bodyPath)
        body.fillColor = buildingColor(for: building.type)
        body.strokeColor = UIColor(white: 0.3, alpha: 0.6)
        body.lineWidth = 1
        container.addChild(body)

        // Label
        let label = SKLabelNode(text: building.name)
        label.fontName = "Helvetica-Bold"
        label.fontSize = 9
        label.fontColor = .white
        label.position = CGPoint(x: 0, y: tileHeight / 2 + buildingHeight + 6)
        label.horizontalAlignmentMode = .center
        container.addChild(label)

        // Level badge
        let levelLabel = SKLabelNode(text: "Lv.\(building.level)")
        levelLabel.fontName = "Helvetica"
        levelLabel.fontSize = 8
        levelLabel.fontColor = UIColor(AshfallColors.accent)
        levelLabel.position = CGPoint(x: 0, y: tileHeight / 2 + buildingHeight + 18)
        levelLabel.horizontalAlignmentMode = .center
        container.addChild(levelLabel)

        return container
    }

    private func buildingColor(for type: Building.BuildingType) -> UIColor {
        switch type {
        case .shelter:    return UIColor(red: 0.35, green: 0.28, blue: 0.20, alpha: 1)
        case .workshop:   return UIColor(red: 0.40, green: 0.35, blue: 0.25, alpha: 1)
        case .farm:       return UIColor(red: 0.25, green: 0.40, blue: 0.20, alpha: 1)
        case .waterPump:  return UIColor(red: 0.20, green: 0.35, blue: 0.50, alpha: 1)
        case .armory:     return UIColor(red: 0.45, green: 0.25, blue: 0.20, alpha: 1)
        case .medBay:     return UIColor(red: 0.50, green: 0.25, blue: 0.30, alpha: 1)
        case .watchtower: return UIColor(red: 0.30, green: 0.30, blue: 0.30, alpha: 1)
        case .generator:  return UIColor(red: 0.45, green: 0.40, blue: 0.15, alpha: 1)
        case .storage:    return UIColor(red: 0.30, green: 0.28, blue: 0.25, alpha: 1)
        }
    }

    // MARK: Survivors

    private func spawnSurvivorWalkers() {
        let count = min(survivorCount, 6)
        for i in 0..<count {
            let survivor = SKShapeNode(circleOfRadius: 3)
            survivor.fillColor = UIColor(red: 0.8, green: 0.7, blue: 0.5, alpha: 0.8)
            survivor.strokeColor = .clear
            survivor.name = "survivor_\(i)"
            survivor.zPosition = 10

            let startCol = Int.random(in: 0..<gridSize)
            let startRow = Int.random(in: 0..<gridSize)
            survivor.position = isoPosition(col: startCol, row: startRow)
            addChild(survivor)

            animateSurvivorWalk(survivor)
        }
    }

    private func animateSurvivorWalk(_ node: SKShapeNode) {
        let targetCol = Int.random(in: 0..<gridSize)
        let targetRow = Int.random(in: 0..<gridSize)
        let target = isoPosition(col: targetCol, row: targetRow)
        let duration = TimeInterval.random(in: 3.0...7.0)

        let move = SKAction.move(to: target, duration: duration)
        move.timingMode = .easeInEaseOut
        let pause = SKAction.wait(forDuration: TimeInterval.random(in: 1.0...3.0))

        node.run(SKAction.sequence([move, pause])) { [weak self] in
            self?.animateSurvivorWalk(node)
        }
    }

    // MARK: Ambient Effects

    private func addAmbientEffects() {
        // Subtle smoke from certain buildings
        for building in buildings where building.type == .generator || building.type == .workshop {
            let pos = isoPosition(col: building.gridX, row: building.gridY)
            let smoke = SKEmitterNode()
            smoke.particleBirthRate = 1
            smoke.particleLifetime = 4
            smoke.particlePositionRange = CGVector(dx: 5, dy: 2)
            smoke.position = CGPoint(x: pos.x, y: pos.y + 40)
            smoke.particleSpeed = 8
            smoke.emissionAngle = .pi / 2
            smoke.emissionAngleRange = 0.3
            smoke.particleAlpha = 0.15
            smoke.particleAlphaSpeed = -0.03
            smoke.particleScale = 0.03
            smoke.particleScaleSpeed = 0.01
            smoke.particleColor = .gray
            smoke.particleColorBlendFactor = 1.0
            smoke.particleTexture = SKTexture(imageNamed: "spark")
            smoke.zPosition = 20
            addChild(smoke)
        }
    }

    // MARK: Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        // Find the closest building to the tap
        var closestBuilding: Building?
        var closestDistance: CGFloat = 50 // max tap distance

        for building in buildings {
            let pos = isoPosition(col: building.gridX, row: building.gridY)
            let dist = hypot(location.x - pos.x, location.y - pos.y)
            if dist < closestDistance {
                closestDistance = dist
                closestBuilding = building
            }
        }

        if let building = closestBuilding {
            onBuildingTapped?(building.id)
        }
    }
}
