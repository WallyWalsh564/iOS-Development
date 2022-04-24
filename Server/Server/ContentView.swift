//
//  ContentView.swift
//  Server
//
//  Created by Michael on 2022-02-24.
//

import SwiftUI

///Grid setup for LazyVSTack to display the game board
class gameGrid: ObservableObject {
    @Published var columnsForGame = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
        ]
    @Published var boardChars : [String] = Array(repeating:"", count: 100)
    init() { }
}

struct ContentView: View {
    ///Instance of gameGrid class
    @EnvironmentObject var gamesGrid : gameGrid
    /// Called when reset button is pressed, this resets the games stats to allow for multiple games, in theory....
    func resetGame() {
        statusMessage = "Waiting for first guess"
        networkSupport.resetGame()
    }
    @State var advertising = false
    @StateObject var networkSupport = NetworkSupport(browse: false)
    ///Status message updated as players make moves
    @State var statusMessage = "Waiting for first guess"
    var body: some View {
        
        VStack {
            if !advertising {
                Button("Start") {
                    networkSupport.getTreasure()
                    networkSupport.nearbyServiceAdvertiser?.startAdvertisingPeer()
                    advertising.toggle()
                }
            }
            else {
                if !networkSupport.gameOver {
                    if networkSupport.connected {
                        //Waits for 2 peers to connect before starting game
                        if networkSupport.peers.count < 2 {
                            Text ("Waiting for players to connect")
                                
                        }
                        else {//Display gameboard.  Hearts are shown for the treasure locations and are removed once found
                            LazyVGrid(columns: gamesGrid.columnsForGame, spacing: 10){
                                ForEach ((0...9), id:\.self){ i in
                                    ForEach((0...9), id:\.self) { j in
                                        let index : String = i == 0 ? String("\(j)") : String("\(i)\(j)")
                                        if networkSupport.treasureLocations.contains(index) {
                                            Image(systemName: "heart")
                                        }
                                        else {
                                            Text(index)
                                        }
                                    }
                                }
                            }
                            Text ("\(statusMessage)")
                                .onChange(of: networkSupport.incomingMessage) { newValue in
                                    statusMessage = "Player \(String(networkSupport.currPlayer + 1)) has guessed \(networkSupport.incomingMessage)"
                                }
                                .accessibilityIdentifier("StatusBox")
                            Text("Player 1 Score: \(String(networkSupport.playerscores[0])) \t\t\t Player 2 Score \(String(networkSupport.playerscores[1]))")
                                .padding()
                        }
                    }
                }
                else {
                    ///Display after the game has been completed
                    let winner = networkSupport.playerscores[0] > networkSupport.playerscores[1] ? "1" : "2"
                    Text("Game Over.  Player \(winner) Wins")
                    Button("Reset Game", action: {resetGame()})
                }

                
                Button("Stop") {
                    networkSupport.nearbyServiceAdvertiser?.stopAdvertisingPeer()
                    advertising.toggle()
                }
                .padding()
            }
        }
        //.padding()
    }
   
    
}
