// CampaignManager.swift
// ProjectAshfall
//
// Drives the five-act story campaign: tracks progress, manages story beats,
// handles dialogue sequences, and processes player decisions that branch
// the narrative.

import Foundation

// MARK: - Campaign Act

/// The five major acts of the Project Ashfall story.
enum CampaignAct: Int, Codable, CaseIterable, Comparable {
    case act1 = 1  // Establish shelter, survive the first wave
    case act2 = 2  // Discover the outbreak was engineered
    case act3 = 3  // Encounter rival human factions
    case act4 = 4  // Reclaim critical infrastructure
    case act5 = 5  // Assault the origin site

    var title: String {
        switch self {
        case .act1: return "Ashes to Shelter"
        case .act2: return "The Engineered Plague"
        case .act3: return "Fractured Alliances"
        case .act4: return "Reclamation"
        case .act5: return "Ground Zero"
        }
    }

    var description: String {
        switch self {
        case .act1:
            return "The world has fallen. Establish a shelter for survivors "
                + "and defend it against the first wave of the infected."
        case .act2:
            return "Clues point to a terrifying truth: the outbreak was no "
                + "accident. Someone engineered the virus."
        case .act3:
            return "Other survivors have organized into factions with their "
                + "own agendas. Ally, negotiate, or fight."
        case .act4:
            return "The city's power grid, water treatment, and communications "
                + "must be restored to mount a final offensive."
        case .act5:
            return "Assault the origin laboratory. End the nightmare once "
                + "and for all — but at what cost?"
        }
    }

    static func < (lhs: CampaignAct, rhs: CampaignAct) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Dialogue Line

/// A single line of dialogue in a story sequence.
struct DialogueLine: Codable, Identifiable {
    let id: UUID
    let speakerName: String
    let text: String
    /// Optional portrait asset name for the speaker.
    let portraitName: String?

    init(speaker: String, text: String, portrait: String? = nil) {
        self.id = UUID()
        self.speakerName = speaker
        self.text = text
        self.portraitName = portrait
    }
}

// MARK: - Decision Point

/// A branching choice the player makes during the story. Each option has
/// a tag that downstream systems can query to alter outcomes.
struct DecisionOption: Codable, Identifiable {
    let id: UUID
    let label: String
    /// Tag stored in campaign state (e.g. "allied_with_ironclad").
    let outcomeTag: String
    let description: String

    init(label: String, outcomeTag: String, description: String = "") {
        self.id = UUID()
        self.label = label
        self.outcomeTag = outcomeTag
        self.description = description
    }
}

struct DecisionPoint: Codable, Identifiable {
    let id: UUID
    let prompt: String
    let options: [DecisionOption]

    init(prompt: String, options: [DecisionOption]) {
        self.id = UUID()
        self.prompt = prompt
        self.options = options
    }
}

// MARK: - Story Beat Trigger

/// Condition that must be satisfied for a story beat to fire.
enum StoryTrigger: Codable {
    case chapterComplete(act: Int, chapter: Int)
    case districtCleared(districtName: String)
    case buildingConstructed(type: BuildingType)
    case heroRecruited(heroName: String)
    case resourceThreshold(type: ResourceType, amount: Int)
    case decisionMade(tag: String)
    case missionCount(count: Int)
}

// MARK: - Story Beat

/// A discrete narrative moment: dialogue, a decision, and/or rewards.
struct StoryBeat: Codable, Identifiable {
    let id: String
    let act: CampaignAct
    let chapter: Int
    let title: String
    let description: String
    let dialogueLines: [DialogueLine]
    let decision: DecisionPoint?
    let triggers: [StoryTrigger]
    let rewards: [ResourceCost]
    /// Hero ID unlocked upon completing this beat (if any).
    let heroUnlockID: UUID?
    var isCompleted: Bool

    init(id: String, act: CampaignAct, chapter: Int, title: String,
         description: String, dialogueLines: [DialogueLine] = [],
         decision: DecisionPoint? = nil, triggers: [StoryTrigger] = [],
         rewards: [ResourceCost] = [], heroUnlockID: UUID? = nil) {
        self.id = id
        self.act = act
        self.chapter = chapter
        self.title = title
        self.description = description
        self.dialogueLines = dialogueLines
        self.decision = decision
        self.triggers = triggers
        self.rewards = rewards
        self.heroUnlockID = heroUnlockID
        self.isCompleted = false
    }
}

// MARK: - Campaign State

/// Serializable snapshot of the player's campaign progress.
struct CampaignState: Codable {
    var currentAct: CampaignAct
    var currentChapter: Int
    var completedBeatIDs: Set<String>
    /// Tags from player decisions, checked by story triggers and outcome
    /// forks.
    var decisionTags: Set<String>
    var totalPlaytimeSeconds: TimeInterval

    static let fresh = CampaignState(
        currentAct: .act1, currentChapter: 1,
        completedBeatIDs: [], decisionTags: [],
        totalPlaytimeSeconds: 0
    )
}

// MARK: - Cutscene Sequence

/// A sequence of dialogue lines and optional decisions presented as a
/// full-screen cutscene.
struct CutsceneSequence: Identifiable {
    let id = UUID()
    let storyBeatID: String
    let lines: [DialogueLine]
    let decision: DecisionPoint?
    /// Index of the line currently being displayed.
    var currentLineIndex: Int = 0

    var isFinished: Bool {
        currentLineIndex >= lines.count
    }

    var currentLine: DialogueLine? {
        guard currentLineIndex < lines.count else { return nil }
        return lines[currentLineIndex]
    }

    mutating func advance() {
        currentLineIndex += 1
    }
}

// MARK: - Campaign Manager

/// Orchestrates the five-act story. Other systems (exploration, combat,
/// base-building) report events; this manager checks triggers, fires
/// story beats, and tracks decisions.
final class CampaignManager {

    // MARK: Properties

    private(set) var state: CampaignState
    private(set) var storyBeats: [StoryBeat]

    /// The cutscene currently being presented (nil if none).
    private(set) var activeCutscene: CutsceneSequence?

    /// Callback when a new cutscene should be displayed.
    var onCutsceneStart: ((CutsceneSequence) -> Void)?
    /// Callback when a decision point is reached.
    var onDecisionRequired: ((DecisionPoint) -> Void)?
    /// Callback when a chapter is completed.
    var onChapterComplete: ((CampaignAct, Int) -> Void)?

    // MARK: Init

    init(state: CampaignState = .fresh) {
        self.state = state
        self.storyBeats = CampaignManager.buildDefaultStoryBeats()
    }

    // MARK: - Trigger Evaluation

    /// Call whenever a game event occurs that might advance the story
    /// (district cleared, building constructed, etc.).
    func evaluateTriggers(context: TriggerContext) {
        for i in storyBeats.indices {
            guard !storyBeats[i].isCompleted else { continue }
            guard storyBeats[i].act <= state.currentAct else { continue }

            if allTriggersMet(storyBeats[i].triggers, context: context) {
                fireStoryBeat(at: i)
            }
        }
    }

    // MARK: - Story Beat Activation

    private func fireStoryBeat(at index: Int) {
        storyBeats[index].isCompleted = true
        state.completedBeatIDs.insert(storyBeats[index].id)

        let beat = storyBeats[index]

        // Start cutscene if there are dialogue lines
        if !beat.dialogueLines.isEmpty {
            let cutscene = CutsceneSequence(
                storyBeatID: beat.id,
                lines: beat.dialogueLines,
                decision: beat.decision
            )
            activeCutscene = cutscene
            onCutsceneStart?(cutscene)
        } else if let decision = beat.decision {
            onDecisionRequired?(decision)
        }

        // Check for chapter advancement
        checkChapterAdvance(after: beat)
    }

    // MARK: - Cutscene Control

    /// Advances the active cutscene by one line. Returns the next line,
    /// or `nil` if the cutscene is finished.
    @discardableResult
    func advanceCutscene() -> DialogueLine? {
        activeCutscene?.advance()
        if activeCutscene?.isFinished == true {
            // If there's a decision at the end, present it
            if let decision = activeCutscene?.decision {
                onDecisionRequired?(decision)
            }
            let beatID = activeCutscene?.storyBeatID
            activeCutscene = nil
            // Grant rewards for the completed beat
            if let bid = beatID {
                grantBeatRewards(beatID: bid)
            }
            return nil
        }
        return activeCutscene?.currentLine
    }

    /// Skips the remaining cutscene dialogue and jumps to the decision
    /// (if any).
    func skipCutscene() {
        guard let cutscene = activeCutscene else { return }
        if let decision = cutscene.decision {
            onDecisionRequired?(decision)
        }
        let beatID = cutscene.storyBeatID
        activeCutscene = nil
        grantBeatRewards(beatID: beatID)
    }

    // MARK: - Decision Handling

    /// Records the player's choice at a decision point.
    func makeDecision(optionTag: String) {
        state.decisionTags.insert(optionTag)
    }

    /// Returns true if the player previously chose the given tag.
    func hasDecision(_ tag: String) -> Bool {
        state.decisionTags.contains(tag)
    }

    // MARK: - Chapter / Act Progression

    /// Advances to the next chapter. If the current act is finished,
    /// advances to the next act.
    func completeCurrentChapter() {
        let act = state.currentAct
        let chapter = state.currentChapter
        onChapterComplete?(act, chapter)

        let chaptersInAct = chapterCount(for: act)
        if chapter >= chaptersInAct {
            // Advance to next act
            if let nextAct = CampaignAct(rawValue: act.rawValue + 1) {
                state.currentAct = nextAct
                state.currentChapter = 1
            }
            // If act 5 is done the game is complete (handled by UI layer)
        } else {
            state.currentChapter += 1
        }
    }

    /// Returns the current act and chapter as a tuple.
    var currentProgress: (act: CampaignAct, chapter: Int) {
        (state.currentAct, state.currentChapter)
    }

    /// Returns all story beats for a given act.
    func beats(forAct act: CampaignAct) -> [StoryBeat] {
        storyBeats.filter { $0.act == act }
    }

    /// Percentage completion of the entire campaign (0.0–1.0).
    var overallProgress: Double {
        let total = storyBeats.count
        guard total > 0 else { return 0 }
        let done = storyBeats.filter(\.isCompleted).count
        return Double(done) / Double(total)
    }

    // MARK: - Playtime

    /// Updates session playtime. Call from the game loop.
    func updatePlaytime(deltaTime dt: TimeInterval) {
        state.totalPlaytimeSeconds += dt
    }

    // MARK: - Private: Trigger Matching

    /// Holds transient context from the event that may satisfy triggers.
    struct TriggerContext {
        var completedAct: Int?
        var completedChapter: Int?
        var clearedDistrictName: String?
        var constructedBuildingType: BuildingType?
        var recruitedHeroName: String?
        var currentResources: ResourceInventory?
        var totalMissionsCompleted: Int?
    }

    private func allTriggersMet(_ triggers: [StoryTrigger],
                                context: TriggerContext) -> Bool {
        guard !triggers.isEmpty else { return false }
        return triggers.allSatisfy { isMet($0, context: context) }
    }

    private func isMet(_ trigger: StoryTrigger,
                       context: TriggerContext) -> Bool {
        switch trigger {
        case .chapterComplete(let act, let chapter):
            if let ca = context.completedAct, let cc = context.completedChapter {
                return ca >= act && cc >= chapter
            }
            return state.currentAct.rawValue > act
                || (state.currentAct.rawValue == act
                    && state.currentChapter > chapter)

        case .districtCleared(let name):
            return context.clearedDistrictName == name

        case .buildingConstructed(let type):
            return context.constructedBuildingType == type

        case .heroRecruited(let name):
            return context.recruitedHeroName == name

        case .resourceThreshold(let type, let amount):
            if let inv = context.currentResources {
                return inv.amount(of: type) >= amount
            }
            return false

        case .decisionMade(let tag):
            return state.decisionTags.contains(tag)

        case .missionCount(let count):
            return (context.totalMissionsCompleted ?? 0) >= count
        }
    }

    private func checkChapterAdvance(after beat: StoryBeat) {
        // If all beats in the current chapter are done, auto-advance
        let currentBeats = storyBeats.filter {
            $0.act == state.currentAct && $0.chapter == state.currentChapter
        }
        if currentBeats.allSatisfy(\.isCompleted) {
            completeCurrentChapter()
        }
    }

    private func grantBeatRewards(beatID: String) {
        // Rewards are picked up by EconomyManager via a notification or
        // delegate in the real integration. Here we store them as completed
        // so the caller can query and distribute.
    }

    private func chapterCount(for act: CampaignAct) -> Int {
        switch act {
        case .act1: return 3
        case .act2: return 4
        case .act3: return 4
        case .act4: return 3
        case .act5: return 2
        }
    }

    // MARK: - Default Story Content

    private static func buildDefaultStoryBeats() -> [StoryBeat] {
        var beats: [StoryBeat] = []

        // ---- ACT 1: Ashes to Shelter ----
        beats.append(StoryBeat(
            id: "act1_ch1_arrival",
            act: .act1, chapter: 1,
            title: "A World in Ashes",
            description: "You awaken to a city in ruins. Find shelter before nightfall.",
            dialogueLines: [
                DialogueLine(speaker: "Commander", text: "The radio went dead three days ago. Whatever happened, we're on our own.", portrait: "portrait_commander"),
                DialogueLine(speaker: "Mara", text: "There's an old fire station two blocks north. Walls are solid. Could work as a shelter.", portrait: "portrait_mara"),
                DialogueLine(speaker: "Commander", text: "Then that's where we dig in. Gather what you can and move.")
            ],
            triggers: [.chapterComplete(act: 1, chapter: 0)] // fires immediately at game start
        ))

        beats.append(StoryBeat(
            id: "act1_ch1_shelter",
            act: .act1, chapter: 1,
            title: "First Walls",
            description: "Construct a shelter to house survivors.",
            dialogueLines: [
                DialogueLine(speaker: "Mara", text: "Shelter's up. It's not pretty, but it'll keep the rain and the dead out."),
                DialogueLine(speaker: "Commander", text: "Good. Now let's make sure we can eat tomorrow.")
            ],
            triggers: [.buildingConstructed(type: .shelter)],
            rewards: [ResourceCost(.food, 20), ResourceCost(.water, 15)]
        ))

        beats.append(StoryBeat(
            id: "act1_ch2_firstwave",
            act: .act1, chapter: 2,
            title: "The First Wave",
            description: "Infected are massing at the perimeter. Survive the night.",
            dialogueLines: [
                DialogueLine(speaker: "Radio", text: "[static] ...multiple contacts incoming from the south..."),
                DialogueLine(speaker: "Commander", text: "All hands, defensive positions. This is what we trained for."),
                DialogueLine(speaker: "Mara", text: "We didn't train for anything. We're just trying not to die.")
            ],
            triggers: [.missionCount(count: 1)],
            rewards: [ResourceCost(.scrap, 30), ResourceCost(.militaryComponents, 5)]
        ))

        beats.append(StoryBeat(
            id: "act1_ch3_dawn",
            act: .act1, chapter: 3,
            title: "Dawn",
            description: "The first wave is repelled. But the infected will return.",
            dialogueLines: [
                DialogueLine(speaker: "Mara", text: "We made it. Barely."),
                DialogueLine(speaker: "Commander", text: "Start fortifying. This was just the beginning.")
            ],
            triggers: [.missionCount(count: 3)]
        ))

        // ---- ACT 2: The Engineered Plague ----
        beats.append(StoryBeat(
            id: "act2_ch1_clues",
            act: .act2, chapter: 1,
            title: "Breadcrumbs",
            description: "Scattered lab notes hint that the outbreak was manufactured.",
            dialogueLines: [
                DialogueLine(speaker: "Dr. Voss", text: "These documents... Strain PA-7 wasn't a mutation. Someone designed it.", portrait: "portrait_voss"),
                DialogueLine(speaker: "Commander", text: "Designed? By who?"),
                DialogueLine(speaker: "Dr. Voss", text: "Ashfall Genomics. A biotech subsidiary. Their lab is across the river.")
            ],
            triggers: [.districtCleared(districtName: "University District")],
            rewards: [ResourceCost(.researchData, 10)]
        ))

        beats.append(StoryBeat(
            id: "act2_ch2_lab",
            act: .act2, chapter: 2,
            title: "The Lab",
            description: "Infiltrate the Ashfall Genomics facility.",
            dialogueLines: [
                DialogueLine(speaker: "Dr. Voss", text: "The containment failed on purpose. Someone opened the vaults."),
                DialogueLine(speaker: "Commander", text: "Why would anyone do this?"),
                DialogueLine(speaker: "Dr. Voss", text: "Control. Whoever has the cure controls everything.")
            ],
            triggers: [.districtCleared(districtName: "Industrial Zone")],
            rewards: [ResourceCost(.bioSamples, 8)]
        ))

        beats.append(StoryBeat(
            id: "act2_ch3_betrayal",
            act: .act2, chapter: 3,
            title: "Betrayal",
            description: "A trusted ally reveals a hidden agenda.",
            dialogueLines: [
                DialogueLine(speaker: "Mara", text: "Commander, we intercepted a transmission. Someone in our camp has been reporting our position."),
                DialogueLine(speaker: "Commander", text: "Find them. Now.")
            ],
            decision: DecisionPoint(
                prompt: "How do you handle the spy?",
                options: [
                    DecisionOption(label: "Confront publicly", outcomeTag: "spy_public",
                                   description: "Make an example. Morale boost but the spy's contacts learn you know."),
                    DecisionOption(label: "Feed false information", outcomeTag: "spy_deception",
                                   description: "Use the spy to mislead the enemy. Riskier but strategic."),
                    DecisionOption(label: "Show mercy", outcomeTag: "spy_mercy",
                                   description: "Exile the spy. Preserves humanity but the leak continues briefly.")
                ]
            ),
            triggers: [.missionCount(count: 8)]
        ))

        beats.append(StoryBeat(
            id: "act2_ch4_truth",
            act: .act2, chapter: 4,
            title: "The Whole Truth",
            description: "The scope of the conspiracy becomes clear.",
            dialogueLines: [
                DialogueLine(speaker: "Dr. Voss", text: "It's not just one lab. There are five sites, all connected. This was a coordinated release."),
                DialogueLine(speaker: "Commander", text: "Then we need to find them all.")
            ],
            triggers: [.chapterComplete(act: 2, chapter: 3)],
            rewards: [ResourceCost(.researchData, 15)]
        ))

        // ---- ACT 3: Fractured Alliances ----
        beats.append(StoryBeat(
            id: "act3_ch1_factions",
            act: .act3, chapter: 1,
            title: "New Players",
            description: "Three rival factions emerge from the ruins.",
            dialogueLines: [
                DialogueLine(speaker: "Scout", text: "Commander, we've confirmed three organized groups in the city."),
                DialogueLine(speaker: "Scout", text: "The Ironclad — military remnants. The Collective — civilian coalition. The Reapers — raiders with heavy gear."),
                DialogueLine(speaker: "Commander", text: "We can't fight everyone. Figure out who we can work with.")
            ],
            triggers: [.chapterComplete(act: 2, chapter: 4)]
        ))

        beats.append(StoryBeat(
            id: "act3_ch2_alliance",
            act: .act3, chapter: 2,
            title: "Choose Your Allies",
            description: "Form an alliance that will shape the rest of the war.",
            dialogueLines: [
                DialogueLine(speaker: "Commander", text: "We can't take the origin site alone. We need allies.")
            ],
            decision: DecisionPoint(
                prompt: "Which faction do you ally with?",
                options: [
                    DecisionOption(label: "The Ironclad", outcomeTag: "allied_ironclad",
                                   description: "Military strength. They demand obedience."),
                    DecisionOption(label: "The Collective", outcomeTag: "allied_collective",
                                   description: "Numbers and infrastructure. Slower to mobilize."),
                    DecisionOption(label: "Go independent", outcomeTag: "allied_none",
                                   description: "Harder road, but you answer to no one.")
                ]
            ),
            triggers: [.missionCount(count: 12)]
        ))

        beats.append(StoryBeat(
            id: "act3_ch3_reapers",
            act: .act3, chapter: 3,
            title: "The Reapers Strike",
            description: "The Reapers launch a coordinated assault on your territory.",
            dialogueLines: [
                DialogueLine(speaker: "Mara", text: "Multiple contacts — Reapers. They're hitting the eastern wall."),
                DialogueLine(speaker: "Commander", text: "Hold the line. If they take the storehouse, we're finished.")
            ],
            triggers: [.chapterComplete(act: 3, chapter: 2)],
            rewards: [ResourceCost(.militaryComponents, 15)]
        ))

        beats.append(StoryBeat(
            id: "act3_ch4_truce",
            act: .act3, chapter: 4,
            title: "Uneasy Truce",
            description: "The factions agree to a temporary ceasefire for the greater threat.",
            dialogueLines: [
                DialogueLine(speaker: "Commander", text: "The infected don't negotiate. We fight each other, we all die."),
                DialogueLine(speaker: "Ironclad Leader", text: "Agreed. For now.")
            ],
            triggers: [.chapterComplete(act: 3, chapter: 3)]
        ))

        // ---- ACT 4: Reclamation ----
        beats.append(StoryBeat(
            id: "act4_ch1_power",
            act: .act4, chapter: 1,
            title: "Lights On",
            description: "Restore power to the city grid.",
            dialogueLines: [
                DialogueLine(speaker: "Engineer", text: "If we can restart the substation, we'll have power for the whole district."),
                DialogueLine(speaker: "Commander", text: "Do it. We need the infrastructure for the final push.")
            ],
            triggers: [.buildingConstructed(type: .generator)],
            rewards: [ResourceCost(.powerCells, 10), ResourceCost(.electronics, 15)]
        ))

        beats.append(StoryBeat(
            id: "act4_ch2_comms",
            act: .act4, chapter: 2,
            title: "Signal Restored",
            description: "Repair the communication relay to coordinate with allies.",
            dialogueLines: [
                DialogueLine(speaker: "Radio Operator", text: "We're live. I'm picking up signals from other survivor groups across the state."),
                DialogueLine(speaker: "Commander", text: "Tell them what we know. Tell them about Ashfall Genomics.")
            ],
            triggers: [.buildingConstructed(type: .radarTower)],
            rewards: [ResourceCost(.researchData, 20)]
        ))

        beats.append(StoryBeat(
            id: "act4_ch3_ready",
            act: .act4, chapter: 3,
            title: "Ready for War",
            description: "All preparations are complete. The origin site awaits.",
            dialogueLines: [
                DialogueLine(speaker: "Mara", text: "This is it. Everything we've built, everyone we've lost — it all comes down to this."),
                DialogueLine(speaker: "Commander", text: "Let's finish it.")
            ],
            triggers: [.resourceThreshold(type: .militaryComponents, amount: 50)],
            rewards: [ResourceCost(.militaryComponents, 20), ResourceCost(.fuel, 30)]
        ))

        // ---- ACT 5: Ground Zero ----
        beats.append(StoryBeat(
            id: "act5_ch1_assault",
            act: .act5, chapter: 1,
            title: "Into the Fire",
            description: "Breach the origin site perimeter.",
            dialogueLines: [
                DialogueLine(speaker: "Commander", text: "All squads, advance. Stay tight and watch your sectors."),
                DialogueLine(speaker: "Dr. Voss", text: "The automated defenses should be offline, but expect heavy infected presence inside."),
                DialogueLine(speaker: "Mara", text: "Heavy infected? That's every Tuesday at this point.")
            ],
            triggers: [.chapterComplete(act: 4, chapter: 3)],
            rewards: [ResourceCost(.bioSamples, 15)]
        ))

        beats.append(StoryBeat(
            id: "act5_ch2_finale",
            act: .act5, chapter: 2,
            title: "Ashfall",
            description: "Confront the architect of the plague and decide humanity's future.",
            dialogueLines: [
                DialogueLine(speaker: "Architect", text: "You think you're saving them? The virus was the cure. Humanity was the disease."),
                DialogueLine(speaker: "Commander", text: "You don't get to make that call."),
                DialogueLine(speaker: "Architect", text: "Someone had to.")
            ],
            decision: DecisionPoint(
                prompt: "The origin site contains the master strain and the cure. What do you do?",
                options: [
                    DecisionOption(label: "Destroy everything", outcomeTag: "ending_destroy",
                                   description: "Burn it all. No one should have this power."),
                    DecisionOption(label: "Secure the cure", outcomeTag: "ending_cure",
                                   description: "Take the cure and distribute it. Risky — others will want it too."),
                    DecisionOption(label: "Preserve the research", outcomeTag: "ending_preserve",
                                   description: "Keep the research intact. Knowledge is power, for better or worse.")
                ]
            ),
            triggers: [.missionCount(count: 25)],
            rewards: [ResourceCost(.researchData, 50), ResourceCost(.bioSamples, 25)]
        ))

        return beats
    }
}
