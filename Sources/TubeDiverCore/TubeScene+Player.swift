import SpriteKit

extension TubeScene {
    func setupPlayer() {
        player.removeAllActions()
        player.removeFromParent()

        player.zPosition = 5
        player.setScale(1)
        playerArt.removeFromParent()
        player.addChild(playerArt)
        rebuildPlayerArt()
        playerArt.setScale(1)
        playerArt.alpha = 1

        player.physicsBody = SKPhysicsBody(circleOfRadius: config.playerRadius)
        player.physicsBody?.affectedByGravity = false
        player.physicsBody?.allowsRotation = false
        player.physicsBody?.linearDamping = 12
        player.physicsBody?.restitution = 0
        player.physicsBody?.usesPreciseCollisionDetection = true

        player.physicsBody?.categoryBitMask = Category.player
        player.physicsBody?.collisionBitMask = Category.obstacle
        player.physicsBody?.contactTestBitMask = Category.obstacle | Category.pickup | Category.coin

        addChild(player)
        layoutPlayer()

        setupShieldVisuals()
        setupModifierArt()
        setupRocketFuelBar()
        updatePlayerModifierArt()
    }

    func layoutPlayer() {
        player.position = CGPoint(x: frame.midX, y: frame.minY + frame.height * 0.82)
        targetX = player.position.x
    }

    func setupModifierArt() {
        rocketArt.removeAllActions()
        parachuteArt.removeAllActions()
        rocketArt.removeFromParent()
        parachuteArt.removeFromParent()

        rocketArt.addChild(makeRocketNode())
        rocketArt.setScale(1.35)
        rocketArt.position = CGPoint(x: 0, y: -10)
        rocketArt.zPosition = -2
        rocketArt.isHidden = true
        playerArt.addChild(rocketArt)

        parachuteArt.addChild(makeParachuteNode())
        parachuteArt.position = CGPoint(x: 0, y: 34)
        parachuteArt.zPosition = 2
        parachuteArt.isHidden = true
        playerArt.addChild(parachuteArt)
    }

    func setupRocketFuelBar() {
        rocketFuelBar.removeAllActions()
        rocketFuelBar.removeFromParent()
        rocketFuelBack.removeAllActions()
        rocketFuelFill.removeAllActions()

        rocketFuelBar.position = CGPoint(x: 0, y: 56)
        rocketFuelBar.zPosition = 3

        rocketFuelBack.path = CGPath(rect: CGRect(x: -32, y: -3, width: 64, height: 6), transform: nil)
        rocketFuelBack.fillColor = SKColor(white: 0.10, alpha: 0.85)
        rocketFuelBack.strokeColor = SKColor(white: 0.0, alpha: 0.4)
        rocketFuelBack.lineWidth = 1

        rocketFuelFill.path = CGPath(rect: CGRect(x: -30, y: -2, width: 60, height: 4), transform: nil)
        rocketFuelFill.fillColor = SKColor(red: 0.98, green: 0.72, blue: 0.17, alpha: 0.95)
        rocketFuelFill.strokeColor = .clear

        rocketFuelBar.addChild(rocketFuelBack)
        rocketFuelBar.addChild(rocketFuelFill)
        rocketFuelBar.alpha = 0
        playerArt.addChild(rocketFuelBar)
    }

    func rebuildPlayerArt() {
        playerArt.removeAllChildren()

        let outline = SKColor(white: 0.10, alpha: 0.95)
        let skin = SKColor(red: 0.98, green: 0.84, blue: 0.72, alpha: 1)
        let suit = SKColor(red: 0.95, green: 0.33, blue: 0.26, alpha: 1)
        let suitDark = SKColor(red: 0.80, green: 0.22, blue: 0.18, alpha: 1)
        let boot = SKColor(white: 0.12, alpha: 1)

        let head = SKShapeNode(circleOfRadius: 9)
        head.fillColor = skin
        head.strokeColor = outline
        head.lineWidth = 2
        head.position = CGPoint(x: 0, y: 16)

        let goggle = SKShapeNode(rectOf: CGSize(width: 16, height: 7), cornerRadius: 3)
        goggle.fillColor = SKColor(white: 0.15, alpha: 1)
        goggle.strokeColor = outline
        goggle.lineWidth = 2
        goggle.position = CGPoint(x: 0, y: 16)

        let lens = SKShapeNode(rectOf: CGSize(width: 12, height: 4), cornerRadius: 2)
        lens.fillColor = SKColor(red: 0.72, green: 0.90, blue: 0.98, alpha: 1)
        lens.strokeColor = .clear
        lens.alpha = 0.85
        lens.position = CGPoint(x: 0, y: 0)
        goggle.addChild(lens)

        let torso = SKShapeNode(rectOf: CGSize(width: 16, height: 22), cornerRadius: 6)
        torso.fillColor = suit
        torso.strokeColor = outline
        torso.lineWidth = 2
        torso.position = CGPoint(x: 0, y: -2)

        let belt = SKShapeNode(rectOf: CGSize(width: 16, height: 5), cornerRadius: 2)
        belt.fillColor = suitDark
        belt.strokeColor = .clear
        belt.position = CGPoint(x: 0, y: -8)

        let leftArmPivot = SKNode()
        leftArmPivot.name = "leftArm"
        leftArmPivot.position = CGPoint(x: -10, y: 2)
        let leftArm = SKShapeNode(rectOf: CGSize(width: 18, height: 6), cornerRadius: 3)
        leftArm.fillColor = suit
        leftArm.strokeColor = outline
        leftArm.lineWidth = 2
        leftArm.position = CGPoint(x: -9, y: 0)
        leftArmPivot.zRotation = 0.22
        leftArmPivot.addChild(leftArm)

        let rightArmPivot = SKNode()
        rightArmPivot.name = "rightArm"
        rightArmPivot.position = CGPoint(x: 10, y: 2)
        let rightArm = SKShapeNode(rectOf: CGSize(width: 18, height: 6), cornerRadius: 3)
        rightArm.fillColor = suit
        rightArm.strokeColor = outline
        rightArm.lineWidth = 2
        rightArm.position = CGPoint(x: 9, y: 0)
        rightArmPivot.zRotation = -0.22
        rightArmPivot.addChild(rightArm)

        let leftLeg = SKShapeNode(rectOf: CGSize(width: 6, height: 20), cornerRadius: 3)
        leftLeg.fillColor = suitDark
        leftLeg.strokeColor = outline
        leftLeg.lineWidth = 2
        leftLeg.zRotation = 0.10
        leftLeg.position = CGPoint(x: -6, y: -20)

        let rightLeg = SKShapeNode(rectOf: CGSize(width: 6, height: 20), cornerRadius: 3)
        rightLeg.fillColor = suitDark
        rightLeg.strokeColor = outline
        rightLeg.lineWidth = 2
        rightLeg.zRotation = -0.10
        rightLeg.position = CGPoint(x: 6, y: -20)

        let leftBoot = SKShapeNode(rectOf: CGSize(width: 10, height: 6), cornerRadius: 3)
        leftBoot.fillColor = boot
        leftBoot.strokeColor = outline
        leftBoot.lineWidth = 2
        leftBoot.position = CGPoint(x: 0, y: -12)
        leftLeg.addChild(leftBoot)

        let rightBoot = SKShapeNode(rectOf: CGSize(width: 10, height: 6), cornerRadius: 3)
        rightBoot.fillColor = boot
        rightBoot.strokeColor = outline
        rightBoot.lineWidth = 2
        rightBoot.position = CGPoint(x: 0, y: -12)
        rightLeg.addChild(rightBoot)

        let pack = SKShapeNode(rectOf: CGSize(width: 18, height: 14), cornerRadius: 5)
        pack.fillColor = SKColor(white: 0.20, alpha: 1)
        pack.strokeColor = outline
        pack.lineWidth = 2
        pack.position = CGPoint(x: 0, y: -4)

        playerArt.addChild(pack)
        playerArt.addChild(torso)
        torso.addChild(belt)
        playerArt.addChild(leftArmPivot)
        playerArt.addChild(rightArmPivot)
        playerArt.addChild(leftLeg)
        playerArt.addChild(rightLeg)
        playerArt.addChild(head)
        playerArt.addChild(goggle)
    }

    func setupShieldVisuals() {
        shieldBubble.removeAllActions()
        shieldRim.removeAllActions()
        shieldBubble.removeFromParent()
        shieldRim.removeFromParent()

        let r = config.playerRadius + 16
        shieldBubble.path = CGPath(ellipseIn: CGRect(x: -r, y: -r, width: r * 2, height: r * 2), transform: nil)
        shieldBubble.fillColor = SKColor(red: 0.10, green: 0.45, blue: 0.18, alpha: 0.18)
        shieldBubble.strokeColor = SKColor(red: 0.08, green: 0.55, blue: 0.20, alpha: 0.7)
        shieldBubble.lineWidth = 2
        shieldBubble.zPosition = -1
        shieldBubble.isHidden = true

        shieldRim.fillColor = .clear
        shieldRim.strokeColor = SKColor(red: 0.08, green: 0.55, blue: 0.20, alpha: 0.95)
        shieldRim.lineWidth = 6
        shieldRim.lineCap = .round
        shieldRim.zPosition = 0
        shieldRim.isHidden = true

        player.addChild(shieldBubble)
        player.addChild(shieldRim)
    }

    func makeParachuteNode() -> SKNode {
        let node = SKNode()
        let outline = SKColor(white: 0.10, alpha: 0.95)
        let canopy = SKColor(red: 0.98, green: 0.82, blue: 0.22, alpha: 1)

        let canopyPath = CGMutablePath()
        canopyPath.move(to: CGPoint(x: -40, y: 0))
        canopyPath.addQuadCurve(to: CGPoint(x: 40, y: 0), control: CGPoint(x: 0, y: 34))
        canopyPath.addQuadCurve(to: CGPoint(x: -40, y: 0), control: CGPoint(x: 0, y: 10))

        let canopyShape = SKShapeNode(path: canopyPath)
        canopyShape.fillColor = canopy
        canopyShape.strokeColor = outline
        canopyShape.lineWidth = 2
        canopyShape.position = CGPoint(x: 0, y: 0)

        let strapLeft = SKShapeNode()
        let p1 = CGMutablePath()
        p1.move(to: CGPoint(x: -20, y: 0))
        p1.addLine(to: CGPoint(x: -6, y: -38))
        strapLeft.path = p1
        strapLeft.strokeColor = outline
        strapLeft.lineWidth = 2

        let strapRight = SKShapeNode()
        let p2 = CGMutablePath()
        p2.move(to: CGPoint(x: 20, y: 0))
        p2.addLine(to: CGPoint(x: 6, y: -38))
        strapRight.path = p2
        strapRight.strokeColor = outline
        strapRight.lineWidth = 2

        node.addChild(canopyShape)
        node.addChild(strapLeft)
        node.addChild(strapRight)
        return node
    }

    func makeRocketNode() -> SKNode {
        let node = SKNode()
        let outline = SKColor(white: 0.10, alpha: 0.95)

        let body = SKShapeNode(rectOf: CGSize(width: 10, height: 24), cornerRadius: 5)
        body.fillColor = SKColor(white: 0.92, alpha: 1)
        body.strokeColor = outline
        body.lineWidth = 2
        body.position = CGPoint(x: 0, y: 0)

        let nosePath = CGMutablePath()
        nosePath.move(to: CGPoint(x: -5, y: 12))
        nosePath.addLine(to: CGPoint(x: 5, y: 12))
        nosePath.addLine(to: CGPoint(x: 0, y: 20))
        nosePath.closeSubpath()
        let nose = SKShapeNode(path: nosePath)
        nose.fillColor = SKColor(red: 0.95, green: 0.33, blue: 0.26, alpha: 1)
        nose.strokeColor = outline
        nose.lineWidth = 2

        let finLeftPath = CGMutablePath()
        finLeftPath.move(to: CGPoint(x: -5, y: -12))
        finLeftPath.addLine(to: CGPoint(x: -12, y: -16))
        finLeftPath.addLine(to: CGPoint(x: -5, y: -6))
        finLeftPath.closeSubpath()
        let finLeft = SKShapeNode(path: finLeftPath)
        finLeft.fillColor = SKColor(red: 0.95, green: 0.33, blue: 0.26, alpha: 1)
        finLeft.strokeColor = outline
        finLeft.lineWidth = 2

        let finRightPath = CGMutablePath()
        finRightPath.move(to: CGPoint(x: 5, y: -12))
        finRightPath.addLine(to: CGPoint(x: 12, y: -16))
        finRightPath.addLine(to: CGPoint(x: 5, y: -6))
        finRightPath.closeSubpath()
        let finRight = SKShapeNode(path: finRightPath)
        finRight.fillColor = SKColor(red: 0.95, green: 0.33, blue: 0.26, alpha: 1)
        finRight.strokeColor = outline
        finRight.lineWidth = 2

        let flamePath = CGMutablePath()
        flamePath.move(to: CGPoint(x: 0, y: -22))
        flamePath.addQuadCurve(to: CGPoint(x: -6, y: -14), control: CGPoint(x: -5, y: -20))
        flamePath.addQuadCurve(to: CGPoint(x: 0, y: -8), control: CGPoint(x: -2, y: -10))
        flamePath.addQuadCurve(to: CGPoint(x: 6, y: -14), control: CGPoint(x: 2, y: -10))
        flamePath.addQuadCurve(to: CGPoint(x: 0, y: -22), control: CGPoint(x: 5, y: -20))
        flamePath.closeSubpath()
        let flame = SKShapeNode(path: flamePath)
        flame.fillColor = SKColor(red: 0.98, green: 0.72, blue: 0.17, alpha: 0.95)
        flame.strokeColor = .clear
        flame.name = "flame"
        flame.run(.repeatForever(.sequence([
            .scale(to: 1.15, duration: 0.10),
            .scale(to: 0.95, duration: 0.10)
        ])))

        node.addChild(flame)
        node.addChild(body)
        node.addChild(nose)
        node.addChild(finLeft)
        node.addChild(finRight)
        node.zRotation = CGFloat.pi
        return node
    }

    func updatePowerupTimers(dt: TimeInterval) {
        if boostRemaining > 0 {
            boostRemaining = max(0, boostRemaining - dt)
        }
        if slowRemaining > 0 {
            slowRemaining = max(0, slowRemaining - dt)
        }
        if shieldRemaining > 0 {
            shieldRemaining = max(0, shieldRemaining - dt)
        }

        var scale: CGFloat = 1
        if boostRemaining > 0 { scale *= 1.55 }
        if slowRemaining > 0 { scale *= 0.65 }
        speedScale = scale

        updateShieldVisuals()
        updatePlayerModifierArt()
        updateShieldCollisionMask()
    }

    func updateShieldCollisionMask() {
        guard let body = player.physicsBody else { return }
        if shieldRemaining > 0 {
            body.collisionBitMask = 0
            body.contactTestBitMask = Category.pickup | Category.coin
        } else {
            body.collisionBitMask = Category.obstacle
            body.contactTestBitMask = Category.obstacle | Category.pickup | Category.coin
        }

        world.enumerateChildNodes(withName: "obstacle") { node, _ in
            guard let obstacleBody = node.physicsBody else { return }
            if self.shieldRemaining > 0 {
                obstacleBody.collisionBitMask = 0
                obstacleBody.contactTestBitMask = 0
            } else {
                obstacleBody.collisionBitMask = Category.player
                obstacleBody.contactTestBitMask = Category.player
            }
        }
    }

    func updatePlayerModifierArt() {
        rocketArt.isHidden = !(boostRemaining > 0)
        parachuteArt.isHidden = !((slowRemaining > 0) || (runState == .ready && startParachuteVisible))
        updateRocketFuelBar()
        updateArmFlail()
    }

    func armBaseAngles() -> (left: CGFloat, right: CGFloat) {
        (1.92 - .pi, 1.22)
    }

    func updateArmFlail() {
        guard let leftArm = playerArt.childNode(withName: "leftArm"),
              let rightArm = playerArt.childNode(withName: "rightArm") else { return }

        if runState == .deathCinematic {
            leftArm.removeAction(forKey: "flail")
            rightArm.removeAction(forKey: "flail")
            return
        }

        let base = armBaseAngles()
        let baseLeft = base.left
        let baseRight = base.right
        let shouldFlail = runState == .playing && slowRemaining <= 0

        if shouldFlail {
            if leftArm.action(forKey: "flail") == nil {
                let leftSeq = SKAction.sequence([
                    .rotate(toAngle: baseLeft + 0.55, duration: 0.10),
                    .rotate(toAngle: baseLeft - 0.45, duration: 0.16),
                    .rotate(toAngle: baseLeft + 0.35, duration: 0.12)
                ])
                leftSeq.timingMode = .easeInEaseOut
                leftArm.run(.repeatForever(leftSeq), withKey: "flail")
            }
            if rightArm.action(forKey: "flail") == nil {
                let rightSeq = SKAction.sequence([
                    .rotate(toAngle: baseRight - 0.55, duration: 0.11),
                    .rotate(toAngle: baseRight + 0.45, duration: 0.15),
                    .rotate(toAngle: baseRight - 0.35, duration: 0.13)
                ])
                rightSeq.timingMode = .easeInEaseOut
                rightArm.run(.repeatForever(rightSeq), withKey: "flail")
            }
        } else {
            leftArm.removeAction(forKey: "flail")
            rightArm.removeAction(forKey: "flail")
            leftArm.zRotation = baseLeft
            rightArm.zRotation = baseRight
        }
    }

    func stopArmFlail(slowly: Bool) {
        guard let leftArm = playerArt.childNode(withName: "leftArm"),
              let rightArm = playerArt.childNode(withName: "rightArm") else { return }

        let base = armBaseAngles()
        leftArm.removeAction(forKey: "flail")
        rightArm.removeAction(forKey: "flail")

        if slowly {
            let leftSettle = SKAction.rotate(toAngle: base.left, duration: 0.6)
            let rightSettle = SKAction.rotate(toAngle: base.right, duration: 0.6)
            leftSettle.timingMode = .easeOut
            rightSettle.timingMode = .easeOut
            leftArm.run(leftSettle, withKey: "flailSettle")
            rightArm.run(rightSettle, withKey: "flailSettle")
        } else {
            leftArm.zRotation = base.left
            rightArm.zRotation = base.right
        }
    }

    func freezeArmPose() {
        guard let leftArm = playerArt.childNode(withName: "leftArm"),
              let rightArm = playerArt.childNode(withName: "rightArm") else { return }

        leftArm.removeAction(forKey: "flail")
        rightArm.removeAction(forKey: "flail")
    }

    func ensurePlayerVisible() {
        if player.parent == nil || playerArt.children.isEmpty {
            setupPlayer()
        }
        player.isHidden = false
        player.alpha = 1
    }

    func updateRocketFuelBar() {
        guard boostRemaining > 0 else {
            rocketFuelBar.alpha = 0
            rocketFuelBar.removeAllActions()
            return
        }

        let frac = max(0, CGFloat(boostRemaining / config.boostDuration))
        let width = 60 * frac
        let rect = CGRect(x: -30, y: -2, width: width, height: 4)
        rocketFuelFill.path = CGPath(rect: rect, transform: nil)

        rocketFuelBar.alpha = 1
        if boostRemaining < 0.2 {
            if rocketFuelBar.action(forKey: "flash") == nil {
                let flash = SKAction.sequence([
                    .fadeAlpha(to: 0.4, duration: 0.12),
                    .fadeAlpha(to: 1.0, duration: 0.12)
                ])
                rocketFuelBar.run(.repeatForever(flash), withKey: "flash")
            }
        } else {
            rocketFuelBar.removeAction(forKey: "flash")
            rocketFuelBar.alpha = 1
        }
    }

    func drivePlayer(dt: TimeInterval) {
        switch inputMode {
        case .pointer:
            guard let targetX else { return }
            let dx = targetX - player.position.x
            let response: CGFloat = 18
            let vx = dx * response
            player.physicsBody?.velocity = CGVector(dx: vx, dy: 0)
        case .keyboard:
            let axis: CGFloat = (rightKeyDown ? 1 : 0) + (leftKeyDown ? -1 : 0)
            let maxSpeed: CGFloat = 520
            player.physicsBody?.velocity = CGVector(dx: axis * maxSpeed, dy: 0)
        }
    }

    func applyHorizontalBounds() {
        let allowOffscreen: CGFloat
        switch inputMode {
        case .pointer:
            allowOffscreen = config.playerRadius * 0.5
        case .keyboard:
            allowOffscreen = config.playerRadius
        }

        let minX = frame.minX - allowOffscreen
        let maxX = frame.maxX + allowOffscreen

        #if os(iOS)
        if player.position.x < frame.minX - config.playerRadius {
            player.position.x = frame.maxX + config.playerRadius
        } else if player.position.x > frame.maxX + config.playerRadius {
            player.position.x = frame.minX - config.playerRadius
        }
        #else
        if inputMode == .keyboard {
            if player.position.x < frame.minX - config.playerRadius {
                player.position.x = frame.maxX + config.playerRadius
            } else if player.position.x > frame.maxX + config.playerRadius {
                player.position.x = frame.minX - config.playerRadius
            }
        } else {
            if player.position.x < minX { player.position.x = minX }
            if player.position.x > maxX { player.position.x = maxX }
        }
        #endif
    }

    func breakParachute() {
        guard startParachuteVisible else { return }
        startParachuteVisible = false
        updatePlayerModifierArt()

        let canopy = makeParachuteNode()
        canopy.setScale(0.95)

        let local = parachuteArt.position
        let scenePos = playerArt.convert(local, to: self)
        canopy.position = scenePos
        canopy.zPosition = player.zPosition + 2
        addChild(canopy)

        let shake = SKAction.sequence([
            .rotate(byAngle: 0.12, duration: 0.06),
            .rotate(byAngle: -0.20, duration: 0.06),
            .rotate(byAngle: 0.14, duration: 0.06),
            .rotate(toAngle: 0, duration: 0.06)
        ])

        let snap = SKAction.run {
            let tear = SKShapeNode()
            let p = CGMutablePath()
            p.move(to: CGPoint(x: -10, y: -2))
            p.addLine(to: CGPoint(x: -2, y: 6))
            p.addLine(to: CGPoint(x: 6, y: -4))
            tear.path = p
            tear.strokeColor = SKColor(red: 0.98, green: 0.22, blue: 0.20, alpha: 0.9)
            tear.lineWidth = 3
            tear.lineCap = .round
            tear.position = .zero
            canopy.addChild(tear)
            tear.run(.sequence([
                .fadeAlpha(to: 0.0, duration: 0.28),
                .removeFromParent()
            ]))
        }

        let drift = SKAction.group([
            .moveBy(x: CGFloat.random(in: -80...80), y: 220, duration: 0.9),
            .fadeAlpha(to: 0.0, duration: 0.9),
            .scale(to: 0.75, duration: 0.9),
            .rotate(byAngle: CGFloat.random(in: -0.6...0.6), duration: 0.9)
        ])

        canopy.run(.sequence([
            shake,
            snap,
            drift,
            .removeFromParent()
        ]))
    }
}
