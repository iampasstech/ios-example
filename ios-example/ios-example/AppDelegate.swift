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
        
        let defaults = UserDefaults.standard
        var registeredDevices: [IPMobileDevice] = []
        if let saved_device = defaults.object(forKey: "user_data") as? Data{
            let decoder = JSONDecoder()
            if let device = try? decoder.decode(IPMobileDevice.self, from: saved_device){
                registeredDevices.append(device)
            }

        }
        
        if let notificationHandler = self.notificationHandler{
            
        
            let iampassResponse = notificationHandler.processNotification(userInfo: userInfo, registeredDevices: registeredDevices)
  
            if iampassResponse.ipNotification{
                completionHandler(iampassResponse.suggestedCompletionResult)
                return
            }
        }
        print("Got a notification")
        completionHandler(.noData)
    
    }


}

