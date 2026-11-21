import SwiftUI
import ChronoTatamiCore

/// Réglages de l'app, comme l'écran Réglages de l'app web.
struct VueReglages: View {
    @Environment(Playlist.self) private var playlist
    @Environment(\.dismiss) private var fermer
    @AppStorage("bips") private var bips = true
    @AppStorage("gong") private var gong = true
    @AppStorage("voix") private var voix = true
    @AppStorage("voixRounds") private var voixRounds = false
    @AppStorage("musVol") private var volume = 0.8
    @AppStorage("musBas") private var baisse = 20.0
    @AppStorage("veille") private var veille = true
    @AppStorage("test") private var test = false
    @State private var voirPlaylist = false
    @AppStorage(Voix.cleCoach) private var coach = true
    private let palette = Palette.partagee

    var body: some View {
        NavigationStack {
            Form {
                Section("Sons et voix") {
                    Toggle("Bips 3-2-1", isOn: $bips)
                    Toggle("Gong de fin de séquence", isOn: $gong)
                    Toggle(isOn: $voix) {
                        Text("Voix")
                        Text("Nouveaux blocs, changements de rôle")
                    }
                    Toggle("Voix : chaque round", isOn: $voixRounds).disabled(!voix)
                }
                Section {
                    Toggle(isOn: $coach) {
                        Text("Mode coach")
                        Text("Relances pendant l'effort, le repos et le dernier round")
                    }
                    NavigationLink { VueVoix() } label: {
                        HStack {
                            Text("Voix")
                            Spacer()
                            Text(Voix.choisie().map { "\($0.name) · \(Voix.qualite($0))" } ?? "").foregroundStyle(Theme.attenue)
                        }
                    }
                } header: { Text("Coach") }
                Section {
                    Button { voirPlaylist = true } label: {
                        HStack {
                            Label("Ma playlist", systemImage: "music.note.list").foregroundStyle(Theme.texte)
                            Spacer()
                            Text(playlist.resume).foregroundStyle(Theme.attenue)
                        }
                    }
                    if playlist.appleMusic == nil {
                        VStack(alignment: .leading) {
                            Text("Volume : \(Int(volume * 100)) %")
                            Slider(value: $volume, in: 0...1)
                        }
                        VStack(alignment: .leading) {
                            Text("Volume baissé : \(Int(baisse)) %")
                            Slider(value: $baisse, in: 0...60, step: 5)
                        }
                    }
                } header: { Text("Musique") } footer: {
                    Text(playlist.appleMusic == nil
                         ? "Le volume baissé s'applique quand la voix parle et pendant les consignes."
                         : "Avec une playlist de l'app Musique, le volume se règle avec les boutons de l'iPhone.")
                }
                Section("Affichage") {
                    Toggle(isOn: $veille) {
                        Text("Écran toujours allumé")
                        Text("Pendant l'animation du cours")
                    }
                }
                Section("Essai") {
                    Toggle(isOn: $test) {
                        Text("Mode essai ×10")
                        Text("Pour tester une séance en quelques minutes")
                    }
                }
                Section {
                    ForEach(Famille.allCases, id: \.self) { f in
                        ColorPicker(Self.nom(f), selection: Binding(
                            get: { Theme.couleur(f) },
                            set: { palette.definir(f, $0.hex) }
                        ), supportsOpacity: false)
                    }
                    if palette.modifiee {
                        Button("Rétablir les couleurs d'origine") { palette.retablir() }
                    }
                } header: { Text("Couleurs des phases") } footer: {
                    Text("Utilisées sur l'iPhone et la montre.")
                }
                Section {} footer: {
                    Text("Chrono Tatami \(Self.version)").frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Réglages")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("OK") { fermer() } } }
            .sheet(isPresented: $voirPlaylist) { VuePlaylist() }

        }
    }

    private static func nom(_ f: Famille) -> String {
        switch f {
        case .ouverture: "Salut"
        case .echauffement: "Échauffement"
        case .techniques: "Techniques"
        case .pratique: "Pratique"
        case .calme: "Retour au calme"
        }
    }

    private static var version: String {
        let i = Bundle.main.infoDictionary
        return "\(i?["CFBundleShortVersionString"] as? String ?? "") (\(i?["CFBundleVersion"] as? String ?? ""))"
    }
}
