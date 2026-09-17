///|
/// Side of a piece or the player to move. Red moves first and
/// advances from rank 0 towards rank 9.
pub(all) enum Side {
  Red
  Black
} derive(Eq, Debug)

///|
/// The opposing side.
pub fn Side::opponent(self : Side) -> Side {
  match self {
    Red => Black
    Black => Red
  }
}

///|
pub fn Side::is_red(self : Side) -> Bool {
  self is Red
}

///|
/// The seven Xiangqi piece kinds.
pub(all) enum Kind {
  King
  Advisor
  Elephant
  Horse
  Rook
  Cannon
  Pawn
} derive(Eq, Debug)

///|
/// A single piece on the board.
pub struct Piece {
  side : Side
  kind : Kind
} derive(Eq, Debug)

///|
/// Constructors for the two sides.
pub fn Piece::red(kind : Kind) -> Piece {
  { side: Red, kind, }
}

///|
pub fn Piece::black(kind : Kind) -> Piece {
  { side: Black, kind, }
}

///|
/// Board position. `file` is 0..8 (files a..i, a on Red's left),
/// `rank` is 0..9 (rank 0 is Red's back rank, rank 9 is Black's).
pub struct Pos {
  file : Int
  rank : Int
} derive(Eq, Debug)

///|
pub fn Pos::new(file : Int, rank : Int) -> Pos {
  { file, rank, }
}

///|
/// True when the position lies on the 9x10 board.
pub fn Pos::is_valid(self : Pos) -> Bool {
  self.file >= 0 && self.file < 9 && self.rank >= 0 && self.rank < 10
}

///|
/// Linear index into the 90-square board array.
pub fn Pos::index(self : Pos) -> Int {
  self.rank * 9 + self.file
}

///|
/// True when the position is inside the palace of `side`.
pub fn Pos::in_palace(self : Pos, side : Side) -> Bool {
  if self.file >= 3 && self.file <= 5 {
    if side.is_red() {
      self.rank >= 0 && self.rank <= 2
    } else {
      self.rank >= 7 && self.rank <= 9
    }
  } else {
    false
  }
}

///|
/// True when the position is on `side`'s own half of the river.
/// The river lies between rank 4 and rank 5.
pub fn Pos::own_half(self : Pos, side : Side) -> Bool {
  if side.is_red() {
    self.rank <= 4
  } else {
    self.rank >= 5
  }
}

///|
/// A move from `from` to `to`.
pub struct Move {
  from : Pos
  to : Pos
} derive(Eq, Debug)

///|
pub fn Move::new(from : Pos, to : Pos) -> Move {
  { from, to, }
}
