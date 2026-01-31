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
        public var slowDuration: TimeInterval = 3.8

        public init() {}
    }

    enum Category {
        static let player: UInt32 = 1 << 0
        static let obstacle: UInt32 = 1 << 2
        static let pickup: UInt32 = 1 << 3
        static let coin: UInt32 = 1 << 4
    }

    enum PickupKind: CaseIterable {
        case shield
        case boost
        case slow
        case coin
    }

    enum InputMode {
        case pointer
        case keyboard
    }

    enum RunState {
        case ready
        case playing
        case deathCinematic
        case enteringName
        case showingScores
    }

    struct ScoreEntry: Codable {
        var name: String
        var score: Int
        var seconds: Int
        var coins: Int
        var dateISO8601: String
    }

    public var config = Config()

    let cameraNode = SKCameraNode()
    let farBackgroundLayer = SKNode()
    let backgroundLayer = SKNode()
    let world = SKNode()
    let hud = SKNode()

    let player = SKNode()
    let playerArt = SKNode()
    var targetX: CGFloat?

    let scoreLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    let statusLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    let hudBar = SKShapeNode()
    let scorePanel = SKShapeNode(rectOf: CGSize(width: 340, height: 420), cornerRadius: 16)
    let deathOverlay = SKShapeNode(rectOf: CGSize(width: 390, height: 844), cornerRadius: 0)

    var elapsed: TimeInterval = 0
    var lastUpdateTime: TimeInterval?
    var intensity: CGFloat = 0

    var obstacleSpawnTimer: TimeInterval = 0
    var pickupSpawnTimer: TimeInterval = 0
    var coinSpawnTimer: TimeInterval = 0
    var cloudSpawnTimer: TimeInterval = 0

    var nextMilestoneSeconds: Int = 10

    var runState: RunState = .ready

    var shieldRemaining: TimeInterval = 0
    var boostRemaining: TimeInterval = 0
    var slowRemaining: TimeInterval = 0
    var wasSlowActive = false
    var speedScale: CGFloat = 1
    var coinsThisRun: Int = 0

    var inputMode: InputMode = .pointer
    var leftKeyDown = false
    var rightKeyDown = false

    let shieldBubble = SKShapeNode()
    let shieldRim = SKShapeNode()
    var shieldWasActive = false

    let rocketArt = SKNode()
    let parachuteArt = SKNode()
    let rocketFuelBar = SKNode()
    let rocketFuelBack = SKShapeNode()
    let rocketFuelFill = SKShapeNode()

    var startParachuteVisible = true

    var nameBuffer: String = ""
    var highScores: [ScoreEntry] = []
    var lastInputEvent: String = "none"

    public override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.47, green: 0.73, blue: 0.96, alpha: 1)

        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self
        isUserInteractionEnabled = true
        #if os(macOS)
        view.window?.makeFirstResponder(view)
        #endif

        cameraNode.position = CGPoint(x: frame.midX, y: frame.midY)
        addChild(cameraNode)
        camera = cameraNode

        farBackgroundLayer.zPosition = -120
        addChild(farBackgroundLayer)

        backgroundLayer.zPosition = -100
        addChild(backgroundLayer)
        addChild(world)
        cameraNode.addChild(hud)

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
        deathOverlay.path = CGPath(rect: CGRect(x: -frame.width / 2, y: -frame.height / 2, width: frame.width, height: frame.height), transform: nil)
    }

    func resetRun() {
        runState = .ready
        world.isPaused = true
        world.speed = 1
        backgroundLayer.speed = 1
        farBackgroundLayer.speed = 1
        world.setScale(1)
        world.position = .zero
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
        wasSlowActive = false
        speedScale = 1
        coinsThisRun = 0
        shieldWasActive = false
        shieldBubble.isHidden = true
        shieldRim.isHidden = true
        rocketFuelBar.alpha = 0
        deathOverlay.alpha = 0
        deathOverlay.removeAllActions()
        cameraNode.removeAllActions()
        cameraNode.setScale(1)
        cameraNode.position = CGPoint(x: frame.midX, y: frame.midY)
        if cameraNode.parent == nil {
            addChild(cameraNode)
        }
        if hud.parent !== cameraNode {
            hud.removeFromParent()
            cameraNode.addChild(hud)
        }

        startParachuteVisible = true

        statusLabel.numberOfLines = 0
        statusLabel.alpha = 1
        statusLabel.text = "Click / Press Space to Start"
        scorePanel.isHidden = true
        hudBar.isHidden = false
        hudBar.alpha = 1
        scoreLabel.alpha = 1
        nameBuffer = ""
        nextMilestoneSeconds = 10

        world.removeAllChildren()
        world.removeAllActions()
        backgroundLayer.removeAllChildren()
        farBackgroundLayer.removeAllChildren()
        setupBackground()
        player.removeAllActions()
        player.zRotation = 0
        playerArt.zRotation = 0
        player.alpha = 1
        player.isHidden = false
        setupPlayer()
        if player.parent == nil {
            addChild(player)
        }
        layoutPlayer()
        updatePlayerModifierArt()
    }

    public override func update(_ currentTime: TimeInterval) {
        guard runState == .playing || runState == .ready || runState == .deathCinematic || runState == .enteringName || runState == .showingScores else { return }

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

        updateHudScale()
    }

    func stepReady(dt: TimeInterval) {
        ensurePlayerVisible()
        driveBackground(dt: dt)
        spawnClouds(dt: dt)
        cleanupClouds()
        updatePlayerModifierArt()
    }

    func stepPlaying(dt: TimeInterval) {
        ensurePlayerVisible()
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

    func currentScrollSpeed() -> CGFloat {
        lerp(config.baseScrollSpeed, config.maxScrollSpeed, intensity) * speedScale
    }

    func startRun() {
        guard runState == .ready else { return }

        runState = .playing
        world.isPaused = false
        statusLabel.text = ""
        lastUpdateTime = nil

        breakParachute()
    }
}
