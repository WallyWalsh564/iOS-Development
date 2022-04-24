//
//  ClientApp.swift
//  Client
//
//  Created by Michael on 2022-02-24.
//

import SwiftUI

@main
struct ClientApp: App {
    @StateObject var gamesGrid = gameGrid()
    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(gamesGrid)
        }
    }
}
