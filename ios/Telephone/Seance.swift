import Foundation
import Observation
import UIKit
import ChronoTatamiCore

/// Fait tourner le chrono : minuterie, sons, voix, montre.
@MainActor @Observable
final class Seance {
    private(set) var chrono: Chrono
    private(set) var etat: EtatChrono
    var feuillePause = false
    /// Bandeau de mi-round (changement de rôle) affiché quelques secondes.
    private(set) var miRound: String?
    private var finMiRound = Date.distantPast

    @ObservationIgnored private let sons = Sons()
    @ObservationIgnored private var minuterie: Timer?
    @ObservationIgnored private var dernier = Date()
    @ObservationIgnored private var lien: LienMontre?
    @ObservationIgnored private var cleMontre = ""
    @ObservationIgnored private let musique: LecteurSeance
    /// Sections où la musique joue (par défaut celles marquées ♪ dans la fiche).
    @ObservationIgnored private let sectionsMusique: Set<Int>
    /// Musique coupée depuis la pause.
    var musiqueCoupee = false { didSet { synchroniserMusique() } }
    /// Morceau en cours, affiché dans la pause.
    private(set) var morceau: Morceau?
    var volumeMusique: Double { didSet { UserDefaults.standard.set(volumeMusique, forKey: "musVol"); synchroniserMusique() } }
    @ObservationIgnored private let baisse: Double
    /// Réglages : bips 3-2-1, gong et signaux de séquence, écran allumé, mode essai ×10.
    @ObservationIgnored private let bips: Bool
    @ObservationIgnored private let gong: Bool
    @ObservationIgnored private let ecranAllume: Bool
    @ObservationIgnored private let vitesse: Double

    init(cours: Cours, depuisBloc: Int, voix: Bool, voixChaqueRound: Bool, playlist: Playlist, sectionsMusique: Set<Int>) {
        var c = Chrono(cours: cours, depuisBloc: depuisBloc)
        c.voixChaqueRound = voixChaqueRound
        chrono = c
        etat = c.etat
        sons.voixActive = voix
        musique = playlist.lecteur()
        self.sectionsMusique = sectionsMusique
        let d = UserDefaults.standard
        volumeMusique = d.object(forKey: "musVol") as? Double ?? 0.8
        baisse = (d.object(forKey: "musBas") as? Double ?? 20) / 100
        bips = d.object(forKey: "bips") as? Bool ?? true
        gong = d.object(forKey: "gong") as? Bool ?? true
        ecranAllume = d.object(forKey: "veille") as? Bool ?? true
        vitesse = d.bool(forKey: "test") ? 10 : 1
        lien = LienMontre { [weak self] cmd in self?.commande(cmd) }
    }

    var cours: Cours { chrono.cours }

    func lancer() {
        sons.demarrer()
        UIApplication.shared.isIdleTimerDisabled = ecranAllume
        jouer(chrono.demarrer())
        dernier = Date()
        minuterie = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tic() }
        }
        publier(important: true)
    }

    func quitter() {
        minuterie?.invalidate(); minuterie = nil
        musique.arreter()
        sons.arreter()
        lien?.finir()
        UIApplication.shared.isIdleTimerDisabled = false
    }

    private func tic() {
        let maintenant = Date()
        let dt = maintenant.timeIntervalSince(dernier)
        dernier = maintenant
        // Plus d'une seconde d'écart : retour de veille, on rattrape sans sons.
        jouer(chrono.avancer(dt * vitesse, silencieux: dt > 1.5))
        if miRound != nil, maintenant > finMiRound { miRound = nil }
        synchroniserMusique()
        publier(important: false)
    }

    // MARK: Musique

    /// La section du bloc en cours a-t-elle de la musique ?
    /// Le curseur de volume de l'app agit (fichiers importés, pas la playlist Musique).
    var volumeReglable: Bool { musique.regleVolume }

    var musiquePrevue: Bool { musique.disponible && sectionsMusique.contains(chrono.bloc.section) }

    /// Baisse pendant la voix et les consignes, comme l'app web.
    var musiqueBaissee: Bool { sons.voixEnCours || chrono.segment.sequence.type == .consigne }

    private func synchroniserMusique() {
        let voulue = musiquePrevue && !musiqueCoupee && chrono.enMarche && !chrono.termine
        if chrono.termine { musique.arreter() }
        else if !chrono.enMarche { musique.suspendre() }
        else { musique.synchroniser(voulue: voulue, niveau: Float(volumeMusique * (musiqueBaissee ? baisse : 1))) }
        if !musique.regleVolume { sons.attenuer(voulue && musiqueBaissee) }
        if morceau != musique.courant { morceau = musique.courant }
    }

    func morceauSuivant() {
        musiqueCoupee = false
        musique.suivant()
        morceau = musique.courant
    }

    private func jouer(_ ev: [Evenement]) {
        for e in ev {
            switch e {
            case .bip: if bips { sons.jouer("bip") }
            case .gong: if gong { sons.jouer("gong") }
            case .double: if gong { sons.jouer("double") }
            case .triple: if gong { sons.jouer("triple") }
            case let .voix(t, forcee): sons.dire(t, forcee: forcee)
            case let .changementDeRole(t): miRound = t; finMiRound = Date().addingTimeInterval(3)
            case .nouveauBloc: break
            case .fin: UIApplication.shared.isIdleTimerDisabled = false
            }
        }
    }

    private func publier(important: Bool) {
        var e = chrono.etat
        e.musiquePrevue = musiquePrevue
        e.musiqueCoupee = musiqueCoupee
        etat = e
        let cle = "\(chrono.index)|\(etat.enMarche)|\(etat.termine)|\(Int(etat.dureeSequence))|\(e.musiquePrevue)|\(e.musiqueCoupee)"
        let change = cle != cleMontre
        cleMontre = cle
        // Une fois par seconde suffit : la montre décompte seule entre deux messages.
        if important || change || Int(etat.restant * 10) % 10 == 0 {
            lien?.envoyer(etat, important: important || change)
        }
    }

    // MARK: Commandes (écran pause ou montre)

    func pause() { chrono.pause(); feuillePause = true; synchroniserMusique(); publier(important: true) }
    func reprendre() { chrono.reprendre(); feuillePause = false; dernier = Date(); sons.demarrer(); publier(important: true) }
    func revenir() { chrono.revenir(); publier(important: true) }
    func passer() { jouer(chrono.passer()); publier(important: true) }
    func ajuster(_ s: Double) { chrono.ajuster(s); publier(important: true) }

    func commande(_ c: CommandeMontre) {
        switch c {
        case .pause: pause()
        case .reprendre: reprendre()
        case .revenir: revenir()
        case .passer: passer()
        case .plus30: ajuster(30)
        case .moins30: ajuster(-30)
        case .couperMusique: musiqueCoupee = true; publier(important: true)
        case .remettreMusique: musiqueCoupee = false; publier(important: true)
        }
    }
}
