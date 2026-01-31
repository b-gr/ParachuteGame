import Foundation
import SpriteKit

extension TubeScene {
    func updateMilestones() {
        let s = Int(elapsed)
        while s >= nextMilestoneSeconds {
            spawnMilestonePlane(seconds: nextMilestoneSeconds)
            nextMilestoneSeconds = nextMilestone(after: nextMilestoneSeconds)
        }
    }

    func nextMilestone(after value: Int) -> Int {
        switch value {
        case 10: return 20
        case 20: return 30
        case 30: return 60
        case 60: return 120
        default:
            if value < 120 { return 120 }
            return value + 60
        }
    }

    func presentNameEntry() {
        runState = .enteringName
        world.isPaused = true

        let seconds = Int(elapsed)
        let multiplier = 1 + coinsThisRun
        let score = seconds * multiplier

        scorePanel.isHidden = false
        hudBar.run(.fadeAlpha(to: 0.0, duration: 0.25))
        scoreLabel.run(.fadeAlpha(to: 0.0, duration: 0.25))
        statusLabel.numberOfLines = 0
        statusLabel.text = "Game Over\nTime: \(seconds)s  Coins: \(coinsThisRun)  \nScore: \(score)\n\nEnter your name and press Return:\n\(nameBuffer.isEmpty ? "_" : nameBuffer)"
    }

    func handleNameEntryKeyDown(_ event: NSEvent) {
        switch event.keyCode {
        case 51:
            if !nameBuffer.isEmpty {
                nameBuffer.removeLast()
            }
            refreshNamePrompt()
        case 36:
            saveCurrentScore()
        default:
            guard let chars = event.characters, !chars.isEmpty else { return }
            for scalar in chars.unicodeScalars {
                if scalar.value == 0x1B { continue }
                let c = Character(scalar)
                if c.isLetter || c.isNumber || c == " " || c == "-" || c == "_" {
                    if nameBuffer.count < 14 {
                        nameBuffer.append(c)
                    }
                }
            }
            refreshNamePrompt()
        }
    }

    func refreshNamePrompt() {
        guard runState == .enteringName else { return }
        let seconds = Int(elapsed)
        let multiplier = 1 + coinsThisRun
        let score = seconds * multiplier
        scorePanel.isHidden = false
        statusLabel.numberOfLines = 0
        statusLabel.text = "Game Over\nTime: \(seconds)s  Coins: \(coinsThisRun)  \nScore: \(score)\n\nEnter your name and press Return:\n\(nameBuffer.isEmpty ? "_" : nameBuffer)"
    }

    func currentScoreEntry() -> ScoreEntry {
        let seconds = Int(elapsed)
        let multiplier = 1 + coinsThisRun
        let score = seconds * multiplier
        let name = nameBuffer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Player" : nameBuffer.trimmingCharacters(in: .whitespacesAndNewlines)

        let iso = ISO8601DateFormatter()
        return ScoreEntry(
            name: name,
            score: score,
            seconds: seconds,
            coins: coinsThisRun,
            dateISO8601: iso.string(from: Date())
        )
    }

    func saveCurrentScore() {
        let entry = currentScoreEntry()
        highScores.append(entry)
        highScores.sort { $0.score > $1.score }
        if highScores.count > 10 {
            highScores = Array(highScores.prefix(10))
        }
        persistHighScores()

        runState = .showingScores
        statusLabel.numberOfLines = 0
        scorePanel.isHidden = false
        statusLabel.text = leaderboardText(current: entry)
    }

    func leaderboardText(current: ScoreEntry) -> String {
        var lines: [String] = []
        lines.append("Your score has been saved!")
        lines.append("\nHigh Scores")
        for (i, e) in highScores.enumerated() {
            lines.append("\(i + 1). \(e.name)  \(e.score)")
        }
        lines.append("\nClick (or press Return) to restart")
        return lines.joined(separator: "\n")
    }

    func loadHighScores() {
        let defaults = UserDefaults.standard
        guard let data = defaults.data(forKey: "TubeDiverHighScores") else { return }
        do {
            highScores = try JSONDecoder().decode([ScoreEntry].self, from: data)
        } catch {
            highScores = []
        }
    }

    func persistHighScores() {
        do {
            let data = try JSONEncoder().encode(highScores)
            UserDefaults.standard.set(data, forKey: "TubeDiverHighScores")
        } catch {
            // ignore for prototype
        }
    }
}
