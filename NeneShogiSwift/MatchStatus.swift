struct MoveHistoryItem {
    let detailedMove: DetailedMove
    let usedTime: Double?
    let scoreCp: Int?
}

// 対局の状態（接続状態、盤面や指し手履歴）
class MatchStatus {
    enum GameState {
        case connecting
        case initializing
        case playing
        case end(gameResult: String)
    }
    let gameState: GameState
    let position: Position
    let moveHistory: [MoveHistoryItem]
    init(gameState: GameState, position: Position, moveHistory: [MoveHistoryItem]) {
        self.gameState = gameState
        self.position = position
        self.moveHistory = moveHistory
    }
}
