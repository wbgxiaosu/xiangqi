// Blackbox tests run against the package's public API. Use `@xiangqi` to import.
// Prefer high-level behaviors over implementation details.
// Run `moon test` to execute and `moon test --update` to refresh snapshots.

///|
/// Initial position structure and FEN round-trip.
test "initial board" {
  let board = Board::initial()
  assert_eq(board.piece_count(), 32)
  assert_eq(board.side(), Red)
  assert_eq(
    board.to_fen(),
    "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 1",
  )
}

///|
test "fen parse and round trip" {
  let fen = "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1"
  let board = match parse_fen(fen) {
    Ok(b) => b
    Err(e) => fail("parse failed: \{e}")
  }
  assert_eq(board.piece_count(), 32)
  assert_eq(
    board.to_fen(),
    "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 1",
  )
}

///|
test "fen rejects malformed input" {
  assert_true(parse_fen("only one field") is Err(_))
  let bad_side = parse_fen("rnbakabnr/9 w")
  // Two rows is not ten: must be a board error, not a side error.
  assert_true(bad_side is Err(BadBoard(_)))
  assert_true(parse_fen("9/9/9/9/9/9/9/9/9/9 x - - 0 1") is Err(BadSide("x")))
}

///|
test "initial legal move count is 44" {
  let board = Board::initial()
  assert_eq(board.legal_moves().length(), 44)
}

///|
test "perft reference values" {
  let board = Board::initial()
  assert_eq(perft(board, 1), 44)
  assert_eq(perft(board, 2), 1920)
  assert_eq(perft(board, 3), 79666)
}

///|
test "cannon middle palace notation and iccs" {
  let board = Board::initial()
  // 炮二平五: red cannon on file h (Red file 二) to file e (Red file 五).
  let mv = match board.move_from_chinese("炮二平五") {
    Ok(m) => m
    Err(e) => fail("parse failed: \{e}")
  }
  assert_eq(mv.from, Pos::new(7, 2))
  assert_eq(mv.to, Pos::new(4, 2))
  assert_eq(board.move_to_iccs(mv), "h2e2")
  // ICCS parse agrees.
  match board.move_from_iccs("h2e2") {
    Ok(m) => assert_eq(m, mv)
    Err(e) => fail("iccs parse failed: \{e}")
  }
  // Bad ICCS rejected.
  assert_true(board.move_from_iccs("z9z9") is Err(_))
  assert_true(board.move_from_iccs("h2") is Err(BadIccs("h2")))
}

///|
test "chinese notation round trip for every opening move" {
  let board = Board::initial()
  for mv in board.legal_moves() {
    let text = board.move_to_chinese(mv)
    match board.move_from_chinese(text) {
      Ok(back) => assert_eq(back, mv)
      Err(e) => fail("round trip failed for \{text}: \{e}")
    }
  }
}

///|
test "black horse notation uses arabic numerals" {
  // Black to move: the horse on file i (black file 9) jumps to g7.
  let board = match
    parse_fen(
      "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR b - - 0 1",
    ) {
    Ok(b) => b
    Err(e) => fail("parse failed: \{e}")
  }
  match board.move_from_chinese("马8进7") {
    Ok(mv) => {
      assert_eq(mv.from, Pos::new(7, 9))
      assert_eq(mv.to, Pos::new(6, 7))
    }
    Err(e) => fail("parse failed: \{e}")
  }
}

///|
test "flying general rule" {
  // Kings on the same file with an empty file between them: the two
  // generals are "facing" each other and the position is illegal for
  // the side that just moved.
  let board = Board::initial()
  let cleared = board
    .without(Pos::new(4, 2))
    .without(Pos::new(4, 3))
    .without(Pos::new(4, 6))
    .without(Pos::new(4, 7))
  assert_true(cleared.kings_facing())
}

///|
test "kings not facing when a screen piece stands between" {
  let board = Board::initial()
  assert_false(board.kings_facing())
}

///|
test "checkmate detection two rooks ladder" {
  // Black king at e9, three red rooks: e8 gives check, d8 and f8 cover
  // the escapes and protect each other. Black has only the king.
  let base = Board::empty()
    .with_piece(Pos::new(4, 9), Piece::black(King))
    .with_piece(Pos::new(4, 0), Piece::red(King))
    .with_piece(Pos::new(4, 8), Piece::red(Rook))
    .with_piece(Pos::new(3, 8), Piece::red(Rook))
    .with_piece(Pos::new(5, 8), Piece::red(Rook))
    .with_side(Black)
  assert_true(base.in_check(Black))
  assert_eq(base.legal_moves().length(), 0)
  assert_true(base.is_checkmate())
  assert_eq(base.result(), RedWins)
}

///|
test "stalemate is a loss for the stalemated side" {
  // Black king at d9; red rook on e4 covers e9 through the open file,
  // red horse on c6 covers d8. No check, but no legal move either.
  let base = Board::empty()
    .with_piece(Pos::new(3, 9), Piece::black(King))
    .with_piece(Pos::new(0, 0), Piece::red(King))
    .with_piece(Pos::new(4, 4), Piece::red(Rook))
    .with_piece(Pos::new(2, 6), Piece::red(Horse))
    .with_side(Black)
  assert_false(base.in_check(Black))
  assert_eq(base.legal_moves().length(), 0)
  assert_true(base.is_stalemate())
  assert_eq(base.result(), RedWins)
}

///|
test "horse leg and elephant eye blocking" {
  // Horse at e1 with a screen at e2: the two forward jumps
  // ((3,3) and (5,3)) are blocked because the leg is e2.
  let b2 = Board::empty()
    .with_piece(Pos::new(4, 1), Piece::red(Horse))
    .with_piece(Pos::new(4, 2), Piece::red(Rook))
    .with_piece(Pos::new(4, 0), Piece::red(King))
  let from = Pos::new(4, 1)
  let targets : Array[Pos] = []
  for mv in b2.pseudo_moves_from(from) {
    targets.push(mv.to)
  }
  assert_false(targets.contains(Pos::new(3, 3)))
  assert_false(targets.contains(Pos::new(5, 3)))
  // Elephant with a blocked eye cannot jump over it.
  let b3 = Board::empty()
    .with_piece(Pos::new(2, 0), Piece::red(Elephant))
    .with_piece(Pos::new(3, 1), Piece::red(Rook))
    .with_piece(Pos::new(4, 0), Piece::red(King))
  let elephant_moves = b3.pseudo_moves_from(Pos::new(2, 0))
  for mv in elephant_moves {
    assert_false(mv.to == Pos::new(4, 2))
  }
  assert_true(elephant_moves.length() > 0)
}

///|
test "cannon needs a screen to capture" {
  let board = Board::empty()
    .with_piece(Pos::new(4, 0), Piece::red(King))
    .with_piece(Pos::new(4, 1), Piece::red(Cannon))
    .with_piece(Pos::new(4, 5), Piece::red(Rook))
    .with_piece(Pos::new(4, 9), Piece::black(King))
    .with_side(Red)
  let moves = board.pseudo_moves_from(Pos::new(4, 1))
  // Cannon at e1: screen at e5 (rook). On the same file it may slide
  // up to e4 without capturing, and the only capture beyond the
  // screen is the black king at e9.
  for mv in moves {
    if mv.to.file == 4 && mv.to.rank > 1 {
      assert_true(mv.to.rank <= 4 || mv.to == Pos::new(4, 9))
    }
  }
  // Squares between the cannon and the screen are quiet moves.
  assert_true(moves.contains(Move::new(Pos::new(4, 1), Pos::new(4, 3))))
}

///|
test "apply move preserves immutability" {
  let board = Board::initial()
  let mv = match board.move_from_iccs("h2e2") {
    Ok(m) => m
    Err(e) => fail("parse failed: \{e}")
  }
  let next = board.apply_move(mv)
  assert_eq(board.side(), Red)
  assert_eq(next.side(), Black)
  assert_eq(board.get(Pos::new(7, 2)) is Some(_), true)
  assert_eq(next.get(Pos::new(7, 2)) is None, true)
  assert_eq(next.get(Pos::new(4, 2)) is Some(_), true)
  assert_eq(next.move_number, 1)
  // After black's reply the full-move counter advances.
  let reply = match next.move_from_iccs("h9g7") {
    Ok(m) => m
    Err(e) => fail("parse failed: \{e}")
  }
  let third = next.apply_move(reply)
  assert_eq(third.move_number, 2)
}

///|
test "palace and river constraints" {
  let board = Board::empty()
    .with_piece(Pos::new(4, 0), Piece::red(King))
    .with_piece(Pos::new(4, 2), Piece::red(Elephant))
    .with_piece(Pos::new(4, 4), Piece::red(Elephant))
    .with_piece(Pos::new(4, 9), Piece::black(King))
    .with_side(Red)
  // Center elephant at e2 cannot cross the river to e4.
  let moves = board.pseudo_moves_from(Pos::new(4, 2))
  for mv in moves {
    assert_false(mv.to == Pos::new(4, 4))
  }
}
