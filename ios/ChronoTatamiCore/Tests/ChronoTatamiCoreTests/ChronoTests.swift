import Testing
@testable import ChronoTatamiCore

private let deuxBlocs = lireCours("""
## Échauffement
### Cardio
- [travail] Course · 0:20
- [repos] Récup · 0:15
### Binômes
- [travail] Round · ⇄ Changez · 0:20
""")

@Test func demarrageAnnonceLePremierBloc() {
    var c = Chrono(cours: deuxBlocs)
    #expect(c.demarrer() == [.nouveauBloc(0), .voix("Cardio")])
    #expect(c.restant == 20)
}

@Test func bipsGongEtSequenceSuivante() {
    var c = Chrono(cours: deuxBlocs); _ = c.demarrer()
    #expect(c.avancer(16.5) == [])
    #expect(c.avancer(3) == [.bip, .bip, .bip])
    let ev = c.avancer(1)
    #expect(ev == [.gong])                       // repos du même bloc, sans voix par défaut
    #expect(c.segment.sequence.type == .repos)
    #expect(abs(c.restant - 14.5) < 0.001)       // le dépassement est reporté
}

@Test func annonceDixSecondesAvantLeBlocSuivantPuisNouveauBloc() {
    var c = Chrono(cours: deuxBlocs); _ = c.demarrer()
    _ = c.avancer(20)
    #expect(c.avancer(5.5) == [.voix("Dans 10 secondes : Binômes")])
    let ev = c.avancer(10)
    #expect(ev.contains(.nouveauBloc(1)))
    #expect(ev.contains(.voix("Binômes")))
}

@Test func miRoundEtFin() {
    var c = Chrono(cours: deuxBlocs, depuisBloc: 1); _ = c.demarrer()
    #expect(c.avancer(10).contains(.changementDeRole("Changez")))
    let ev = c.avancer(10)
    #expect(ev.contains(.fin))
    #expect(c.termine)
}

@Test func commandesDeLaPause() {
    var c = Chrono(cours: deuxBlocs); _ = c.demarrer()
    c.ajuster(30)
    #expect(c.restant == 50); #expect(c.ajoute == 30)
    c.ajuster(-100)
    #expect(c.restant == 1)
    c.passer()
    #expect(c.index == 1)
    c.revenir()                                   // la séquence vient de commencer : retour à la précédente
    #expect(c.index == 0)
    #expect(c.restant == 20)
}

@Test func etatPourLaMontre() {
    var c = Chrono(cours: deuxBlocs); _ = c.demarrer()
    _ = c.avancer(5)
    let e = c.etat
    #expect(e.blocTitre == "Cardio")
    #expect(e.rang == 1 && e.nbSequences == 2)
    #expect(abs(e.progressionSequence - 0.25) < 0.001)
    #expect(e.suivant == "Récup")
    #expect(formatChrono(e.restant) == "0:15")
}

@Test func modeCoach() {
    let c = lireCours("""
    ## Techniques · 3 min
    ### Bloc · 3 min
    - [travail] R1 · 1:00
    - [repos] Repos · 0:30
    - [travail] R2 · 1:00
    - [repos] Repos · 0:30
    """)
    var ch = Chrono(cours: c)
    ch.coach = true
    _ = ch.demarrer()
    var tout: [Evenement] = []
    for _ in 0..<1900 { tout += ch.avancer(0.1) }
    let enc = tout.compactMap { if case let .encouragement(e) = $0 { e } else { nil } }
    #expect(enc == [.miTravail, .dixSecondes, .repos, .dernierRound, .miTravail, .dixSecondes, .repos, .fin])
}
