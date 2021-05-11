#if canImport(CarPlay)
import Foundation
import CarPlay
import MapboxGeocoder
import MapboxDirections

@available(iOS 12.0, *)
public protocol CarPlaySearchControllerDelegate: class, CPSearchTemplateDelegate {
    func previewRoutes(to waypoint: Waypoint, completionHandler: @escaping () -> Void)
    func resetPanButtons(_ mapTemplate: CPMapTemplate)
    func pushTemplate(_ template: CPTemplate, animated: Bool)
    func popTemplate(animated: Bool)

    var recentItems: [Recentitem] { get set }
    var recentSearchItems: [CPListItem]? { get set }
    var recentSearchText: String? { get set }
    
    func searchTemplate(_ searchTemplate: CPSearchTemplate, updatedSearchText searchText: String, completionHandler: @escaping ([CPListItem]) -> Void)
    func searchTemplate(_ searchTemplate: CPSearchTemplate, selectedResult item: CPListItem, completionHandler: @escaping () -> Void)
    func forwardGeocodeOptions(_ searchText: String) -> ForwardGeocodeOptions
    func selectResult(item: CPListItem, completionHandler: @escaping () -> Void)
    func recentSearches(_ searchText: String) -> [CPListItem]
    func resultsOrNoResults(_ items: [CPListItem], limit: UInt?) -> [CPListItem]
//    func listTemplate(_ listTemplate: CPListTemplate, didSelect item: CPListItem, completionHandler: @escaping () -> Void)
}

// TODO: add comments to all public
public struct NavGeocodedPlacemark: Equatable, Codable {
    public var title: String
//    var subtitle: String? {
//        if let addressDictionary = addressDictionary, var lines = addressDictionary["formattedAddressLines"] as? [String] {
//            // Chinese addresses have no commas and are reversed.
//            if scope == .address {
//                if qualifiedName?.contains(", ") ?? false {
//                    lines.removeFirst()
//                } else {
//                    lines.removeLast()
//                }
//            }
//
//            if let regionCode = administrativeRegion?.code,
//               let abbreviatedRegion = regionCode.components(separatedBy: "-").last, (abbreviatedRegion as NSString).intValue == 0 {
//                // Cut off country and postal code and add abbreviated state/region code at the end.
//
//                let stitle = lines.prefix(2).joined(separator: NSLocalizedString("ADDRESS_LINE_SEPARATOR", value: ", ", comment: "Delimiter between lines in an address when displayed inline"))
//
//                if scope == .region || scope == .district || scope == .place || scope == .postalCode {
//                    return stitle
//                }
//                return stitle.appending("\(NSLocalizedString("ADDRESS_LINE_SEPARATOR", value: ", ", comment: "Delimiter between lines in an address when displayed inline"))\(abbreviatedRegion)")
//            }
//
//            if scope == .country {
//                return ""
//            }
//            if qualifiedName?.contains(", ") ?? false {
//                return lines.joined(separator: NSLocalizedString("ADDRESS_LINE_SEPARATOR", value: ", ", comment: "Delimiter between lines in an address when displayed inline"))
//            }
//            return lines.joined()
//        }
//
//        return description
//    }
    public var address: String?
    public var location: CLLocation?
    public var routableLocations: [CLLocation]?

    
    enum CodingKeys: String, CodingKey {
        case title
        case address
        case location
        case routableLocations
    }
    
    public init (from geocodedPlacemark: GeocodedPlacemark) {
        title = geocodedPlacemark.formattedName
        address = geocodedPlacemark.address
        location = geocodedPlacemark.location
        routableLocations = geocodedPlacemark.routableLocations
    }
    
    public init (from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        address = try container.decodeIfPresent(String.self, forKey: .address)
        print("!!! DECODED ADDRESS: \(String(describing: address))")
        if let locationHolder = try container.decodeIfPresent(CLLocationModel.self, forKey: .location) {
            location = CLLocation(model: locationHolder)
        }
        if let routableLocationsHolder = try container.decodeIfPresent([CLLocationModel].self, forKey: .routableLocations) {
            routableLocations = routableLocationsHolder.map { CLLocation(model: $0) }
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(address, forKey: .address)
        try container.encodeIfPresent(location, forKey: .location)
        try container.encodeIfPresent(routableLocations, forKey: .routableLocations)
    }
    
    // SHOULD this equality be more strict?
    public static func == (lhs: NavGeocodedPlacemark, rhs: NavGeocodedPlacemark) -> Bool {
        return lhs.title == rhs.title &&
            lhs.address == rhs.address
    }
    
}

extension CLLocation: Encodable {
    public enum CodingKeys: String, CodingKey {
        case latitude
        case longitude
        case altitude
        case horizontalAccuracy
        case verticalAccuracy
        case speed
        case course
        case timestamp
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(coordinate.latitude, forKey: .latitude)
        try container.encode(coordinate.longitude, forKey: .longitude)
        try container.encode(altitude, forKey: .altitude)
        try container.encode(horizontalAccuracy, forKey: .horizontalAccuracy)
        try container.encode(verticalAccuracy, forKey: .verticalAccuracy)
        try container.encode(speed, forKey: .speed)
        try container.encode(course, forKey: .course)
        try container.encode(timestamp, forKey: .timestamp)
    }
    
    convenience init(model: CLLocationModel) {
        self.init(coordinate: CLLocationCoordinate2DMake(model.latitude, model.longitude), altitude: model.altitude, horizontalAccuracy: model.horizontalAccuracy, verticalAccuracy: model.verticalAccuracy, course: model.course, speed: model.speed, timestamp: model.timestamp)
    }
}

struct CLLocationModel: Codable {
    let latitude: CLLocationDegrees
    let longitude: CLLocationDegrees
    let altitude: CLLocationDistance
    let horizontalAccuracy: CLLocationAccuracy
    let verticalAccuracy: CLLocationAccuracy
    let speed: CLLocationSpeed
    let course: CLLocationDirection
    let timestamp: Date
}

extension NavGeocodedPlacemark {
    @available(iOS 12.0, *)
    public func listItem() -> CPListItem {
        print("!!! ADDRESS: \(String(describing: address))")
        let item = CPListItem(text: title, detailText: "ADDRESS", image: nil, showsDisclosureIndicator: true)
        item.userInfo = [CarPlaySearchController.CarPlayGeocodedPlacemarkKey: self]
        return item
    }
}

/**
 `CarPlaySearchController` is the main object responsible for managing the search feature on CarPlay.
 
 Messages declared in the `CPApplicationDelegate` protocol should be sent to this object in the containing application's application delegate. Implement `CarPlaySearchControllerDelegate` in the containing application and assign an instance to the `delegate` property of your `CarPlaySearchController` instance.
 
 - note: It is very important you have a single `CarPlaySearchController` instance at any given time. 
 */
@available(iOS 12.0, *)
public class CarPlaySearchController: NSObject {
    /**
     The completion handler that will process the list of search results initiated on CarPlay.
     */
    var searchCompletionHandler: (([CPListItem]) -> Void)?
    
    // TODO: Confirm that these properties can become public
    /**
     The most recent search results.
     */
//    public var recentSearchItems: [CPListItem]?
    
    /**
     The most recent search text.
     */
//    public var recentSearchText: String?
    
    /**
     The `CarPlaySearchController` delegate.
     */
    public weak var delegate: CarPlaySearchControllerDelegate?
}
#else
/**
 CarPlay support requires iOS 12.0 or above and the CarPlay framework.
 */
public class CarPlaySearchController: NSObject {}
#endif
