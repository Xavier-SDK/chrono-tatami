import MediaPlayer
import SwiftUI

/// Playlist de l'app Musique, retrouvée par son identifiant.
struct PlaylistApple: Codable, Hashable {
    let id: UInt64
    let nom: String
    let titres: Int
}

enum BibliothequeMusique {
    static func autoriser() async -> Bool {
        if MPMediaLibrary.authorizationStatus() == .authorized { return true }
        return await withCheckedContinuation { c in
            MPMediaLibrary.requestAuthorization { c.resume(returning: $0 == .authorized) }
        }
    }

    static func playlists() -> [PlaylistApple] {
        (MPMediaQuery.playlists().collections ?? []).compactMap { $0 as? MPMediaPlaylist }
            .filter { $0.count > 0 }
            .map { PlaylistApple(id: $0.persistentID, nom: $0.name ?? "Sans nom", titres: $0.count) }
            .sorted { $0.nom.localizedCompare($1.nom) == .orderedAscending }
    }

    static func titres(_ p: PlaylistApple) -> [MPMediaItem] {
        let q = MPMediaQuery.playlists()
        q.addFilterPredicate(MPMediaPropertyPredicate(value: NSNumber(value: p.id), forProperty: MPMediaPlaylistPropertyPersistentID))
        return q.collections?.first?.items ?? []
    }
}

/// Lecture d'une playlist Musique (titres Apple Music compris) par le lecteur de l'app.
/// iOS ne laisse pas l'app régler ce volume : la baisse pendant la voix passe par l'atténuation d'iOS (voir `Sons.attenuer`).
@MainActor
final class LecteurAppleMusic: LecteurSeance {
    private let lecteur = MPMusicPlayerController.applicationQueuePlayer
    private let playlist: PlaylistApple
    private let aleatoire: Bool
    private var pret = false
    private var actif = false
    let regleVolume = false

    init(playlist: PlaylistApple, aleatoire: Bool) {
        self.playlist = playlist
        self.aleatoire = aleatoire
    }

    var disponible: Bool { MPMediaLibrary.authorizationStatus() == .authorized }

    var courant: Morceau? {
        guard pret, let m = lecteur.nowPlayingItem else { return nil }
        return Morceau(id: String(m.persistentID), nom: m.title ?? "", artiste: m.artist ?? "", duree: m.playbackDuration)
    }

    private func preparer() -> Bool {
        if pret { return true }
        let items = BibliothequeMusique.titres(playlist)
        guard !items.isEmpty else { return false }
        lecteur.setQueue(with: MPMediaItemCollection(items: items))
        lecteur.shuffleMode = aleatoire ? .songs : .off
        lecteur.repeatMode = .all
        lecteur.prepareToPlay()
        pret = true
        return true
    }

    func synchroniser(voulue: Bool, niveau: Float) {
        if voulue {
            guard !actif, preparer() else { return }
            actif = true
            lecteur.play()
        } else { suspendre() }
    }

    func suspendre() {
        let jouait = lecteur.playbackState == .playing
        guard actif || (pret && jouait) else { return }
        actif = false
        lecteur.pause()
    }

    func suivant() {
        guard preparer() else { return }
        lecteur.skipToNextItem()
        // Hors section avec musique, passer au morceau suivant ne doit pas relancer la lecture.
        if !actif { lecteur.pause() }
    }

    func arreter() {
        actif = false
        if pret { lecteur.stop() }
    }
}

/// Choix d'une playlist de l'app Musique.
struct ChoixPlaylistApple: View {
    @Environment(Playlist.self) private var playlist
    @Environment(\.dismiss) private var fermer
    @State private var listes: [PlaylistApple]?
    @State private var refuse = false

    var body: some View {
        List {
            if refuse {
                Text("Chrono Tatami n'a pas accès à ta bibliothèque. Autorise-le dans Réglages > Apps > Chrono Tatami > Musique et médias.")
                    .foregroundStyle(Theme.attenue)
            } else if let listes {
                if listes.isEmpty { Text("Aucune playlist dans l'app Musique.").foregroundStyle(Theme.attenue) }
                ForEach(listes, id: \.id) { p in
                    Button {
                        playlist.appleMusic = p
                        fermer()
                    } label: {
                        HStack {
                            Text(p.nom).foregroundStyle(Theme.texte)
                            Spacer()
                            Text("\(p.titres) titres").foregroundStyle(Theme.attenue)
                            if playlist.appleMusic?.id == p.id { Image(systemName: "checkmark").foregroundStyle(Theme.citron) }
                        }
                    }
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Playlists Musique")
        .task {
            if await BibliothequeMusique.autoriser() { listes = BibliothequeMusique.playlists() } else { refuse = true }
        }
    }
}
