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
    Err(e) => fail("parse failed: \{e.to_string()}")
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
    Err(e) => fail("parse failed: \{e.to_string()}")
  }
  assert_eq(mv.from, Pos::new(7, 2))
  assert_eq(mv.to, Pos::new(4, 2))
  assert_eq(board.move_to_iccs(mv), "h2e2")
  // ICCS parse agrees.
  match board.move_from_iccs("h2e2") {
    Ok(m) => assert_eq(m, mv)
    Err(e) => fail("iccs parse failed: \{e.to_string()}")
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
      Err(e) => fail("round trip failed for \{text}: \{e.to_string()}")
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
    Err(e) => fail("parse failed: \{e.to_string()}")
  }
  match board.move_from_chinese("马8进7") {
    Ok(mv) => {
      assert_eq(mv.from, Pos::new(7, 9))
      assert_eq(mv.to, Pos::new(6, 7))
    }
    Err(e) => fail("parse failed: \{e.to_string()}")
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
    Err(e) => fail("parse failed: \{e.to_string()}")
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
    Err(e) => fail("parse failed: \{e.to_string()}")
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

///|
test "fen error variants are precise" {
  // Missing fields entirely.
  assert_true(parse_fen("9/9/9/9/9/9/9/9/9/9") is Err(BadFieldCount))
  // Non-numeric move number.
  assert_true(
    parse_fen("9/9/9/9/9/9/9/9/9/9 w - - abc") is Err(BadMoveNumber("abc")),
  )
  // Ten rows with a stray piece character outside the piece alphabet.
  assert_true(parse_fen("9/9/9/9/9/9/9/9/9/zz w - - 0 1") is Err(BadBoard("zz")))
}

///|
test "char to piece kind mapping" {
  assert_eq(char_to_piece_kind('帅'), Some(King))
  assert_eq(char_to_piece_kind('將'), Some(King))
  assert_eq(char_to_piece_kind('仕'), Some(Advisor))
  assert_eq(char_to_piece_kind('士'), Some(Advisor))
  assert_eq(char_to_piece_kind('马'), Some(Horse))
  assert_eq(char_to_piece_kind('車'), Some(Rook))
  assert_eq(char_to_piece_kind('炮'), Some(Cannon))
  assert_eq(char_to_piece_kind('卒'), Some(Pawn))
  assert_true(char_to_piece_kind('x') is None)
}

///|
test "palace membership helper" {
  // Red palace: files 3-5, ranks 0-2.
  assert_true(Pos::new(4, 1).in_palace(Red))
  assert_true(Pos::new(3, 2).in_palace(Red))
  assert_false(Pos::new(2, 1).in_palace(Red))
  assert_false(Pos::new(4, 3).in_palace(Red))
  // Black palace: files 3-5, ranks 7-9.
  assert_true(Pos::new(4, 8).in_palace(Black))
  assert_true(Pos::new(5, 7).in_palace(Black))
  assert_false(Pos::new(4, 6).in_palace(Black))
}

///|
test "side helpers" {
  let red : Side = Red
  let black : Side = Black
  assert_eq(red.opponent(), black)
  assert_eq(black.opponent(), red)
  assert_true(red.is_red())
  assert_false(black.is_red())
}

///|
test "advisor moves diagonally inside palace" {
  let board = Board::empty()
    .with_piece(Pos::new(4, 0), Piece::red(King))
    .with_piece(Pos::new(4, 1), Piece::red(Advisor))
    .with_piece(Pos::new(4, 9), Piece::black(King))
    .with_side(Red)
  // Advisor on the palace center has exactly four diagonal targets.
  let moves = board.pseudo_moves_from(Pos::new(4, 1))
  assert_eq(moves.length(), 4)
  for mv in moves {
    assert_true(mv.to.in_palace(Red))
  }
}

///|
test "horse in the corner has two jumps" {
  let board = Board::empty()
    .with_piece(Pos::new(4, 0), Piece::red(King))
    .with_piece(Pos::new(0, 0), Piece::red(Horse))
    .with_piece(Pos::new(4, 9), Piece::black(King))
    .with_side(Red)
  let moves = board.pseudo_moves_from(Pos::new(0, 0))
  assert_eq(moves.length(), 2)
  assert_true(moves.contains(Move::new(Pos::new(0, 0), Pos::new(1, 2))))
  assert_true(moves.contains(Move::new(Pos::new(0, 0), Pos::new(2, 1))))
}

///|
test "pawn before the river only advances" {
  let board = Board::empty()
    .with_piece(Pos::new(4, 0), Piece::red(King))
    .with_piece(Pos::new(4, 4), Piece::red(Pawn))
    .with_piece(Pos::new(4, 9), Piece::black(King))
    .with_side(Red)
  let moves = board.pseudo_moves_from(Pos::new(4, 4))
  assert_eq(moves.length(), 1)
  assert_eq(moves[0].to, Pos::new(4, 5))
}

///|
test "pawn across the river gains sideways moves" {
  let board = Board::empty()
    .with_piece(Pos::new(4, 0), Piece::red(King))
    .with_piece(Pos::new(4, 5), Piece::red(Pawn))
    .with_piece(Pos::new(4, 9), Piece::black(King))
    .with_side(Red)
  let targets : Array[Pos] = []
  for mv in board.pseudo_moves_from(Pos::new(4, 5)) {
    targets.push(mv.to)
  }
  assert_true(targets.contains(Pos::new(4, 6)))
  assert_true(targets.contains(Pos::new(3, 5)))
  assert_true(targets.contains(Pos::new(5, 5)))
  // Pawns never retreat.
  assert_false(targets.contains(Pos::new(4, 4)))
}

///|
test "pinned piece may not leave the king's file" {
  // Red king e0, red rook e5, black king e9: the rook is pinned by the
  // flying-general rule, so every legal rook move stays on file e.
  let board = Board::empty()
    .with_piece(Pos::new(4, 0), Piece::red(King))
    .with_piece(Pos::new(4, 5), Piece::red(Rook))
    .with_piece(Pos::new(4, 9), Piece::black(King))
    .with_side(Red)
  let rook_moves : Array[Move] = []
  for mv in board.legal_moves() {
    if mv.from == Pos::new(4, 5) {
      rook_moves.push(mv)
    }
  }
  assert_true(rook_moves.length() > 0)
  for mv in rook_moves {
    assert_eq(mv.to.file, 4)
  }
  // In particular the horizontal escapes are all filtered out.
  assert_false(rook_moves.contains(Move::new(Pos::new(4, 5), Pos::new(0, 5))))
}

///|
test "horse attack detection respects the leg" {
  // Black horse at f2 attacks red king e0 only while the leg at f1 is free.
  let with_leg = Board::empty()
    .with_piece(Pos::new(4, 0), Piece::red(King))
    .with_piece(Pos::new(5, 2), Piece::black(Horse))
    .with_piece(Pos::new(4, 9), Piece::black(King))
  assert_true(with_leg.is_attacked(Pos::new(4, 0), Black))
  let blocked = with_leg.with_piece(Pos::new(5, 1), Piece::red(Pawn))
  assert_false(blocked.is_attacked(Pos::new(4, 0), Black))
}

///|
test "cannon attack detection needs exactly one screen" {
  let king_only = Board::empty()
    .with_piece(Pos::new(4, 0), Piece::red(King))
    .with_piece(Pos::new(4, 8), Piece::black(Cannon))
    .with_piece(Pos::new(4, 9), Piece::black(King))
  // No screen between cannon and king: no attack.
  assert_false(king_only.is_attacked(Pos::new(4, 0), Black))
  // One screen: attack.
  let one_screen = king_only.with_piece(Pos::new(4, 5), Piece::black(Pawn))
  assert_true(one_screen.is_attacked(Pos::new(4, 0), Black))
  // Two screens: the second one shields the king again.
  let two_screens = one_screen.with_piece(Pos::new(4, 2), Piece::red(Pawn))
  assert_false(two_screens.is_attacked(Pos::new(4, 0), Black))
}

///|
test "pawn attack detection across the river" {
  // Black pawn on e1 has crossed the river: it attacks e0 forward and
  // the sideways squares d1/f1.
  let board = Board::empty()
    .with_piece(Pos::new(4, 0), Piece::red(King))
    .with_piece(Pos::new(4, 1), Piece::black(Pawn))
    .with_piece(Pos::new(0, 9), Piece::black(King))
  assert_true(board.is_attacked(Pos::new(4, 0), Black))
  assert_true(board.is_attacked(Pos::new(3, 1), Black))
  assert_false(board.is_attacked(Pos::new(2, 1), Black))
}

///|
test "capture updates piece count" {
  let board = Board::empty()
    .with_piece(Pos::new(4, 0), Piece::red(King))
    .with_piece(Pos::new(4, 9), Piece::black(King))
    .with_piece(Pos::new(0, 4), Piece::red(Rook))
    .with_piece(Pos::new(0, 5), Piece::black(Pawn))
    .with_side(Red)
  assert_eq(board.piece_count(), 4)
  let capture = Move::new(Pos::new(0, 4), Pos::new(0, 5))
  let next = board.apply_move(capture)
  assert_eq(next.piece_count(), 3)
  assert_eq(next.get(Pos::new(0, 5)), Some(Piece::red(Rook)))
}

///|
test "ongoing game has no result yet" {
  assert_eq(Board::initial().result(), Ongoing)
}

///|
test "iccs round trip for every opening move" {
  let board = Board::initial()
  for mv in board.legal_moves() {
    let text = board.move_to_iccs(mv)
    match board.move_from_iccs(text) {
      Ok(back) => assert_eq(back, mv)
      Err(e) => fail("iccs round trip failed for \{text}: \{e.to_string()}")
    }
  }
}

///|
test "front and back rook disambiguation" {
  let board = Board::empty()
    .with_piece(Pos::new(0, 0), Piece::red(King))
    .with_piece(Pos::new(4, 5), Piece::red(Rook))
    .with_piece(Pos::new(4, 7), Piece::red(Rook))
    .with_piece(Pos::new(8, 9), Piece::black(King))
    .with_side(Red)
  // The rook nearer the enemy is the front one.
  assert_eq(
    board.move_to_chinese(Move::new(Pos::new(4, 7), Pos::new(4, 8))),
    "前车进一",
  )
  assert_eq(
    board.move_to_chinese(Move::new(Pos::new(4, 5), Pos::new(4, 4))),
    "后车退一",
  )
  // Both notations parse back to their original moves.
  match board.move_from_chinese("前车进一") {
    Ok(mv) => assert_eq(mv, Move::new(Pos::new(4, 7), Pos::new(4, 8)))
    Err(e) => fail("front rook parse failed: \{e.to_string()}")
  }
  match board.move_from_chinese("后车退一") {
    Ok(mv) => assert_eq(mv, Move::new(Pos::new(4, 5), Pos::new(4, 4)))
    Err(e) => fail("back rook parse failed: \{e.to_string()}")
  }
}
