# yourname/xiangqi

中国象棋规则引擎 / A Xiangqi (Chinese Chess) rules engine in pure MoonBit.

- 完整走法生成（蹩马腿、塞象眼、炮架、过河兵、九宫约束）
- 将军 / 将死 / 困毙判定，含将帅照面（飞将）规则
- 中文纵线记谱（炮二平五、前车进一）与 ICCS 坐标双向转换
- XiangqiFEN 解析与生成
- Perft 验证：44 / 1920 / 79666，与公开参考值一致

```moonbit
let board = @xiangqi.Board::initial()
let mv = board.move_from_chinese("炮二平五").unwrap()  // h2e2
let next = board.apply_move(mv)
```

Run `moon run cmd/main` for a terminal demo. License: Apache-2.0.
