//
//  MessageDetailViewController.swift
//  PelicanDemo iOS
//
//  Created by yoshi-kou on 2018/01/04.
//

import UIKit
import Pelican
import WebKit

class MessageDetailViewController: UITableViewController {

    // MARK: - Instance properties
    
    var message: Message!
    var textPart: MailPart!
    var attachments: [MailPart] = []
    
    var webView: WKWebView!
    
    var sessionController: ImapSessionViewController {
        return self.parent?.parent as! ImapSessionViewController
    }
    
    // MARK: - Instance Life Methods
    
    deinit {
//        self.removeWebviewDidChangeSizeObserve()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - View Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
        guard let body = self.message.body else { return }
        
        self.webView = self.makeWebView()
        self.textPart = body.textPart(prefer: .html)
        if body.hasData {
            self.loadText(self.textPart)
        } else {
            self.downloadData(with: body) { (error) in
                guard error == nil else {
                    print("download failure: \(error!)")
                    return
                }
                
                self.loadText(self.textPart)
            }
        }
    }
    
    func makeWebView() -> WKWebView {
        let jscript = "var meta = document.createElement('meta'); meta.setAttribute('name', 'viewport'); meta.setAttribute('content', 'width=device-width'); document.getElementsByTagName('head')[0].appendChild(meta);"
        let userScript = WKUserScript(source: jscript, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        let wkUController = WKUserContentController()
        wkUController.addUserScript(userScript)
        let wkWebConfig = WKWebViewConfiguration()
        wkWebConfig.userContentController = wkUController
        
        let webView = WKWebView(frame: CGRect.zero, configuration: wkWebConfig)
        webView.autoresizingMask = [.flexibleTopMargin, .flexibleWidth, .flexibleHeight, .flexibleLeftMargin, .flexibleRightMargin, .flexibleBottomMargin]
        
        webView.scrollView.maximumZoomScale = 1.5
        return webView
    }
    
    // MARK: - WKWebView related methods
    
    func registerWebviewDidChangeSizeObserve() {
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.isLoading), options: .new, context: nil)
        webView.scrollView.delegate = self
    }
    
    func removeWebviewDidChangeSizeObserve() {
        self.removeObserver(self.webView, forKeyPath: #keyPath(WKWebView.isLoading))
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if object is WKWebView {
            print("change", change!)
//            print("web.isLoading", self.webView.isLoading)
//            print("wk.size = \(self.webView.scrollView.contentSize)")
            guard let newValue = change?[.newKey] else { return }
            guard let isLoading = newValue as? Bool else { return }
            guard isLoading == false else { return }
            webView.evaluateJavaScript("document.body.scrollHeight", completionHandler: { [weak self] (value, error) in
                if let value = value as? CGFloat {
                    print("value", value)
                    self?.reloadBodyCell(height: value)
                }
            })
            
        }
    }
    
    override func scrollViewDidZoom(_ scrollView: UIScrollView) {
        if scrollView == self.webView.scrollView {
            self.reloadBodyCell(height: self.bodyCellHeight)
        }
    }
    
    var bodyCellHeight: CGFloat = 0.0
    private func reloadBodyCell(height: CGFloat) {
        self.bodyCellHeight = height
        self.tableView.reloadSections(IndexSet(integer: 2), with: .none)
    }
    
    // MARK - Private methods
    
    private func loadText(_ text: MailPart) {
        guard let html = text.decodedText else { return }
        self.webView.loadHTMLString(html, baseURL: nil)
        self.webView.scrollView.showsVerticalScrollIndicator = false
        
    }
    
    private func downloadData(with body: MailPart, completion: @escaping (Error?)->()) {
        let uid = self.message.uid
    
        self.sessionController.command({ (imap) in
            for part in body.singleParts ({ ($0.isText == true && $0.id == self.textPart.id) || $0.isInline == true }) {
                guard part.hasData == false else {
                    continue
                }
            
                _ = imap.fetchData(uid: uid, partId: part.id, completion: { (data) in
        
                    self.message.body![part.id]?.data = data
                    
                    if part.id == self.textPart.id {
                        self.textPart = self.message.body![part.id]
                    }
                    
                })
            }
            
            OperationQueue.main.addOperation {
                completion(nil)
            }
        }) { (_) in
//            OperationQueue.main.addOperation {
//                completion(error)
//            }
        }
    }
    

    // MARK: - Table view data source
    enum Section: Int {
        case subject
        case from
        case body
        
        static var count: Int = 3
        init(_ section: Int) {
            switch section {
            case 0:
                self = .subject
            case 1:
                self = .from
            case 2:
                self = .body
            default:
                fatalError()
            }
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return Section.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return 1
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch Section(indexPath.section) {
        case .subject:
            return MessageDetailSubjectCell.cellHeight(withSubject: self.message.header!.subject, maxWidth: self.view.bounds.width)
        case .from:
            return MessageDetailFromCell.cellHeight()
        case .body:
            let minimumHeight = self.view.bounds.size.height - MessageDetailSubjectCell.cellHeight(withSubject: self.message.header!.subject, maxWidth: self.view.bounds.width) - MessageDetailFromCell.cellHeight()
            
            /*
            if self.textPart.hasData == true && self.webView.scrollView.contentSize.height >= minimumHeight {
                return self.webView.scrollView.contentSize.height
                
                
            } else {
                return minimumHeight
            }
 */
            if self.textPart.hasData == true {
                // todo: 縦横比率を考慮して、+ or - の増加分heightを上げる。
                let viewRatio = self.view.frame.size.width / self.bodyCellHeight
                let heigh = self.bodyCellHeight * self.webView.scrollView.zoomScale * viewRatio
                print("cellHeigh", heigh)
                if heigh > minimumHeight {
                    return heigh
                } else {
                    return minimumHeight
                }
                
            } else {
                return minimumHeight
            }
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(indexPath.section) {
        case .subject:
            let cell = tableView.dequeueReusableCell(withIdentifier: "MessageDetailSubjectCell", for: indexPath) as! MessageDetailSubjectCell
            cell.ibSubjectLabel.text = self.message.header?.subject
            return cell
            
        case .from:
            let cell = tableView.dequeueReusableCell(withIdentifier: "MessageDetailFromCell", for: indexPath) as! MessageDetailFromCell
            cell.ibFromLabel.text = self.message.header?.from.first?.preferedDisplayName
            return cell
        case .body:
            let cell = tableView.dequeueReusableCell(withIdentifier: "MessageDetailBodyCell", for: indexPath) as! MessageDetailBodyCell
            
            if cell.subviews.contains(self.webView) == false {
                self.webView.frame = cell.bounds
                cell.addSubview(self.webView)
                
                // handles changing webView size.
                self.registerWebviewDidChangeSizeObserve()
            }
            return cell
        }
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

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
