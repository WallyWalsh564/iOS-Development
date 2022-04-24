//
//  ContentView.swift
//  Client
//
//  Created by Michael on 2022-02-24.
//

import SwiftUI

/// This object is used to create the board and store the variables for the game
/// The columns for grid is used to set the ammount of columns for the display in the UI dictating how many items appear on each row
/// Have used published vars in this class to track player scores, the values of the grid, the game over boolean, and winnning player because storing them in this observable object wil link them to the network support allowing them to be updated when messages are recieved
/// the function restartIt is simply used to reset all the variables in the object, Its implemtation is simple due to the fact it was thrown in just for testing but somehow evolved into a feature
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
    @Published var player1Score = 0
    @Published var player2Score = 0
    @Published var boardChars : [String] = Array(repeating:"", count: 100)
    @Published var gameOver = false
    @Published var winningPlayer = ""
    init(){
    }
    
    func restartIt(){
        self.boardChars = Array(repeating:"", count: 100)
        self.player2Score = 0
        self.player1Score = 0
        self.gameOver = false
    }
}
//PUSH IT

/// Gamesgrid is an environment object passed into content view when the app is started, it is observable so we can update the UI on any changes made to the object
///message is used when connecting the server
///network support is a object used to update, recieve, and send text messages over the network to the server
///State variable outgoingMessage is to enforce
///gamestarted variable is used for the initial load, a button will be clicked linking the gameboard to the network support file and then give the user the available list of servers
struct ContentView: View {
    
    @EnvironmentObject var gamesGrid : gameGrid
    @State var message = ""
    @StateObject var networkSupport = NetworkSupport(browse: true)
    @State var gameStarted = false

    
    
    var body: some View {
        if !gameStarted {
            Button("Find Servers", action: {networkSupport.gamesGrid = gamesGrid; gameStarted = true})
        }else if gameStarted {
            ///Once the game has been started users will be displayed a list of servers to choose from
                VStack {
                    if !networkSupport.connected {
                        TextField("Message", text: $message)
                            .multilineTextAlignment(.center)
                        
                        List ($networkSupport.peers, id: \.self) {
                            $peer in
                            Button(peer.displayName) {
                                do {
                                    try networkSupport.contactPeer(peerID: peer, request: Request(details: message))
                                }
                                catch let error {
                                    print(error)
                                }
                            }
                        }
                    }
                    ///once the user has selected a server from the list the game will actualy begin, displaying the objects of the gamesgrid object
                    ///
                    ///using two loops to iterate over the array of possible objects and creating buttons indexed from the loops
                    ///if the index of the gamesGrid object is empty a button will be displayed with the image of a leaf,
                    /// clicking a leaf button will send a message to the server of the two indexes from the loop
                    ///
                    else  if !gamesGrid.gameOver{
                        LazyVGrid(columns: gamesGrid.columnsForGame, spacing: 10){
                            ForEach ((0...9), id:\.self){ i in
                                ForEach((0...9), id:\.self){j in
                                    let index : String = String("\(i)\(j)")
                                    if gamesGrid.boardChars[Int(index)!] == ""{
                                    Button( action: { networkSupport.send(message: String("\(i)\(j)"))
                                        print(networkSupport.incomingMessage)
                                        networkSupport.incomingMessage = ""
                                    }){
                                        Image(systemName: "leaf.fill").foregroundColor(.green)
                                    }
                                    ///When the server sends a message back to the client (in network support) it will update the gamesgrid array with a string that will represent another image to be displayed
                                    ///Once the array value has changed the image will no longer be displayed as a button,
                                    }else if gamesGrid.boardChars[Int(index)!] == "!"{
                                        Image(systemName: "heart.fill").foregroundColor(.red)
                                    }else if gamesGrid.boardChars[Int(index)!] == "O"{
                                        Image(systemName: "trash.fill").foregroundColor(.blue)
                                    }
                                    else{
                                        Text(gamesGrid.boardChars[Int(index)!])
                                    }
                                }
                            }
                        }
                        ///H stack to display the player score attributes from the gamesgrid object, the values will be updated every message recieved from the server
                        HStack(spacing: 20){
                            Section{
                                Text("PLAYER 1 SCORE:     \(gamesGrid.player1Score)")
                            }    .padding()
                            Divider()
                            Section{
                                Text("PLAYER 2 SCORE:     \(gamesGrid.player2Score)")
                            }    .padding()
                            
                          //  Text(networkSupport.incomingMessage)
                            //    .padding()
                        }.frame(maxHeight: 50)
                        Section{
                            
                        }
                    }else {
                        ///once game over has been decided from the server the grid will disappear and the the winning player will be annouced and reset button displayed
                        Text(gamesGrid.winningPlayer)
                        Button("Reset", action: {gamesGrid.restartIt()})
                    }
                }.padding()
            
            }
        
        }
    }

