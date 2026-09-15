# Terminal prices, 2026-09-15

New IMA sales derive their average realized unit price from the PA2 monetary and quantity difference against the same device's previous recorded counter. Resets, missing amounts, and ambiguous previous selections remain unverified. PA1 product_index is not interpreted as a price. Monetary counters use minor CZK units.

The planogram is not overwritten. Sales record price_source, terminal_unit_price_czk, and planogram_unit_price_czk. A planogram-only estimate has null monetary totals, so it does not inflate confirmed revenue; the dashboard transaction row labels it as an estimate. Legacy rows with no source are not globally restated.

Machine details display a price-check section with the latest observations from up to 500 recent sourced sales; missing or older observations are not proof of the current physical price. Discounts and mixed prices within a report window can produce an average difference and should be reviewed, not automatically corrected.

Hlučín EV86: 34 retained sales rows / 40 drinks were checked against adjacent raw ingests for terminal 602224. PA2 supports 690 CZK, versus the preceding planogram-based correction of 685 CZK. Backup of both versions is in the RLS-protected hlucin_price_audit_20260915 (ids 1 and 2). No raw DEX, quantities, or stock movements were changed.

Validation: terminal price precedence and missing/reset/zero counter tests; terminal switch/replay regression; aggregate free-vend regression; HTML script syntax checks.
