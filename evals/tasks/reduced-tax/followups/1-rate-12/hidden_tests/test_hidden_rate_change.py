"""続きの依頼（標準税率を12%にする）の合否を決めるテスト。1回目の隠しテストのうち、税率に関係しないものも含める。"""

import unittest

from shop.cart import Cart
from shop.receipt import render
from shop.refund import refund_amount


class CartTaxTest(unittest.TestCase):
    def test_standard_rate_is_12_percent(self):
        cart = Cart()
        cart.add("ペン", 105, 3)
        self.assertEqual(cart.tax(), 37)
        self.assertEqual(cart.total(), 352)

    def test_food_stays_8_percent(self):
        cart = Cart()
        cart.add("パン", 105, 3, food=True)
        self.assertEqual(cart.tax(), 25)

    def test_mixed_cart_rounds_each_rate_separately(self):
        cart = Cart()
        cart.add("パン", 105, 3, food=True)
        cart.add("ペン", 105, 3)
        self.assertEqual(cart.tax(), 62)
        self.assertEqual(cart.total(), 692)


class ReceiptTest(unittest.TestCase):
    def test_mixed_receipt_shows_new_rate(self):
        cart = Cart()
        cart.add("パン", 300, food=True)
        cart.add("ノート", 200)
        self.assertEqual(
            render(cart),
            "パン※ x1 300円\n"
            "ノート x1 200円\n"
            "小計 500円\n"
            "消費税(12%) 24円\n"
            "消費税(8%) 24円\n"
            "合計 548円\n"
            "※は軽減税率対象",
        )

    def test_receipt_without_food(self):
        cart = Cart()
        cart.add("ノート", 200, 2)
        self.assertEqual(
            render(cart),
            "ノート x2 400円\n小計 400円\n消費税 48円\n合計 448円",
        )


class RefundTest(unittest.TestCase):
    def test_refund_standard_item_uses_new_rate(self):
        cart = Cart()
        cart.add("パン", 105, 3, food=True)
        cart.add("ペン", 105, 3)
        self.assertEqual(refund_amount(cart, ["ペン"]), 352)

    def test_refund_food_is_unchanged(self):
        cart = Cart()
        cart.add("パン", 105, 3, food=True)
        cart.add("ペン", 105, 3)
        self.assertEqual(refund_amount(cart, ["パン"]), 340)

    def test_refund_mixed(self):
        cart = Cart()
        cart.add("パン", 105, 3, food=True)
        cart.add("ペン", 105, 3)
        self.assertEqual(refund_amount(cart, ["パン", "ペン"]), 692)


if __name__ == "__main__":
    unittest.main()
