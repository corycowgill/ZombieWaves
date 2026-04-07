// SaveManager.swift
// ProjectAshfall
//
// Persistent save/load system using JSON encoding to the app documents directory.
// Supports multiple save slots with metadata for the save-selection UI.

import Foundation
import UIKit

// MARK: - Save Slot

struct SaveSlot: Identifiable, Codable {
    let id: Int
    var playerName: String
    var chapter: Int
    var daysSurvived: Int
    var commanderLevel: Int
    var playtime: TimeInterval
    var dateCreated: Date
    var dateModified: Date
    var thumbnailData: Data?

    var formattedPlaytime: String {
        let hours = Int(playtime) / 3600
        let minutes = (Int(playtime) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: dateModified)
    }
}

// MARK: - Save File Wrapper

private struct SaveFileWrapper: Codable {
    let metadata: SaveSlot
    let state: SaveableState
}

// MARK: - Save Manager

final class SaveManager {
    static let shared = SaveManager()

    private let fileManager = FileManager.default
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    static let maxSlots = 5
    static let autoSaveSlot = 0

    private init() {}

    // MARK: - Directory

    private var saveDirectory: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("SaveData", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private func fileURL(for slot: Int) -> URL {
        saveDirectory.appendingPathComponent("save_slot_\(slot).json")
    }

    // MARK: - Save

    @discardableResult
    func save(state: SaveableState, slot: Int) -> Bool {
        let metadata = SaveSlot(
            id: slot,
            playerName: state.playerName,
            chapter: state.progression.currentChapter,
            daysSurvived: state.campaign.daysSurvived,
            commanderLevel: state.progression.commanderLevel,
            playtime: state.totalPlaytime,
            dateCreated: existingMetadata(slot: slot)?.dateCreated ?? Date(),
            dateModified: Date(),
            thumbnailData: nil
        )

        let wrapper = SaveFileWrapper(metadata: metadata, state: state)

        do {
            let data = try encoder.encode(wrapper)
            try data.write(to: fileURL(for: slot), options: [.atomic, .completeFileProtection])
            return true
        } catch {
            print("[SaveManager] Save failed for slot \(slot): \(error)")
            return false
        }
    }

    // MARK: - Load

    func load(slot: Int) -> SaveableState? {
        let url = fileURL(for: slot)
        guard fileManager.fileExists(atPath: url.path) else { return nil }

        do {
            let data = try Data(contentsOf: url)
            let wrapper = try decoder.decode(SaveFileWrapper.self, from: data)
            return wrapper.state
        } catch {
            print("[SaveManager] Load failed for slot \(slot): \(error)")
            return nil
        }
    }

    // MARK: - Metadata

    func existingMetadata(slot: Int) -> SaveSlot? {
        let url = fileURL(for: slot)
        guard fileManager.fileExists(atPath: url.path) else { return nil }

        do {
            let data = try Data(contentsOf: url)
            let wrapper = try decoder.decode(SaveFileWrapper.self, from: data)
            return wrapper.metadata
        } catch {
            return nil
        }
    }

    // MARK: - List Saves

    func listSaves() -> [SaveSlot] {
        var slots: [SaveSlot] = []
        for i in 0..<SaveManager.maxSlots {
            if let meta = existingMetadata(slot: i) {
                slots.append(meta)
            }
        }
        return slots.sorted { $0.dateModified > $1.dateModified }
    }

    // MARK: - Delete

    @discardableResult
    func deleteSave(slot: Int) -> Bool {
        let url = fileURL(for: slot)
        guard fileManager.fileExists(atPath: url.path) else { return false }

        do {
            try fileManager.removeItem(at: url)
            return true
        } catch {
            print("[SaveManager] Delete failed for slot \(slot): \(error)")
            return false
        }
    }

    // MARK: - Auto-Save

    func autoSave(state: SaveableState) {
        save(state: state, slot: SaveManager.autoSaveSlot)
    }

    // MARK: - Slot Availability

    func isSlotOccupied(_ slot: Int) -> Bool {
        fileManager.fileExists(atPath: fileURL(for: slot).path)
    }

    func nextAvailableSlot() -> Int? {
        for i in 1..<SaveManager.maxSlots {
            if !isSlotOccupied(i) { return i }
        }
        return nil
    }
}
