import SwiftUI

// MARK: - Content View (entry)
struct ContentView: View {
    @StateObject var engine = GameEngine()

    var body: some View {
        if engine.gameOver || (!engine.isRunning && engine.score == 0) {
            StartView(engine: engine)
        } else {
            GameView(engine: engine)
        }
    }
}

// MARK: - Start Screen
struct StartView: View {
    @ObservedObject var engine: GameEngine
    private let gold = Color(red: 0.83, green: 0.66, blue: 0.21)

    var body: some View {
        VStack(spacing: 8) {
            Text("Le Monde\nen Blocs")
                .font(.system(size: 16, weight: .medium, design: .serif))
                .foregroundColor(gold)
                .multilineTextAlignment(.center)

            if engine.gameOver {
                Text("Score : \(engine.score)")
                    .font(.system(size: 13))
                    .foregroundColor(.white)
            }

            Button(engine.gameOver ? "Rejouer" : "Jouer") {
                engine.start()
            }
            .buttonStyle(.borderedProminent)
            .tint(gold)
            .font(.system(size: 14, weight: .medium))
        }
        .padding()
        .background(Color(red: 0.027, green: 0.020, blue: 0.063))
    }
}

// MARK: - Game View
struct GameView: View {
    @ObservedObject var engine: GameEngine
    @State private var crownValue: Double = 0
    @State private var lastCrownValue: Double = 0
    private let cellSize: CGFloat = 13
    private let gold = Color(red: 0.83, green: 0.66, blue: 0.21)

    var body: some View {
        ZStack {
            Color(red: 0.027, green: 0.020, blue: 0.063).ignoresSafeArea()

            HStack(alignment: .top, spacing: 4) {
                BoardView(engine: engine, cellSize: cellSize)
                    .gesture(
                        DragGesture(minimumDistance: 20)
                            .onEnded { val in
                                if val.translation.height > 30 { engine.hardDrop() }
                                else if val.translation.width > 20 { engine.moveRight() }
                                else if val.translation.width < -20 { engine.moveLeft() }
                            }
                    )
                    .onTapGesture { engine.rotate() }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Next")
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                    NextPieceView(piece: engine.next, cellSize: cellSize - 3)
                        .frame(width: 36, height: 28)

                    Divider().background(Color.gray.opacity(0.3))

                    Text("Score")
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                    Text("\(engine.score)")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(gold)

                    Text("Niv.\(engine.level)")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)

                    Spacer()

                    Button(action: { engine.pause() }) {
                        Image(systemName: engine.isRunning ? "pause.fill" : "play.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(.plain)
                }
                .frame(width: 42)
                .padding(.vertical, 2)
            }
            .padding(.horizontal, 2)
        }
        .focusable()
        .digitalCrownRotation(
            $crownValue,
            from: -1000, through: 1000,
            by: 1,
            sensitivity: .low,
            isContinuous: true,
            isHapticFeedbackEnabled: true
        )
        .onChange(of: crownValue) { newVal in
            let delta = newVal - lastCrownValue
            if delta > 0.8 { engine.moveRight(); lastCrownValue = newVal }
            else if delta < -0.8 { engine.moveLeft(); lastCrownValue = newVal }
        }
    }
}

// MARK: - Board View
struct BoardView: View {
    @ObservedObject var engine: GameEngine
    let cellSize: CGFloat

    var body: some View {
        Canvas { ctx, _ in
            let ghostY = engine.ghostY()

            for row in 0..<ROWS {
                for col in 0..<COLS {
                    let x = CGFloat(col) * cellSize
                    let y = CGFloat(row) * cellSize
                    let rect = CGRect(x: x + 0.5, y: y + 0.5, width: cellSize - 1, height: cellSize - 1)

                    ctx.fill(Path(rect), with: .color(Color.white.opacity(0.04)))

                    if engine.board[row][col].filled {
                        ctx.fill(Path(rect), with: .color(engine.board[row][col].color.color))
                        ctx.fill(
                            Path(CGRect(x: x + 0.5, y: y + 0.5, width: cellSize - 1, height: 2)),
                            with: .color(Color.white.opacity(0.2))
                        )
                    }
                }
            }

            // Ghost
            for (r, row) in engine.current.shape.enumerated() {
                for (c, cell) in row.enumerated() {
                    guard cell else { continue }
                    let nx = engine.current.x + c
                    let ny = ghostY + r
                    guard ny >= 0 && ny < ROWS else { continue }
                    let rect = CGRect(x: CGFloat(nx)*cellSize+0.5, y: CGFloat(ny)*cellSize+0.5, width: cellSize-1, height: cellSize-1)
                    ctx.fill(Path(rect), with: .color(engine.current.color.color.opacity(0.15)))
                }
            }

            // Current piece
            for (r, row) in engine.current.shape.enumerated() {
                for (c, cell) in row.enumerated() {
                    guard cell else { continue }
                    let nx = engine.current.x + c
                    let ny = engine.current.y + r
                    guard ny >= 0 && ny < ROWS else { continue }
                    let rect = CGRect(x: CGFloat(nx)*cellSize+0.5, y: CGFloat(ny)*cellSize+0.5, width: cellSize-1, height: cellSize-1)
                    ctx.fill(Path(rect), with: .color(engine.current.color.color))
                    ctx.fill(
                        Path(CGRect(x: CGFloat(nx)*cellSize+0.5, y: CGFloat(ny)*cellSize+0.5, width: cellSize-1, height: 2)),
                        with: .color(Color.white.opacity(0.25))
                    )
                }
            }

            // Border
            ctx.stroke(
                Path(CGRect(x: 0, y: 0, width: CGFloat(COLS)*cellSize, height: CGFloat(ROWS)*cellSize)),
                with: .color(Color(red: 0.83, green: 0.66, blue: 0.21).opacity(0.3)),
                lineWidth: 0.5
            )
        }
        .frame(width: CGFloat(COLS) * cellSize, height: CGFloat(ROWS) * cellSize)
    }
}

// MARK: - Next Piece View
struct NextPieceView: View {
    let piece: Piece
    let cellSize: CGFloat

    var body: some View {
        Canvas { ctx, size in
            let s = piece.shape
            let ox = (size.width - CGFloat(s[0].count) * cellSize) / 2
            let oy = (size.height - CGFloat(s.count) * cellSize) / 2
            for (r, row) in s.enumerated() {
                for (c, cell) in row.enumerated() {
                    guard cell else { continue }
                    let rect = CGRect(
                        x: ox + CGFloat(c)*cellSize + 0.5,
                        y: oy + CGFloat(r)*cellSize + 0.5,
                        width: cellSize - 1,
                        height: cellSize - 1
                    )
                    ctx.fill(Path(rect), with: .color(piece.color.color))
                }
            }
        }
    }
}
