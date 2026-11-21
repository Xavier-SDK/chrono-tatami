import AVFoundation
import ChronoTatamiCore

/// Bips, gong et voix. Le moteur audio reste actif pendant la séance : l'app continue de tourner écran verrouillé.
@MainActor
final class Sons {
    private let moteur = AVAudioEngine()
    private let lecteur = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private let voix = AVSpeechSynthesizer()
    private lazy var tampons: [String: AVAudioPCMBuffer] = [
        "bip": ton([(880, 0)], duree: 0.16, decroissance: 30),
        "double": ton([(1046, 0), (1046, 0.2)], duree: 0.38, decroissance: 30),
        "triple": ton([(1318, 0), (1318, 0.16), (1318, 0.32)], duree: 0.5, decroissance: 35),
        "gong": ton([(196, 0), (294, 0), (392, 0)], duree: 2.2, decroissance: 2.2),
    ]
    var voixActive = true
    private(set) var parle = false

    init() {
        moteur.attach(lecteur)
        moteur.connect(lecteur, to: moteur.mainMixerNode, format: format)
    }

    func demarrer() {
        let s = AVAudioSession.sharedInstance()
        try? s.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? s.setActive(true)
        attenue = false
        if !moteur.isRunning { try? moteur.start() }
        if !lecteur.isPlaying { lecteur.play() }
    }

    /// Atténue la musique des autres lecteurs (playlist Musique, autre app) pendant la voix et les consignes.
    /// iOS n'applique le retour au volume normal qu'en désactivant la session : on suspend le moteur le temps de le faire.
    private var attenue = false
    func attenuer(_ oui: Bool) {
        guard oui != attenue else { return }
        attenue = oui
        let s = AVAudioSession.sharedInstance()
        if oui {
            try? s.setCategory(.playback, mode: .default, options: [.mixWithOthers, .duckOthers])
            try? s.setActive(true)
        } else {
            moteur.pause()
            try? s.setActive(false, options: .notifyOthersOnDeactivation)
            try? s.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try? s.setActive(true)
            try? moteur.start()
            if !lecteur.isPlaying { lecteur.play() }
        }
    }

    func arreter() {
        lecteur.stop(); moteur.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func jouer(_ nom: String) {
        guard let t = tampons[nom] else { return }
        if !moteur.isRunning { demarrer() }
        lecteur.scheduleBuffer(t, at: nil, options: .interrupts)
        if !lecteur.isPlaying { lecteur.play() }
    }

    func dire(_ texte: String, forcee: Bool = false) {
        guard voixActive || forcee else { return }
        let u = Voix.annonce(texte)
        // Juste après une relance du coach, l'annonce passe à la suite au lieu de la couper.
        if Date().timeIntervalSince(relance) > 0.5 { voix.stopSpeaking(at: .immediate) }
        if let c = clip, c.isPlaying { u.preUtteranceDelay = c.duration - c.currentTime + 0.1 }
        voix.speak(u)
    }
    private var relance = Date.distantPast

    /// Relance du coach : un enregistrement s'il y en a dans l'app (Coach/<cas>-<n>.m4a), sinon la synthèse vocale.
    private var clip: AVAudioPlayer?
    private var derniere: [Encouragement: String] = [:]
    func encourager(_ e: Encouragement) {
        guard voixActive || e == .fin else { return }
        if let url = Self.clips(e).filter({ $0.lastPathComponent != derniere[e] }).randomElement() ?? Self.clips(e).first,
           let p = try? AVAudioPlayer(contentsOf: url) {
            derniere[e] = url.lastPathComponent
            voix.stopSpeaking(at: .immediate)
            clip?.stop()
            clip = p
            p.play()
            relance = Date()
            return
        }
        let choix = Voix.phrases(e).filter { $0 != derniere[e] }.randomElement() ?? Voix.phrases(e)[0]
        derniere[e] = choix
        dire(choix, forcee: true)
        relance = Date()
    }

    private static func clips(_ e: Encouragement) -> [URL] {
        ["m4a", "mp3", "wav"].flatMap { Bundle.main.urls(forResourcesWithExtension: $0, subdirectory: nil) ?? [] }
            .filter { $0.lastPathComponent.hasPrefix("coach-\(e.rawValue)-") }
    }

    var voixEnCours: Bool { voix.isSpeaking || clip?.isPlaying == true }

    /// Somme de sinus amortis : (fréquence, départ en secondes).
    private func ton(_ notes: [(Double, Double)], duree: Double, decroissance: Double) -> AVAudioPCMBuffer {
        let sr = format.sampleRate, n = AVAudioFrameCount(duree * sr)
        let b = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: n)!
        b.frameLength = n
        let p = b.floatChannelData![0]
        for i in 0..<Int(n) {
            let t = Double(i) / sr
            var v = 0.0
            for (f, d) in notes where t >= d {
                let u = t - d
                let attaque = min(1, u / 0.005)
                v += sin(2 * .pi * f * u) * exp(-u * decroissance) * attaque
                if decroissance < 5 { v += 0.3 * sin(2 * .pi * f * 2.76 * u) * exp(-u * decroissance * 2) }
            }
            p[i] = Float(v / Double(max(1, notes.count)) * 0.9)
        }
        return b
    }
}
