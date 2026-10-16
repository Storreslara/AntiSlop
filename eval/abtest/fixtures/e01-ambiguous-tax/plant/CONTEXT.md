# toy-lib glossary

**taxable amount**: the post-discount line total. Tax is never applied to the pre-discount price.
_Avoid_: subtotal, gross.

**rate**: always a percentage from 0 to 100, never a fraction; see `applyDiscountPercent`.
_Avoid_: ratio, factor.

**pure helper**: a new pricing function never mutates its arguments; it works on copies. `applyDiscountPercent` is the one legacy exception and stays as it is.
