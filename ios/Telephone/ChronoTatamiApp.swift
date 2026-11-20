import ChronoTatamiCore
import SwiftUI

@main
struct ChronoTatamiApp: App {
    @State private var bibliotheque = Bibliotheque()

    var body: some Scene {
        WindowGroup {
            ListeSeances()
                .environment(bibliotheque)
                .preferredColorScheme(.dark)
                .tint(Theme.citron)
        }
    }
}

/// « 23 min », « 1 h 30 »
func minutes(_ s: Int) -> String {
    let m = Int((Double(s) / 60).rounded())
    return m >= 60 ? "\(m / 60) h \(m % 60 == 0 ? "" : String(format: "%02d", m % 60))" : "\(m) min"
}

/// Barre de composition : un trait par bloc, coloré par famille, au prorata de la durée.
struct BarreComposition: View {
    let cours: ChronoTatamiCore.Cours
    var hauteur: CGFloat = 8
    var body: some View {
        GeometryReader { g in
            HStack(spacing: 2) {
                ForEach(Array(cours.blocs.enumerated()), id: \.offset) { _, b in
                    Theme.couleur(b.famille)
                        .frame(width: max(2, (g.size.width - CGFloat(cours.blocs.count) * 2) * CGFloat(b.duree) / CGFloat(max(1, cours.total))))
                }
            }
        }
        .frame(height: hauteur)
        .clipShape(.rect(cornerRadius: hauteur / 2))
    }
}
