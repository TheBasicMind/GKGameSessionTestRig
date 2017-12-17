//
//  ViewController.swift
//  GKGameSessionTestRig
//
//  Created by Paul Lancefield on 15/12/2017.
//  Copyright © 2017 Paul Lancefield. All rights reserved.
//

import UIKit
import GameKit

let WCloudKitContainer                  = "iCloud.radicalfraction.GKGameSessionTestRig"
let openWabbleForPlayerChallenge        = "newOWTestGameRequest://?token="

enum APIError: Error {
    case doesNotMatchVersion(currentVersion: Int, storedVersion: Int)
}

// Change this value when a new version
// of your encoding and decoding API is
// published.
let apiVersionNo = 1

struct APIData<T: Codable>: Codable {
    let apiVersion: Int
    let apiData: T
    
    enum CodingKeys: String, CodingKey {
        case apiVersion = "apiVersion"
        case apiData = "apiData"
    }
    
    init(versionNumber: Int, apiData: T) {
        self.apiVersion = versionNumber
        self.apiData = apiData
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let apiVersion = try container.decode(Int.self, forKey: .apiVersion)
        if apiVersion != apiVersionNo { throw APIError.doesNotMatchVersion(currentVersion: apiVersionNo, storedVersion: apiVersion) }
        let apiData = try container.decode(T.self, forKey: .apiData)
        self.apiVersion = apiVersion
        self.apiData = apiData
    }
}

extension JSONEncoder {
    open func encodeApiVersion<T>(_ value: T) throws -> Data where T : Codable {
        let wrappedData = APIData(versionNumber: apiVersionNo, apiData: value)
        let data = try self.encode(wrappedData)
        return data
    }
}

extension JSONDecoder {
    open func decodeApiVersion<T>(_ type: T.Type, from data: Data) throws -> T where T : Codable {
        let wrappedData: APIData = try decode(APIData<T>.self, from: data)
        let data = wrappedData.apiData
        return data
    }
}

struct GameData: Codable {
    let someString: String
}
/**
 Abstracted for testing and dependency inversion
 */
protocol OWGameSession {
    var identifier: String { get }
    var title: String { get }
    var owOwner: OWCloudPlayer { get }
    var owPlayers: [OWCloudPlayer] { get }
    var lastModifiedDate: Date { get }
    var lastModifiedOWPlayer: OWCloudPlayer { get }
    var maxNumberOfConnectedPlayers: Int { get }
    var badgedOWPlayers: [OWCloudPlayer] { get }
    func owPlayers(with state: GKConnectionState) -> [OWCloudPlayer]
    func save(_ gameData: GameData, completionHandler: @escaping (GameData?, Error?) -> Swift.Void)
    func testPlayerOrder(ownerID: String, gameData: GameData)
    func loadWabbleData(completionHandler: @escaping (GameData?, Error?) -> Void)
}

protocol OWCloudPlayer {
    var playerID: String? { get }
    var displayName: String? { get }
}

extension GKCloudPlayer: OWCloudPlayer { }

extension GKGameSession: OWGameSession {
    func testPlayerOrder(ownerID: String, gameData: GameData) {
    }
    
    var owOwner: OWCloudPlayer {
        return owner
    }
    var owPlayers: [OWCloudPlayer] {
        return players
    }
    var lastModifiedOWPlayer: OWCloudPlayer {
        return lastModifiedPlayer
    }
    var badgedOWPlayers: [OWCloudPlayer] {
        return badgedPlayers
    }
    func owPlayers(with state: GKConnectionState) -> [OWCloudPlayer] {
        return players(with: state)
    }
    func save(_ gameData: GameData, completionHandler: @escaping (GameData?, Error?) -> Void) {
        let encoder = JSONEncoder()
        let data: Data
        do {
            data = try encoder.encodeApiVersion(gameData)
        } catch {
            print("error saving API data")
            return
        }
        
        #if DEBUG
            let undata: GameData?
            let decoder = JSONDecoder()
            do {
                undata = try decoder.decodeApiVersion(GameData.self, from: data)
            } catch {
                print("couldn't get GameData from network data")
                return
            }
            if undata != nil {
                print("validated decoding data before saving")
            }
        #endif
        save(data) { (data, error) in
            var gameData: GameData? = nil
            let decoder = JSONDecoder()
            
            if data != nil {
                do {
                    gameData = try decoder.decodeApiVersion(GameData.self, from: data!)
                    print("******** Could not save data, conflict.")
                } catch {
                    
                }
            } else {
                print("******** Data saved.")
            }
            completionHandler(gameData, error)
        }
    }
    
    func loadWabbleData(completionHandler: @escaping (GameData?, Error?) -> Void) {
        loadData { (data, error) in
            if data == nil {
                completionHandler(nil, error)
                return
            }
            let decoder = JSONDecoder()
            let gameData: GameData
            do {
                gameData = try decoder.decodeApiVersion(GameData.self, from: data!)
            } catch let anError {
                print("Error: Could not decode gamedata when loading data")
                completionHandler(nil, anError)
                return
            }
            completionHandler(gameData, error)
        }
    }
}


class ViewController: UIViewController {

    @IBOutlet var manuallyJoinGameButton: UIButton?
    var signedInPlayer: GKCloudPlayer?
    var session: GKGameSession?
    var sessions: [GKGameSession]?
    var sessionsAndData: [GKGameSession:GameData] = [:]
    var inviteURL: URL?
    var gameData: GameData?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        GKGameSession.add(listener: self)
        manuallyJoinGameButton?.isEnabled = !JoinAtStartUp
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func printError(_ error: GKGameSessionError) {
        print("Error = \(error)")
    }
    
    @IBAction func getSignedInPlayer(_ sender: Any) {
        GKCloudPlayer.getCurrentSignedInPlayer(forContainer: WCloudKitContainer) { [weak self] (cloudKitPlayer, error) in
            if let cloudKitPlayer = cloudKitPlayer {
                self?.signedInPlayer = cloudKitPlayer
                print("******** Got current signed in player")
                print("Player Name: \(cloudKitPlayer.displayName ?? "Null")")
                print("with player ID: \(cloudKitPlayer.playerID ?? "Null")")
            } else {
                if let error = error as? GKGameSessionError {
                    self?.printError(error)
                }
            }
            
        }
    }
    
    @IBAction func listSessions(_ sender: Any) {
        GKGameSession.loadSessions(inContainer: WCloudKitContainer) {
            [weak self] (retreivedSessions, error) in
            if let error = error as? GKGameSessionError {
                self?.printError(error)
                return
            }
            print("******** Got sessions, count = \(retreivedSessions?.count ?? 0)")
            
            self?.sessions = retreivedSessions
            guard let retreivedSessions = retreivedSessions else { return }
            for gameSession in retreivedSessions {
                gameSession.loadWabbleData  {
                    [weak self] (gameData, error) in
                    if let error = error as? GKGameSessionError {
                        self?.printError(error)
                    } else {
                        if let gameData = gameData {
                            self?.sessionsAndData[gameSession] = gameData
                        }
                    }
                }
            }
            self?.session = retreivedSessions.last
        }
    }
    
    @IBAction func createSession(_ sender: Any) {
        GKGameSession.createSession(inContainer: WCloudKitContainer, withTitle: "Wabble Two Player Owned by \(signedInPlayer?.displayName ?? "Null")", maxConnectedPlayers: 2) {
            [weak self] (gameSession, error) in
            if let error = error as? GKGameSessionError {
                self?.printError(error)
            } else {
                print("******** Created session: \(gameSession?.title ?? "No title defined")")
                self?.session = gameSession
            }
        }
    }
    
    @IBAction func logSession(_ sender: Any) {
        guard let session = session else {
            print("No session assigned to session property as yet.")
            return
        }
        print("Session Title: \(session.title), \(session.owner.displayName ?? "No display name")")
        print("Session owner: \(session.owner.displayName ?? "Null")")
        print("List of Session players:")
        if session.players.count == 0 {
            print("none")
        }
        for (i, player) in session.players.enumerated() {
            print("    Player number: \(i), name: \(player.displayName ?? "Null")")
        }
    }
    
    func saveData(contentString: String) {
        guard let session = session else {
            print("Error: Session must be set-up and cached before we can save data")
            return
        }

        let myData = GameData(someString: contentString)
        session.save(myData) {
            [weak self] (data, error) in
            if let error = error as? GKGameSessionError {
                self?.printError(error)
            } else {
                if let data = data {
                    print("Conflict: data already saved with someString: \(data.someString)")
                } else {
                    print("******** Saved data with someString: \(myData.someString)")
                    self?.sessionsAndData[session] = myData
                }
            }
        }
    }
    
    @IBAction func saveDataToSession(_ sender: Any) {
        saveData(contentString: "Data \"Ice Cream\", player: \(signedInPlayer?.displayName ?? "Null")")
    }
    
    @IBAction func saveDataToSession2(_ sender: Any) {
        saveData(contentString: "Data \"Apples\", player: \(signedInPlayer?.displayName ?? "Null")")
    }
    
    @IBAction func getSharingURL(_ sender: Any) {
        if let gameSession = session {
            gameSession.getShareURL {
                [weak self] (url, error) in
                guard let url = url else {
                    if let error = error as? GKGameSessionError {
                        self?.printError(error)
                        
                    } else if let error = error {
                        print("Error not accounted for: \(error)")
                    }
                    return
                }
                
                let encodedChallengeURL = url.absoluteString.addingPercentEncoding(withAllowedCharacters:.urlHostAllowed)
                let nestedURLString = openWabbleForPlayerChallenge + encodedChallengeURL!
                let nestedURL = URL(string: nestedURLString)!
                self?.inviteURL = nestedURL
                print("******** Retreived share URL: \(url)")
                print("Retreived encoded URL: \(nestedURL)")
            }
        }
    }
    
    @IBAction func loadDataForSession(_ sender: Any) {
        session?.loadWabbleData  {
            [weak self] (gameData, error) in
            if let error = error as? GKGameSessionError {
                self?.printError(error)
            } else {
                if let gameData = gameData {
                    print("******** Retreived session data with someString: \(gameData.someString)")
                    self?.gameData = gameData
                    self?.sessionsAndData[self!.session!] = gameData
                } else {
                    print("It appears no data has been saved to this session yet")
                }
            }
        }
    }
    
    @IBAction func logSessionData(_ sender: Any) {
        print("Session data someString: \(gameData?.someString ?? "No string or game data")")
    }
    
    @IBAction func deleteSessions(_ sender: Any) {
        guard let sessions = sessions else {
            print("Must have some sessions if we are going to try to delete them")
            return
        }
        
        guard sessions.count > 0 else {
            print("No sessions to delete.")
            return
        }
        
        var tempSessions = sessions

        for (index, session) in sessions.enumerated() {
            GKGameSession.remove(withIdentifier: session.identifier) {
                [weak self] (error) in
                if let error = error as? GKGameSessionError {
                    self?.printError(error)
                } else {
                    tempSessions.remove(at: index)
                    print ("******** Deleted session")
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
}

extension ViewController: GKGameSessionEventListener {
    public func session(_ session: GKGameSession, didAdd player: GKCloudPlayer) {
        print("####### Session: \(session.title), Did add player: \(String(describing: player.displayName))")
        self.session = session
    }
    
    public func session(_ session: GKGameSession, didRemove player: GKCloudPlayer) {
        print("####### Did remove player: \(player.displayName ?? "Null")")
        print("Session owner: \(session.owner.displayName ?? "Null")")
    }
    
    public func session(_ session: GKGameSession, player: GKCloudPlayer, didChange newState: GKConnectionState) {
        print("####### Player: \(player.displayName ?? "Name is Null"), did change connection stare: \(newState)")
    }
    
    public func session(_  : GKGameSession, player: GKCloudPlayer, didSave data: Data) {
        let decoder = JSONDecoder()
        let gameData: GameData
        do {
            gameData = try decoder.decodeApiVersion(GameData.self, from: data)
        } catch {
            print("Error: Could not decode gamedata from network data")
            return
        }
        print("####### Player: \(player.displayName ?? "Name is Null"), did save data: \(gameData.someString)")
    }
    
    public func session(_ session: GKGameSession, didReceive data: Data, from player: GKCloudPlayer) {
        
    }
    
    public func session(_ session: GKGameSession, didReceiveMessage message: String, with data: Data, from player: GKCloudPlayer) {
        
    }
}

