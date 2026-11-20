"""返品したときの返金額を計算する。"""

TAX_RATE_PERCENT = 10


def refund_amount(cart, names):
    """names に挙げた商品を、かごにある数だけすべて返品したときの返金額（税込み）を返す。"""
    returned = [line for line in cart.lines() if line[0] in names]
    if not returned:
        raise ValueError("no matching items to refund")
    subtotal = sum(price * quantity for _, price, quantity in returned)
    return subtotal + subtotal * TAX_RATE_PERCENT // 100
