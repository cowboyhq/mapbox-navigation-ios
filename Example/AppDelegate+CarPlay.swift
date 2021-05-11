import UIKit
import MapboxNavigation
#if canImport(CarPlay)
import CarPlay
import MapboxGeocoder
import MapboxCoreNavigation
import MapboxDirections

let CarPlayWaypointKey: String = "MBCarPlayWaypoint"

/**
 This example application delegate implementation is used in both our "Example-Swift" and our "Example-CarPlay" example apps.
 
 In order to run the "Example-CarPlay" example app with CarPlay functionality enabled, one must first obtain a CarPlay entitlement from Apple.
 
 Once the entitlement has been obtained and loaded into your ADC account:
 - Create a provisioning profile which includes the entitlement
 - Download and select the provisioning profile for the "Example-CarPlay" example app
 - Be sure to select an iOS simulator or device running iOS 12 or greater
 */
@available(iOS 12.0, *)
extension AppDelegate: CPApplicationDelegate {
    
    // MARK: - CPApplicationDelegate methods
    
    func application(_ application: UIApplication, didConnectCarInterfaceController interfaceController: CPInterfaceController, to window: CPWindow) {
        carPlayManager.delegate = self
        carPlaySearchController.delegate = self
        carPlayManager.application(application, didConnectCarInterfaceController: interfaceController, to: window)
        
        if let navigationViewController = self.window?.rootViewController?.presentedViewController as? NavigationViewController,
           let service = navigationViewController.navigationService {
            carPlayManager.beginNavigationWithCarPlay(using: service.router.location!.coordinate, navigationService: service)
        }
    }
    
    func application(_ application: UIApplication, didDisconnectCarInterfaceController interfaceController: CPInterfaceController, from window: CPWindow) {
        carPlayManager.delegate = nil
        carPlaySearchController.delegate = nil
        carPlayManager.application(application, didDisconnectCarInterfaceController: interfaceController, from: window)
        
        if let navigationViewController = currentAppRootViewController?.activeNavigationViewController {
            navigationViewController.didDisconnectFromCarPlay()
        }
    }
}

@available(iOS 12.0, *)
extension AppDelegate: CarPlayManagerDelegate {
    func carPlayManager(_ carPlayManager: CarPlayManager, navigationServiceAlong route: Route, routeIndex: Int, routeOptions: RouteOptions, desiredSimulationMode: SimulationMode) -> NavigationService {
 
        if let nvc = self.window?.rootViewController?.presentedViewController as? NavigationViewController, let service = nvc.navigationService {
            //Do not set simulation mode if we already have an active navigation session.
            return service
        }
        return MapboxNavigationService(route: route, routeIndex: routeIndex, routeOptions: routeOptions,  simulating: desiredSimulationMode)
    }
    
    // MARK: CarPlayManagerDelegate
    func carPlayManager(_ carPlayManager: CarPlayManager, didBeginNavigationWith service: NavigationService) {
        currentAppRootViewController?.beginNavigationWithCarPlay(navigationService: service)
        carPlayManager.currentNavigator?.compassView.isHidden = false
        
        // Render part of the route that has been traversed with full transparency, to give the illusion of a disappearing route.
        carPlayManager.currentNavigator?.routeLineTracksTraversal = true
    }
    
    func carPlayManagerDidEndNavigation(_ carPlayManager: CarPlayManager) {
        // Dismiss NavigationViewController if it's present in the navigation stack
        currentAppRootViewController?.dismissActiveNavigationViewController()
    }
    
    func favoritesListTemplate() -> CPListTemplate {
        let mapboxSFItem = CPListItem(text: FavoritesList.POI.mapboxSF.rawValue,
                                      detailText: FavoritesList.POI.mapboxSF.subTitle)
        let timesSquareItem = CPListItem(text: FavoritesList.POI.timesSquare.rawValue,
                                         detailText: FavoritesList.POI.timesSquare.subTitle)
        mapboxSFItem.userInfo = [CarPlayWaypointKey: Waypoint(location: FavoritesList.POI.mapboxSF.location)]
        timesSquareItem.userInfo = [CarPlayWaypointKey: Waypoint(location: FavoritesList.POI.timesSquare.location)]
        let listSection = CPListSection(items: [mapboxSFItem, timesSquareItem])
        return CPListTemplate(title: "Favorites List", sections: [listSection])
    }
    
    func carPlayManager(_ carPlayManager: CarPlayManager, leadingNavigationBarButtonsCompatibleWith traitCollection: UITraitCollection, in template: CPTemplate, for activity: CarPlayActivity) -> [CPBarButton]? {
        guard let interfaceController = self.carPlayManager.interfaceController else {
            return nil
        }
        
        switch activity {
        case .browsing:
            let searchTemplate = CPSearchTemplate()
            searchTemplate.delegate = carPlaySearchController
            let searchButton = carPlaySearchController.searchTemplateButton(searchTemplate: searchTemplate, interfaceController: interfaceController, traitCollection: traitCollection)
            return [searchButton]
        case .navigating, .previewing, .panningInBrowsingMode:
            return nil
        }
    }
    
    func carPlayManager(_ carPlayManager: CarPlayManager, didFailToFetchRouteBetween waypoints: [Waypoint]?, options: RouteOptions, error: DirectionsError) -> CPNavigationAlert? {
        let okTitle = NSLocalizedString("CARPLAY_OK", bundle: .main, value: "OK", comment: "CPAlertTemplate OK button title")
        let action = CPAlertAction(title: okTitle, style: .default, handler: {_ in })
        let alert = CPNavigationAlert(titleVariants: [error.localizedDescription],
                                      subtitleVariants: [error.failureReason ?? ""],
                                      imageSet: nil,
                                      primaryAction: action,
                                      secondaryAction: nil,
                                      duration: 5)
        return alert
    }
    
    func carPlayManager(_ carPlayManager: CarPlayManager, trailingNavigationBarButtonsCompatibleWith traitCollection: UITraitCollection, in template: CPTemplate, for activity: CarPlayActivity) -> [CPBarButton]? {
        switch activity {
        case .previewing:
            let disableSimulateText = "Disable Simulation"
            let enableSimulateText =  "Enable Simulation"
            let simulationButton = CPBarButton(type: .text) { (barButton) in
                carPlayManager.simulatesLocations = !carPlayManager.simulatesLocations
                barButton.title = carPlayManager.simulatesLocations ? disableSimulateText : enableSimulateText
            }
            simulationButton.title = carPlayManager.simulatesLocations ? disableSimulateText : enableSimulateText
            return [simulationButton]
        case .browsing:
            let favoriteTemplateButton = CPBarButton(type: .image) { [weak self] button in
                guard let strongSelf = self else { return }
                let listTemplate = strongSelf.favoritesListTemplate()
                listTemplate.delegate = strongSelf
                carPlayManager.interfaceController?.pushTemplate(listTemplate, animated: true)
            }
            favoriteTemplateButton.image = UIImage(named: "carplay_star", in: nil, compatibleWith: traitCollection)
            return [favoriteTemplateButton]
        case .navigating, .panningInBrowsingMode:
            return nil
        }
    }
    
    func carPlayManager(_ carPlayManager: CarPlayManager, mapButtonsCompatibleWith traitCollection: UITraitCollection, in template: CPTemplate, for activity: CarPlayActivity) -> [CPMapButton]? {
        switch activity {
        case .browsing:
            guard let mapViewController = carPlayManager.carPlayMapViewController,
                let mapTemplate = template as? CPMapTemplate else {
                return nil
            }
            var mapButtons = [mapViewController.recenterButton,
                              mapViewController.zoomInButton,
                              mapViewController.zoomOutButton]
            mapButtons.insert(mapViewController.panningInterfaceDisplayButton(for: mapTemplate), at: 1)
            return mapButtons
        case .previewing, .navigating, .panningInBrowsingMode:
            return nil
        }
    }
}

@available(iOS 12.0, *)
extension AppDelegate: CarPlaySearchControllerDelegate {
    struct RecentsHolder {
        static var _recentItems:[Recentitem] = Recentitem.loadDefaults()
        static var _recentSearchItems:[CPListItem]? = []
        static var _recentSearchText:String? = ""
    }
    
    var recentItems: [Recentitem] {
        get {
            return RecentsHolder._recentItems
        }
        set(newValue) {
            RecentsHolder._recentItems = newValue
        }
    }
    
    var recentSearchItems: [CPListItem]? {
        get {
            return RecentsHolder._recentSearchItems
        }
        set(newValue) {
            RecentsHolder._recentSearchItems = newValue
        }
    }
    
    var recentSearchText: String? {
        get {
            return RecentsHolder._recentSearchText
        }
        set(newValue) {
            RecentsHolder._recentSearchText = newValue
        }
    }
    
    struct MaximumSearchResults {
        static var initial: UInt = 5
        static var extended: UInt = 10
    }
    
//    fileprivate static let coarseLocationManager: CLLocationManager = {
//        let coarseLocationManager = CLLocationManager()
//        coarseLocationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
//        return coarseLocationManager
//    }()
    
    func previewRoutes(to waypoint: Waypoint, completionHandler: @escaping () -> Void) {
        carPlayManager.previewRoutes(to: waypoint, completionHandler: completionHandler)
    }
    
    func resetPanButtons(_ mapTemplate: CPMapTemplate) {
        carPlayManager.resetPanButtons(mapTemplate)
    }
    
    func pushTemplate(_ template: CPTemplate, animated: Bool) {
        if let listTemplate = template as? CPListTemplate {
            listTemplate.delegate = carPlaySearchController
        }
        carPlayManager.interfaceController?.pushTemplate(template, animated: animated)
    }
    
    func popTemplate(animated: Bool) {
        carPlayManager.interfaceController?.popTemplate(animated: animated)
    }
    
    func searchTemplate(_ searchTemplate: CPSearchTemplate, updatedSearchText searchText: String, completionHandler: @escaping ([CPListItem]) -> Void) {
        var items = recentSearches(searchText)
        
        // Search for placemarks using MapboxGeocoder.swift
        let shouldSearch = searchText.count > 2
        if shouldSearch {
            let options = forwardGeocodeOptions(searchText)
            Geocoder.shared.geocode(options, completionHandler: { [weak self] (placemarks, attribution, error) in
                guard let strongSelf = self else { return }
                guard let placemarks = placemarks else {
                    // TODO: FIX INPUT TO COMPLETION HANDLER
                    completionHandler((self?.resultsOrNoResults(items, limit: MaximumSearchResults.initial))!)
                    return
                }
                let navplacemarks = placemarks.map { NavGeocodedPlacemark(from: $0) }
                let results = navplacemarks.map { $0.listItem() }
                items.append(contentsOf: results)
                completionHandler(strongSelf.resultsOrNoResults(results, limit: MaximumSearchResults.initial))
            })
        } else {
            completionHandler(self.resultsOrNoResults(items, limit: MaximumSearchResults.initial))
        }
    }
    
    func searchTemplate(_ searchTemplate: CPSearchTemplate, selectedResult item: CPListItem, completionHandler: @escaping () -> Void) {
        guard let items = recentSearchItems else { return }
        let extendedItems = resultsOrNoResults(items, limit: MaximumSearchResults.extended)
        
        let section = CPListSection(items: extendedItems)
        let template = CPListTemplate(title: recentSearchText, sections: [section])
        template.delegate = self
        pushTemplate(template, animated: true)
    }
    
    func forwardGeocodeOptions(_ searchText: String) -> ForwardGeocodeOptions {
        let options = ForwardGeocodeOptions(query: searchText)
//        options.focalLocation = CarPlaySearchController.coarseLocationManager.location
        options.locale = Locale.autoupdatingCurrent.languageCode == "en" ? nil : .autoupdatingCurrent
        var allScopes: PlacemarkScope = .all
        allScopes.remove(.postalCode)
        options.allowedScopes = allScopes
        options.maximumResultCount = MaximumSearchResults.extended
        options.includesRoutableLocations = true
        return options
    }
    
    func selectResult(item: CPListItem, completionHandler: @escaping () -> Void) {
        guard let userInfo = item.userInfo as? [String: Any],
              let placemark = userInfo[CarPlaySearchController.CarPlayGeocodedPlacemarkKey] as? NavGeocodedPlacemark,
              let location = placemark.routableLocations?.first ?? placemark.location else {
            completionHandler()
            return
        }
        
        recentItems.add(Recentitem(placemark))
        recentItems.save()
        
        let destinationWaypoint = Waypoint(location: location, heading: nil, name: placemark.title)
        previewRoutes(to: destinationWaypoint, completionHandler: completionHandler)
    }
    
    func recentSearches(_ searchText: String) -> [CPListItem] {
        if searchText.isEmpty {
            return recentItems.map { $0.geocodedPlacemark.listItem() }
        }
        return recentItems.filter { $0.matches(searchText) }.map { $0.geocodedPlacemark.listItem() }
    }
    
    @available(iOS 12.0, *)
    func resultsOrNoResults(_ items: [CPListItem], limit: UInt?) -> [CPListItem] {
        recentSearchItems = items
        
        if items.count > 0 {
            if let limit = limit {
                return Array<CPListItem>(items.prefix(Int(limit)))
            }
            
            return items
        } else {
            let title = NSLocalizedString("CARPLAY_SEARCH_NO_RESULTS", bundle: .mapboxNavigation, value: "No results", comment: "Message when search returned zero results in CarPlay")
            let noResult = CPListItem(text: title, detailText: nil, image: nil, showsDisclosureIndicator: false)
            return [noResult]
        }
    }
}

@available(iOS 12.0, *)
extension AppDelegate: CPListTemplateDelegate {
    func listTemplate(_ listTemplate: CPListTemplate, didSelect item: CPListItem, completionHandler: @escaping () -> Void) {
        // Selected a favorite
        if let userInfo = item.userInfo as? [String: Any],
            let waypoint = userInfo[CarPlayWaypointKey] as? Waypoint {
            carPlayManager.previewRoutes(to: waypoint, completionHandler: completionHandler)
            return
        }
        
        completionHandler()
    }
}
#endif
