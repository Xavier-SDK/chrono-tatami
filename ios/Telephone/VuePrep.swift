import SwiftUI
import ChronoTatamiCore

struct VuePrep: View {
    let fiche: Fiche
    @AppStorage("voix") private var voix = true
    @AppStorage("voixRounds") private var voixRounds = false
    @State private var depart = 0
    @State private var ouvert: Int?
    @State private var seance: Seance?
    @Environment(\.dismiss) private var fermer

    var body: some View {
        let c = fiche.cours
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Button { fermer() } label: {
                    Label("Séances", systemImage: "chevron.left").font(Theme.texte(16, gras: true))
                }
                .foregroundStyle(Theme.attenue)
                Text(c.titre).font(Theme.affiche(40)).textCase(.uppercase).foregroundStyle(Theme.texte)
                if !c.objectif.isEmpty {
                    Text(c.objectif).font(Theme.texte(16)).foregroundStyle(Theme.attenue)
                }
                HStack(spacing: 18) {
                    stat("Durée", minutes(c.total))
                    stat("Blocs", "\(c.blocs.count)")
                    if let h = c.meta["heure"] { stat("Début", h.replacingOccurrences(of: ":", with: "h")) }
                }
                BarreComposition(cours: c, hauteur: 10)
                if !c.erreurs.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(c.erreurs, id: \.self) { Text("⚠︎ " + $0) }
                    }
                    .font(Theme.texte(14)).foregroundStyle(.orange)
                    .padding(12).background(Theme.panneau2, in: .rect(cornerRadius: 12))
                }
                VStack(spacing: 10) {
                    Toggle("Annoncer les blocs à voix haute", isOn: $voix)
                    Toggle("Annoncer chaque round", isOn: $voixRounds).disabled(!voix)
                }
                .font(Theme.texte(16)).padding(14).background(Theme.panneau, in: .rect(cornerRadius: 14))

                Text("Déroulé").font(Theme.affiche(15)).tracking(2).textCase(.uppercase).foregroundStyle(Theme.discret)
                ForEach(Array(c.blocs.enumerated()), id: \.offset) { i, b in
                    ligne(i, b, debut: c.blocs[..<i].reduce(0) { $0 + $1.duree })
                }
                Color.clear.frame(height: 90)
            }
            .padding(20)
        }
        .background(Theme.encre)
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom) {
            Button {
                let s = Seance(cours: c, depuisBloc: depart, voix: voix, voixChaqueRound: voixRounds)
                seance = s
            } label: {
                Text(depart == 0 ? "Go" : "Go depuis « \(c.blocs[depart].titre) »")
                    .font(Theme.affiche(depart == 0 ? 34 : 22)).textCase(.uppercase).lineLimit(1)
                    .frame(maxWidth: .infinity).frame(height: 68)
                    .background(Theme.citron, in: .rect(cornerRadius: 18))
                    .foregroundStyle(Theme.encre)
            }
            .padding(.horizontal, 20).padding(.bottom, 8)
            .background(LinearGradient(colors: [Theme.encre.opacity(0), Theme.encre], startPoint: .top, endPoint: .center))
        }
        .fullScreenCover(item: $seance) { s in
            VueCourse(seance: s) { s.quitter(); seance = nil }
                .onAppear { s.lancer() }
        }
    }

    private func stat(_ k: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(k).font(Theme.affiche(13)).tracking(2).textCase(.uppercase).foregroundStyle(Theme.discret)
            Text(v).font(Theme.affiche(34)).foregroundStyle(Theme.texte)
        }
    }

    private func ligne(_ i: Int, _ b: Bloc, debut: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Button { withAnimation(.snappy) { ouvert = ouvert == i ? nil : i } } label: {
                HStack(spacing: 12) {
                    Text(formatChrono(Double(debut))).font(Theme.affiche(17)).foregroundStyle(Theme.discret).frame(width: 48, alignment: .leading)
                    RoundedRectangle(cornerRadius: 2).fill(Theme.couleur(b.famille)).frame(width: 4, height: 26)
                    Text(b.titre).font(Theme.texte(17, gras: true)).foregroundStyle(Theme.texte).multilineTextAlignment(.leading)
                    Spacer()
                    Text("\(Int((Double(b.duree) / 60).rounded()))′").font(Theme.affiche(19)).foregroundStyle(Theme.attenue)
                }
            }
            .buttonStyle(.plain)
            if ouvert == i {
                VStack(alignment: .leading, spacing: 8) {
                    if !b.description.isEmpty { Text(b.description.joined(separator: " ")).font(Theme.texte(15)) }
                    if !b.consigne.isEmpty { Text("Consigne : ").bold() + Text(b.consigne) }
                    if !b.materiel.isEmpty { Text("Matériel : ").bold() + Text(b.materiel) }
                    ForEach(Array(b.sequences.enumerated()), id: \.offset) { _, q in
                        HStack {
                            Text(Theme.nomType(q.type)).font(Theme.affiche(14)).textCase(.uppercase)
                                .foregroundStyle(q.type == .travail ? Theme.couleur(b.famille) : Theme.discret).frame(width: 74, alignment: .leading)
                            Text(q.libelle + (q.miRound.isEmpty ? "" : " · ⇄")).font(Theme.texte(14))
                            Spacer()
                            Text(formatChrono(Double(q.duree))).font(Theme.affiche(18))
                        }
                    }
                    Button { depart = i; ouvert = nil } label: {
                        Label(depart == i ? "Départ ici" : "Démarrer depuis ce bloc", systemImage: "play.fill")
                            .font(Theme.texte(15, gras: true))
                    }
                    .disabled(depart == i)
                }
                .font(Theme.texte(14)).foregroundStyle(Theme.attenue)
                .padding(.leading, 64)
            }
        }
        .padding(.vertical, 6)
        .overlay(alignment: .leading) {
            if depart == i { Rectangle().fill(Theme.citron).frame(width: 3).offset(x: -12) }
        }
    }
}

extension Seance: Identifiable {
    nonisolated var id: ObjectIdentifier { ObjectIdentifier(self) }
}
