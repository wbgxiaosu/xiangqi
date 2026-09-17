///|
/// The 9x10 Xiangqi board plus game state metadata.
///
/// Squares are stored row-major with rank 0 (Red's back rank) first,
/// so `squares[pos.index()]` is the piece at `pos` (or `None` if empty).
pub struct Board {
  squares : Array[Piece?]
  side_to_move : Side
  /// Number of full moves played, starting from 1.
  move_number : Int
} derive(Eq, Debug)

///|
/// Build a board from a mutable square array.
pub fn Board::of_squares(
  squares : Array[Piece?],
  side_to_move : Side,
  move_number : Int,
) -> Board {
  { squares, side_to_move, move_number, }
}

///|
/// The piece at `pos`, or `None` when the square is empty.
pub fn Board::get(self : Board, pos : Pos) -> Piece? {
  if pos.is_valid() {
    self.squares[pos.index()]
  } else {
    None
  }
}

///|
/// The side whose turn it is.
pub fn Board::side(self : Board) -> Side {
  self.side_to_move
}

///|
/// Locate the king of `side`. Kings are always on the board in
/// legal Xiangqi positions; returns `None` only for malformed boards.
pub fn Board::find_king(self : Board, side : Side) -> Pos? {
  let (lo, hi) = if side.is_red() { (0, 2) } else { (7, 9) }
  for rank in lo..<=hi {
    for file in 3..<=5 {
      let pos = Pos::new(file, rank)
      match self.get(pos) {
        Some(p) => if p.side == side && p.kind is King { return Some(pos) }
        None => ()
      }
    }
  }
  None
}

///|
/// An empty board with Red to move. Combine with `with`, `without`
/// and `with_side` to construct custom test positions.
pub fn Board::empty() -> Board {
  let squares : Array[Piece?] = Array::make(90, None)
  { squares, side_to_move: Red, move_number: 1, }
}

///|
/// The classic starting position. Red is at the bottom (ranks 0-4),
/// Black at the top (ranks 5-9). Red moves first.
pub fn Board::initial() -> Board {
  let squares : Array[Piece?] = Array::make(90, None)
  let back = [
    Rook,
    Horse,
    Elephant,
    Advisor,
    King,
    Advisor,
    Elephant,
    Horse,
    Rook,
  ]
  // Back ranks
  for file in 0..<9 {
    squares[Pos::new(file, 0).index()] = Some(Piece::red(back[file]))
    squares[Pos::new(file, 9).index()] = Some(Piece::black(back[file]))
  }
  // Cannons on files b and h
  for file in [1, 7] {
    squares[Pos::new(file, 2).index()] = Some(Piece::red(Cannon))
    squares[Pos::new(file, 7).index()] = Some(Piece::black(Cannon))
  }
  // Pawns on files a, c, e, g, i
  for file in [0, 2, 4, 6, 8] {
    squares[Pos::new(file, 3).index()] = Some(Piece::red(Pawn))
    squares[Pos::new(file, 6).index()] = Some(Piece::black(Pawn))
  }
  { squares, side_to_move: Red, move_number: 1, }
}

///|
/// Copy the square array (shared by the mutator helpers below).
fn Board::copy_squares(self : Board) -> Array[Piece?] {
  let squares = Array::make(90, None)
  for i in 0..<90 {
    squares[i] = self.squares[i]
  }
  squares
}

///|
/// Apply a move and return the resulting board. The receiver is left
/// untouched. This function trusts that the move is pseudo-legal;
/// use `legal_moves` / `move_from_*` for validated play.
pub fn Board::apply_move(self : Board, mv : Move) -> Board {
  let squares = self.copy_squares()
  squares[mv.from.index()] = None
  squares[mv.to.index()] = self.get(mv.from)
  let next_side = self.side_to_move.opponent()
  let move_number = if self.side_to_move.is_red() {
    self.move_number
  } else {
    self.move_number + 1
  }
  { squares, side_to_move: next_side, move_number, }
}

///|
/// Remove the piece at `pos` (for constructing custom positions).
pub fn Board::without(self : Board, pos : Pos) -> Board {
  let squares = self.copy_squares()
  squares[pos.index()] = None
  { squares, side_to_move: self.side_to_move, move_number: self.move_number, }
}

///|
/// Place or replace a piece at `pos` (for constructing custom positions).
pub fn Board::with_piece(self : Board, pos : Pos, piece : Piece) -> Board {
  let squares = self.copy_squares()
  squares[pos.index()] = Some(piece)
  { squares, side_to_move: self.side_to_move, move_number: self.move_number, }
}

///|
/// Set the side to move (for constructing custom positions).
pub fn Board::with_side(self : Board, side : Side) -> Board {
  { ..self, side_to_move: side, }
}

///|
/// Count all pieces currently on the board.
pub fn Board::piece_count(self : Board) -> Int {
  let mut n = 0
  for i in 0..<90 {
    if self.squares[i] is Some(_) {
      n = n + 1
    }
  }
  n
}

///|
/// Collect every position occupied by a piece of `side` and `kind`.
pub fn Board::positions_of(
  self : Board,
  side : Side,
  kind : Kind,
) -> Array[Pos] {
  let result = []
  for i in 0..<90 {
    match self.squares[i] {
      Some(p) =>
        if p.side == side && p.kind == kind {
          let rank = i / 9
          let file = i % 9
          result.push(Pos::new(file, rank))
        }
      None => ()
    }
  }
  result
}

///|
/// Collect every position occupied by a piece of `side`.
pub fn Board::positions_of_side(self : Board, side : Side) -> Array[Pos] {
  let result = []
  for i in 0..<90 {
    match self.squares[i] {
      Some(p) =>
        if p.side == side {
          let rank = i / 9
          let file = i % 9
          result.push(Pos::new(file, rank))
        }
      None => ()
    }
  }
  result
}
