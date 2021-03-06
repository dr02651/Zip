//
//  ViewController.swift
//  Zip
//
//  Created by Devodriq Roberts on 7/16/18.
//  Copyright © 2018 Devodriq Roberts. All rights reserved.
//

import UIKit
import RevealingSplashView
import Firebase
import CoreLocation
import MapKit

class HomeViewController: UIViewController, MKMapViewDelegate {
    @IBOutlet weak var mapView: MKMapView!
    
    @IBOutlet weak var actionButton: RoundedShadowButton!
    @IBOutlet weak var userImageView: RoundImageView!
    @IBOutlet weak var centerMapButton: UIButton!
    @IBOutlet weak var destinationTextField: UITextField!
    @IBOutlet weak var destinationCircleView: CircleViews!
    
    
    let locationManager = CLLocationManager()
    var tableView = UITableView()
    var matchingLocations = [MKMapItem]()
    
    var regionRadius: CLLocationDistance = 1000
    
    
    weak var delegate: CenterVCDelegate?
    //let loginVC = LoginViewController()
    
    let revealingSplashView = RevealingSplashView(iconImage: UIImage(named: "launchScreenIcon")!, iconInitialSize: CGSize(width: 80, height: 80), backgroundColor: UIColor(displayP3Red: 0/255, green: 143/255, blue: 0/255, alpha: 1))
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.addSubview(revealingSplashView)
        revealingSplashView.animationType = SplashAnimationType.heartBeat
        revealingSplashView.startAnimation()
        revealingSplashView.heartAttack = true
        
        self.locationManager.requestAlwaysAuthorization()
        checkLocationAuthStatus()
        
        mapView.delegate = self
        centerMapOnUserLocation()
        
        DataService.instance.REF_DRIVERS.observe(.value, with: { (snapshot) in
            self.loadDriverAnnotationFromFB()
        })
        destinationTextField.delegate = self
        
        
        
        
        
    }
    
    func checkLocationAuthStatus() {
        if CLLocationManager.locationServicesEnabled() {
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.startUpdatingLocation()
        } else {
            locationManager.requestAlwaysAuthorization()
        }
    }
    
    func loadDriverAnnotationFromFB() {
        DataService.instance.REF_DRIVERS.observeSingleEvent(of: .value, with: { (snapshot) in
            if let driverSnapShot = snapshot.children.allObjects as? [DataSnapshot] {
                for driver in driverSnapShot {
                    if driver.hasChild("userIsDriver") {
                        if driver.hasChild("coordinate") {
                            if driver.childSnapshot(forPath: "isDriverOnline").value as? Bool == true {
                                if let driverDict = driver.value as? [String:AnyObject] {
                                    let coordinateArray = driverDict["coordinate"] as! NSArray
                                    let driverCoordinate = CLLocationCoordinate2D(latitude: coordinateArray[0] as! CLLocationDegrees, longitude: coordinateArray[1] as! CLLocationDegrees)
                                    
                                    let annotation = DriverAnnotation(coordinate: driverCoordinate, withKey: driver.key)
                                    
                                    var driverIsVisible: Bool {
                                        return self.mapView.annotations.contains(where: { (annotation) -> Bool in
                                            if let driverAnnotation = annotation as? DriverAnnotation {
                                                if driverAnnotation.key == driver.key {
                                                    driverAnnotation.update(annotationPosition: driverAnnotation, withCoordinate: driverCoordinate)
                                                    return true
                                                }
                                            }
                                            return false
                                        })
                                    }
                                    if !driverIsVisible {
                                        self.mapView.addAnnotation(annotation)
                                    }
                                }
                            } else {
                                for annotation in self.mapView.annotations {
                                    if annotation.isKind(of: DriverAnnotation.self) {
                                        if let annotation = annotation as? DriverAnnotation {
                                            if annotation.key == driver.key {
                                                self.mapView.removeAnnotation(annotation)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                }
            }
        })
    }
    
    func centerMapOnUserLocation() {
        let coordinateRegion = MKCoordinateRegionMakeWithDistance(mapView.userLocation.coordinate, regionRadius * 2.0, regionRadius * 2.0)
        self.mapView.setRegion(coordinateRegion, animated: true)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if Auth.auth().currentUser == nil {
            userImageView.image = UIImage(named: "noProfilePhoto")
        }
    }
    
    @IBAction func actionButtonPressed(_ sender: Any) {
        actionButton.animateButton(shouldLoad: true, withMessage: nil)
    }
    
    @IBAction func menuButtonPressed(_ sender: UIButton) {
        delegate?.toggleLeftDrawer()
    }
    
    @IBAction func centerMap(_ sender: UIButton) {
        centerMapOnUserLocation()
        centerMapButton.fadeTo(alpha: 0.0, withDuration: 0.2)
    }
    func showError(ofType error: Error) {
        print(error)
        Alert.showLoginErrorAlert(on: self, error: error as NSError)
    }
    func showResultsError() {
        Alert.showSearchErrorAlert(on: self, message: nil)
    }
    
}

extension HomeViewController: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        checkLocationAuthStatus()
        if status == .authorizedAlways {
            mapView.showsUserLocation = true
            mapView.userTrackingMode = .follow
        }
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if let annotation = annotation as? DriverAnnotation {
            let identifier = "driver"
            var view: MKAnnotationView
            view = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            view.image = UIImage(named: "driverAnnotation")
            return view
        }
        return nil
    }
    
    func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
        centerMapButton.fadeTo(alpha: 1.0, withDuration: 0.2)
    }
    
    func performSearch() {
        matchingLocations.removeAll()
        let locations = MKLocalSearchRequest()
        locations.naturalLanguageQuery = destinationTextField.text
        locations.region = mapView.region
        
        let search = MKLocalSearch(request: locations)
        search.start { (response, error) in
            if error != nil {
                guard let error = error else {return}
                self.showResultsError()
                print(error.localizedDescription)
                return
            }else if response?.mapItems.count == 0 {
                self.showResultsError()
            } else {
                for mapItem in response!.mapItems {
                    self.matchingLocations.append(mapItem as MKMapItem)
                    self.tableView.reloadData()
                }
            }
        }
    }
}

extension HomeViewController: UITextFieldDelegate, UITableViewDelegate, UITableViewDataSource {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        if textField == destinationTextField {
            tableView.frame = CGRect(x: 16, y: view.frame.height, width: view.frame.width - 32, height: view.frame.height - 170)
            tableView.layer.cornerRadius = 5.0
            tableView.register(UITableViewCell.self, forCellReuseIdentifier: "locationCell")
            
            tableView.delegate = self
            tableView.dataSource = self
            
            tableView.tag = 30
            tableView.rowHeight = 60
            
            view.addSubview(tableView)
            animateTableView(shouldShow: true)
            
            UIView.animate(withDuration: 0.2) {
                self.destinationCircleView.backgroundColor = UIColor.red
                self.destinationCircleView.borderColor = UIColor.init(red: 199/255, green: 0/255, blue: 0/255, alpha: 1.0)
            }
            
        }
    }
    
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == destinationTextField {
            performSearch()
            view.endEditing(true)
        }
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField == destinationTextField {
            if destinationTextField.text == "" {
                UIView.animate(withDuration: 0.2) {
                    self.destinationCircleView.backgroundColor = UIColor.init(red: 170/255, green: 170/255, blue: 170/255, alpha: 1.0)
                    self.destinationCircleView.borderColor = UIColor.init(red: 94/255, green: 94/255, blue: 94/255, alpha: 1.0)
                }
            }
        }
    }
    
    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        centerMapOnUserLocation()
        matchingLocations = []
        tableView.reloadData()
        return true
    }
    
    func animateTableView(shouldShow: Bool) {
        if shouldShow {
            
            UIView.animate(withDuration: 0.2) {
                self.tableView.frame = CGRect(x: 16, y: 220, width: self.view.frame.width - 32, height: self.view.frame.height - 360)}
            
        } else {
            UIView.animate(withDuration: 0.2, animations: {
                self.tableView.frame = CGRect(x: 16, y: self.view.frame.height, width: self.view.frame.width - 32, height: self.view.frame.height - 170)
            }) { (finished) in
                for subview in self.view.subviews {
                    if subview.tag == 30 {
                        subview.removeFromSuperview()
                    }
                }
            }
        }
    }
    
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "locationCell")
        let mapItem = matchingLocations[indexPath.row]
        cell.textLabel?.text = mapItem.name
        cell.detailTextLabel?.text = mapItem.placemark.title
        return cell
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        view.endEditing(true)
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        if destinationTextField.text == "" {
            animateTableView(shouldShow: false)
        }
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return matchingLocations.count
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        animateTableView(shouldShow: false)
        destinationTextField.endEditing(true)
        destinationTextField.text = tableView.cellForRow(at: indexPath)?.textLabel?.text
        print("selected")
    }
}



    
















