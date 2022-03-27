import Foundation
import Network

// AI種類選択
var playerClass = "MCTS"

class USIClient {
    let matchManager: MatchManager
    var serverEndpoint: NWEndpoint
    var connection: NWConnection?
    let queue: DispatchQueue
    var recvBuffer: Data = Data()
    var player: PlayerProtocol?
    var position: Position // 手番把握のためにAIとは別に必要
    init(matchManager: MatchManager, usiServerIpAddress: String) {
        self.matchManager = matchManager // TODO: 循環参照回避
        queue = DispatchQueue(label: "usiClient")
        self.serverEndpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(usiServerIpAddress), port: NWEndpoint.Port(8090))
        position = Position()
    }
    
    func start() {
        self.matchManager.displayMessage("connecting to USI server")
        connection = NWConnection(to: serverEndpoint, using: .tcp)
        connection?.stateUpdateHandler = {(newState) in
            print("stateUpdateHandler", newState)
            switch newState {
            case .ready:
                self.matchManager.displayMessage("connected to USI server")
                self.startRecv()
            case .waiting(let nwError):
                // ネットワーク構成が変化するまで待つ=事実上の接続失敗
                // TODO: 接続失敗時のアクション
                self.matchManager.displayMessage("Failed to connect to USI server: \(nwError)")
            default:
                break
            }
        }
        connection?.start(queue: queue)
    }
    
    func startRecv() {
        connection?.receive(minimumIncompleteLength: 0, maximumLength: 65535, completion: {(data,context,flag,error) in
            if let error = error {
                self.matchManager.displayMessage("USI receive error \(error)")
                print("receive error", error)
            } else {
                if let data = data {
                    self.recvBuffer.append(data)
                    while true {
                        if let lfPos = self.recvBuffer.firstIndex(of: 0x0a) {
                            var lineEndPos = lfPos
                            // CRをカット
                            if lineEndPos > 0 && self.recvBuffer[lineEndPos - 1] == 0x0d {
                                lineEndPos -= 1
                            }
                            if let commandStr = String(data: self.recvBuffer[..<lineEndPos], encoding: .utf8) {
                                self.handleUSICommand(command: commandStr)
                            } else {
                                print("Cannot decode USI data as utf-8")
                                self.matchManager.displayMessage("Cannot decode USI data as utf-8")
                            }
                            // Data()で囲わないと、次のfirstIndexで返る値が接続開始時からの全文字列に対するindexになる？バグか仕様か不明
                            self.recvBuffer = Data(self.recvBuffer[(lfPos+1)...])
                        } else {
                            break
                        }
                    }
                    self.startRecv()
                } else {
                    // コネクション切断で発生
                    self.matchManager.displayMessage("USI disconnected")
                }
            }
        })
    }
    
    func handleUSICommand(command: String) {
        self.matchManager.displayMessage("USI recv: '\(command)'")
        let splits = command.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: false)
        if splits.count < 1 {
            return
        }
        let commandType = splits[0]
        let commandArg = splits.count == 2 ? String(splits[1]) : nil
        switch commandType {
        case "usi":
            switch playerClass {
            case "Random":
                self.player = RandomPlayer()
            case "Policy":
                self.player = PolicyPlayer()
            case "MCTS":
                self.player = MCTSPlayer()
            default:
                fatalError("Unknown player selection")
            }
            sendUSI(messages: ["id name NeneShogiSwift", "id author select766", "usiok"])
        case "isready":
            self.player?.isReady(callback: {
                self.queue.async {
                    self.sendUSI(message: "readyok")
                }
            })
        case "setoption":
            break
        case "usinewgame":
            self.player?.usiNewGame()
            break
        case "position":
            if let commandArg = commandArg {
                position.setUSIPosition(positionArg: commandArg)
                self.player?.position(positionArg: commandArg)
            }
            break
        case "go":
            guard let player = self.player else {
                fatalError()
            }
            let thinkingTime: ThinkingTime
            if let commandArg = commandArg {
                thinkingTime = parseThinkingTime(commandArg: commandArg)
            } else {
                // 便宜上秒読み10秒にしておく
                thinkingTime = ThinkingTime(ponder: false, remaining: 0.0, byoyomi: 10.0, fisher: 0.0)
            }
            player.go(info: {(message: String) in
                self.queue.async {
                    self.sendUSI(message: message)
                }
            }, thinkingTime: thinkingTime, callback: {(bestMove: Move) in
                self.queue.async {
                    self.sendUSI(message: "bestmove \(bestMove.toUSIString())")
                    
                }
            })
        case "gameover":
            break
        case "quit":
            // 接続を切断することで接続先のncコマンドが終了する
            connection?.cancel()
            connection = nil
            // TODO: AI側終了
        default:
            print("Unknown command \(command)")
        }
    }
    
    func parseThinkingTime(commandArg: String) -> ThinkingTime {
        //　positionで指定された手番側の持ち時間を取得する
        let sideToMove = position.sideToMove
        let parts = commandArg.split(separator: " ", omittingEmptySubsequences: false)
        var idx = 0
        var remainingTime = 0.0
        var byoyomi = 0.0
        var fisher = 0.0
        while idx < parts.count {
            let key = parts[idx]
            idx += 1
            switch key {
            case "btime":
                if sideToMove == PColor.BLACK {
                    remainingTime = (Double(parts[idx]) ?? 0.0)  / 1000.0
                }
                idx += 1
            case "wtime":
                if sideToMove == PColor.WHITE {
                    remainingTime = (Double(parts[idx]) ?? 0.0)  / 1000.0
                }
                idx += 1
            case "byoyomi":
                byoyomi = (Double(parts[idx]) ?? 0.0) / 1000.0
                idx += 1
            case "binc":
                if sideToMove == PColor.BLACK {
                    fisher = (Double(parts[idx]) ?? 0.0)  / 1000.0
                }
                idx += 1
            case "winc":
                if sideToMove == PColor.WHITE {
                    fisher = (Double(parts[idx]) ?? 0.0)  / 1000.0
                }
                idx += 1
            default:
                print("Warning: unsupported go argument \(key)")
            }
        }
        return ThinkingTime(ponder: false, remaining: remainingTime, byoyomi: byoyomi, fisher: fisher)
    }
    
    func _send(messageWithNewline: String) {
        connection?.send(content: messageWithNewline.data(using: .utf8)!, completion: .contentProcessed{ error in
            if let error = error {
                print("Error in send", error)
            }
        })
        
    }
    
    func sendUSI(message: String) {
        _send(messageWithNewline: message + "\n")
    }
    
    func sendUSI(messages: [String]) {
        _send(messageWithNewline: messages.map({m in m + "\n"}).joined())
    }
}
