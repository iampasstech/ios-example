//
//  ViewController.swift
//  ios-example
//
//  Created by Jason Mullings on 2023-02-27.
//

import UIKit
import IAMPASSiOS


class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(true)
        // Check if we have a uer.
        // If we don't have a user display the register view.
        let deviceStorage = DeviceStorage()
        deviceStorage.Load()
        if( deviceStorage.user == nil){
            self.showRegisterView()
        }
    }
    
    private func showRegisterView(){
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "RegisterView")
        vc.modalPresentationStyle = .fullScreen
        vc.modalTransitionStyle = .crossDissolve
        self.present(vc, animated: true)
    }
    
    @IBAction func onLogin(_ sender: Any) {
        let storage = DeviceStorage()
        storage.Load()
        if let _ = storage.user, let userName = storage.identifier{
            let api = IPAuthenticationAPI(application_id: IAMPASS_APPLICATION_ID, application_secret: IAMPASS_APPLICATION_SECRET, iampass_configuration: IAMPASS_CONFIGURATION)
            
            let busyView = BusyViewController.showBusyView(presenter: self, message: "Authenticating")
            // Reset the session.
            api.authenticateUser(client_id: userName, methods: Array()) { client_id, session in
                
                // To maintain the view hierarchy we have to wait until the Authentication UI presented when
                // the authentication notification is received has been cleaned up.
                // The AppDelegate posts the AUTHENTICATION_UI_COMPLETE_MESSAGE notification when it is done.
                
                var token: NSObjectProtocol?
                token = NotificationCenter.default.addObserver(forName: AUTHENTICATION_UI_COMPLETE_MESSAGE, object: nil, queue: OperationQueue.main) { _ in
                    // Remove the observer because we don't need it any more.
                    NotificationCenter.default.removeObserver(token!)
                    
                    // We now have to refresh the status of the session to see what the result was.
                    session.refreshStatus { status in
                        DispatchQueue.main.async {
                            
                            if( session.didFail){
                                busyView.dismiss(animated: true)
                                let message = session.status == SessionStatus.time_out ? "Authentication request timed out." : "Authentication request failed"
                                self.showMessage(title: "Authentication Failed", message: message)

                            }else{
                                // The user is authenticated.
                                busyView.dismiss(animated: true)
                                self.showMessage(title: "Authenticated", message: "User Authenticated")
                            }
                        }
                    } failure: { error in
                        DispatchQueue.main.async {
                            busyView.dismiss(animated: true)
                            busyView.dismiss(animated: true)
                            let message = session.status == SessionStatus.time_out ? "Authentication request timed out." : "Authentication request failed"
                            self.showMessage(title: "Authentication Failed", message: message)
                        }
                    }
                }
            } failure: { error in
                // The authentication process failed to start.
                DispatchQueue.main.async {
                    busyView.dismiss(animated: true)
                }
            }
        }
    }
    
    private func showMessage( title: String, message: String){
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        self.present(alert, animated: true)
    }
    
    
    @IBAction func onReset(_ sender: Any) {
        // This method unregisters this device from the IAMPASS system.
        // The user is not deleted from the system. The API to do this requires the use of the IAMPASS account
        // credentials used to create this application.
        
        // Get the saved IAMPASS user data.
        let storage = DeviceStorage()
        storage.Load()
        
        // If there is no saved data return.
        guard let user = storage.identifier, let device = storage.user else{
            return
        }
        
        // Unregister the stored device information.
        device.unregister(identifier: user as Any, success: { identifier in
            // The device has been unregistered.
            DeviceStorage.Reset()
            DispatchQueue.main.async {
                let alert = UIAlertController(title: "User Reset", message: "User data has been reset", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { action in
                    self.showRegisterView()
                }))
                self.present(alert, animated: true)
            }
        }, failure: { identifier, error in
            DeviceStorage.Reset()
            DispatchQueue.main.async {
                let alert = UIAlertController(title: "User Reset", message: "Failed to unregister device", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { action in
                    self.showRegisterView()
                }))
                self.present(alert, animated: true)
            }
        })
    }
}

