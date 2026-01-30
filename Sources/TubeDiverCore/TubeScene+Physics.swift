import SpriteKit

extension TubeScene: @preconcurrency SKPhysicsContactDelegate {
    public func didBegin(_ contact: SKPhysicsContact) {
        let a = contact.bodyA
        let b = contact.bodyB

        if isPair(a, b, Category.player, Category.pickup) {
            let pickupBody = a.categoryBitMask == Category.pickup ? a : b
            if let node = pickupBody.node {
                applyPickup(node)
                node.removeAllActions()
                node.removeFromParent()
            }
            return
        }

        if isPair(a, b, Category.player, Category.coin) {
            let coinBody = a.categoryBitMask == Category.coin ? a : b
            if let node = coinBody.node {
                applyPickup(node)
                node.removeAllActions()
                node.removeFromParent()
            }
            return
        }

        if isPair(a, b, Category.player, Category.obstacle) {
            let birdBody = a.categoryBitMask == Category.obstacle ? a : b
            if let birdNode = birdBody.node {
                handleHit(contact: contact, bird: birdNode)
            }
            return
        }
    }
}

extension TubeScene {
    func handleHit(contact: SKPhysicsContact, bird: SKNode) {
        guard runState == .playing else { return }

        if shieldRemaining > 0 {
            flashPlayer()
            return
        }

        startDeathCinematic(contact: contact, bird: bird)
    }

    func flashPlayer() {
        let a = SKAction.sequence([
            .fadeAlpha(to: 0.25, duration: 0.06),
            .fadeAlpha(to: 1.0, duration: 0.10)
        ])
        player.run(.repeat(a, count: 3))

        if shieldRemaining > 0 {
            shieldBubble.removeAllActions()
            shieldBubble.run(.sequence([
                .fadeAlpha(to: 0.35, duration: 0.06),
                .fadeAlpha(to: 1.0, duration: 0.10)
            ]))
        }
    }

    func startDeathCinematic(contact: SKPhysicsContact, bird: SKNode) {
        runState = .deathCinematic
        freezeArmPose()
        freezeLegPose()
        stopTumbling(freeze: true)

        player.physicsBody?.velocity = .zero
        player.physicsBody?.isDynamic = false
        player.physicsBody?.contactTestBitMask = 0
        bird.physicsBody?.velocity = .zero
        bird.physicsBody?.isDynamic = false

        let hitW = (bird.userData?["hitW"] as? NSNumber).map { CGFloat(truncating: $0) } ?? 70
        let dx = abs(contact.contactPoint.x - bird.position.x)
        let edgeRatio = min(1, dx / max(1, hitW * 0.5))
        let emphasis = pow(edgeRatio, 1.7)

        let zoomScale = lerp(1.5, 2.1, emphasis)
        let zoomDuration = TimeInterval(lerp(0.95, 0.6, emphasis))
        let slowMin: CGFloat = 0.05
        let ringDelay: TimeInterval = 0.08
        let holdDuration: TimeInterval = 1.0
        let resumeDuration: TimeInterval = 0.7
        let zoomOutDuration: TimeInterval = 0.8
        let finishDelay: TimeInterval = 0.8

        world.removeAllActions()
        cameraNode.removeAllActions()
        let moveIn = SKAction.move(to: contact.contactPoint, duration: zoomDuration)
        let scaleIn = SKAction.scale(to: 1.0 / zoomScale, duration: zoomDuration)
        moveIn.timingMode = .easeInEaseOut
        scaleIn.timingMode = .easeInEaseOut
        let zoomIn = SKAction.group([moveIn, scaleIn])

        let moveOut = SKAction.move(to: CGPoint(x: frame.midX, y: frame.midY), duration: zoomOutDuration)
        let scaleOut = SKAction.scale(to: 1.0, duration: zoomOutDuration)
        moveOut.timingMode = .easeInEaseOut
        scaleOut.timingMode = .easeInEaseOut
        let zoomOut = SKAction.group([moveOut, scaleOut])

        let knock = SKAction.sequence([
            .wait(forDuration: ringDelay),
            .run { [weak self] in
                guard let self else { return }
                self.showImpactRing(at: contact.contactPoint)
            }
        ])

        let impact = SKAction.run { [weak self] in
            guard let self else { return }
            let hit = SKAction.group([
                .rotate(byAngle: -1.6, duration: 0.45),
                .moveBy(x: 0, y: -90, duration: 0.6)
            ])
            self.player.run(hit)

            let fallOut = SKAction.sequence([
                .wait(forDuration: 0.2),
                .moveTo(y: self.frame.minY - 220, duration: 0.55),
                .removeFromParent()
            ])
            self.player.run(fallOut)

            let birdOut = SKAction.sequence([
                .moveTo(y: self.frame.maxY + 220, duration: 0.45),
                .removeFromParent()
            ])
            bird.run(birdOut)
        }

        let slowMo = SKAction.customAction(withDuration: zoomDuration) { [weak self] _, t in
            guard let self else { return }
            let frac = max(0, min(1, t / CGFloat(zoomDuration)))
            let speed = self.lerp(1.0, slowMin, frac)
            self.world.speed = speed
            self.backgroundLayer.speed = speed
            self.farBackgroundLayer.speed = speed
        }

        let resumeTime = SKAction.customAction(withDuration: resumeDuration) { [weak self] _, t in
            guard let self else { return }
            let frac = max(0, min(1, t / CGFloat(resumeDuration)))
            let speed = self.lerp(slowMin, 1.0, frac)
            self.world.speed = speed
            self.backgroundLayer.speed = speed
            self.farBackgroundLayer.speed = speed
        }

        let fade = SKAction.sequence([
            .wait(forDuration: 0.6),
            .fadeAlpha(to: 1.0, duration: 0.8)
        ])

        run(.sequence([
            slowMo,
            .wait(forDuration: holdDuration),
            resumeTime
        ]), withKey: "deathSlowMo")

        cameraNode.run(.sequence([
            zoomIn,
            knock,
            .wait(forDuration: holdDuration),
            .wait(forDuration: resumeDuration),
            zoomOut,
            .run { [weak self] in
                self?.deathOverlay.run(fade)
            },
            .wait(forDuration: finishDelay),
            .run { [weak self] in
                self?.finishDeathSequence()
            }
        ]))

        run(.sequence([
            .wait(forDuration: zoomDuration + ringDelay + holdDuration + resumeDuration + zoomOutDuration),
            impact
        ]))
    }

    func finishDeathSequence() {
        world.speed = 1
        backgroundLayer.speed = 1
        farBackgroundLayer.speed = 1

        world.removeAllActions()
        world.setScale(1)
        world.position = .zero

        presentNameEntry()
    }

    func showImpactRing(at position: CGPoint) {
        let ring = SKShapeNode(circleOfRadius: 20)
        ring.strokeColor = SKColor(red: 0.95, green: 0.20, blue: 0.18, alpha: 0.95)
        ring.lineWidth = 4
        ring.fillColor = .clear
        ring.position = position
        ring.zPosition = player.zPosition + 3
        addChild(ring)

        let flash = SKAction.sequence([
            .fadeAlpha(to: 0.2, duration: 0.12),
            .fadeAlpha(to: 1.0, duration: 0.12)
        ])
        let pulse = SKAction.sequence([
            .scale(to: 1.18, duration: 0.2),
            .scale(to: 1.0, duration: 0.2)
        ])
        let fade = SKAction.sequence([
            .wait(forDuration: 0.8),
            .fadeAlpha(to: 0.0, duration: 0.4),
            .removeFromParent()
        ])

        ring.run(.repeatForever(flash))
        ring.run(.repeatForever(pulse))
        ring.run(fade)
    }
}
