"""簡単なタスク（Cart.item_count を足す）の合否を決めるテスト。"""

import unittest

from shop.cart import Cart


class ItemCountTest(unittest.TestCase):
    def test_empty_cart(self):
        self.assertEqual(Cart().item_count(), 0)

    def test_counts_quantities(self):
        cart = Cart()
        cart.add("ペン", 105, 3)
        cart.add("ノート", 200)
        self.assertEqual(cart.item_count(), 4)

    def test_does_not_change_totals(self):
        cart = Cart()
        cart.add("ペン", 105, 3)
        cart.item_count()
        self.assertEqual(cart.total(), 346)


if __name__ == "__main__":
    unittest.main()
