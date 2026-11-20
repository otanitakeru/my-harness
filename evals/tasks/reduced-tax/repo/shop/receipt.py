"""かごの中身をレシートの文字列にする。"""


def render(cart):
    rows = [
        f"{name} x{quantity} {price * quantity}円"
        for name, price, quantity in cart.lines()
    ]
    rows.append(f"小計 {cart.subtotal()}円")
    rows.append(f"消費税 {cart.tax()}円")
    rows.append(f"合計 {cart.total()}円")
    return "\n".join(rows)
