import Foundation

/// Messages échangés entre l'iPhone et la montre (WatchConnectivity transporte des dictionnaires).
public enum Lien {
    public static let cleEtat = "etat"
    public static let cleCommande = "commande"
    public static let cleRepos = "repos"          // aucune séance en cours
    public static let cleDemande = "demande"      // la montre redemande l'état (retour de veille)

    public static func message(_ etat: EtatChrono) -> [String: Any] {
        guard let d = try? JSONEncoder().encode(etat) else { return [:] }
        return [cleEtat: d]
    }

    public static func etat(depuis m: [String: Any]) -> EtatChrono? {
        guard let d = m[cleEtat] as? Data else { return nil }
        return try? JSONDecoder().decode(EtatChrono.self, from: d)
    }

    public static func message(_ c: CommandeMontre) -> [String: Any] { [cleCommande: c.rawValue] }

    public static func commande(depuis m: [String: Any]) -> CommandeMontre? {
        (m[cleCommande] as? String).flatMap(CommandeMontre.init(rawValue:))
    }
}
