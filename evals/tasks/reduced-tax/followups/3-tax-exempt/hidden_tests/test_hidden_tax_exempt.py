"""3回目の続きの依頼（非課税の商品）の合否を決めるテスト。標準12%・食品8%・税率ごとに四捨五入は前の依頼から続く。"""

import unittest

from shop.cart import Cart
from shop.receipt import render
from shop.refund import refund_amount


def mixed_cart():
    cart = Cart()
    cart.add("切手", 84, 5, tax_exempt=True)
    cart.add("ペン", 105, 3)
    cart.add("パン", 105, 3, food=True)
    return cart


class CartTaxTest(unittest.TestCase):
    def test_exempt_only_has_no_tax(self):
        cart = Cart()
        cart.add("切手", 84, 5, tax_exempt=True)
        self.assertEqual(cart.subtotal(), 420)
        self.assertEqual(cart.tax(), 0)
        self.assertEqual(cart.total(), 420)

    def test_mixed_cart(self):
        cart = mixed_cart()
        self.assertEqual(cart.subtotal(), 1050)
        self.assertEqual(cart.tax(), 63)
        self.assertEqual(cart.total(), 1113)

    def test_standard_and_food_are_unchanged(self):
        cart = Cart()
        cart.add("ペン", 105, 3)
        cart.add("パン", 110, food=True)
        self.assertEqual(cart.tax(), 47)


class ReceiptTest(unittest.TestCase):
    def test_receipt_with_exempt_and_standard(self):
        cart = Cart()
        cart.add("切手", 84, tax_exempt=True)
        cart.add("ノート", 105)
        self.assertEqual(
            render(cart),
            "切手(非課税) x1 84円\nノート x1 105円\n小計 189円\n消費税 13円\n合計 202円",
        )

    def test_receipt_with_exempt_food_and_standard(self):
        cart = Cart()
        cart.add("切手", 84, tax_exempt=True)
        cart.add("パン", 110, food=True)
        cart.add("ノート", 105)
        self.assertEqual(
            render(cart),
            "切手(非課税) x1 84円\n"
            "パン※ x1 110円\n"
            "ノート x1 105円\n"
            "小計 299円\n"
            "消費税(12%) 13円\n"
            "消費税(8%) 9円\n"
            "合計 321円\n"
            "※は軽減税率対象",
        )


class RefundTest(unittest.TestCase):
    def test_refund_exempt(self):
        self.assertEqual(refund_amount(mixed_cart(), ["切手"]), 420)

    def test_refund_exempt_and_standard(self):
        self.assertEqual(refund_amount(mixed_cart(), ["切手", "ペン"]), 773)

    def test_refund_food_is_unchanged(self):
        self.assertEqual(refund_amount(mixed_cart(), ["パン"]), 340)


if __name__ == "__main__":
    unittest.main()
