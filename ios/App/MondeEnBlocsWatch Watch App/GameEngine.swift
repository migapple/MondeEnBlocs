import Foundation
import SwiftUI
import Combine

// MARK: - Constants
let COLS = 6
let ROWS = 12

// MARK: - Piece Color
enum PieceColor: CaseIterable {
    case gold, copper, blue, rose, green, purple, red

    var color: Color {
        switch self {
        case .gold:   return Color(red: 0.83, green: 0.66, blue: 0.21)
        case .copper: return Color(red: 0.75, green: 0.47, blue: 0.19)
        case .blue:   return Color(red: 0.48, green: 0.62, blue: 0.83)
        case .rose:   return Color(red: 0.83, green: 0.48, blue: 0.62)
        case .green:  return Color(red: 0.48, green: 0.74, blue: 0.48)
        case .purple: return Color(red: 0.62, green: 0.48, blue: 0.83)
        case .red:    return Color(red: 0.83, green: 0.48, blue: 0.48)
        }
    }
}

// MARK: - Piece Type
enum PieceType: CaseIterable {
    case I, O, T, L, J, S, Z

    var shape: [[Bool]] {
        switch self {
        case .I: return [[true, true, true, true]]
        case .O: return [[true, true], [true, true]]
        case .T: return [[true, true, true], [false, true, false]]
        case .L: return [[true, true, true], [true, false, false]]
        case .J: return [[true, true, true], [false, false, true]]
        case .S: return [[false, true, true], [true, true, false]]
        case .Z: return [[true, true, false], [false, true, true]]
        }
    }

    var color: PieceColor {
        switch self {
        case .I: return .gold
        case .O: return .copper
        case .T: return .blue
        case .L: return .rose
        case .J: return .green
        case .S: return .purple
        case .Z: return .red
        }
    }
}

// MARK: - Piece
struct Piece {
    var shape: [[Bool]]
    var color: PieceColor
    var x: Int
    var y: Int

    init(type: PieceType) {
        self.color = type.color
        self.shape = type.shape
        self.x = COLS / 2 - type.shape[0].count / 2
        self.y = 0
    }

    var rotated: [[Bool]] {
        let rows = shape.count
        let cols = shape[0].count
        var result = Array(repeating: Array(repeating: false, count: rows), count: cols)
        for r in 0..<rows {
            for c in 0..<cols {
                result[c][rows - 1 - r] = shape[r][c]
            }
        }
        return result
    }
}

// MARK: - Board Cell
struct Cell {
    var filled: Bool = false
    var color: PieceColor = .gold
}

// MARK: - Game Engine
class GameEngine: ObservableObject {
    @Published var board: [[Cell]] = GameEngine.emptyBoard()
    @Published var current: Piece = GameEngine.randomPiece()
    @Published var next: Piece = GameEngine.randomPiece()
    @Published var score: Int = 0
    @Published var level: Int = 1
    @Published var lines: Int = 0
    @Published var gameOver: Bool = false
    @Published var isRunning: Bool = false

    private var timer: AnyCancellable?
    private var totalLines: Int = 0

    static func emptyBoard() -> [[Cell]] {
        Array(repeating: Array(repeating: Cell(), count: COLS), count: ROWS)
    }

    static func randomPiece() -> Piece {
        Piece(type: PieceType.allCases.randomElement()!)
    }

    func start() {
        board = GameEngine.emptyBoard()
        score = 0; level = 1; lines = 0; totalLines = 0
        current = GameEngine.randomPiece()
        next = GameEngine.randomPiece()
        gameOver = false
        isRunning = true
        startTimer()
    }

    func pause() {
        isRunning.toggle()
        if isRunning { startTimer() } else { timer?.cancel() }
    }

    private func startTimer() {
        timer?.cancel()
        let interval = max(0.1, 0.6 - Double(level - 1) * 0.07)
        timer = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
    }

    private func tick() {
        guard isRunning && !gameOver else { return }
        moveDown()
    }

    func moveLeft() {
        guard isRunning && !gameOver else { return }
        if valid(piece: current, dx: -1, dy: 0) { current.x -= 1 }
    }

    func moveRight() {
        guard isRunning && !gameOver else { return }
        if valid(piece: current, dx: 1, dy: 0) { current.x += 1 }
    }

    func moveDown() {
        guard isRunning && !gameOver else { return }
        if valid(piece: current, dx: 0, dy: 1) {
            current.y += 1
        } else {
            place()
        }
    }

    func rotate() {
        guard isRunning && !gameOver else { return }
        let rotated = current.rotated
        var test = current
        test.shape = rotated
        if valid(piece: test, dx: 0, dy: 0) {
            current.shape = rotated
        } else if valid(piece: test, dx: 1, dy: 0) {
            current.shape = rotated; current.x += 1
        } else if valid(piece: test, dx: -1, dy: 0) {
            current.shape = rotated; current.x -= 1
        }
    }

    func hardDrop() {
        guard isRunning && !gameOver else { return }
        while valid(piece: current, dx: 0, dy: 1) { current.y += 1 }
        place()
    }

    private func valid(piece: Piece, dx: Int, dy: Int, shape: [[Bool]]? = nil) -> Bool {
        let s = shape ?? piece.shape
        for (r, row) in s.enumerated() {
            for (c, cell) in row.enumerated() {
                guard cell else { continue }
                let nx = piece.x + c + dx
                let ny = piece.y + r + dy
                if nx < 0 || nx >= COLS || ny >= ROWS { return false }
                if ny >= 0 && board[ny][nx].filled { return false }
            }
        }
        return true
    }

    private func place() {
        for (r, row) in current.shape.enumerated() {
            for (c, cell) in row.enumerated() {
                guard cell else { continue }
                let ny = current.y + r
                let nx = current.x + c
                if ny >= 0 { board[ny][nx] = Cell(filled: true, color: current.color) }
            }
        }
        clearLines()
        current = next
        next = GameEngine.randomPiece()
        if !valid(piece: current, dx: 0, dy: 0) { endGame() }
    }

    private func clearLines() {
        var cleared = 0
        var newBoard = board.filter { row in !row.allSatisfy { $0.filled } }
        cleared = ROWS - newBoard.count
        let emptyRows = Array(repeating: Array(repeating: Cell(), count: COLS), count: cleared)
        newBoard = emptyRows + newBoard
        board = newBoard
        if cleared > 0 {
            let pts = [0, 100, 300, 500, 800][min(cleared, 4)] * level
            score += pts
            lines += cleared
            totalLines += cleared
            level = totalLines / 8 + 1
            startTimer()
            WatchConnectivityManager.shared.sendScore(score: score, level: level)
        }
    }

    private func endGame() {
        gameOver = true
        isRunning = false
        timer?.cancel()
        WatchConnectivityManager.shared.sendScore(score: score, level: level)
    }

    func ghostY() -> Int {
        var gy = current.y
        while valid(piece: current, dx: 0, dy: gy - current.y + 1) { gy += 1 }
        return gy
    }
}
