///|
/// Chinese numeral for 1..9 in Red's notation.
fn red_num(n : Int) -> String {
  match n {
    1 => "一"
    2 => "二"
    3 => "三"
    4 => "四"
    5 => "五"
    6 => "六"
    7 => "七"
    8 => "八"
    9 => "九"
    _ => "?"
  }
}

///|
/// Characters used for a piece in Chinese notation.
fn piece_char(piece : Piece) -> String {
  match piece.kind {
    King => if piece.side.is_red() { "帅" } else { "将" }
    Advisor => if piece.side.is_red() { "仕" } else { "士" }
    Elephant => if piece.side.is_red() { "相" } else { "象" }
    Horse => "马"
    Rook => "车"
    Cannon => "炮"
    Pawn => if piece.side.is_red() { "兵" } else { "卒" }
  }
}

///|
/// Map a notation character to a piece kind (accepts simplified and
/// traditional variants used by common software).
pub fn char_to_piece_kind(ch : Char) -> Kind? {
  match ch {
    '帅' | '将' | '將' => Some(King)
    '仕' | '士' => Some(Advisor)
    '相' | '象' => Some(Elephant)
    '马' | '馬' | '傌' => Some(Horse)
    '车' | '車' | '俥' => Some(Rook)
    '炮' | '砲' | '包' => Some(Cannon)
    '兵' | '卒' => Some(Pawn)
    _ => None
  }
}

///|
/// File number in the side's own notation. Red counts 一..九 from its
/// right (file i is 一); Black counts 1..9 from its right (file a is 1).
fn file_num(file : Int, side : Side) -> Int {
  if side.is_red() {
    9 - file
  } else {
    file + 1
  }
}

///|
/// Render a file/step number in the side's numeral system.
fn num_string(n : Int, side : Side) -> String {
  if side.is_red() {
    red_num(n)
  } else {
    n.to_string()
  }
}

///|
/// Kind-aware same-file disambiguation applies to rook, horse,
/// cannon and pawn only.
fn needs_disambiguation(kind : Kind) -> Bool {
  match kind {
    Rook | Cannon | Horse | Pawn => true
    King | Advisor | Elephant => false
  }
}

///|
/// How many same-side pieces of `kind` share `file` (including the
/// piece at `from` itself).
fn same_file_count(board : Board, from : Pos, piece : Piece) -> Int {
  let mut n = 0
  for rank in 0..<10 {
    match board.get(Pos::new(from.file, rank)) {
      Some(p) => if p.side == piece.side && p.kind == piece.kind { n = n + 1 }
      None => ()
    }
  }
  n
}

///|
/// Prefix (前/中/后) for a piece among its same-file twins. Front
/// means closest to the enemy. For more than three pieces the middle
/// ones all render as 中 (a documented approximation for degenerate
/// positions with 4+ stacked pawns).
fn same_file_prefix(board : Board, from : Pos, piece : Piece) -> String {
  let mut ahead = 0
  let mut behind = 0
  for rank in 0..<10 {
    match board.get(Pos::new(from.file, rank)) {
      Some(p) =>
        if p.side == piece.side && p.kind == piece.kind {
          if piece.side.is_red() {
            if rank > from.rank {
              ahead = ahead + 1
            } else if rank < from.rank {
              behind = behind + 1
            }
          } else if rank < from.rank {
            ahead = ahead + 1
          } else if rank > from.rank {
            behind = behind + 1
          }
        }
      None => ()
    }
  }
  if ahead == 0 {
    "前"
  } else if behind == 0 {
    "后"
  } else {
    "中"
  }
}

///|
/// Render a move in Chinese file notation (中文纵线记谱法), e.g.
/// `炮二平五`, `马8进7`, `前车进一`. The board is required for
/// disambiguation. Works for both the side to move and (for analysis
/// tooling) the opposite side, as long as the moving piece belongs to
/// `board.side_to_move` in the common case.
pub fn Board::move_to_chinese(self : Board, mv : Move) -> String {
  let sb = StringBuilder()
  match self.get(mv.from) {
    Some(piece) => {
      let side = piece.side
      let kind = piece.kind
      let ambiguous = needs_disambiguation(kind) &&
        same_file_count(self, mv.from, piece) >= 2
      if ambiguous {
        sb.write_string(same_file_prefix(self, mv.from, piece))
        sb.write_string(piece_char(piece))
      } else {
        sb.write_string(piece_char(piece))
        sb.write_string(num_string(file_num(mv.from.file, side), side))
      }
      if mv.to.file == mv.from.file {
        // Straight move: 进/退 + number of steps.
        let dr = mv.to.rank - mv.from.rank
        if dr == 0 {
          sb.write_string("平")
        } else {
          let forward = if side.is_red() { dr > 0 } else { dr < 0 }
          sb.write_string(if forward { "进" } else { "退" })
          let steps = if dr < 0 { -dr } else { dr }
          sb.write_string(num_string(steps, side))
        }
      } else if mv.to.rank == mv.from.rank {
        // Sideways: 平 + destination file.
        sb.write_string("平")
        sb.write_string(num_string(file_num(mv.to.file, side), side))
      } else {
        // Diagonal movers (horse/advisor/elephant): 进/退 + destination file.
        let dr = mv.to.rank - mv.from.rank
        let forward = if side.is_red() { dr > 0 } else { dr < 0 }
        sb.write_string(if forward { "进" } else { "退" })
        sb.write_string(num_string(file_num(mv.to.file, side), side))
      }
      sb.to_string()
    }
    None => ""
  }
}

///|
/// Errors from coordinate parsing.
pub enum NotationError {
  /// The notation does not match any legal move of the side to move.
  IllegalOrUnknown(String)
  /// The ICCS coordinate string is malformed (expected 4 chars).
  BadIccs(String)
} derive(Eq, Debug)

///|
/// Human-readable rendering of a notation error (for messages and tests).
pub fn NotationError::to_string(self : NotationError) -> String {
  match self {
    IllegalOrUnknown(s) => "IllegalOrUnknown(\{s})"
    BadIccs(s) => "BadIccs(\{s})"
  }
}

///|
/// Interpret a Chinese notation string against the current position.
/// The implementation generates the notation of every legal move and
/// selects the exact match, which guarantees round-trip consistency.
pub fn Board::move_from_chinese(
  self : Board,
  notation : String,
) -> Result[Move, NotationError] {
  for mv in self.legal_moves() {
    if self.move_to_chinese(mv) == notation {
      return Ok(mv)
    }
  }
  Err(IllegalOrUnknown(notation))
}

///|
/// Render a move in ICCS coordinate notation, e.g. `h2e2`.
/// Files are `a`..`i` (a on Red's left), ranks `0`..`9`
/// (0 is Red's back rank).
pub fn Board::move_to_iccs(_self : Board, mv : Move) -> String {
  let sb = StringBuilder()
  sb.write_char(('a'.to_int() + mv.from.file).unsafe_to_char())
  sb.write_char(('0'.to_int() + mv.from.rank).unsafe_to_char())
  sb.write_char(('a'.to_int() + mv.to.file).unsafe_to_char())
  sb.write_char(('0'.to_int() + mv.to.rank).unsafe_to_char())
  sb.to_string()
}

///|
/// Parse an ICCS coordinate string into a move, validating that it is
/// legal in the current position.
pub fn Board::move_from_iccs(
  self : Board,
  iccs : String,
) -> Result[Move, NotationError] {
  if iccs.length() != 4 {
    return Err(BadIccs(iccs))
  }
  let chars : Array[Char] = []
  for ch in iccs {
    chars.push(ch)
  }
  let f1 = chars[0].to_int() - 'a'.to_int()
  let r1 = chars[1].to_int() - '0'.to_int()
  let f2 = chars[2].to_int() - 'a'.to_int()
  let r2 = chars[3].to_int() - '0'.to_int()
  if f1 < 0 ||
    f1 > 8 ||
    f2 < 0 ||
    f2 > 8 ||
    r1 < 0 ||
    r1 > 9 ||
    r2 < 0 ||
    r2 > 9 {
    return Err(BadIccs(iccs))
  }
  let mv = Move::new(Pos::new(f1, r1), Pos::new(f2, r2))
  for legal in self.legal_moves() {
    if legal == mv {
      return Ok(mv)
    }
  }
  Err(IllegalOrUnknown(iccs))
}
