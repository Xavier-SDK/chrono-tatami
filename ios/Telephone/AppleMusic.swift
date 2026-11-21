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
    /// Lecteur propre à l'app : il ne touche pas à la file de l'app Musique.
    /// Seuls les titres téléchargés sur l'iPhone sont mis en file : un titre Apple Music resté dans le nuage
    /// ne se charge pas depuis une app tierce, et le lecteur restait bloqué dessus, muet, ce qui coupait aussi
    /// l'app Musique (même service de lecture) jusqu'au redémarrage de l'iPhone.
    private let lecteur = MPMusicPlayerController.applicationQueuePlayer
    private let systeme = false
    private let playlist: PlaylistApple
    private let aleatoire: Bool
    private enum Etat { case vide, chargement, pret, echec }
    private var etat = Etat.vide
    private var actif = false
    let regleVolume = false

    init(playlist: PlaylistApple, aleatoire: Bool) {
        self.playlist = playlist
        self.aleatoire = aleatoire
    }

    var disponible: Bool { MPMediaLibrary.authorizationStatus() == .authorized }

    var courant: Morceau? {
        guard etat == .pret, let m = lecteur.nowPlayingItem else { return nil }
        return Morceau(id: String(m.persistentID), nom: m.title ?? "", artiste: m.artist ?? "", duree: m.playbackDuration)
    }

    private(set) var probleme: String?

    /// Charge la file une seule fois. Rien n'est lancé tant que le lecteur n'a pas confirmé :
    /// des play() en rafale sur une file refusée bloquaient le son de tout l'iPhone.
    private func preparer() {
        guard etat == .vide else { return }
        guard disponible else {
            probleme = "Accès à la bibliothèque refusé : Réglages > Apps > Chrono Tatami > Musique et médias."
            etat = .echec
            return
        }
        let tous = BibliothequeMusique.titres(playlist)
        guard !tous.isEmpty else {
            probleme = "Playlist « \(playlist.nom) » introuvable ou vide. Choisis-la à nouveau."
            etat = .echec
            return
        }
        titres = tous.filter { !$0.isCloudItem }
        let manquants = tous.count - titres.count
        guard !titres.isEmpty else {
            probleme = "Aucun titre de « \(playlist.nom) » n'est téléchargé sur l'iPhone. Dans l'app Musique, ouvre la playlist et touche Télécharger."
            etat = .echec
            return
        }
        if manquants > 0 {
            probleme = "\(manquants) titre\(manquants > 1 ? "s" : "") sur \(tous.count) non téléchargé\(manquants > 1 ? "s" : "") : \(manquants > 1 ? "ils sont ignorés" : "il est ignoré"). Télécharge la playlist dans l'app Musique."
        }
        etat = .chargement
        charger()
    }
    private var titres: [MPMediaItem] = []

    private func charger() {
        print("[Musique] charger (\(systeme ? "app Musique" : "app")) \(playlist.nom)")
        lecteur.setQueue(with: MPMediaItemCollection(items: titres))
        lecteur.shuffleMode = aleatoire ? .songs : .off
        lecteur.repeatMode = .all
        lecteur.prepareToPlay { [weak self] erreur in
            Task { @MainActor in self?.charge(erreur) }
        }
    }

    private func charge(_ erreur: Error?) {
        guard etat == .chargement else { return }
        if let erreur {
            print("[Musique] prepareToPlay (\(systeme ? "app Musique" : "app")) : \(erreur)")
            probleme = "L'app Musique refuse de lire cette playlist (\(erreur.localizedDescription)). Vérifie qu'elle se lit dans l'app Musique."
            etat = .echec
            return
        }
        print("[Musique] prêt (\(systeme ? "app Musique" : "app")), actif=\(actif)")
        etat = .pret
        if actif { lecteur.play() }
    }

    /// Dernière relance, pour ne pas solliciter le lecteur à chaque dixième de seconde.
    private var relance = Date.distantPast

    func synchroniser(voulue: Bool, niveau: Float) {
        guard voulue else { suspendre(); return }
        preparer()
        guard etat == .pret else { actif = etat == .chargement; return }
        if !actif {
            actif = true
            relance = Date()
            print("[Musique] play (début)")
            lecteur.play()
        } else if lecteur.playbackState == .paused || lecteur.playbackState == .stopped,
                  Date().timeIntervalSince(relance) > 3 {
            // iOS met le lecteur en pause quand l'app rend la main sur l'audio (fin d'atténuation,
            // relance du coach, interruption) : on le relance tant que la section a de la musique.
            relance = Date()
            print("[Musique] play (relance, état \(lecteur.playbackState.rawValue))")
            lecteur.play()
        }
    }

    func suspendre() {
        let avait = actif
        actif = false
        guard etat == .pret, avait || lecteur.playbackState == .playing else { return }
        lecteur.pause()
    }

    func suivant() {
        guard etat == .pret else { return }
        lecteur.skipToNextItem()
        // Hors section avec musique, passer au morceau suivant ne doit pas relancer la lecture.
        if !actif { lecteur.pause() }
    }

    func arreter() {
        actif = false
        if etat == .pret || etat == .chargement {
            // Le lecteur de l'app Musique continuerait après la séance : on l'arrête aussi.
            lecteur.stop()
        }
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
