import Foundation
import SpriteKit

extension TubeScene {
    func spawnObstacle() {
        let spawnY = frame.minY - 120
        let fromLeft = Bool.random()

        let bird = makeBirdNode()
        bird.name = "obstacle"
        bird.position = CGPoint(x: fromLeft ? frame.minX - 80 : frame.maxX + 80, y: spawnY)
        bird.zPosition = 3

        let hitW = (bird.userData?["hitW"] as? NSNumber).map { CGFloat(truncating: $0) } ?? 64
        let hitH = (bird.userData?["hitH"] as? NSNumber).map { CGFloat(truncating: $0) } ?? 30
        bird.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: hitW, height: hitH))
        bird.physicsBody?.affectedByGravity = false
        bird.physicsBody?.allowsRotation = false
        bird.physicsBody?.usesPreciseCollisionDetection = true
        bird.physicsBody?.categoryBitMask = Category.obstacle
        bird.physicsBody?.collisionBitMask = Category.player
        bird.physicsBody?.contactTestBitMask = Category.player

        let scroll = max(1, currentScrollSpeed())
        let playerY = player.position.y
        let dy = max(120, playerY - spawnY)
        let t = max(0.65, min(2.2, TimeInterval(dy / scroll)))

        let margin: CGFloat = 22
        let leftEdge = frame.minX + margin
        let rightEdge = frame.maxX - margin
        let edgeBand: CGFloat = 70

        let roll = CGFloat.random(in: 0...1)
        let targetX: CGFloat
        if roll < 0.42 {
            targetX = CGFloat.random(in: leftEdge...(min(leftEdge + edgeBand, rightEdge)))
        } else if roll < 0.84 {
            targetX = CGFloat.random(in: (max(rightEdge - edgeBand, leftEdge))...rightEdge)
        } else {
            targetX = CGFloat.random(in: (leftEdge + edgeBand)...(rightEdge - edgeBand))
        }

        var vx = (targetX - bird.position.x) / CGFloat(t)
        let maxVx = lerp(240, 520, intensity)
        let minVx = lerp(120, 220, intensity)
        if abs(vx) < minVx {
            vx = vx < 0 ? -minVx : minVx
        }
        vx = max(-maxVx, min(maxVx, vx))
        vx *= (0.75 + CGFloat.random(in: 0...0.7))
        bird.physicsBody?.velocity = CGVector(dx: vx, dy: 0)

        world.addChild(bird)
    }

    func makeBirdNode() -> SKNode {
        let node = SKNode()
        let outline = SKColor(white: 0.06, alpha: 0.55)

        struct Palette {
            let body: SKColor
            let wing: SKColor
            let belly: SKColor
            let beak: SKColor
        }

        let palettes: [Palette] = [
            .init(body: SKColor(red: 0.20, green: 0.22, blue: 0.26, alpha: 1), wing: SKColor(red: 0.14, green: 0.15, blue: 0.18, alpha: 1), belly: SKColor(red: 0.42, green: 0.44, blue: 0.48, alpha: 1), beak: SKColor(red: 0.98, green: 0.72, blue: 0.17, alpha: 1)),
            .init(body: SKColor(red: 0.34, green: 0.28, blue: 0.22, alpha: 1), wing: SKColor(red: 0.26, green: 0.22, blue: 0.18, alpha: 1), belly: SKColor(red: 0.60, green: 0.54, blue: 0.44, alpha: 1), beak: SKColor(red: 0.96, green: 0.62, blue: 0.22, alpha: 1)),
            .init(body: SKColor(red: 0.24, green: 0.30, blue: 0.34, alpha: 1), wing: SKColor(red: 0.16, green: 0.20, blue: 0.24, alpha: 1), belly: SKColor(red: 0.55, green: 0.58, blue: 0.62, alpha: 1), beak: SKColor(red: 0.98, green: 0.72, blue: 0.17, alpha: 1))
        ]
        let palette = palettes.randomElement() ?? palettes[0]

        let scale = CGFloat.random(in: 0.5...1.0)
        let hitW: CGFloat = 70 * scale
        let hitH: CGFloat = 28 * scale
        let data = NSMutableDictionary()
        data["hitW"] = NSNumber(value: Double(hitW))
        data["hitH"] = NSNumber(value: Double(hitH))
        node.userData = data

        let bodyPath = CGMutablePath()
        bodyPath.move(to: CGPoint(x: -30, y: 0))
        bodyPath.addQuadCurve(to: CGPoint(x: 20, y: 10), control: CGPoint(x: -6, y: 16))
        bodyPath.addQuadCurve(to: CGPoint(x: 28, y: 0), control: CGPoint(x: 30, y: 8))
        bodyPath.addQuadCurve(to: CGPoint(x: 20, y: -10), control: CGPoint(x: 30, y: -8))
        bodyPath.addQuadCurve(to: CGPoint(x: -30, y: 0), control: CGPoint(x: -6, y: -16))
        bodyPath.closeSubpath()
        let body = SKShapeNode(path: bodyPath)
        body.fillColor = palette.body
        body.strokeColor = outline
        body.lineWidth = 2

        let belly = SKShapeNode(ellipseOf: CGSize(width: 26, height: 12))
        belly.fillColor = palette.belly
        belly.strokeColor = .clear
        belly.alpha = 0.85
        belly.position = CGPoint(x: -6, y: -4)
        body.addChild(belly)

        let head = SKShapeNode(circleOfRadius: 7)
        head.fillColor = palette.body
        head.strokeColor = outline
        head.lineWidth = 2
        head.position = CGPoint(x: 22, y: 6)

        let beakPath = CGMutablePath()
        beakPath.move(to: CGPoint(x: 28, y: 6))
        beakPath.addLine(to: CGPoint(x: 42, y: 10))
        beakPath.addLine(to: CGPoint(x: 42, y: 3))
        beakPath.closeSubpath()
        let beak = SKShapeNode(path: beakPath)
        beak.fillColor = palette.beak
        beak.strokeColor = outline
        beak.lineWidth = 2

        let eyeWhite = SKShapeNode(circleOfRadius: 2.6)
        eyeWhite.fillColor = SKColor(white: 0.98, alpha: 1)
        eyeWhite.strokeColor = outline
        eyeWhite.lineWidth = 1
        eyeWhite.position = CGPoint(x: 24, y: 8)
        let pupil = SKShapeNode(circleOfRadius: 1.4)
        pupil.fillColor = SKColor(white: 0.10, alpha: 1)
        pupil.strokeColor = .clear
        pupil.position = CGPoint(x: 0.7, y: -0.7)
        eyeWhite.addChild(pupil)

        let tailPath = CGMutablePath()
        tailPath.move(to: CGPoint(x: -26, y: 4))
        tailPath.addLine(to: CGPoint(x: -44, y: 10))
        tailPath.addLine(to: CGPoint(x: -38, y: 0))
        tailPath.addLine(to: CGPoint(x: -44, y: -10))
        tailPath.addLine(to: CGPoint(x: -26, y: -4))
        tailPath.closeSubpath()
        let tail = SKShapeNode(path: tailPath)
        tail.fillColor = palette.wing
        tail.strokeColor = outline
        tail.lineWidth = 2
        tail.alpha = 0.95

        func wing(isLeft: Bool) -> SKNode {
            let pivot = SKNode()
            pivot.position = CGPoint(x: 0, y: 5)

            let wingPath = CGMutablePath()
            wingPath.move(to: CGPoint(x: -4, y: 0))
            wingPath.addQuadCurve(to: CGPoint(x: isLeft ? -44 : 44, y: 10), control: CGPoint(x: isLeft ? -26 : 26, y: 24))
            wingPath.addQuadCurve(to: CGPoint(x: isLeft ? -18 : 18, y: -8), control: CGPoint(x: isLeft ? -46 : 46, y: 0))
            wingPath.addQuadCurve(to: CGPoint(x: -4, y: 0), control: CGPoint(x: isLeft ? -10 : 10, y: -2))
            wingPath.closeSubpath()
            let w = SKShapeNode(path: wingPath)
            w.fillColor = palette.wing
            w.strokeColor = outline
            w.lineWidth = 2
            w.alpha = 0.98
            w.position = CGPoint(x: 2, y: -1)

            let feather = SKShapeNode()
            let fp = CGMutablePath()
            fp.move(to: CGPoint(x: -30, y: 6))
            fp.addLine(to: CGPoint(x: -40, y: 2))
            fp.move(to: CGPoint(x: -28, y: 2))
            fp.addLine(to: CGPoint(x: -40, y: -2))
            feather.path = fp
            feather.strokeColor = SKColor(white: 1.0, alpha: 0.12)
            feather.lineWidth = 2
            feather.lineCap = .round
            w.addChild(feather)

            pivot.addChild(w)
            return pivot
        }

        let leftWing = wing(isLeft: true)
        let rightWing = wing(isLeft: false)
        rightWing.xScale = -1

        node.addChild(tail)
        node.addChild(leftWing)
        node.addChild(rightWing)
        node.addChild(body)
        node.addChild(head)
        node.addChild(beak)
        node.addChild(eyeWhite)

        let flapSpeed = TimeInterval(CGFloat.random(in: 0.11...0.16))
        let leftFlap = SKAction.sequence([
            .rotate(toAngle: 0.55, duration: flapSpeed),
            .rotate(toAngle: -0.12, duration: flapSpeed)
        ])
        let rightFlap = SKAction.sequence([
            .rotate(toAngle: -0.55, duration: flapSpeed),
            .rotate(toAngle: 0.12, duration: flapSpeed)
        ])
        leftWing.run(.repeatForever(leftFlap))
        rightWing.run(.repeatForever(rightFlap))

        node.run(.repeatForever(.sequence([
            .moveBy(x: 0, y: 2.4, duration: 0.35),
            .moveBy(x: 0, y: -2.4, duration: 0.35)
        ])))

        node.setScale(scale)
        return node
    }
}
