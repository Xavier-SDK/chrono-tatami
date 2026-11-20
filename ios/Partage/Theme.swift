import SwiftUI
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

    static func couleur(_ f: Famille) -> Color {
        switch f {
        case .ouverture: Color(hex: 0xF2EFE6)
        case .echauffement: Color(hex: 0xFF7A1A)
        case .techniques: Color(hex: 0xC6FF1A)
        case .pratique: Color(hex: 0xFF3B30)
        case .calme: Color(hex: 0x3DB8FF)
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
