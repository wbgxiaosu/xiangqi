// Blackbox tests for the game-history layer (repetition + long check).

///|
test "quiet opening has no long check" {
  let board = Board::initial()
  let history = GameHistory::new(board)
  let mut current = board
  for text in ["h2e2", "h9g7"] {
    let mv = match current.move_from_iccs(text) {
      Ok(m) => m
      Err(e) => fail("parse failed: \{e.to_string()}")
    }
    current = current.apply_move(mv)
    history.push(current)
  }
  assert_eq(history.position_repetitions(), 1)
  assert_eq(history.check_streak(Red), 0)
  assert_true(history.long_check_side(2, 3) is None)
}

///|
test "perpetual check shuttle is flagged" {
  // Red rook shuttles d8/e8, always landing on the file of a black
  // king that shuffles d9/e9. A second rook on a8 protects the
  // shuttle rook along the rank so the king may never capture it.
  // Red checks on every one of its moves; the position repeats
  // every 4 plies.
  let start = Board::empty()
    .with_piece(Pos::new(0, 0), Piece::red(King))
    .with_piece(Pos::new(0, 8), Piece::red(Rook))
    .with_piece(Pos::new(3, 8), Piece::red(Rook))
    .with_piece(Pos::new(4, 9), Piece::black(King))
    .with_side(Red)
  let history = GameHistory::new(start)
  let mut current = start
  for text in [
    "d8e8", "e9d9", "e8d8", "d9e9", "d8e8", "e9d9",
  ] {
    let mv = match current.move_from_iccs(text) {
      Ok(m) => m
      Err(e) => fail("move \{text} rejected: \{e.to_string()}")
    }
    current = current.apply_move(mv)
    history.push(current)
  }
  // The current position (rook e8, king d9, black to move) has now
  // appeared twice, and red checked three times in a row.
  assert_eq(history.position_repetitions(), 2)
  assert_eq(history.check_streak(Red), 3)
  // Black, meanwhile, never checked.
  assert_eq(history.check_streak(Black), 0)
  assert_eq(history.long_check_side(2, 3), Some(Red))
  // Under competition-grade thresholds (threefold repetition) the
  // evidence is not yet sufficient.
  assert_true(history.long_check_side(3, 3) is None)
}

///|
test "a quiet move resets the check streak" {
  let start = Board::empty()
    .with_piece(Pos::new(0, 0), Piece::red(King))
    .with_piece(Pos::new(0, 8), Piece::red(Rook))
    .with_piece(Pos::new(3, 8), Piece::red(Rook))
    .with_piece(Pos::new(4, 9), Piece::black(King))
    .with_side(Red)
  let history = GameHistory::new(start)
  let mut current = start
  // Two checking moves, then a quiet rook move along the back rank.
  for text in ["d8e8", "e9d9", "e8d8", "d9e9", "d8b8"] {
    let mv = match current.move_from_iccs(text) {
      Ok(m) => m
      Err(e) => fail("move \{text} rejected: \{e.to_string()}")
    }
    current = current.apply_move(mv)
    history.push(current)
  }
  assert_eq(history.check_streak(Red), 0)
  assert_true(history.long_check_side(2, 3) is None)
}
