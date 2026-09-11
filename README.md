# AstroBot MTF Scanner

A multi-timeframe ensemble scanner for MetaTrader 5, with a dark-themed panel and an
optional auto trend engine that is **off by default**.

Two engines share one signal core.

**The manual cockpit** scans M1, M5, M15, M30, H1, H4 and D1 with an indicator ensemble,
shows per-timeframe and overall BUY/SELL bias, and gives you a draggable ticket — lot,
risk %, stop, target — with BUY and SELL buttons. Those orders fire only when you click.

**The auto trend engine** reads the same ensemble and opens, manages and closes trades on
its own with a trailing stop. Every decision comes from an input; nothing is hard-coded
and nothing is read from the panel's live edit boxes. It is disabled unless you set
`InpEnableAutoTrading`.

## What a year of measurement said

The auto engine was measured for a year and **found to have no edge on M1**. Version 6.5
is a deliberate retreat: back to being a scanner, investing in the part that was never
the problem.

That measurement changed real defaults. `InpSignalTF` was M1 and is now M5, because 24.9
points of spread against a 401-point stop is 7.8% of risk per trade while the ensemble is
worth about 6.8% — M5 spreads the same signal over a stop roughly twice as wide, halving
that share.

Where the evidence is thin, the feature ships off. `InpRequireConfirmTF` lets a higher
timeframe veto a trade, and the numbers behind it (+24.3R with D1 aligned against −10.9R
without) come from one symbol over one year. That is a hint, not a finding, so it is
opt-in.

## The signal

Votes are **graded, not binary**. Each vote ramps from 0 at its own threshold to 1 at
saturation, in its own units — the EMA stack by its narrowest rung, slope and DI at three
times their gates, RSI halfway to its extreme, Donchian at the channel edge, AD at full
pressure. Nothing crosses that could not cross before; only the weight is new, so the
percentage stops flickering when a vote sits exactly on its boundary.
`InpGradedVotes=false` restores the old sum exactly.

**The verdict card** states a conclusion instead of leaving you to assemble one from
forty-two arrows. It names the side, grades it A to C by how many independent checks
agree, prints the entry, stop, target and lot the buttons would actually use, and lists
what is for the trade and what is against it. When there is no trade it says so in the
warning colour and names what is missing — "no" needs to be as visible as "yes".

It reads the same aggregate and the same thresholds the engine reads, so the panel and
the engine can never tell two stories about one bar. It places nothing.

## Install

1. Copy `MTF_Scanner3.mq5` and the eight `AB_*.mqh` files into `MQL5/Experts/` in your
   terminal's data folder.
2. Compile in MetaEditor (F7). It builds at 0 errors, 0 warnings.
3. Attach to a chart and allow algorithmic trading.

`Sweep_SL_ATR.set` is a preset for the Strategy Tester.

### If you use the JSON feed

`AB_Api.mqh` publishes the whole panel state as one JSON document so a website can rebuild
the display rather than scrape text. It is inert unless configured.

The endpoint URL must be whitelisted **by hand** in Tools → Options → Expert Advisors →
"Allow WebRequest for listed URL". Code cannot do this, by design. Without it every call
returns −1 with error 4014, and that specific failure is named in the log rather than
reported as a generic network problem.

Set `InpApiKey` to the key your server expects; it is sent as the `X-API-Key` header and
defaults to empty. **No key is stored in this repository.**

Three constraints shape that module: `WebRequest` is blocking, so the push runs from
`OnTimer` only and never `OnTick`, after the engine, so a stalled endpoint delays the
report rather than the trade. Repeated failures back off to a ceiling instead of hammering
a dead host. It does not work in the Strategy Tester at all, so the whole module disables
itself there.

## Files

```
MTF_Scanner3.mq5   the EA: panel, signal core, verdict card
AB_State.mqh       peaks, HALT latch and day anchor, kept across restarts
AB_Journal.mqh     ENTRY / EXIT rows with the full ensemble state; MFE, MAE, initial R
AB_Tester.mqh      custom optimisation criterion; per-pass frames to CSV
AB_Trader.mqh      the trader's journal: your decisions, graded against the panel
AB_Watch.mqh       the same ensemble across other pairs, display only
AB_Hedge.mqh       currency exposure netting and correlation-based offsets
AB_History.mqh     the ensemble at past moments, recomputed from closed bars
AB_Api.mqh         JSON push to a web dashboard
```

## A note for contributors

MQL5 sources are UTF-16LE with a BOM, which is what MetaEditor writes. Git treats UTF-16
as **binary** — without configuration, changing one line in a 3,952-line file shows as
`Bin 425948 -> 425960 bytes` with no diff, no blame and no merge.

`.gitattributes` sets `working-tree-encoding=UTF-16LE-BOM`, so the repository stores UTF-8
(diffable and reviewable on GitHub) while your checkout stays UTF-16LE+BOM and MetaEditor
never notices. This needs **Git 2.18 or newer**.

## Risk

This is a scanner and a trading tool, not advice. It does not predict prices. Trading
carries risk of loss, automated trading can lose money faster than manual trading, and
past measurements do not carry forward — the M1 result above is exactly that lesson.

Test on a demo account first. Understand every input before enabling
`InpEnableAutoTrading`. What you trade and what you risk is your decision and your
responsibility.

## Licence

[MIT](LICENSE).
