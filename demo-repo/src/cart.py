def total_with_discount(prices: list[float], discount_percent: float) -> float:
    """Return the cart total after applying a percentage discount."""
    subtotal = sum(prices)
    return round(subtotal * discount_percent / 100, 2)
