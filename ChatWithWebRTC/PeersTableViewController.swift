//
//  PeersTableViewController.swift
//  ChatWithWebRTC
//
//  Created by JingWen on 2017/1/14.
//  Copyright © 2017年 JingWen. All rights reserved.
//

import Foundation
import UIKit

let kCellIdentifiler = "cell"

class PeersTableViewController:UITableViewController{
    fileprivate var myContext = 0
    
    @IBOutlet weak var refresh:UIBarButtonItem!
    fileprivate let bjClient = BonjourClient()
    fileprivate let calleePool = CalleePool.sharedInstance()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.rightBarButtonItem = self.refresh
        NotificationCenter.default.addObserver(forName: BonjourClient_NewPeer, object: nil, queue: OperationQueue.main) { (notification) in
            if let dict = notification.userInfo{
                let device = dict[BonjourClient_NewCallee.device] as! String
                let ip = dict[BonjourClient_NewCallee.ip] as! String
                
                let newCallee = Callee(device, address: ip, sendHello: true)
                self.calleePool.updateCalles(newCallee, complete: { 
                    self.updateCalleList()
                })
            }
        }
        
        NotificationCenter.default.addObserver(forName: SignalingServer_NewPeer, object: nil, queue: OperationQueue.main) { (notification) in
            if let dict = notification.userInfo{
                let device = dict[Callee_HTTPHeader_Key.device] as! String
                let ip = dict[Callee_HTTPHeader_Key.ip] as! String
                let sessionId = dict[Callee_HTTPHeader_Key.sessionId] as! String
                let newCallee = Callee(device, address: ip)
                newCallee.uid = sessionId
                self.calleePool.updateCalles(newCallee, complete: { 
                    self.updateCalleList()
                })
            }
        }
        
        NotificationCenter.default.addObserver(forName: SignalingServer_ReceiveOffer, object: nil, queue: OperationQueue.main) { (notification) in
            let sessionId = notification.object as! String
            let index = CalleePool.sharedInstance().index(sessionId)
            self.performSegue(withIdentifier: "chat", sender: index!)
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    fileprivate func updateCalleList(){
        let indexSet = IndexSet(integer: 0)
        self.tableView.beginUpdates()
        self.tableView.reloadSections(indexSet, with: .automatic)
        self.tableView.endUpdates()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        self.bjClient.search(false)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        var isCaller = false
        var index = 0
        if let indexPath = self.tableView.indexPathForSelectedRow{
            index = indexPath.row
            isCaller = true
        }else{
            index = sender as! Int
            isCaller = false
        }
        
        let callee = self.calleePool.callee(fromIndex: index)
        let vc = segue.destination as! ChatViewController
        vc.callee = callee
        vc.isCaller = isCaller
    }
}

extension PeersTableViewController{
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.calleePool.totalCallees()
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let callee = self.calleePool.callee(fromIndex: indexPath.row)
        let cell = tableView.dequeueReusableCell(withIdentifier: kCellIdentifiler, for: indexPath)
        cell.textLabel?.text = callee.device
        #if DEBUG
            cell.detailTextLabel?.text = "\(callee.ip):\(callee.uid)"
        #else
            cell.detailTextLabel?.text = callee.ip
        #endif
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
    }
}

extension PeersTableViewController{
    @IBAction func clickRefresh(){
//        RTCUtil.sharedInstance().findCallees()
        self.bjClient.search()
    }
}

