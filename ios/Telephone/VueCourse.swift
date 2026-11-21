import SwiftUI
import ChronoTatamiCore

/// Écran du chrono : lisible à 5 m, un toucher met en pause.
struct VueCourse: View {
    let seance: Seance
    let quitter: () -> Void

    var body: some View {
        let e = seance.etat
        let c = seance.cours
        let segment = seance.chrono.segment
        let bloc = c.blocs[segment.bloc]
        let coul = Theme.couleur(bloc.famille)
        let suivant = seance.chrono.suivant
        let annonce = suivant.map { $0.bloc != segment.bloc } == true && e.restant <= 10 && e.enMarche && seance.miRound == nil

        Group {
            if e.termine {
                VueFin(seance: seance, quitter: quitter)
            } else {
                VStack(spacing: 0) {
                    entete(e, coul: coul)
                    cadran(e, coul: coul)
                    pied(e)
                }
                .overlay { if let m = seance.miRound { bandeauRole(m, bloc: bloc, coul: coul) } }
                .overlay { if annonce, let nx = suivant { annonceSuivant(e, c.blocs[nx.bloc]) } }
                .contentShape(.rect)
                .onTapGesture { seance.pause() }
            }
        }
        .background(Theme.encre)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .sheet(isPresented: Binding(get: { seance.feuillePause }, set: { if !$0 { seance.reprendre() } })) {
            VuePause(seance: seance, quitter: quitter)
                .presentationDetents([.large])
                .presentationBackground(Theme.panneau)
        }
    }

    private func entete(_ e: EtatChrono, coul: Color) -> some View {
        HStack(spacing: 12) {
            Text(Theme.nomType(e.type))
                .font(Theme.affiche(18)).tracking(1.4).textCase(.uppercase)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(e.type == .repos ? Color.clear : coul, in: .rect(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(coul, lineWidth: 2))
                .foregroundStyle(e.type == .repos ? coul : Theme.encre)
            Text(e.blocTitre).font(Theme.affiche(22)).textCase(.uppercase).lineLimit(1).foregroundStyle(Theme.texte)
            Spacer(minLength: 8)
            Text(e.nbSequences > 1 ? "\(e.rang)/\(e.nbSequences)" : minutes(Int(e.dureeSequence)))
                .font(Theme.affiche(24)).foregroundStyle(coul)
        }
        .padding(.horizontal, 24).padding(.top, 14).padding(.bottom, 10)
    }

    private func cadran(_ e: EtatChrono, coul: Color) -> some View {
        let fond: Color = e.type == .consigne ? Theme.texte : Theme.panneau
        let encre: Color = e.type == .consigne ? Theme.encre : (e.type == .repos ? coul : coul)
        let p = min(1, max(0, e.progressionSequence))
        return GeometryReader { g in
            let chiffres = Text(formatChrono(e.restant))
                .font(.custom("BigShouldersDisplay-Black", fixedSize: min(g.size.width * 0.42, g.size.height * 0.86)))
                .monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.3)
            ZStack(alignment: .topLeading) {
                fond
                if e.type == .repos {
                    Rectangle().fill(Theme.graphite).frame(width: g.size.width * p)
                }
                chiffres.foregroundStyle(encre).frame(maxWidth: .infinity, maxHeight: .infinity).padding(.top, 30)
                if e.type == .travail {
                    // Remplissage de la couleur du bloc ; les chiffres passent en noir sous la partie remplie.
                    ZStack {
                        coul
                        chiffres.foregroundStyle(Theme.encre).frame(maxWidth: .infinity, maxHeight: .infinity).padding(.top, 30)
                    }
                    .mask(alignment: .leading) { Rectangle().frame(width: g.size.width * p) }
                }
                Text(e.libelle)
                    .font(Theme.texte(26, gras: true)).textCase(.uppercase).tracking(1.2)
                    .foregroundStyle(e.type == .consigne ? Theme.encre : Theme.texte)
                    .lineLimit(2).padding(.horizontal, 24).padding(.top, 14)
            }
            .animation(.linear(duration: 0.1), value: p)
        }
    }

    private func pied(_ e: EtatChrono) -> some View {
        let fin = Date().addingTimeInterval(max(0, e.total - e.ecoule))
        return VStack(spacing: 8) {
            HStack(spacing: 12) {
                Text("Ensuite").font(Theme.affiche(16)).tracking(2).textCase(.uppercase).foregroundStyle(Theme.discret)
                Text(e.suivant).font(Theme.texte(17, gras: true)).lineLimit(1)
                if e.dureeSuivant > 0 { Text(formatChrono(Double(e.dureeSuivant))).foregroundStyle(Theme.attenue).font(Theme.texte(16)) }
                Spacer()
                Text(formatChrono(e.ecoule)).font(Theme.affiche(18)).foregroundStyle(Theme.attenue)
                Text("Fin " + fin.formatted(.dateTime.hour().minute()))
                    .font(Theme.affiche(18)).textCase(.uppercase).foregroundStyle(Theme.attenue)
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.trait)
                    Capsule().fill(Theme.texte.opacity(0.7)).frame(width: g.size.width * min(1, e.ecoule / max(1, e.total)))
                }
            }
            .frame(height: 4)
        }
        .foregroundStyle(Theme.texte)
        .padding(.horizontal, 24).padding(.top, 10).padding(.bottom, 14)
    }

    private func bandeauRole(_ m: String, bloc: Bloc, coul: Color) -> some View {
        VStack(spacing: 6) {
            Text("Mi-round").font(Theme.affiche(22)).tracking(4).textCase(.uppercase).foregroundStyle(coul)
            Text(m).font(Theme.affiche(80)).textCase(.uppercase).multilineTextAlignment(.center).minimumScaleFactor(0.4)
        }
        .foregroundStyle(Theme.texte)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.encre.opacity(0.94))
        .allowsHitTesting(false)
    }

    private func annonceSuivant(_ e: EtatChrono, _ nb: Bloc) -> some View {
        let coul = Theme.couleur(nb.famille)
        return HStack(spacing: 28) {
            Text("\(Int(ceil(e.restant)))").font(Theme.affiche(180)).foregroundStyle(coul).monospacedDigit()
            VStack(alignment: .leading, spacing: 8) {
                Text("Phase suivante · " + nb.famille.nom).font(Theme.affiche(18)).tracking(2).textCase(.uppercase).foregroundStyle(coul)
                Text(nb.titre).font(Theme.affiche(48)).textCase(.uppercase).foregroundStyle(Theme.texte).minimumScaleFactor(0.5)
                Text(minutes(nb.duree) + (nb.materiel.isEmpty ? "" : " · " + nb.materiel))
                    .font(Theme.texte(17)).foregroundStyle(Theme.attenue).lineLimit(2)
            }
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.encre.opacity(0.95))
        .allowsHitTesting(false)
    }
}

struct VuePause: View {
    let seance: Seance
    let quitter: () -> Void
    @State private var confirmer = false

    var body: some View {
        let e = seance.etat
        GeometryReader { g in
            if g.size.width > g.size.height {
                HStack(spacing: 28) {
                    resume(e, taille: min(110, g.size.height * 0.4)).frame(maxWidth: .infinity)
                    commandes.frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 24).frame(maxHeight: .infinity)
            } else {
                VStack(spacing: 18) { resume(e, taille: 110); commandes }
                    .padding(24).frame(maxHeight: .infinity)
            }
        }
    }

    private func resume(_ e: EtatChrono, taille: CGFloat) -> some View {
        VStack(spacing: 8) {
            Text("En pause").font(Theme.affiche(18)).tracking(3).textCase(.uppercase).foregroundStyle(Theme.discret)
            Text(formatChrono(e.restant)).font(Theme.affiche(taille)).monospacedDigit().foregroundStyle(Theme.texte)
            Text(e.blocTitre).font(Theme.affiche(26)).textCase(.uppercase).foregroundStyle(Theme.texte).multilineTextAlignment(.center)
            Text(e.libelle).font(Theme.texte(17)).foregroundStyle(Theme.attenue).multilineTextAlignment(.center)
        }
    }

    private var commandes: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                bouton("−30 s", "gobackward.30") { seance.ajuster(-30) }
                bouton("+30 s", "goforward.30") { seance.ajuster(30) }
            }
            HStack(spacing: 12) {
                bouton("Revenir", "backward.end.fill") { seance.revenir() }
                bouton("Passer", "forward.end.fill") { seance.passer() }
            }
            if seance.musiquePrevue { musique }
            Button { seance.reprendre() } label: {
                Label("Reprendre", systemImage: "play.fill")
                    .font(Theme.affiche(30)).textCase(.uppercase)
                    .frame(maxWidth: .infinity).frame(height: 62)
                    .background(Theme.citron, in: .rect(cornerRadius: 18)).foregroundStyle(Theme.encre)
            }
            Button("Terminer la séance", role: .destructive) { confirmer = true }
                .font(Theme.texte(16, gras: true))
                .confirmationDialog("Terminer la séance ?", isPresented: $confirmer, titleVisibility: .visible) {
                    Button("Terminer", role: .destructive) { quitter() }
                }
        }
    }

    private var musique: some View {
        VStack(spacing: 8) {
            if let m = seance.morceau, !seance.musiqueCoupee {
                Text("♪ " + m.nom + (m.artiste.isEmpty ? "" : " · " + m.artiste))
                    .font(Theme.texte(15)).foregroundStyle(Theme.attenue).lineLimit(1)
            }
            HStack(spacing: 12) {
                bouton(seance.musiqueCoupee ? "Remettre" : "Couper", seance.musiqueCoupee ? "speaker.wave.2.fill" : "speaker.slash.fill") {
                    seance.musiqueCoupee.toggle()
                }
                bouton("Morceau suivant", "forward.fill") { seance.morceauSuivant() }
            }
            if seance.volumeReglable { HStack(spacing: 10) {
                Image(systemName: "speaker.fill").foregroundStyle(Theme.discret)
                Slider(value: Binding(get: { seance.volumeMusique }, set: { seance.volumeMusique = $0 }), in: 0...1)
                Image(systemName: "speaker.wave.3.fill").foregroundStyle(Theme.discret)
            } }
        }
    }

    private func bouton(_ t: String, _ i: String, _ a: @escaping () -> Void) -> some View {
        Button(action: a) {
            Label(t, systemImage: i).font(Theme.texte(17, gras: true))
                .frame(maxWidth: .infinity).frame(height: 54)
                .background(Theme.graphite, in: .rect(cornerRadius: 14))
        }
        .buttonStyle(.plain).foregroundStyle(Theme.texte)
    }
}

struct VueFin: View {
    let seance: Seance
    let quitter: () -> Void
    var body: some View {
        let ecart = Int(seance.chrono.ajoute.rounded())
        VStack(spacing: 16) {
            Text("Fin de la séance").font(Theme.affiche(20)).tracking(3).textCase(.uppercase).foregroundStyle(Theme.citron)
            Text("Salut.").font(Theme.affiche(96)).textCase(.uppercase)
            Text(seance.cours.titre).font(Theme.texte(18)).foregroundStyle(Theme.attenue).multilineTextAlignment(.center)
            Text(ecart == 0 ? "Dans les temps" : (ecart > 0 ? "+" : "−") + formatChrono(Double(abs(ecart))) + " sur le prévu")
                .font(Theme.affiche(30)).foregroundStyle(Theme.texte)
            Button(action: quitter) {
                Text("Retour aux séances").font(Theme.affiche(24)).textCase(.uppercase)
                    .padding(.horizontal, 28).frame(height: 58)
                    .background(Theme.citron, in: .rect(cornerRadius: 16)).foregroundStyle(Theme.encre)
            }
        }
        .foregroundStyle(Theme.texte)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
