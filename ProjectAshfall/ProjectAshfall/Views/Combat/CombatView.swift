// CombatView.swift
// ProjectAshfall
//
// Tactical combat screen with a SpriteKit battlefield, hero portraits
// with health bars, skill buttons, floating damage numbers, and
// victory/defeat overlays.

import SwiftUI
import SpriteKit

// MARK: - Combat View

struct CombatView: View {
    @EnvironmentObject var gameState: GameStateManager

    @State private var selectedHeroIndex: Int = 0
    @State private var isAutoBattle = false
    @State private var isPaused = false
    @State private var combatResult: CombatResult?
    @State private var combatScene = CombatScene(size: CGSize(width: 800, height: 600))

    private var activeHeroes: [Hero] {
        gameState.heroes.filter { gameState.activeSquad.contains($0.id) }
    }

    private var selectedHero: Hero? {
        guard selectedHeroIndex < activeHeroes.count else { return nil }
        return activeHeroes[selectedHeroIndex]
    }

    var body: some View {
        ZStack {
            // Battlefield
            SpriteView(scene: combatScene)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar: enemy info + controls
                topBar

                Spacer()

                // Hero portraits row
                heroPortraitRow
                    .padding(.bottom, 6)

                // Skill bar
                if let hero = selectedHero {
                    skillBar(for: hero)
                        .padding(.bottom, 8)
                }
            }

            // Victory / Defeat overlay
            if let result = combatResult {
                combatResultOverlay(result)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: combatResult != nil)
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            // Pause
            Button(action: {
                isPaused.toggle()
                combatScene.isPaused = isPaused
                AudioManager.shared.hapticLight()
            }) {
                Image(systemName: isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: 18, weight: .bold))
            }
            .buttonStyle(IconButtonStyle())

            Spacer()

            // Wave indicator
            VStack(spacing: 2) {
                Text("WAVE 1/3")
                    .font(AshfallFonts.caption(11))
                    .foregroundColor(AshfallColors.textSecondary)
                Text("Industrial Sector")
                    .font(AshfallFonts.caption(10))
                    .foregroundColor(AshfallColors.textSecondary.opacity(0.6))
            }

            Spacer()

            // Auto-battle toggle
            Button(action: {
                isAutoBattle.toggle()
                AudioManager.shared.hapticLight()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 12))
                    Text("AUTO")
                        .font(AshfallFonts.caption(11))
                }
                .foregroundColor(isAutoBattle ? AshfallColors.accent : AshfallColors.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isAutoBattle ? AshfallColors.accent.opacity(0.2) : AshfallColors.surface)
                )
                .overlay(
                    Capsule()
                        .stroke(isAutoBattle ? AshfallColors.accent.opacity(0.6) : Color.clear, lineWidth: 1)
                )
            }
        }
        .padding(.horizontal, AshfallTheme.screenPadding)
        .padding(.top, 8)
    }

    // MARK: - Hero Portraits

    private var heroPortraitRow: some View {
        HStack(spacing: 10) {
            ForEach(Array(activeHeroes.enumerated()), id: \.element.id) { index, hero in
                heroPortraitCard(hero: hero, index: index)
                    .onTapGesture {
                        selectedHeroIndex = index
                        AudioManager.shared.hapticSelection()
                    }
            }
        }
        .padding(.horizontal, AshfallTheme.screenPadding)
    }

    private func heroPortraitCard(hero: Hero, index: Int) -> some View {
        let isSelected = index == selectedHeroIndex
        let healthPercent = Double(hero.maxHP) > 0
            ? min(1.0, max(0.0, Double(hero.maxHP) / Double(hero.maxHP)))
            : 1.0

        return VStack(spacing: 4) {
            // Portrait
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(AshfallColors.surface)
                    .frame(width: 56, height: 64)

                // Role icon as placeholder portrait
                Image(systemName: hero.role.icon)
                    .font(.system(size: 22))
                    .foregroundColor(AshfallColors.textPrimary)
                    .frame(width: 56, height: 50)

                // Health bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.black.opacity(0.6))
                            .frame(height: 6)

                        Rectangle()
                            .fill(healthBarColor(healthPercent))
                            .frame(width: geo.size.width * healthPercent, height: 6)
                    }
                }
                .frame(height: 6)
                .clipShape(RoundedRectangle(cornerRadius: 2))
            }
            .frame(width: 56, height: 64)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isSelected ? AshfallColors.accent : Color.clear,
                        lineWidth: 2
                    )
            )

            Text(hero.name.split(separator: " ").first.map(String.init) ?? hero.name)
                .font(AshfallFonts.caption(9))
                .foregroundColor(isSelected ? AshfallColors.textPrimary : AshfallColors.textSecondary)
                .lineLimit(1)
        }
    }

    private func healthBarColor(_ percent: Double) -> Color {
        if percent > 0.6 { return AshfallColors.health }
        if percent > 0.3 { return AshfallColors.gold }
        return AshfallColors.danger
    }

    // MARK: - Skill Bar

    private func skillBar(for hero: Hero) -> some View {
        HStack(spacing: 10) {
            // Basic attack
            skillButton(
                name: "Attack",
                icon: "burst.fill",
                cooldown: 0,
                action: {
                    combatScene.executeSkill(heroId: hero.id, skillIndex: -1)
                    AudioManager.shared.hapticMedium()
                }
            )

            // Hero skills
            ForEach(Array(hero.skills.enumerated()), id: \.element.id) { index, skill in
                skillButton(
                    name: skill.name,
                    icon: skillIcon(for: skill.name),
                    cooldown: 0,
                    isLocked: !skill.unlocked,
                    action: {
                        guard skill.unlocked else {
                            AudioManager.shared.hapticWarning()
                            return
                        }
                        combatScene.executeSkill(heroId: hero.id, skillIndex: index)
                        AudioManager.shared.hapticMedium()
                    }
                )
            }

            Spacer()
        }
        .padding(.horizontal, AshfallTheme.screenPadding)
    }

    private func skillButton(
        name: String,
        icon: String,
        cooldown: Int,
        isLocked: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isLocked ? AshfallColors.surface.opacity(0.5) : AshfallColors.surface)
                        .frame(width: 48, height: 48)

                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(isLocked ? AshfallColors.textSecondary.opacity(0.3) : AshfallColors.accent)

                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10))
                            .foregroundColor(AshfallColors.textSecondary)
                            .offset(x: 14, y: 14)
                    }

                    if cooldown > 0 {
                        Text("\(cooldown)")
                            .font(AshfallFonts.mono(14))
                            .foregroundColor(.white)
                            .background(
                                Circle()
                                    .fill(Color.black.opacity(0.7))
                                    .frame(width: 22, height: 22)
                            )
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(AshfallColors.surfaceLight.opacity(0.4), lineWidth: 0.5)
                )

                Text(name)
                    .font(AshfallFonts.caption(8))
                    .foregroundColor(AshfallColors.textSecondary)
                    .lineLimit(1)
            }
        }
        .disabled(isLocked)
    }

    private func skillIcon(for skillName: String) -> String {
        switch skillName.lowercased() {
        case let n where n.contains("shield") || n.contains("wall"):   return "shield.lefthalf.filled"
        case let n where n.contains("heal") || n.contains("mend"):     return "cross.fill"
        case let n where n.contains("shot") || n.contains("snipe"):    return "scope"
        case let n where n.contains("rally") || n.contains("boost"):   return "speaker.wave.3.fill"
        case let n where n.contains("turret") || n.contains("deploy"): return "target"
        case let n where n.contains("ambush") || n.contains("stealth"):return "eye.slash.fill"
        case let n where n.contains("recon") || n.contains("scan"):    return "binoculars.fill"
        case let n where n.contains("repair") || n.contains("fix"):    return "wrench.fill"
        case let n where n.contains("overwatch"):                      return "eye.fill"
        case let n where n.contains("triage"):                         return "heart.fill"
        default: return "sparkle"
        }
    }

    // MARK: - Combat Result Overlay

    private func combatResultOverlay(_ result: CombatResult) -> some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()

            VStack(spacing: 24) {
                Text(result == .victory ? "VICTORY" : "DEFEAT")
                    .font(.system(size: 48, weight: .black, design: .serif))
                    .foregroundColor(result == .victory ? AshfallColors.gold : AshfallColors.danger)
                    .shadow(color: (result == .victory ? AshfallColors.gold : AshfallColors.danger).opacity(0.5),
                            radius: 16)

                if result == .victory {
                    VStack(spacing: 8) {
                        Text("Rewards")
                            .font(AshfallFonts.heading())
                            .foregroundColor(AshfallColors.textPrimary)

                        HStack(spacing: 20) {
                            rewardItem(icon: "gearshape.fill", color: AshfallColors.scrap, amount: 50)
                            rewardItem(icon: "leaf.fill", color: AshfallColors.food, amount: 20)
                            rewardItem(icon: "star.fill", color: AshfallColors.gold, amount: 100)
                        }
                    }
                    .padding()
                    .ashfallCard()
                }

                Button(action: {
                    gameState.exitCombat(victory: result == .victory)
                }) {
                    Text(result == .victory ? "Collect & Return" : "Return to Base")
                }
                .buttonStyle(PrimaryButtonStyle(isDestructive: result == .defeat))
            }
        }
    }

    private func rewardItem(icon: String, color: Color, amount: Int) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
            Text("+\(amount)")
                .font(AshfallFonts.mono(14))
                .foregroundColor(AshfallColors.textPrimary)
        }
    }
}

// MARK: - Combat Result

enum CombatResult {
    case victory
    case defeat
}

// MARK: - Combat SpriteKit Scene

final class CombatScene: SKScene {
    private var heroNodes: [String: SKNode] = [:]
    private var enemyNodes: [SKNode] = []
    private var damageNumberCounter = 0

    override func didMove(to view: SKView) {
        backgroundColor = UIColor(red: 0.06, green: 0.05, blue: 0.04, alpha: 1)
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        scaleMode = .aspectFill

        setupBattlefield()
        spawnEnemies()
        spawnHeroes()
    }

    // MARK: Setup

    private func setupBattlefield() {
        // Ground
        let ground = SKShapeNode(rectOf: CGSize(width: size.width, height: size.height * 0.6))
        ground.fillColor = UIColor(red: 0.10, green: 0.09, blue: 0.07, alpha: 1)
        ground.strokeColor = .clear
        ground.position = CGPoint(x: 0, y: -size.height * 0.05)
        ground.zPosition = -1
        addChild(ground)

        // Grid lines for tactical feel
        for i in stride(from: -size.width / 2, through: size.width / 2, by: 60) {
            let line = SKShapeNode(rectOf: CGSize(width: 0.5, height: size.height * 0.5))
            line.fillColor = UIColor(white: 0.15, alpha: 0.3)
            line.strokeColor = .clear
            line.position = CGPoint(x: i, y: 0)
            line.zPosition = 0
            addChild(line)
        }
    }

    private func spawnHeroes() {
        let positions: [CGPoint] = [
            CGPoint(x: -200, y: -120),
            CGPoint(x: -120, y: -160),
            CGPoint(x: -280, y: -80),
            CGPoint(x: -160, y: -40),
            CGPoint(x: -240, y: -200),
        ]

        let colors: [UIColor] = [
            UIColor(red: 0.3, green: 0.5, blue: 0.9, alpha: 1),
            UIColor(red: 0.9, green: 0.4, blue: 0.2, alpha: 1),
            UIColor(red: 0.3, green: 0.8, blue: 0.4, alpha: 1),
            UIColor(red: 0.7, green: 0.5, blue: 0.2, alpha: 1),
            UIColor(red: 0.5, green: 0.3, blue: 0.7, alpha: 1),
        ]

        for i in 0..<min(positions.count, 5) {
            let node = createCombatUnit(color: colors[i], position: positions[i], isHero: true)
            node.name = "hero_\(i)"
            addChild(node)
            heroNodes["hero_\(i)"] = node

            // Idle animation
            let breathe = SKAction.sequence([
                SKAction.moveBy(x: 0, y: 3, duration: 1.0),
                SKAction.moveBy(x: 0, y: -3, duration: 1.0)
            ])
            node.run(SKAction.repeatForever(breathe))
        }
    }

    private func spawnEnemies() {
        let positions: [CGPoint] = [
            CGPoint(x: 160, y: -60),
            CGPoint(x: 240, y: -120),
            CGPoint(x: 200, y: -180),
            CGPoint(x: 280, y: -30),
        ]

        for i in 0..<positions.count {
            let node = createCombatUnit(
                color: UIColor(red: 0.7, green: 0.2, blue: 0.15, alpha: 1),
                position: positions[i],
                isHero: false
            )
            node.name = "enemy_\(i)"
            addChild(node)
            enemyNodes.append(node)

            // Menacing sway
            let sway = SKAction.sequence([
                SKAction.moveBy(x: 4, y: 0, duration: 0.8),
                SKAction.moveBy(x: -4, y: 0, duration: 0.8)
            ])
            node.run(SKAction.repeatForever(sway))

            // Enemy health bar
            addHealthBar(to: node, width: 40, yOffset: 28)
        }
    }

    private func createCombatUnit(color: UIColor, position: CGPoint, isHero: Bool) -> SKNode {
        let container = SKNode()
        container.position = position
        container.zPosition = 10

        // Body
        let body = SKShapeNode(rectOf: CGSize(width: 24, height: 32), cornerRadius: 4)
        body.fillColor = color
        body.strokeColor = color.withAlphaComponent(0.6)
        body.lineWidth = 1
        container.addChild(body)

        // Head
        let head = SKShapeNode(circleOfRadius: 8)
        head.fillColor = color.lighter(by: 0.15)
        head.strokeColor = .clear
        head.position = CGPoint(x: 0, y: 22)
        container.addChild(head)

        return container
    }

    private func addHealthBar(to node: SKNode, width: CGFloat, yOffset: CGFloat) {
        let bg = SKShapeNode(rectOf: CGSize(width: width, height: 5), cornerRadius: 2)
        bg.fillColor = UIColor(white: 0.15, alpha: 0.8)
        bg.strokeColor = .clear
        bg.position = CGPoint(x: 0, y: yOffset)
        bg.name = "healthbar_bg"
        node.addChild(bg)

        let fill = SKShapeNode(rectOf: CGSize(width: width - 2, height: 3), cornerRadius: 1)
        fill.fillColor = UIColor(red: 0.8, green: 0.2, blue: 0.15, alpha: 1)
        fill.strokeColor = .clear
        fill.position = CGPoint(x: 0, y: yOffset)
        fill.name = "healthbar_fill"
        node.addChild(fill)
    }

    // MARK: Skill Execution

    func executeSkill(heroId: String, skillIndex: Int) {
        guard let targetEnemy = enemyNodes.randomElement() else { return }

        // Flash the attacker
        let heroNode = heroNodes.values.first ?? SKNode()

        let flash = SKAction.sequence([
            SKAction.colorize(with: .white, colorBlendFactor: 0.8, duration: 0.05),
            SKAction.colorize(with: .white, colorBlendFactor: 0.0, duration: 0.15)
        ])
        heroNode.children.forEach { $0.run(flash) }

        // Projectile
        let projectile = SKShapeNode(circleOfRadius: 4)
        projectile.fillColor = UIColor(red: 1.0, green: 0.7, blue: 0.2, alpha: 1)
        projectile.strokeColor = .clear
        projectile.position = heroNode.position
        projectile.zPosition = 15
        addChild(projectile)

        let flyToEnemy = SKAction.move(to: targetEnemy.position, duration: 0.25)
        flyToEnemy.timingMode = .easeIn
        projectile.run(SKAction.sequence([flyToEnemy, SKAction.removeFromParent()])) { [weak self] in
            self?.showDamageNumber(at: targetEnemy.position, damage: Int.random(in: 20...80))
            self?.shakeNode(targetEnemy)
        }
    }

    private func showDamageNumber(at position: CGPoint, damage: Int) {
        damageNumberCounter += 1
        let label = SKLabelNode(text: "-\(damage)")
        label.fontName = "Helvetica-Bold"
        label.fontSize = 18
        label.fontColor = UIColor(red: 1.0, green: 0.3, blue: 0.2, alpha: 1)
        label.position = CGPoint(x: position.x + CGFloat.random(in: -10...10), y: position.y + 30)
        label.zPosition = 100
        addChild(label)

        let rise = SKAction.moveBy(x: 0, y: 40, duration: 0.8)
        let fade = SKAction.fadeOut(withDuration: 0.6)
        let scale = SKAction.scale(to: 1.3, duration: 0.15)
        let shrink = SKAction.scale(to: 0.8, duration: 0.65)

        label.run(SKAction.sequence([
            SKAction.group([scale, SKAction.wait(forDuration: 0.15)]),
            SKAction.group([rise, fade, shrink]),
            SKAction.removeFromParent()
        ]))
    }

    private func shakeNode(_ node: SKNode) {
        let shake = SKAction.sequence([
            SKAction.moveBy(x: 5, y: 0, duration: 0.03),
            SKAction.moveBy(x: -10, y: 0, duration: 0.03),
            SKAction.moveBy(x: 8, y: 0, duration: 0.03),
            SKAction.moveBy(x: -3, y: 0, duration: 0.03),
        ])
        node.run(shake)
    }
}

// MARK: - UIColor Extension

private extension UIColor {
    func lighter(by percentage: CGFloat) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return UIColor(
            red: min(r + percentage, 1.0),
            green: min(g + percentage, 1.0),
            blue: min(b + percentage, 1.0),
            alpha: a
        )
    }
}
