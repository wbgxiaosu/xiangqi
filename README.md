# xiangqi · MoonBit 中国象棋规则引擎库

[![mooncakes.io](https://img.shields.io/badge/mooncakes-wbgxiaosu%2Fxiangqi-8b5cf6)](https://mooncakes.io/docs/wbgxiaosu/xiangqi)
[![CI](https://github.com/wbgxiaosu/xiangqi/actions/workflows/ci.yml/badge.svg)](https://github.com/wbgxiaosu/xiangqi/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue)](./LICENSE)

MoonBit 生态的中国象棋**规则基础库**：零依赖、纯逻辑、可编译到 `wasm-gc` / `js` / `native` 全后端。它不绑定任何界面与运行方式，只负责回答两个问题——**哪些走法合法，走完之后局面处于什么状态**。AI 引擎、对弈平台、教学软件、棋谱工具，都以它为规则内核，不必各自重写蹩马腿、塞象眼、将帅照面这些细节。

## 安装

```bash
moon add wbgxiaosu/xiangqi
```

## API 一览

公共接口由 `moon info` 生成的 [`pkg.generated.mbti`](./pkg.generated.mbti) 定义，类型安全、所见即所得：

| 能力 | API |
|---|---|
| 合法走法生成 | `Board::legal_moves` / `pseudo_moves` / `pseudo_moves_from` |
| 局面状态判定 | `in_check` / `is_checkmate` / `is_stalemate` / `kings_facing` / `result` |
| 中文纵线记谱 | `move_from_chinese` / `move_to_chinese`（炮二平五、前车进一） |
| ICCS 坐标记谱 | `move_from_iccs` / `move_to_iccs`（h2e2 风格） |
| FEN 导入导出 | `parse_fen` / `Board::to_fen`（XiangqiFEN 标准） |
| 走法生成验证 | `perft` |
| 棋盘结构操作 | `Board::get` / `with_piece` / `without` / `piece_count` 等 |

## 用法示例

```moonbit
// 走法生成与状态判定
let board = @xiangqi.Board::initial()
let moves = board.legal_moves()          // 开局 44 种合法着法
let mv = board.move_from_chinese("炮二平五").unwrap()  // 解析为 h2e2
let next = board.apply_move(mv)          // 返回新棋盘，原局面不变
println(board.in_check(@xiangqi.Red))    // 将军判定
println(next.to_fen())                   // 导出 FEN

// 棋谱双向转换
println(board.move_to_chinese(mv))       // 炮二平五
println(board.move_to_iccs(mv))          // h2e2

// 从 FEN 恢复任意局面
let mid = @xiangqi.parse_fen("2k6/9/9/9/9/9/9/9/4K4/9 w - - 0 1")
```

## 正确性保证

走法生成是所有象棋软件最容易藏 bug 的环节，本库用 perft（穷举式节点计数）逐层校验：

| 深度 | 本库 | 公开参考值 |
|---|---|---|
| perft(1) | 44 | 44 |
| perft(2) | 1920 | 1920 |
| perft(3) | 79666 | 79666 |

另有 16 个单元测试覆盖边界规则（蹩马腿、塞象眼、炮架、九宫、过河兵、将帅照面），CI 全程回归。

## 设计决策

- **不可变棋盘**：`apply_move` 返回新局面，原局面不变，天然适合做搜索树与撤销
- **生成-解析对称**：记谱解析采用"枚举合法着法 → 重新生成记谱串 → 精确匹配"策略，保证 `move_from_chinese` 与 `move_to_chinese` 永远互逆
- **反向推理攻击判定**：`is_attacked` 从目标格反推攻击子，正确处理马腿与炮架遮挡
- **接口即契约**：公共 API 全部沉淀在 `.mbti` 接口文件中，升级版本时 diff 即可审查兼容性

## 典型集成

- **象棋 AI**：`legal_moves` + `apply_move` 构成搜索树的展开层，配一层 UCCI 协议即可接入象棋界面与现有引擎
- **对弈平台后端**：前端只画棋盘、传着法，"能不能走、是否将军、是否绝杀"集中由库判定，便于测试与审计
- **棋谱处理管道**：FEN 解析 + 中文纵线记谱双向转换，支撑复盘软件、棋谱网站与讲棋内容

## 开发

```bash
moon check       # 静态检查
moon test        # 16 个测试（含 perft 回归）
moon fmt         # 格式化
moon info        # 重新生成 .mbti 接口文件
```

## License

Apache-2.0
