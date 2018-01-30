//
//  AppDelegate.swift
//  GKGameSessionTestRig
//
//  Created by Paul Lancefield on 15/12/2017.
//  Copyright © 2017 Paul Lancefield. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var gameURL: URL?
    var debugString: String = ""
    func updateDebugTextView(_ string: String) {
        if let vc = window?.rootViewController as? ViewController {
            vc.textView?.text = string
            vc.textView?.setNeedsLayout()
        }
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        myDebugPrint("[] application:didFinishLaunchingWithOptions")
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
        myDebugPrint("[] applicationWillResignActive")
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        myDebugPrint("[] applicationDidEnterBackground")
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
        myDebugPrint("[] applicationWillEnterForeground")
    }
    
    func joinGame() {
        guard let gameURL = gameURL else {
            myDebugPrint("The share game URL must have been received before a game can be joined")
            return
        }
        if UIApplication.shared.canOpenURL(gameURL) {
            UIApplication.shared.open(gameURL, options: [:]) {
                (success) in
                myDebugPrint("[] Application opened URL to self with success \(success)")
            }
        } else {
            myDebugPrint("Error: Bad Share Game URL")
        }
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
        myDebugPrint("[] application:open:options")
        var success = false
        if let queryString = url.query {
            if let urlStringToken = queryString.removingPercentEncoding {
                let token = "token="
                let startIndex = urlStringToken.startIndex
                let stringRange = startIndex..<urlStringToken.index(startIndex, offsetBy: token.count)
                let urlString = urlStringToken.replacingOccurrences(of: token, with: "", options: .literal, range: stringRange)
                if let url = URL(string: urlString) {
                    gameURL = url
                    if GKGameSessionRigBools.joinAtStartUp {
                        joinGame()
                        success = true
                    }
                }
            }
        }
        return success
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        myDebugPrint("[] applicationDidBecomeActive")
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        myDebugPrint("[] applicationWillTerminate")
    }
}

