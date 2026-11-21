import Foundation
import Testing
@testable import ChronoTatamiCore

private func fiche() throws -> String {
    let url = try #require(Bundle.module.url(forResource: "2026-11-19-debutants-dojo", withExtension: "md", subdirectory: "Fixtures"))
    return try String(contentsOf: url, encoding: .utf8)
}

@Test func lectureDeLaFicheDuDojo() throws {
    let c = lireCours(try fiche())
    #expect(c.erreurs == [])
    #expect(c.estValide)
    #expect(c.total == 90 * 60)
    #expect(c.meta["lieu"] == "DOJO Montauban")
    #expect(c.sections.first?.famille == .ouverture)
    #expect(c.blocs.first?.titre == "Salut")
}

@Test func marqueurMusiqueSurUneSection() {
    let c = lireCours("""
    ---
    duree: 3 min
    ---
    ## Échauffement · 2 min · ♪
    ### A · 2 min
    - [travail] x · 2:00
    ## Calme ♪
    ### B
    - [consigne] y · 1:00
    """)
    #expect(c.erreurs == [])
    #expect(c.sections.map(\.titre) == ["Échauffement", "Calme"])
    #expect(c.sections.map(\.musique) == [true, true])
    #expect(c.sections.map(\.famille) == [.echauffement, .calme])
    #expect(c.blocs.map(\.section) == [0, 1])
}

@Test func erreursDeDuree() {
    let c = lireCours("""
    ## Techniques · 5 min
    ### Bloc · 5 min
    - [travail] sans durée
    - [travail] Round · 2:00
    """)
    #expect(c.erreurs.contains("Durée manquante : « - [travail] sans durée »"))
    #expect(c.erreurs.contains("« Bloc » : séquences = 2 min, prévu 5 min."))
}

@Test func miRoundEtLibelles() {
    let c = lireCours("""
    ### Binômes
    - [travail] Round 1/2 · Clés · ⇄ Changez · 1:00
    """)
    let q = c.blocs[0].sequences[0]
    #expect(q.libelle == "Round 1/2 · Clés")
    #expect(q.miRound == "Changez")
    #expect(q.duree == 60)
}

@Test func lectureDeLaSeanceCrossFit() throws {
    let url = try #require(Bundle.module.url(forResource: "crossfit-seance-type", withExtension: "md", subdirectory: "Fixtures"))
    let c = lireCours(try String(contentsOf: url, encoding: .utf8))
    #expect(c.erreurs == [])
    #expect(c.estValide)
    #expect(c.total == 60 * 60)
    #expect(c.sections.map(\.famille) == [.ouverture, .echauffement, .techniques, .pratique, .calme])
    #expect(c.sections.map(\.musique) == [false, true, false, true, false])
    #expect(c.blocs.allSatisfy { $0.duree == ($0.prevu ?? 0) * 60 })
}
