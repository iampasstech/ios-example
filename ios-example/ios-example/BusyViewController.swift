//
//  BusyViewController.swift
//  ios-example
//
//  Created by IAMPASS on 2023-03-20.
//
// THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
// CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
// SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


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
