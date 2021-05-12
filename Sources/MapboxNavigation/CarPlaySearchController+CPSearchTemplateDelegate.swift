#if canImport(CarPlay) && canImport(MapboxGeocoder)
import Foundation
import CarPlay
import MapboxGeocoder
import MapboxDirections

@available(iOS 12.0, *)
extension CarPlaySearchController: CPSearchTemplateDelegate {
    
    // TODO: Find a way to get rid of these OR
    // move button functions up and remove this extension
    public func searchTemplate(_ searchTemplate: CPSearchTemplate, updatedSearchText searchText: String, completionHandler: @escaping ([CPListItem]) -> Void) {
        delegate?.searchTemplate(searchTemplate, updatedSearchText: searchText, completionHandler: completionHandler)
    }
    
    public func searchTemplate(_ searchTemplate: CPSearchTemplate, selectedResult item: CPListItem, completionHandler: @escaping () -> Void) {
        delegate?.searchTemplate(searchTemplate, selectedResult: item, completionHandler: completionHandler)
    }
    
    public static let CarPlayGeocodedPlacemarkKey: String = "MBGecodedPlacemark"
    
    static var MaximumInitialSearchResults: UInt = 5
    static var MaximumExtendedSearchResults: UInt = 10
    /// A very coarse location manager used for focal location when searching
    // TODO: Confirm that this location manager can become public to use in AppDelegate
    public static let coarseLocationManager: CLLocationManager = {
        let coarseLocationManager = CLLocationManager()
        coarseLocationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        return coarseLocationManager
    }()

    public func searchTemplateSearchButtonPressed(_ searchTemplate: CPSearchTemplate) {
        guard let items = delegate?.recentSearchItems else { return }
        guard let extendedItems = delegate?.resultsOrNoResults(items, limit: CarPlaySearchController.MaximumExtendedSearchResults) else { return }
        
        let section = CPListSection(items: extendedItems)
        let template = CPListTemplate(title: delegate?.recentSearchText, sections: [section])
        template.delegate = self
        delegate?.pushTemplate(template, animated: true)
    }
    
    public func searchTemplateButton(searchTemplate: CPSearchTemplate, interfaceController: CPInterfaceController, traitCollection: UITraitCollection) -> CPBarButton {
        let searchTemplateButton = CPBarButton(type: .image) { [weak self] button in
            guard let strongSelf = self else {
                return
            }
            
            if let mapTemplate = interfaceController.topTemplate as? CPMapTemplate {
                strongSelf.delegate?.resetPanButtons(mapTemplate)
            }
            
            self?.delegate?.pushTemplate(searchTemplate, animated: false)
        }
        
        let bundle = Bundle.mapboxNavigation
        searchTemplateButton.image = UIImage(named: "carplay_search", in: bundle, compatibleWith: traitCollection)
        
        return searchTemplateButton
    }
}

@available(iOS 12.0, *)
extension CarPlaySearchController: CPListTemplateDelegate {
    public func listTemplate(_ listTemplate: CPListTemplate, didSelect item: CPListItem, completionHandler: @escaping () -> Void) {
        // Selected a search item from the extended list?
        if let userInfo = item.userInfo as? [String: Any],
           let placemark = userInfo[CarPlaySearchController.CarPlayGeocodedPlacemarkKey] as? NavGeocodedPlacemark,
           let location = placemark.location {
            let destinationWaypoint = Waypoint(location: location)
            delegate?.popTemplate(animated: false)
            delegate?.previewRoutes(to: destinationWaypoint, completionHandler: completionHandler)
            return
        }
    }
}

extension GeocodedPlacemark {
    open var subtitle: String? {
        if let addressDictionary = addressDictionary, var lines = addressDictionary["formattedAddressLines"] as? [String] {
            // Chinese addresses have no commas and are reversed.
            if scope == .address {
                if qualifiedName?.contains(", ") ?? false {
                    lines.removeFirst()
                } else {
                    lines.removeLast()
                }
            }

            if let regionCode = administrativeRegion?.code,
               let abbreviatedRegion = regionCode.components(separatedBy: "-").last, (abbreviatedRegion as NSString).intValue == 0 {
                // Cut off country and postal code and add abbreviated state/region code at the end.

                let stitle = lines.prefix(2).joined(separator: NSLocalizedString("ADDRESS_LINE_SEPARATOR", value: ", ", comment: "Delimiter between lines in an address when displayed inline"))

                if scope == .region || scope == .district || scope == .place || scope == .postalCode {
                    return stitle
                }
                return stitle.appending("\(NSLocalizedString("ADDRESS_LINE_SEPARATOR", value: ", ", comment: "Delimiter between lines in an address when displayed inline"))\(abbreviatedRegion)")
            }

            if scope == .country {
                return ""
            }
            if qualifiedName?.contains(", ") ?? false {
                return lines.joined(separator: NSLocalizedString("ADDRESS_LINE_SEPARATOR", value: ", ", comment: "Delimiter between lines in an address when displayed inline"))
            }
            return lines.joined()
        }

        return description
    }
}
#endif
