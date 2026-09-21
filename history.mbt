// Game history for repetition and long-check adjudication.
//
// Chinese chess rules ( 中国象棋竞赛规则 ) forbid perpetual check:
// a side that checks on every one of its recent moves while the game
// loops through repeated positions loses. This layer tracks just
// enough history to adjudicate that: normalized position keys and a
// per-move check flag. It sits on top of the immutable Board and does
// not influence move generation.

///|
/// Position history recorder. Start with `new`, then `push` the board
/// after every move.
pub struct GameHistory {
  /// Normalized position keys (board layout + side to move), where
  /// `keys[0]` describes the starting position.
  keys : Array[String]
  /// `movers[i]` is the side that played the move leading to keys[i + 1].
  movers : Array[Side]
  /// `checks[i]` tells whether that move delivered check.
  checks : Array[Bool]
} derive(Eq, Debug)

///|
/// Normalize a board into a repetition key: the FEN board field plus
/// the side to move. Move counters are stripped on purpose — they do
/// not take part in repetition detection.
fn position_key(board : Board) -> String {
  let fen = board.to_fen()
  let sb = StringBuilder()
  let mut spaces = 0
  for ch in fen {
    if ch == ' ' {
      spaces = spaces + 1
      if spaces >= 2 {
        break
      }
    }
    sb.write_char(ch)
  }
  sb.to_string()
}

///|
/// Start a history from any position.
pub fn GameHistory::new(start : Board) -> GameHistory {
  {
    keys: [position_key(start)],
    movers: [],
    checks: [],
  }
}

///|
/// Record one played move by passing the board after the move. The
/// mover and the check flag are derived from the board itself.
pub fn GameHistory::push(self : GameHistory, after : Board) -> Unit {
  self.keys.push(position_key(after))
  self.movers.push(after.side().opponent())
  self.checks.push(after.in_check(after.side()))
}

///|
/// How many times the current (latest) position has occurred in the
/// recorded history, inclusive.
pub fn GameHistory::position_repetitions(self : GameHistory) -> Int {
  let mut count = 0
  let key = self.keys[self.keys.length() - 1]
  for k in self.keys {
    if k == key {
      count = count + 1
    }
  }
  count
}

///|
/// Length of the side's current streak of consecutive checking moves,
/// counted backwards from the latest position. Any own move that did
/// not give check resets the streak.
pub fn GameHistory::check_streak(self : GameHistory, side : Side) -> Int {
  let mut streak = 0
  let mut i = self.checks.length() - 1
  while i >= 0 {
    if self.movers[i] != side {
      i = i - 1
      continue
    }
    if self.checks[i] {
      streak = streak + 1
      i = i - 1
    } else {
      break
    }
  }
  streak
}

///|
/// Simplified long-check adjudication: a side violates the rule when
/// it has delivered check on at least `min_streak` consecutive own
/// moves while the current position has repeated at least `min_repeats`
/// times. Returns the offending side, if any. With the competition
/// thresholds this corresponds to 长将判负; callers decide the limits.
pub fn GameHistory::long_check_side(
  self : GameHistory,
  min_repeats : Int,
  min_streak : Int,
) -> Side? {
  let repeats = self.position_repetitions()
  if repeats < min_repeats {
    return None
  }
  for side in [Red, Black] {
    if self.check_streak(side) >= min_streak {
      return Some(side)
    }
  }
  None
}
