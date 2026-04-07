// DialogueView.swift
// ProjectAshfall
//
// Story dialogue overlay with character portrait, typewriter text animation,
// tap-to-advance, skip button, and branching choice buttons.

import SwiftUI

// MARK: - Dialogue Models

struct DialogueLine: Identifiable {
    let id = UUID()
    var speakerName: String
    var speakerPortraitIcon: String      // SF Symbol name as portrait placeholder
    var text: String
    var choices: [DialogueChoice]?       // nil = normal line, non-nil = choice prompt

    var isChoiceLine: Bool {
        choices != nil && !(choices?.isEmpty ?? true)
    }
}

struct DialogueChoice: Identifiable {
    let id = UUID()
    var label: String
    var nextLineIndex: Int?              // which line to jump to, nil = continue sequentially
    var storyFlag: String?               // flag to set in CampaignManager
}

// MARK: - Dialogue View

struct DialogueView: View {
    @EnvironmentObject var gameState: GameStateManager

    let lines: [DialogueLine]
    var onComplete: () -> Void

    @State private var currentLineIndex: Int = 0
    @State private var displayedText: String = ""
    @State private var isTyping: Bool = false
    @State private var typewriterTask: Task<Void, Never>?
    @State private var showSkipConfirm: Bool = false
    @State private var fadeIn: Bool = false

    private var currentLine: DialogueLine? {
        guard currentLineIndex < lines.count else { return nil }
        return lines[currentLineIndex]
    }

    private let typingSpeed: TimeInterval = 0.03

    var body: some View {
        ZStack {
            // Semi-transparent dark background
            Color.black.opacity(0.75)
                .ignoresSafeArea()
                .onTapGesture {
                    handleTap()
                }

            VStack {
                // Skip button at top-right
                HStack {
                    Spacer()
                    skipButton
                }
                .padding(.horizontal, AshfallTheme.screenPadding)
                .padding(.top, 16)

                Spacer()

                if let line = currentLine {
                    dialoguePanel(line)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .opacity(fadeIn ? 1 : 0)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                fadeIn = true
            }
            startTyping()
        }
        .onDisappear {
            typewriterTask?.cancel()
        }
    }

    // MARK: - Skip Button

    private var skipButton: some View {
        Button(action: {
            if showSkipConfirm {
                skipAll()
            } else {
                showSkipConfirm = true
                // Auto-dismiss confirmation after 2 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    showSkipConfirm = false
                }
            }
        }) {
            HStack(spacing: 4) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 11))
                Text(showSkipConfirm ? "Tap again to skip" : "Skip")
                    .font(AshfallFonts.caption(12))
            }
            .foregroundColor(AshfallColors.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(AshfallColors.surface.opacity(0.8))
            )
        }
    }

    // MARK: - Dialogue Panel

    private func dialoguePanel(_ line: DialogueLine) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                // Character portrait
                characterPortrait(line)

                VStack(alignment: .leading, spacing: 8) {
                    // Speaker name
                    Text(line.speakerName)
                        .font(AshfallFonts.heading(16))
                        .foregroundColor(AshfallColors.accent)

                    // Dialogue text with typewriter effect
                    Text(displayedText)
                        .font(AshfallFonts.body(15))
                        .foregroundColor(AshfallColors.textPrimary)
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)

                    // Advance indicator
                    if !isTyping && !line.isChoiceLine {
                        advanceIndicator
                            .transition(.opacity)
                    }
                }
            }
            .padding(18)

            // Choice buttons
            if let choices = line.choices, !isTyping {
                choiceButtons(choices)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(AshfallColors.surface.opacity(0.95))
                .shadow(color: .black.opacity(0.5), radius: 12, y: -4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AshfallColors.surfaceLight.opacity(0.4), lineWidth: 0.5)
        )
        .padding(.horizontal, AshfallTheme.screenPadding)
        .padding(.bottom, 24)
    }

    // MARK: - Character Portrait

    private func characterPortrait(_ line: DialogueLine) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [AshfallColors.accent.opacity(0.2), AshfallColors.surface],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 72, height: 82)

            Image(systemName: line.speakerPortraitIcon)
                .font(.system(size: 32))
                .foregroundColor(AshfallColors.textPrimary.opacity(0.8))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AshfallColors.accent.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Advance Indicator

    private var advanceIndicator: some View {
        HStack(spacing: 4) {
            Text("Tap to continue")
                .font(AshfallFonts.caption(11))
                .foregroundColor(AshfallColors.textDim)

            Image(systemName: "chevron.right")
                .font(.system(size: 9))
                .foregroundColor(AshfallColors.textDim)
                .modifier(PulseModifier())
        }
    }

    // MARK: - Choice Buttons

    private func choiceButtons(_ choices: [DialogueChoice]) -> some View {
        VStack(spacing: 8) {
            Rectangle()
                .fill(AshfallColors.surfaceLight.opacity(0.3))
                .frame(height: 1)

            ForEach(choices) { choice in
                Button(action: {
                    handleChoice(choice)
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "arrowtriangle.right.fill")
                            .font(.system(size: 10))
                            .foregroundColor(AshfallColors.accent)

                        Text(choice.label)
                            .font(AshfallFonts.body(14))
                            .foregroundColor(AshfallColors.textPrimary)
                            .multilineTextAlignment(.leading)

                        Spacer()
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(AshfallColors.background.opacity(0.5))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(AshfallColors.accent.opacity(0.2), lineWidth: 0.5)
                    )
                }
                .padding(.horizontal, 14)
            }
            .padding(.bottom, 12)
        }
    }

    // MARK: - Typewriter Logic

    private func startTyping() {
        guard let line = currentLine else {
            onComplete()
            return
        }

        displayedText = ""
        isTyping = true

        typewriterTask?.cancel()
        typewriterTask = Task { @MainActor in
            for character in line.text {
                guard !Task.isCancelled else { return }
                displayedText.append(character)
                try? await Task.sleep(nanoseconds: UInt64(typingSpeed * 1_000_000_000))
            }
            isTyping = false
        }
    }

    private func completeCurrentLine() {
        typewriterTask?.cancel()
        if let line = currentLine {
            displayedText = line.text
        }
        isTyping = false
    }

    // MARK: - Interaction

    private func handleTap() {
        if isTyping {
            // Complete the current line instantly
            completeCurrentLine()
        } else if let line = currentLine, line.isChoiceLine {
            // Do nothing -- wait for choice button press
        } else {
            advanceToNextLine()
        }
    }

    private func advanceToNextLine() {
        AudioManager.shared.hapticLight()

        let nextIndex = currentLineIndex + 1
        if nextIndex >= lines.count {
            withAnimation(.easeOut(duration: 0.3)) {
                fadeIn = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                onComplete()
            }
        } else {
            currentLineIndex = nextIndex
            startTyping()
        }
    }

    private func handleChoice(_ choice: DialogueChoice) {
        AudioManager.shared.hapticSelection()

        // Set story flag if present
        if let flag = choice.storyFlag {
            gameState.campaign.storyFlags[flag] = true
        }

        if let jumpIndex = choice.nextLineIndex, jumpIndex < lines.count {
            currentLineIndex = jumpIndex
            startTyping()
        } else {
            advanceToNextLine()
        }
    }

    private func skipAll() {
        AudioManager.shared.hapticLight()
        typewriterTask?.cancel()

        withAnimation(.easeOut(duration: 0.3)) {
            fadeIn = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            onComplete()
        }
    }
}

// MARK: - Pulse Animation Modifier

private struct PulseModifier: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .opacity(isPulsing ? 0.4 : 1.0)
            .animation(
                .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear { isPulsing = true }
    }
}

// MARK: - Sample Dialogue (development convenience)

extension DialogueLine {
    static let sampleConversation: [DialogueLine] = [
        DialogueLine(
            speakerName: "Kira Voss",
            speakerPortraitIcon: "shield.fill",
            text: "Commander, we've picked up movement in the industrial sector. Looks like a pack of ferals settled near the old foundry.",
            choices: nil
        ),
        DialogueLine(
            speakerName: "Dex Moreno",
            speakerPortraitIcon: "scope",
            text: "I scoped it out from the ridge. Six, maybe seven of them. One big one. Could be trouble if we don't hit hard.",
            choices: nil
        ),
        DialogueLine(
            speakerName: "Commander",
            speakerPortraitIcon: "person.fill",
            text: "What do you recommend?",
            choices: [
                DialogueChoice(label: "\"We go in now. Full assault.\"", nextLineIndex: 3, storyFlag: "chose_assault"),
                DialogueChoice(label: "\"Let's wait and scout more first.\"", nextLineIndex: 4, storyFlag: "chose_caution"),
            ]
        ),
        DialogueLine(
            speakerName: "Kira Voss",
            speakerPortraitIcon: "shield.fill",
            text: "Bold call. I'll rally the squad. We move at dawn.",
            choices: nil
        ),
        DialogueLine(
            speakerName: "Dex Moreno",
            speakerPortraitIcon: "scope",
            text: "Smart. I'll keep eyes on them. We'll know their patterns before we strike.",
            choices: nil
        ),
    ]
}
