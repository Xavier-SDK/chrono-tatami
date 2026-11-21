import SwiftUI
import WatchKit
import ChronoTatamiCore

/// Écran de la montre (maquette d'origine) : grand temps, libellé, barre de progression, trois boutons.
struct VueMontre: View {
    @Environment(LienTelephone.self) private var lien
    @State private var derniereCle = ""
    @State private var dernierBip = -1

    var body: some View {
        if let e = lien.etat, !e.termine {
            TimelineView(.periodic(from: .now, by: 0.25)) { ctx in
                chrono(e, maintenant: ctx.date)
            }
            .onChange(of: cle(e)) { _, nouvelle in
                if !derniereCle.isEmpty { WKInterfaceDevice.current().play(.start) }
                derniereCle = nouvelle
            }
        } else {
            attente(termine: lien.etat?.termine == true)
        }
    }

    private func cle(_ e: EtatChrono) -> String { "\(e.blocTitre)|\(e.rang)|\(e.libelle)" }

    private func chrono(_ e: EtatChrono, maintenant: Date) -> some View {
        let restant = e.restant(a: maintenant)
        let fait = max(0, e.dureeSequence - restant)
        let p = e.dureeSequence > 0 ? min(1, fait / e.dureeSequence) : 0
        let coul = e.enMarche ? Theme.couleur(e.famille) : Theme.discret
        let s = Int(ceil(restant))
        return VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .center, spacing: 4) {
                Text(formatChrono(restant))
                    .font(Theme.affiche(52)).monospacedDigit()
                    .foregroundStyle(e.enMarche ? Theme.couleur(e.famille) : Theme.texte)
                    .lineLimit(1).minimumScaleFactor(0.6)
                if e.musiquePrevue {
                    Spacer(minLength: 0)
                    rond(e.musiqueCoupee ? "speaker.slash.fill" : "speaker.wave.2.fill", taille: 34) {
                        lien.envoyer(e.musiqueCoupee ? .remettreMusique : .couperMusique)
                    }
                }
            }
            Text((e.enMarche ? "" : "En pause · ") + sousTitre(e))
                .font(Theme.texte(14, gras: true)).lineLimit(1)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.trait)
                    Capsule().fill(coul).frame(width: g.size.width * p)
                }
            }
            .frame(height: 5)
            HStack {
                Text(formatChrono(fait))
                Spacer()
                Text("−" + formatChrono(restant))
            }
            .font(Theme.texte(12)).foregroundStyle(Theme.attenue)
            Spacer(minLength: 2)
            HStack {
                rond("backward.end.fill", taille: 44) { lien.envoyer(.revenir) }
                Spacer()
                rond(e.enMarche ? "pause.fill" : "play.fill", taille: 52, principal: true) {
                    lien.envoyer(e.enMarche ? .pause : .reprendre)
                }
                Spacer()
                rond("forward.end.fill", taille: 44) { lien.envoyer(.passer) }
            }
        }
        .foregroundStyle(Theme.texte)
        .onChange(of: s) { _, v in
            if e.enMarche, (1...3).contains(v), v != dernierBip { dernierBip = v; WKInterfaceDevice.current().play(.click) }
            // Arrivé à zéro sans nouvel état : on a sans doute raté des messages, on redemande.
            if e.enMarche, v <= 0 { lien.resynchroniser() }
        }
    }

    private func sousTitre(_ e: EtatChrono) -> String {
        let premier = e.libelle.components(separatedBy: "·")[0].trimmingCharacters(in: .whitespaces)
        if e.nbSequences > 1 { return "\(e.rang)/\(e.nbSequences) · " + (premier.isEmpty ? e.blocTitre : premier) }
        return premier.isEmpty ? e.blocTitre : premier
    }

    private func rond(_ icone: String, taille: CGFloat, principal: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icone)
                .font(.system(size: taille * 0.36, weight: .bold))
                .frame(width: taille, height: taille)
                .background(principal ? Theme.citron : Theme.graphite, in: .circle)
                .foregroundStyle(principal ? Theme.encre : Theme.texte)
        }
        .buttonStyle(.plain)
    }

    private func attente(termine: Bool) -> some View {
        VStack(spacing: 8) {
            Image(systemName: termine ? "checkmark.circle.fill" : "iphone")
                .font(.system(size: 30)).foregroundStyle(Theme.citron)
            Text(termine ? "Séance terminée" : "Lance une séance sur l'iPhone")
                .font(Theme.texte(15, gras: true)).multilineTextAlignment(.center)
            if !termine && !lien.joignable {
                Text("iPhone hors de portée").font(Theme.texte(12)).foregroundStyle(Theme.attenue)
            }
        }
        .foregroundStyle(Theme.texte)
    }
}
