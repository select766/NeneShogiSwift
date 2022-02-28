//
//  ContentView.swift
//  NeneShogiSwift
//
//  Created by Masatoshi Hidaka on 2022/02/13.
//

import SwiftUI

struct ContentView: View {
    @State var latestMessage: String = "Press Start"
    @State var matchManager: MatchManager?
    @State var testProgress: String = ""
    
    func start() {
        if matchManager != nil {
            return
        }
        let shogiUIInterface = ShogiUIInterface(displayMessage: {message in DispatchQueue.main.async {
            self.latestMessage = message
        }
            
        })
        matchManager = MatchManager(shogiUIInterface: shogiUIInterface)
        matchManager?.start()
    }
    
    func testPosition() {
        DispatchQueue.global(qos: .background).async {
            let position = Position()
            var failed = false
            let positionTestCases = loadPositionTestCases()
            for (i, tc) in positionTestCases.enumerated() {
                position.setUSIPosition(positionArg: tc.positionCommand)
                if position.getSFEN() != tc.sfen {
                    print("\(i) error: \(position.getSFEN()) != \(tc.sfen)")
                    failed = true
                    break
                }
                if position.inCheck() != tc.inCheck {
                    print("\(i) error inCheck: \(position.inCheck()) != \(tc.inCheck)")
                    failed = true
                    break
                }
                let actualMoveSet = Set(position.generateMoveList().map({m in m.toUSIString()}))
                
                if actualMoveSet != tc.legalMoves {
                    print("\(i) error moveset: \(actualMoveSet) != \(tc.legalMoves)")
                    failed = true
                    break
                    
                }
                if i % 100 == 0 {
                    DispatchQueue.main.async {
                        self.testProgress = "\(i) / \(positionTestCases.count)"
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.testProgress = failed ? "failed " : "completed"
            }
        }
    }
    
    func testDNNInput() {
        DispatchQueue.global(qos: .background).async {
            //let position = Position()
            //var failed = false
            // テストケース1024件を読むのに5分ほどかかってしまうが仕方ない(release build)
            print("loading")
            var failed = false
            let dnnInputTestCase = loadDNNInputTestCases()
            print(dnnInputTestCase[0].moveUSI)
            for (i, tc) in dnnInputTestCase.enumerated() {
                let position = Position()
                position.setSFEN(sfen: tc.sfen)
                let dnnInput = position.getDNNInput()
                for j in 0..<tc.x.count {
                    if dnnInput[j] != Float(tc.x[j]) {
                        print("case \(i) input[\(j)]: \(dnnInput[j]) != \(tc.x[j]) sfen=\(tc.sfen)")
                        print(position.hand)
                        failed = true
                        break
                    }
                }
                
                let moveLabel = position.getDNNMoveLabel(move: Move.fromUSIString(moveUSI: tc.moveUSI)!)
                if moveLabel != tc.moveLabel {
                    print("case \(i) move: \(moveLabel) != \(tc.moveLabel) sfen=\(tc.sfen) move=\(tc.moveUSI)")
                    failed = true
                }
                
                if failed {
                    break
                }
            }
            
            DispatchQueue.main.async {
                self.testProgress = failed ? "failed " : "completed"
            }
        }
    }

    var body: some View {
        VStack {
            Text(latestMessage)
                .padding()
            Button(action: start) {
                Text("Start")
            }.padding()
            Button(action: testPosition) {
                Text("Test position")
            }.padding()
            Button(action: testDNNInput) {
                Text("Test dnn input")
            }.padding()
            Text(testProgress)
                .padding()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
