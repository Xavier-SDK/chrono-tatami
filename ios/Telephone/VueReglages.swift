import AVFoundation
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
    /// Écoute de la playlist depuis les réglages.
    @State private var apercu: LecteurSeance?
    @State private var extraitCoach: AVAudioPlayer?
    private let palette = Palette.partagee

    var body: some View {
        @Bindable var playlist = playlist
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
                    if coach, Voix.enregistrementsCoach {
                        Button { ecouterCoach() } label: { Label("Écouter le coach", systemImage: "megaphone.fill") }
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
                    if !playlist.vide {
                        Button { basculerApercu() } label: {
                            Label(apercu == nil ? "Écouter la playlist" : "Arrêter l'écoute",
                                  systemImage: apercu == nil ? "play.circle.fill" : "stop.circle.fill")
                        }
                        if let a = apercu, let m = a.courant {
                            Text("♪ " + m.nom + (m.artiste.isEmpty ? "" : " · " + m.artiste))
                                .font(.footnote).foregroundStyle(Theme.attenue).lineLimit(1)
                        }
                    }
                    Toggle("Lecture aléatoire", isOn: $playlist.aleatoire)
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
            .onChange(of: volume) { _, v in apercu?.synchroniser(voulue: true, niveau: Float(v)) }
            .onChange(of: playlist.resume) { arreterApercu() }
            .onChange(of: voirPlaylist) { if voirPlaylist { arreterApercu() } }
            .onDisappear { arreterApercu() }
        }
    }

    private func basculerApercu() {
        if apercu != nil { arreterApercu(); return }
        let s = AVAudioSession.sharedInstance()
        try? s.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? s.setActive(true)
        let l = playlist.lecteur()
        l.synchroniser(voulue: true, niveau: Float(volume))
        apercu = l
    }

    private func ecouterCoach() {
        let urls = (Bundle.main.urls(forResourcesWithExtension: "m4a", subdirectory: nil) ?? [])
            .filter { $0.lastPathComponent.hasPrefix("coach-") }
        guard let u = urls.randomElement(), let p = try? AVAudioPlayer(contentsOf: u) else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers, .duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        extraitCoach = p
        p.play()
    }

    private func arreterApercu() {
        apercu?.arreter()
        apercu = nil
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
