import Foundation
import MapboxGeocoder
import CarPlay
// TODO: fix camelcase for RecentItem
public struct Recentitem: Equatable, Codable {
    public static func ==(lhs: Recentitem, rhs: Recentitem) -> Bool {
        return lhs.timestamp == rhs.timestamp && lhs.geocodedPlacemark == rhs.geocodedPlacemark
    }

    var timestamp: Date
    public var geocodedPlacemark: NavGeocodedPlacemark

    static let persistenceKey = "RecentItems"

    static var filePathUrl: URL {
        get {
            let documents = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
            let url = URL(fileURLWithPath: documents)
            return url.appendingPathComponent(persistenceKey.appending(".data"))
        }
    }

    static public func loadDefaults() -> [Recentitem] {
        let data = try? Data(contentsOf: Recentitem.filePathUrl)
        let decoder = JSONDecoder()
        if let data = data, let recentItems = try? decoder.decode([Recentitem].self, from: data) {
            return recentItems.sorted(by: { $0.timestamp > $1.timestamp })
        }

        return [Recentitem]()
    }

    public init(_ geocodedPlacemark: NavGeocodedPlacemark) {
        self.geocodedPlacemark = geocodedPlacemark
        self.timestamp = Date()
    }

    public func matches(_ searchText: String) -> Bool {
        return geocodedPlacemark.title.contains(searchText) || geocodedPlacemark.address?.contains(searchText) ?? false
    }
}

extension Array where Element == Recentitem {
    public func save() {
        let encoder = JSONEncoder()
        let data = try? encoder.encode(self)
        (try? data?.write(to: Recentitem.filePathUrl)) as ()??
    }

    public mutating func add(_ recentItem: Recentitem) {
        let existing = lazy.filter { $0.geocodedPlacemark == recentItem.geocodedPlacemark }.first

        guard let alreadyExisting = existing else {
            insert(recentItem, at: 0)
            return
        }

        var updated = alreadyExisting
        updated.timestamp = Date()
        remove(alreadyExisting)
        add(updated)
    }

    mutating func remove(_ recentItem: Recentitem) {
        if let index = firstIndex(of: recentItem) {
            remove(at: index)
        }
    }
}
