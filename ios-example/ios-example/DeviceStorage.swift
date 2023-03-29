//
//  DeviceStorage.swift
//  iampass-ios-example
//
//  Created by IAMPASS on 2023-02-28.
//  Copyright © 2023 IAMPASS Technologies Inc. All rights reserved.
//
// THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
// CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
// SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


import Foundation
import IAMPASSiOS

// DeviceStorage is a utility class for storing IAMPASS user information in UserDefaults.
// This is an example only, production code should use a more secure method for storing the data (KeyChain for example).
// The user data is stored as an IPMobileDevice serialized as JSON.
class DeviceStorage{
    
    /// The IAMPASS user data.
    var user: IPUser?
    
    /// The identifier for the user (typically a username).
    var identifier: String?
    
    init(){

    }
    
    init( identifier: String, user: IPUser){
        self.identifier = identifier
        self.user = user
    }
    
    /// Loads the user data from UserDefaults.
    func Load(){
        var loaded_user: IPUser? = nil
        var loaded_identifier: String? = nil

        let defaults = UserDefaults.standard
        // Get the user data, which is an IPUser serialized as JSON.
        if let saved_user = defaults.object(forKey: "user_data") as? Data{
            // Decode the JSON data and create an IPUser.
            let decoder = JSONDecoder()
            if let ld = try? decoder.decode(IPUser.self, from: saved_user){
                loaded_user = ld
            }
            
            if let username = defaults.string(forKey: "user_name"){
                loaded_identifier = username
            }
        }
        self.user = loaded_user
        self.identifier = loaded_identifier
    }
    
    /// Saves the user information.
    /// device is serialized as JSON and written to UserDefaults.
    func Save(){
        let encoder = JSONEncoder()

        if let id = self.identifier, let d = self.user{
        
            if let encoded = try? encoder.encode(d){
                let defaults = UserDefaults.standard
                defaults.set(encoded, forKey: "user_data")
                defaults.set(id, forKey: "user_name")
            }
        }
    }
    
    /// Resets the user data.
    /// The user_date and user_name keys are deleted from UserDefaults.
    public static func Reset(){
        UserDefaults.standard.removeObject(forKey: "user_data")
        UserDefaults.standard.removeObject(forKey: "user_name")

    }
}
