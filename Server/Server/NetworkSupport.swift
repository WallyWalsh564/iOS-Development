//
//  NetworkSupport.swift
//  Server
//
//  Created by Michael on 2022-02-24.
//

import Foundation
import MultipeerConnectivity
import os

/// Uniquely identifies the service.
/// Make this unique to avoid interfering with other Multipeer services.
/// Don't forget to update the project Info AND the project Info.plist property lists accordingly.
let serviceType = "ChrisNMike"




/// Preset characters to communicate the results of the previous users guess
let wrongGuess = "O"
let correctGuess = "!"
let gameOverSymbol = "X"


/// This structure is used at setup time to identify client needs to a server.
/// Currently, it only contains an identifying message, but this can be expanded to contain version information and other data.
struct Request: Codable {
    /// An identifying message that is to be transmitted.
    var details: String
}

/// This class deals with matters relating to setting up Server and Client Multipeer services.
class NetworkSupport: NSObject, ObservableObject, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate, MCSessionDelegate {
    /// The local peer identifier
    private var peerID: MCPeerID
    
    /// The current session
    private var session: MCSession
    
    /// For a server, this allows access to the MCNearbyServiceAdvertiser; nil otherwise.
    var nearbyServiceAdvertiser: MCNearbyServiceAdvertiser?
    
    /// For a client, this allows access to the MCNearbyServiceBrowser; nil otherwise.
    var nearbyServiceBrowser: MCNearbyServiceBrowser?
    
    /// Contains the list of connected peers.  Used by the client.
    @Published var peers: [MCPeerID] = [MCPeerID]()
    
    /// True if connected to a peer, false otherwise.
    @Published var connected = false
    
    /// Contains the most recent incoming message.
    @Published var incomingMessage = ""
    /// Contains player scores
    @Published var playerscores: [Int] = Array(repeating: 0, count: 2)
    /// Boolean to track if game is still going
    var gameOver = false
    /// Tracks player who is currently allowed to guess
    var currPlayer: Int = 0
    /// List of treasure locations
    var treasureLocations: [String] = Array(repeating: String(arc4random() % 99), count: 1)
    /// Triggered by ContentView's resetGame() method, restores all variables to default, creates new Treasure List
    func resetGame() {
        self.gameOver = false
        self.currPlayer = 0
        self.playerscores = Array(repeating: 0, count: 2)
        getTreasure()
        
    }
    
    
    /// Generates list of locations treasure is stored at.
    func getTreasure() {
        while treasureLocations.count < 5 {
            let newTreasure = arc4random() % 99
            if !treasureLocations.contains(String(newTreasure)) {
                treasureLocations.append(String(newTreasure))
            }
        }
        dump(treasureLocations)
    }
    
    
    /// Evaluates a given coordinate and determines if the location contains a treasure
    /// - Parameter userGuess: Coordinates given by the client
    /// - Returns: true if the location contains treasure, false otherwise
    func evaluateLocation(userGuess: String) -> Bool {

        if treasureLocations.contains(userGuess) {
            treasureLocations = treasureLocations.filter {$0 != userGuess}
            if treasureLocations.isEmpty {
                gameOver.toggle()
            }
            return true
        }
        else {
            return false
        }
    }
    
    /// Create a Multipeer Server or Client
    /// - Parameter browse: true creates a Client, false creates a Server
    init(browse: Bool) {
        peerID = MCPeerID(displayName: "ChrisNMike")
        session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .none)
        if !browse {
            nearbyServiceAdvertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: serviceType)
        }
        else {
            nearbyServiceBrowser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)
        }
        
        super.init()
        
        session.delegate = self
        nearbyServiceAdvertiser?.delegate = self
        nearbyServiceBrowser?.delegate = self
        
        if browse {
            nearbyServiceBrowser?.startBrowsingForPeers()
        }
    }
    
    // MARK: - MCNearbyServiceAdvertiserDelegate Methods. See XCode documentation for details.
    
    /// Inherited from MCNearbyServiceAdvertiserDelegate.advertiser(_:didNotStartAdvertisingPeer:).
    /// Currently only logs.
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        os_log("didNotStartAdvertisingPeer \(error.localizedDescription)")
    }
    
    /// Inherited from MCNearbyServiceAdvertiserDelegate.advertiser(_:didReceiveInvitationFromPeer:withContext:invitationHandler:).
    /// Right now, all connection requests are accepted.
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        do {
            let request = try JSONDecoder().decode(Request.self, from: context ?? Data())
            os_log("didReceiveInvitationFromPeer \(peerID.displayName) \(request.details)")
            
            invitationHandler(true, self.session)
        }
        catch let error {
            os_log("didReceiveInvitationFromPeer \(error.localizedDescription)")
        }
    }
    
    // MARK: - MCNearbyServiceBrowserDelegate Methods. See XCode documentation for details.
    
    /// Adds the given peer to the peers array.
    /// - Parameter peer: The peer to be added.
    private func addPeer(peer: MCPeerID) {
        DispatchQueue.main.async {
            if !self.peers.contains(peer) {
                os_log("addPeer")
                self.peers.append(peer)
            }
        }
    }
    
    /// Removes the given peer from the peers array, if possible.
    /// - Parameter peer: The peer to be removed.
    private func removePeer(peer: MCPeerID) {
        DispatchQueue.main.async {
            guard let index = self.peers.firstIndex(of: peer) else {
                return
            }
            os_log("removePeer")
            self.peers.remove(at: index)
        }
    }
    
    /// Inherited from MCNearbyServiceBrowserDelegate.browser(_:didNotStartBrowsingForPeers:).
    /// Currently only logs.
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        os_log("didNotStartBrowsingForPeers \(error.localizedDescription)")
    }
    
    /// Inherited from MCNearbyServiceBrowserDelegate.browser(_:foundPeer:withDiscoveryInfo:).
    /// Updates the peers array with the newly-found peerID.
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        let info2 = info?.description ?? ""
        os_log("foundPeer \(peerID) \(info2)")
        addPeer(peer: peerID)
    }
    
    /// Inherited from MCNearbyServiceBrowserDelegate.browser(_:lostPeer:).
    /// Removes the lost peerID from the peers array and updates connected status.
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        os_log("lostPeer \(peerID)")
        removePeer(peer: peerID)
        DispatchQueue.main.async {
            self.connected = false
        }
    }
    
    // MARK: - Client Setup Method
    
    /// Establish a session with a server.
    /// - Parameters:
    ///   - peerID: The peer ID of the server.
    ///   - request: The connection request.  This can contain additional information that can be used by a server to accept or reject a connection.
    func contactPeer(peerID: MCPeerID, request: Request) throws {
        os_log("contactPeer \(peerID) \(request.details)")
        let request = try JSONEncoder().encode(request)
        nearbyServiceBrowser?.invitePeer(peerID, to: session, withContext: request, timeout: TimeInterval(120))
    }
    
    // MARK: - MCSessionDelegate Methods. See XCode documentation for details.
    
    /// Inherited from MCSessionDelegate.session(_:didReceive:fromPeer:).
    /// Updates incomingMessage with the message that was just received
    /// CHANGES MADE:
    /// This method has been modified from the original version given.  The message received from the client is checked against the array of treasure locations.  The message sent back contains (A)a character to denote whether a treasure was found or not OR if the game is now ended (B) the current score for both users and (C) the last message received(last guess).  This reply is sent back to the clients.
    func session(_ session: MCSession, didReceive: Data, fromPeer: MCPeerID) {
        do {
            var request = try JSONDecoder().decode(String.self, from: didReceive)
            os_log("didReceive \(request) \(fromPeer)")
            DispatchQueue.main.async {
                //dump(treasureLocations)
                self.incomingMessage = request
                if self.peers[self.currPlayer] == fromPeer {
                    if request.prefix(1) == "0" {
                        request.removeFirst()
                    }
                    if self.evaluateLocation(userGuess: request) {
                        self.playerscores[self.currPlayer] += 1
                        if self.currPlayer == 0 { //Used to enforce turns for the players
                            self.currPlayer = 1
                        }
                        else {
                            self.currPlayer = 0
                        }
                        if self.gameOver {
                            /// If game has ended, sends final message
                            self.send(message: "\(gameOverSymbol)\(self.playerscores[0])\(self.playerscores[1])\(self.incomingMessage)")

                        }
                        else { ///Sent to clients if user's guess was correct
                            self.send(message: "\(correctGuess)\(self.playerscores[0])\(self.playerscores[1])\(self.incomingMessage)")
                        }
                    }
                    else { ///sent to clients if users guess was incorrect
                        self.send(message: "\(wrongGuess)\(self.playerscores[0])\(self.playerscores[1])\(self.incomingMessage)")
                        if self.currPlayer == 0 {
                            self.currPlayer = 1
                        }
                        else {
                            self.currPlayer = 0
                        }
                    }
                }
            }
        }
        catch let error {
            os_log("didReceive \(error.localizedDescription)")
        }
    }
    
    /// Inherited from MCSessionDelegate.session(_:didStartReceivingResourceWithName:fromPeer:with:).
    /// Currently only logs.
    func session(_ session: MCSession, didStartReceivingResourceWithName: String, fromPeer: MCPeerID, with: Progress) {
        os_log("didStartReceivingResourceWithName \(didStartReceivingResourceWithName) \(fromPeer) \(with)")
    }
    
    /// Inherited from MCSessionDelegate.session(_:didFinishReceivingResourceWithName:fromPeer:at:withError:).
    /// Currently only logs.
    func session(_ session: MCSession, didFinishReceivingResourceWithName: String, fromPeer: MCPeerID, at: URL?, withError: Error?) {
        let at2 = at?.description ?? ""
        let withError2 = withError?.localizedDescription ?? ""
        os_log("didFinishReceivingResourceWithName \(didFinishReceivingResourceWithName) \(fromPeer) \(at2) \(withError2)")
    }
    
    /// Inherited from MCSessionDelegate.session(_:didReceive:withName:fromPeer:).
    /// Currently only logs.
    func session(_ session: MCSession, didReceive: InputStream, withName: String, fromPeer: MCPeerID) {
        os_log("didReceive:withName \(didReceive) \(withName) \(fromPeer)")
    }
    
    /// Inherited from MCSessionDelegate.session(_:peer:didChange:).
    /// Updates the connected state.
    func session(_ session: MCSession, peer: MCPeerID, didChange: MCSessionState) {
        switch didChange {
        case .notConnected:
            os_log("didChange notConnected \(peer)")
            removePeer(peer: peer)
            DispatchQueue.main.async {
                self.connected = false
            }
        case .connecting:
            os_log("didChange connecting \(peer)")
            DispatchQueue.main.async {
                self.connected = false
            }
        case .connected:
            os_log("didChange connected \(peer)")
            addPeer(peer: peer)
            DispatchQueue.main.async {
                self.connected = true
            }
        default:
            os_log("didChange \(peer)")
            DispatchQueue.main.async {
                self.connected = false
            }
        }
    }
    
    /// Inherited from MCSessionDelegate.session(_:didReceiveCertificate:fromPeer:certificateHandler:).
    /// Currently accepts all certificates.
    func session(_ session: MCSession, didReceiveCertificate: [Any]?, fromPeer: MCPeerID, certificateHandler: (Bool) -> Void) {
        let didReceiveCertificate2 = didReceiveCertificate?.description ?? ""
        os_log("didReceiveCertificate \(didReceiveCertificate2) \(fromPeer)")
        certificateHandler(true)
    }
    
    // MARK: - Data Transmission Method
    
    /// Sends a message to all registered peers.  Used by the client.
    /// - Parameter message: The message that is to be transmitted.
    func send(message: String) {
        do {
            let data = try JSONEncoder().encode(message)
            try session.send(data, toPeers: peers, with: .reliable)
            os_log("send \(message)")
        }
        catch let error {
            os_log("send \(error.localizedDescription)")
        }
    }
    
   
    
    // MARK: - Cleanup
    
    deinit {
        os_log("deinit")
        nearbyServiceBrowser?.stopBrowsingForPeers()
    }
}
