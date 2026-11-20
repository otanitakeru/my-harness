# shop

小さな店のレジで使う、買い物かごの金額計算、レシートの表示、返品の返金額の計算。Python 3.10 以上、標準ライブラリだけで動く。

## 使い方

```python
from shop.cart import Cart
from shop.receipt import render
from shop.refund import refund_amount

cart = Cart()
cart.add("ノート", 200, 2)
print(render(cart))
print(refund_amount(cart, ["ノート"]))
```

## テスト

```bash
python3 -m unittest
```

## 料金の決まり

[docs/pricing.md](docs/pricing.md) にある。
