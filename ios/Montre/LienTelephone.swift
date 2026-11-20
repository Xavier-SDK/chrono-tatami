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
            default: break
            }
            e.horodatage = maintenant.timeIntervalSince1970
            etat = e
        }
        relais?.envoyer(Lien.message(c))
    }
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
    }
    func sessionReachabilityDidChange(_ session: WCSession) {
        let j = session.isReachable, f = surJoignable
        Task { @MainActor in f(j) }
    }
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) { recevoir(message) }
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) { recevoir(applicationContext) }
}
