import Foundation
import SwiftUI
import SpriteKit

// MARK: - CGPoint Extensions

extension CGPoint {
    /// Convert screen coordinates to isometric grid position
    func toIsoGrid(tileWidth: CGFloat = GameConstants.isoTileWidth,
                   tileHeight: CGFloat = GameConstants.isoTileHeight) -> (col: Int, row: Int) {
        let col = Int((x / (tileWidth / 2) + y / (tileHeight / 2)) / 2)
        let row = Int((y / (tileHeight / 2) - x / (tileWidth / 2)) / 2)
        return (col, row)
    }

    /// Convert isometric grid position to screen coordinates
    static func fromIsoGrid(col: Int, row: Int,
                            tileWidth: CGFloat = GameConstants.isoTileWidth,
                            tileHeight: CGFloat = GameConstants.isoTileHeight) -> CGPoint {
        let x = CGFloat(col - row) * (tileWidth / 2)
        let y = CGFloat(col + row) * (tileHeight / 2)
        return CGPoint(x: x, y: y)
    }

    /// Distance to another point
    func distance(to other: CGPoint) -> CGFloat {
        let dx = x - other.x
        let dy = y - other.y
        return sqrt(dx * dx + dy * dy)
    }

    /// Manhattan distance for grid-based pathfinding
    func manhattanDistance(to other: CGPoint) -> CGFloat {
        return abs(x - other.x) + abs(y - other.y)
    }
}

// MARK: - Double Extensions

extension Double {
    /// Format as percentage string
    var percentString: String {
        return String(format: "%.0f%%", self * 100)
    }

    /// Clamp value between min and max
    func clamped(to range: ClosedRange<Double>) -> Double {
        return min(max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - Int Extensions

extension Int {
    /// Format large numbers with K/M suffixes
    var abbreviated: String {
        if self >= 1_000_000 {
            return String(format: "%.1fM", Double(self) / 1_000_000)
        } else if self >= 1_000 {
            return String(format: "%.1fK", Double(self) / 1_000)
        }
        return "\(self)"
    }
}

// MARK: - Array Extensions

extension Array {
    /// Safely access array element by index
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Color Extensions

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - View Extensions

extension View {
    /// Apply post-apocalyptic card styling
    func ashfallCard() -> some View {
        self
            .padding()
            .background(Color(hex: "1A1A2E").opacity(0.9))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(hex: "E94560").opacity(0.3), lineWidth: 1)
            )
    }

    /// Conditional modifier
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - SKNode Extensions

extension SKNode {
    /// Fade in animation
    func fadeIn(duration: TimeInterval = 0.3) {
        alpha = 0
        run(SKAction.fadeIn(withDuration: duration))
    }

    /// Fade out and remove
    func fadeOutAndRemove(duration: TimeInterval = 0.3) {
        run(SKAction.sequence([
            SKAction.fadeOut(withDuration: duration),
            SKAction.removeFromParent()
        ]))
    }

    /// Pulse animation for selection highlights
    func pulseAnimation(scale: CGFloat = 1.1, duration: TimeInterval = 0.6) {
        let scaleUp = SKAction.scale(to: scale, duration: duration / 2)
        let scaleDown = SKAction.scale(to: 1.0, duration: duration / 2)
        scaleUp.timingMode = .easeInEaseOut
        scaleDown.timingMode = .easeInEaseOut
        run(SKAction.repeatForever(SKAction.sequence([scaleUp, scaleDown])), withKey: "pulse")
    }

    /// Stop pulse animation
    func stopPulse() {
        removeAction(forKey: "pulse")
        run(SKAction.scale(to: 1.0, duration: 0.2))
    }
}

// MARK: - TimeInterval Extensions

extension TimeInterval {
    /// Format as MM:SS
    var timerString: String {
        let minutes = Int(self) / 60
        let seconds = Int(self) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    /// Format as human-readable duration
    var durationString: String {
        if self < 60 {
            return "\(Int(self))s"
        } else if self < 3600 {
            return "\(Int(self) / 60)m"
        } else {
            let hours = Int(self) / 3600
            let minutes = (Int(self) % 3600) / 60
            return "\(hours)h \(minutes)m"
        }
    }
}
