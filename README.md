# moonxiangqi · 中国象棋规则引擎 (Xiangqi Rules Engine in MoonBit)

纯 [MoonBit](https://www.moonbitlang.com) 实现的中国象棋规则引擎，零依赖，可编译到
`wasm-gc` / `js` / `native` 全后端。为对弈应用、棋力 AI、教学工具、棋谱处理提供
可靠的基础库。

## 功能特性

- **完整走法生成**：车、马、炮、兵、仕、相、帅七类棋子的全部走法规则，
  包括蹩马腿、塞象眼、炮打隔子、兵过河横移、仕相不出九宫、帅不出宫等细节
- **规则判定**：将军检测（含马腿/炮架反向推理）、将帅照面（飞将）判定、
  合法着法过滤、将死与困毙（无子可动判负）判定
- **中文纵线记谱**：`炮二平五`、`马8进7`、`前车进一` 等标准记谱的双向转换，
  红方中文数字、黑方阿拉伯数字，前/中/后消歧
- **ICCS 坐标记谱**：`h2e2` 风格坐标的双向转换
- **XiangqiFEN**：标准 FEN 的解析与生成
- **Perft 验证**：开局 perft(1)=44、perft(2)=1920、perft(3)=79666，
  与公开参考值完全一致
- **终端棋盘渲染**：Unicode 棋盘文本图，楚河汉界，双后端棋子字形区分

## 快速开始

```bash
git clone https://github.com/wbgxiaosu/xiangqi.git
cd xiangqi
moon check && moon test    # 16 个测试全部通过
moon run cmd/main          # 查看终端演示
```

## 作为依赖使用

```bash
moon add wbgxiaosu/xiangqi
```

```moonbit
let board = @xiangqi.Board::initial()
let mv = board.move_from_chinese("炮二平五").unwrap()  // h2e2
let next = board.apply_move(mv)
println(board.move_to_chinese(mv))  // 炮二平五
println(next.to_fen())
```

## 示例输出

```text
9 车 马 象 士 將 士 象 马 车
8 ・ ・ ・ ・ ・ ・ ・ ・ ・
7 ・ 砲 ・ ・ ・ ・ ・ 砲 ・
6 卒 ・ 卒 ・ 卒 ・ 卒 ・ 卒
5 ・ ・ ・ ・ ・ ・ ・ ・ ・
  ～ 楚 河 ～ 汉 界 ～
4 ・ ・ ・ ・ ・ ・ ・ ・ ・
3 兵 ・ 兵 ・ 兵 ・ 兵 ・ 兵
2 ・ 炮 ・ ・ ・ ・ ・ 炮 ・
1 ・ ・ ・ ・ ・ ・ ・ ・ ・
0 車 馬 相 仕 帅 仕 相 馬 車
   a b c d e f g h i
轮到红方
```

## 设计说明

- **坐标系统**：`file` 0..8 对应 a..i（a 在红方左手），`rank` 0..9
  （0 为红方底线，9 为黑方底线），与 ICCS/XiangqiFEN 惯例一致
- **不可变风格**：`apply_move` 返回新棋盘，原棋盘不变，便于做搜索树
- **记谱解析采用重生成匹配**：解析中文记谱时枚举所有合法着法并重新生成
  记谱串做精确匹配，保证生成与解析永远对称一致
- **马腿/炮架反向推理**：`is_attacked` 从目标格反推攻击子，正确处理
  蹩马腿与炮架遮挡

## 路线图

- [ ] 长将/长捉禁着判定
- [ ] UCCI 协议适配层（对接象棋引擎）
- [ ] 简单 α-β 搜索与评估示例
- [ ] 棋谱（PGN 风格）读写
- [ ] 发布到 mooncakes.io

## 开发

```bash
moon check       # 静态检查
moon test        # 运行 16 个测试（含 perft 回归）
moon fmt         # 格式化
moon info        # 更新 .mbti 接口
```

## License

Apache-2.0
