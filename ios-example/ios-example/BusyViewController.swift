//
//  BusyViewController.swift
//  ios-example
//
//  Created by IAMPASS on 2023-03-20.
//

import Foundation
import UIKit

class BusyViewController : UIViewController{
    
    @IBOutlet weak var messageLabel: UILabel!
    private var messageText: String = ""
    
    static func showBusyView( presenter: UIViewController, message: String) -> BusyViewController{
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "BusyView") as! BusyViewController
        vc.message = message
        vc.modalPresentationStyle = .fullScreen
        vc.modalTransitionStyle = .crossDissolve
        
        presenter.present(vc, animated: true)
        return vc
    }

    var message: String{
        get {
                return self.messageText
            }
            set(value){
                self.messageText = value
                if let label = self.messageLabel{
                    label.text=messageText
                }
            }
        }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.message = messageText
    }
}
