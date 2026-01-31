import SwiftUI
import SpriteKit
import TubeDiverCore
import UIKit

@main
struct TubeDiveriOSApp: App {
    var body: some Scene {
        WindowGroup {
            TubeDiveriOSRootView()
        }
    }
}

final class GameSession: ObservableObject {
    let scene: TubeScene
    @Published var isEnteringName = false
    @Published var name = ""
    @Published var isEditing = false

    init() {
        let size = UIScreen.main.bounds.size
        let scene = TubeScene(size: size)
        scene.scaleMode = .resizeFill
        self.scene = scene
    }

    @MainActor
    func syncFromScene() {
        let entering = scene.isEnteringName
        if entering != isEnteringName {
            isEnteringName = entering
        }
        if entering && !isEditing {
            let current = scene.currentNameBuffer()
            if current != name {
                name = current
            }
        }
        if !entering && name.isEmpty == false {
            name = ""
        }
    }

    @MainActor
    func updateName() {
        scene.updateNameBuffer(name)
    }

    @MainActor
    func submit() {
        scene.submitNameEntry()
    }
}

struct TubeDiveriOSRootView: View {
    @StateObject private var session = GameSession()
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            SpriteView(scene: session.scene)
                .ignoresSafeArea()

            if session.isEnteringName {
                VStack(spacing: 12) {
                    Text("Enter your name")
                        .font(.headline)
                        .foregroundStyle(.white)

                    TextField("Name", text: $session.name, onEditingChanged: { editing in
                        session.isEditing = editing
                    })
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 16)
                    .frame(height: 44)
                    .background(Color.white.opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .onChange(of: session.name) { _ in
                        Task { @MainActor in
                            session.updateName()
                        }
                    }
                    .onSubmit {
                        Task { @MainActor in
                            session.submit()
                        }
                    }

                    Button("Done") {
                        Task { @MainActor in
                            session.submit()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .padding(20)
                .background(Color.black.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding()
            }
        }
        .onReceive(timer) { _ in
            Task { @MainActor in
                session.syncFromScene()
            }
        }
    }
}
