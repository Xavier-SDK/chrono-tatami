import AVFoundation
import SwiftUI
import ChronoTatamiCore

/// Choix de la voix des annonces : la meilleure voix française installée, ou celle choisie dans les réglages.
enum Voix {
    static let cleVoix = "voixId"
    static let cleDebit = "voixDebit"
    static let cleCoach = "coach"

    /// Phrases enregistrées du coach (voix Kevin, ElevenLabs v4) présentes dans l'app.
    static var enregistrementsCoach: Bool {
        (Bundle.main.urls(forResourcesWithExtension: "m4a", subdirectory: nil) ?? []).contains { $0.lastPathComponent.hasPrefix("coach-") }
    }

    static var coach: Bool { UserDefaults.standard.object(forKey: cleCoach) as? Bool ?? true }

    /// Phrases du coach, tirées au hasard pour ne pas répéter la même.
    static func phrases(_ e: Encouragement) -> [String] {
        switch e {
        case .debutTravail: ["C'est parti !", "Allez, on y va !", "Go, go, go !", "À vous de jouer !", "On attaque, allez !"]
        case .miTravail: ["Allez, on tient le rythme !", "Ne lâchez rien !", "C'est bien, continuez comme ça !", "On garde l'intensité !"]
        case .dixSecondes: ["Plus que dix secondes, à fond !", "Dix secondes, on donne tout !", "On lâche rien, dix secondes !", "Dernières secondes, allez allez !"]
        case .dernierRound: ["Dernier round ! Tout ce qui vous reste !", "Dernier effort, on finit fort !", "Allez, le dernier, on donne tout !"]
        case .repos: ["Bien joué. Respirez.", "Repos, on récupère.", "Bon travail. Soufflez, ça repart bientôt.", "Récupérez, buvez un coup."]
        case .fin: ["Fin de la séance. Bravo à tous, beau travail !"]
        }
    }

    /// Voix françaises utilisables, de la meilleure à la moins bonne. Les voix « fantaisie » d'iOS sont écartées.
    static func disponibles() -> [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("fr") }
            .filter { !$0.identifier.contains("eloquence") && !$0.identifier.contains("speech.synthesis.voice") }
            .sorted { rang($0) > rang($1) || (rang($0) == rang($1) && $0.name < $1.name) }
    }

    private static func rang(_ v: AVSpeechSynthesisVoice) -> Int {
        var r = 0
        if v.voiceTraits.contains(.isPersonalVoice) { r += 50 }
        switch v.quality {
        case .premium: r += 30
        case .enhanced: r += 20
        default: r += 10
        }
        if v.language == "fr-FR" { r += 5 }
        return r
    }

    /// Voix choisie dans les réglages si elle est encore installée, sinon la meilleure disponible.
    static func choisie() -> AVSpeechSynthesisVoice? {
        if let id = UserDefaults.standard.string(forKey: cleVoix), let v = AVSpeechSynthesisVoice(identifier: id) { return v }
        return disponibles().first ?? AVSpeechSynthesisVoice(language: "fr-FR")
    }

    static func qualite(_ v: AVSpeechSynthesisVoice) -> String {
        if v.voiceTraits.contains(.isPersonalVoice) { return "Voix personnelle" }
        switch v.quality {
        case .premium: return "Premium"
        case .enhanced: return "Améliorée"
        default: return "Standard"
        }
    }

    static func region(_ v: AVSpeechSynthesisVoice) -> String {
        switch v.language {
        case "fr-FR": "France"
        case "fr-CA": "Canada"
        case "fr-BE": "Belgique"
        case "fr-CH": "Suisse"
        default: v.language
        }
    }

    /// Annonce prête à dire : débit réglé, petites pauses aux séparateurs, abréviations des fiches développées.
    static func annonce(_ texte: String) -> AVSpeechUtterance {
        let u = AVSpeechUtterance(string: prononcer(texte))
        u.voice = choisie()
        let debit = UserDefaults.standard.object(forKey: cleDebit) as? Double ?? 1
        // Mode coach : diction plus rapide et plus haute, plus tonique.
        u.rate = min(AVSpeechUtteranceMaximumSpeechRate, AVSpeechUtteranceDefaultSpeechRate * Float(debit) * (coach ? 1.08 : 1))
        u.pitchMultiplier = coach ? 1.12 : 1
        u.preUtteranceDelay = 0.05
        u.prefersAssistiveTechnologySettings = false
        return u
    }

    /// Ce que la voix doit lire : « 2/5 » → « 2 sur 5 », « R1 » → « round 1 », « 30" » → « 30 secondes »…
    static func prononcer(_ texte: String) -> String {
        var t = texte
        let regles: [(String, String)] = [
            (#"(\d+)\s*/\s*(\d+)"#, "$1 sur $2"),
            (#"\bR(\d+)\b"#, "round $1"),
            (#"(\d+)\s*(?:"|″|s\b)"#, "$1 secondes"),
            (#"(\d+)\s*(?:'|′|min\b)"#, "$1 minutes"),
            (#"(\d+)\s*m\b"#, "$1 mètres"),
            (#"\bx\s*(\d+)"#, "fois $1"),
            (#"\s*\+\s*"#, " plus "),
            (#"\s*[→>]\s*"#, ", "),
            (#"\s*[·|]\s*"#, ", "),
            (#"[«»⇄♪*_#]"#, " "),
            (#"\s{2,}"#, " "),
        ]
        for (motif, rempl) in regles {
            t = t.replacingOccurrences(of: motif, with: rempl, options: .regularExpression)
        }
        return t.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ",")))
    }
}

/// Réglage de la voix : liste des voix françaises installées, essai, débit, voix personnelle.
struct VueVoix: View {
    @AppStorage(Voix.cleVoix) private var choix = ""
    @AppStorage(Voix.cleDebit) private var debit = 1.0
    @State private var voix: [AVSpeechSynthesisVoice] = Voix.disponibles()
    @State private var statutPerso = AVSpeechSynthesizer.personalVoiceAuthorizationStatus
    @State private var lecteur = AVSpeechSynthesizer()

    private var choisie: String { Voix.choisie()?.identifier ?? "" }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading) {
                    Text("Débit : \(Int((debit * 100).rounded())) %")
                    Slider(value: $debit, in: 0.8...1.2, step: 0.05) { _ in essayer(Voix.choisie()) }
                }
                Button { essayer(Voix.choisie()) } label: { Label("Écouter un exemple", systemImage: "play.circle") }
            }
            Section {
                ForEach(voix, id: \.identifier) { v in
                    Button {
                        choix = v.identifier
                        essayer(v)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(v.name).foregroundStyle(Theme.texte)
                                Text("\(Voix.qualite(v)) · \(Voix.region(v))").font(.footnote).foregroundStyle(Theme.attenue)
                            }
                            Spacer()
                            if v.identifier == choisie { Image(systemName: "checkmark").foregroundStyle(Theme.citron) }
                        }
                    }
                }
                if !choix.isEmpty {
                    Button("Choisir automatiquement la meilleure") { choix = "" }
                }
            } header: { Text("Voix françaises installées") } footer: {
                Text("Pour une voix plus naturelle, télécharge une voix « Premium » ou « Améliorée » dans Réglages > Accessibilité > Contenu énoncé > Voix > Français, puis reviens ici.")
            }
            Section {
                switch statutPerso {
                case .authorized:
                    Text("Ta voix personnelle apparaît dans la liste ci-dessus si elle est créée sur cet iPhone.")
                        .foregroundStyle(Theme.attenue)
                case .denied:
                    Text("Accès refusé. Autorise-le dans Réglages > Apps > Chrono Tatami.").foregroundStyle(Theme.attenue)
                case .unsupported:
                    Text("La voix personnelle n'est pas disponible sur cet appareil.").foregroundStyle(Theme.attenue)
                default:
                    Button("Utiliser ma voix personnelle") {
                        AVSpeechSynthesizer.requestPersonalVoiceAuthorization { s in
                            Task { @MainActor in
                                statutPerso = s
                                voix = Voix.disponibles()
                            }
                        }
                    }
                }
            } header: { Text("Ma voix") } footer: {
                Text("La voix personnelle d'iOS lit les annonces avec ta propre voix. Elle se crée dans Réglages > Accessibilité > Voix personnelle (environ 15 minutes de lecture).")
            }
        }
        .navigationTitle("Voix")
        .onAppear { voix = Voix.disponibles() }
    }

    private func essayer(_ v: AVSpeechSynthesisVoice?) {
        let u = Voix.annonce(Voix.coach
            ? "C'est parti ! Techniques, round 2 sur 4. Plus que dix secondes, à fond !"
            : "Techniques, round 2 sur 4. Changez de rôle. Dans 10 secondes : mise en pratique.")
        u.voice = v
        lecteur.stopSpeaking(at: .immediate)
        lecteur.speak(u)
    }
}
