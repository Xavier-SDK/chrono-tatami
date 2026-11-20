import Foundation
import Observation
import ChronoTatamiCore

/// Une fiche de cours : incluse dans l'app ou importée (copiée dans Documents/Seances).
struct Fiche: Identifiable, Hashable {
    let id: String
    let url: URL
    let incluse: Bool
    let cours: Cours
    static func == (a: Fiche, b: Fiche) -> Bool { a.id == b.id }
    func hash(into h: inout Hasher) { h.combine(id) }
    var date: String { cours.meta["date"] ?? "" }
    var lieu: String { [cours.meta["heure"], cours.meta["lieu"]].compactMap { $0 }.joined(separator: " · ") }
}

@MainActor @Observable
final class Bibliotheque {
    private(set) var fiches: [Fiche] = []
    var erreur: String?

    private var dossier: URL {
        let d = URL.documentsDirectory.appending(path: "Seances", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    init() { recharger() }

    func recharger() {
        var out: [Fiche] = []
        let incluses = Bundle.main.urls(forResourcesWithExtension: "md", subdirectory: nil) ?? []
        for u in incluses { if let f = lire(u, incluse: true) { out.append(f) } }
        let importees = (try? FileManager.default.contentsOfDirectory(at: dossier, includingPropertiesForKeys: nil)) ?? []
        for u in importees where u.pathExtension.lowercased() == "md" {
            if let f = lire(u, incluse: false) { out.removeAll { $0.id == f.id }; out.append(f) }
        }
        fiches = out.sorted { $0.id > $1.id }
    }

    private func lire(_ u: URL, incluse: Bool) -> Fiche? {
        guard let t = try? String(contentsOf: u, encoding: .utf8) else { return nil }
        let c = lireCours(t)
        guard !c.blocs.isEmpty else { return nil }
        return Fiche(id: u.deletingPathExtension().lastPathComponent, url: u, incluse: incluse, cours: c)
    }

    /// Importe une fiche choisie dans Fichiers.
    func importer(_ u: URL) {
        let acces = u.startAccessingSecurityScopedResource()
        defer { if acces { u.stopAccessingSecurityScopedResource() } }
        guard let t = try? String(contentsOf: u, encoding: .utf8) else { erreur = "Fichier illisible."; return }
        let c = lireCours(t)
        guard !c.blocs.isEmpty else { erreur = "Ce fichier n'est pas une fiche Chrono Tatami."; return }
        let dest = dossier.appending(path: u.lastPathComponent)
        try? FileManager.default.removeItem(at: dest)
        do { try t.write(to: dest, atomically: true, encoding: .utf8); erreur = nil } catch { erreur = "Import impossible." }
        recharger()
    }

    func supprimer(_ f: Fiche) {
        guard !f.incluse else { return }
        try? FileManager.default.removeItem(at: f.url)
        recharger()
    }
}
