///|
/// Is `target` attacked by any piece of `attacker`? Includes rook,
/// cannon (with screen), horse (with leg check) and pawn attacks.
/// The flying-general rule is checked separately by `kings_facing`.
pub fn Board::is_attacked(self : Board, target : Pos, attacker : Side) -> Bool {
  if self.rook_attacks(target, attacker) {
    return true
  }
  if self.cannon_attacks(target, attacker) {
    return true
  }
  if self.horse_attacks(target, attacker) {
    return true
  }
  if self.pawn_attacks(target, attacker) {
    return true
  }
  false
}

///|
/// Rook-style line attack: the first piece seen on any ray from
/// `target` is an enemy rook.
fn Board::rook_attacks(self : Board, target : Pos, attacker : Side) -> Bool {
  let dirs = [(0, 1), (0, -1), (1, 0), (-1, 0)]
  for dir in dirs {
    let mut f = target.file + dir.0
    let mut r = target.rank + dir.1
    while Pos::new(f, r).is_valid() {
      match self.get(Pos::new(f, r)) {
        None => ()
        Some(p) =>
          if p.side == attacker && p.kind is Rook {
            return true
          } else {
            break
          }
      }
      f = f + dir.0
      r = r + dir.1
    }
  }
  false
}

///|
/// Cannon attack: past the first screen on a ray, the first piece
/// found is an enemy cannon.
fn Board::cannon_attacks(self : Board, target : Pos, attacker : Side) -> Bool {
  let dirs = [(0, 1), (0, -1), (1, 0), (-1, 0)]
  for dir in dirs {
    let mut f = target.file + dir.0
    let mut r = target.rank + dir.1
    let mut screen_seen = false
    while Pos::new(f, r).is_valid() {
      match self.get(Pos::new(f, r)) {
        None => ()
        Some(p) =>
          if !screen_seen {
            screen_seen = true
          } else {
            if p.side == attacker && p.kind is Cannon {
              return true
            }
            break
          }
      }
      f = f + dir.0
      r = r + dir.1
    }
  }
  false
}

///|
/// Horse attack. The blocking leg sits next to the *attacking* horse,
/// so from the target we check the leg square adjacent to the
/// candidate horse position.
fn Board::horse_attacks(self : Board, target : Pos, attacker : Side) -> Bool {
  for pair in horse_offsets() {
    let (offset, leg) = pair
    // Horse at (target - offset) attacks target if its leg is empty.
    let horse_pos = Pos::new(target.file - offset.0, target.rank - offset.1)
    if horse_pos.is_valid() {
      match self.get(horse_pos) {
        Some(p) =>
          if p.side == attacker && p.kind is Horse {
            let leg_pos = Pos::new(
              horse_pos.file + leg.0,
              horse_pos.rank + leg.1,
            )
            if self.get(leg_pos) is None {
              return true
            }
          }
        None => ()
      }
    }
  }
  false
}

///|
/// Pawn attack: an enemy pawn directly in front of `target`, or on
/// either side once that pawn has crossed the river.
fn Board::pawn_attacks(self : Board, target : Pos, attacker : Side) -> Bool {
  // Pawn directly in front (from the attacker's perspective).
  let front = Pos::new(target.file, target.rank - forward_step(attacker))
  if front.is_valid() {
    match self.get(front) {
      Some(p) => if p.side == attacker && p.kind is Pawn { return true }
      None => ()
    }
  }
  // Pawns on the flanks, but only after they have crossed the river.
  for df in [-1, 1] {
    let side_pos = Pos::new(target.file + df, target.rank)
    if side_pos.is_valid() {
      match self.get(side_pos) {
        Some(p) =>
          if p.side == attacker &&
            p.kind is Pawn &&
            !side_pos.own_half(attacker) {
            return true
          }
        None => ()
      }
    }
  }
  false
}

///|
/// The flying-general rule: the two kings face each other on the same
/// file with no piece in between. Such a position is illegal for the
/// side that just moved.
pub fn Board::kings_facing(self : Board) -> Bool {
  let red_king = self.find_king(Red)
  let black_king = self.find_king(Black)
  match (red_king, black_king) {
    (Some(rk), Some(bk)) =>
      if rk.file == bk.file {
        let mut r = rk.rank + 1
        while r < bk.rank {
          if self.get(Pos::new(rk.file, r)) is Some(_) {
            return false
          }
          r = r + 1
        }
        true
      } else {
        false
      }
    _ => false
  }
}

///|
/// Is the king of `side` in check (including the flying-general rule)?
pub fn Board::in_check(self : Board, side : Side) -> Bool {
  match self.find_king(side) {
    Some(king_pos) =>
      self.is_attacked(king_pos, side.opponent()) || self.kings_facing()
    None => false
  }
}

///|
/// All fully legal moves for the side to move: pseudo-legal moves that
/// leave the mover's own king safe (not in check, kings not facing).
pub fn Board::legal_moves(self : Board) -> Array[Move] {
  let result = []
  let side = self.side_to_move
  for mv in self.pseudo_moves() {
    let next = self.apply_move(mv)
    if !next.in_check(side) {
      result.push(mv)
    }
  }
  result
}

///|
/// Outcome of a position from the perspective of the game.
pub(all) enum GameResult {
  /// The game is still in progress.
  Ongoing
  /// Red has won (checkmate or stalemate against Black).
  RedWins
  /// Black has won (checkmate or stalemate against Red).
  BlackWins
} derive(Eq, Debug)

///|
/// Evaluate the game status. In Xiangqi, a side with no legal moves
/// loses whether or not it is in check (困毙 counts as a loss).
pub fn Board::result(self : Board) -> GameResult {
  let side = self.side_to_move
  if self.legal_moves().length() == 0 {
    if side.is_red() {
      BlackWins
    } else {
      RedWins
    }
  } else {
    Ongoing
  }
}

///|
/// True when the side to move is checkmated (in check with no legal
/// response). Use `Board::result` for the complete outcome.
pub fn Board::is_checkmate(self : Board) -> Bool {
  let side = self.side_to_move
  self.in_check(side) && self.legal_moves().length() == 0
}

///|
/// True when the side to move is stalemated (no legal moves while not
/// in check — 困毙, which loses in Xiangqi).
pub fn Board::is_stalemate(self : Board) -> Bool {
  let side = self.side_to_move
  !self.in_check(side) && self.legal_moves().length() == 0
}

///|
/// Perft: count leaf nodes of the legal move tree to `depth`.
/// Used to validate move generation against known reference counts.
pub fn perft(board : Board, depth : Int) -> Int {
  if depth <= 0 {
    return 1
  }
  let moves = board.legal_moves()
  if depth == 1 {
    return moves.length()
  }
  let mut total = 0
  for mv in moves {
    total = total + perft(board.apply_move(mv), depth - 1)
  }
  total
}
