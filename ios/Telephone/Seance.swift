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

    init(cours: Cours, depuisBloc: Int, voix: Bool, voixChaqueRound: Bool) {
        var c = Chrono(cours: cours, depuisBloc: depuisBloc)
        c.voixChaqueRound = voixChaqueRound
        chrono = c
        etat = c.etat
        sons.voixActive = voix
        lien = LienMontre { [weak self] cmd in self?.commande(cmd) }
    }

    var cours: Cours { chrono.cours }

    func lancer() {
        sons.demarrer()
        UIApplication.shared.isIdleTimerDisabled = true
        jouer(chrono.demarrer())
        dernier = Date()
        minuterie = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tic() }
        }
        publier(important: true)
    }

    func quitter() {
        minuterie?.invalidate(); minuterie = nil
        sons.arreter()
        lien?.finir()
        UIApplication.shared.isIdleTimerDisabled = false
    }

    private func tic() {
        let maintenant = Date()
        let dt = maintenant.timeIntervalSince(dernier)
        dernier = maintenant
        // Plus d'une seconde d'écart : retour de veille, on rattrape sans sons.
        jouer(chrono.avancer(dt, silencieux: dt > 1.5))
        if miRound != nil, maintenant > finMiRound { miRound = nil }
        publier(important: false)
    }

    private func jouer(_ ev: [Evenement]) {
        for e in ev {
            switch e {
            case .bip: sons.jouer("bip")
            case .gong: sons.jouer("gong")
            case .double: sons.jouer("double")
            case .triple: sons.jouer("triple")
            case let .voix(t, forcee): sons.dire(t, forcee: forcee)
            case let .changementDeRole(t): miRound = t; finMiRound = Date().addingTimeInterval(3)
            case .nouveauBloc: break
            case .fin: UIApplication.shared.isIdleTimerDisabled = false
            }
        }
    }

    private func publier(important: Bool) {
        etat = chrono.etat
        let cle = "\(chrono.index)|\(etat.enMarche)|\(etat.termine)|\(Int(etat.dureeSequence))"
        let change = cle != cleMontre
        cleMontre = cle
        // Une fois par seconde suffit : la montre décompte seule entre deux messages.
        if important || change || Int(etat.restant * 10) % 10 == 0 {
            lien?.envoyer(etat, important: important || change)
        }
    }

    // MARK: Commandes (écran pause ou montre)

    func pause() { chrono.pause(); feuillePause = true; publier(important: true) }
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
        }
    }
}
