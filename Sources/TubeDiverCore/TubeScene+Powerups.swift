import Foundation
import SpriteKit

extension TubeScene {
    func spawnPickup() {
        let margin: CGFloat = 24
        let minX = frame.minX + margin
        let maxX = frame.maxX - margin

        let kind: PickupKind = [.shield, .boost, .slow].randomElement() ?? .shield
        let color: SKColor

        switch kind {
        case .shield:
            color = SKColor(red: 0.25, green: 0.62, blue: 0.95, alpha: 1)
        case .boost:
            color = SKColor(red: 0.98, green: 0.72, blue: 0.17, alpha: 1)
        case .slow:
            color = SKColor(red: 0.35, green: 0.86, blue: 0.62, alpha: 1)
        case .coin:
            color = SKColor(red: 0.98, green: 0.82, blue: 0.22, alpha: 1)
        }

        let x = CGFloat.random(in: minX...maxX)
        let y = frame.minY - 160

        let node = SKShapeNode(circleOfRadius: 18)
        node.name = "pickup"
        let data = NSMutableDictionary()
        data["kind"] = kindKey(kind)
        node.userData = data
        node.position = CGPoint(x: x, y: y)
        node.fillColor = color
        node.strokeColor = SKColor(white: 0.10, alpha: 0.45)
        node.lineWidth = 3
        node.zPosition = 4

        let icon = makePowerupIcon(kind: kind)
        icon.position = .zero
        node.addChild(icon)

        node.run(.repeatForever(.sequence([
            .scale(to: 1.12, duration: 0.4),
            .scale(to: 1.0, duration: 0.4)
        ])))

        node.physicsBody = SKPhysicsBody(circleOfRadius: 18)
        node.physicsBody?.affectedByGravity = false
        node.physicsBody?.isDynamic = false
        node.physicsBody?.categoryBitMask = Category.pickup
        node.physicsBody?.collisionBitMask = 0
        node.physicsBody?.contactTestBitMask = Category.player

        world.addChild(node)
    }

    func makePowerupIcon(kind: PickupKind) -> SKNode {
        let outline = SKColor(white: 0.08, alpha: 0.95)
        switch kind {
        case .shield:
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: 12))
            path.addLine(to: CGPoint(x: -10, y: 6))
            path.addLine(to: CGPoint(x: -8, y: -10))
            path.addQuadCurve(to: CGPoint(x: 0, y: -14), control: CGPoint(x: -2, y: -14))
            path.addQuadCurve(to: CGPoint(x: 8, y: -10), control: CGPoint(x: 2, y: -14))
            path.addLine(to: CGPoint(x: 10, y: 6))
            path.closeSubpath()
            let s = SKShapeNode(path: path)
            s.fillColor = SKColor(white: 0.98, alpha: 0.9)
            s.strokeColor = outline
            s.lineWidth = 3
            return s
        case .boost:
            let r = makeRocketNode()
            r.setScale(0.7)
            return r
        case .slow:
            let pack = SKShapeNode(rectOf: CGSize(width: 16, height: 18), cornerRadius: 4)
            pack.fillColor = SKColor(white: 0.95, alpha: 0.9)
            pack.strokeColor = outline
            pack.lineWidth = 2
            let strap = SKShapeNode(rectOf: CGSize(width: 18, height: 4), cornerRadius: 2)
            strap.fillColor = SKColor(white: 0.2, alpha: 1)
            strap.strokeColor = .clear
            strap.position = CGPoint(x: 0, y: 4)
            pack.addChild(strap)
            return pack
        case .coin:
            let c = SKShapeNode(circleOfRadius: 9)
            c.fillColor = SKColor(white: 0.98, alpha: 0.9)
            c.strokeColor = outline
            c.lineWidth = 2
            return c
        }
    }

    func applyPickup(_ node: SKNode) {
        guard let kindString = node.userData?["kind"] as? String else { return }
        switch kindString {
        case kindKey(.shield):
            shieldRemaining = config.shieldDuration
            shieldWasActive = true
            shieldBubble.isHidden = false
            shieldRim.isHidden = false
            updateShieldVisuals(force: true)
            updateShieldCollisionMask()
        case kindKey(.boost):
            boostRemaining = config.boostDuration
            slowRemaining = 0
        case kindKey(.slow):
            slowRemaining = config.slowDuration
            boostRemaining = 0
        case kindKey(.coin):
            coinsThisRun += 1
        default:
            break
        }

        updatePlayerModifierArt()
    }

    func updateShieldVisuals(force: Bool = false) {
        let active = shieldRemaining > 0

        if !active {
            if shieldWasActive || force {
                shieldWasActive = false
                shieldBubble.removeAllActions()
                shieldRim.removeAllActions()

                shieldBubble.isHidden = false
                shieldRim.isHidden = false
                shieldBubble.strokeColor = SKColor(red: 0.98, green: 0.22, blue: 0.20, alpha: 0.8)
                shieldRim.strokeColor = SKColor(red: 0.98, green: 0.22, blue: 0.20, alpha: 0.95)
                let flash = SKAction.sequence([
                    .wait(forDuration: 0.12),
                    .fadeAlpha(to: 0.0, duration: 0.22),
                    .run { [weak self] in
                        self?.shieldBubble.alpha = 1
                        self?.shieldRim.alpha = 1
                        self?.shieldBubble.isHidden = true
                        self?.shieldRim.isHidden = true
                    }
                ])
                shieldBubble.run(flash)
                shieldRim.run(.sequence([
                    .wait(forDuration: 0.12),
                    .fadeAlpha(to: 0.0, duration: 0.22),
                    .run { [weak self] in
                        self?.shieldBubble.alpha = 1
                        self?.shieldRim.alpha = 1
                        self?.shieldBubble.isHidden = true
                        self?.shieldRim.isHidden = true
                    }
                ]))
            }
            return
        }

        shieldWasActive = true
        shieldBubble.isHidden = false
        shieldRim.isHidden = false
        shieldBubble.alpha = 1
        shieldRim.alpha = 1

        let fraction = max(0, min(1, CGFloat(shieldRemaining / config.shieldDuration)))
        let r = config.playerRadius + 16
        let start = CGFloat.pi / 2
        let end = start - (2 * CGFloat.pi * fraction)
        let path = CGMutablePath()
        path.addArc(center: .zero, radius: r, startAngle: start, endAngle: end, clockwise: true)
        shieldRim.path = path
        shieldRim.lineWidth = 6

        if shieldRemaining < 0.9 {
            shieldBubble.strokeColor = SKColor(red: 0.98, green: 0.22, blue: 0.20, alpha: 0.65)
            shieldRim.strokeColor = SKColor(red: 0.98, green: 0.22, blue: 0.20, alpha: 0.95)
        } else {
            shieldBubble.strokeColor = SKColor(red: 0.08, green: 0.55, blue: 0.20, alpha: 0.7)
            shieldRim.strokeColor = SKColor(red: 0.08, green: 0.55, blue: 0.20, alpha: 0.95)
        }
    }
}
