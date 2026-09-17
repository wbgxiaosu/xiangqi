///|
/// Demo CLI: prints the initial board, plays the classic opening
/// 炮二平五 via the Chinese-notation parser, and runs perft counts.
/// Run with `moon run cmd/main` from the project root.
fn main {
  let board = @xiangqi.Board::initial()
  println("=== 中国象棋 · MoonBit 规则引擎演示 ===\n")
  println(board.render_board())
  println("FEN: \{board.to_fen()}")
  println("开局合法着法数: \{board.legal_moves().length()}\n")
  // Play 1. 炮二平五 by notation, 2. ... 马8进7 by ICCS.
  match board.move_from_chinese("炮二平五") {
    Ok(mv) => {
      println("红方: 炮二平五 (\{board.move_to_iccs(mv)})")
      let after_red = board.apply_move(mv)
      match after_red.move_from_iccs("h9g7") {
        Ok(reply) => {
          println(
            "黑方: \{after_red.move_to_chinese(reply)} (\{after_red.move_to_iccs(reply)})",
          )
          let after_black = after_red.apply_move(reply)
          println("")
          println(after_black.render_board())
          println("FEN: \{after_black.to_fen()}")
        }
        Err(e) => println("黑方着法解析失败: \{e}")
      }
    }
    Err(e) => println("着法解析失败: \{e}")
  }
  println("")
  println("=== 走法生成正确性验证 (perft) ===")
  let start = @xiangqi.Board::initial()
  println("perft(1) = \{@xiangqi.perft(start, 1)}  (期望 44)")
  println("perft(2) = \{@xiangqi.perft(start, 2)}  (期望 1920)")
  println("perft(3) = \{@xiangqi.perft(start, 3)}  (期望 79666)")
}
