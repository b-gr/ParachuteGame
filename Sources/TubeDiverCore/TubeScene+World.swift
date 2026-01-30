import SpriteKit

extension TubeScene {
    func driveWorld(dt: TimeInterval) {
        let scrollSpeed = currentScrollSpeed()

        world.enumerateChildNodes(withName: "obstacle") { node, _ in
            if let body = node.physicsBody {
                body.velocity = CGVector(dx: body.velocity.dx, dy: scrollSpeed)
                let bank = max(-0.35, min(0.35, -body.velocity.dx / 900))
                node.zRotation = bank
                node.xScale = body.velocity.dx < 0 ? -abs(node.xScale) : abs(node.xScale)
            } else {
                node.position.y += scrollSpeed * CGFloat(dt)
            }
        }
        world.enumerateChildNodes(withName: "pickup") { node, _ in
            node.position.y += scrollSpeed * CGFloat(dt)
        }
        world.enumerateChildNodes(withName: "coin") { node, _ in
            node.position.y += scrollSpeed * CGFloat(dt)
        }
    }

    func spawnThings(dt: TimeInterval) {
        obstacleSpawnTimer += dt
        pickupSpawnTimer += dt
        coinSpawnTimer += dt

        let interval = TimeInterval(lerp(CGFloat(config.birdSpawnBaseInterval), CGFloat(config.birdSpawnMinInterval), intensity))
        while obstacleSpawnTimer >= interval {
            obstacleSpawnTimer -= interval
            spawnObstacle()
        }

        if pickupSpawnTimer >= config.powerupSpawnInterval {
            pickupSpawnTimer = 0
            spawnPickup()
        }

        if coinSpawnTimer >= config.coinSpawnInterval {
            coinSpawnTimer = 0
            spawnCoin()
        }
    }

    func cleanupWorld() {
        let cutoffY = frame.maxY + 260
        world.children.forEach { node in
            let offscreenX = node.position.x < frame.minX - 260 || node.position.x > frame.maxX + 260
            if node.position.y > cutoffY || offscreenX {
                node.removeAllActions()
                node.removeFromParent()
            }
        }
    }
}
