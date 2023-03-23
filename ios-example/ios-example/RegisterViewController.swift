//
//  RegisterViewController.swift
//  ios-example
//
//  Created by Jason Mullings on 2023-03-04.
//

import UIKit
import IAMPASSiOS

class RegisterViewController: UIViewController, UITextFieldDelegate {

    @IBOutlet weak var usernameTextField: UITextField!
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the text field delegate so we can dismiss it when the done button is tapped.
        usernameTextField.delegate = self
    }
    
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

    @IBAction func onRegister(_ sender: Any) {
        if let userName = usernameTextField.text{
            if !userName.isEmpty{
                // Register the user.
                
                let managementAPI = IPManagementAPI(application_id: IAMPASS_APPLICATION_ID, application_secret: IAMPASS_APPLICATION_SECRET, iampass_configuration: IAMPASS_CONFIGURATION)
                
                managementAPI.create_user_and_register_device(user: userName, notification_token: NOTIFICATION_TOKEN) { identifier, user in
                    
                    // The user has been created and this device has been registered so save the information.
                    let deviceStorage = DeviceStorage(identifier: userName, user: user)
                    deviceStorage.Save()
                    
                    // If training is required show the training UI.
                    if user.training_required{
                        // Do training for the user.
                        self.doTraining(user: user, identifier: userName)
                    }
                    
                } failure: { identifier, error in
                    self.showError(title: "Registration Failed", error: error)
                }
            }
        }
    }
    
    // Performs training required by IAMPASS for the specified user.
    private func doTraining( user: IPUser, identifier: String){
        // We have to make sure UI changes happen on the main thread.
        DispatchQueue.main.async {
            // This is used to present the training UI.
            if let vc = IPTrainingViewController.create(device: user, identifier: identifier, success: { sender, identifier, device in
                // The training process completed successfuly so save the user information.
                if let id = identifier as? String{
                    let storage = DeviceStorage(identifier: id as String, user: user)
                    storage.Save()
                }
                // sender is the training UI view controller, so dismiss it.
                sender.dismiss(animated: true)
                // Now go to the main UI.
                self.dismiss(animated: true)
            }, failure: { sender, identifier, device, error in
                self.showError(title: "Training Failed", error: error)
                sender.dismiss(animated: true)
            }){
                // Present the training UI.
                vc.modalPresentationStyle = .fullScreen
                vc.modalTransitionStyle = .crossDissolve
                self.present(vc, animated: true, completion: nil)
            }
        }
    }
    
    /// Displays an alert with the specified title and the localized description of the error.
    private func showError( title: String, error: Error?){
        DispatchQueue.main.async {
            let errorMessage = error == nil ? "Unknown Error" : error?.localizedDescription

            // Show an alert
            let alert = UIAlertController(title: title, message: errorMessage, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            self.present(alert, animated: true)
        }

    }
}
