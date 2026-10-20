# Test report template

Produced by the tester session at the end of every "check this change" cycle.
Paste it into the chat where the fix is made; everything needed to reproduce is in it.

```
Check: <what changed, one line>  ·  emulator: <name, Android version>  ·  build: <HH:MM>

✅ <item 1> — <what I saw, one line>
❌ <item 2> — <what I saw, one line>
✅ <item 3> — ...

Smoke: 2/2 ✅

Not covered automatically:
- Google sign-in (no Play services on this emulator)
- Payment sheet (sandbox not configured)

Bugs:
1. <title>
   Steps: launch → login (default account) → tab "Orders" → tap first row
   Expected: order details open
   Actual: spinner forever, logcat: <one line if relevant>
   Screenshot: .maestro/artifacts/2026-10-20_14-02-11/.../03_orders.png
   Flow: .maestro/cases/2026-10-20_order-details.yaml (step 7)

Id candidates:
- Orders screen: row item (`orders_row`), details title (`order_details_title`)

Files under .maestro/:
- new: cases/2026-10-20_order-details.yaml
- changed: subflows/logout.yaml (drawer path)

Screenshots: .maestro/artifacts/2026-10-20_14-02-11/
```

## Rules of a good report

- One line per item. A screenshot path beats a paragraph.
- A bug has steps, expected, actual. Someone else must be able to reproduce it.
- "Not covered automatically" is not optional: it is the honest boundary of the run.
- Never paste credentials, tokens or the contents of `.env`.
- Screenshots were looked at. A white screenshot with a passing check is reported as
  "recheck", not as a pass.
