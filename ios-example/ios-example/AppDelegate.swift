//
//  AppDelegate.swift
//  ios-example
//
//  Created by IAMPASS on 2023-02-27.
//

import UIKit
import IAMPASSiOS

// Global value used to store the notification token the app receives from APNS.
// This value is used to identify this device to IAMPASS so that it knows where to
// send authentication requests.
var NOTIFICATION_TOKEN: String = ""

// These values are the application ID and secret provided by IAMPASS for your application.
// This is not necessarily the best way to store these value.
let IAMPASS_APPLICATION_ID = "e9dcd48757ae43739eed6150ea51a389"
let IAMPASS_APPLICATION_SECRET="J5WHAK1KKRYSQ5IGB4NFPL4YSGX5GRY2"

// This example uses the default IAMPASS servers.
// If you are using a custom IAMPASS server you can set IAMPASS_CONFIGURATION to
// values appropriate for your server.
// IAMPASSConfiguration(server_url: URL(string: "https://MY-CUSTOM-SERVER")!)
let IAMPASS_CONFIGURATION: IAMPASSConfiguration? = nil

// When an authentication request is triggered by the application (tapping the login button)
// IAMPASS sends a push notification to the users registered device (this device).
// The push notification is handled in AppDelegate:didReceiveRemoteNotification.
// To code that handle the notification and displays the authentication UI posts this
// message once the authentication UI has completed so that the rest of the app can update
// its state.
// If your system does not allow users to login from the mobeile application this is not
// required.
let AUTHENTICATION_UI_COMPLETE_MESSAGE = Notification.Name("AUTHENTICATION_UI_COMPLETE")


@main
class AppDelegate: UIResponder, UIApplicationDelegate{
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // IAMPASS communcates authentication requets to the application using Push Notifications.
        // The application has to follow the standard rules for Push Notifications:
        // 1) Add notification entitlement.
        // 2) Request user permission to receive push notifications.
        registerForPushNotifications()

        return true
    }
    
    
    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
    
    //MARK: Notification registration
    /// IAMPASS communicates authentication requests using Push Notifications.
    /// This method requests permission to receive push notifications and if granted registers to receive remote notifications.
    /// If the registration process is successful, didRegisterForRemoteNotificationsWithDeviceToken is called.
    /// If the registration proces fails, didFailToRegisterForRemoteNotificationsWithError is called.
    /// If the process fails the application will not receive authentications requests.
    /// The application can provide a UI for checking for authentication requests using IPUser.get_pending_requests

    func registerForPushNotifications() {
        // The simulator does not support push notifications so we fake it using a token
        // that the IAMPASS server will know is not a real APNS token (starts with a *).
        #if targetEnvironment(simulator)
            self.registeredForNotifications(token: "*SIMULATOR_TOKEN")
            return
        #else
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) {
             granted, error in
              
            guard granted else { return }
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                guard settings.authorizationStatus == .authorized else { return }
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
        #endif
    }

    /// IAMPASS allows users ot be logged out remotely.
    /// When this happens a push notification is sent to the users registered mobile device.
    func sessionStatusChanged(status: IAMPASSiOS.IPSessionStatus) {
        //TODO: implement sessionStatusChanged.
    }

    /// Called when the application has registered for push notifications
    func application(
      _ application: UIApplication,
      didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        self.registeredForNotifications(token: token)
    }
    

    func application(
      _ application: UIApplication,
      didFailToRegisterForRemoteNotificationsWithError error: Error) {
    }

    // This method is called when we have registered for push notifications.
    // At this point we have to update the stored user if we have one.
    // This ensures that IAMPASS has an up to date token to use when sending push notifications.
    func registeredForNotifications( token: String){
        NOTIFICATION_TOKEN = token
        
        self.updateUserData(notificationToken: NOTIFICATION_TOKEN)
    }

    func application(
      _ application: UIApplication,
      didReceiveRemoteNotification userInfo: [AnyHashable: Any],
      fetchCompletionHandler completionHandler:
      @escaping (UIBackgroundFetchResult) -> Void
    ) {
        
        // IAMPASS authentcation request notifications contain data to identify the user the request targets.
        // We have to provide the notification handler with a list of user data that is stored on this device so that it can determine whether the notification should be handled.
        
        let deviceStorage = DeviceStorage()
        deviceStorage.Load()
        
        // Do we have a user?
        if let user = deviceStorage.user{
            let registeredUser = [user]
            let  notificationHandler = IPNotificationHandler()
            notificationHandler.processNotification(userInfo: userInfo, registeredUsers: registeredUser) { request, user in
                // This is an authentication request for a user of this device so show the authentication UI.
                let vc = IPAuthenticationViewController.create(request: request, device: user) { sender in
                    // Authentication was successful
                    sender.dismiss(animated: false) {
                        // We send a notification now that the UI has been cleaned up so that interested
                        // parties (ViewController) can update their state.
                        NotificationCenter.default.post(name: AUTHENTICATION_UI_COMPLETE_MESSAGE, object: nil)
                    }
                } failure: { sender, error in
                    // Authentication failed.
                    sender.dismiss(animated: false){
                        // We send a notification now that the UI has been cleaned up so that interested
                        // parties (ViewController) can update their state.
                        NotificationCenter.default.post(name: AUTHENTICATION_UI_COMPLETE_MESSAGE, object: nil)
                    }
                }
                vc?.modalPresentationStyle = .fullScreen
                vc?.modalTransitionStyle = .crossDissolve

                self.topViewController()?.present(vc!, animated: true)

            } onStatusChanged: { status in
                // The notification is a session status change notification.
                completionHandler(.noData)
            } onError: { error in
                // There was an error handling the notification.
                completionHandler(.noData)
            } onIgnore: {
                // The notification is an IAMPASS notification but should be ignored.
                completionHandler(.noData)
            } defaultHandler: { userInfo in
                // The notification is not an IAMPASS notification.
                // The application should continue with its normal notification handling.
                completionHandler(.noData)
            }

        }else{
            completionHandler(.noData)
        }
    
    }
    
    //MARK: User management
    /// When an IAMPASS application starts up it should query IAMPASS to update any stored
    /// user data.
    /// This method loads stored user data then calls IAMPASS to refresh the data.
    /// The user data is then stored.
    /// IAMPASS may require that training is performed for the user. The training_required property of
    /// the user is checked and the doTrainingForDevice method is called if required.
    /// We have to perform the training check because the training may not have been completed when
    /// the devive was registered.
    private func updateUserData(notificationToken: String){
        let deviceStorage = DeviceStorage()
        deviceStorage.Load()
        
        if let identifier = deviceStorage.identifier, let mobile_device = deviceStorage.user{
            
            // Display a 'busy view' while we are updating the user'
            let busyView = self.showBusyView(message: "Updating User Data")

            // Call IAMPASS to update the user data.
            mobile_device.update(identifier: identifier, notification_token: notificationToken) { identifier, updated_user in
                
                // Save the updated user data.
                deviceStorage.user = updated_user
                deviceStorage.Save()
                
                // Hide the busy view
                DispatchQueue.main.async {
                    busyView.dismiss(animated: true)
                }
                
                // Check if training is required.
                if mobile_device.training_required{
                    // Do the training.
                    self.doTrainingForDevice(identifier: identifier, device: updated_user)
                }

            } failure: { identifier, error in
                // User update failed

                DispatchQueue.main.async {
                    // Hide the busy view controller.
                    busyView.dismiss(animated: true)
                    // Show an alert
                    let alert = UIAlertController(title: "Update Failed", message: error.localizedDescription, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                    self.topViewController()?.present(alert, animated: true)
                }
            }
        }
    }
    
    private func showBusyView( message: String) -> BusyViewController{
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "BusyView") as! BusyViewController
        vc.message = message
        vc.modalPresentationStyle = .fullScreen
        vc.modalTransitionStyle = .crossDissolve

        self.topViewController()?.present(vc, animated: true)
        return vc

    }
    
    /// Utility method to get a UIViewController the AppDelegate can use to present
    /// other view controllers.
    private func topViewController() -> UIViewController? {
        var windowToUse: UIWindow? = nil;
        for window in UIApplication.shared.windows {
            if window.isKeyWindow {
                windowToUse = window
                break
            }
        }
        
        var topController = windowToUse?.rootViewController
        while ((topController?.presentedViewController) != nil) {
            topController = topController?.presentedViewController
        }
        return topController
    }

    /// Performs training required for the specified device.
    /// This method displays the IAMPASS training view.
    func doTrainingForDevice(identifier: Any, device: IPUser) {
        // It is important that the code to display UI components happens
        // on the main thread.
        DispatchQueue.main.async {
            
            // Get the top view controller.
            // This is used to present the training UI.
            if let topVC = self.topViewController() {
                // Create the IAMPASS training view controller.
                if let vc = IPTrainingViewController.create(device: device, identifier: identifier, success: { sender, identifier, device in
                    // The training process completed successfuly so save the user information.
                    if let id = identifier as? String{
                        let storage = DeviceStorage(identifier: id as String, user: device)
                        storage.Save()
                    }
                    // sender is the training UI view controller, so dismiss it.
                    sender.dismiss(animated: true)
                }, failure: { sender, identifier, device, error in
                    // TODO: Training failed - provide user feedback.
                    sender.dismiss(animated: true)
                }){
                    // Present the training UI.
                    vc.modalPresentationStyle = .fullScreen
                    vc.modalTransitionStyle = .crossDissolve
                    topVC.present(vc, animated: true, completion: nil)
                    
                }
            }
        }
    }
}

