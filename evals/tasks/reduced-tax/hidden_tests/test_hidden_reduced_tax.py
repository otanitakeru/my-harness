"""合否を決めるテスト。エージェントには見せず、実行のあとに tests/ に写して動かす。"""

import unittest

from shop.cart import Cart
from shop.receipt import render
from shop.refund import refund_amount


class CartTaxTest(unittest.TestCase):
    def test_food_only_uses_8_percent(self):
        cart = Cart()
        cart.add("パン", 300, food=True)
        self.assertEqual(cart.tax(), 24)
        self.assertEqual(cart.total(), 324)

    def test_tax_is_rounded_per_rate_not_per_item(self):
        cart = Cart()
        cart.add("パン", 105, 3, food=True)
        self.assertEqual(cart.tax(), 25)

    def test_mixed_cart_rounds_each_rate_separately(self):
        cart = Cart()
        cart.add("パン", 105, 3, food=True)
        cart.add("ペン", 105, 3)
        self.assertEqual(cart.subtotal(), 630)
        self.assertEqual(cart.tax(), 56)
        self.assertEqual(cart.total(), 686)

    def test_food_rate_is_summed_across_lines(self):
        cart = Cart()
        cart.add("パン", 105, food=True)
        cart.add("牛乳", 105, food=True)
        cart.add("卵", 105, food=True)
        self.assertEqual(cart.tax(), 25)

    def test_default_is_standard_rate(self):
        cart = Cart()
        cart.add("ペン", 105, 3)
        self.assertEqual(cart.tax(), 31)


class ReceiptTest(unittest.TestCase):
    def test_mixed_receipt_splits_tax_and_marks_food(self):
        cart = Cart()
        cart.add("パン", 300, food=True)
        cart.add("ノート", 200)
        self.assertEqual(
            render(cart),
            "パン※ x1 300円\n"
            "ノート x1 200円\n"
            "小計 500円\n"
            "消費税(10%) 20円\n"
            "消費税(8%) 24円\n"
            "合計 544円\n"
            "※は軽減税率対象",
        )

    def test_food_only_receipt_has_no_standard_rate_row(self):
        cart = Cart()
        cart.add("パン", 300, food=True)
        self.assertEqual(
            render(cart),
            "パン※ x1 300円\n小計 300円\n消費税(8%) 24円\n合計 324円\n※は軽減税率対象",
        )

    def test_receipt_without_food_is_unchanged(self):
        cart = Cart()
        cart.add("ノート", 200, 2)
        self.assertEqual(
            render(cart),
            "ノート x2 400円\n小計 400円\n消費税 40円\n合計 440円",
        )


class RefundTest(unittest.TestCase):
    def test_refund_food_uses_8_percent(self):
        cart = Cart()
        cart.add("パン", 105, 3, food=True)
        cart.add("ペン", 105, 3)
        self.assertEqual(refund_amount(cart, ["パン"]), 340)

    def test_refund_mixed_rounds_each_rate_separately(self):
        cart = Cart()
        cart.add("パン", 105, 3, food=True)
        cart.add("ペン", 105, 3)
        cart.add("ノート", 200)
        self.assertEqual(refund_amount(cart, ["パン", "ペン"]), 686)

    def test_refund_standard_item_is_unchanged(self):
        cart = Cart()
        cart.add("パン", 105, 3, food=True)
        cart.add("ペン", 105, 3)
        self.assertEqual(refund_amount(cart, ["ペン"]), 346)


if __name__ == "__main__":
    unittest.main()
