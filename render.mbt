///|
/// Render one rank row with pieces or dots.
fn render_rank(board : Board, rank : Int) -> String {
  let sb = StringBuilder()
  sb.write_string(num_label(rank))
  sb.write_string(" ")
  for file in 0..<9 {
    match board.get(Pos::new(file, rank)) {
      Some(piece) => sb.write_string(display_char(piece))
      None => sb.write_string("・")
    }
    if file < 8 {
      sb.write_string(" ")
    }
  }
  sb.write_string("\n")
  sb.to_string()
}

///|
/// Piece glyph for terminal display; traditional characters make the
/// two sides visually distinct.
fn display_char(piece : Piece) -> String {
  match piece.kind {
    King => if piece.side.is_red() { "帅" } else { "將" }
    Advisor => if piece.side.is_red() { "仕" } else { "士" }
    Elephant => if piece.side.is_red() { "相" } else { "象" }
    Horse => if piece.side.is_red() { "馬" } else { "马" }
    Rook => if piece.side.is_red() { "車" } else { "车" }
    Cannon => if piece.side.is_red() { "炮" } else { "砲" }
    Pawn => if piece.side.is_red() { "兵" } else { "卒" }
  }
}

///|
/// Rank label: Arabic digits 0-9 (rank 0 = Red's back rank).
fn num_label(rank : Int) -> String {
  rank.to_string()
}

///|
/// Full board rendering including river and side-to-move caption.
pub fn Board::render_board(self : Board) -> String {
  let sb = StringBuilder()
  let mut rank = 9
  while rank >= 0 {
    sb.write_string(render_rank(self, rank))
    if rank == 5 {
      sb.write_string("  ～ 楚 河 ～ 汉 界 ～\n")
    }
    rank = rank - 1
  }
  sb.write_string("   a b c d e f g h i\n")
  sb.write_string(
    if self.side_to_move.is_red() {
      "轮到红方\n"
    } else {
      "轮到黑方\n"
    },
  )
  sb.to_string()
}
