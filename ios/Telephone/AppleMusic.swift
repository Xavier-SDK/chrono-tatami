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

    static func requete(_ p: PlaylistApple) -> MPMediaQuery {
        let q = MPMediaQuery.playlists()
        q.addFilterPredicate(MPMediaPropertyPredicate(value: NSNumber(value: p.id), forProperty: MPMediaPlaylistPropertyPersistentID))
        return q
    }

    static func titres(_ p: PlaylistApple) -> [MPMediaItem] {
        requete(p).collections?.first?.items ?? []
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

    private(set) var probleme: String?

    private func preparer() -> Bool {
        if pret { return true }
        guard disponible else {
            probleme = "Accès à la bibliothèque refusé : Réglages > Apps > Chrono Tatami > Musique et médias."
            return false
        }
        let items = BibliothequeMusique.titres(playlist)
        guard !items.isEmpty else {
            probleme = "Playlist « \(playlist.nom) » introuvable ou vide. Choisis-la à nouveau."
            return false
        }
        // File construite depuis la requête de la playlist : iOS résout lui-même les titres Apple Music
        // (dans le nuage ou téléchargés), ce que la liste d'éléments ne fait pas toujours.
        lecteur.setQueue(with: BibliothequeMusique.requete(playlist))
        lecteur.shuffleMode = aleatoire ? .songs : .off
        lecteur.repeatMode = .all
        let nuage = items.filter(\.isCloudItem).count
        lecteur.prepareToPlay { [weak self] erreur in
            guard let erreur else { return }
            let texte = "Lecture impossible (\(erreur.localizedDescription))."
                + (nuage > 0 ? " \(nuage) titre\(nuage > 1 ? "s" : "") sur \(items.count) non téléchargé\(nuage > 1 ? "s" : "") : télécharge la playlist dans l'app Musique." : "")
            print("[Musique] prepareToPlay : \(erreur)")
            Task { @MainActor in self?.probleme = texte }
        }
        pret = true
        return true
    }

    /// Dernière relance, pour ne pas solliciter le lecteur à chaque dixième de seconde.
    private var relance = Date.distantPast

    func synchroniser(voulue: Bool, niveau: Float) {
        if voulue {
            guard preparer() else { return }
            if !actif {
                actif = true
                relance = Date()
                lecteur.play()
            } else if lecteur.playbackState != .playing, Date().timeIntervalSince(relance) > 1 {
                // iOS met le lecteur en pause quand l'app rend la main sur l'audio (fin d'atténuation,
                // relance du coach, interruption) : on le relance tant que la section a de la musique.
                relance = Date()
                lecteur.play()
            }
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
