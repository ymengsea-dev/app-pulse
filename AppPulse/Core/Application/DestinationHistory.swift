import Foundation

/// The external hosts each app has talked to this session. Held in memory only.
struct DestinationHistory {
    private static let limitPerApp = 200
    private var destinations: [String: [String: Destination]] = [:]
    private var hostNames: [String: String] = [:]

    /// Records this sample's addresses, and marks everything else as no longer active.
    mutating func update(addressesByApp: [String: Set<String>], at date: Date) {
        for appID in destinations.keys {
            for address in destinations[appID, default: [:]].keys {
                destinations[appID]?[address]?.isActive = false
            }
        }
        for (appID, addresses) in addressesByApp {
            var known = destinations[appID, default: [:]]
            for address in addresses {
                known[address] = Destination(address: address, hostName: hostNames[address], isActive: true, lastSeen: date)
            }
            destinations[appID] = Self.trimmed(known)
        }
    }

    mutating func setHostName(_ name: String, forAddress address: String) {
        hostNames[address] = name
        for appID in destinations.keys where destinations[appID]?[address] != nil {
            destinations[appID]?[address]?.hostName = name
        }
    }

    func destinations(forApp appID: String) -> [Destination] {
        destinations[appID, default: [:]].values.sorted(by: Self.isShownBefore)
    }

    private static func trimmed(_ known: [String: Destination]) -> [String: Destination] {
        guard known.count > limitPerApp else { return known }
        let kept = known.values.sorted(by: isShownBefore).prefix(limitPerApp)
        return Dictionary(uniqueKeysWithValues: kept.map { ($0.address, $0) })
    }

    private static func isShownBefore(_ a: Destination, _ b: Destination) -> Bool {
        if a.isActive != b.isActive { return a.isActive }
        if a.lastSeen != b.lastSeen { return a.lastSeen > b.lastSeen }
        return a.address < b.address
    }
}
