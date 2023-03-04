//
//  AppDelegate.swift
//  ios-example
//
//  Created by Jason Mullings on 2023-02-27.
//

import UIKit
import IAMPASSiOS

var NOTIFICATION_TOKEN: String = ""


@main
class AppDelegate: UIResponder, UIApplicationDelegate, IPNotificationHandlerDelegate {
    
    var notificationHandler: IPNotificationHandler?
    


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // Initialize the notification handler.
        notificationHandler = IPNotificationHandler(delegate: self)
        
        // Register for push notifications.
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
    /// The application can provide a UI for checking for authentication requests using IPMobileDevice.get_pending_requests

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

    
    //MARK: IPNotificationHandlerDelegate.
    func presentAuthenticationUI(request: IAMPASSiOS.IPAuthenticationRequest, device: IAMPASSiOS.IPMobileDevice) {
        //TODO: implement presentAuthenticationUI.
    }
    
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

    func registeredForNotifications( token: String){
        NOTIFICATION_TOKEN = token
    }

    
    func application(
      _ application: UIApplication,
      didReceiveRemoteNotification userInfo: [AnyHashable: Any],
      fetchCompletionHandler completionHandler:
      @escaping (UIBackgroundFetchResult) -> Void
    ) {
        
        // IAMPASS authentcation request notifications contain data to identify the user the request targets.
        // We have to provide the notification handler with a list of user data that is stored on this device so that it can determine whether the notification should be handled.
        var registeredDevices: [IPMobileDevice] = []
        
        let deviceStorage = DeviceStorage()
        deviceStorage.Load()
        
        if let mobile_device = deviceStorage.device{
            registeredDevices.append(mobile_device)
        }
        
        // We can now pass the notification payload to the IAMPASS notification handler.
        // If the notification is an IAMPASS authentication notification the presentAuthenticationUI method will be called.
        // If the notification is an IAMPASS session status notification the sessionStatusChanged will be called.
        // If the ipNotification property of the return value of processNotification is true, the notification is an IAMPASS notification and the method should call completionHandler with the suggestedCompletionResult property of the return value.
        // If the ipNotification property is false continue with normal notification handling.
        if let notificationHandler = self.notificationHandler{
            
            // Pass the notification to the IAMPASS notification handler.
            let iampassResponse = notificationHandler.processNotification(userInfo: userInfo, registeredDevices: registeredDevices)
  
            if iampassResponse.ipNotification{
                completionHandler(iampassResponse.suggestedCompletionResult)
                return
            }else{
                //TODO: continue normal notification handling.
            }
        }
        completionHandler(.noData)
    
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
        
        if let identifier = deviceStorage.identifier, let mobile_device = deviceStorage.device{
            
            // Call IAMPASS to update the user data.
            mobile_device.update(identifier: identifier, notification_token: notificationToken) { identifier, updated_device in
                
                // Save the updated user data.
                deviceStorage.device = updated_device
                deviceStorage.Save()
                
                // Check if training is required.
                if mobile_device.training_required{
                    self.doTrainingForDevice(identifier: identifier, device: updated_device)
                }

            } failure: { identifier, error in
                // User update failed
                // TODO: Add UI to inform user.
            }
        }
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
    func doTrainingForDevice(identifier: Any, device: IPMobileDevice) {
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
                        let storage = DeviceStorage(identifier: id as String, device: device)
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

