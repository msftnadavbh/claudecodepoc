import unittest

from src.cart import total_with_discount


class CartTests(unittest.TestCase):
    def test_applies_percentage_discount(self) -> None:
        self.assertEqual(total_with_discount([20.0, 30.0], 10), 45.0)

    def test_zero_discount_keeps_subtotal(self) -> None:
        self.assertEqual(total_with_discount([12.5, 7.5], 0), 20.0)


if __name__ == "__main__":
    unittest.main()
