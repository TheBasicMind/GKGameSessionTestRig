//
//  MiscExtensionsFunctionsConstants.swift
//  GKGameSessionTestRig
//
//  Created by Paul Lancefield on 20/12/2017.
//  Copyright © 2017 Paul Lancefield. All rights reserved.
//

import UIKit
import GameKit


func myDebugPrint(_ string: String) {
    guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
    var newString = appDelegate.debugString
    newString.append("\n\(string)")
    appDelegate.debugString = newString
    appDelegate.updateDebugTextView(newString)
    print(string)
}

let WCloudKitContainer                  = "iCloud.radicalfraction.GKGameSessionTestRig"
let openWabbleForPlayerChallenge        = "newOWTestGameRequest://?token="
let JoinAtStartUp                       = true
let apiVersionNo                        = 1
let shortIDs                            = true

enum APIError: Error {
    case doesNotMatchVersion(currentVersion: Int, storedVersion: Int)
}

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

extension String {
    // Compare short easier to read values when debugging
    func strHash() -> String {
        var result = UInt64 (5381)
        let buf = [UInt8](self.utf8)
        for b in buf {
            result = 127 * (result & 0x00ffffffffffffff) + UInt64(b)
        }
        let resultString = "\(result)"
        return String(resultString.prefix(8))
    }
}

extension GKGameSession {
    
    func saveGameData(_ gameData: GameData, completionHandler: @escaping (GameData?, Error?) -> Void) {
        let encoder = JSONEncoder()
        let data: Data
        do {
            data = try encoder.encodeApiVersion(gameData)
        } catch {
            myDebugPrint("error saving API data")
            return
        }
        
        save(data) { (data, error) in
            var gameData: GameData? = nil
            let decoder = JSONDecoder()
            
            if data != nil {
                do {
                    gameData = try decoder.decodeApiVersion(GameData.self, from: data!)
                } catch {
                    myDebugPrint("******** Error decoding data saved by other player.")
                }
            } else {
                myDebugPrint("******** Data saved.")
            }
            completionHandler(gameData, error)
        }
    }
    
    func loadGameData(completionHandler: @escaping (GameData?, Error?) -> Void) {
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
                myDebugPrint("Error: Could not decode gamedata when loading data")
                completionHandler(nil, anError)
                return
            }
            completionHandler(gameData, error)
        }
    }
}
