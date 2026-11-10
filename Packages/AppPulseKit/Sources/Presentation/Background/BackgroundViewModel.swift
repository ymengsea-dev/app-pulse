import Domain
import Observation

/// How a signer is shown, from most to least worth a look.
struct SignerBadge: Equatable {
    enum Tone: Equatable {
        case concern
        case caution
        case neutral
        case trusted
    }

    let title: String
    let tone: Tone
}

struct BackgroundRowModel: Equatable, Identifiable {
    let id: String
    let name: String
    let path: String
    let bundlePath: String?
    let badge: SignerBadge
    let processCount: Int
    let detail: String
}

enum BackgroundState: Equatable {
    case loading
    /// `checkingCount` programs are still having their signature checked, and are not counted or listed yet.
    case ready(Headline, [BackgroundRowModel], checkingCount: Int)
}

/// Turns snapshots into the Background page: programs with no window or Dock icon, and who signed them.
@MainActor
@Observable
final class BackgroundViewModel {
    /// Off by default: Apple's own background programs number in the hundreds and are rarely the question.
    var showsApplePrograms = false

    private var programs: [BackgroundProgram]?

    func apply(_ snapshot: UsageSnapshot) {
        programs = snapshot.backgroundPrograms
    }

    var state: BackgroundState {
        guard let programs else { return .loading }
        // Unchecked programs would otherwise count as "not from Apple", which is almost never true.
        let checked = programs.filter { $0.signer != nil }
        let shown = checked.filter { showsApplePrograms || $0.signer != .apple }
        let rows = shown.sorted(by: Self.isShownBefore).map(Self.makeRow)
        let checking = programs.count - checked.count
        return .ready(Self.makeHeadline(checked, isComplete: checking == 0), rows, checkingCount: checking)
    }

    private static func makeHeadline(_ programs: [BackgroundProgram], isComplete: Bool) -> Headline {
        let notApple = programs.filter { $0.signer != .apple }.count
        let unverified = programs.filter { $0.signer?.isUnverified == true }.count
        let fromDevelopers = programs.filter { if case .developer = $0.signer { true } else { false } }.count
        let fromApple = programs.count - notApple
        let phrase = notApple == 1 ? "background program not from Apple" : "background programs not from Apple"

        return Headline(
            value: "\(notApple)",
            phrase: isComplete ? phrase : "\(phrase) so far",
            totals: [
                TotalFigure(value: "\(unverified)", label: "Unverified", tone: .used),
                TotalFigure(value: "\(fromDevelopers)", label: "Developer", tone: .neutral),
                TotalFigure(value: "\(fromApple)", label: "Apple", tone: .available),
            ]
        )
    }

    /// Unverified programs first, then the rest by name, so the list stays still as figures change.
    private static func isShownBefore(_ a: BackgroundProgram, _ b: BackgroundProgram) -> Bool {
        let (rankA, rankB) = (rank(a.signer), rank(b.signer))
        if rankA != rankB { return rankA < rankB }
        let order = a.name.localizedCaseInsensitiveCompare(b.name)
        return order == .orderedSame ? a.path < b.path : order == .orderedAscending
    }

    private static func rank(_ signer: CodeSigner?) -> Int {
        switch signer {
        case .invalid, .unsigned: 0
        case .adHoc: 1
        case .unknown: 2
        case nil: 3
        case .developer: 4
        case .apple: 5
        }
    }

    static func badge(for signer: CodeSigner?) -> SignerBadge {
        switch signer {
        case .invalid: SignerBadge(title: "Signature broken", tone: .concern)
        case .unsigned: SignerBadge(title: "Unsigned", tone: .concern)
        case .adHoc: SignerBadge(title: "No developer", tone: .caution)
        case .unknown: SignerBadge(title: "Couldn't check", tone: .neutral)
        case nil: SignerBadge(title: "Checking…", tone: .neutral)
        case .developer(let name): SignerBadge(title: name, tone: .neutral)
        case .apple: SignerBadge(title: "Apple", tone: .trusted)
        }
    }

    private static func makeRow(_ program: BackgroundProgram) -> BackgroundRowModel {
        BackgroundRowModel(
            id: program.id,
            name: program.name,
            path: program.path,
            bundlePath: program.bundlePath,
            badge: badge(for: program.signer),
            processCount: program.processCount,
            detail: detail(program)
        )
    }

    private static func detail(_ program: BackgroundProgram) -> String {
        guard program.isReadable else { return "Runs as another user, so its figures need admin access" }
        var parts = ["\(UsageFormat.percent(program.cpuFraction)) CPU", UsageFormat.memory(program.memoryBytes)]
        if program.networkBytesPerSecond >= 100 {
            parts.append(UsageFormat.speed(program.networkBytesPerSecond))
        }
        return parts.joined(separator: " · ")
    }
}
