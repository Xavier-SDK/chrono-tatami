import SwiftUI
import Observation
import ChronoTatamiCore

/// Couleurs et typographies de Chrono Tatami (mêmes valeurs que l'app web).
enum Theme {
    static let encre = Color(hex: 0x0B0B0C)
    static let panneau = Color(hex: 0x141517)
    static let panneau2 = Color(hex: 0x1B1C1F)
    static let trait = Color(hex: 0x2A2C30)
    static let graphite = Color(hex: 0x222428)
    static let texte = Color(hex: 0xF2EFE6)
    static let attenue = Color(hex: 0xA3A5AA)
    static let discret = Color(hex: 0x8E9096)
    static let citron = Color(hex: 0xC6FF1A)

    /// Couleur de la phase : celle choisie dans les réglages, sinon celle par défaut.
    @MainActor static func couleur(_ f: Famille) -> Color { Color(hex: Palette.partagee.hex(f)) }

    static func couleurParDefaut(_ f: Famille) -> UInt32 {
        switch f {
        case .ouverture: 0xF2EFE6
        case .echauffement: 0xFF7A1A
        case .techniques: 0xC6FF1A
        case .pratique: 0xFF3B30
        case .calme: 0x3DB8FF
        }
    }

    /// Big Shoulders Display Black : chiffres et titres.
    static func affiche(_ taille: CGFloat) -> Font { .custom("BigShouldersDisplay-Black", fixedSize: taille) }
    static func afficheRelative(_ taille: CGFloat) -> Font { .custom("BigShouldersDisplay-Black", size: taille) }
    /// Barlow : texte courant.
    static func texte(_ taille: CGFloat, gras: Bool = false) -> Font {
        .custom(gras ? "Barlow-Bold" : "Barlow-SemiBold", size: taille)
    }

    static func nomType(_ t: TypeSequence) -> String {
        switch t {
        case .travail: "Travail"
        case .repos: "Repos"
        case .consigne: "Consignes"
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}

/// Couleurs des phases modifiées dans les réglages (iPhone), enregistrées dans UserDefaults.
@MainActor @Observable
final class Palette {
    static let partagee = Palette()
    private static let cle = "couleurs"
    private(set) var choix: [String: UInt32]

    private init() {
        choix = UserDefaults.standard.dictionary(forKey: Self.cle)?.compactMapValues { ($0 as? NSNumber)?.uint32Value } ?? [:]
    }

    func hex(_ f: Famille) -> UInt32 { choix[f.rawValue] ?? Theme.couleurParDefaut(f) }
    var modifiee: Bool { !choix.isEmpty }

    func definir(_ f: Famille, _ hex: UInt32?) {
        choix[f.rawValue] = hex == Theme.couleurParDefaut(f) ? nil : hex
        UserDefaults.standard.set(choix.mapValues { NSNumber(value: $0) }, forKey: Self.cle)
    }

    func retablir() {
        choix = [:]
        UserDefaults.standard.removeObject(forKey: Self.cle)
    }
}

extension Color {
    /// 0xRRGGBB de la couleur, en sRGB.
    var hex: UInt32 {
        let c = self.resolve(in: EnvironmentValues())
        func o(_ v: Float) -> UInt32 { UInt32(max(0, min(255, (v * 255).rounded()))) }
        return o(c.red) << 16 | o(c.green) << 8 | o(c.blue)
    }
}
