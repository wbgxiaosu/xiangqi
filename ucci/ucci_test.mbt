// Blackbox tests for the UCCI adapter. The parent package is imported
// as @xiangqi via moon.pkg; the UCCI layer itself is the local package.

///|
test "position startpos yields the initial board" {
  let board = match parse_position("position startpos") {
    Ok(b) => b
    Err(e) => fail("\{e.to_string()}")
  }
  assert_eq(board.piece_count(), 32)
  assert_eq(board.side(), @xiangqi.Red)
  assert_eq(board.legal_moves().length(), 44)
}

///|
test "position startpos with moves replays the line" {
  let board = match
    parse_position("position startpos moves h2e2 h9g7") {
    Ok(b) => b
    Err(e) => fail("\{e.to_string()}")
  }
  // After 1. 炮二平五 马8进7 it is red to move again.
  assert_eq(board.side(), @xiangqi.Red)
  assert_eq(board.piece_count(), 32)
  // The horse really moved to g7.
  assert_true(board.get(@xiangqi.Pos::new(6, 7)) is Some(_))
  assert_true(board.get(@xiangqi.Pos::new(7, 9)) is None)
}

///|
test "position fen with moves" {
  let board = match
    parse_position(
      "position fen 2k6/9/9/9/9/9/9/9/4K4/9 w - - 0 1 moves e1e2",
    ) {
    Ok(b) => b
    Err(e) => fail("\{e.to_string()}")
  }
  assert_eq(board.side(), @xiangqi.Black)
  assert_eq(board.piece_count(), 2)
}

///|
test "malformed position commands are rejected" {
  // Not a position command at all.
  assert_true(parse_position("go depth 4") is Err(BadCommand(_)))
  // Unknown board spec.
  assert_true(parse_position("position movelist h2e2") is Err(BadCommand(_)))
  // Broken FEN.
  assert_true(
    parse_position("position fen nonsense w - - 0 1") is Err(BadFen(_)),
  )
}

///|
test "illegal move inside the moves list" {
  // a1a2 is not legal for red in the initial position (a1 is a rook
  // but the pawn on a3 blocks ... actually rook on a0 cannot jump).
  assert_true(
    parse_position("position startpos moves a1a2") is Err(BadMove("a1a2")),
  )
}

///|
test "move_to_ucci formats coordinates" {
  let board = @xiangqi.Board::initial()
  let mv = match board.move_from_chinese("炮二平五") {
    Ok(m) => m
    Err(e) => fail("\{e.to_string()}")
  }
  assert_eq(move_to_ucci(mv), "h2e2")
}

///|
test "validate_move_line replays and reports bad moves" {
  let board = @xiangqi.Board::initial()
  match validate_move_line(board, "h2e2 h9g7") {
    Ok(moves) => assert_eq(moves.length(), 2)
    Err(e) => fail("\{e.to_string()}")
  }
  assert_true(validate_move_line(board, "e2e4") is Err(BadMove("e2e4")))
}
