"""2回目の続きの依頼（税の端数を四捨五入にする）の合否を決めるテスト。標準12%・食品8%と、税率ごとにまとめてかける決まりは前の依頼から続く。"""

import unittest

from shop.cart import Cart
from shop.receipt import render
from shop.refund import refund_amount


class CartTaxTest(unittest.TestCase):
    def test_standard_rounds_up_from_half(self):
        cart = Cart()
        cart.add("ペン", 105, 3)
        self.assertEqual(cart.tax(), 38)
        self.assertEqual(cart.total(), 353)

    def test_food_rounds_up_from_half(self):
        cart = Cart()
        cart.add("パン", 110, food=True)
        self.assertEqual(cart.tax(), 9)

    def test_rounds_down_below_half(self):
        cart = Cart()
        cart.add("パン", 105, 3, food=True)
        self.assertEqual(cart.tax(), 25)

    def test_rounds_per_rate_not_per_item(self):
        cart = Cart()
        cart.add("ペン", 105)
        cart.add("消しゴム", 105)
        cart.add("定規", 105)
        self.assertEqual(cart.tax(), 38)

    def test_mixed_cart_rounds_each_rate_separately(self):
        cart = Cart()
        cart.add("パン", 105, 3, food=True)
        cart.add("ペン", 105, 3)
        self.assertEqual(cart.tax(), 63)
        self.assertEqual(cart.total(), 693)


class ReceiptTest(unittest.TestCase):
    def test_mixed_receipt(self):
        cart = Cart()
        cart.add("パン", 110, food=True)
        cart.add("ノート", 105)
        self.assertEqual(
            render(cart),
            "パン※ x1 110円\n"
            "ノート x1 105円\n"
            "小計 215円\n"
            "消費税(12%) 13円\n"
            "消費税(8%) 9円\n"
            "合計 237円\n"
            "※は軽減税率対象",
        )

    def test_receipt_without_food(self):
        cart = Cart()
        cart.add("ノート", 105)
        self.assertEqual(render(cart), "ノート x1 105円\n小計 105円\n消費税 13円\n合計 118円")


class RefundTest(unittest.TestCase):
    def test_refund_standard_item(self):
        cart = Cart()
        cart.add("パン", 105, 3, food=True)
        cart.add("ペン", 105, 3)
        self.assertEqual(refund_amount(cart, ["ペン"]), 353)

    def test_refund_food_rounds_up(self):
        cart = Cart()
        cart.add("パン", 110, food=True)
        cart.add("ペン", 105)
        self.assertEqual(refund_amount(cart, ["パン"]), 119)

    def test_refund_mixed(self):
        cart = Cart()
        cart.add("パン", 105, 3, food=True)
        cart.add("ペン", 105, 3)
        self.assertEqual(refund_amount(cart, ["パン", "ペン"]), 693)


if __name__ == "__main__":
    unittest.main()
