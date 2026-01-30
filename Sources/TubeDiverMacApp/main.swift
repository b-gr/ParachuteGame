import Cocoa
import SpriteKit
import TubeDiverCore

final class GameView: SKView {
    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        scene?.mouseDown(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        scene?.mouseDragged(with: event)
    }

    override func keyDown(with event: NSEvent) {
        scene?.keyDown(with: event)
    }

    override func keyUp(with event: NSEvent) {
        scene?.keyUp(with: event)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)

        let gameplaySize = NSSize(width: 390, height: 844)
        let initialScale: CGFloat = 1.0
        let size = NSSize(width: gameplaySize.width * initialScale, height: gameplaySize.height * initialScale)
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "TubeDiver"
        window.center()
        window.contentAspectRatio = gameplaySize

        let skView = GameView(frame: NSRect(origin: .zero, size: size))
        skView.ignoresSiblingOrder = true
        skView.preferredFramesPerSecond = 60
        skView.showsFPS = true
        skView.showsNodeCount = true

        window.contentView = skView
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(skView)

        let scene = TubeScene(size: gameplaySize)
        scene.scaleMode = .aspectFit
        skView.presentScene(scene)

        app.activate(ignoringOtherApps: true)
        self.window = window
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
