import SpriteKit

extension TubeScene {
    func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        a + (b - a) * max(0, min(1, t))
    }

    func isPair(_ a: SKPhysicsBody, _ b: SKPhysicsBody, _ ca: UInt32, _ cb: UInt32) -> Bool {
        (a.categoryBitMask == ca && b.categoryBitMask == cb) || (a.categoryBitMask == cb && b.categoryBitMask == ca)
    }

    func kindKey(_ kind: PickupKind) -> String {
        switch kind {
        case .shield: return "shield"
        case .boost: return "boost"
        case .slow: return "slow"
        case .coin: return "coin"
        }
    }
}
