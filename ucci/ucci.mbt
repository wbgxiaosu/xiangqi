// UCCI (Universal Chinese Chess Protocol) adapter.
//
// Bridges the rules engine to the command dialect spoken by Chinese
// chess interfaces and engines ( ElephantEye and friends ). The layer
// is deliberately small: it turns `position` commands into Board
// values and formats moves in UCCI coordinate notation. Search and
// time management stay outside on purpose — those belong to engines.

///|
/// Errors from UCCI command handling.
pub enum UcciError {
  /// The line is not a well-formed `position` command.
  BadCommand(String)
  /// The embedded FEN string could not be parsed.
  BadFen(String)
  /// A move in the moves list is malformed or illegal in the position.
  BadMove(String)
} derive(Eq, Debug)

///|
/// Human-readable rendering of a UCCI error (for messages and tests).
pub fn UcciError::to_string(self : UcciError) -> String {
  match self {
    BadCommand(s) => "BadCommand(\{s})"
    BadFen(s) => "BadFen(\{s})"
    BadMove(s) => "BadMove(\{s})"
  }
}

///|
/// Split a command line on whitespace, dropping empty tokens.
fn tokenize(line : String) -> Array[String] {
  let tokens : Array[String] = []
  let current = StringBuilder()
  for ch in line {
    if ch == ' ' || ch == '\t' || ch == '\r' || ch == '\n' {
      let word = current.to_string()
      if word.length() > 0 {
        tokens.push(word)
      }
      let _ = current.reset()
    } else {
      current.write_char(ch)
    }
  }
  let word = current.to_string()
  if word.length() > 0 {
    tokens.push(word)
  }
  tokens
}

///|
fn join_tokens(parts : Array[String], sep : String) -> String {
  let sb = StringBuilder()
  for i, part in parts {
    if i > 0 {
      sb.write_string(sep)
    }
    sb.write_string(part)
  }
  sb.to_string()
}

///|
/// Render a position in UCCI coordinate notation, e.g. `h2e2`.
/// UCCI uses the same file/rank convention as ICCS.
pub fn move_to_ucci(mv : @xiangqi.Move) -> String {
  let sb = StringBuilder()
  sb.write_char(('a'.to_int() + mv.from.file).unsafe_to_char())
  sb.write_char(('0'.to_int() + mv.from.rank).unsafe_to_char())
  sb.write_char(('a'.to_int() + mv.to.file).unsafe_to_char())
  sb.write_char(('0'.to_int() + mv.to.rank).unsafe_to_char())
  sb.to_string()
}

///|
/// Parse a UCCI `position` command into a board.
///
/// Supported forms:
/// - `position startpos`
/// - `position startpos moves h2e2 h9g7 ...`
/// - `position fen <fen> [moves h2e2 h9g7 ...]`
///
/// The moves are applied one by one; every move must be legal in the
/// position it is played in, otherwise `BadMove` is returned.
pub fn parse_position(line : String) -> Result[@xiangqi.Board, UcciError] {
  let tokens = tokenize(line)
  if tokens.length() < 2 || tokens[0] != "position" {
    return Err(BadCommand(line))
  }
  let mut i = 1
  let base : @xiangqi.Board = if tokens[i] == "startpos" {
    i = i + 1
    @xiangqi.Board::initial()
  } else if tokens[i] == "fen" {
    i = i + 1
    let fields : Array[String] = []
    while i < tokens.length() && tokens[i] != "moves" {
      fields.push(tokens[i])
      i = i + 1
    }
    let fen = join_tokens(fields, " ")
    match @xiangqi.parse_fen(fen) {
      Ok(b) => b
      Err(e) => return Err(BadFen(e.to_string()))
    }
  } else {
    return Err(BadCommand(line))
  }
  if i < tokens.length() && tokens[i] == "moves" {
    i = i + 1
    let mut current = base
    while i < tokens.length() {
      let mv = match current.move_from_iccs(tokens[i]) {
        Ok(m) => m
        Err(_) => return Err(BadMove(tokens[i]))
      }
      current = current.apply_move(mv)
      i = i + 1
    }
    return Ok(current)
  }
  Ok(base)
}

///|
/// Validate a whitespace-separated list of UCCI moves against a board,
/// returning each move in order. Useful for engines replaying a moves
/// line without going through `parse_position`.
pub fn validate_move_line(
  board : @xiangqi.Board,
  moves : String,
) -> Result[Array[@xiangqi.Move], UcciError] {
  let tokens = tokenize(moves)
  let result : Array[@xiangqi.Move] = []
  let mut current = board
  for token in tokens {
    let mv = match current.move_from_iccs(token) {
      Ok(m) => m
      Err(_) => return Err(BadMove(token))
    }
    result.push(mv)
    current = current.apply_move(mv)
  }
  Ok(result)
}
