import SwiftUI

@main
struct ChronoMontreApp: App {
    @State private var lien = LienTelephone()
    var body: some Scene {
        WindowGroup { VueMontre().environment(lien) }
    }
}
