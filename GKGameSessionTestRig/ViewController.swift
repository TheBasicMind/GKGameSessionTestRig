//
//  ViewController.swift
//  GKGameSessionTestRig
//
//  Created by Paul Lancefield on 15/12/2017.
//  Copyright © 2017 Paul Lancefield. All rights reserved.
//

import UIKit
import GameKit
import MessageUI

extension ViewController: MFMessageComposeViewControllerDelegate {
    func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
        controller.dismiss(animated: true, completion: nil)
        switch result {
        case .cancelled, .failed:
            /// TODO: Should be optimised to ask again
            navigationController?.popViewController(animated: true)
        case .sent:
            // The successful case
            // we do nothing because
            // now the gameState object
            // is listinging for changes
            // to the game session state
            break
        }
    }
}

class ViewController: UIViewController {

    @IBOutlet var manuallyJoinGameButton: UIButton?
    @IBOutlet var textView: UITextView?
    var signedInPlayer: GKCloudPlayer?
    var session: GKGameSession?
    var sessions: [GKGameSession]?
    var sessionsAndData: [GKGameSession:GameData] = [:]
    var inviteURL: URL?
    var gameData: GameData?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        GKGameSession.add(listener: self)
        manuallyJoinGameButton?.isEnabled = !GKGameSessionRigBools.joinAtStartUp
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func printError(_ error: GKGameSessionError) {
        myDebugPrint("Error = \(error)")
    }
    
    @IBAction func getSignedInPlayer(_ sender: Any) {
        GKCloudPlayer.getCurrentSignedInPlayer(forContainer: GKGameSessionRigStrings.cloudKitContainer) { [weak self] (cloudKitPlayer, error) in
            if let cloudKitPlayer = cloudKitPlayer {
                self?.signedInPlayer = cloudKitPlayer
                myDebugPrint("******** Got current signed in player")
                myDebugPrint("             Player Name: \(cloudKitPlayer.displayName ?? "Null")")
                myDebugPrint("             with player ID: \(cloudKitPlayer.playerID?.strHash() ?? "Null")")
            } else {
                if let error = error as? GKGameSessionError {
                    self?.printError(error)
                }
            }
            
        }
    }
    
    @IBAction func logSignedInPlayer(_ sender: Any) {
        guard let signedInPlayer = signedInPlayer else {
            myDebugPrint("Error: Player must be signed in before we can log the player object's properties")
            return
        }
        myDebugPrint("******** Signed in player display name = \(signedInPlayer.displayName ?? "Null")")
        myDebugPrint("         Signed in player, playerID = \(signedInPlayer.playerID?.strHash() ?? "Null")")
        if let badgedPlayers = session?.badgedPlayers {
            var badgedPlayer: GKCloudPlayer? = nil
            for player in badgedPlayers {
                if player.playerID == signedInPlayer.playerID {
                    badgedPlayer = player
                }
            }
            if badgedPlayer != nil {
                myDebugPrint("         signed in player is badged \(signedInPlayer.playerID?.strHash() ?? "Null")")
            } else {
                myDebugPrint("         signed in player is not badged")
            }
        }
    }
    
    @IBAction func listSessions(_ sender: Any) {
        GKGameSession.loadSessions(inContainer: GKGameSessionRigStrings.cloudKitContainer) {
            [weak self] (retreivedSessions, error) in
            if let error = error as? GKGameSessionError {
                self?.printError(error)
                return
            }
            myDebugPrint("******** Got sessions, count = \(retreivedSessions?.count ?? 0)")
            
            self?.sessions = retreivedSessions
            guard let retreivedSessions = retreivedSessions else { return }
            for gameSession in retreivedSessions {
                gameSession.loadGameData  {
                    [weak self] (gameData, error) in
                    if let error = error as? GKGameSessionError {
                        self?.printError(error)
                    } else {
                        if let gameData = gameData {
                            myDebugPrint("    ******** Got data for session, \(gameData.someString)")
                            self?.sessionsAndData[gameSession] = gameData
                        }
                    }
                }
            }
            self?.session = retreivedSessions.last
        }
    }
    
    @IBAction func createSession(_ sender: Any) {
        GKGameSession.createSession(inContainer: GKGameSessionRigStrings.cloudKitContainer, withTitle: "Wabble Two Player Owned by \(signedInPlayer?.displayName ?? "Null"), id: \(signedInPlayer?.playerID?.strHash() ?? "Null")", maxConnectedPlayers: 2) {
            [weak self] (gameSession, error) in
            if let error = error as? GKGameSessionError {
                self?.printError(error)
            } else {
                myDebugPrint("******** Created session: \(gameSession?.title ?? "No title defined")")
                myDebugPrint("    ******** Session owner: \(gameSession?.owner.displayName ?? "Null")")
                myDebugPrint("    ******** Session owner ID: \(gameSession?.owner.playerID?.strHash() ?? "Null")")
                self?.session = gameSession
            }
        }
    }
    
    @IBAction func logSession(_ sender: Any) {
        guard let session = session else {
            myDebugPrint("No session assigned to session property as yet.")
            return
        }
        myDebugPrint("--------------")
        myDebugPrint("Session Title: \(session.title)")
        myDebugPrint("Session owner: \(session.owner.displayName ?? "Null"), id: \(session.owner.playerID?.strHash() ?? "Null")")
        myDebugPrint("List of Session players:")
        if session.players.count == 0 {
            myDebugPrint("none")
        }
        for (i, player) in session.players.enumerated() {
            myDebugPrint("    Player number: \(i), name: \(player.displayName ?? "Null"), id: \(player.playerID?.strHash() ?? "Null")")
        }
        myDebugPrint("--------------")
    }
    
    func saveData(contentString: String) {
        guard let session = session else {
            myDebugPrint("Error: Session must be set-up and cached before we can save data")
            return
        }

        let myData = GameData(someString: contentString)
        session.saveGameData(myData) {
            [weak self] (data, error) in
            if let error = error as? GKGameSessionError {
                self?.printError(error)
            } else {
                if let data = data {
                    myDebugPrint("Conflict: data already saved with someString: \(data.someString)")
                } else {
                    myDebugPrint("******** Saved data with someString: \(myData.someString)")
                    self?.sessionsAndData[session] = myData
                }
            }
        }
    }
    
    @IBAction func saveDataToSession(_ sender: Any) {
        saveData(contentString: "Data \"Ice Cream\", saved by player: \(signedInPlayer?.displayName ?? "Null"), id: \(signedInPlayer?.playerID?.strHash() ?? "Null")")
    }
    
    @IBAction func saveDataToSession2(_ sender: Any) {
        saveData(contentString: "Data \"Apples\", saved by player: \(signedInPlayer?.displayName ?? "Null"), id: \(signedInPlayer?.playerID?.strHash() ?? "Null")")
    }
    
    @IBAction func getSharingURL(_ sender: Any) {
        if let gameSession = session {
            gameSession.getShareURL {
                [weak self] (url, error) in
                guard let url = url else {
                    if let error = error as? GKGameSessionError {
                        self?.printError(error)
                        
                    } else if let error = error {
                        myDebugPrint("Error not accounted for: \(error)")
                    }
                    return
                }
                
                let encodedChallengeURL = url.absoluteString.addingPercentEncoding(withAllowedCharacters:.urlHostAllowed)
                let nestedURLString = GKGameSessionRigStrings.openWabbleForPlayerChallenge + encodedChallengeURL!
                let nestedURL = URL(string: nestedURLString)!
                self?.inviteURL = nestedURL
                self?.inviteOpponent(withSharingURL: nestedURL)
                myDebugPrint("******** Retreived share URL: \(url)")
                myDebugPrint("Retreived encoded URL: \(nestedURL)")
            }
        }
    }
    
    private func inviteOpponent(withSharingURL url: URL) {
        guard MFMessageComposeViewController.canSendText() else { return }
        let composeVC = MFMessageComposeViewController()
        composeVC.messageComposeDelegate = self
        let bodyText = NSLocalizedString("Hey, would you like to join me for a game? ", comment: "")
        composeVC.body = bodyText + "\(url)"
        self.present(composeVC, animated: true, completion: nil)
    }
    
    @IBAction func loadDataForSession(_ sender: Any) {
        session?.loadGameData  {
            [weak self] (gameData, error) in
            if let error = error as? GKGameSessionError {
                self?.printError(error)
            } else {
                if let gameData = gameData {
                    myDebugPrint("******** Retreived session data with someString: \(gameData.someString)")
                    self?.gameData = gameData
                    self?.sessionsAndData[self!.session!] = gameData
                } else {
                    myDebugPrint("Request to iCloud returned nothing. No data has been saved.")
                }
            }
        }
    }
    
    @IBAction func logSessionData(_ sender: Any) {
        myDebugPrint("Session data someString: \(gameData?.someString ?? "No string or game data")")
    }
    
    @IBAction func deleteSessions(_ sender: Any) {
        guard let sessions = sessions else {
            myDebugPrint("Must have some sessions if we are going to try to delete them. Press \"List Sessions.\"")
            return
        }
        
        guard sessions.count > 0 else {
            myDebugPrint("No sessions to delete.")
            return
        }
        
        var tempSessions = sessions

        for (index, session) in sessions.reversed().enumerated() {
            GKGameSession.remove(withIdentifier: session.identifier) {
                [weak self] (error) in
                if let error = error as? GKGameSessionError {
                    self?.printError(error)
                } else {
                    tempSessions.remove(at: sessions.count - index - 1)
                    myDebugPrint("******** Deleted session")
                }
                if index == sessions.count - 1 {
                    self?.sessions = tempSessions
                    self?.sessionsAndData.removeValue(forKey: session)
                }
            }
        }
        
    }
    
    @IBAction func manuallyJoin(_ sender: Any) {
        if let delegate = UIApplication.shared.delegate as? AppDelegate {
            delegate.joinGame()
        }
    }
    
    @IBAction func messageOpponent(_ sender: Any) {
        guard let signedInPlayer = signedInPlayer else {
            myDebugPrint("Error: Player must be signed in before we can message opponents")
            return
        }
        guard let session = session else {
            myDebugPrint("Error: Session must be set-up and cached before we can message an opponent")
            return
        }
        guard session.players.count > 1 else {
            myDebugPrint("Error: The session player count must be greater than one before we can send a messsage")
            return
        }
        var playersToMessage: [GKCloudPlayer] = []
        for player in session.players {
            if player.playerID != signedInPlayer.playerID {
                playersToMessage.append(player)
            }
        }
        let message = "Hi, this is a message"
        session.sendMessage(withLocalizedFormatKey: message, arguments: [], data: nil, to: playersToMessage, badgePlayers: true) {
            (error) in
            if let error = error {
                print(error)
            } else {
                myDebugPrint("******** Message successfully sent. Message content: \(message)")
            }
        }
        
    }
    
    @IBAction func clearBadge(_ sender: Any) {
        guard let signedInPlayer = signedInPlayer else {
            myDebugPrint("Error: Player must be signed in before we can message opponents")
            return
        }
        guard let session = session else {
            myDebugPrint("Error: Session must be set-up and cached before we can message an opponent")
            return
        }
        session.clearBadge(for: [signedInPlayer]) {
            (error) in
            if let error = error {
                print(error)
            } else {
                myDebugPrint("******** Local player \(signedInPlayer.playerID?.strHash() ?? "Null"), badge removed")
            }
        }
    }
}

extension ViewController: GKGameSessionEventListener {
    public func session(_ session: GKGameSession, didAdd player: GKCloudPlayer) {
        //self.session = session
        myDebugPrint("###### Session: \(session.title), Did add player: \(String(describing: player.displayName)), id: \(player.playerID?.strHash() ?? "Null")")
    }
    
    public func session(_ session: GKGameSession, didRemove player: GKCloudPlayer) {
        //self.session = session
        myDebugPrint("###### Did remove player: \(player.displayName ?? "Null")")
        myDebugPrint("Session owner: \(session.owner.displayName ?? "Null")")
    }
    
    public func session(_ session: GKGameSession, player: GKCloudPlayer, didChange newState: GKConnectionState) {
        //self.session = session
        myDebugPrint("###### Player: \(player.displayName ?? "Name is Null"), did change connection state: \(newState.rawValue)")
    }
    
    public func session(_ session: GKGameSession, player: GKCloudPlayer, didSave data: Data) {
        //self.session = session
        let decoder = JSONDecoder()
        let gameData: GameData
        do {
            gameData = try decoder.decodeApiVersion(GameData.self, from: data)
        } catch {
            myDebugPrint("Error: Could not decode gamedata from network data")
            return
        }
        myDebugPrint("###### Player: \(player.displayName ?? "Name is Null"), id: \(player.playerID?.strHash() ?? "Null"), did save data: \(gameData.someString)")
    }
    
    public func session(_ session: GKGameSession, didReceive data: Data, from player: GKCloudPlayer) {
        //self.session = session

    }
    
    public func session(_ session: GKGameSession, didReceiveMessage message: String, with data: Data, from player: GKCloudPlayer) {
        //self.session = session
        myDebugPrint("Message received from player: \(player)")
        myDebugPrint(message)
    }
}

