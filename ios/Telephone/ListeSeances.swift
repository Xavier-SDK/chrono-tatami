import SwiftUI
import ChronoTatamiCore

struct ListeSeances: View {
    @Environment(Bibliotheque.self) private var bib
    @State private var importer = false
    @State private var reglages = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Chrono Tatami")
                            .font(Theme.affiche(18)).tracking(2.8).foregroundStyle(Theme.citron).textCase(.uppercase)
                        Spacer()
                        Button { reglages = true } label: {
                            Image(systemName: "slider.horizontal.3").font(.system(size: 18, weight: .semibold))
                                .frame(width: 44, height: 44)
                                .background(Theme.panneau2, in: .circle)
                        }
                        .foregroundStyle(Theme.texte)
                        .accessibilityLabel("Réglages")
                    }
                    Text("Séances")
                        .font(Theme.affiche(52)).textCase(.uppercase).foregroundStyle(Theme.texte)
                    if let e = bib.erreur {
                        Text(e).font(Theme.texte(15)).foregroundStyle(.red)
                    }
                    ForEach(bib.fiches) { f in
                        NavigationLink(value: f) { Carte(fiche: f) }
                            .buttonStyle(.plain)
                            .contextMenu {
                                if !f.incluse {
                                    Button("Supprimer", systemImage: "trash", role: .destructive) { bib.supprimer(f) }
                                }
                            }
                    }
                    Button { importer = true } label: {
                        Label("Importer une fiche .md", systemImage: "square.and.arrow.down")
                            .font(Theme.texte(17, gras: true))
                            .frame(maxWidth: .infinity).padding(.vertical, 16)
                            .background(Theme.panneau2, in: .rect(cornerRadius: 16))
                    }
                    .buttonStyle(.plain).foregroundStyle(Theme.texte)
                }
                .padding(20)
            }
            .background(Theme.encre)
            .navigationDestination(for: Fiche.self) { VuePrep(fiche: $0) }
            .fileImporter(isPresented: $importer, allowedContentTypes: [.init(filenameExtension: "md") ?? .plainText, .plainText]) { r in
                if case let .success(u) = r { bib.importer(u) }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $reglages) { VueReglages() }
        }
    }
}

private struct Carte: View {
    let fiche: Fiche
    var body: some View {
        let c = fiche.cours
        VStack(alignment: .leading, spacing: 8) {
            Text([fiche.date, fiche.lieu].filter { !$0.isEmpty }.joined(separator: " · "))
                .font(Theme.affiche(15)).tracking(2).textCase(.uppercase).foregroundStyle(Theme.citron)
            Text(c.titre.isEmpty ? fiche.id : c.titre)
                .font(Theme.affiche(34)).textCase(.uppercase).foregroundStyle(Theme.texte)
                .multilineTextAlignment(.leading).lineSpacing(-6)
            HStack {
                Text(minutes(c.total)).font(Theme.texte(15, gras: true))
                Text("· \(c.blocs.count) blocs").font(Theme.texte(15))
                Spacer()
                if !c.erreurs.isEmpty {
                    Label("\(c.erreurs.count)", systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                        .font(Theme.texte(14, gras: true))
                }
            }
            .foregroundStyle(Theme.attenue)
            BarreComposition(cours: c)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.panneau, in: .rect(cornerRadius: 20))
    }
}
