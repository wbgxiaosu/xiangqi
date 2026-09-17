///|
/// Errors produced while parsing a FEN string.
pub enum FenError {
  /// The string does not have 4+ space-separated fields.
  BadFieldCount
  /// The board layout field is malformed.
  BadBoard(String)
  /// The side-to-move field is not `w` or `b`.
  BadSide(String)
  /// The move number field is not a non-negative integer.
  BadMoveNumber(String)
} derive(Eq, Show, Debug)

///|
fn char_to_kind(c : Char) -> Kind? {
  match c {
    'K' | 'k' => Some(King)
    'A' | 'a' => Some(Advisor)
    'B' | 'b' | 'E' | 'e' => Some(Elephant)
    'N' | 'n' | 'H' | 'h' => Some(Horse)
    'R' | 'r' => Some(Rook)
    'C' | 'c' => Some(Cannon)
    'P' | 'p' => Some(Pawn)
    _ => None
  }
}

///|
fn is_upper(c : Char) -> Bool {
  c >= 'A' && c <= 'Z'
}

///|
fn digit_value(c : Char) -> Int {
  c.to_int() - '0'.to_int()
}

///|
/// Split a string on a single separator character.
fn split_char(s : String, sep : Char) -> Array[String] {
  let parts = []
  let mut current = StringBuilder()
  for ch in s {
    if ch == sep {
      parts.push(current.to_string())
      current = StringBuilder()
    } else {
      current.write_char(ch)
    }
  }
  parts.push(current.to_string())
  parts
}

///|
/// Split a string on single spaces (FEN separator).
fn split_spaces(s : String) -> Array[String] {
  let raw = split_char(s, ' ')
  let parts = []
  for p in raw {
    if p.length() > 0 {
      parts.push(p)
    }
  }
  parts
}

///|
/// Parse a Xiangqi FEN string, e.g.
/// `"rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1"`.
///
/// Ranks are listed top-down: the first row is rank 9 (Black's back
/// rank), the last row is rank 0 (Red's back rank). Letters are
/// standard XiangqiFEN: `k a b n r c p` (case = side). The second
/// field is `w` (Red) or `b` (Black); the last field, when present,
/// is the full-move number.
pub fn parse_fen(fen : String) -> Result[Board, FenError] {
  let parts = split_spaces(fen)
  if parts.length() < 2 {
    return Err(BadFieldCount)
  }
  // Board layout
  let rows = split_char(parts[0], '/')
  if rows.length() != 10 {
    return Err(BadBoard(parts[0]))
  }
  let squares : Array[Piece?] = Array::make(90, None)
  for row_idx in 0..<10 {
    let rank = 9 - row_idx
    let row = rows[row_idx]
    let mut file = 0
    for ch in row {
      if ch >= '1' && ch <= '9' {
        file = file + digit_value(ch)
      } else {
        match char_to_kind(ch) {
          Some(kind) => {
            if file > 8 {
              return Err(BadBoard(row))
            }
            let side = if is_upper(ch) { Red } else { Black }
            squares[Pos::new(file, rank).index()] = Some(Piece::{ side, kind, })
            file = file + 1
          }
          None => return Err(BadBoard(row))
        }
      }
    }
    if file != 9 {
      return Err(BadBoard(row))
    }
  }
  // Side to move
  let side = match parts[1] {
    "w" | "r" => Red
    "b" => Black
    other => return Err(BadSide(other))
  }
  // Move number (last field when present)
  let move_number = if parts.length() >= 5 {
    let field = parts[parts.length() - 1]
    match parse_int(field) {
      Some(n) => n
      None => return Err(BadMoveNumber(field))
    }
  } else {
    1
  }
  Ok(Board::of_squares(squares, side, move_number))
}

///|
fn parse_int(s : String) -> Int? {
  if s.length() == 0 {
    return None
  }
  let mut n = 0
  for ch in s {
    if ch < '0' || ch > '9' {
      return None
    }
    n = n * 10 + digit_value(ch)
  }
  Some(n)
}

///|
/// Render a board as a FEN string in standard layout.
pub fn Board::to_fen(self : Board) -> String {
  let sb = StringBuilder()
  for row_idx in 0..<10 {
    let rank = 9 - row_idx
    if row_idx > 0 {
      sb.write_char('/')
    }
    let mut empties = 0
    for file in 0..<9 {
      match self.get(Pos::new(file, rank)) {
        Some(piece) => {
          if empties > 0 {
            sb.write_char(digit_char(empties))
            empties = 0
          }
          sb.write_char(fen_char(piece))
        }
        None => empties = empties + 1
      }
    }
    if empties > 0 {
      sb.write_char(digit_char(empties))
    }
  }
  sb.write_char(' ')
  sb.write_string(if self.side_to_move.is_red() { "w" } else { "b" })
  sb.write_string(" - - ")
  sb.write_string(self.move_number.to_string())
  sb.to_string()
}

///|
fn digit_char(n : Int) -> Char {
  // n is always 1..9 here.
  ('0'.to_int() + n).unsafe_to_char()
}

///|
fn fen_char(piece : Piece) -> Char {
  let c = match piece.kind {
    King => 'k'
    Advisor => 'a'
    Elephant => 'b'
    Horse => 'n'
    Rook => 'r'
    Cannon => 'c'
    Pawn => 'p'
  }
  if piece.side.is_red() {
    (c.to_int() - 32).unsafe_to_char()
  } else {
    c
  }
}
