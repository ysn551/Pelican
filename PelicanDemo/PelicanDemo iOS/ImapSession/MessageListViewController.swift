//
//  MessageListViewController.swift
//  PelicanDemo iOS
//
//  Created by yoshi-kou on 2017/12/24.
//

import UIKit
import Pelican

class MessageListViewController: UITableViewController {

    var sessionController: ImapSessionViewController {
        return self.parent?.parent as! ImapSessionViewController
    }
    
    var selectedFolder: Folder!
    var messages: [Message] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
        
        self.sessionController.command({ [weak self] (imap) in
            guard let `self` = self else { return }
//            try imap.fetch(range: 1..<50, options: [.messageHeader, .bodystructure], completion: { (message) in
//                OperationQueue.main.addOperation {
//                    self.appendMessage(message)
//                }
//            }).check()
//            try imap.fetchLast(num: 50, options: [.messageHeader, .bodystructure]) { (message) in
//                OperationQueue.main.addOperation {
//                    self.appendMessage(message)
//                }
//            }.check()
//            let condition: SearchCondition = .and(.key(.sentbefore(day: 10, month: 2, year: 2018)), .key(.sentsince(day: 1, month: 1, year: 2018)))
//            let condition: SearchCondition = .key(.subject("テスト"))
//            let uids = try imap.search(condition)
//            print(uids)
            try imap.select(self.selectedFolder.name)
//            try imap.search
            var fetchCount = 0
            for term in SearchCondition.weeks(range: 0..<48) {
                let uids = try imap.search(term)
                fetchCount += uids.count
                try imap.fetch(uids: uids, options: [.messageHeader, .bodystructure]) { [weak self] (messages) in
                    OperationQueue.main.addOperation {
                        self?.appendMessage(messages)
                    }
                }
                
                if fetchCount >= 50 {
                    break
                }
            }
            
        }, catched: { (error) in
            self.sessionController.handleImapError(error as? ImapSessionError)
        })
    }
    
    func appendMessage(_ message: Message) {
        guard message.header != nil else { return }
        self.tableView.beginUpdates()
        self.messages.append(message)
        let appendingIndexPath = IndexPath(row: self.messages.count-1, section: 0)
        self.tableView.insertRows(at: [appendingIndexPath], with: .top)
        self.tableView.endUpdates()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return self.messages.count
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MessageCell", for: indexPath) as! MessageCell

        let header = self.messages[indexPath.row].header!
        cell.ibSubjectLabel.text = header.subject
        cell.ibFromLabel.text = header.from.first!.displayName ?? header.from.first!.email

        if let date = header.date {
            let dateFormatter = DateFormatter()
            dateFormatter.calendar = Calendar(identifier: .gregorian)
            dateFormatter.dateStyle = .short
            dateFormatter.timeStyle = .short
            cell.ibDateLabel.text = dateFormatter.string(from: date)
            cell.ibDateLabel.isHidden = false
        } else {
            cell.ibDateLabel.isHidden = true
        }
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 73
    }


    /*
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
        if segue.identifier == "MessageDetailViewController",
            let selectedIndex = self.tableView.indexPathForSelectedRow {
            let dest = segue.destination as! MessageDetailViewController
            let selectedMessage = self.messages[selectedIndex.row]
            dest.message = selectedMessage
        }
    }

}
