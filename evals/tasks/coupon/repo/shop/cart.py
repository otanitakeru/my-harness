"""買い物かごの金額を計算する。金額はすべて円の整数で扱う。"""

TAX_RATE_PERCENT = 10


class Cart:
    def __init__(self):
        self._lines = []

    def add(self, name, unit_price, quantity=1):
        if unit_price < 0:
            raise ValueError("unit_price must be 0 or more")
        if quantity < 1:
            raise ValueError("quantity must be 1 or more")
        self._lines.append((name, unit_price, quantity))

    def lines(self):
        return list(self._lines)

    def subtotal(self):
        return sum(price * quantity for _, price, quantity in self._lines)

    def tax(self):
        return self.subtotal() * TAX_RATE_PERCENT // 100

    def total(self):
        return self.subtotal() + self.tax()
