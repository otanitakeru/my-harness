import unittest

from shop.cart import Cart
from shop.receipt import render


class CartTest(unittest.TestCase):
    def test_empty_cart_is_zero(self):
        cart = Cart()
        self.assertEqual(cart.total(), 0)

    def test_total_includes_tax_rounded_down(self):
        cart = Cart()
        cart.add("ペン", 105, 3)
        self.assertEqual(cart.subtotal(), 315)
        self.assertEqual(cart.tax(), 31)
        self.assertEqual(cart.total(), 346)

    def test_rejects_invalid_lines(self):
        cart = Cart()
        with self.assertRaises(ValueError):
            cart.add("ペン", -1)
        with self.assertRaises(ValueError):
            cart.add("ペン", 100, 0)


class ReceiptTest(unittest.TestCase):
    def test_render(self):
        cart = Cart()
        cart.add("ノート", 200, 2)
        self.assertEqual(
            render(cart),
            "ノート x2 400円\n小計 400円\n消費税 40円\n合計 440円",
        )


if __name__ == "__main__":
    unittest.main()
