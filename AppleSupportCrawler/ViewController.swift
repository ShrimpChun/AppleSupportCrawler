//
//  ViewController.swift
//  AppleSupportCrawler
//
//  Created by Shrimp Hsieh on 2018/12/17.
//  Copyright © 2018 Chia-Chun Hsieh. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {
    
    @IBOutlet weak var tf_Cookie: NSTextField!
    @IBOutlet weak var tf_Token: NSTextField!
    @IBOutlet weak var tf_Dims: NSTextField!
    @IBOutlet weak var tf_Store: NSTextField!
    
    @IBOutlet weak var lbl_Information: NSTextField!
    @IBOutlet weak var btn_Resev: NSButton!
    
    var countTimer: Timer?
    var countDown: Int = 10
    var bool_StartReservation: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        loadConfig()
        lbl_Information.stringValue = "Ready"
        btn_Resev.title = "Start"
    }
    
    override var representedObject: Any? {
        didSet {
        }
    }
    
    func loadConfig() -> Void {
        if let cookie = UserDefaults.standard.value(forKey: "cookie") as? String    { tf_Cookie.stringValue = cookie }
        if let token = UserDefaults.standard.value(forKey: "token") as? String      { tf_Token.stringValue = token }
        if let dims = UserDefaults.standard.value(forKey: "dims") as? String        { tf_Dims.stringValue = dims }
        if let store = UserDefaults.standard.value(forKey: "store") as? String      { tf_Store.stringValue = store }
    }
    
    @IBAction func startReservation(_ sender: Any) {
        
        if tf_Token.stringValue.count > 0   { UserDefaults.standard.set(tf_Cookie.stringValue, forKey: "cookie") }
        if tf_Cookie.stringValue.count > 0  { UserDefaults.standard.set(tf_Token.stringValue, forKey: "token") }
        if tf_Dims.stringValue.count > 0    { UserDefaults.standard.set(tf_Dims.stringValue, forKey: "dims") }
        if tf_Store.stringValue.count > 0   { UserDefaults.standard.set(tf_Store.stringValue, forKey: "store") }
        
        initialTimer()
        
        bool_StartReservation = !bool_StartReservation
        tf_Token.isEditable = !bool_StartReservation
        tf_Cookie.isEditable = !bool_StartReservation
        tf_Dims.isEditable = !bool_StartReservation
        tf_Store.isEditable = !bool_StartReservation
        btn_Resev.title = (bool_StartReservation == true) ? "Cancel" : "Start"
        
        if bool_StartReservation == true {
            countTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { (_) in
                self.startCountTimer()
            })
        } else {
            countDown = 10
            lbl_Information.stringValue = "Ready"
        }
    }
    
    // MARK: Reset Timer
    func initialTimer() -> Void {
        countTimer?.invalidate()
        countTimer = nil
    }
    
    func startCountTimer() -> Void {
        if countDown == 0 {
            lbl_Information.stringValue = String(format: "Please wait...", countDown)
            countDown = 10
            callSupportAPI()
        } else {
            lbl_Information.stringValue = String(format: "Check the reservation after %d second(s)...", countDown)
            countDown = countDown - 1
        }
    }
    
    
    func callSupportAPI() -> Void {
        let queryURL = URL(string: "https://getsupport.apple.com/web/v2/takein/timeslots")!
        let header: [String:String] = [
            "X-Apple-CSRF-Token": tf_Token.stringValue,
            "Cookie": tf_Cookie.stringValue,
            "Content-Type" : "application/json; charset=UTF-8",
            "cp" : "cin"
        ]
        
        var request = URLRequest(url: queryURL, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 10)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = header
        
        do {
            let body = ["store": tf_Store.stringValue, "athenaRetailRequest": ["dims": tf_Dims.stringValue, "clientTimeZone": 480]] as [String : Any]
            let jsonData = try JSONSerialization.data(withJSONObject: body, options: .prettyPrinted)
            request.httpBody = jsonData
        } catch {
            print(error.localizedDescription)
        }
        
        let session = URLSession.shared
        let task = session.dataTask(with: request) { (data, response, error) in
            if let error = error {
                self.popErrorMsg(code: "", msg: error.localizedDescription)
            } else {
                self.initialTimer()
                if let data = data {
                    do {
                        if let dict = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String:AnyObject] {
                            if let errorDetail = dict["errorDetail"] as? [String:AnyObject] {
                                self.popErrorMsg(code: errorDetail["errorCode"] as? String ?? "", msg: errorDetail["userErrMsg"] as? String ?? "")
                            } else {
                                if let infos = dict["data"] as? [String:AnyObject] {
                                    var bool_available: Bool = false
                                    if let timeslots = infos["timeslots"] as? [String:AnyObject] {
                                        if let days = timeslots["days"] as? Array<[String:AnyObject]> {
                                            for day in days {
                                                if let available = day["available"] as? Int {
                                                    if available > 0 {
                                                        bool_available = true
                                                        break
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    
                                    if bool_available == true {
                                        DispatchQueue.main.async {
                                            self.sendUserNotification(msg: "Reservation Available!ヽ(́◕◞౪◟◕‵)ﾉ")
                                        }
                                    }
                                    
                                    DispatchQueue.main.async {
                                        self.countDown = 10
                                        self.countTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { (_) in
                                            self.startCountTimer()
                                        })
                                    }
                                    
                                }
                            }
                        }
                    } catch {
                        self.popErrorMsg(code: "", msg: error.localizedDescription)
                    }
                }
            }
        }
        task.resume()
    }
    
    // MARK: When reading data error
    func popErrorMsg(code: String, msg: String) {
        DispatchQueue.main.async {
            self.sendUserNotification(msg: "Session expired or invalid parameters. (;´༎ຶД༎ຶ`)")
            let error = NSAlert()
            error.alertStyle = .warning
            error.messageText = msg
            error.informativeText = code
            error.addButton(withTitle: "OK")
            error.beginSheetModal(for: self.view.window!) { (response) in
                if response ==  NSApplication.ModalResponse.alertFirstButtonReturn {
                    self.countDown = 10
                    self.bool_StartReservation = false
                    self.tf_Token.isEditable = true
                    self.tf_Cookie.isEditable = true
                    self.tf_Dims.isEditable = true
                    self.tf_Store.isEditable = true
                    self.btn_Resev.title = "Start"
                    self.lbl_Information.stringValue = "Ready"
                }
            }
        }
    }
    
    func sendUserNotification(msg: String) -> Void {
        let notification = NSUserNotification()
        notification.hasActionButton = false
        notification.hasReplyButton = false
        notification.title = "Apple Repair Reservation Tool"
        notification.informativeText = msg
        NSUserNotificationCenter.default.deliver(notification)
    }
    
}

