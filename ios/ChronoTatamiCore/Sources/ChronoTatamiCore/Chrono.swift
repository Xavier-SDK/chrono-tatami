import Foundation

/// Ce que le chrono demande de jouer ou d'afficher : sons, voix, vibrations sur la montre.
public enum Evenement: Equatable, Sendable {
    case bip                        // 3, 2, 1
    case gong                       // fin de séquence ou nouveau bloc
    case double                     // nouvelle séquence de travail
    case triple                     // mi-round
    case voix(String, forcee: Bool = false)
    case changementDeRole(String)
    case nouveauBloc(Int)
    case fin
}

/// Une séquence placée sur la ligne de temps de la séance.
public struct Segment: Sendable, Equatable {
    public let sequence: SequenceMinutee
    public let bloc: Int
    public let rang: Int            // rang dans le bloc
    public let debut: Int           // secondes depuis le début de la séance
}

public func segments(de c: Cours) -> [Segment] {
    var out: [Segment] = [], acc = 0
    for (bi, b) in c.blocs.enumerated() {
        for (si, q) in b.sequences.enumerated() {
            out.append(Segment(sequence: q, bloc: bi, rang: si, debut: acc))
            acc += q.duree
        }
    }
    return out
}

/// Moteur du chrono, sans minuterie : on lui donne le temps écoulé, il rend les événements.
/// Même logique que l'app web (app.js) : bips 3-2-1, gong, mi-round, annonce 10 s avant le bloc suivant.
public struct Chrono: Sendable {
    public let cours: Cours
    public let segs: [Segment]
    public let total: Int
    public var voixChaqueRound = false

    public private(set) var index = 0
    public private(set) var restant: Double = 0
    public private(set) var enMarche = false
    public private(set) var termine = false
    /// Temps ajouté (+30 s) ou retiré (−30 s, passer) sur la séquence en cours.
    public private(set) var extra: Double = 0
    /// Écart total sur la séance, et par bloc, pour le bilan.
    public private(set) var ajoute: Double = 0
    public private(set) var ecarts: [Int: Double] = [:]
    private var dernierBloc = -1

    public init(cours: Cours, depuisBloc: Int = 0) {
        self.cours = cours
        segs = segments(de: cours)
        total = segs.reduce(0) { $0 + $1.sequence.duree }
        index = max(0, segs.firstIndex { $0.bloc == depuisBloc } ?? 0)
        restant = Double(segs.isEmpty ? 0 : segs[index].sequence.duree)
    }

    public var segment: Segment { segs[index] }
    public var bloc: Bloc { cours.blocs[segment.bloc] }
    public var dureeCourante: Double { Double(segment.sequence.duree) + extra }
    public var suivant: Segment? { index + 1 < segs.count ? segs[index + 1] : nil }
    /// Temps écoulé sur la séance (chrono), de 0 à total.
    public var ecoule: Double { Double(segment.debut) + (dureeCourante - restant) }

    /// Démarre la séance : annonce le premier bloc.
    public mutating func demarrer() -> [Evenement] {
        guard !segs.isEmpty else { return [] }
        enMarche = true
        return entrer(silencieux: false, premier: true)
    }

    public mutating func pause() { enMarche = false }
    public mutating func reprendre() { if !termine { enMarche = true } }

    /// Fait avancer le chrono de `dt` secondes. `silencieux` : rattrapage (retour au premier plan), sans sons.
    public mutating func avancer(_ dt: Double, silencieux: Bool = false) -> [Evenement] {
        guard enMarche, !termine, !segs.isEmpty else { return [] }
        var ev: [Evenement] = []
        let avant = restant
        restant -= dt
        let q = segment, cd = dureeCourante
        if !silencieux {
            for seuil in [3.0, 2.0, 1.0] where avant > seuil && restant <= seuil && cd > 6 { ev.append(.bip) }
            if !q.sequence.miRound.isEmpty, avant > cd / 2, restant <= cd / 2 {
                ev += [.triple, .voix(q.sequence.miRound), .changementDeRole(q.sequence.miRound)]
            }
            if let nx = suivant, nx.bloc != q.bloc, avant > 10, restant <= 10 {
                ev.append(.voix("Dans 10 secondes : " + cours.blocs[nx.bloc].titre))
            }
        }
        while restant <= 0 && !termine {
            let report = -restant
            if index >= segs.count - 1 {
                restant = 0
                ev += finir(silencieux: silencieux)
                break
            }
            if segs[index + 1].bloc == segs[index].bloc && !silencieux { ev.append(.gong) }
            index += 1
            extra = 0
            restant = Double(segment.sequence.duree) - report
            ev += entrer(silencieux: silencieux, premier: false)
        }
        return ev
    }

    private mutating func entrer(silencieux: Bool, premier: Bool) -> [Evenement] {
        let q = segment, b = cours.blocs[q.bloc]
        var ev: [Evenement] = []
        if q.bloc != dernierBloc {
            dernierBloc = q.bloc
            ev.append(.nouveauBloc(q.bloc))
            if !silencieux {
                if !premier { ev.append(.gong) }
                ev.append(.voix(b.titre))
            }
        } else if !silencieux {
            if q.sequence.type == .repos {
                if voixChaqueRound { ev.append(.voix(q.sequence.libelle)) }
            } else {
                ev.append(.double)
                if voixChaqueRound {
                    ev.append(.voix(q.sequence.libelle.components(separatedBy: "·")[0].trimmingCharacters(in: .whitespaces)))
                }
            }
        }
        return ev
    }

    private mutating func finir(silencieux: Bool) -> [Evenement] {
        termine = true
        enMarche = false
        return silencieux ? [.fin] : [.gong, .voix("Fin de la séance. Salut.", forcee: true), .fin]
    }

    // MARK: Commandes de la pause (iPhone ou montre)

    /// +30 s ou −30 s sur la séquence en cours (jamais sous 1 s).
    public mutating func ajuster(_ secondes: Double) {
        let nouveau = max(1, restant + secondes), reel = nouveau - restant
        restant = nouveau; extra += reel; ajoute += reel
        ecarts[segment.bloc, default: 0] += reel
    }

    /// Revenir : au début de la séquence, ou à la précédente si elle vient de commencer.
    public mutating func revenir() {
        let fait = dureeCourante - restant
        if fait > 3 {
            ecarts[segment.bloc, default: 0] += fait; ajoute += fait
            restant = Double(segment.sequence.duree); extra = 0
        } else if index > 0 {
            index -= 1
            let p = segment
            restant = Double(p.sequence.duree); extra = 0
            ecarts[p.bloc, default: 0] += Double(p.sequence.duree); ajoute += Double(p.sequence.duree)
            dernierBloc = p.bloc
        }
    }

    /// Passer à la séquence suivante (la fin de séance si c'était la dernière).
    @discardableResult
    public mutating func passer() -> [Evenement] {
        ecarts[segment.bloc, default: 0] -= restant; ajoute -= restant
        if index >= segs.count - 1 { restant = 0; return finir(silencieux: true) }
        index += 1
        restant = Double(segment.sequence.duree); extra = 0
        return entrer(silencieux: true, premier: false)
    }

    /// Instantané envoyé à la montre.
    public var etat: EtatChrono {
        let q = segment, b = bloc, n = b.sequences.count
        var libSuivant = "Fin de séance", durSuivant = 0
        if let nx = suivant {
            if nx.bloc != q.bloc { libSuivant = cours.blocs[nx.bloc].titre; durSuivant = cours.blocs[nx.bloc].duree }
            else { libSuivant = nx.sequence.libelle; durSuivant = nx.sequence.duree }
        }
        return EtatChrono(blocTitre: b.titre, famille: b.famille, libelle: q.sequence.libelle, type: q.sequence.type,
                          restant: max(0, restant), dureeSequence: dureeCourante, rang: q.rang + 1, nbSequences: n,
                          enMarche: enMarche, termine: termine, ecoule: ecoule, total: Double(total) + ajoute,
                          suivant: libSuivant, dureeSuivant: durSuivant, horodatage: Date().timeIntervalSince1970)
    }
}

/// Ce que la montre affiche, envoyé par l'iPhone à chaque changement (et toutes les secondes en marche).
public struct EtatChrono: Codable, Sendable, Equatable {
    public var blocTitre: String
    public var famille: Famille
    public var libelle: String
    public var type: TypeSequence
    public var restant: Double
    public var dureeSequence: Double
    public var rang: Int
    public var nbSequences: Int
    public var enMarche: Bool
    public var termine: Bool
    public var ecoule: Double
    public var total: Double
    public var suivant: String
    public var dureeSuivant: Int
    /// Moment de l'envoi : la montre en déduit le temps restant sans attendre le message suivant.
    public var horodatage: Double
    /// Musique prévue sur la section en cours, et coupée ou non (bouton de la montre).
    public var musiquePrevue = false
    public var musiqueCoupee = false

    public var progressionSequence: Double { dureeSequence > 0 ? 1 - restant / dureeSequence : 0 }

    /// Temps restant estimé à l'instant `maintenant` (la montre continue de décompter entre deux messages).
    public func restant(a maintenant: Date) -> Double {
        enMarche ? max(0, restant - (maintenant.timeIntervalSince1970 - horodatage)) : restant
    }
}

/// Commandes envoyées par la montre à l'iPhone.
public enum CommandeMontre: String, Codable, Sendable {
    case pause, reprendre, revenir, passer, plus30, moins30, couperMusique, remettreMusique
}

/// « 1:05 », « 0:09 »
public func formatChrono(_ s: Double) -> String {
    let v = max(0, Int(ceil(s - 1e-6)))
    return "\(v / 60):" + String(format: "%02d", v % 60)
}
