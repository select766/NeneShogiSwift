import Foundation
import CoreML

class PolicyPlayer: NNPlayerBase {
    override func go(info: (String) -> Void) -> String {
        // goコマンド
        guard let model = self.model else {
            fatalError()
        }
        let moves = position.generateMoveList()
        let inputArray = position.getDNNInput()
        if moves.count == 0 {
            return "resign"
        }
        guard let mmArray = try? MLMultiArray(shape: [1, 119, 9, 9], dataType: .float32) else {
            fatalError("Cannot allocate MLMultiArray")
        }
        let mmRawPtr = UnsafeMutablePointer<Float>(OpaquePointer(mmArray.dataPointer))
        for i in 0..<inputArray.count {
            mmRawPtr[i] = Float(inputArray[i])
        }
        let pred = try! model.prediction(x: mmArray)
        let moveArray = UnsafeMutablePointer<Float>(OpaquePointer(pred.move.dataPointer))
        var bestMove = "resign"
        var bestScore = Float(-100.0)
        for move in moves {
            let moveLabel = position.getDNNMoveLabel(move: move)
            let score = moveArray[moveLabel]
            if score >= bestScore {
                bestScore = score
                bestMove = move.toUSIString()
            }
        }
        let resultArray = UnsafeMutablePointer<Float>(OpaquePointer(pred.result.dataPointer))
        let cpInt = winRateToCp(winrate: resultArray[0])
        
        info("info depth 1 score cp \(cpInt) pv \(bestMove)")
        
        return bestMove
    }
}
