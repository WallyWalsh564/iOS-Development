//
//  ServerApp.swift
//  Server
//
//  Created by Michael on 2022-02-24.
//

import SwiftUI

@main
struct ServerApp: App {
    @StateObject var gamesGrid = gameGrid()
    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(gamesGrid)
        }
    }
}
