//
//  PlaceListViewController.swift
//  Snacktacular
//
//  Created by Linda Chen on 11/28/17.
//  Copyright © 2017 Synestha. All rights reserved.
//

import UIKit
import CoreLocation
import Firebase
import FirebaseAuthUI
import FirebaseGoogleAuthUI

class PlaceListViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    
    var places = [PlaceData]()
    var authUI: FUIAuth!
    var db: Firestore!
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //places.append(PlaceData(placeName: "Shake Shack", address: "The Street - Chestnut Hill", coordinate: CLLocationCoordinate2D(), postingUserID: "" ))
        //places.append(PlaceData(placeName: "The Eagle's Nest", address: "McElroy Commons", coordinate: CLLocationCoordinate2D(), postingUserID: "" ))
        
        db = Firestore.firestore()
        authUI = FUIAuth.defaultAuthUI()
        // You need to adopt a FUIAuthDelegate protocol to receive callback
        authUI?.delegate = self
        
        
        tableView.dataSource = self
        tableView.delegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        loadData()
        checkForUpdates()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(true)
        signIn()
    }
    
    func signIn() {
        let providers: [FUIAuthProvider] = [FUIGoogleAuth()]
        if authUI.auth?.currentUser == nil {
            self.authUI?.providers = providers
            present(authUI.authViewController(), animated: true, completion: nil)
        }
    }
    
    func checkForUpdates() {
        db.collection("places").addSnapshotListener { (querySnapshot, error) in
            guard error == nil else {
                print("ERROR: adding the snapshot listener \(error!.localizedDescription)")
                return
            }
            self.loadData()
        }
    }
    
    func loadData() {
        db.collection("places").getDocuments { (querySnapshot, error) in
            guard error == nil else {
                print("ERROR: reading documents \(error?.localizedDescription)")
                return
            }
            
            self.places = []
            for document in querySnapshot!.documents {
                
                let placeDocumentID = document.documentID
                let docData = document.data()
                let placeName = docData["placeName"] as! String? ?? ""
                let address = docData["address"] as! String? ?? ""
                let postingUserID = docData["postingUserID"] as! String? ?? ""
                
                let latitude = docData["latitude"] as! CLLocationDegrees? ?? 0.0
                let longitude = docData["longitude"] as! CLLocationDegrees? ?? 0.0
                let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                
                self.places.append(PlaceData(placeName: placeName, address: address, coordinate: coordinate, postingUserID: postingUserID, placeDocumentID: placeDocumentID))
            }
            
            self.tableView.reloadData()
        }
    }
    
    func saveData(index:Int) {
        //Grab unique user ID
        if let postingUserID = authUI.auth?.currentUser?.email {
            places[index].postingUserID = postingUserID
        } else {
            places[index].postingUserID = "Unknown User"
        }
        
        //Simplify coordinates into strings
        let latitude = places[index].coordinate.latitude
        let longitude = places[index].coordinate.longitude
        
        //Create a dictionary
        let dataToSave: [String:Any] =
            ["placeName": places[index].placeName,
             "address": places[index].address,
             "postingUserID": places[index].postingUserID,
             "latitude": latitude,
             "longitude": longitude]
        
        //If we have a saved record, we'll have an ID:
        if places[index].placeDocumentID != "" {
            let ref = db.collection("places").document(places[index].placeDocumentID)
            ref.setData(dataToSave) { (error) in
                if let error = error {
                    print("Error: updating document \(error.localizedDescription)")
                } else {
                    print("Document updated with reference ID \(ref)")
                }
            }
        } else {
        //Otherwise we need to make a new one. Firestore will make a new ID for us.
            var ref: DocumentReference? = nil
            ref = db.collection("places").addDocument(data: dataToSave) { (error) in
                if let error = error {
                    print("Error: adding document \(error.localizedDescription)")
                } else {
                    print("Document updated with reference ID \(ref)")
                    self.places[index].placeDocumentID = "\(ref!.documentID)"
                }
                
            }
            
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "ShowDetail" {
            let destination = segue.destination as! DetailViewController
            let selectedRow = tableView.indexPathForSelectedRow!.row
            destination.placeData = places[selectedRow]
        } else {
            if let selectedIndexPath = tableView.indexPathForSelectedRow {
                tableView.deselectRow(at: selectedIndexPath, animated: true)
            }
        }
    }
    
    @IBAction func unwindFromDetail(segue: UIStoryboardSegue) {
        let source = segue.source as! DetailViewController
        if let selectedIndexPath = tableView.indexPathForSelectedRow {
            places[selectedIndexPath.row] = (source.placeData)!
            tableView.reloadRows(at: [selectedIndexPath], with: .automatic)
            saveData(index: selectedIndexPath.row)
        } else {
            let newIndexPath = IndexPath(row: places.count, section: 0)
            places.append((source.placeData)!)
            tableView.insertRows(at: [newIndexPath], with: .bottom)
            tableView.scrollToRow(at: newIndexPath, at: .bottom, animated: true)
            saveData(index: newIndexPath.row)
        }
    }
    

    @IBAction func SignOutButtonPressed(_ sender: UIBarButtonItem) {
        
        do {
            try authUI!.signOut()
            print("^^^ Successfully signed out!")
            signIn()
        } catch {
            print("Couldn't sign out")
        }
    }
    
}

extension PlaceListViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return places.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.textLabel?.text = places[indexPath.row].placeName
        //cell.detailTextLabel?.text = places[indexPath.row].address
        cell.detailTextLabel?.text = places[indexPath.row].postingUserID
        return cell
    }
}

extension PlaceListViewController: FUIAuthDelegate {
    
    func application(_ app: UIApplication, open url: URL,
                     options: [UIApplicationOpenURLOptionsKey : Any]) -> Bool {
        let sourceApplication = options[UIApplicationOpenURLOptionsKey.sourceApplication] as! String?
        if FUIAuth.defaultAuthUI()?.handleOpen(url, sourceApplication: sourceApplication) ?? false {
            return true
        }
        // other URL handling goes here.
        return false
    }
    
    func authUI(_ authUI: FUIAuth, didSignInWith user: User?, error: Error?) {
        if let user = user {
            print("*** Successfully logged in with user = \(user.email!)")
        }
    }
    
    func authPickerViewController(forAuthUI authUI: FUIAuth) -> FUIAuthPickerViewController {
        let loginViewController = FUIAuthPickerViewController(authUI: authUI)
        loginViewController.view.backgroundColor = UIColor.white
        
        let marginInset: CGFloat = 16
        let imageY = self.view.center.y - 225
        
        let logoFrame = CGRect(x: self.view.frame.origin.x + marginInset, y: imageY, width: self.view.frame.width - (marginInset*2), height: 225)
        let logoImageView = UIImageView(frame: logoFrame)
        logoImageView.image = UIImage(named: "logo")
        logoImageView.contentMode = .scaleAspectFit
        loginViewController.view.addSubview(logoImageView)
        
        return loginViewController
    }
    
}
