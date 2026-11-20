import Foundation
import WatchConnectivity
import ChronoTatamiCore

/// Côté iPhone : envoie l'état du chrono à la montre, reçoit ses commandes.
final class LienMontre: NSObject, WCSessionDelegate, @unchecked Sendable {
    private let surCommande: @MainActor (CommandeMontre) -> Void
    private var dernierContexte = Date.distantPast

    init(surCommande: @escaping @MainActor (CommandeMontre) -> Void) {
        self.surCommande = surCommande
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    /// `important` : changement de séquence, pause… (contexte mis à jour même si la montre dort).
    func envoyer(_ etat: EtatChrono, important: Bool) {
        guard WCSession.isSupported() else { return }
        let s = WCSession.default
        guard s.activationState == .activated, s.isPaired, s.isWatchAppInstalled else { return }
        let m = Lien.message(etat)
        if s.isReachable { s.sendMessage(m, replyHandler: nil, errorHandler: nil) }
        if important || Date().timeIntervalSince(dernierContexte) > 5 {
            dernierContexte = Date()
            try? s.updateApplicationContext(m)
        }
    }

    func finir() {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated else { return }
        let m: [String: Any] = [Lien.cleRepos: true]
        if WCSession.default.isReachable { WCSession.default.sendMessage(m, replyHandler: nil, errorHandler: nil) }
        try? WCSession.default.updateApplicationContext(m)
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { WCSession.default.activate() }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let c = Lien.commande(depuis: message) else { return }
        let f = surCommande
        Task { @MainActor in f(c) }
    }
}
