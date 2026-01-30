import Foundation
import SpriteKit

@MainActor
public final class TubeScene: SKScene {
    public struct Config {
        public var corridorInset: CGFloat = 72
        public var playerRadius: CGFloat = 18
        public var baseScrollSpeed: CGFloat = 160
        public var maxScrollSpeed: CGFloat = 760
        public var difficultyRampPerSecond: CGFloat = 0.0065
        public var birdSpawnBaseInterval: TimeInterval = 1.05
        public var birdSpawnMinInterval: TimeInterval = 0.42
        public var powerupSpawnInterval: TimeInterval = 9.0
        public var coinSpawnInterval: TimeInterval = 1.35
        public var cloudSpawnInterval: TimeInterval = 1.8
        public var shieldDuration: TimeInterval = 6.0
        public var boostDuration: TimeInterval = 2.2
        public var slowDuration: TimeInterval = 2.8

        public init() {}
    }

    private enum Category {
        static let player: UInt32 = 1 << 0
        static let obstacle: UInt32 = 1 << 2
        static let pickup: UInt32 = 1 << 3
        static let coin: UInt32 = 1 << 4
    }

    private enum PickupKind: CaseIterable {
        case shield
        case boost
        case slow
        case coin
    }

    private enum InputMode {
        case pointer
        case keyboard
    }

    private enum RunState {
        case ready
        case playing
        case deathCinematic
        case enteringName
        case showingScores
    }

    private struct ScoreEntry: Codable {
        var name: String
        var score: Int
        var seconds: Int
        var coins: Int
        var dateISO8601: String
    }

    public var config = Config()

    private let cameraNode = SKCameraNode()
    private let farBackgroundLayer = SKNode()
    private let backgroundLayer = SKNode()
    private let world = SKNode()
    private let hud = SKNode()

    private let player = SKNode()
    private let playerArt = SKNode()
    private var targetX: CGFloat?

    private let scoreLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let statusLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let hudBar = SKShapeNode()
    private let scorePanel = SKShapeNode(rectOf: CGSize(width: 340, height: 420), cornerRadius: 16)
    private let deathOverlay = SKShapeNode(rectOf: CGSize(width: 390, height: 844), cornerRadius: 0)

    private var elapsed: TimeInterval = 0
    private var lastUpdateTime: TimeInterval?
    private var intensity: CGFloat = 0

    private var obstacleSpawnTimer: TimeInterval = 0
    private var pickupSpawnTimer: TimeInterval = 0
    private var coinSpawnTimer: TimeInterval = 0
    private var cloudSpawnTimer: TimeInterval = 0

    private var nextMilestoneSeconds: Int = 10

    private var runState: RunState = .ready

    private var shieldRemaining: TimeInterval = 0
    private var boostRemaining: TimeInterval = 0
    private var slowRemaining: TimeInterval = 0
    private var speedScale: CGFloat = 1
    private var coinsThisRun: Int = 0

    private var inputMode: InputMode = .pointer
    private var leftKeyDown = false
    private var rightKeyDown = false

    private let shieldBubble = SKShapeNode()
    private let shieldRim = SKShapeNode()
    private var shieldWasActive = false

    private let rocketArt = SKNode()
    private let parachuteArt = SKNode()
    private let rocketFuelBar = SKNode()
    private let rocketFuelBack = SKShapeNode()
    private let rocketFuelFill = SKShapeNode()

    private var startParachuteVisible = true

    private var nameBuffer: String = ""
    private var highScores: [ScoreEntry] = []

    public override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.47, green: 0.73, blue: 0.96, alpha: 1)

        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self

        cameraNode.position = CGPoint(x: frame.midX, y: frame.midY)
        addChild(cameraNode)
        camera = cameraNode

        farBackgroundLayer.zPosition = -120
        addChild(farBackgroundLayer)

        backgroundLayer.zPosition = -100
        addChild(backgroundLayer)
        addChild(world)
        addChild(hud)

        setupBackground()
        setupPlayer()
        setupHUD()
        loadHighScores()
        setupDeathOverlay()
        resetRun()
    }

    public override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        setupBackground()
        layoutHUD()
        layoutPlayer()
        cameraNode.position = CGPoint(x: frame.midX, y: frame.midY)
        deathOverlay.path = CGPath(rect: CGRect(x: frame.midX - frame.width / 2, y: frame.midY - frame.height / 2, width: frame.width, height: frame.height), transform: nil)
    }

    private func setupBackground() {
        childNode(withName: "tube")?.removeFromParent()
        physicsBody = nil

        if backgroundLayer.children.isEmpty {
            for i in 0..<7 {
                let y = frame.minY + CGFloat(i) * (frame.height / 6.0)
                spawnCloud(y: y)
            }
        }
    }

    private func setupPlayer() {
        player.removeAllActions()
        player.removeFromParent()

        player.zPosition = 5
        player.addChild(playerArt)
        rebuildPlayerArt()

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

    private func setupModifierArt() {
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

    private func setupRocketFuelBar() {
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

    private func rebuildPlayerArt() {
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

        let leftArm = SKShapeNode(rectOf: CGSize(width: 18, height: 6), cornerRadius: 3)
        leftArm.fillColor = suit
        leftArm.strokeColor = outline
        leftArm.lineWidth = 2
        leftArm.zRotation = 0.22
        leftArm.position = CGPoint(x: -14, y: 2)

        let rightArm = SKShapeNode(rectOf: CGSize(width: 18, height: 6), cornerRadius: 3)
        rightArm.fillColor = suit
        rightArm.strokeColor = outline
        rightArm.lineWidth = 2
        rightArm.zRotation = -0.22
        rightArm.position = CGPoint(x: 14, y: 2)

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
        playerArt.addChild(leftArm)
        playerArt.addChild(rightArm)
        playerArt.addChild(leftLeg)
        playerArt.addChild(rightLeg)
        playerArt.addChild(head)
        playerArt.addChild(goggle)
    }

    private func setupShieldVisuals() {
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

    private func makeParachuteNode() -> SKNode {
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

    private func makeRocketNode() -> SKNode {
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

    private func setupHUD() {
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

    private func setupDeathOverlay() {
        deathOverlay.fillColor = SKColor(white: 0.0, alpha: 1)
        deathOverlay.strokeColor = .clear
        deathOverlay.alpha = 0
        deathOverlay.zPosition = 40
        deathOverlay.path = CGPath(rect: CGRect(x: frame.midX - frame.width / 2, y: frame.midY - frame.height / 2, width: frame.width, height: frame.height), transform: nil)
        addChild(deathOverlay)
    }

    private func layoutHUD() {
        scoreLabel.position = CGPoint(x: frame.minX + 18, y: frame.maxY - 14)
        statusLabel.position = CGPoint(x: frame.midX, y: frame.midY)
        let barHeight = scoreLabel.fontSize + 12
        hudBar.path = CGPath(rect: CGRect(x: frame.midX - frame.width / 2, y: frame.maxY - barHeight, width: frame.width, height: barHeight), transform: nil)
        hudBar.position = .zero
        scorePanel.position = CGPoint(x: frame.midX, y: frame.midY)
    }

    private func layoutPlayer() {
        player.position = CGPoint(x: frame.midX, y: frame.minY + frame.height * 0.82)
        targetX = player.position.x
    }

    private func resetRun() {
        runState = .ready
        world.isPaused = true
        world.speed = 1
        backgroundLayer.speed = 1
        farBackgroundLayer.speed = 1
        elapsed = 0
        lastUpdateTime = nil
        intensity = 0

        obstacleSpawnTimer = 0
        pickupSpawnTimer = 0
        coinSpawnTimer = 0
        cloudSpawnTimer = 0

        shieldRemaining = 0
        boostRemaining = 0
        slowRemaining = 0
        speedScale = 1
        coinsThisRun = 0
        shieldWasActive = false
        shieldBubble.isHidden = true
        shieldRim.isHidden = true
        rocketFuelBar.alpha = 0
        deathOverlay.alpha = 0
        cameraNode.removeAllActions()
        cameraNode.setScale(1)
        cameraNode.position = CGPoint(x: frame.midX, y: frame.midY)

        startParachuteVisible = true

        statusLabel.numberOfLines = 0
        statusLabel.text = "Click / Press Space to Start"
        scorePanel.isHidden = true
        hudBar.isHidden = false
        nameBuffer = ""
        nextMilestoneSeconds = 10

        world.removeAllChildren()
        backgroundLayer.removeAllChildren()
        farBackgroundLayer.removeAllChildren()
        setupBackground()
        player.removeAllActions()
        player.zRotation = 0
        playerArt.zRotation = 0
        player.physicsBody?.velocity = .zero
        player.physicsBody?.isDynamic = true
        if player.parent == nil {
            setupPlayer()
        }
        layoutPlayer()
        updatePlayerModifierArt()
    }

    public override func update(_ currentTime: TimeInterval) {
        guard runState == .playing || runState == .ready else { return }

        guard let lastUpdateTime else {
            self.lastUpdateTime = currentTime
            return
        }

        let dt = min(1.0 / 30.0, currentTime - lastUpdateTime)
        self.lastUpdateTime = currentTime

        switch runState {
        case .ready:
            stepReady(dt: dt)
        case .playing:
            stepPlaying(dt: dt)
        case .deathCinematic, .enteringName, .showingScores:
            break
        }
    }

    private func stepReady(dt: TimeInterval) {
        driveBackground(dt: dt)
        spawnClouds(dt: dt)
        cleanupClouds()
        updatePlayerModifierArt()
    }

    private func stepPlaying(dt: TimeInterval) {
        elapsed += dt
        intensity = min(1, intensity + config.difficultyRampPerSecond * CGFloat(dt))

        updatePowerupTimers(dt: dt)
        drivePlayer(dt: dt)
        applyHorizontalBounds()
        driveWorld(dt: dt)
        driveBackground(dt: dt)
        spawnThings(dt: dt)
        spawnClouds(dt: dt)
        updateMilestones()
        updateHUD()
        cleanupWorld()
        cleanupClouds()
    }

    private func updatePowerupTimers(dt: TimeInterval) {
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
    }

    private func updatePlayerModifierArt() {
        rocketArt.isHidden = !(boostRemaining > 0)
        parachuteArt.isHidden = !((slowRemaining > 0) || (runState == .ready && startParachuteVisible))
        updateRocketFuelBar()
    }

    private func updateRocketFuelBar() {
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

    private func currentScrollSpeed() -> CGFloat {
        lerp(config.baseScrollSpeed, config.maxScrollSpeed, intensity) * speedScale
    }

    private func drivePlayer(dt: TimeInterval) {
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

    private func applyHorizontalBounds() {
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

    private func driveWorld(dt: TimeInterval) {
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

    private func spawnThings(dt: TimeInterval) {
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

    private func spawnObstacle() {
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

    private func makeBirdNode() -> SKNode {
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
            .init(body: SKColor(red: 0.24, green: 0.30, blue: 0.34, alpha: 1), wing: SKColor(red: 0.16, green: 0.20, blue: 0.24, alpha: 1), belly: SKColor(red: 0.55, green: 0.58, blue: 0.62, alpha: 1), beak: SKColor(red: 0.98, green: 0.72, blue: 0.17, alpha: 1)),
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

    private func spawnPickup() {
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

    private func makePowerupIcon(kind: PickupKind) -> SKNode {
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

    private func spawnCoin() {
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

    private func updateMilestones() {
        let s = Int(elapsed)
        while s >= nextMilestoneSeconds {
            spawnMilestonePlane(seconds: nextMilestoneSeconds)
            nextMilestoneSeconds = nextMilestone(after: nextMilestoneSeconds)
        }
    }

    private func nextMilestone(after value: Int) -> Int {
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

    private func spawnMilestonePlane(seconds: Int) {
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

    private func updateHUD() {
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

    private func cleanupWorld() {
        let cutoffY = frame.maxY + 260
        world.children.forEach { node in
            let offscreenX = node.position.x < frame.minX - 260 || node.position.x > frame.maxX + 260
            if node.position.y > cutoffY || offscreenX {
                node.removeAllActions()
                node.removeFromParent()
            }
        }
    }

    private func driveBackground(dt: TimeInterval) {
        let cloudSpeed = lerp(14, 26, intensity)
        backgroundLayer.enumerateChildNodes(withName: "cloud") { node, _ in
            node.position.y += cloudSpeed * CGFloat(dt)
            if let dx = (node.userData?["dx"] as? NSNumber)?.doubleValue {
                node.position.x += CGFloat(dx) * CGFloat(dt)
            }
        }
    }

    private func spawnClouds(dt: TimeInterval) {
        cloudSpawnTimer += dt
        while cloudSpawnTimer >= config.cloudSpawnInterval {
            cloudSpawnTimer -= config.cloudSpawnInterval
            spawnCloud(y: frame.minY - 90)
        }
    }

    private func cleanupClouds() {
        let cutoffY = frame.maxY + 220
        backgroundLayer.children.forEach { node in
            if node.name == "cloud" && node.position.y > cutoffY {
                node.removeAllActions()
                node.removeFromParent()
            }
        }
    }

    private func spawnCloud(y: CGFloat) {
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

    private func handleHit(contact: SKPhysicsContact, bird: SKNode) {
        guard runState == .playing else { return }

        if shieldRemaining > 0 {
            flashPlayer()
            return
        }

        startDeathCinematic(contact: contact, bird: bird)
    }

    private func flashPlayer() {
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

    private func startDeathCinematic(contact: SKPhysicsContact, bird: SKNode) {
        runState = .deathCinematic

        world.speed = 0.2
        backgroundLayer.speed = 0.2
        farBackgroundLayer.speed = 0.2

        player.physicsBody?.velocity = .zero
        player.physicsBody?.isDynamic = false
        bird.physicsBody?.velocity = .zero
        bird.physicsBody?.isDynamic = false

        let hitW = (bird.userData?["hitW"] as? NSNumber).map { CGFloat(truncating: $0) } ?? 70
        let dx = abs(contact.contactPoint.x - bird.position.x)
        let edgeRatio = min(1, dx / max(1, hitW * 0.5))
        let emphasis = pow(edgeRatio, 1.7)

        let zoomScale = lerp(1.5, 2.1, emphasis)
        let zoomDuration = TimeInterval(lerp(1.0, 0.55, emphasis))
        let cameraScale = 1 / zoomScale

        cameraNode.removeAllActions()
        let move = SKAction.move(to: contact.contactPoint, duration: zoomDuration)
        let scale = SKAction.scale(to: cameraScale, duration: zoomDuration)
        move.timingMode = .easeInEaseOut
        scale.timingMode = .easeInEaseOut

        let zoom = SKAction.group([move, scale])
        let knock = SKAction.run { [weak self] in
            guard let self else { return }
            self.showImpactRing(at: contact.contactPoint)
        }

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

        let fade = SKAction.sequence([
            .wait(forDuration: 0.6),
            .fadeAlpha(to: 1.0, duration: 0.8)
        ])

        cameraNode.run(.sequence([
            zoom,
            knock,
            .wait(forDuration: 0.45),
            impact,
            .run { [weak self] in
                self?.deathOverlay.run(fade)
            },
            .wait(forDuration: 1.2),
            .run { [weak self] in
                self?.finishDeathSequence()
            }
        ]))
    }

    private func finishDeathSequence() {
        world.speed = 1
        backgroundLayer.speed = 1
        farBackgroundLayer.speed = 1

        cameraNode.removeAllActions()
        cameraNode.setScale(1)
        cameraNode.position = CGPoint(x: frame.midX, y: frame.midY)

        presentNameEntry()
    }

    private func showImpactRing(at position: CGPoint) {
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

    private func presentNameEntry() {
        runState = .enteringName
        world.isPaused = true

        let seconds = Int(elapsed)
        let multiplier = 1 + coinsThisRun
        let score = seconds * multiplier

        scorePanel.isHidden = false
        statusLabel.numberOfLines = 0
        statusLabel.text = "Game Over\nTime: \(seconds)s  Coins: \(coinsThisRun)  x\(multiplier)\nScore: \(score)\n\nEnter your name and press Return:\n\(nameBuffer.isEmpty ? "_" : nameBuffer)"
    }

    private func startRun() {
        guard runState == .ready else { return }

        runState = .playing
        world.isPaused = false
        statusLabel.text = ""

        breakParachute()
    }

    private func breakParachute() {
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

    private func applyPickup(_ node: SKNode) {
        guard let kindString = node.userData?["kind"] as? String else { return }
        switch kindString {
        case kindKey(.shield):
            shieldRemaining = config.shieldDuration
            shieldWasActive = true
            shieldBubble.isHidden = false
            shieldRim.isHidden = false
            updateShieldVisuals(force: true)
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

    private func updateShieldVisuals(force: Bool = false) {
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

    #if os(macOS)
    public override func mouseDown(with event: NSEvent) {
        if runState == .showingScores {
            resetRun()
            return
        }
        if runState == .ready {
            startRun()
            return
        }
        if runState != .playing { return }
        inputMode = .pointer
        targetX = convertPoint(fromView: event.locationInWindow).x
    }

    public override func mouseDragged(with event: NSEvent) {
        if runState != .playing { return }
        inputMode = .pointer
        targetX = convertPoint(fromView: event.locationInWindow).x
    }

    public override func keyDown(with event: NSEvent) {
        if runState == .enteringName {
            handleNameEntryKeyDown(event)
            return
        }

        if runState == .showingScores {
            if event.keyCode == 36 { // return
                resetRun()
            }
            return
        }

        if runState == .ready {
            if event.keyCode == 49 { // space
                startRun()
            }
            return
        }

        inputMode = .keyboard
        switch event.keyCode {
        case 123:
            leftKeyDown = true
        case 124:
            rightKeyDown = true
        default:
            break
        }
    }

    public override func keyUp(with event: NSEvent) {
        if runState != .playing { return }
        switch event.keyCode {
        case 123:
            leftKeyDown = false
        case 124:
            rightKeyDown = false
        default:
            break
        }
    }
    #else
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if runState == .ready {
            startRun()
            return
        }
        if runState != .playing { return }
        inputMode = .pointer
        targetX = touches.first.map { $0.location(in: self).x }
    }

    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if runState != .playing { return }
        inputMode = .pointer
        targetX = touches.first.map { $0.location(in: self).x }
    }
    #endif

    private func handleNameEntryKeyDown(_ event: NSEvent) {
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

    private func refreshNamePrompt() {
        guard runState == .enteringName else { return }
        let seconds = Int(elapsed)
        let multiplier = 1 + coinsThisRun
        let score = seconds * multiplier
        scorePanel.isHidden = false
        statusLabel.numberOfLines = 0
        statusLabel.text = "Game Over\nTime: \(seconds)s  Coins: \(coinsThisRun)  x\(multiplier)\nScore: \(score)\n\nEnter your name and press Return:\n\(nameBuffer.isEmpty ? "_" : nameBuffer)"
    }

    private func currentScoreEntry() -> ScoreEntry {
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

    private func saveCurrentScore() {
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

    private func leaderboardText(current: ScoreEntry) -> String {
        var lines: [String] = []
        lines.append("Saved score for \(current.name)")
        lines.append("\nHigh Scores")
        for (i, e) in highScores.enumerated() {
            lines.append("\(i + 1). \(e.name)  \(e.score)  (\(e.seconds)s, \(e.coins) coins)")
        }
        lines.append("\nClick (or press Return) to restart")
        return lines.joined(separator: "\n")
    }

    private func loadHighScores() {
        let defaults = UserDefaults.standard
        guard let data = defaults.data(forKey: "TubeDiverHighScores") else { return }
        do {
            highScores = try JSONDecoder().decode([ScoreEntry].self, from: data)
        } catch {
            highScores = []
        }
    }

    private func persistHighScores() {
        do {
            let data = try JSONEncoder().encode(highScores)
            UserDefaults.standard.set(data, forKey: "TubeDiverHighScores")
        } catch {
            // ignore for prototype
        }
    }

    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        a + (b - a) * max(0, min(1, t))
    }

    private func isPair(_ a: SKPhysicsBody, _ b: SKPhysicsBody, _ ca: UInt32, _ cb: UInt32) -> Bool {
        (a.categoryBitMask == ca && b.categoryBitMask == cb) || (a.categoryBitMask == cb && b.categoryBitMask == ca)
    }

    private func kindKey(_ kind: PickupKind) -> String {
        switch kind {
        case .shield: return "shield"
        case .boost: return "boost"
        case .slow: return "slow"
        case .coin: return "coin"
        }
    }
}

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
