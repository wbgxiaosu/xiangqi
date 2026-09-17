///|
/// Generate all pseudo-legal moves for the piece at `from`.
/// A pseudo-legal move follows the piece's movement pattern and does
/// not land on a friendly piece; it may leave the mover's own king in
/// check. Use `legal_moves` for fully validated moves.
pub fn Board::pseudo_moves_from(self : Board, from : Pos) -> Array[Move] {
  let moves = []
  match self.get(from) {
    Some(piece) => {
      match piece.kind {
        Rook => gen_rook(self, from, piece, moves)
        Cannon => gen_cannon(self, from, piece, moves)
        Horse => gen_horse(self, from, piece, moves)
        Elephant => gen_elephant(self, from, piece, moves)
        Advisor => gen_advisor(self, from, piece, moves)
        King => gen_king(self, from, piece, moves)
        Pawn => gen_pawn(self, from, piece, moves)
      }
      moves
    }
    None => moves
  }
}

///|
/// Generate all pseudo-legal moves for the side to move.
pub fn Board::pseudo_moves(self : Board) -> Array[Move] {
  let moves = []
  for pos in self.positions_of_side(self.side_to_move) {
    for mv in self.pseudo_moves_from(pos) {
      moves.push(mv)
    }
  }
  moves
}

///|
fn forward_step(side : Side) -> Int {
  if side.is_red() {
    1
  } else {
    -1
  }
}

///|
fn gen_rook(
  board : Board,
  from : Pos,
  piece : Piece,
  moves : Array[Move],
) -> Unit {
  let dirs = [(0, 1), (0, -1), (1, 0), (-1, 0)]
  for dir in dirs {
    let mut f = from.file + dir.0
    let mut r = from.rank + dir.1
    while Pos::new(f, r).is_valid() {
      let to = Pos::new(f, r)
      match board.get(to) {
        None => moves.push(Move::new(from, to))
        Some(target) => {
          if target.side != piece.side {
            moves.push(Move::new(from, to))
          }
          break
        }
      }
      f = f + dir.0
      r = r + dir.1
    }
  }
}

///|
/// A cannon moves like a rook when not capturing, but to capture it
/// must jump over exactly one piece (the screen) on the ray.
fn gen_cannon(
  board : Board,
  from : Pos,
  piece : Piece,
  moves : Array[Move],
) -> Unit {
  let dirs = [(0, 1), (0, -1), (1, 0), (-1, 0)]
  for dir in dirs {
    let mut f = from.file + dir.0
    let mut r = from.rank + dir.1
    let mut screen_seen = false
    while Pos::new(f, r).is_valid() {
      let to = Pos::new(f, r)
      match board.get(to) {
        None => if !screen_seen { moves.push(Move::new(from, to)) }
        Some(target) =>
          if !screen_seen {
            screen_seen = true
          } else {
            if target.side != piece.side {
              moves.push(Move::new(from, to))
            }
            break
          }
      }
      f = f + dir.0
      r = r + dir.1
    }
  }
}

///|
/// Horse move offsets paired with their blocking-leg offsets.
/// The leg is the orthogonal square the horse must pass through.
fn horse_offsets() -> Array[((Int, Int), (Int, Int))] {
  [
    ((1, 2), (0, 1)),
    ((-1, 2), (0, 1)),
    ((1, -2), (0, -1)),
    ((-1, -2), (0, -1)),
    ((2, 1), (1, 0)),
    ((2, -1), (1, 0)),
    ((-2, 1), (-1, 0)),
    ((-2, -1), (-1, 0)),
  ]
}

///|
fn gen_horse(
  board : Board,
  from : Pos,
  piece : Piece,
  moves : Array[Move],
) -> Unit {
  for pair in horse_offsets() {
    let (offset, leg) = pair
    let to = Pos::new(from.file + offset.0, from.rank + offset.1)
    if to.is_valid() {
      let leg_pos = Pos::new(from.file + leg.0, from.rank + leg.1)
      // 蹩马腿: the leg square must be empty.
      if board.get(leg_pos) is None {
        match board.get(to) {
          None => moves.push(Move::new(from, to))
          Some(target) =>
            if target.side != piece.side {
              moves.push(Move::new(from, to))
            }
        }
      }
    }
  }
}

///|
/// Elephant (bishop) moves two points diagonally and cannot cross the
/// river. The "eye" at the diagonal midpoint must be empty (塞象眼).
fn gen_elephant(
  board : Board,
  from : Pos,
  piece : Piece,
  moves : Array[Move],
) -> Unit {
  let offsets = [(2, 2), (2, -2), (-2, 2), (-2, -2)]
  for offset in offsets {
    let to = Pos::new(from.file + offset.0, from.rank + offset.1)
    if to.is_valid() && to.own_half(piece.side) {
      let eye = Pos::new(from.file + offset.0 / 2, from.rank + offset.1 / 2)
      if board.get(eye) is None {
        match board.get(to) {
          None => moves.push(Move::new(from, to))
          Some(target) =>
            if target.side != piece.side {
              moves.push(Move::new(from, to))
            }
        }
      }
    }
  }
}

///|
/// Advisor moves one point diagonally and must stay inside the palace.
fn gen_advisor(
  board : Board,
  from : Pos,
  piece : Piece,
  moves : Array[Move],
) -> Unit {
  let offsets = [(1, 1), (1, -1), (-1, 1), (-1, -1)]
  for offset in offsets {
    let to = Pos::new(from.file + offset.0, from.rank + offset.1)
    if to.is_valid() && to.in_palace(piece.side) {
      match board.get(to) {
        None => moves.push(Move::new(from, to))
        Some(target) =>
          if target.side != piece.side {
            moves.push(Move::new(from, to))
          }
      }
    }
  }
}

///|
/// King moves one point orthogonally inside the palace. The flying
/// general rule (kings facing each other on an open file) is handled
/// during legality filtering, not here.
fn gen_king(
  board : Board,
  from : Pos,
  piece : Piece,
  moves : Array[Move],
) -> Unit {
  let offsets = [(0, 1), (0, -1), (1, 0), (-1, 0)]
  for offset in offsets {
    let to = Pos::new(from.file + offset.0, from.rank + offset.1)
    if to.is_valid() && to.in_palace(piece.side) {
      match board.get(to) {
        None => moves.push(Move::new(from, to))
        Some(target) =>
          if target.side != piece.side {
            moves.push(Move::new(from, to))
          }
      }
    }
  }
}

///|
/// Pawn moves one point forward; after crossing the river it may also
/// move sideways, but never backwards.
fn gen_pawn(
  board : Board,
  from : Pos,
  piece : Piece,
  moves : Array[Move],
) -> Unit {
  let targets = []
  let forward = Pos::new(from.file, from.rank + forward_step(piece.side))
  targets.push(forward)
  if !from.own_half(piece.side) {
    targets.push(Pos::new(from.file - 1, from.rank))
    targets.push(Pos::new(from.file + 1, from.rank))
  }
  for to in targets {
    if to.is_valid() {
      match board.get(to) {
        None => moves.push(Move::new(from, to))
        Some(target) =>
          if target.side != piece.side {
            moves.push(Move::new(from, to))
          }
      }
    }
  }
}
