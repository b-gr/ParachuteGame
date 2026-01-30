import Foundation
import SpriteKit

extension TubeScene {
    func setupBackground() {
        childNode(withName: "tube")?.removeFromParent()
        physicsBody = nil

        if backgroundLayer.children.isEmpty {
            for i in 0..<7 {
                let y = frame.minY + CGFloat(i) * (frame.height / 6.0)
                spawnCloud(y: y)
            }
        }
    }

    func driveBackground(dt: TimeInterval) {
        let cloudSpeed = lerp(14, 26, intensity)
        backgroundLayer.enumerateChildNodes(withName: "cloud") { node, _ in
            node.position.y += cloudSpeed * CGFloat(dt)
            if let dx = (node.userData?["dx"] as? NSNumber)?.doubleValue {
                node.position.x += CGFloat(dx) * CGFloat(dt)
            }
        }
    }

    func spawnClouds(dt: TimeInterval) {
        cloudSpawnTimer += dt
        while cloudSpawnTimer >= config.cloudSpawnInterval {
            cloudSpawnTimer -= config.cloudSpawnInterval
            spawnCloud(y: frame.minY - 90)
        }
    }

    func cleanupClouds() {
        let cutoffY = frame.maxY + 220
        backgroundLayer.children.forEach { node in
            if node.name == "cloud" && node.position.y > cutoffY {
                node.removeAllActions()
                node.removeFromParent()
            }
        }
    }

    func spawnCloud(y: CGFloat) {
        let margin: CGFloat = 40
        let x = CGFloat.random(in: (frame.minX + margin)...(frame.maxX - margin))
        let scale = CGFloat.random(in: 0.8...1.6)

        let cloud = SKNode()
        cloud.name = "cloud"
        cloud.position = CGPoint(x: x, y: y)
        cloud.zPosition = -100

        let outline = SKColor(white: 1.0, alpha: 0.35)
        let fill = SKColor(white: 1.0, alpha: 0.85)
        let shadow = SKColor(white: 0.80, alpha: 0.35)

        let blobs: [CGPoint] = [
            CGPoint(x: -22, y: 0),
            CGPoint(x: -6, y: 10),
            CGPoint(x: 14, y: 8),
            CGPoint(x: 28, y: 0),
            CGPoint(x: 0, y: -4)
        ]

        for (i, p) in blobs.enumerated() {
            let r = CGFloat([16, 18, 16, 14, 18][i])
            let s = SKShapeNode(circleOfRadius: r)
            s.fillColor = fill
            s.strokeColor = outline
            s.lineWidth = 2
            s.position = p
            cloud.addChild(s)

            let sh = SKShapeNode(circleOfRadius: r)
            sh.fillColor = shadow
            sh.strokeColor = .clear
            sh.position = CGPoint(x: p.x + 2, y: p.y - 3)
            sh.zPosition = -1
            cloud.addChild(sh)
        }

        cloud.setScale(scale)
        cloud.alpha = CGFloat.random(in: 0.55...0.85)

        let data = NSMutableDictionary()
        data["dx"] = NSNumber(value: Double(CGFloat.random(in: -8...8)))
        cloud.userData = data

        backgroundLayer.addChild(cloud)
    }

    func spawnMilestonePlane(seconds: Int) {
        let goRight = Bool.random()
        let y = CGFloat.random(in: (frame.minY + frame.height * 0.25)...(frame.minY + frame.height * 0.55))

        let plane = SKNode()
        plane.name = "plane"
        let startX = goRight ? frame.minX - 140 : frame.maxX + 140
        let endX = goRight ? frame.maxX + 140 : frame.minX - 140
        plane.position = CGPoint(x: startX, y: y)
        plane.zPosition = -120

        let outline = SKColor(white: 0.12, alpha: 0.9)
        let fill = SKColor(white: 0.95, alpha: 0.9)

        let body = SKShapeNode(rectOf: CGSize(width: 70, height: 16), cornerRadius: 8)
        body.fillColor = fill
        body.strokeColor = outline
        body.lineWidth = 2

        let nosePath = CGMutablePath()
        nosePath.move(to: CGPoint(x: 35, y: 0))
        nosePath.addLine(to: CGPoint(x: 50, y: 6))
        nosePath.addLine(to: CGPoint(x: 50, y: -6))
        nosePath.closeSubpath()
        let nose = SKShapeNode(path: nosePath)
        nose.fillColor = fill
        nose.strokeColor = outline
        nose.lineWidth = 2

        let wing = SKShapeNode(rectOf: CGSize(width: 26, height: 8), cornerRadius: 4)
        wing.fillColor = SKColor(white: 0.88, alpha: 0.9)
        wing.strokeColor = outline
        wing.lineWidth = 2
        wing.position = CGPoint(x: -6, y: -8)

        let tail = SKShapeNode(rectOf: CGSize(width: 16, height: 8), cornerRadius: 3)
        tail.fillColor = SKColor(white: 0.88, alpha: 0.9)
        tail.strokeColor = outline
        tail.lineWidth = 2
        tail.position = CGPoint(x: -28, y: 6)

        let banner = SKShapeNode(rectOf: CGSize(width: 190, height: 28), cornerRadius: 12)
        banner.fillColor = SKColor(white: 1.0, alpha: 0.75)
        banner.strokeColor = outline
        banner.lineWidth = 2
        banner.position = CGPoint(x: -170, y: -4)

        let text = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        text.text = "\(seconds) seconds achieved!"
        text.fontSize = 14
        text.fontColor = SKColor(white: 0.12, alpha: 0.95)
        text.verticalAlignmentMode = .center
        text.horizontalAlignmentMode = .center
        text.position = .zero
        banner.addChild(text)

        plane.addChild(banner)
        plane.addChild(body)
        plane.addChild(nose)
        plane.addChild(wing)
        plane.addChild(tail)

        if !goRight {
            plane.xScale = -1
            banner.xScale = -1
        }

        let duration = TimeInterval(CGFloat.random(in: 6.0...8.5))
        let move = SKAction.moveTo(x: endX, duration: duration)
        plane.run(.sequence([move, .removeFromParent()]))

        farBackgroundLayer.addChild(plane)
    }
}
