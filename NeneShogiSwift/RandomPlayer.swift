import Foundation

class RandomPlayer: PlayerProtocol {
    var position: Position
    init() {
        position = Position()
    }
    
    func isReady(callback: @escaping () -> Void) {
        callback()
    }
    
    func usiNewGame() {
    }
    
    func position(positionArg: String) {
        // positionコマンド
        position.setUSIPosition(positionArg: positionArg)
    }
    
    func position(moves: [Move]) {
        position.setPosition(moves: moves)
    }
    
    func go(info: @escaping (SearchProgress) -> Void, thinkingTime: ThinkingTime, callback: @escaping (Move, Int) -> Void) {
        // goコマンド
        let moves = position.generateMoveList()
        let bestMove: Move
        if moves.count > 0 {
            let rnd = Int.random(in: 0..<moves.count)
            bestMove = moves[rnd]
        } else {
            bestMove = Move.Resign
        }
        callback(bestMove, 0)
    }

    func stop() {}
}
