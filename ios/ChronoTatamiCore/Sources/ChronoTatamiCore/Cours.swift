import Foundation

/// Type d'une séquence minutée de la fiche (`- [travail] …`).
public enum TypeSequence: String, Codable, Sendable {
    case travail, repos, consigne
}

/// Famille d'une section, qui donne sa couleur (Salut, Échauffement, Techniques, Pratique, Calme).
public enum Famille: String, Codable, Sendable, CaseIterable {
    case ouverture, echauffement, techniques, pratique, calme

    public var nom: String {
        switch self {
        case .ouverture: "Salut"
        case .echauffement: "Échauffement"
        case .techniques: "Techniques"
        case .pratique: "Mise en pratique"
        case .calme: "Retour au calme"
        }
    }

    static func depuis(titre: String) -> Famille {
        let t = titre.lowercased()
        if t.contains("ouvert") || t.contains("accueil") { return .ouverture }
        if t.contains("échauf") || t.contains("echauf") { return .echauffement }
        if ["pratique", "restitution", "combat", "sparring"].contains(where: t.contains) { return .pratique }
        if ["calme", "étire", "etire"].contains(where: t.contains) { return .calme }
        return .techniques
    }
}

public struct SequenceMinutee: Codable, Sendable, Equatable {
    public var type: TypeSequence
    public var libelle: String
    /// Durée en secondes.
    public var duree: Int
    /// Consigne de mi-round (changement de rôle), vide sinon.
    public var miRound: String
}

public struct Bloc: Codable, Sendable {
    public var titre: String
    public var prevu: Int?          // minutes
    public var famille: Famille
    public var section: Int         // index de la section
    public var description: [String] = []
    public var consigne = ""
    public var materiel = ""
    public var debrief = ""
    public var sequences: [SequenceMinutee] = []
    public var duree: Int { sequences.reduce(0) { $0 + $1.duree } }
}

public struct Section: Codable, Sendable {
    public var titre: String
    public var prevu: Int?          // minutes
    public var famille: Famille
    /// Marqueur ♪ dans le titre de la section : musique prévue.
    public var musique: Bool
    public var blocs: [Int] = []    // index des blocs
    public var duree = 0
}

public struct Cours: Codable, Sendable {
    public var meta: [String: String]
    public var titre: String
    public var objectif: String
    public var sections: [Section]
    public var blocs: [Bloc]
    public var total: Int
    public var erreurs: [String]
    public var estValide: Bool { erreurs.isEmpty && total > 0 && !blocs.isEmpty }
}

// MARK: - Lecture du format chrono-tatami/1

private func match(_ s: String, _ motif: String) -> [String?]? {
    guard let re = try? NSRegularExpression(pattern: motif, options: []) else { return nil }
    let ns = s as NSString
    guard let m = re.firstMatch(in: s, range: NSRange(location: 0, length: ns.length)) else { return nil }
    return (0..<m.numberOfRanges).map { i in
        let r = m.range(at: i)
        return r.location == NSNotFound ? nil : ns.substring(with: r)
    }
}

/// « 2:30 » → 150 secondes.
func lireDuree(_ s: String) -> Int? {
    guard let m = match(s, #"(\d+):(\d{2})"#), let a = Int(m[1] ?? ""), let b = Int(m[2] ?? "") else { return nil }
    return a * 60 + b
}

/// « 1h30 », « 23 min » → minutes.
func lireMinutes(_ s: String) -> Int? {
    if let m = match(s, #"(\d+)\s*h\s*(\d+)?"#), let h = Int(m[1] ?? "") { return h * 60 + (Int(m[2] ?? "") ?? 0) }
    if let m = match(s, #"(\d+)\s*min"#), let v = Int(m[1] ?? "") { return v }
    return nil
}

private func fmtMin(_ s: Int) -> String {
    s % 60 == 0 ? "\(s / 60)" : String(format: "%.1f", Double(s) / 60).replacingOccurrences(of: ".", with: ",")
}

public func lireCours(_ texte: String) -> Cours {
    let lignes = texte.replacingOccurrences(of: "\r", with: "").components(separatedBy: "\n")
    var meta: [String: String] = [:], sections: [Section] = [], blocs: [Bloc] = [], erreurs: [String] = []
    var i = 0
    if lignes.first?.trimmingCharacters(in: .whitespaces) == "---" {
        i = 1
        while i < lignes.count, lignes[i].trimmingCharacters(in: .whitespaces) != "---" {
            if let m = match(lignes[i], #"^([\w_]+)\s*:\s*(.*)$"#), let k = m[1] {
                meta[k] = (m[2] ?? "").trimmingCharacters(in: .whitespaces)
            }
            i += 1
        }
        i += 1
    }
    var titre = "", objectif = ""
    var blocCourant: Int? = nil

    while i < lignes.count {
        let L = lignes[i]; i += 1
        if let m = match(L, #"^#\s+(.*)"#) { titre = (m[1] ?? "").trimmingCharacters(in: .whitespaces); continue }
        if let m = match(L, #"^>\s*\*\*Objectif\s*:\*\*\s*(.*)"#) { objectif = (m[1] ?? "").trimmingCharacters(in: .whitespaces); continue }
        if let m = match(L, #"^##\s+(.*?)\s*·\s*(.*)$"#) ?? match(L, #"^##\s+(.*)$"#) {
            let t = (m[1] ?? "").replacingOccurrences(of: "♪", with: "").trimmingCharacters(in: .whitespaces)
            let reste = m.count > 2 ? m[2] : nil
            sections.append(Section(titre: t, prevu: reste.flatMap(lireMinutes), famille: .depuis(titre: t), musique: L.contains("♪")))
            blocCourant = nil
            continue
        }
        if let m = match(L, #"^###\s+(.*?)\s*·\s*(.*)$"#) ?? match(L, #"^###\s+(.*)$"#) {
            if sections.isEmpty { sections.append(Section(titre: "Séance", prevu: nil, famille: .techniques, musique: false)) }
            let t = (m[1] ?? "").trimmingCharacters(in: .whitespaces)
            let s = sections.count - 1
            let fam: Famille = t.lowercased().hasPrefix("salut") ? .ouverture : sections[s].famille
            let reste = m.count > 2 ? m[2] : nil
            blocs.append(Bloc(titre: t, prevu: reste.flatMap(lireMinutes), famille: fam, section: s))
            sections[s].blocs.append(blocs.count - 1)
            blocCourant = blocs.count - 1
            continue
        }
        guard let b = blocCourant else { continue }
        if let m = match(L, #"^-\s*\[(travail|repos|consigne)\]\s*(.*)$"#), let ty = m[1] {
            var parts = (m[2] ?? "").components(separatedBy: "·").map { $0.trimmingCharacters(in: .whitespaces) }
            var mi = ""
            if let k = parts.firstIndex(where: { $0.hasPrefix("⇄") }) {
                mi = parts[k].replacingOccurrences(of: "⇄", with: "").trimmingCharacters(in: .whitespaces)
                parts.remove(at: k)
            }
            guard let d = lireDuree(parts.last ?? "") else {
                erreurs.append("Durée manquante : « \(L.trimmingCharacters(in: .whitespaces)) »"); continue
            }
            parts.removeLast()
            blocs[b].sequences.append(SequenceMinutee(type: TypeSequence(rawValue: ty.lowercased()) ?? .travail,
                                               libelle: parts.joined(separator: " · "), duree: d, miRound: mi))
            continue
        }
        if let m = match(L, #"^\*\*Consigne\s*:\*\*\s*(.*)"#) { blocs[b].consigne = (m[1] ?? "").trimmingCharacters(in: .whitespaces); continue }
        if let m = match(L, #"^\*\*Matériel\s*:\*\*\s*(.*)"#) { blocs[b].materiel = (m[1] ?? "").trimmingCharacters(in: .whitespaces); continue }
        if let m = match(L, #"^\*\*Débrief\s*:\*\*\s*(.*)"#) { blocs[b].debrief = (m[1] ?? "").trimmingCharacters(in: .whitespaces); continue }
        let tl = L.trimmingCharacters(in: .whitespaces)
        if !tl.isEmpty { blocs[b].description.append(tl) }
    }

    var total = 0
    for s in sections.indices {
        var st = 0
        for bi in sections[s].blocs {
            let b = blocs[bi]
            st += b.duree
            if b.sequences.isEmpty { erreurs.append("« \(b.titre) » n’a aucune séquence minutée.") }
            else if let p = b.prevu, b.duree != p * 60 {
                erreurs.append("« \(b.titre) » : séquences = \(fmtMin(b.duree)) min, prévu \(p) min.")
            }
        }
        sections[s].duree = st
        total += st
        if let p = sections[s].prevu, st != p * 60 {
            erreurs.append("Section « \(sections[s].titre) » : \(fmtMin(st)) min, prévu \(p) min.")
        }
    }
    if let p = meta["duree"].flatMap(lireMinutes), total != p * 60 {
        erreurs.append("Total \(fmtMin(total)) min pour une séance de \(p) min.")
    }
    return Cours(meta: meta, titre: titre, objectif: objectif, sections: sections, blocs: blocs, total: total, erreurs: erreurs)
}
