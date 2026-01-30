import SpriteKit

extension TubeScene {
    func setupHUD() {
        scoreLabel.fontSize = 20
        scoreLabel.fontColor = SKColor(white: 0.92, alpha: 1)
        scoreLabel.horizontalAlignmentMode = .left
        scoreLabel.verticalAlignmentMode = .top
        scoreLabel.zPosition = 50
        hud.addChild(scoreLabel)

        statusLabel.fontSize = 18
        statusLabel.fontColor = SKColor(white: 0.92, alpha: 0.95)
        statusLabel.horizontalAlignmentMode = .center
        statusLabel.verticalAlignmentMode = .center
        statusLabel.zPosition = 51
        hud.addChild(statusLabel)

        hudBar.fillColor = SKColor(white: 0.05, alpha: 0.88)
        hudBar.strokeColor = .clear
        hudBar.zPosition = 49
        hudBar.isHidden = false
        hud.addChild(hudBar)

        scorePanel.fillColor = SKColor(white: 0.05, alpha: 0.88)
        scorePanel.strokeColor = .clear
        scorePanel.zPosition = 50
        scorePanel.isHidden = true
        hud.addChild(scorePanel)

        layoutHUD()
    }

    func setupDeathOverlay() {
        deathOverlay.fillColor = SKColor(white: 0.0, alpha: 1)
        deathOverlay.strokeColor = .clear
        deathOverlay.alpha = 0
        deathOverlay.zPosition = 40
        deathOverlay.path = CGPath(rect: CGRect(x: -frame.width / 2, y: -frame.height / 2, width: frame.width, height: frame.height), transform: nil)
        cameraNode.addChild(deathOverlay)
    }

    func layoutHUD() {
        let halfW = frame.width * 0.5
        let halfH = frame.height * 0.5
        scoreLabel.position = CGPoint(x: -halfW + 18, y: halfH - 14)
        statusLabel.position = .zero
        let barHeight = scoreLabel.fontSize + 12
        hudBar.path = CGPath(rect: CGRect(x: -halfW, y: halfH - barHeight, width: frame.width, height: barHeight), transform: nil)
        hudBar.position = .zero
        scorePanel.position = .zero
    }

    func updateHudScale() {
        // HUD stays in screen space; no scaling needed.
    }

    func updateHUD() {
        let seconds = max(0, elapsed)
        let score = Int((seconds * Double(1 + coinsThisRun)).rounded())
        let timeText = String(format: "%.1f", seconds)
        var buffs: [String] = []
        if shieldRemaining > 0 { buffs.append("Shield") }
        if boostRemaining > 0 { buffs.append("Boost") }
        if slowRemaining > 0 { buffs.append("Slow") }
        let buffText = buffs.isEmpty ? "" : "  [" + buffs.joined(separator: ", ") + "]"

        scoreLabel.text = "Score: \(score)  Time: \(timeText)s  Coins: \(coinsThisRun)" + buffText
    }
}
