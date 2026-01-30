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

        let blimp = SKNode()
        blimp.name = "blimp"
        let startX = goRight ? frame.minX - 180 : frame.maxX + 180
        let endX = goRight ? frame.maxX + 180 : frame.minX - 180
        blimp.position = CGPoint(x: startX, y: y)
        blimp.zPosition = -120

        let outline = SKColor(white: 0.12, alpha: 0.9)
        let fill = SKColor(white: 0.95, alpha: 0.9)
        let accent = SKColor(white: 0.88, alpha: 0.9)

        let body = SKShapeNode(ellipseOf: CGSize(width: 120, height: 36))
        body.fillColor = fill
        body.strokeColor = outline
        body.lineWidth = 2

        let band = SKShapeNode(rectOf: CGSize(width: 110, height: 6), cornerRadius: 3)
        band.fillColor = accent
        band.strokeColor = .clear
        band.position = CGPoint(x: 0, y: -2)

        let gondola = SKShapeNode(rectOf: CGSize(width: 26, height: 10), cornerRadius: 4)
        gondola.fillColor = accent
        gondola.strokeColor = outline
        gondola.lineWidth = 2
        gondola.position = CGPoint(x: 8, y: -22)

        let tailFin = SKShapeNode(rectOf: CGSize(width: 14, height: 6), cornerRadius: 2)
        tailFin.fillColor = accent
        tailFin.strokeColor = outline
        tailFin.lineWidth = 2
        tailFin.position = CGPoint(x: -54, y: 6)

        let tailFinLower = SKShapeNode(rectOf: CGSize(width: 12, height: 5), cornerRadius: 2)
        tailFinLower.fillColor = accent
        tailFinLower.strokeColor = outline
        tailFinLower.lineWidth = 2
        tailFinLower.position = CGPoint(x: -50, y: -8)

        let banner = SKShapeNode(rectOf: CGSize(width: 190, height: 28), cornerRadius: 12)
        banner.fillColor = SKColor(white: 1.0, alpha: 0.75)
        banner.strokeColor = outline
        banner.lineWidth = 2
        banner.position = CGPoint(x: -170, y: -26)

        let text = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        text.text = "\(seconds) seconds achieved!"
        text.fontSize = 14
        text.fontColor = SKColor(white: 0.12, alpha: 0.95)
        text.verticalAlignmentMode = .center
        text.horizontalAlignmentMode = .center
        text.position = .zero
        banner.addChild(text)

        blimp.addChild(body)
        body.addChild(band)
        blimp.addChild(gondola)
        blimp.addChild(tailFin)
        blimp.addChild(tailFinLower)
        blimp.addChild(banner)

        if !goRight {
            blimp.xScale = -1
            banner.xScale = -1
        }

        let duration = TimeInterval(CGFloat.random(in: 6.0...8.5))
        let move = SKAction.moveTo(x: endX, duration: duration)
        blimp.run(.sequence([move, .removeFromParent()]))

        farBackgroundLayer.addChild(blimp)
    }
}
