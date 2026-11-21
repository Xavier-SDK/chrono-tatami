import Foundation
import Observation
import WatchConnectivity
import ChronoTatamiCore

/// Côté montre : reçoit l'état du chrono de l'iPhone, envoie les commandes.
@MainActor @Observable
final class LienTelephone {
    private(set) var etat: EtatChrono?
    private(set) var joignable = false
    @ObservationIgnored private var relais: Relais?

    init() {
        relais = Relais(
            surEtat: { [weak self] e in self?.etat = e },
            surJoignable: { [weak self] j in self?.joignable = j }
        )
    }

    func envoyer(_ c: CommandeMontre) {
        // Réponse immédiate à l'écran, corrigée par le prochain état de l'iPhone.
        if var e = etat {
            let maintenant = Date()
            switch c {
            case .pause: e.restant = e.restant(a: maintenant); e.enMarche = false
            case .reprendre: e.enMarche = true
            case .couperMusique: e.musiqueCoupee = true
            case .remettreMusique: e.musiqueCoupee = false
            default: break
            }
            e.horodatage = maintenant.timeIntervalSince1970
            etat = e
        }
        relais?.envoyer(Lien.message(c))
    }

    /// Redemande l'état à l'iPhone : au retour sur l'app, ou quand l'affichage semble dépassé.
    func resynchroniser() {
        let maintenant = Date()
        guard maintenant.timeIntervalSince(derniereDemande) > 2 else { return }
        derniereDemande = maintenant
        relais?.demander()
    }
    @ObservationIgnored private var derniereDemande = Date.distantPast
}

/// Délégué WatchConnectivity (hors acteur principal).
private final class Relais: NSObject, WCSessionDelegate, @unchecked Sendable {
    let surEtat: @MainActor (EtatChrono?) -> Void
    let surJoignable: @MainActor (Bool) -> Void

    init(surEtat: @escaping @MainActor (EtatChrono?) -> Void, surJoignable: @escaping @MainActor (Bool) -> Void) {
        self.surEtat = surEtat
        self.surJoignable = surJoignable
        super.init()
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func envoyer(_ m: [String: Any]) {
        let s = WCSession.default
        if s.isReachable { s.sendMessage(m, replyHandler: nil, errorHandler: nil) }
        else { s.transferUserInfo(m) }
    }

    /// Demande l'état courant ; à défaut d'iPhone joignable, relit le dernier contexte reçu.
    func demander() {
        let s = WCSession.default
        guard s.activationState == .activated else { return }
        if s.isReachable {
            s.sendMessage([Lien.cleDemande: true], replyHandler: { [weak self] r in self?.recevoir(r) }, errorHandler: nil)
        } else {
            recevoir(s.receivedApplicationContext)
        }
    }

    private func recevoir(_ m: [String: Any]) {
        if m[Lien.cleRepos] != nil { let f = surEtat; Task { @MainActor in f(nil) }; return }
        guard let e = Lien.etat(depuis: m) else { return }
        let f = surEtat
        Task { @MainActor in f(e) }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        recevoir(session.receivedApplicationContext)
        let j = session.isReachable, f = surJoignable
        Task { @MainActor in f(j) }
        if j { demander() }
    }
    func sessionReachabilityDidChange(_ session: WCSession) {
        let j = session.isReachable, f = surJoignable
        Task { @MainActor in f(j) }
        if j { demander() }
    }
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) { recevoir(message) }
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) { recevoir(applicationContext) }
}
