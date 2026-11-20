# shop

小さな店のレジで使う、買い物かごの金額計算、レシートの表示、返品の返金額の計算。Python 3.10 以上、標準ライブラリだけで動く。

## 起動方法

ライブラリなので起動するものはない。使い方:

```python
from shop.cart import Cart
from shop.receipt import render
from shop.refund import refund_amount

cart = Cart()
cart.add("ノート", 200, 2)
print(render(cart))
print(refund_amount(cart, ["ノート"]))
```

テスト: `python3 -m unittest -q`

## ドキュメント

| 内容 | 場所 |
|---|---|
| 料金の決まり | [docs/pricing.md](docs/pricing.md) |
| 設計判断の記録 | [docs/decisions.md](docs/decisions.md) |
| 開発の原則 | [docs/guidelines/](docs/guidelines/) |
| AI エージェント向けの指示 | [AGENTS.md](AGENTS.md) |
