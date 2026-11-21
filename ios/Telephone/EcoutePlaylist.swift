import AVFoundation
import SwiftUI

/// Bouton lecture/arrêt pour écouter la playlist choisie (fichiers ou app Musique), hors séance.
struct EcoutePlaylist: View {
    @Environment(Playlist.self) private var playlist
    var volume: Double = UserDefaults.standard.object(forKey: "musVol") as? Double ?? 0.8
    @State private var lecteur: LecteurSeance?
    @State private var titre: String?
    @State private var probleme: String?

    var body: some View {
        Button { basculer() } label: {
            VStack(alignment: .leading, spacing: 2) {
                Label(lecteur == nil ? "Écouter la playlist" : "Arrêter l'écoute",
                      systemImage: lecteur == nil ? "play.circle.fill" : "stop.circle.fill")
                if let titre { Text(titre).font(.footnote).foregroundStyle(Theme.attenue).lineLimit(1) }
                if let probleme { Text(probleme).font(.footnote).foregroundStyle(.orange) }
            }
        }
        .disabled(playlist.vide)
        .task(id: lecteur == nil) {
            // Titre en cours, rafraîchi tant que l'écoute dure ; relance si iOS a mis la lecture en pause.
            while lecteur != nil, !Task.isCancelled {
                lecteur?.synchroniser(voulue: true, niveau: Float(volume))
                probleme = lecteur?.probleme
                titre = lecteur?.courant.map { "♪ " + $0.nom + ($0.artiste.isEmpty ? "" : " · " + $0.artiste) }
                try? await Task.sleep(for: .seconds(1))
            }
        }
        .onChange(of: playlist.resume) { arreter() }
        .onDisappear { arreter() }
    }

    private func basculer() {
        if lecteur != nil { arreter(); return }
        let s = AVAudioSession.sharedInstance()
        try? s.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? s.setActive(true)
        let l = playlist.lecteur()
        l.synchroniser(voulue: true, niveau: Float(volume))
        lecteur = l
    }

    private func arreter() {
        lecteur?.arreter()
        lecteur = nil
        titre = nil
        probleme = nil
    }
}
