import SwiftUI
import UniformTypeIdentifiers
import ChronoTatamiCore

/// Gestion de la playlist : import depuis Fichiers, ordre, suppression, lecture aléatoire.
struct VuePlaylist: View {
    @Environment(Playlist.self) private var playlist
    @Environment(\.dismiss) private var fermer
    @State private var importer = false
    @State private var message: String?

    var body: some View {
        @Bindable var playlist = playlist
        NavigationStack {
            List {
                Section {
                    NavigationLink { ChoixPlaylistApple() } label: {
                        HStack {
                            Label("Playlist de l'app Musique", systemImage: "music.note.list")
                            Spacer()
                            Text(playlist.appleMusic?.nom ?? "Aucune").foregroundStyle(Theme.attenue)
                        }
                    }
                    if playlist.appleMusic != nil {
                        Button("Utiliser les fichiers importés à la place", role: .destructive) { playlist.appleMusic = nil }
                    }
                    if !playlist.vide { EcoutePlaylist() }
                } header: { Text("Source") } footer: {
                    Text(playlist.appleMusic == nil
                         ? "Sans playlist Musique, la séance joue les fichiers importés ci-dessous."
                         : "La séance joue la playlist « \(playlist.appleMusic!.nom) » (titres Apple Music compris). Le volume se règle avec les boutons de l'iPhone ; iOS atténue la musique pendant la voix et les consignes.")
                }
                Section {
                    Toggle("Ordre aléatoire", isOn: $playlist.aleatoire)
                    Button { importer = true } label: { Label("Ajouter des morceaux", systemImage: "plus") }
                } footer: {
                    Text("Morceaux en MP3, M4A, AAC ou WAV depuis l'app Fichiers. Nom « Artiste - Titre » reconnu. Les titres Apple Music protégés ne s'importent pas.")
                }
                if !playlist.morceaux.isEmpty {
                    Section("\(playlist.morceaux.count) morceaux · \(minutes(Int(playlist.dureeTotale)))") {
                        ForEach(playlist.morceaux) { m in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(m.nom).font(Theme.texte(16, gras: true))
                                    if !m.artiste.isEmpty { Text(m.artiste).font(Theme.texte(14)).foregroundStyle(Theme.attenue) }
                                }
                                Spacer()
                                Text(formatChrono(m.duree)).font(Theme.affiche(17)).foregroundStyle(Theme.attenue)
                            }
                        }
                        .onDelete { playlist.supprimer($0) }
                        .onMove { playlist.deplacer($0, vers: $1) }
                    }
                }
            }
            .navigationTitle("Musique")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("OK") { fermer() } }
                if !playlist.morceaux.isEmpty { ToolbarItem(placement: .topBarLeading) { EditButton() } }
            }
            .fileImporter(isPresented: $importer, allowedContentTypes: [.audio], allowsMultipleSelection: true) { r in
                guard case let .success(urls) = r else { return }
                Task {
                    let n = await playlist.importer(urls)
                    message = n == 0 ? "Aucun morceau importé" : "\(n) morceau\(n > 1 ? "x" : "") ajouté\(n > 1 ? "s" : "")"
                }
            }
            .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {}
        }
    }
}
