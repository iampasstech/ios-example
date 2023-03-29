# ios-example
This is an example iOS application that uses [IAMPASS](https://iampass.com) to authenticate users. Because IAMPASS uses push notifications the application will only run on a physical Apple device.

## Getting Started
### Create an IAMPASS Application
The application requires that you create an IAMPASS developer [account](https://iam-api.com).
Once you have created an you can create an IAMPASS Application. You can find instructions [here](https://iampass.readthedocs.io/en/latest/ios_framework.html).

The application ID and application secret you obtained when you create the IAMPASS application should be entered in AppDelegate.swift
```swift
let IAMPASS_APPLICATION_ID = "YOUR APPLICATION ID"
let IAMPASS_APPLICATION_SECRET="YOUR APPLICATION SECRET"
```
### Configure the iOS Application
You will need to update the Team ID and Bundle Identifier in the project settings to match your Apple development team.
The IAMPASS framework is provided as a CocoaPod. Before building the application you must install the pod. Open a terminal window in the project folder and run
```bash
pod install
```

### Modify IAMPASS Notification Settings
By default IAMPASS sends authentication notifications to the IAMPASS Authenticator App.
To send the notifications to the example app you have to change the notification settings for the application on on the IAMPASS developer site. See 'Configure IAMPASS Notification Credentials' section in the getting started [guide](https://iampass.readthedocs.io/en/latest/ios_framework.html#configure-iampass-notifications-credentials).


## Using the Application
### Registering a user
The application illustrates registering new users and using IAMPASS to authenticate them.
The first time the application is run there is no registered user so you will have to enter a username and tap the 'Register' button. The username must be unique for your IAMPASS application.
When you tap the register button the application will perform user training.
### Authenticating
Once you have registered a user you can tap the 'Login' button to authenticate the user.
The device will receive a push notification and present the authentication UI.
You can tap the 'Logout' button to log out.
### Reseting the user
If the device already has a registered user the registration screen is skipped at startup.
To delete the stored user tap the 'Reset' button.

## Code Overview
### DeviceStorage.swift
The application stores the user information in standard defaults. DeviceStorage provides a simple way to access the user data. For a production application a more secure method of storing user information is suggested, the KeyChain for example.
In this application the username entered is used to identify the user to IAMPASS. It is a better option to maintain an application specific lookup table/method that maps your application username to an IAMPASS user ID.

### AppDelegate.swift
AppDelegate.swift contains the code to register for and handle push notifications.
The method ```updateUserData(notificationToken: String)``` is called once the application has registered to receive push notifications.
This method checks to see if there is a registered user and calls the ```IPUser.update``` method. This method ensures that the device notification token is up to date and that the user information stored on the device is up to date. The ```update``` call may result in additional training being required.
```swift
private func updateUserData(notificationToken: String){
    let deviceStorage = DeviceStorage()
    deviceStorage.Load()
    
    if let identifier = deviceStorage.identifier, let user = deviceStorage.user{
        
        // Display a 'busy view' while we are updating the user'
        let busyView = self.showBusyView(message: "Updating User Data")

        // Call IAMPASS to update the user data.
        user.update(identifier: identifier, notification_token: notificationToken) { identifier, updated_user in
            
            // Save the updated user data.
            deviceStorage.user = updated_user
            deviceStorage.Save()
            
            // Hide the busy view
            DispatchQueue.main.async {
                busyView.dismiss(animated: true)
            }
            
            // Check if training is required.
            if user.training_required{
                // Do the training.
                self.doTrainingForDevice(identifier: identifier, user: updated_user)
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

```

When the application receives a push notification the `AppDelegate.didReceiveRemoteNotification` method is called. In this method an instance of `IPNotificationHandler` is created and the notification data is passed to its `processNotification`. This method examines the content of the notification and calls the `onAuthenticationRequest` code block. This code block displays the authentication UI.
The calls to `NotificationCenter.default.post` are used to inform the application that the authentication flow is complete so the it can restore the application UI.
```swift
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

    } ...
```

###RegisterViewController.swift
`RegisterViewController` contains the code to register users. When the user taps the register button the `onRegister` method is called. This method uses an `IPManagementAPI` to create the new IAMPASS user and register the mobile device.
``` swift
// Register the user.

// Create an IAMPASS management API interface using the optional custom server
// configuration, IAMPASS_CONFIGURATION defined in AppDelegate.swift
// or the default IAMPASS server.
let iampassConfig = IAMPASS_CONFIGURATION ?? IAMPASSConfiguration.DEFAULT_IAMPASS_CONFIGURATION
let managementAPI = IPManagementAPI(application_id: IAMPASS_APPLICATION_ID, application_secret: IAMPASS_APPLICATION_SECRET, iampass_configuration: iampassConfig)

// Create a user using the supplied username and the notification token
// received when the app started up.
managementAPI.create_user_and_register_device(user: userName, notification_token: NOTIFICATION_TOKEN) { identifier, user in
    
    // The user has been created and this device has been registered so save the information.
    let deviceStorage = DeviceStorage(identifier: userName, user: user)
    deviceStorage.Save()
    
    // IAMPASS may require the collection of training data.
    // If training is required show the training UI.
    if user.training_required{
        // Do training for the user.
        self.doTraining(user: user, identifier: userName)
    }
    
} failure: { identifier, error in
    self.showError(title: "Registration Failed", error: error)
}
```
In the example the username entered in the edit control is used as the IAMPASS user ID. See the DeviceStorage.swift section for suggestions using a lookup table to separate your application username from the IAMPASS user ID.

###ViewControllwr.swift
`ViewController` contains the code to login and logout the registered user.
The same button `ViewController.loginButton` is used to handle login and logout, the text on the button is changed depending on the login state.
When an aplication triggers the authentication process it receives an `IPAuthenticationSession` instance. This instance is used to determin the authentication state of the user.
The login process is triggered in `ViewController.doLogin()`. This method uses an instance of `IPAuthenticationAPI` to trigger the authentication process.


``` swift
func doLogin(){
        // Get the stored user information.
        let storage = DeviceStorage()
        storage.Load()
        if let _ = storage.user, let userName = storage.identifier{
            // Create an authentication API instance using the app configuration
            // (AppDelegate.swift) or the defauly IAMPASS server configuration.
            let iampassConfig = IAMPASS_CONFIGURATION ?? IAMPASSConfiguration.DEFAULT_IAMPASS_CONFIGURATION
            
            let api = IPAuthenticationAPI(application_id: IAMPASS_APPLICATION_ID,
                                          application_secret: IAMPASS_APPLICATION_SECRET,
                                          iampass_configuration: iampassConfig)
            
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
                                self.currentSession = session
                                self.updateUIforAuthenticationState()
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
```
The method calls `IPAuthentcationAPI.authenticateUser`, saves the returned `IPAuthenticationSession` instance and waits for the `AUTHENTICATION_COMPLETE_MESSAGE` posted by the notification handler in `AppDelegate`.
On receipt of the `AUTHENTICATION_COMPLETE_MESSAGE` the `IPAuthenticationSession` is refreshed an its status used to determine whether the user was authenticated.
It is good practice to call `IPAuthenticationSession.refresStatus` before allowing access to any protected resource because IAMPASS allows sessions to be closed remotely or when a user leaves the proximity of a protected resource (walkaway feature).