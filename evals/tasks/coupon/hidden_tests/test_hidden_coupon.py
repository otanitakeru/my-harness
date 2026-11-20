"""合否を決めるテスト。エージェントには見せず、実行のあとに tests/ に写して動かす。"""

import unittest

from shop.cart import Cart
from shop.receipt import render


def cart_with(price, quantity=1):
    cart = Cart()
    cart.add("商品", price, quantity)
    return cart


class PercentCouponTest(unittest.TestCase):
    def test_percent_applies_before_tax(self):
        cart = cart_with(1000)
        cart.apply_coupon("percent", 10)
        self.assertEqual(cart.discount(), 100)
        self.assertEqual(cart.tax(), 90)
        self.assertEqual(cart.total(), 990)

    def test_percent_discount_is_rounded_down(self):
        cart = cart_with(999)
        cart.apply_coupon("percent", 10)
        self.assertEqual(cart.discount(), 99)
        self.assertEqual(cart.total(), 990)

    def test_percent_100_makes_total_zero(self):
        cart = cart_with(1000)
        cart.apply_coupon("percent", 100)
        self.assertEqual(cart.total(), 0)

    def test_percent_follows_items_added_later(self):
        cart = Cart()
        cart.apply_coupon("percent", 10)
        cart.add("商品", 1000)
        self.assertEqual(cart.discount(), 100)
        cart.add("商品", 500)
        self.assertEqual(cart.discount(), 150)


class AmountCouponTest(unittest.TestCase):
    def test_amount_applies_before_tax(self):
        cart = cart_with(1000)
        cart.apply_coupon("amount", 300)
        self.assertEqual(cart.discount(), 300)
        self.assertEqual(cart.tax(), 70)
        self.assertEqual(cart.total(), 770)

    def test_amount_never_exceeds_subtotal(self):
        cart = cart_with(300)
        cart.apply_coupon("amount", 500)
        self.assertEqual(cart.discount(), 300)
        self.assertEqual(cart.total(), 0)


class CouponRuleTest(unittest.TestCase):
    def test_no_coupon_means_no_discount(self):
        cart = cart_with(1000)
        self.assertEqual(cart.discount(), 0)
        self.assertEqual(cart.total(), 1100)

    def test_second_coupon_is_rejected(self):
        cart = cart_with(1000)
        cart.apply_coupon("percent", 10)
        with self.assertRaises(ValueError):
            cart.apply_coupon("amount", 100)
        self.assertEqual(cart.discount(), 100)

    def test_out_of_range_and_unknown_kind_are_rejected(self):
        for kind, value in [
            ("percent", 0),
            ("percent", 101),
            ("amount", 0),
            ("amount", -100),
            ("point", 10),
        ]:
            with self.subTest(kind=kind, value=value):
                cart = cart_with(1000)
                with self.assertRaises(ValueError):
                    cart.apply_coupon(kind, value)

    def test_rejected_coupon_is_not_used_up(self):
        cart = cart_with(1000)
        with self.assertRaises(ValueError):
            cart.apply_coupon("percent", 0)
        cart.apply_coupon("percent", 10)
        self.assertEqual(cart.discount(), 100)


class ReceiptWithCouponTest(unittest.TestCase):
    def test_discount_row_comes_after_subtotal(self):
        cart = cart_with(1000)
        cart.apply_coupon("amount", 300)
        self.assertEqual(
            render(cart),
            "商品 x1 1000円\n小計 1000円\n割引 -300円\n消費税 70円\n合計 770円",
        )

    def test_no_discount_row_without_coupon(self):
        cart = cart_with(1000)
        self.assertNotIn("割引", render(cart))


if __name__ == "__main__":
    unittest.main()
