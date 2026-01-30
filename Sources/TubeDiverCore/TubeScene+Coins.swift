import Foundation
import SpriteKit

extension TubeScene {
    func spawnCoin() {
        let margin: CGFloat = 22
        let minX = frame.minX + margin
        let maxX = frame.maxX - margin

        let x = CGFloat.random(in: minX...maxX)
        let y = frame.minY - 140

        let node = SKShapeNode(circleOfRadius: 11)
        node.name = "coin"
        let data = NSMutableDictionary()
        data["kind"] = kindKey(.coin)
        node.userData = data
        node.position = CGPoint(x: x, y: y)
        node.fillColor = SKColor(red: 0.98, green: 0.82, blue: 0.22, alpha: 1)
        node.strokeColor = SKColor(white: 1, alpha: 0.25)
        node.lineWidth = 2
        node.zPosition = 4

        node.physicsBody = SKPhysicsBody(circleOfRadius: 11)
        node.physicsBody?.affectedByGravity = false
        node.physicsBody?.isDynamic = false
        node.physicsBody?.categoryBitMask = Category.coin
        node.physicsBody?.collisionBitMask = 0
        node.physicsBody?.contactTestBitMask = Category.player

        node.run(.repeatForever(.sequence([
            .rotate(byAngle: 0.9, duration: 0.45),
            .rotate(byAngle: 0.9, duration: 0.45)
        ])))

        world.addChild(node)
    }
}
