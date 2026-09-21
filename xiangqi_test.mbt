// Blackbox tests run against the package's public API. Use `@xiangqi` to import.
// Prefer high-level behaviors over implementation details.
// Run `moon test` to execute and `moon test --update` to refresh snapshots.

///|
/// Initial position structure and FEN round-trip.
test "initial board" {
  let board = @xiangqi.Board::initial()
  assert_eq(board.piece_count(), 32)
  assert_eq(board.side(), @xiangqi.Red)
  assert_eq(
    board.to_fen(),
    "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 1",
  )
}

///|
test "fen parse and round trip" {
  let fen = "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1"
  let board = match @xiangqi.parse_fen(fen) {
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
  assert_true(@xiangqi.parse_fen("only one field") is Err(_))
  let bad_side = @xiangqi.parse_fen("rnbakabnr/9 w")
  // Two rows is not ten: must be a board error, not a side error.
  assert_true(bad_side is Err(@xiangqi.BadBoard(_)))
  assert_true(
    @xiangqi.parse_fen("9/9/9/9/9/9/9/9/9/9 x - - 0 1")
    is Err(@xiangqi.BadSide("x")),
  )
}

///|
test "initial legal move count is 44" {
  let board = @xiangqi.Board::initial()
  assert_eq(board.legal_moves().length(), 44)
}

///|
test "@xiangqi.perft reference values" {
  let board = @xiangqi.Board::initial()
  assert_eq(@xiangqi.perft(board, 1), 44)
  assert_eq(@xiangqi.perft(board, 2), 1920)
  assert_eq(@xiangqi.perft(board, 3), 79666)
}

///|
test "cannon middle palace notation and iccs" {
  let board = @xiangqi.Board::initial()
  // 炮二平五: red cannon on file h (Red file 二) to file e (Red file 五).
  let mv = match board.move_from_chinese("炮二平五") {
    Ok(m) => m
    Err(e) => fail("parse failed: \{e.to_string()}")
  }
  assert_eq(mv.from, @xiangqi.Pos::new(7, 2))
  assert_eq(mv.to, @xiangqi.Pos::new(4, 2))
  assert_eq(board.move_to_iccs(mv), "h2e2")
  // ICCS parse agrees.
  match board.move_from_iccs("h2e2") {
    Ok(m) => assert_eq(m, mv)
    Err(e) => fail("iccs parse failed: \{e.to_string()}")
  }
  // Bad ICCS rejected.
  assert_true(board.move_from_iccs("z9z9") is Err(_))
  assert_true(board.move_from_iccs("h2") is Err(@xiangqi.BadIccs("h2")))
}

///|
test "chinese notation round trip for every opening move" {
  let board = @xiangqi.Board::initial()
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
    @xiangqi.parse_fen(
      "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR b - - 0 1",
    ) {
    Ok(b) => b
    Err(e) => fail("parse failed: \{e.to_string()}")
  }
  match board.move_from_chinese("马8进7") {
    Ok(mv) => {
      assert_eq(mv.from, @xiangqi.Pos::new(7, 9))
      assert_eq(mv.to, @xiangqi.Pos::new(6, 7))
    }
    Err(e) => fail("parse failed: \{e.to_string()}")
  }
}

///|
test "flying general rule" {
  // Kings on the same file with an empty file between them: the two
  // generals are "facing" each other and the position is illegal for
  // the side that just moved.
  let board = @xiangqi.Board::initial()
  let cleared = board
    .without(@xiangqi.Pos::new(4, 2))
    .without(@xiangqi.Pos::new(4, 3))
    .without(@xiangqi.Pos::new(4, 6))
    .without(@xiangqi.Pos::new(4, 7))
  assert_true(cleared.kings_facing())
}

///|
test "kings not facing when a screen piece stands between" {
  let board = @xiangqi.Board::initial()
  assert_false(board.kings_facing())
}

///|
test "checkmate detection two rooks ladder" {
  // Black king at e9, three red rooks: e8 gives check, d8 and f8 cover
  // the escapes and protect each other. Black has only the king.
  let base = @xiangqi.Board::empty()
    .with_piece(@xiangqi.Pos::new(4, 9), @xiangqi.Piece::black(@xiangqi.King))
    .with_piece(@xiangqi.Pos::new(4, 0), @xiangqi.Piece::red(@xiangqi.King))
    .with_piece(@xiangqi.Pos::new(4, 8), @xiangqi.Piece::red(@xiangqi.Rook))
    .with_piece(@xiangqi.Pos::new(3, 8), @xiangqi.Piece::red(@xiangqi.Rook))
    .with_piece(@xiangqi.Pos::new(5, 8), @xiangqi.Piece::red(@xiangqi.Rook))
    .with_side(@xiangqi.Black)
  assert_true(base.in_check(@xiangqi.Black))
  assert_eq(base.legal_moves().length(), 0)
  assert_true(base.is_checkmate())
  assert_eq(base.result(), @xiangqi.RedWins)
}

///|
test "stalemate is a loss for the stalemated side" {
  // Black king at d9; red rook on e4 covers e9 through the open file,
  // red horse on c6 covers d8. No check, but no legal move either.
  let base = @xiangqi.Board::empty()
    .with_piece(@xiangqi.Pos::new(3, 9), @xiangqi.Piece::black(@xiangqi.King))
    .with_piece(@xiangqi.Pos::new(0, 0), @xiangqi.Piece::red(@xiangqi.King))
    .with_piece(@xiangqi.Pos::new(4, 4), @xiangqi.Piece::red(@xiangqi.Rook))
    .with_piece(@xiangqi.Pos::new(2, 6), @xiangqi.Piece::red(@xiangqi.Horse))
    .with_side(@xiangqi.Black)
  assert_false(base.in_check(@xiangqi.Black))
  assert_eq(base.legal_moves().length(), 0)
  assert_true(base.is_stalemate())
  assert_eq(base.result(), @xiangqi.RedWins)
}

///|
test "horse leg and elephant eye blocking" {
  // Horse at e1 with a screen at e2: the two forward jumps
  // ((3,3) and (5,3)) are blocked because the leg is e2.
  let b2 = @xiangqi.Board::empty()
    .with_piece(@xiangqi.Pos::new(4, 1), @xiangqi.Piece::red(@xiangqi.Horse))
    .with_piece(@xiangqi.Pos::new(4, 2), @xiangqi.Piece::red(@xiangqi.Rook))
    .with_piece(@xiangqi.Pos::new(4, 0), @xiangqi.Piece::red(@xiangqi.King))
  let from = @xiangqi.Pos::new(4, 1)
  let targets : Array[@xiangqi.Pos] = []
  for mv in b2.pseudo_moves_from(from) {
    targets.push(mv.to)
  }
  assert_false(targets.contains(@xiangqi.Pos::new(3, 3)))
  assert_false(targets.contains(@xiangqi.Pos::new(5, 3)))
  // Elephant with a blocked eye cannot jump over it.
  let b3 = @xiangqi.Board::empty()
    .with_piece(@xiangqi.Pos::new(2, 0), @xiangqi.Piece::red(@xiangqi.Elephant))
    .with_piece(@xiangqi.Pos::new(3, 1), @xiangqi.Piece::red(@xiangqi.Rook))
    .with_piece(@xiangqi.Pos::new(4, 0), @xiangqi.Piece::red(@xiangqi.King))
  let elephant_moves = b3.pseudo_moves_from(@xiangqi.Pos::new(2, 0))
  for mv in elephant_moves {
    assert_false(mv.to == @xiangqi.Pos::new(4, 2))
  }
  assert_true(elephant_moves.length() > 0)
}

///|
test "cannon needs a screen to capture" {
  let board = @xiangqi.Board::empty()
    .with_piece(@xiangqi.Pos::new(4, 0), @xiangqi.Piece::red(@xiangqi.King))
    .with_piece(@xiangqi.Pos::new(4, 1), @xiangqi.Piece::red(@xiangqi.Cannon))
    .with_piece(@xiangqi.Pos::new(4, 5), @xiangqi.Piece::red(@xiangqi.Rook))
    .with_piece(@xiangqi.Pos::new(4, 9), @xiangqi.Piece::black(@xiangqi.King))
    .with_side(@xiangqi.Red)
  let moves = board.pseudo_moves_from(@xiangqi.Pos::new(4, 1))
  // Cannon at e1: screen at e5 (rook). On the same file it may slide
  // up to e4 without capturing, and the only capture beyond the
  // screen is the black king at e9.
  for mv in moves {
    if mv.to.file == 4 && mv.to.rank > 1 {
      assert_true(mv.to.rank <= 4 || mv.to == @xiangqi.Pos::new(4, 9))
    }
  }
  // Squares between the cannon and the screen are quiet moves.
  assert_true(
    moves.contains(
      @xiangqi.Move::new(@xiangqi.Pos::new(4, 1), @xiangqi.Pos::new(4, 3)),
    ),
  )
}

///|
test "apply move preserves immutability" {
  let board = @xiangqi.Board::initial()
  let mv = match board.move_from_iccs("h2e2") {
    Ok(m) => m
    Err(e) => fail("parse failed: \{e.to_string()}")
  }
  let next = board.apply_move(mv)
  assert_eq(board.side(), @xiangqi.Red)
  assert_eq(next.side(), @xiangqi.Black)
  assert_eq(board.get(@xiangqi.Pos::new(7, 2)) is Some(_), true)
  assert_eq(next.get(@xiangqi.Pos::new(7, 2)) is None, true)
  assert_eq(next.get(@xiangqi.Pos::new(4, 2)) is Some(_), true)
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
  let board = @xiangqi.Board::empty()
    .with_piece(@xiangqi.Pos::new(4, 0), @xiangqi.Piece::red(@xiangqi.King))
    .with_piece(@xiangqi.Pos::new(4, 2), @xiangqi.Piece::red(@xiangqi.Elephant))
    .with_piece(@xiangqi.Pos::new(4, 4), @xiangqi.Piece::red(@xiangqi.Elephant))
    .with_piece(@xiangqi.Pos::new(4, 9), @xiangqi.Piece::black(@xiangqi.King))
    .with_side(@xiangqi.Red)
  // Center elephant at e2 cannot cross the river to e4.
  let moves = board.pseudo_moves_from(@xiangqi.Pos::new(4, 2))
  for mv in moves {
    assert_false(mv.to == @xiangqi.Pos::new(4, 4))
  }
}

///|
test "fen error variants are precise" {
  // Missing fields entirely.
  assert_true(
    @xiangqi.parse_fen("9/9/9/9/9/9/9/9/9/9") is Err(@xiangqi.BadFieldCount),
  )
  // Non-numeric move number.
  assert_true(
    @xiangqi.parse_fen("9/9/9/9/9/9/9/9/9/9 w - - abc")
    is Err(@xiangqi.BadMoveNumber("abc")),
  )
  // Ten rows with a stray piece character outside the piece alphabet.
  assert_true(
    @xiangqi.parse_fen("9/9/9/9/9/9/9/9/9/zz w - - 0 1")
    is Err(@xiangqi.BadBoard("zz")),
  )
}

///|
test "char to piece kind mapping" {
  assert_eq(@xiangqi.char_to_piece_kind('帅'), Some(@xiangqi.King))
  assert_eq(@xiangqi.char_to_piece_kind('將'), Some(@xiangqi.King))
  assert_eq(@xiangqi.char_to_piece_kind('仕'), Some(@xiangqi.Advisor))
  assert_eq(@xiangqi.char_to_piece_kind('士'), Some(@xiangqi.Advisor))
  assert_eq(@xiangqi.char_to_piece_kind('马'), Some(@xiangqi.Horse))
  assert_eq(@xiangqi.char_to_piece_kind('車'), Some(@xiangqi.Rook))
  assert_eq(@xiangqi.char_to_piece_kind('炮'), Some(@xiangqi.Cannon))
  assert_eq(@xiangqi.char_to_piece_kind('卒'), Some(@xiangqi.Pawn))
  assert_true(@xiangqi.char_to_piece_kind('x') is None)
}

///|
test "palace membership helper" {
  // Red palace: files 3-5, ranks 0-2.
  assert_true(@xiangqi.Pos::new(4, 1).in_palace(@xiangqi.Red))
  assert_true(@xiangqi.Pos::new(3, 2).in_palace(@xiangqi.Red))
  assert_false(@xiangqi.Pos::new(2, 1).in_palace(@xiangqi.Red))
  assert_false(@xiangqi.Pos::new(4, 3).in_palace(@xiangqi.Red))
  // Black palace: files 3-5, ranks 7-9.
  assert_true(@xiangqi.Pos::new(4, 8).in_palace(@xiangqi.Black))
  assert_true(@xiangqi.Pos::new(5, 7).in_palace(@xiangqi.Black))
  assert_false(@xiangqi.Pos::new(4, 6).in_palace(@xiangqi.Black))
}

///|
test "side helpers" {
  let red : @xiangqi.Side = @xiangqi.Red
  let black : @xiangqi.Side = @xiangqi.Black
  assert_eq(red.opponent(), black)
  assert_eq(black.opponent(), red)
  assert_true(red.is_red())
  assert_false(black.is_red())
}

///|
test "advisor moves diagonally inside palace" {
  let board = @xiangqi.Board::empty()
    .with_piece(@xiangqi.Pos::new(4, 0), @xiangqi.Piece::red(@xiangqi.King))
    .with_piece(@xiangqi.Pos::new(4, 1), @xiangqi.Piece::red(@xiangqi.Advisor))
    .with_piece(@xiangqi.Pos::new(4, 9), @xiangqi.Piece::black(@xiangqi.King))
    .with_side(@xiangqi.Red)
  // Advisor on the palace center has exactly four diagonal targets.
  let moves = board.pseudo_moves_from(@xiangqi.Pos::new(4, 1))
  assert_eq(moves.length(), 4)
  for mv in moves {
    assert_true(mv.to.in_palace(@xiangqi.Red))
  }
}

///|
test "horse in the corner has two jumps" {
  let board = @xiangqi.Board::empty()
    .with_piece(@xiangqi.Pos::new(4, 0), @xiangqi.Piece::red(@xiangqi.King))
    .with_piece(@xiangqi.Pos::new(0, 0), @xiangqi.Piece::red(@xiangqi.Horse))
    .with_piece(@xiangqi.Pos::new(4, 9), @xiangqi.Piece::black(@xiangqi.King))
    .with_side(@xiangqi.Red)
  let moves = board.pseudo_moves_from(@xiangqi.Pos::new(0, 0))
  assert_eq(moves.length(), 2)
  assert_true(
    moves.contains(
      @xiangqi.Move::new(@xiangqi.Pos::new(0, 0), @xiangqi.Pos::new(1, 2)),
    ),
  )
  assert_true(
    moves.contains(
      @xiangqi.Move::new(@xiangqi.Pos::new(0, 0), @xiangqi.Pos::new(2, 1)),
    ),
  )
}

///|
test "pawn before the river only advances" {
  let board = @xiangqi.Board::empty()
    .with_piece(@xiangqi.Pos::new(4, 0), @xiangqi.Piece::red(@xiangqi.King))
    .with_piece(@xiangqi.Pos::new(4, 4), @xiangqi.Piece::red(@xiangqi.Pawn))
    .with_piece(@xiangqi.Pos::new(4, 9), @xiangqi.Piece::black(@xiangqi.King))
    .with_side(@xiangqi.Red)
  let moves = board.pseudo_moves_from(@xiangqi.Pos::new(4, 4))
  assert_eq(moves.length(), 1)
  assert_eq(moves[0].to, @xiangqi.Pos::new(4, 5))
}

///|
test "pawn across the river gains sideways moves" {
  let board = @xiangqi.Board::empty()
    .with_piece(@xiangqi.Pos::new(4, 0), @xiangqi.Piece::red(@xiangqi.King))
    .with_piece(@xiangqi.Pos::new(4, 5), @xiangqi.Piece::red(@xiangqi.Pawn))
    .with_piece(@xiangqi.Pos::new(4, 9), @xiangqi.Piece::black(@xiangqi.King))
    .with_side(@xiangqi.Red)
  let targets : Array[@xiangqi.Pos] = []
  for mv in board.pseudo_moves_from(@xiangqi.Pos::new(4, 5)) {
    targets.push(mv.to)
  }
  assert_true(targets.contains(@xiangqi.Pos::new(4, 6)))
  assert_true(targets.contains(@xiangqi.Pos::new(3, 5)))
  assert_true(targets.contains(@xiangqi.Pos::new(5, 5)))
  // Pawns never retreat.
  assert_false(targets.contains(@xiangqi.Pos::new(4, 4)))
}

///|
test "pinned piece may not leave the king's file" {
  // Red king e0, red rook e5, black king e9: the rook is pinned by the
  // flying-general rule, so every legal rook move stays on file e.
  let board = @xiangqi.Board::empty()
    .with_piece(@xiangqi.Pos::new(4, 0), @xiangqi.Piece::red(@xiangqi.King))
    .with_piece(@xiangqi.Pos::new(4, 5), @xiangqi.Piece::red(@xiangqi.Rook))
    .with_piece(@xiangqi.Pos::new(4, 9), @xiangqi.Piece::black(@xiangqi.King))
    .with_side(@xiangqi.Red)
  let rook_moves : Array[@xiangqi.Move] = []
  for mv in board.legal_moves() {
    if mv.from == @xiangqi.Pos::new(4, 5) {
      rook_moves.push(mv)
    }
  }
  assert_true(rook_moves.length() > 0)
  for mv in rook_moves {
    assert_eq(mv.to.file, 4)
  }
  // In particular the horizontal escapes are all filtered out.
  assert_false(
    rook_moves.contains(
      @xiangqi.Move::new(@xiangqi.Pos::new(4, 5), @xiangqi.Pos::new(0, 5)),
    ),
  )
}

///|
test "horse attack detection respects the leg" {
  // Black horse at f2 attacks red king e0 only while the leg at f1 is free.
  let with_leg = @xiangqi.Board::empty()
    .with_piece(@xiangqi.Pos::new(4, 0), @xiangqi.Piece::red(@xiangqi.King))
    .with_piece(@xiangqi.Pos::new(5, 2), @xiangqi.Piece::black(@xiangqi.Horse))
    .with_piece(@xiangqi.Pos::new(4, 9), @xiangqi.Piece::black(@xiangqi.King))
  assert_true(with_leg.is_attacked(@xiangqi.Pos::new(4, 0), @xiangqi.Black))
  let blocked = with_leg.with_piece(
    @xiangqi.Pos::new(5, 1),
    @xiangqi.Piece::red(@xiangqi.Pawn),
  )
  assert_false(blocked.is_attacked(@xiangqi.Pos::new(4, 0), @xiangqi.Black))
}

///|
test "cannon attack detection needs exactly one screen" {
  let king_only = @xiangqi.Board::empty()
    .with_piece(@xiangqi.Pos::new(4, 0), @xiangqi.Piece::red(@xiangqi.King))
    .with_piece(@xiangqi.Pos::new(4, 8), @xiangqi.Piece::black(@xiangqi.Cannon))
    .with_piece(@xiangqi.Pos::new(4, 9), @xiangqi.Piece::black(@xiangqi.King))
  // No screen between cannon and king: no attack.
  assert_false(king_only.is_attacked(@xiangqi.Pos::new(4, 0), @xiangqi.Black))
  // One screen: attack.
  let one_screen = king_only.with_piece(
    @xiangqi.Pos::new(4, 5),
    @xiangqi.Piece::black(@xiangqi.Pawn),
  )
  assert_true(one_screen.is_attacked(@xiangqi.Pos::new(4, 0), @xiangqi.Black))
  // Two screens: the second one shields the king again.
  let two_screens = one_screen.with_piece(
    @xiangqi.Pos::new(4, 2),
    @xiangqi.Piece::red(@xiangqi.Pawn),
  )
  assert_false(two_screens.is_attacked(@xiangqi.Pos::new(4, 0), @xiangqi.Black))
}

///|
test "pawn attack detection across the river" {
  // Black pawn on e1 has crossed the river: it attacks e0 forward and
  // the sideways squares d1/f1.
  let board = @xiangqi.Board::empty()
    .with_piece(@xiangqi.Pos::new(4, 0), @xiangqi.Piece::red(@xiangqi.King))
    .with_piece(@xiangqi.Pos::new(4, 1), @xiangqi.Piece::black(@xiangqi.Pawn))
    .with_piece(@xiangqi.Pos::new(0, 9), @xiangqi.Piece::black(@xiangqi.King))
  assert_true(board.is_attacked(@xiangqi.Pos::new(4, 0), @xiangqi.Black))
  assert_true(board.is_attacked(@xiangqi.Pos::new(3, 1), @xiangqi.Black))
  assert_false(board.is_attacked(@xiangqi.Pos::new(2, 1), @xiangqi.Black))
}

///|
test "capture updates piece count" {
  let board = @xiangqi.Board::empty()
    .with_piece(@xiangqi.Pos::new(4, 0), @xiangqi.Piece::red(@xiangqi.King))
    .with_piece(@xiangqi.Pos::new(4, 9), @xiangqi.Piece::black(@xiangqi.King))
    .with_piece(@xiangqi.Pos::new(0, 4), @xiangqi.Piece::red(@xiangqi.Rook))
    .with_piece(@xiangqi.Pos::new(0, 5), @xiangqi.Piece::black(@xiangqi.Pawn))
    .with_side(@xiangqi.Red)
  assert_eq(board.piece_count(), 4)
  let capture = @xiangqi.Move::new(
    @xiangqi.Pos::new(0, 4),
    @xiangqi.Pos::new(0, 5),
  )
  let next = board.apply_move(capture)
  assert_eq(next.piece_count(), 3)
  assert_eq(
    next.get(@xiangqi.Pos::new(0, 5)),
    Some(@xiangqi.Piece::red(@xiangqi.Rook)),
  )
}

///|
test "ongoing game has no result yet" {
  assert_eq(@xiangqi.Board::initial().result(), @xiangqi.Ongoing)
}

///|
test "iccs round trip for every opening move" {
  let board = @xiangqi.Board::initial()
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
  let board = @xiangqi.Board::empty()
    .with_piece(@xiangqi.Pos::new(0, 0), @xiangqi.Piece::red(@xiangqi.King))
    .with_piece(@xiangqi.Pos::new(4, 5), @xiangqi.Piece::red(@xiangqi.Rook))
    .with_piece(@xiangqi.Pos::new(4, 7), @xiangqi.Piece::red(@xiangqi.Rook))
    .with_piece(@xiangqi.Pos::new(8, 9), @xiangqi.Piece::black(@xiangqi.King))
    .with_side(@xiangqi.Red)
  // The rook nearer the enemy is the front one.
  assert_eq(
    board.move_to_chinese(
      @xiangqi.Move::new(@xiangqi.Pos::new(4, 7), @xiangqi.Pos::new(4, 8)),
    ),
    "前车进一",
  )
  assert_eq(
    board.move_to_chinese(
      @xiangqi.Move::new(@xiangqi.Pos::new(4, 5), @xiangqi.Pos::new(4, 4)),
    ),
    "后车退一",
  )
  // Both notations parse back to their original moves.
  match board.move_from_chinese("前车进一") {
    Ok(mv) =>
      assert_eq(
        mv,
        @xiangqi.Move::new(@xiangqi.Pos::new(4, 7), @xiangqi.Pos::new(4, 8)),
      )
    Err(e) => fail("front rook parse failed: \{e.to_string()}")
  }
  match board.move_from_chinese("后车退一") {
    Ok(mv) =>
      assert_eq(
        mv,
        @xiangqi.Move::new(@xiangqi.Pos::new(4, 5), @xiangqi.Pos::new(4, 4)),
      )
    Err(e) => fail("back rook parse failed: \{e.to_string()}")
  }
}
