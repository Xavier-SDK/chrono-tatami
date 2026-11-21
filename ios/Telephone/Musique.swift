import AVFoundation
import Foundation
import Observation

/// Un morceau importé, copié dans Documents/Musique.
struct Morceau: Identifiable, Codable, Hashable {
    let id: String          // nom du fichier dans le dossier
    var nom: String
    var artiste: String
    var duree: Double
}

/// Playlist de l'app : fichiers audio importés depuis Fichiers (comme la playlist de l'app web).
@MainActor @Observable
final class Playlist {
    private(set) var morceaux: [Morceau] = []
    var aleatoire: Bool {
        didSet { UserDefaults.standard.set(aleatoire, forKey: "musAlea") }
    }
    /// Playlist de l'app Musique choisie à la place des fichiers importés.
    var appleMusic: PlaylistApple? {
        didSet { UserDefaults.standard.set(try? JSONEncoder().encode(appleMusic), forKey: "playlistApple") }
    }

    /// Ce qui sera joué : « 12 morceaux · 45 min » ou le nom de la playlist Musique.
    var resume: String {
        if let a = appleMusic { return "♫ " + a.nom }
        if morceaux.isEmpty { return "Aucun morceau" }
        return "\(morceaux.count) morceau\(morceaux.count > 1 ? "x" : "") · \(minutes(Int(dureeTotale)))"
    }
    var vide: Bool { appleMusic == nil && morceaux.isEmpty }

    /// Lecteur adapté à la source choisie.
    func lecteur() -> LecteurSeance {
        if let a = appleMusic { return LecteurAppleMusic(playlist: a, aleatoire: aleatoire) }
        return LecteurMusique(playlist: self)
    }

    static let dossier: URL = {
        let d = URL.documentsDirectory.appending(path: "Musique", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }()

    private static let cle = "playlist"

    init() {
        aleatoire = UserDefaults.standard.object(forKey: "musAlea") as? Bool ?? true
        if let d = UserDefaults.standard.data(forKey: "playlistApple") {
            appleMusic = try? JSONDecoder().decode(PlaylistApple.self, from: d)
        }
        if let d = UserDefaults.standard.data(forKey: Self.cle), let l = try? JSONDecoder().decode([Morceau].self, from: d) {
            morceaux = l.filter { FileManager.default.fileExists(atPath: url($0).path) }
        }
    }

    func url(_ m: Morceau) -> URL { Self.dossier.appending(path: m.id) }

    var dureeTotale: Double { morceaux.reduce(0) { $0 + $1.duree } }

    /// Copie les fichiers choisis dans l'app. Rend le nombre de morceaux ajoutés.
    func importer(_ urls: [URL]) async -> Int {
        var n = 0
        for u in urls {
            let acces = u.startAccessingSecurityScopedResource()
            defer { if acces { u.stopAccessingSecurityScopedResource() } }
            let ext = u.pathExtension.lowercased()
            guard ["mp3", "m4a", "aac", "wav", "aif", "aiff", "caf"].contains(ext) else { continue }
            let id = UUID().uuidString.prefix(8) + "." + ext
            let dest = Self.dossier.appending(path: String(id))
            do { try FileManager.default.copyItem(at: u, to: dest) } catch { continue }
            let base = u.deletingPathExtension().lastPathComponent
            let parts = base.components(separatedBy: " - ")
            let artiste = parts.count > 1 ? parts[0].trimmingCharacters(in: .whitespaces) : ""
            let nom = (parts.count > 1 ? parts.dropFirst().joined(separator: " - ") : base).trimmingCharacters(in: .whitespaces)
            let duree = (try? await AVURLAsset(url: dest).load(.duration).seconds) ?? 0
            morceaux.append(Morceau(id: String(id), nom: nom, artiste: artiste, duree: duree.isFinite ? duree : 0))
            n += 1
        }
        enregistrer()
        return n
    }

    func supprimer(_ offsets: IndexSet) {
        for i in offsets { try? FileManager.default.removeItem(at: url(morceaux[i])) }
        morceaux.remove(atOffsets: offsets)
        enregistrer()
    }

    func deplacer(_ depuis: IndexSet, vers: Int) {
        morceaux.move(fromOffsets: depuis, toOffset: vers)
        enregistrer()
    }

    private func enregistrer() {
        if let d = try? JSONEncoder().encode(morceaux) { UserDefaults.standard.set(d, forKey: Self.cle) }
    }
}

/// Ce que la séance demande à la musique, quelle que soit la source.
@MainActor
protocol LecteurSeance: AnyObject {
    var disponible: Bool { get }
    /// Le volume de l'app s'applique (fichiers). Sinon (Musique), seule l'atténuation d'iOS joue.
    var regleVolume: Bool { get }
    var courant: Morceau? { get }
    func synchroniser(voulue: Bool, niveau: Float)
    func suspendre()
    func suivant()
    func arreter()
}

/// Lecteur de la musique pendant la séance : fondus, baisse progressive, fondu enchaîné entre morceaux,
/// reprise là où la section précédente s'est arrêtée. Même logique que `Musique.sync` de l'app web (musique.js).
@MainActor
final class LecteurMusique: NSObject, AVAudioPlayerDelegate, LecteurSeance {
    /// Durée de la baisse ou de la remontée du volume (voix, consignes, entrée et sortie de section).
    static let fondu: TimeInterval = 1
    /// Durée du fondu enchaîné d'un morceau au suivant.
    static let enchaine: TimeInterval = 4

    private let playlist: Playlist
    private var lecteur: AVAudioPlayer?
    /// Morceau précédent, en train de s'éteindre pendant le fondu enchaîné.
    private var sortant: AVAudioPlayer?
    private var ordre: [Morceau] = []
    private var pos = 0
    private var actif = false            // musique voulue et en cours
    private var cible: Float = 0
    private(set) var courant: Morceau?

    init(playlist: Playlist) { self.playlist = playlist }

    var disponible: Bool { !playlist.morceaux.isEmpty }
    let regleVolume = true

    /// `voulue` : section avec musique et chrono en marche. `niveau` : volume visé de 0 à 1.
    func synchroniser(voulue: Bool, niveau: Float) {
        guard disponible else { return }
        if voulue {
            if lecteur == nil, !charger() { return }
            if !actif {
                actif = true
                lecteur?.volume = 0
                lecteur?.play()
                cible = 0
            }
            volume(niveau)
            if let l = lecteur, l.duration > 0, l.duration - l.currentTime <= dureeEnchaine(l), sortant == nil {
                enchainer()
            }
        } else {
            if actif {
                actif = false
                volume(0)
                mettreEnPause(apres: Self.fondu + 0.05)
            } else if lecteur?.isPlaying == true, cible > 0 {
                // Sécurité : rien ne doit jouer hors d'une section avec musique.
                volume(0)
                mettreEnPause(apres: Self.fondu + 0.05)
            }
            couperSortant()
        }
    }

    /// Pause du chrono : coupure rapide, la position est gardée.
    func suspendre() {
        couperSortant()
        guard actif else { return }
        actif = false
        cible = 0
        lecteur?.setVolume(0, fadeDuration: 0.15)
        mettreEnPause(apres: 0.2)
    }

    /// Morceau suivant : fondu enchaîné si la musique joue.
    func suivant() {
        if actif { enchainer(); return }
        pos += 1
        lecteur?.stop(); lecteur = nil
        _ = charger()
    }

    func arreter() {
        actif = false
        couperSortant()
        lecteur?.setVolume(0, fadeDuration: 0.8)
        arreterPlusTard(lecteur, apres: 0.85)
        lecteur = nil
        courant = nil
    }

    private func dureeEnchaine(_ l: AVAudioPlayer) -> TimeInterval { min(Self.enchaine, l.duration / 3) }

    /// Le morceau en cours s'éteint pendant que le suivant monte.
    private func enchainer() {
        guard let ancien = lecteur else { return }
        let d = dureeEnchaine(ancien)
        couperSortant()
        sortant = ancien
        ancien.setVolume(0, fadeDuration: d)
        arreterPlusTard(ancien, apres: d + 0.1)
        pos += 1
        lecteur = nil
        guard charger(), let l = lecteur else { return }
        l.volume = 0
        l.play()
        l.setVolume(cible, fadeDuration: d)
    }

    private func couperSortant() {
        sortant?.stop()
        sortant = nil
    }

    private func arreterPlusTard(_ l: AVAudioPlayer?, apres s: Double) {
        guard let l else { return }
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(s))
            l.stop()
            if self?.sortant === l { self?.sortant = nil }
        }
    }

    /// Met en pause à la fin du fondu, sauf si la musique a été relancée entre-temps.
    private func mettreEnPause(apres s: Double) {
        let l = lecteur
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(s))
            guard let self, !self.actif, l === self.lecteur else { return }
            l?.pause()
        }
    }

    /// Volume visé, atteint progressivement en une seconde.
    private func volume(_ v: Float) {
        let v = max(0, min(1, v))
        guard abs(v - cible) > 0.005 else { return }
        cible = v
        lecteur?.setVolume(v, fadeDuration: Self.fondu)
    }

    private func melanger() {
        ordre = playlist.morceaux
        if playlist.aleatoire { ordre.shuffle() }
        pos = 0
    }

    private func charger() -> Bool {
        if ordre.isEmpty || ordre.contains(where: { !playlist.morceaux.contains($0) }) { melanger() }
        guard !ordre.isEmpty else { return false }
        if pos >= ordre.count { melanger() }
        for _ in 0..<ordre.count {
            let m = ordre[pos]
            if let l = try? AVAudioPlayer(contentsOf: playlist.url(m)) {
                l.delegate = self
                l.prepareToPlay()
                lecteur = l
                courant = m
                return true
            }
            pos = (pos + 1) % ordre.count
        }
        return false
    }

    /// Fin d'un morceau sans fondu enchaîné (pause juste avant la fin) : on passe au suivant.
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        let fini = ObjectIdentifier(player)
        Task { @MainActor in
            guard let l = lecteur, ObjectIdentifier(l) == fini else { return }
            let jouait = actif
            pos += 1
            lecteur = nil
            guard charger() else { return }
            if jouait {
                lecteur?.volume = 0
                lecteur?.play()
                lecteur?.setVolume(cible, fadeDuration: Self.fondu)
            }
        }
    }
}
