import SwiftUI

@main
struct ChronoMontreApp: App {
    @State private var lien = LienTelephone()
    @Environment(\.scenePhase) private var phase
    var body: some Scene {
        WindowGroup { VueMontre().environment(lien) }
            .onChange(of: phase) { _, p in if p == .active { lien.resynchroniser() } }
    }
}
