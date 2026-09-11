//+------------------------------------------------------------------+
//|                                          AstroBot_MTF_Scanner.mq5 |
//|      Multi-timeframe ensemble scanner + AUTO trend-following bot  |
//|      Dark-themed GUI on the standard Controls library             |
//|                                                                   |
//| WHAT THIS IS: two engines sharing one signal core.                |
//|                                                                   |
//|   1. MANUAL COCKPIT (unchanged). Scans M1/M5/M15/M30/H1/H4/D1 with|
//|      an indicator ensemble, shows per-timeframe and overall       |
//|      BUY%/SELL% bias, and gives you a draggable ticket (lot /     |
//|      risk% / SL / TP) with green BUY and red SELL buttons. These  |
//|      orders still fire only when YOU click.                       |
//|                                                                   |
//|   2. AUTO TREND ENGINE (v4.0, NEW). Reads the SAME ensemble and   |
//|      opens, manages and closes trades on its own, with a trailing |
//|      stop. Every decision it makes comes from an input — nothing  |
//|      is hard-coded and nothing is read from the panel's live      |
//|      edit boxes. It is OFF by default (InpEnableAutoTrading).     |
//|                                                                   |
//| v6.5 — BACK TO BEING A SCANNER                                    |
//|                                                                   |
//|  The auto engine was measured for a year and found to have no     |
//|  edge on M1. The scanner it grew out of was never the problem,    |
//|  so this pass invests there: a sane default timeframe, an         |
//|  ensemble that distinguishes strong evidence from marginal, and   |
//|  a panel that states a conclusion instead of leaving a person to  |
//|  assemble one from forty-two arrows.                              |
//|                                                                   |
//|  H0 M5 IS THE DEFAULT NOW. InpSignalTF was SIG_M1; a full year    |
//|     said 24.9 points of spread against a 401-point stop is 7.8%   |
//|     of risk per trade while the ensemble is worth about 6.8%.     |
//|     M5 spreads the same signal over a stop roughly twice as       |
//|     wide, which halves that share. SIG_CHART is also new and      |
//|     follows whatever chart the EA is attached to, falling back    |
//|     to M5 on a period the ladder does not carry. Appended to the  |
//|     enum, so no existing ordinal moved and old presets still      |
//|     load - unlike the v6.0 change that shifted everything.        |
//|                                                                   |
//|  H1 VOTES CARRY STRENGTH. Every vote was 0 or 1, so a DI gap of   |
//|     5.1 against a threshold of 5 counted exactly as much as a     |
//|     gap of 40. Each vote now ramps from 0 at its own threshold    |
//|     to 1 at saturation, in its own units: the EMA stack by its    |
//|     narrowest rung, slope and DI at three times their gates, RSI  |
//|     halfway to its extreme, Donchian at the channel edge, AD at   |
//|     full pressure. Nothing new crosses that could not cross       |
//|     before - the thresholds still decide whether a vote counts,   |
//|     and the signs are untouched. Only the weight is new, so       |
//|     buyPct stops flickering when a vote sits on its boundary.     |
//|     InpGradedVotes=false restores the old sum exactly.            |
//|                                                                   |
//|  H2 A HIGHER TIMEFRAME CAN BACK OR VETO. InpConfirmTF (default    |
//|     H1) is shown in the verdict as one of its checks. The auto    |
//|     engine will also refuse trades it opposes, but only if you    |
//|     set InpRequireConfirmTF - off by default, because the         |
//|     evidence for it is one symbol and one year (+24.3R with D1    |
//|     aligned against -10.9R without), which is a hint and not a    |
//|     finding.                                                      |
//|                                                                   |
//|  H3 THE VERDICT CARD. A block under the gauge that says the       |
//|     side, grades it A to C by how many independent checks agree,  |
//|     prints the entry, stop, target and lot the buttons would      |
//|     actually use, and lists what is FOR the trade and what is     |
//|     AGAINST it. When there is no trade it says so in the warning  |
//|     colour and names what is missing, because "no" needs to be    |
//|     as visible as "yes". It reads the same aggregate and the      |
//|     same thresholds the engine reads, so the panel and the        |
//|     engine can never tell two stories about one bar. It places    |
//|     nothing: the buttons are still the only thing that trades.    |
//|                                                                   |
//|  R3 RETIRED. The label thresholds the header has admitted were    |
//|     never re-derived are inputs now: InpLabelBuyNet and           |
//|     InpLabelStrongNet, at their historical 2 and 4.               |
//|                                                                   |
//|  H6 THE PANEL MEASURES ITS TEXT (v6.52). H4 below replaced one    |
//|     hard-coded width with a derived one and kept the underlying   |
//|     mistake: a guess at how many pixels a character takes. That   |
//|     guess was wrong twice, because the answer depends on the      |
//|     display's DPI scaling - the same 8pt Consolas is about 5.3 px |
//|     per character at 100% and about 8 at 150% - which the EA      |
//|     cannot know and the user should not have to supply.           |
//|                                                                   |
//|     TextGetSize asks the terminal how wide a string will actually |
//|     be, at the font and size it is about to be drawn, on THIS     |
//|     display. Every long label and every button now goes through   |
//|     FitLabel/FitButton: measure, drop a point at a time to a 6pt  |
//|     floor, and only if it still will not fit, trim and mark the   |
//|     cut with "..". A visible ".." is honest; a silently amputated |
//|     line is not, and that is what the last two versions shipped.  |
//|     The seven timeframe rows are sized TOGETHER against the       |
//|     widest of them, so the table never ends up with mixed font    |
//|     sizes and ragged columns. Panel_W is back to 620: with real   |
//|     measurement it no longer has to be oversized to be safe.      |
//|                                                                   |
//|  H4 THE PANEL FITS ITS OWN TEXT (v6.51). Every horizontal number  |
//|     was hard-coded against a 530 px panel on the assumption that  |
//|     a character is about 6.5 px wide. True at 100% display        |
//|     scaling; at 150% a character is nearer 8 px, so the panel     |
//|     fitted 63 characters where the code assumed 76. CLabel clips  |
//|     instead of wrapping, so long lines lost their tails with no   |
//|     visible clue - "Vol: ATR 1202.0 - HIGH (exp", "| butt".       |
//|     Column positions, label and button widths and the gauge all   |
//|     derive from ClientAreaWidth() now, and Panel_W defaults to    |
//|     760. Raise it if your scaling is higher still and everything  |
//|     follows. The longest status lines were shortened as well, so  |
//|     the panel stays legible at the old 530.                       |
//|                                                                   |
//|  H5 TOGGLES SAY WHICH STATE THEY ARE IN (v6.51). "SL/TP: AUTO"    |
//|     could be read as the state the button is in or the state a    |
//|     click would put you in, and those are opposites. Every toggle |
//|     now reads "<CURRENT> -> <what a click does>", upper case for  |
//|     what is and lower case for what a click makes: "SL/TP: AUTO   |
//|     -> manual", "AUTO: ON -> disarm", "TRAIL: ATR -> CHANDLR".    |
//|     The two cycling buttons name the next step in their cycle,    |
//|     so the ATR source and the trail mode no longer have to be     |
//|     discovered by clicking through them.                          |
//|                                                                   |
//|  PANEL: Panel_H default 548 -> 620 for the verdict card, Panel_W  |
//|  530 -> 760 for the text. A saved preset carrying the old numbers |
//|  will still clip - set both, or clear the preset.                 |
//|                                                                   |
//|  PRESETS: seven inputs added (InpGradedVotes, InpLabelBuyNet,     |
//|  InpLabelStrongNet, InpConfirmTF, InpVerdictUseConfirm,           |
//|  InpRequireConfirmTF, and SIG_CHART as a new choice); nothing     |
//|  removed. InpSignalTF's DEFAULT changed from M1 to M5 - a saved   |
//|  preset still overrides it, so re-check that input.               |
//|                                                                   |
//| v6.4 — THE INSTRUMENT WAS LYING, AND THE YEAR IT MEASURED         |
//|                                                                   |
//|  THE YEAR. A full twelve months of XAUUSD M1 (2025-09 to          |
//|  2026-09, 4953 entries) says the strategy has no edge: 46.4%      |
//|  wins, +1.13R average win against -0.99R average loss, and an     |
//|  expectancy of -0.0096R per trade. Profit factor 0.90.            |
//|                                                                   |
//|  The reason is not the signal, it is the toll. Average spread at  |
//|  entry was 24.9 points against an average stop of 401, so every   |
//|  trade pays 7.8% of its own risk to get in. Add that back and     |
//|  the ensemble is worth about +0.068R per trade GROSS. The cost    |
//|  is 0.078R. Sorted into five buckets by stop width, net           |
//|  expectancy climbs from -0.061R to +0.053R while gross stays      |
//|  flat near +0.07R — the wider stops do not find better trades,    |
//|  they dilute a fixed cost over more risk. Read that before        |
//|  tuning anything: this needs cost per trade under about 0.035R,   |
//|  which is roughly double the stop or half the trades.             |
//|                                                                   |
//|  G1 THE MAGIC ON CLOSE (the defect that hid it). CTrade stamps    |
//|     every request with its own m_magic, and SendEntry leaves      |
//|     that on MagicNumber when it returns. So every close the       |
//|     ENGINE performed — reversal exit, weekend flatten, drawdown   |
//|     flatten, both stop-guard closes, the panel's CLOSE AUTO —     |
//|     produced a deal tagged with the MANUAL magic, which           |
//|     OnTradeTransaction's IsAutoPos test then discarded. Those     |
//|     exits reached no journal row, no realised W/L, no day P/L     |
//|     and no history rebuild. Server-triggered stops inherit the    |
//|     POSITION's magic and were never affected, which is exactly    |
//|     why a year of rows held nothing but INIT_STOP and             |
//|     TRAIL_STOP, and why seventeen weekend-flatten closes left     |
//|     no trace at all. ClosePos() and ModifyPos() now carry the     |
//|     position's own magic and restore MagicNumber afterwards.      |
//|                                                                   |
//|  G2 WHAT THE FIXED JOURNAL WILL SHOW that the old one could       |
//|     not: how often the reversal exit fires (it logged zero in     |
//|     4942 trades, so it is close to dead code), what the weekend   |
//|     flatten costs or saves, and whether the stop guard ever       |
//|     fires on a live broker.                                       |
//|                                                                   |
//|  PRESETS: no inputs added or removed. The sweep preset written    |
//|  alongside this version (Sweep_SL_ATR.set) turns the drawdown     |
//|  governor OFF and sizes at a fixed lot, so every pass runs the    |
//|  whole year and SQN over R multiples measures the edge without    |
//|  the equity path distorting it.                                   |
//|                                                                   |
//| v6.3 — WHAT THE FIRST JOURNAL SAID                                |
//|                                                                   |
//|  The first v6.1 backtest covered eight months and traded one      |
//|  day. Twenty-six trades on Friday 2 January, a short held into    |
//|  the Monday gap that filled 23 dollars past its stop, a 15%       |
//|  drawdown at 01:00, and a HALT that — correctly, for a live       |
//|  account — never cleared. The remaining eight months produced     |
//|  nothing to measure. Three changes follow from that one file.     |
//|                                                                   |
//|  F1 TESTER RE-ARM. Live, clearing a HALT is a human decision and  |
//|     stays one. In the tester nobody is there, so                  |
//|     InpTesterReArmDays (default 1) re-arms a latched halt that    |
//|     many server days later with the peaks reset, exactly as the   |
//|     panel button would. Every halt is numbered and the time       |
//|     spent halted is summed; both go into the SCORE line and the   |
//|     optimisation rows, so a parameter set that halts eleven       |
//|     times in eight months says so instead of showing one week.    |
//|     The score formula is untouched: a halted pass already         |
//|     carries a drawdown at least as deep as the limit, and the     |
//|     drawdown factor prices that. 0 keeps the live behaviour.      |
//|                                                                   |
//|  F2 WEEKEND FLATTEN. From InpFridayCutoffHour:Min server time     |
//|     on Friday until the week's close, no auto entries are taken   |
//|     and every auto position is closed. A three-dollar stop held   |
//|     across a weekend gap is the one exposure no trailing stop     |
//|     covers, and it produced the worst trade and the halt above.   |
//|     Manual positions are yours and are left alone.                |
//|                                                                   |
//|  F3 EXIT KINDS. To the broker a trailed stop and an initial stop  |
//|     are both "stop loss", which made the first journal read as    |
//|     26 stop-outs. EXIT rows now carry exit_kind: INIT_STOP,       |
//|     TRAIL_STOP, TP, STOPOUT, MANUAL, or ENGINE:<why>, where why   |
//|     names the engine's own reason — reversal, weekend flatten,    |
//|     drawdown limit, stop guard, the panel's buttons. The schema   |
//|     moves to v2, so the file name changes and the v1 file stays.  |
//|                                                                   |
//|  PRESETS: four inputs added (InpTesterReArmDays,                  |
//|  InpWeekendFlatten, InpFridayCutoffHour, InpFridayCutoffMin);     |
//|  nothing removed.                                                 |
//|                                                                   |
//| v6.2 — SAFETY PACK (three guards, no change to any decision)      |
//|                                                                   |
//|  E1 ONE ENGINE PER SYMBOL AND MAGIC (AB_State.mqh). The first     |
//|     day of v6.1 had the EA on two XAUUSD charts at once, both     |
//|     with the default InpAutoMagic. Armed, that is one engine      |
//|     with a double: two sets of entries, every ticket trailed      |
//|     twice, every close journaled twice, one state store written   |
//|     by both. The first copy to start now owns the symbol+magic    |
//|     by writing a heartbeat to the store every second; a copy      |
//|     that finds a fresh heartbeat under another chart's id runs    |
//|     as a SCANNER ONLY — no entries, no stop management, no        |
//|     journal rows, no state writes — and says so on the panel      |
//|     (AUTO reads DUPLICATE) and in the log. If the owner goes      |
//|     away the duplicate promotes itself within ten seconds and     |
//|     arms per InpEnableAutoTrading. Keyed on ChartID, so a         |
//|     recompile or period change on one chart never trips it; it    |
//|     cannot see another terminal. InpDupGuard turns it off.        |
//|                                                                   |
//|  E2 HEDGING ACCOUNTS ONLY FOR THE ENGINE. Stacking, per-ticket    |
//|     R and the reversal exit assume one position per fill. On a    |
//|     netting or exchange account every fill merges into one        |
//|     position with one stop, so InpMaxPositions, the total-risk    |
//|     ceiling and the journal's R would all quietly mean something  |
//|     else. On such an account the auto engine will not arm (the    |
//|     panel says NETTING: NO AUTO); the scanner and the manual      |
//|     ticket still work. Checked once the account is known, not     |
//|     at the instant of init, because a disconnected terminal       |
//|     reports the netting value for everything.                     |
//|                                                                   |
//|  E3 A POSITION WITHOUT A STOP DOES NOT STAY THAT WAY. Two nets:   |
//|     right after a fill the position is read back, and if the      |
//|     server accepted the order but dropped the stop, the stop is   |
//|     sent again as a modify. Every tick after that, any auto       |
//|     position found with no stop gets one from its INITIAL         |
//|     distance (the journal tracker keeps it, and recovers it from  |
//|     the opening order after a restart). If price has already      |
//|     gone through where the stop should be, that is a stop-out     |
//|     arriving late, and the position is closed at market. If the   |
//|     modify keeps failing for InpNoStopGraceSec, InpNoStopAction   |
//|     decides: CLOSE (default) or WARN and keep trying. Before      |
//|     this, B3 charged a stopless position the whole risk budget,   |
//|     which stopped new entries but left the position running       |
//|     unprotected. Note this also puts back a stop you drag off an  |
//|     AUTO position by hand: the engine owns its stops.             |
//|                                                                   |
//|  PRESETS: three inputs added (InpDupGuard, InpNoStopAction,       |
//|  InpNoStopGraceSec); nothing removed.                             |
//|                                                                   |
//| v6.1 — MEASUREMENT AND STATE (nothing here changes a decision)    |
//|                                                                   |
//|  Every version above was argued from a backtest read by eye and   |
//|  a journal of Print() lines. This pass builds the instruments:    |
//|  a per-trade record with the full ensemble state, a store for     |
//|  the facts the governors depend on, and a tester criterion that   |
//|  asks for a plateau. The engine trades exactly as v6.03 did.      |
//|                                                                   |
//|  D1 TRADE JOURNAL (AB_Journal.mqh). Every auto fill writes an     |
//|     ENTRY row — 42 vote signs, per-TF bias / ADX / ranging, the   |
//|     overall bias, spread in points and as a share of ATR, the     |
//|     session, news and volatility state, stop, lot, money at risk  |
//|     and the setup line — and every closing deal writes an EXIT    |
//|     row with the same context plus P/L in money and in R, MFE     |
//|     and MAE in points and in R, bars held and how it left. R is   |
//|     the INITIAL stop, recovered from the opening order after a    |
//|     restart, never the trailed one. One CSV per symbol and magic  |
//|     under Common\Files\AstroBot\; tester runs get their own file  |
//|     and start it over. Until now nothing recorded why a trade     |
//|     was taken; every question about which gate earns its keep     |
//|     starts from this file.                                        |
//|                                                                   |
//|  D2 STATE (AB_State.mqh). The equity and balance peaks, the       |
//|     drawdown HALT latch and the day's anchor equity now live in   |
//|     terminal global variables keyed by symbol and magic, and      |
//|     come back on restart. Today's entry count, W/L, realised P/L  |
//|     and the cooldown and pacing anchors are rebuilt from the      |
//|     deal history instead, so a restart neither forgets a close    |
//|     nor skips a cooldown. THIS CHANGES C1's RE-ARM RULE: a        |
//|     restart no longer clears a HALT. Re-arming is the AUTO        |
//|     button, which reads HALTED: RE-ARM while latched, or one      |
//|     start with InpResetState=true; both reset the peaks to the    |
//|     account as it stands. The tester never loads or saves.        |
//|                                                                   |
//|  D3 TESTER CRITERION AND FRAMES (AB_Tester.mqh). OnTester scores  |
//|     a pass by SQN over R multiples (or PF x sqrt(N), or recovery  |
//|     factor), times a drawdown factor that reaches zero at         |
//|     InpScoreDDCap, and zero outright under InpScoreMinTrades      |
//|     closed trades. Pick "Custom max" in the optimiser. During an  |
//|     optimisation every pass also ships its statistics to the      |
//|     terminal, which writes one row per pass — score, stats and    |
//|     the optimised inputs — to Common\Files\AstroBot\Opt_*\        |
//|     passes.csv. That is the plateau-versus-spike review the v5.1  |
//|     header asked for, in a file rather than in a screenshot.      |
//|                                                                   |
//|  D4 MODULES. The three features above are include files beside    |
//|     the EA rather than more lines in this one. The existing code  |
//|     stays where it was for this pass; moving the ensemble, the    |
//|     engine and the panel out is the next step, not this one.      |
//|                                                                   |
//|  PRESETS: seven inputs added (InpPersistState, InpResetState,     |
//|  InpJournal, InpOptJournalFrames, InpScore, InpScoreMinTrades,    |
//|  InpScoreDDCap); nothing removed. v6.0x .set files load as-is.    |
//|                                                                   |
//| v6.03 — DRAWDOWN BASIS (C1 was wrong, and a backtest proved it)   |
//|                                                                   |
//|  C2 WHAT "DRAWDOWN" IS MEASURED AGAINST. C1 shipped measuring     |
//|     from the EQUITY high-water mark. Its first test on M5 halted  |
//|     the engine at 15:31 on the FIRST DAY, and it never traded     |
//|     again across the remaining seven months. Nothing had gone     |
//|     wrong: three stacked longs ran to a peak equity of 2353       |
//|     against a balance of 1980, the trailing stops took them out   |
//|     for a combined +110.91, and handing back that unbanked        |
//|     profit read as an 11.13% drawdown. Balance drawdown for the   |
//|     entire run was 0.99%. The account never lost money. The       |
//|     governor killed it for winning.                               |
//|                                                                   |
//|     The error was scoring unrealised profit as if it were         |
//|     capital. A trailing stop banks a winner by definition — ride  |
//|     to a peak, give back to the stop — so an equity-peak basis    |
//|     makes that mechanic indistinguishable from a loss. With       |
//|     several positions exiting together the give-back on ONE good  |
//|     trade already approached the whole budget, which means the    |
//|     halt was not a risk of the design. It was a certainty of it.  |
//|                                                                   |
//|     InpDD_Basis now defaults to DD_FROM_BALANCE: equity is        |
//|     compared against the REALISED peak. Floating loss still       |
//|     counts in full, so a position underwater registers at once;   |
//|     only profit that was never banked stops counting against      |
//|     you. DD_FROM_EQUITY keeps the strict reading for anyone       |
//|     bound by a prop-firm trailing rule that works that way — and  |
//|     if you select it, budget several times the per-trade          |
//|     give-back or expect the same day-one halt.                    |
//|                                                                   |
//|  C1 MAX DRAWDOWN GOVERNOR. InpDailyLossLimitPct resets every      |
//|     server day, so it bounds a day and bounds nothing over a      |
//|     month. InpMaxDrawdownPct never resets: once the account is    |
//|     that far below its high-water mark, the engine stops opening  |
//|     positions, and with InpDD_FlattenOnBreach it closes what it   |
//|     already holds.                                                |
//|                                                                   |
//|     The halt LATCHES. Once flat and halted, equity stops moving,  |
//|     so a self-clearing version could never recover the drawdown   |
//|     that tripped it — it would deadlock. A maximum-drawdown limit |
//|     is terminal by nature; the per-day limit is the one built to  |
//|     resume. Re-arming is a restart, because that is a decision a  |
//|     person should make rather than a timer.                       |
//|                                                                   |
//|     WHAT IT DOES NOT PROMISE. It stops the engine ADDING risk at  |
//|     the limit; it cannot undo what is already open. With flatten  |
//|     off, live positions keep running past it. With flatten on,    |
//|     the close still needs a fill, and a gap fills below the       |
//|     limit. Expect the realised figure to overshoot. What this     |
//|     enforces is "stop trading at 10%", not "never print a number  |
//|     worse than 10%" — no EA can honestly promise the second.      |
//|                                                                   |
//| v6.0 — M1 EXECUTION AND POSITION STACKING                          |
//|                                                                   |
//|  WHAT CHANGED AT THE TOP: M1 joins the ladder as a seventh        |
//|  timeframe, InpSignalTF defaults to it, and the engine may now    |
//|  hold up to MAX_AUTO_POSITIONS (5) at once instead of one.        |
//|                                                                   |
//|  BREAKING — READ BEFORE LOADING AN OLD PRESET. ENUM_SIG_TF got    |
//|  M1 at index 0, so every other ordinal moved up by one. A .set    |
//|  file stores the NUMBER, not the name: a v5.x preset saying       |
//|  InpSignalTF=3 meant H1 and now means M30, and the same is true   |
//|  of InpTrailTF. Re-pick both by hand after loading anything old.  |
//|  Nothing in the code can detect this for you — the file is        |
//|  indistinguishable from a deliberate choice of M30.               |
//|                                                                   |
//|  B1 STOP FLOOR APPLIED BEFORE SIZING. A latent v4.0 bug that H1   |
//|     never triggered and M1 triggers most bars. PlaceAuto sized    |
//|     the lot from AutoSLPts(), then SendEntry silently widened a   |
//|     too-tight stop to the broker's minimum — so the trade went    |
//|     on at a lot computed for a stop narrower than the one it got, |
//|     and real risk exceeded InpAutoRiskPct without saying so. On   |
//|     H1 the ATR stop always cleared the minimum. On M1 the ATR is  |
//|     small enough that it usually does not. MinStopPoints() is now |
//|     the single floor, applied in AutoSLPts BEFORE the lot is      |
//|     computed, so SendEntry's clamp is a no-op for auto entries.   |
//|     InpMinSLPoints raises it further if the broker's own minimum  |
//|     is not the constraint you care about.                         |
//|                                                                   |
//|  B2 STACK SEPARATION. A cap of five is not five positions if all  |
//|     five open within a few points of each other — that is one     |
//|     position at five times the size, paying five spreads, with    |
//|     every stop in the same place. In a trend, five consecutive M1 |
//|     bars pass identical gates at almost identical prices, so this |
//|     is the DEFAULT outcome of raising the cap, not an edge case.  |
//|     InpStackMinSepATR requires each new entry to sit that far     |
//|     from the nearest position on the same side. Distance is       |
//|     absolute, not directional: demanding the new entry be further |
//|     along the trend would forbid re-entry after a pullback, and   |
//|     that is the entry this strategy exists to take.               |
//|                                                                   |
//|  B5 STACK PACING (v6.01). Price separation alone was not enough.  |
//|     In a fast M1 trend the 0.75 x ATR gap can be cleared inside   |
//|     two consecutive minutes, so the cap filled almost as quickly  |
//|     as it would have with no separation gate at all.              |
//|     InpMinBarsBetweenEntries puts a floor on the TIME between     |
//|     any two entries, measured in signal-TF bars. It is separate   |
//|     from InpCooldownBars on purpose: that one answers "how long   |
//|     after a stop-out do I sit still", this one answers "how fast  |
//|     may I build a stack", and neither implies the other.          |
//|                                                                   |
//|  B3 TOTAL RISK CEILING. InpAutoRiskPct is a PER-TRADE number. At  |
//|     a cap of one that was also the portfolio number; at five it   |
//|     is not, and nothing in v5.x said so. InpMaxTotalRiskPct       |
//|     bounds the combined open risk of every auto position, priced  |
//|     from each one's CURRENT stop — so a position the trail has    |
//|     pulled to break-even releases its budget for the next entry.  |
//|     A position with no stop at all is charged the entire budget   |
//|     rather than zero: unknown risk is not absent risk.            |
//|                                                                   |
//|  B4 SPREAD AS A SHARE OF ATR. InpMaxSpreadPoints needs a number   |
//|     that is correct for one symbol. On M1 the move being traded   |
//|     is small enough that spread is a material fraction of it, and |
//|     that FRACTION is the thing worth capping. InpMaxSpreadATR     |
//|     blocks entries when spread exceeds a share of ATR, which      |
//|     needs no per-symbol tuning and tightens by itself in the fast |
//|     conditions where M1 edges disappear first.                    |
//|                                                                   |
//|  NOT CHANGED, AND WORTH KNOWING: InpExitOnReversal still closes   |
//|  EVERY auto position when the bias flips, so a stack of five      |
//|  unwinds together. That is deliberate — they were opened on one   |
//|  thesis and they die with it — but it means one reversal bar can  |
//|  realise five losses at once. Size InpAutoRiskPct accordingly,    |
//|  and note that InpMaxTotalRiskPct is the number that actually     |
//|  bounds that event.                                               |
//|                                                                   |
//| v5.1 — TRAIL REQUEST RATE (found by a backtest, not by reading)    |
//|                                                                   |
//|  A10 MODIFY SPAM. The first XAUUSD run of v5.0 was correct and    |
//|     profitable, and its journal was thousands of lines of         |
//|     "position modified". InpTrailStepPts is measured in POINTS,   |
//|     and a point on gold is one cent — so the anti-spam gate was   |
//|     demanding ten cents of improvement on a stop trailing thirty  |
//|     DOLLARS behind price. Sixteen modifies inside one second was  |
//|     routine. The tester accepts every one of them for free. A     |
//|     live server answers with TRADE_RETCODE_TOO_MANY_REQUESTS,     |
//|     and some brokers answer by restricting the account.           |
//|                                                                   |
//|     Two gates now, because they fail in different ways:           |
//|       InpTrailStepATR    scales the minimum improvement to the    |
//|                          instrument, so one number is not         |
//|                          silently 100x too fine on gold while     |
//|                          being right on EURUSD. The points value  |
//|                          still applies — the LARGER of the two    |
//|                          wins, so neither can be defeated alone.  |
//|       InpTrailMinSeconds is a hard ceiling on requests per        |
//|                          position. The step gate still bursts     |
//|                          when price runs; a clock cannot.         |
//|                                                                   |
//|     COST, PREDICTED AND THEN MEASURED. The prediction was that    |
//|     a coarser step gives back part of a step per exit, costing    |
//|     5-10% of net profit. The re-run on identical data (42594      |
//|     bars, 93498336 ticks) refuted it: net 3355.80 -> 3871.47      |
//|     (+15.4%), PF 1.55 -> 1.66, equity DD 8.55% -> 7.68%,          |
//|     largest win 637.94 -> 871.74. The step is not only an         |
//|     anti-spam gate, it is a strategy parameter: a stop welded     |
//|     to price is a stop that noise removes, and letting it lag     |
//|     let winners run. Treat 0.05 as UNVALIDATED all the same -     |
//|     one symbol, 151 trades. Sweep InpTrailStepATR and keep the    |
//|     value only if the result is a plateau, not a spike.           |
//|                                                                   |
//| v5.0 — SIX INDEPENDENT VOTES (the ensemble is now an ensemble)     |
//|                                                                   |
//|  H3 COLLINEARITY, RETIRED. v3.2 named this defect and shipped     |
//|     anyway: the EMA stack, price-vs-EMA, the BB-middle vote and   |
//|     CCI were four readings of ONE quantity — where price sits     |
//|     relative to a moving average. CCI's numerator is literally    |
//|     price minus its own SMA; the BB middle band IS an SMA. Four   |
//|     of six votes moved together, so "6 of 6 bullish" routinely    |
//|     meant one measurement shouting through a 4x amplifier, and    |
//|     buyPct carried far less information than its precision        |
//|     implied. Tolerable while the number was only DISPLAYED.       |
//|     Not tolerable now that v4.0 trades it.                        |
//|                                                                   |
//|     The set is rebuilt so no two votes share a numerator. Each    |
//|     measures a different property of the market:                  |
//|                                                                   |
//|       STK  structure  EMA stack ORDER, with a separation gate     |
//|       SLP  rate       EMA-medium SLOPE over two bars, x ATR       |
//|       DMI  movement   +DI vs -DI (directional range share)        |
//|       RSI  momentum   bounded oscillator                          |
//|       DON  position   where close sits in the Donchian channel    |
//|       AD   pressure   volume-weighted close location              |
//|                                                                   |
//|     Still six unit votes, so MAX_PTS, buyPct and every label      |
//|     threshold are unchanged. EXPECT NET TO RUN LOWER THAN IT DID: |
//|     unanimity across six independent measurements is a far        |
//|     stronger claim than unanimity across four copies of one.      |
//|     That is the correction, not a regression.                     |
//|                                                                   |
//|  M9 RETIRED. iADX buffers 1 and 2 were computed on all six        |
//|     timeframes and thrown away. +DI/-DI is now the DMI vote —     |
//|     free, and the one directional reading in the set built from   |
//|     range expansion rather than from price levels.                |
//|                                                                   |
//|  M8 RETIRED. The old "volume" vote was close[1]>close[2] with a   |
//|     one-bar tick-volume comparison bolted on: a price vote        |
//|     wearing a volume hat, collinear with everything else. AD is   |
//|     the honest version — volume is the WEIGHT, and the direction  |
//|     comes from where each bar closed inside its own range,        |
//|     summed over InpADBars. No moving average anywhere in it.      |
//|                                                                   |
//|  M14 RETIRED. Copy3 fetched three bars and read index 0. Index 2  |
//|     is now the far end of the SLP vote, so the fetch is paid for. |
//|     Level and rate are different derivatives of one curve —       |
//|     related, but not the same number.                             |
//|                                                                   |
//|  M10 GENERALISED. One global InpDeadZoneATR gated three votes in  |
//|     price units. Each vote now carries its own threshold in its   |
//|     own units — InpSlopeATR (x ATR), InpDIThresh (DI points),     |
//|     InpDonchianPos (channel fraction), InpADThresh (pressure).    |
//|     InpStackSepATR keeps the ATR-scaled form for the one vote     |
//|     still built from a bare price comparison.                     |
//|                                                                   |
//|  M11 EXPOSED. The 1.3x timeframe ladder was arbitrary and the     |
//|     header said so. No weighting is derivable from first          |
//|     principles, so rather than swap one invented ladder for       |
//|     another it is now InpTFWeighting: LADDER (unchanged default), |
//|     FLAT, or HORIZON (1 + log2 of the bar-length ratio). Pick it  |
//|     by testing, which is the only honest way to pick it.          |
//|                                                                   |
//|  A9 RETIRED. Closes were inferred from the auto-position count    |
//|     falling, which armed the cooldown but could never say why a   |
//|     position left. OnTradeTransaction now reads the closing deal: |
//|     exact cooldown anchor, the exit reason in the log (stop loss  |
//|     / take profit / engine / manual), and a running realised W/L  |
//|     and P/L for the day on the panel. The count check stays as a  |
//|     backstop for transactions missed across a reconnect.          |
//|                                                                   |
//|  PRESETS: this pass removes InpCCIPeriod, InpCCIThresh,           |
//|  InpBBPeriod, InpBBDev and InpDeadZoneATR, and adds seven inputs. |
//|  Saved .set files from v4.0 and earlier will not load cleanly.    |
//|                                                                   |
//| v4.0 — THE AUTO TREND ENGINE                                      |
//|                                                                   |
//|  A1 SEPARATE MAGIC. Auto positions carry InpAutoMagic, manual     |
//|     ones carry MagicNumber. Position comments are not a reliable  |
//|     discriminator (brokers truncate and rewrite them), and the    |
//|     engine must never trail, break-even or reverse-exit a trade   |
//|     you placed by hand unless you ask it to. The panel's counters |
//|     and CLOSE ALL cover both magics; CLOSE AUTO covers only the   |
//|     engine's.                                                     |
//|                                                                   |
//|  A2 ONE DECISION PER SIGNAL BAR. Entries are evaluated once, at   |
//|     the open of a new InpSignalTF bar, using bar-1 (closed bar)   |
//|     data — the same data the scanner displays. No intrabar        |
//|     re-entry, no acting twice on one bar, and g_lastSigBar is     |
//|     seeded at init so attaching the EA mid-bar cannot fire an     |
//|     immediate trade. The setup line in the panel is recomputed    |
//|     every pass for display only; it never places anything.        |
//|                                                                   |
//|  A3 TREND GATES. A directional aggregate is necessary but not     |
//|     sufficient. On the signal timeframe the engine can also       |
//|     demand its own vote agree (InpRequireSignalTFAgree), the EMA  |
//|     stack point the trade's way (InpRequireStack — the stable     |
//|     structural vote, not the jumpy price-vs-EMA one), and ADX be  |
//|     out of the ranging band (InpSkipRanging). That is what makes  |
//|     this trend-FOLLOWING rather than "whatever the number says".  |
//|                                                                   |
//|  A4 STATELESS STOP MANAGEMENT. Break-even and trailing are        |
//|     derived from live price, the position's own open price, and   |
//|     ATR — never from a per-ticket table. A terminal restart, a    |
//|     recompile or a chart change therefore loses nothing: the      |
//|     stop is recomputed from scratch and can only ever ratchet in  |
//|     the position's favour.                                        |
//|                                                                   |
//|  A5 TRAILING MODES (InpTrailMode):                                |
//|       FIXED POINTS  arm at InpTrailStartPts profit, then hold     |
//|                     InpTrailDistPts behind price.                 |
//|       ATR           arm at InpTrailStartATR x ATR profit, then    |
//|                     hold InpTrailATRMult x ATR behind price, so   |
//|                     the leash widens when volatility does.        |
//|       CHANDELIER    the classic trend-following exit: highest     |
//|                     high (lowest low) of InpChandelierBars, minus |
//|                     (plus) InpTrailATRMult x ATR. Anchored to the |
//|                     swing rather than to the last tick, so a      |
//|                     retrace does not drag the stop up with it.    |
//|     Every mode is filtered through the same guards: never loosen  |
//|     an existing stop, never breach SYMBOL_TRADE_STOPS_LEVEL,      |
//|     never modify inside SYMBOL_TRADE_FREEZE_LEVEL, and never      |
//|     send a modify smaller than InpTrailStepPts (which otherwise   |
//|     means one server request per tick, all rejected or throttled).|
//|                                                                   |
//|  A6 RISK GOVERNORS. InpMaxPositions, InpOnePerDirection,          |
//|     InpCooldownBars (counted in real signal-TF bars, not          |
//|     wall-clock, so a weekend cannot skip it), InpMaxTradesPerDay  |
//|     and InpDailyLossLimitPct — the last measured against the      |
//|     equity at the first tick of the server day. All of them       |
//|     block NEW entries only; open positions are always still       |
//|     managed, because refusing to trail a live trade is not a      |
//|     safety feature.                                               |
//|                                                                   |
//|  A7 HEADLESS FALLBACK. CAppDialog cannot draw in the non-visual   |
//|     tester, and v3.2 returned INIT_FAILED when the panel failed   |
//|     to build — which made an auto engine impossible to backtest.  |
//|     If the panel cannot be created the EA now continues without   |
//|     it (tester, or auto trading explicitly enabled) instead of    |
//|     refusing to start.                                            |
//|                                                                   |
//|  A8 THE PANEL EXPLAINS ITSELF. The engine writes a one-line       |
//|     reason for its current state on every pass — "setup LONG",    |
//|     "blocked - H1 ranging (ADX 18 < 25)", "cooldown 1/2 bars".    |
//|     A bot that is silently doing nothing is indistinguishable     |
//|     from a broken one.                                            |
//|                                                                   |
//| v3.2 (ensemble correctness + cheap wins):                          |
//|                                                                   |
//|  C1 SCORING. buyPct was bull/(bull+bear), which EXCLUDES neutral  |
//|     votes from the denominator: one bull vote and five neutrals   |
//|     scored 100%, same as a unanimous 6-0. Every reading was       |
//|     pinned to 0 or 100 and carried no conviction information.     |
//|     Now scored against the full scale: 50 + (net/6)*50, so        |
//|     neutrals pull toward 50. The aggregate had the identical      |
//|     defect and is fixed the same way — it now accumulates net     |
//|     over TOTAL AVAILABLE weight rather than over cast votes.      |
//|     EXPECT MUCH LESS EXTREME NUMBERS. That is the point.          |
//|                                                                   |
//|  C2 READINESS. r.ready was set independently by the EMA block AND |
//|     the RSI block. A failed EMA copy (routine on D1, which needs  |
//|     50 days for EMA50) still left ready=true via RSI, so the      |
//|     weight-2 directional vote silently became a zero and the row  |
//|     merely looked neutral — on the highest-weighted timeframe.    |
//|     There is now ONE readiness gate for the whole timeframe.      |
//|                                                                   |
//|  H4 HISTORY GATE. Added BarsCalculated() + iBars() checks before  |
//|     any CopyBuffer. Partial MTF data now reports "loading" rather |
//|     than masquerading as neutral votes. Also retires M12 (a       |
//|     failed ADX read used to display as a real "ranging" regime    |
//|     with ADX 0) and most of L19.                                  |
//|                                                                   |
//|  H5 EMA SPLIT. The weight-2 vote bundled stable structure         |
//|     (stack order) with jumpy timing (price vs EMA9). One pullback |
//|     bar swung net by 2 — the entire BUY threshold — so the signal |
//|     flipped on noise. Now two independent weight-1 votes: STK     |
//|     (stack order) and PX (price position). Max points unchanged   |
//|     at 6, so the label thresholds still hold.                     |
//|     SUPERSEDED BY v5.0: PX was retired as collinear (see H3).     |
//|     STK survives, gains a separation gate, and is paired with     |
//|     SLP — rate rather than a second reading of level.             |
//|                                                                   |
//|  H6 REGIME GATE. ADX was computed, displayed, and never used.     |
//|     A ranging timeframe now has its directional contribution      |
//|     discounted by InpRangingWeight while still counting toward    |
//|     the denominator, so the aggregate is pulled toward neutral    |
//|     rather than simply ignoring the timeframe. STRONG calls are   |
//|     also suppressed in a ranging regime (shown as "BUY (rng)").   |
//|                                                                   |
//|  H7 SL SOURCE. Auto SL/TP used ATR of the CHART timeframe no      |
//|     matter which timeframe produced the conviction — a D1 thesis  |
//|     read from an M5 chart got an M5-sized stop. Per-timeframe ATR |
//|     handles added, plus an "ATR: <TF>" cycle button. The estimate |
//|     line always names the timeframe the stop actually came from,  |
//|     and says so explicitly when it has fallen back.               |
//|                                                                   |
//|  M10 DEAD ZONES. EMA-timing, BB and the volume vote were bare     |
//|     inequalities — a tick above the line was a full vote, so the  |
//|     ensemble was noisiest exactly when the market was undecided.  |
//|     All three now need InpDeadZoneATR * ATR(tf) of separation.    |
//|     SUPERSEDED BY v5.0: all three votes are gone and the single   |
//|     global knob with them. Every vote now carries a threshold in  |
//|     its own units; InpStackSepATR keeps the ATR-scaled form.      |
//|                                                                   |
//|  M13 CACHING. Bar-1 values only change on a new bar, but the      |
//|     whole ensemble was recomputed every second (~250 timeseries   |
//|     calls/sec; 86,400 identical recomputes per D1 bar). Now gated |
//|     on iTime() changing. Filters still run every second.          |
//|                                                                   |
//|  M15 HANDLE VALIDATION. 48 indicator handles (v5.0: 36, since CCI |
//|     and Bollinger are gone) are checked at init instead of        |
//|     degrading to permanent silent neutrality.                     |
//|                                                                   |
//| KNOWN AND DELIBERATELY NOT ADDRESSED IN THIS PASS:                |
//|   R1  STK and SLP are both built from EMAs — the ORDER of three   |
//|       and the SLOPE of one. Different derivatives, so not the     |
//|       same number, but in a clean trend they will agree most of   |
//|       the time. Residual correlation, not collinearity.           |
//|   R2  Every directional vote correlates in a strong trend. That   |
//|       is the market, not a defect. What v5.0 fixed is votes that  |
//|       computed the SAME QUANTITY and so could never disagree.     |
//|   R3  The label thresholds (net >= 2 BUY, >= 4 STRONG) were       |
//|       calibrated against the old collinear set and are carried    |
//|       over unchanged. They are now conservative rather than       |
//|       inflated, but they have not been re-derived.                |
//|   R4  AD uses TICK volume wherever the broker reports no real     |
//|       volume, so it measures activity rather than size.           |
//|   R5  A stop is not gap-proof. In the first XAUUSD run one SELL   |
//|       stop at 4063.80 filled at 4074.78 on a Monday open — 11     |
//|       dollars past it, and the largest loss of the test. Only     |
//|       position size and the daily loss limit cover that; the      |
//|       trailing stop cannot.                                       |
//|                                                                   |
//| SAFETY NETS: risk% hard-capped; risk-based auto lot; broker       |
//| min-stop-distance and freeze-level enforced; spread + free-margin |
//| guards; lot clamped to broker min/max/step (rounded DOWN);        |
//| InpAllowTrading master switch over BOTH engines; est-risk shown   |
//| before you click; auto engine off by default.                     |
//|                                                                   |
//| NOTE: the GUI needs a live/demo chart (or the VISUAL tester); the |
//| auto engine does not. Signals are analysis, not advice.           |
//+------------------------------------------------------------------+
#property copyright "AstroBot MTF Scanner"
#property link      "https://astrobot-ea.live"
#property version   "6.95"
#property strict

#define AB_VERSION "6.95"   // v6.1: one place for the number the ready-line and the journal print

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Controls\Dialog.mqh>
#include <Controls\Label.mqh>
#include <Controls\Edit.mqh>
#include <Controls\Button.mqh>
#include <Controls\Panel.mqh>

CTrade        m_trade;
CPositionInfo m_position;
CSymbolInfo   m_symbol;

//+------------------------------------------------------------------+
//| Enumerations used by the inputs                                  |
//+------------------------------------------------------------------+
//--- Values are indices into g_tf[] / g_tfName[], so a selection here
//--- reuses the scanner's already-computed result for that timeframe
//--- instead of opening a second set of indicator handles.
//--- v6.0 BREAKING: M1 is inserted at index 0, so every ordinal below
//--- shifted up by one. A .set file written by v5.x carries RAW ORDINALS,
//--- not names — InpSignalTF=3 meant H1 there and means M30 here. Re-pick
//--- both TF inputs by hand after loading any older preset.
enum ENUM_SIG_TF
{
   SIG_M1  = 0,   // M1
   SIG_M5  = 1,   // M5
   SIG_M15 = 2,   // M15
   SIG_M30 = 3,   // M30
   SIG_H1  = 4,   // H1
   SIG_H4  = 5,   // H4
   SIG_D1  = 6,   // D1
   //--- v6.5: appended, so every ordinal above keeps its meaning and old
   //--- .set files still load. CHART follows whatever chart the EA sits on,
   //--- and falls back to M5 when that period is not one of the seven.
   SIG_CHART = 7  // CHART - follow the chart's own timeframe
};

//--- C2: what the drawdown limit measures against. The distinction is not
//--- academic — the first live test of C1 halted the engine on day one
//--- because a trailing exit gave back open profit, which the equity-peak
//--- basis scores identically to losing capital.
enum ENUM_DD_BASIS
{
   DD_FROM_BALANCE = 0,   // BALANCE PEAK - giving back OPEN profit is not a drawdown
   DD_FROM_EQUITY  = 1    // EQUITY PEAK - every tick of give-back counts (prop-firm trailing rule)
};

enum ENUM_TRAIL_MODE
{
   TRAIL_OFF        = 0,   // OFF - the stop stays where it was placed
   TRAIL_POINTS     = 1,   // FIXED POINTS - constant distance behind price
   TRAIL_ATR        = 2,   // ATR - distance scales with volatility
   TRAIL_CHANDELIER = 3    // CHANDELIER - swing high/low minus ATR
};

//--- M11: no timeframe weighting is derivable from first principles, so
//--- the choice is exposed rather than invented a second time.
enum ENUM_TFW
{
   TFW_LADDER  = 0,   // LADDER - the legacy 1.3x step (M5 1.0 ... D1 3.4)
   TFW_FLAT    = 1,   // FLAT - every timeframe counts the same
   TFW_HORIZON = 2    // HORIZON - 1 + log2 of the bar-length ratio vs M5
};

//--- v6.1/D1: whether ENTRY / EXIT rows reach a CSV, and where. The
//--- per-position tracker behind them runs regardless (see AB_Journal.mqh).
enum ENUM_JOURNAL
{
   JOURNAL_OFF       = 0,   // OFF - no file
   JOURNAL_LIVE      = 1,   // LIVE / DEMO only
   JOURNAL_LIVE_TEST = 2    // LIVE / DEMO + single tester runs (optimisation passes only via InpOptJournalFrames)
};

//--- v6.1/D3: what OnTester hands the optimiser under "Custom max".
enum ENUM_SCORE
{
   SCORE_SQN      = 0,   // SQN - sqrt(min(N,100)) x mean(R) / stdev(R), x drawdown factor
   SCORE_PF_SQRTN = 1,   // (PF - 1) x sqrt(N), x drawdown factor
   SCORE_RECOVERY = 2    // recovery factor (net / worst drawdown), x drawdown factor
};

//--- v6.7: how many timeframes each WATCHED symbol gets. MT5 allows 512
//--- indicator handles per chart and the chart symbol already spends 43,
//--- so this input is the handle budget: 6 handles per timeframe per
//--- symbol. A watchlist says WHERE to look, and M1/M5 are noise at that.
enum ENUM_WTF
{
   WTF_H1_D1  = 0,   // H1 H4 D1 - 18 handles each, about 25 symbols
   WTF_M15_D1 = 1,   // M15 H1 H4 D1 - 24 handles each, about 19 symbols
   WTF_ALL    = 2    // all seven - 42 handles each, about 11 symbols
};

//--- v6.2/E3: an auto position the stop guard cannot protect.
enum ENUM_NOSTOP
{
   NOSTOP_CLOSE = 0,   // CLOSE - still no stop after the grace period: close it at market
   NOSTOP_WARN  = 1    // WARN - keep it, keep trying every second, and log
};

//+------------------------------------------------------------------+
//| Inputs                                                           |
//+------------------------------------------------------------------+
input group "=== Trading ==="
input bool     InpAllowTrading      = true;               // InpAllowTrading - Master switch over BOTH engines (buttons AND auto)
input ulong    MagicNumber          = 20260726;           // MagicNumber - Magic for MANUAL (button) trades
input double   InpDefaultLot        = 0.01;               // InpDefaultLot - Starting lot in the ticket
input double   InpDefaultRisk       = 1.0;                // InpDefaultRisk - Starting risk % (capped by InpMaxRiskPct)
input double   InpMaxRiskPct        = 2.0;                // InpMaxRiskPct - Hard cap on risk per trade (%) - applies to auto too
input int      InpMaxSpreadPoints   = 0;                  // InpMaxSpreadPoints - Block entry above this spread (0 = off)

input group "=== Auto SL/TP (ATR source selectable in the panel) ==="
input int      InpATRPeriod         = 14;                 // InpATRPeriod
input double   InpSL_ATR_Mult       = 1.5;                // InpSL_ATR_Mult - SL distance = mult * ATR(selected TF)
input double   InpTP_RR             = 2.0;                // InpTP_RR - TP = SL * this reward:risk

//+------------------------------------------------------------------+
//| The six votes. Each one measures a DIFFERENT property, and each   |
//| carries its own dead zone in its own natural units (H3/M10).      |
//+------------------------------------------------------------------+
input group "=== Ensemble: STK + SLP (EMA structure and rate) ==="
input int      InpEMAFast           = 9;                  // InpEMAFast
input int      InpEMAMedium         = 21;                 // InpEMAMedium
input int      InpEMASlow           = 50;                 // InpEMASlow
input double   InpStackSepATR       = 0.15;               // InpStackSepATR - STK: adjacent EMAs must be this far apart, x ATR
input double   InpSlopeATR          = 0.10;               // InpSlopeATR - SLP: EMA-medium must move this x ATR over 2 bars

input group "=== Ensemble: DMI + RSI (movement and momentum) ==="
input int      InpADXPeriod         = 14;                 // InpADXPeriod
input double   InpADXMin            = 25.0;               // InpADXMin - below = "ranging" tag
input double   InpDIThresh          = 5.0;                // InpDIThresh - DMI: +DI vs -DI gap needed for a directional vote
input int      InpRSIPeriod         = 14;                 // InpRSIPeriod
input double   InpRSIBull           = 55.0;               // InpRSIBull
input double   InpRSIBear           = 45.0;               // InpRSIBear

input group "=== Ensemble: DON + AD (range position and pressure) ==="
input int      InpDonchianBars      = 20;                 // InpDonchianBars - DON: channel lookback in bars
input double   InpDonchianPos       = 0.75;               // InpDonchianPos - DON: close above this share of the channel = bull
input int      InpADBars            = 5;                  // InpADBars - AD: bars of volume-weighted pressure
input double   InpADThresh          = 0.25;               // InpADThresh - AD: |pressure| beyond this = directional vote

input group "=== Ensemble: aggregation ==="
input ENUM_TFW InpTFWeighting       = TFW_LADDER;         // InpTFWeighting - how much more a higher timeframe counts
input double   InpRangingWeight     = 0.5;                // InpRangingWeight - discount a ranging TF's vote by this
//--- v6.5/H1: a vote one tick past its threshold used to weigh exactly as
//--- much as one deep in its own territory. Graded votes ramp from 0 at the
//--- threshold to a full 1 at saturation, so conviction means something.
input bool     InpGradedVotes       = true;               // InpGradedVotes - votes carry strength (0..1) instead of a bare 0/1
//--- R3, finally exposed. These were calibrated against the pre-v5.0
//--- collinear vote set and carried over unexamined ever since.
input double   InpLabelBuyNet       = 2.0;                // InpLabelBuyNet - net at or above this = BUY
input double   InpLabelStrongNet    = 4.0;                // InpLabelStrongNet - net at or above this = STRONG BUY

input group "=== Verdict (what the panel tells you to do) ==="
input ENUM_SIG_TF InpConfirmTF      = SIG_H1;             // InpConfirmTF - the higher timeframe the verdict wants on side
input bool     InpVerdictUseConfirm = true;               // InpVerdictUseConfirm - count the confirm TF as one of the verdict's checks
input bool     InpRequireConfirmTF  = false;              // InpRequireConfirmTF - AUTO engine also refuses entries the confirm TF opposes

input group "=== Filters ==="
input bool     UseNYSessionFilter   = false;              // UseNYSessionFilter
input int      NY_Session_Hour      = 12;                 // NY_Session_Hour - Server time
input int      NY_Session_Minute    = 0;                  // NY_Session_Minute
input int      Hours_Before_NY      = 1;                  // Hours_Before_NY
input int      Hours_After_NY       = 2;                  // Hours_After_NY
input bool     UseNewsFilter        = false;              // UseNewsFilter
input int      Minutes_Before_News  = 30;                 // Minutes_Before_News
input int      Minutes_After_News   = 30;                 // Minutes_After_News

//+------------------------------------------------------------------+
//| AUTO TREND ENGINE                                                |
//|                                                                  |
//| Entry requires ALL of the enabled gates below to agree. The       |
//| aggregate says WHETHER there is a trend; the signal-TF gates say  |
//| whether it is the kind of trend worth joining.                   |
//+------------------------------------------------------------------+
input group "=== Auto Trend Engine: signal ==="
input bool        InpEnableAutoTrading    = false;        // InpEnableAutoTrading - AUTO-EXECUTE trades (OFF = analysis only)
input ulong       InpAutoMagic            = 20260727;     // InpAutoMagic - Magic for AUTO trades (must differ from MagicNumber)
//--- v6.5: M1 was the v6.0 default and a full year of it said the spread
//--- eats the edge — 24.9 points of spread against a 401-point stop is
//--- 7.8% of risk per trade, while the ensemble is worth about 6.8%. M5
//--- spreads the same signal over a stop roughly twice as wide.
input ENUM_SIG_TF InpSignalTF             = SIG_M5;       // InpSignalTF - Entries are decided at the open of each bar of this TF (CHART = follow the chart)
input double      InpAutoBuyPct           = 65.0;         // InpAutoBuyPct - Overall BUY% at or above this = long setup
input double      InpAutoSellPct          = 35.0;         // InpAutoSellPct - Overall BUY% at or below this = short setup
input bool        InpRequireSignalTFAgree = true;         // InpRequireSignalTFAgree - The signal TF's own verdict must point the same way
input bool        InpRequireStack         = true;         // InpRequireStack - EMA stack on the signal TF must point the same way
input bool        InpSkipRanging          = true;         // InpSkipRanging - No entries while ADX(signal TF) < InpADXMin
input bool        InpRespectFilters       = true;         // InpRespectFilters - Session/news filters also block auto entries
input bool        InpExitOnReversal       = true;         // InpExitOnReversal - Close an auto position when the bias flips past the far threshold

input group "=== Auto Trend Engine: sizing and stops ==="
input bool        InpAutoUseRiskPct       = true;         // InpAutoUseRiskPct - true = size from InpAutoRiskPct, false = InpAutoFixedLot
input double      InpAutoRiskPct          = 1.0;          // InpAutoRiskPct - Risk per auto trade (%) - still capped by InpMaxRiskPct
input double      InpAutoFixedLot         = 0.01;         // InpAutoFixedLot - Lot when InpAutoUseRiskPct = false
input double      InpAutoSL_ATR_Mult      = 0.0;          // InpAutoSL_ATR_Mult - SL = mult * ATR(signal TF). 0 = inherit InpSL_ATR_Mult
input double      InpAutoTP_RR            = 0.0;          // InpAutoTP_RR - TP = SL * this. 0 = no fixed TP, let the trail decide
//--- v6.0/B1: on M1 the ATR stop routinely lands INSIDE the broker's own
//--- minimum distance. The floor is applied before sizing so the lot is
//--- computed against the stop that will actually be sent.
input int         InpMinSLPoints          = 0;            // InpMinSLPoints - hard floor on the auto SL, in points (0 = broker minimum only)

input group "=== Auto Trend Engine: risk governors ==="
input int         InpMaxPositions         = 3;            // InpMaxPositions - Max simultaneous AUTO positions (hard ceiling 5)
input bool        InpOnePerDirection      = false;        // InpOnePerDirection - v6.0: false lets the engine stack; true restores v5.x
input int         InpCooldownBars         = 2;            // InpCooldownBars - Signal-TF bars to wait after an auto position closes
input int         InpMaxTradesPerDay      = 0;            // InpMaxTradesPerDay - Max auto entries per server day (0 = unlimited)
input double      InpDailyLossLimitPct    = 0.0;          // InpDailyLossLimitPct - Stop new entries after this % equity drawdown today (0 = off)
//--- v6.0/B2+B3: the two governors that make stacking mean something.
//--- Without separation, five entries on five consecutive M1 bars are one
//--- trade at five times the size and five times the spread. Without a
//--- total-risk ceiling, InpAutoRiskPct silently multiplies by the count.
input int         InpMinBarsBetweenEntries= 3;            // InpMinBarsBetweenEntries - signal-TF bars that must pass between two auto ENTRIES (0 = off)
input double      InpStackMinSepATR       = 0.75;         // InpStackMinSepATR - a new entry must be this x ATR from the nearest same-way position (0 = off)
input double      InpMaxTotalRiskPct      = 3.0;          // InpMaxTotalRiskPct - ceiling on COMBINED open risk of all auto positions (0 = off)
input double      InpMaxSpreadATR         = 0.20;         // InpMaxSpreadATR - block entry when spread exceeds this x ATR (0 = off)
//--- v6.02/C1: the absolute drawdown governor. InpDailyLossLimitPct above
//--- resets every server day and so bounds nothing over a month; this one
//--- measures from the equity high-water mark and does not reset.
input double      InpMaxDrawdownPct       = 10.0;         // InpMaxDrawdownPct - HALT auto entries at this % drawdown (0 = off)
input ENUM_DD_BASIS InpDD_Basis           = DD_FROM_BALANCE; // InpDD_Basis - measure that drawdown against WHICH peak
input bool        InpDD_FlattenOnBreach   = false;        // InpDD_FlattenOnBreach - also close every auto position when the limit is hit

input group "=== Trailing Stop ==="
input ENUM_TRAIL_MODE InpTrailMode        = TRAIL_ATR;    // InpTrailMode - Trailing method (start value of the panel's TRAIL button)
input ENUM_SIG_TF     InpTrailTF          = SIG_M15;      // InpTrailTF - TF whose ATR / swings drive the trail
input double          InpTrailATRMult     = 2.0;          // InpTrailATRMult - ATR + CHANDELIER: stop distance = mult * ATR
input double          InpTrailStartATR    = 1.0;          // InpTrailStartATR - ATR + CHANDELIER: arm once profit >= mult * ATR
input int             InpChandelierBars   = 22;           // InpChandelierBars - CHANDELIER: bars of swing high/low lookback
input int             InpTrailStartPts    = 200;          // InpTrailStartPts - FIXED POINTS: arm once profit >= this many points
input int             InpTrailDistPts     = 150;          // InpTrailDistPts - FIXED POINTS: stop distance behind price
input int             InpTrailStepPts     = 10;           // InpTrailStepPts - ALL MODES: min improvement in POINTS before a modify
input double          InpTrailStepATR     = 0.05;         // InpTrailStepATR - min improvement as x ATR - the LARGER gate wins (0 = points only)
input int             InpTrailMinSeconds  = 5;            // InpTrailMinSeconds - hard floor on seconds between modifies of one position (0 = off)
input bool            InpTrailManagesManual = false;      // InpTrailManagesManual - Also trail/break-even positions you placed by hand
input bool            InpUseBreakEven     = true;         // InpUseBreakEven - Move the stop to entry once in profit
input int             InpBE_TriggerPts    = 0;            // InpBE_TriggerPts - BE trigger in points (0 = the auto SL distance, approx 1R)
input int             InpBE_LockPts       = 20;           // InpBE_LockPts - Points beyond entry the break-even stop locks in

input group "=== Measurement and state (v6.1) ==="
input bool         InpPersistState     = true;            // InpPersistState - keep peaks, HALT latch and day anchor across restarts (terminal global variables)
input bool         InpResetState       = false;           // InpResetState - wipe that stored state at start - the deliberate re-arm after a HALT (set back to false after)
input ENUM_JOURNAL InpJournal          = JOURNAL_LIVE_TEST; // InpJournal - trade journal CSV under Common\Files\AstroBot\
input bool         InpOptJournalFrames = false;           // InpOptJournalFrames - optimisation - also ship every pass's journal to the terminal (heavy)
input ENUM_SCORE   InpScore            = SCORE_SQN;       // InpScore - custom optimisation criterion (pick "Custom max" in the tester)
input int          InpScoreMinTrades   = 30;              // InpScoreMinTrades - fewer closed trades than this scores 0
input double       InpScoreDDCap       = 20.0;            // InpScoreDDCap - score falls linearly to 0 as max drawdown (basis = InpDD_Basis) nears this %

input group "=== Watchlist: scan other pairs (v6.7) ==="
//--- Comma separated, exactly as your broker names them - suffixes and all
//--- ("EURUSD.m, XAUUSD.m"). Empty means the chart symbol only. These are
//--- SCANNED, never traded: the engine and both journals stay on the chart.
input string    InpWatchSymbols          = "";            // InpWatchSymbols - Other pairs to scan, comma separated (empty = off)
input ENUM_WTF  InpWatchTFs              = WTF_M15_D1;    // InpWatchTFs - Timeframes per watched symbol - this is the handle budget
input bool      InpWatchSortByConviction = true;          // InpWatchSortByConviction - Strongest reading first, rather than the order you typed

input group "=== Signal history (v6.93) ==="
//--- What the ensemble said at each lookback, recomputed from closed bars,
//--- plus where price has gone since. A consistency check more than proof.
input bool     InpShowHistory   = true;                // InpShowHistory - Show the ensemble 15m, 30m, 1h, 4h and 1d ago
input string   InpHistLookbacks = "15,30,60,240,1440";  // InpHistLookbacks - Lookbacks in MINUTES, comma separated (up to 6)

input group "=== JSON feed to a website (v6.9) ==="
//--- The URL must ALSO be whitelisted by hand: Tools > Options > Expert
//--- Advisors > "Allow WebRequest for listed URL". Code cannot do it. Until
//--- it is there every call returns -1 with error 4014 and nothing is sent.
input string InpApiUrl          = "";                     // InpApiUrl - POST the panel state here as JSON (empty = off)
input string InpApiKey          = "";                     // InpApiKey - Sent as the X-API-Key header
input int    InpApiMinSeconds   = 5;                      // InpApiMinSeconds - Never send more often than this
input int    InpApiHeartbeatSec = 60;                     // InpApiHeartbeatSec - Send even when unchanged, so the dashboard can spot a dead feed
input int    InpApiTimeoutMs    = 2000;                   // InpApiTimeoutMs - Keep this short - WebRequest blocks the EA while it waits
input bool   InpApiDebugFile    = true;                   // InpApiDebugFile - Also write the last payload to Common\Files\AstroBot\last_payload.json

input group "=== Exposure and hedging (v6.8) ==="
//--- Currency netting is exact arithmetic. Correlation is a description of
//--- the recent past and nothing more: it is shown with the window it was
//--- measured over, and it is never called a hedge that is in place.
input bool        InpShowHedge   = true;                  // InpShowHedge - Net currency exposure and offsetting-pair suggestions
input ENUM_SIG_TF InpCorrTF      = SIG_H1;                // InpCorrTF - Timeframe the correlation is measured on
input int         InpCorrBars    = 120;                   // InpCorrBars - Bars in the correlation window (20..400)
input double      InpCorrMinAbs  = 0.50;                  // InpCorrMinAbs - Below this |correlation| no offset is suggested

input group "=== Trader journal: your decisions, not the engine's (v6.6) ==="
input bool     InpTraderJournal    = true;                // InpTraderJournal - Record every position YOU open or close, with the context you decided in
input int      InpRevengeMinutes   = 15;                  // InpRevengeMinutes - A trade opened this soon after a LOSS is flagged as revenge
input double   InpOversizeRatio    = 1.5;                 // InpOversizeRatio - Lot beyond this multiple of your own risk% sizing counts as oversized
input int      InpReportMinN       = 20;                  // InpReportMinN - A split with fewer trades than this is reported as too thin to read
input bool     InpReportOnDeinit   = false;               // InpReportOnDeinit - Also write the report when the EA is removed

input group "=== Safety (v6.2) ==="
input bool         InpDupGuard         = true;            // InpDupGuard - one engine per symbol+magic - a second chart runs as a scanner only
input ENUM_NOSTOP  InpNoStopAction     = NOSTOP_CLOSE;    // InpNoStopAction - an auto position that cannot be given a stop
input int          InpNoStopGraceSec   = 15;              // InpNoStopGraceSec - seconds of trying before InpNoStopAction applies

input group "=== Tester and weekend (v6.3) ==="
input int          InpTesterReArmDays  = 1;               // InpTesterReArmDays - TESTER ONLY - re-arm a latched HALT this many server days later, peaks reset (0 = stay halted, as live)
input bool         InpWeekendFlatten   = true;            // InpWeekendFlatten - from the Friday cut-off: no auto entries, and every auto position is closed
input int          InpFridayCutoffHour = 22;              // InpFridayCutoffHour - Friday cut-off, server time - hour
input int          InpFridayCutoffMin  = 0;               // InpFridayCutoffMin - Friday cut-off, server time - minute

input group "=== Panel ==="
input int      Panel_X              = 12;                 // Panel_X
input int      Panel_Y              = 12;                 // Panel_Y
//--- v6.51: 530 fitted about 63 characters on a 150%-scaled display and
//--- clipped every longer line. The layout is width-derived now, so this
//--- is a real knob: raise it if your display scaling is higher still.
input int      Panel_W              = 620;                // Panel_W - client = W - 4; all columns derive from this
input int      Panel_H              = 620;                // Panel_H - minimum height; the panel grows itself to fit (client = H - 24: caption 22 + border 2)

//+------------------------------------------------------------------+
//| Dark theme                                                       |
//|                                                                  |
//| Contrast ratios against C_PANEL (approx, WCAG relative luminance):|
//|   C_TEXT  15.4:1   C_HEAD  12.1:1   C_BULL   9.9:1               |
//|   C_DIM    7.9:1   C_BEAR   6.3:1   C_WARN   8.6:1               |
//+------------------------------------------------------------------+
#define C_PANEL   C'15,17,24'     // client backdrop
#define C_CARD    C'26,30,42'     // section header bands
#define C_CAPTION C'30,34,46'
#define C_BORDER  C'88,96,118'
#define C_TEXT    C'236,240,248'
#define C_HEAD    C'255,205,92'
#define C_BULL    C'70,225,120'
#define C_BEAR    C'255,105,95'
#define C_DIM     C'166,175,196'
#define C_WARN    C'255,172,64'
#define C_EDIT_BG C'44,50,66'
#define C_SEP     C'48,54,70'
#define C_TRACK   C'34,39,52'     // gauge track fill
#define C_TABON   C'40,100,180'   // v6.95: the tab on show, and the frame around its content
#define C_TABOFF  C'30,34,46'     // v6.95: the tabs behind it

//+------------------------------------------------------------------+
//| Timeframe set + analysis state                                   |
//+------------------------------------------------------------------+
#define TF_COUNT 7

//--- v6.0: the hard ceiling on simultaneous AUTO positions. This is a
//--- compile-time limit, not a preference — TRAIL_SLOTS and the risk
//--- governors are sized against it, and OnInit refuses to start above it.
#define MAX_AUTO_POSITIONS 5

//--- C1 + H3: the full directional scale. Six unit votes, six DIFFERENT
//--- measurements — structure, rate, directional movement, momentum,
//--- range position, volume-weighted pressure. net lives in [-6,+6] and
//--- buyPct maps it onto [0,100].
#define MAX_PTS 6.0

ENUM_TIMEFRAMES g_tf[TF_COUNT];
string          g_tfName[TF_COUNT];
double          g_tfW[TF_COUNT];

struct MTFHandles { int emaF, emaM, emaS, rsi, adx, atr; };
MTFHandles g_H[TF_COUNT];

struct TFResult
{
   bool   ready;
   double bullPts, bearPts;
   double buyPct;
   int    dir;
   string label;
   string breakdown;
   double adx;
   bool   ranging;
   double atrVal;      // H7: this TF's own ATR, in price units
   //--- A3: the raw vote signs are kept so the auto engine can gate on
   //--- an individual vote (the EMA stack) rather than only on the
   //--- summary. Previously these lived and died inside AnalyzeTF.
   int    stkS, slpS, dmiS, rsiS, donS, adS;
   //--- v6.5/H1: the same six votes as graded strengths in [-1,+1]. The
   //--- signs above still drive the arrows and the stack gate; these drive
   //--- the score. With InpGradedVotes off they are simply the signs.
   double stkV, slpV, dmiV, rsiV, donV, adV;
};
TFResult g_R[TF_COUNT];

datetime g_lastBar[TF_COUNT];      // M13: new-bar cache key per timeframe
datetime g_lastBarChart = 0;

double g_overallBuyPct = 50.0;
int    g_overallDir    = 0;
string g_overallLabel  = "NEUTRAL";
int    g_up=0, g_dn=0, g_nt=0;

int    g_atr_cur  = INVALID_HANDLE;
double g_atrChart = 0;
string g_atrSrc   = "-";           // which TF the live auto-stop actually came from

struct NewsEvent { datetime t; string title; int impact; };
NewsEvent g_news[];
datetime  g_newsUpdate = 0;
string    g_sessionMsg = "OK";
string    g_newsMsg    = "clear";
string    g_volMsg     = "-";
double    g_volRatio   = 0;        // v6.1/D1: ATR(1) / 20-bar mean ATR, the number behind g_volMsg's tag
bool      g_sessionBlock = false;  // A3: booleans instead of comparing display strings
bool      g_newsBlock    = false;

//--- UI state
double g_ui_lot     = 0.01;
double g_ui_risk    = 1.0;
double g_ui_slPts   = 0;
double g_ui_tpPts   = 0;
bool   g_ui_auto    = true;
bool   g_ui_riskMode= true;
int    g_ui_atrTF   = -1;          // -1 = chart TF, else index into g_tf[]
string g_lastAction = "ready";
bool   g_headless   = false;       // A7: panel could not be built; engine runs anyway

//--- auto engine state
bool            g_auto_on      = false;          // runtime mirror of InpEnableAutoTrading
ENUM_TRAIL_MODE g_trailMode    = TRAIL_ATR;      // runtime mirror of InpTrailMode
string          g_autoMsg      = "auto OFF";
bool            g_autoSetup    = false;          // a valid setup exists right now (display only)
datetime        g_lastSigBar   = 0;              // A2: the signal bar already acted on
datetime        g_lastCloseBar = 0;              // A6: cooldown anchor
datetime        g_lastEntryBar = 0;              // B5: stack-pacing anchor
double          g_eqPeak       = 0;              // C1: equity high-water mark
double          g_balPeak      = 0;              // C2: balance (realised) high-water mark
bool            g_ddHalt       = false;          // C1: latched once the limit is breached
int             g_prevAutoCount= 0;              // A9: close detection by count
//--- v6.2 safety pack
bool            g_netting      = false;          // E2: netting / exchange account - the engine will not arm
bool            g_marginChecked= false;          // E2: margin mode is read once the account is known, not at init
datetime        g_netLastTry   = 0;              // E3: stopless net sends at most one request per second
datetime        g_netLastLog   = 0;              // E3: and logs a persisting failure at most every 10 s
ulong           g_lastFillPosId = 0;             // E3: snapshot of the last fill, taken before any post-fill modify
double          g_lastFillPrice = 0;             //     can overwrite m_trade's last result (the journal reads these)
double          g_lastFillVolume= 0;
//--- v6.3
bool            g_isTester     = false;          // cached MQL_TESTER
int             g_haltCount    = 0;              // F1: halts this run
datetime        g_haltTime     = 0;              // F1: when the current halt latched
datetime        g_haltReArmAt  = 0;              // F1: tester-only automatic re-arm moment (0 = never)
long            g_haltedSecs   = 0;              // F1: time spent halted, summed at each re-arm
datetime        g_lastWeekendFlatten = 0;        // F2: CloseAuto throttle inside the weekend window
string          g_closeTag     = "";             // F3: why the engine last closed something (journal exit_kind)
datetime        g_dayStamp     = 0;
double          g_dayStartEq   = 0;
int             g_tradesToday  = 0;
//--- A9: realised results, filled by OnTradeTransaction from closing deals
int             g_autoWins     = 0;
int             g_autoLosses   = 0;
double          g_autoRealized = 0;
//--- A10: when each position's stop was last moved, so the trail cannot
//--- machine-gun the server. Small fixed ring — InpMaxPositions is a
//--- handful, and losing it on restart costs at most one extra modify.
#define TRAIL_SLOTS 16
ulong           g_trailTicket[TRAIL_SLOTS];
datetime        g_trailWhen[TRAIL_SLOTS];

//+------------------------------------------------------------------+
//| v6.5/H3: THE VERDICT. One block that answers the only question a  |
//| person actually has in front of a scanner: do I take this, and    |
//| at what price.                                                    |
//|                                                                  |
//| Everything above it is evidence — seven rows of votes, a gauge, a |
//| percentage. None of that is an instruction, and reading six       |
//| arrows across seven timeframes to reach a decision is work the    |
//| machine should have done. The verdict states the side, grades how |
//| much of the evidence agrees, prints the entry, stop, target and   |
//| size the BUY or SELL button would actually use, and lists what is |
//| for the trade and what is against it. When there is no trade it   |
//| says so and says what is missing.                                 |
//+------------------------------------------------------------------+
struct ABVerdict
{
   int    dir;          // +1 long, -1 short, 0 stand aside
   int    pass, total;  // checks passed out of checks made
   string grade;        // A, B, C, or "-" when there is no setup
   string head;         // the line that says what to do
   string levels;       // entry / stop / target / size
   string pros, cons;   // what argues for it, and what argues against
};
ABVerdict g_V;

//--- forward decls
void   BuildVerdict();
//--- v6.7: the ensemble, for any symbol - the watchlist calls the same code
void   AnalyzeOne(const string sym,const ENUM_TIMEFRAMES tf,const MTFHandles &H,TFResult &r,const int shift);
bool   TFDataReadyFor(const string sym,const ENUM_TIMEFRAMES tf,const MTFHandles &H,const int shift);
int    MinBarsNeeded();
bool   HandleHasBars(int h);
string LabelFromNet(double net,bool ranging,int &dir);
color  DirColor(int dir);
void   AnalyzeAll();
void   UpdateFilters();
void   UpdateVolatility();
void   UpdateAutoStops();
void   LoadNewsCalendar();
void   SetBestFillingMode();
double RiskToLot(double slPts);
double RiskToLotPct(double slPts,double pct);
double LossPerLot(double slPts);
double NormalizeLot(double lot);
double EffSLpts();
double EffTPpts();
void   PlaceManual(bool isBuy);
void   CloseAll(string reason);
void   CloseAuto(string reason);
void   PosCounts(int &b,int &s);
void   AutoPosCounts(int &b,int &s);
double FloatingPL();
string TfName(ENUM_TIMEFRAMES tf);
int    CurrentTFIndex();
color  DirColor(int dir);
//--- auto engine
void   RunEngine();
void   AutoEngine();
void   ManagePositions();
bool   EvaluateSetup(int &dir,string &why);
void   PlaceAuto(bool isBuy,const string why);
double AutoSLPts();
double AutoSLMult();
double AutoATR();
//--- v6.0
double MinStopPoints();
double OpenAutoRiskPct();
bool   AutoStackOK(int dir,string &why);
//--- v6.02
void   UpdateDrawdown();
double CurrentDDPct();
int    SigIdx();
ENUM_TIMEFRAMES SigTF();
int    TrailIdx();
ENUM_TIMEFRAMES TrailTF();
string TrailModeName(ENUM_TRAIL_MODE m);
void   RollDay();
double DayPnLPct();
void   ApplyTFWeights();
string DealReasonName(long r);
//--- v6.4/G1: every close and modify goes through these, under the
//--- POSITION's magic rather than whatever m_trade was last set to.
bool   ClosePos(const ulong ticket,const long magic);
bool   ModifyPos(const ulong ticket,const double sl,const double tp,const long magic);

//+------------------------------------------------------------------+
//| v6.1: measurement and state live in their own files. Included     |
//| here, after every global they read and before anything that calls |
//| them. Each file says what it is for at the top.                   |
//+------------------------------------------------------------------+
#include "AB_State.mqh"      // D2: peaks, HALT latch and day anchor across restarts; history rebuild
#include "AB_Journal.mqh"    // D1: ENTRY / EXIT rows with the full ensemble state; MFE / MAE / initial R
#include "AB_Tester.mqh"     // D3: custom optimisation criterion; per-pass frames to CSV
#include "AB_Trader.mqh"     // v6.6: the TRADER's journal — your decisions, graded against the panel
#include "AB_Watch.mqh"      // v6.7: the same ensemble across other pairs, display only
#include "AB_Hedge.mqh"      // v6.8: currency exposure netting and correlation-based offsets
//--- v6.94: History BEFORE Api. The feed now reads g_hist, and MQL5 needs a
//--- global declared before any function that reads it - functions resolve
//--- in any order, variables do not.
#include "AB_History.mqh"    // v6.93: the ensemble at past moments, recomputed from closed bars
#include "AB_Api.mqh"        // v6.9: push the whole panel state to a website as JSON

//+------------------------------------------------------------------+
//| v6.52: measure text instead of guessing at it.                    |
//|                                                                  |
//| This panel was fitted twice against an assumed pixels-per-        |
//| character, and both assumptions were wrong. The real figure       |
//| depends on the display's DPI scaling, which the EA cannot know    |
//| and the user should not have to tell it: the same 8pt Consolas    |
//| is about 5.3 px per character at 100% scaling and about 8 at      |
//| 150%. Guessing produced silently truncated lines, because CLabel  |
//| clips rather than wraps and gives no sign it has done so.         |
//|                                                                  |
//| TextGetSize asks the terminal how wide a string will ACTUALLY be, |
//| at the exact font and size it is about to be drawn, on THIS       |
//| display. Everything below fits against that measurement, so the   |
//| panel is correct at any scaling and at any Panel_W.               |
//+------------------------------------------------------------------+
int TextPxWidth(const string s,const int fs,const string fn="Consolas")
{
   uint w=0,h=0;
   //--- a negative size is tenths of a point, which is the DPI-aware form
   //--- and the same one OBJPROP_FONTSIZE uses
   TextSetFont(fn,-fs*10);
   if(!TextGetSize(s,w,h)) return (int)(StringLen(s)*fs*2);   // fallback: deliberately pessimistic
   return (int)w;
}

//+------------------------------------------------------------------+
//| v6.95: THE TAB STRIP                                             |
//|                                                                  |
//| Bias, history, hedge and stats were four stacked sections, and   |
//| the panel had grown taller than most charts. CAppDialog minimises |
//| itself on every chart change while the chart is shorter than the |
//| dialog, so past that height the panel kept collapsing. The four  |
//| now share one area under a row of tabs, between the filters and |
//| the ticket.                                                      |
//|                                                                  |
//| The area is sized ONCE, to the tallest tab, and never changes    |
//| with the selection. A panel that resized per tab would move the  |
//| BUY and SELL buttons under the mouse, which a trading panel must |
//| never do.                                                        |
//|                                                                  |
//| Only the tab on show is drawn each second. SetTab draws the new  |
//| one before showing it, so a switch never flashes stale text.     |
//+------------------------------------------------------------------+
#define TAB_COUNT     4
#define TAB_BIAS      0
#define TAB_HIST      1
#define TAB_HEDGE     2
#define TAB_STATS     3
#define TAB_BTN_H     22
#define TAB_GAP       3
#define TAB_ROWS      8     // lines under a tab's caption: now + 6 lookbacks + summary, or the stats grid + a finding
#define TAB_CONTENT_H (24+TAB_ROWS*14)
#define TAB_MAX_CTL   64    // controls registered to a tab

//--- the tab on show. UI state like g_ui_auto: it survives a timeframe
//--- change and starts on MARKET BIAS when the EA is attached.
int g_uiTab = TAB_BIAS;

//--- where the strip sits, and the offset that puts the ticket under it.
//--- OnInit sizes the panel from the same numbers BuildControls lays it
//--- out with, so the two can never drift apart.
int TabStripY()     { return 176+(TF_COUNT-6)*14; }
int PanelTicketDY() { return TabStripY()+TAB_BTN_H+TAB_CONTENT_H+6-240; }

//+------------------------------------------------------------------+
//| The panel                                                        |
//+------------------------------------------------------------------+
class CScannerPanel : public CAppDialog
{
private:
   CPanel  m_bg;
   CPanel  m_band1, m_band3, m_band4;
   CPanel  m_sep1, m_sep2, m_sep5;

   CLabel  m_sub, m_mtfHdr, m_col;
   CLabel  m_tf[TF_COUNT];
   CLabel  m_fltHdr, m_flt;
   //--- v6.95: the tab strip, the frame its content sits in, and a register
   //--- of which control belongs to which tab
   CButton m_tabBtn[TAB_COUNT];
   CPanel  m_tabCard;
   CWnd   *m_tw[TAB_MAX_CTL];
   int     m_twTab[TAB_MAX_CTL];
   int     m_twN;
   int     m_inW;                          // text width inside the frame
   //--- tab 0: overall market bias, with the verdict card (v6.5)
   CLabel  m_ovHdr, m_bias, m_gPct;
   CPanel  m_gTrack, m_gBuy, m_gSell, m_gMid;
   CPanel  m_bandV;
   CLabel  m_vHead, m_vLev, m_vPros, m_vCons;
   int     m_vW;
   //--- tab 1: signal history (v6.93)
   CLabel  m_hsHdr;
   CLabel  m_hs[MAX_HIST_ROWS];
   int     m_hsRows;
   //--- tab 2: exposure and hedging (v6.8)
   CLabel  m_hHdr, m_hExpo, m_hNote;
   CLabel  m_hRow[MAX_HEDGE_ROWS];
   //--- tab 3: my stats (the v6.6 journal, read back)
   CLabel  m_sHdr, m_sFind;
   CLabel  m_sL[TRADER_TAB_ROWS], m_sR[TRADER_TAB_ROWS];
   CButton m_btnReport;
   int     m_colW, m_repW;
   CLabel  m_tkHdr, m_lbLot, m_lbRisk, m_lbCap, m_lbSL, m_lbTP, m_est, m_pos;
   CEdit   m_edLot, m_edRisk, m_edSL, m_edTP;
   CButton m_btnAuto, m_btnSize, m_btnAtrTF, m_btnBuy, m_btnSell, m_btnClose;
   //--- v4.0 auto engine strip
   CLabel  m_auHdr, m_auState, m_auStats, m_auMsg;
   CButton m_btnAutoOn, m_btnTrail, m_btnCloseAuto;
   //--- v6.7: the watchlist
   CPanel  m_bandW;
   CLabel  m_wHdr;
   CLabel  m_wl[MAX_WATCH];
   int     m_wlRows;        // how many rows actually fit in the client area
   int     m_gaugeW;
   int     m_gaugeX;
   //--- v6.52: the widths every fitted label and button measures against
   int     m_lblW;     // full-width label
   int     m_btnW;     // one column
   int     m_btn2W;    // v6.95: half a row - the two ticket toggles

public:
   virtual bool Create(const long chart,const string name,const int subwin,
                       const int x1,const int y1,const int x2,const int y2);
   void Refresh();

protected:
   bool MkLabel(CLabel &l,string id,int x,int y,int w,string txt,color c,int fs=9,string fn="Consolas");
   bool MkEdit(CEdit &e,string id,int x,int y,int w,string txt);
   bool MkButton(CButton &b,string id,int x,int y,int w,int h,string txt,color bg,color fg,int fs=9);
   bool MkPanel(CPanel &p,string id,int x,int y,int w,int h,color bg,color bd=clrNONE);
   bool BuildControls();
   void ApplyDarkChrome();
   void Paint(string id,color c,int fs=-1);
   //--- v6.52: set text that is guaranteed to fit, by measuring it
   void FitLabel(CLabel &l,string id,string text,color c,int fsWant,int maxPx);
   void FitButton(CButton &b,string id,string text,int fsWant,int maxPx);
   //--- v6.95: tabs
   void TabReg(const int t,CWnd &w);
   bool TabLabel(const int t,CLabel &l,string id,int x,int y,int w,string txt,color c,int fs=8);
   bool TabPanel(const int t,CPanel &p,string id,int x,int y,int w,int h,color bg,color bd=clrNONE);
   void ApplyTabs();
   void SetTab(const int t);
   void RefreshBias(); void RefreshHist(); void RefreshHedge(); void RefreshStats();
   virtual void Maximize(void);

   void OnBuy();  void OnSell();  void OnCloseAll();
   void OnAuto(); void OnSize();  void OnAtrTF(); void OnReport();
   void OnTab0(); void OnTab1();  void OnTab2();  void OnTab3();
   void OnAutoOn(); void OnTrail(); void OnCloseAuto();
   void OnEditLot(); void OnEditRisk(); void OnEditSL(); void OnEditTP();

   EVENT_MAP_BEGIN(CScannerPanel)
      ON_EVENT(ON_CLICK,    m_tabBtn[0],    OnTab0)
      ON_EVENT(ON_CLICK,    m_tabBtn[1],    OnTab1)
      ON_EVENT(ON_CLICK,    m_tabBtn[2],    OnTab2)
      ON_EVENT(ON_CLICK,    m_tabBtn[3],    OnTab3)
      ON_EVENT(ON_CLICK,    m_btnReport,    OnReport)
      ON_EVENT(ON_CLICK,    m_btnBuy,       OnBuy)
      ON_EVENT(ON_CLICK,    m_btnSell,      OnSell)
      ON_EVENT(ON_CLICK,    m_btnClose,     OnCloseAll)
      ON_EVENT(ON_CLICK,    m_btnAuto,      OnAuto)
      ON_EVENT(ON_CLICK,    m_btnSize,      OnSize)
      ON_EVENT(ON_CLICK,    m_btnAtrTF,     OnAtrTF)
      ON_EVENT(ON_CLICK,    m_btnAutoOn,    OnAutoOn)
      ON_EVENT(ON_CLICK,    m_btnTrail,     OnTrail)
      ON_EVENT(ON_CLICK,    m_btnCloseAuto, OnCloseAuto)
      ON_EVENT(ON_END_EDIT, m_edLot,        OnEditLot)
      ON_EVENT(ON_END_EDIT, m_edRisk,       OnEditRisk)
      ON_EVENT(ON_END_EDIT, m_edSL,         OnEditSL)
      ON_EVENT(ON_END_EDIT, m_edTP,         OnEditTP)
   EVENT_MAP_END(CAppDialog)
};

CScannerPanel g_panel;

//--- control factories -------------------------------------------------
bool CScannerPanel::MkLabel(CLabel &l,string id,int x,int y,int w,string txt,color c,int fs,string fn)
{
   if(!l.Create(m_chart_id,m_name+id,m_subwin,x,y,x+w,y+16)) return false;
   if(!Add(l)) return false;
   l.Font(fn); l.FontSize(fs); l.Text(txt); l.Color(c);
   return true;
}
bool CScannerPanel::MkEdit(CEdit &e,string id,int x,int y,int w,string txt)
{
   if(!e.Create(m_chart_id,m_name+id,m_subwin,x,y,x+w,y+18)) return false;
   if(!Add(e)) return false;
   e.Text(txt); e.TextAlign(ALIGN_CENTER);
   e.ColorBackground(C_EDIT_BG); e.Color(C_TEXT); e.ColorBorder(C_BORDER);
   return true;
}
bool CScannerPanel::MkButton(CButton &b,string id,int x,int y,int w,int h,string txt,color bg,color fg,int fs)
{
   if(!b.Create(m_chart_id,m_name+id,m_subwin,x,y,x+w,y+h)) return false;
   if(!Add(b)) return false;
   b.Text(txt); b.FontSize(fs); b.Font("Arial Bold");
   b.ColorBackground(bg); b.Color(fg); b.ColorBorder(C_BORDER);
   return true;
}
bool CScannerPanel::MkPanel(CPanel &p,string id,int x,int y,int w,int h,color bg,color bd)
{
   if(!p.Create(m_chart_id,m_name+id,m_subwin,x,y,x+w,y+h)) return false;
   if(!Add(p)) return false;
   p.BorderType(BORDER_FLAT);
   p.ColorBackground(bg);
   p.ColorBorder(bd==clrNONE ? bg : bd);
   return true;
}

//--- force a label's colour straight onto the chart object.
//    CWndObj::Color() caches m_color and skips the ObjectSetInteger when
//    it believes nothing changed, which leaves some labels at the
//    library default. Writing OBJPROP_COLOR directly always wins.
void CScannerPanel::Paint(string id,color c,int fs)
{
   const string n = m_name + id;
   if(ObjectFind(m_chart_id,n) < 0) return;
   ObjectSetInteger(m_chart_id,n,OBJPROP_COLOR,c);
   if(fs > 0) ObjectSetInteger(m_chart_id,n,OBJPROP_FONTSIZE,fs);
}

//+------------------------------------------------------------------+
//| Dark chrome for the parts CDialog keeps private.                 |
//|                                                                  |
//| "<name>Client" is a CWndClient *container* and paints nothing —   |
//| the object that fills the client area is its child, created by    |
//| CWndClient::CreateBack() as "<name>ClientBack". Belt-and-braces   |
//| only: m_bg already guarantees a dark base.                        |
//+------------------------------------------------------------------+
void CScannerPanel::ApplyDarkChrome()
{
   const string parts[4]   = {"White",  "Back",   "ClientBack", "Caption"};
   const color  bgs[4]     = {C_PANEL,  C_PANEL,  C_PANEL,      C_CAPTION};
   const color  borders[4] = {C_BORDER, C_BORDER, C_PANEL,      C_CAPTION};
   const color  fgs[4]     = {C_BORDER, C_BORDER, C_PANEL,      C_TEXT};

   for(int i=0;i<4;i++)
   {
      const string n = m_name + parts[i];
      if(ObjectFind(m_chart_id,n) < 0) continue;
      ObjectSetInteger(m_chart_id,n,OBJPROP_BGCOLOR,       bgs[i]);
      ObjectSetInteger(m_chart_id,n,OBJPROP_BORDER_COLOR,  borders[i]);
      ObjectSetInteger(m_chart_id,n,OBJPROP_COLOR,         fgs[i]);
   }
}

//+------------------------------------------------------------------+
//| v6.52: fit text to a width by measuring it. Shrink the font a     |
//| step at a time down to 6pt, and only if it STILL does not fit,    |
//| trim and mark the cut with "..". A visible ".." is honest; a      |
//| silently amputated line is not.                                    |
//+------------------------------------------------------------------+
void CScannerPanel::FitLabel(CLabel &l,string id,string text,color c,int fsWant,int maxPx)
{
   int fs=fsWant;
   string t=text;
   while(fs>6 && TextPxWidth(t,fs)>maxPx) fs--;
   if(TextPxWidth(t,fs)>maxPx)
   {
      while(StringLen(t)>3 && TextPxWidth(t+"..",fs)>maxPx)
         t=StringSubstr(t,0,StringLen(t)-1);
      t+="..";
   }
   l.Text(t);
   Paint(id,c,fs);
}

void CScannerPanel::FitButton(CButton &b,string id,string text,int fsWant,int maxPx)
{
   int fs=fsWant;
   //--- buttons are Arial Bold and centred, so they need a little breathing
   //--- room inside the border rather than the full width
   const int room=maxPx-8;
   while(fs>6 && TextPxWidth(text,fs,"Arial Bold")>room) fs--;
   b.Text(text);
   const string n=m_name+id;
   if(ObjectFind(m_chart_id,n)>=0) ObjectSetInteger(m_chart_id,n,OBJPROP_FONTSIZE,fs);
}

//--- layout ------------------------------------------------------------
bool CScannerPanel::Create(const long chart,const string name,const int subwin,
                           const int x1,const int y1,const int x2,const int y2)
{
   if(!CAppDialog::Create(chart,name,subwin,x1,y1,x2,y2)) return false;
   ApplyDarkChrome();
   if(!BuildControls()) return false;
   ApplyDarkChrome();
   ApplyTabs();         // v6.95: every tab was built visible - show only the selected one
   return true;
}

bool CScannerPanel::BuildControls()
{
   //--- v6.51: every horizontal number is DERIVED from the panel's own
   //--- width now. The old layout hard-coded 506 px of label inside a
   //--- 530 px panel and assumed about 6.5 px per character. That holds at
   //--- 100% display scaling and is wrong at 125% or 150%, where a
   //--- character is nearer 8 px — so on a scaled display every long line
   //--- silently lost its tail ("...HIGH (exp", "...| butt"). CLabel clips
   //--- rather than wraps, so there was no visible clue beyond the missing
   //--- words. Widen or narrow Panel_W now and the columns follow it.
   const int CW  = ClientAreaWidth();
   const int L   = 10;                       // col 1 left
   const int W   = CW - 2*L;                 // full-width labels (CLabel CLIPS to width)
   const int BX  = 8;
   const int BW  = CW - 2*BX;
   const int GAP = 12;
   const int COLW= (W - 2*GAP)/3;            // three equal columns
   const int C2  = L  + COLW + GAP;          // col 2 left
   const int C3  = C2 + COLW + GAP;          // col 3 left
   const int LBW = 58;
   const int EDX1= L  + 60, EDX2 = C2 + 60;
   const int EDW = COLW - 60;
   const int BTW = COLW;
   const int BTW3= COLW;
   m_lblW = W;                               // v6.52: what the fitters measure against
   m_btnW = COLW;

   //--- OUR OWN BACKDROP, CREATED FIRST. MT5 paints chart objects in
   //--- creation order, so everything after this sits on a dark base.
   if(!MkPanel(m_bg,"bg", 0, 0, ClientAreaWidth(), ClientAreaHeight(), C_PANEL)) return false;

   if(!MkLabel(m_sub,"sub", L, 3, W, "loading...", C_TEXT, 8)) return false;
   if(!MkPanel(m_sep1,"sp1", L, 21, W, 1, C_SEP)) return false;

   //--- section 1: multi-timeframe signals
   if(!MkPanel(m_band1,"bd1", BX, 26, BW, 17, C_CARD)) return false;
   if(!MkLabel(m_mtfHdr,"mh", L+4, 27, W, "MULTI-TIMEFRAME SIGNALS", C_HEAD)) return false;

   //--- header built with the SAME field widths as the data rows
   const string colHdr = StringFormat("%s%-4s %-12s %4s%s  %3s%-2s  %s",
                                      " ", "TF", "Signal", "Buy", "%", "ADX", "", "Indicators");
   if(!MkLabel(m_col,"col", L, 45, W, colHdr, C_DIM, 8)) return false;

   for(int i=0;i<TF_COUNT;i++)
      if(!MkLabel(m_tf[i],"tf"+IntegerToString(i), L, 59+i*14, W, g_tfName[i]+" ...", C_DIM)) return false;

   //--- v6.0: everything below the MTF block is placed RELATIVE to where
   //--- that block ends, so adding a timeframe moves the panel down instead
   //--- of drawing the next section on top of the last row. DY is zero on
   //--- the six-row v5.x layout, so every coordinate below still reads as
   //--- the number it always was.
   const int DY = (TF_COUNT-6)*14;

   if(!MkPanel(m_sep2,"sp2", L, 149+DY, W, 1, C_SEP)) return false;

   //--- section 2: filters. v6.95: straight under the table, because they
   //--- gate those signals, and outside the tabs so no tab can hide a block
   if(!MkLabel(m_fltHdr,"fh", L,    154+DY, 70,   "FILTERS:", C_HEAD, 8)) return false;
   if(!MkLabel(m_flt,   "fl", L+62, 154+DY, W-62, "-",        C_TEXT, 8)) return false;

   //--- section 3: v6.95 THE TABS
   m_twN=0;
   const int TY = TabStripY();
   const int CT = TY + TAB_BTN_H;              // content top
   const int IL = L + 4;                       // text inside the frame
   const int IW = W - 8;
   m_inW = IW;

   //--- one size for all four labels: the largest at which every one fits
   //--- in full on THIS display. Widths then follow the words, so the long
   //--- name gets the room and no label is clipped or set smaller than its
   //--- neighbours.
   const string tabName[TAB_COUNT] = {"MARKET BIAS","SIGNAL HISTORY","EXPOSURE / HEDGE","MY STATS"};
   int tw[TAB_COUNT];
   int tfs=9, need=0;
   while(true)
   {
      need=(TAB_COUNT-1)*TAB_GAP;
      for(int t=0;t<TAB_COUNT;t++){ tw[t]=TextPxWidth(tabName[t],tfs,"Arial Bold")+16; need+=tw[t]; }
      if(need<=BW || tfs<=6) break;
      tfs--;
   }
   if(need>BW)
   {
      //--- a very narrow Panel_W: equal shares, and the labels clip
      for(int t=0;t<TAB_COUNT;t++) tw[t]=(BW-(TAB_COUNT-1)*TAB_GAP)/TAB_COUNT;
   }
   else
   {
      //--- share the slack out, so the strip spans the frame exactly
      const int slack=BW-need;
      for(int t=0;t<TAB_COUNT;t++) tw[t]+=slack/TAB_COUNT+(t<slack%TAB_COUNT ? 1 : 0);
   }
   int tx=BX;
   for(int t=0;t<TAB_COUNT;t++)
   {
      if(!MkButton(m_tabBtn[t],"tab"+IntegerToString(t), tx, TY, tw[t], TAB_BTN_H, tabName[t], C_TABOFF, C_DIM, tfs)) return false;
      tx+=tw[t]+TAB_GAP;
   }
   //--- the frame: panel-dark inside, so everything in it looks as it did
   //--- when it was a section of its own, and outlined in the colour of the
   //--- selected tab, so the frame reads as belonging to it
   if(!MkPanel(m_tabCard,"tcard", BX, CT, BW, TAB_CONTENT_H, C_PANEL, C_TABON)) return false;

   //--- tab 0: OVERALL MARKET BIAS. The verdict card lives here because it
   //--- is the conclusion the gauge is the evidence for.
   if(!TabLabel(TAB_BIAS,m_ovHdr,"oh", IL, CT+4, IW, "OVERALL MARKET BIAS", C_HEAD)) return false;
   m_gaugeW = IW - 120;                      // v6.51: leaves room for the "71 / 29" readout
   m_gaugeX = IL;
   if(!TabPanel(TAB_BIAS,m_gTrack,"gt", m_gaugeX-1,          CT+22, m_gaugeW+2, 13, C_TRACK, C_BORDER)) return false;
   if(!TabPanel(TAB_BIAS,m_gBuy,  "gb", m_gaugeX,            CT+23, m_gaugeW/2, 11, C_BULL)) return false;
   if(!TabPanel(TAB_BIAS,m_gSell, "gs", m_gaugeX+m_gaugeW/2, CT+23, m_gaugeW/2, 11, C_BEAR)) return false;
   if(!TabPanel(TAB_BIAS,m_gMid,  "gm", m_gaugeX+m_gaugeW/2, CT+20, 1, 17, C_TEXT)) return false;
   if(!TabLabel(TAB_BIAS,m_gPct,  "gp", m_gaugeX+m_gaugeW+12, CT+21, 106, "50 / 50", C_TEXT)) return false;
   if(!TabLabel(TAB_BIAS,m_bias,  "bi", IL, CT+38, IW, "-", C_TEXT, 9)) return false;
   //--- v6.5: THE VERDICT CARD, the line a person acts on
   m_vW = W - 12;
   if(!TabPanel(TAB_BIAS,m_bandV,"bdv", L+2, CT+58, W-4, 72, C_CARD, C_BORDER)) return false;
   if(!TabLabel(TAB_BIAS,m_vHead,"vh",  L+6, CT+61,  m_vW, "-", C_TEXT, 10)) return false;
   if(!TabLabel(TAB_BIAS,m_vLev, "vl",  L+6, CT+80,  m_vW, "-", C_DIM,   8)) return false;
   if(!TabLabel(TAB_BIAS,m_vPros,"vp",  L+6, CT+96,  m_vW, "-", C_BULL,  8)) return false;
   if(!TabLabel(TAB_BIAS,m_vCons,"vc",  L+6, CT+112, m_vW, "-", C_BEAR,  8)) return false;

   //--- tab 1: SIGNAL HISTORY (v6.93). At least one row, so a strip that
   //--- is switched off can say so instead of showing an empty frame.
   if(!TabLabel(TAB_HIST,m_hsHdr,"hsh", IL, CT+4, IW, "SIGNAL HISTORY", C_HEAD)) return false;
   m_hsRows=MathMax(1,MathMin(TAB_ROWS,MathMin(MAX_HIST_ROWS,Hist_PanelRows())));
   for(int i=0;i<m_hsRows;i++)
      if(!TabLabel(TAB_HIST,m_hs[i],"hs"+IntegerToString(i), IL, CT+20+i*14, IW, "", C_DIM)) return false;

   //--- tab 2: EXPOSURE AND HEDGE (v6.8)
   if(!TabLabel(TAB_HEDGE,m_hHdr, "hh", IL, CT+4,  IW, "EXPOSURE AND HEDGE", C_HEAD)) return false;
   if(!TabLabel(TAB_HEDGE,m_hExpo,"hx", IL, CT+20, IW, "-", C_TEXT)) return false;
   for(int i=0;i<MAX_HEDGE_ROWS;i++)
      if(!TabLabel(TAB_HEDGE,m_hRow[i],"hr"+IntegerToString(i), IL, CT+34+i*14, IW, "", C_DIM)) return false;
   if(!TabLabel(TAB_HEDGE,m_hNote,"hn", IL, CT+20+(TAB_ROWS-1)*14, IW, "", C_DIM)) return false;

   //--- tab 3: MY STATS. The journal's headlines as a two-column grid, the
   //--- first finding under it, and a button for the full report.
   m_repW = MathMin(IW/3, TextPxWidth("FULL REPORT",8,"Arial Bold")+18);
   if(!TabLabel(TAB_STATS,m_sHdr,"sth", IL, CT+4, IW-m_repW-8, "MY STATS", C_HEAD)) return false;
   if(!MkButton(m_btnReport,"brep", IL+IW-m_repW, CT+2, m_repW, 18, "FULL REPORT", C'70,52,96', C_TEXT, 8)) return false;
   TabReg(TAB_STATS,m_btnReport);
   m_colW = (IW-12)/2;
   for(int k=0;k<TRADER_TAB_ROWS;k++)
   {
      if(!TabLabel(TAB_STATS,m_sL[k],"sl"+IntegerToString(k), IL,           CT+20+k*14, m_colW, "", C_DIM)) return false;
      if(!TabLabel(TAB_STATS,m_sR[k],"sr"+IntegerToString(k), IL+m_colW+12, CT+20+k*14, m_colW, "", C_DIM)) return false;
   }
   if(!TabLabel(TAB_STATS,m_sFind,"sf", IL, CT+20+TRADER_TAB_ROWS*14, IW, "", C_DIM)) return false;

   //--- from here down one offset carries the ticket to just under the
   //--- frame, so every coordinate below still reads as its original number
   const int DY2 = PanelTicketDY();

   //--- section 4: trade ticket
   if(!MkPanel(m_band3,"bd3", BX, 240+DY2, BW, 17, C_CARD)) return false;
   if(!MkLabel(m_tkHdr,"th", L+4, 241+DY2, W, "TRADE TICKET", C_HEAD)) return false;

   //--- row 1: lot | risk | cap note
   if(!MkLabel(m_lbLot, "llot", L,    264+DY2, LBW, "Lot:",   C_TEXT, 8)) return false;
   if(!MkEdit (m_edLot, "elot", EDX1, 262+DY2, EDW, DoubleToString(g_ui_lot,2))) return false;
   if(!MkLabel(m_lbRisk,"lrsk", C2,   264+DY2, LBW, "Risk%:", C_TEXT, 8)) return false;
   if(!MkEdit (m_edRisk,"ersk", EDX2, 262+DY2, EDW, DoubleToString(g_ui_risk,1))) return false;
   if(!MkLabel(m_lbCap, "lcap", C3,   264+DY2, BTW3, StringFormat("(max %.1f%%)",InpMaxRiskPct), C_DIM, 8)) return false;

   //--- row 2: SL | TP | H7 ATR-source selector
   if(!MkLabel(m_lbSL,"lsl", L,    288+DY2, LBW, "SL pts:", C_TEXT, 8)) return false;
   if(!MkEdit (m_edSL,"esl", EDX1, 286+DY2, EDW, DoubleToString(g_ui_slPts,0))) return false;
   if(!MkLabel(m_lbTP,"ltp", C2,   288+DY2, LBW, "TP pts:", C_TEXT, 8)) return false;
   if(!MkEdit (m_edTP,"etp", EDX2, 286+DY2, EDW, DoubleToString(g_ui_tpPts,0))) return false;
   if(!MkButton(m_btnAtrTF,"batf", C3, 286+DY2, BTW3, 18, "ATR: CHART", C'52,58,76', C_TEXT, 8)) return false;

   //--- toggles. v6.95: MY STATS became a tab, so the two toggles split the
   //--- row and get the room their "-> what a click does" text needs
   m_btn2W = (W-GAP)/2;
   if(!MkButton(m_btnAuto,"bauto", L,             310+DY2, m_btn2W, 20, "SL/TP: AUTO", C'40,86,58', C_TEXT, 8)) return false;
   if(!MkButton(m_btnSize,"bsize", L+m_btn2W+GAP, 310+DY2, m_btn2W, 20, "SIZE: RISK%", C'44,62,96', C_TEXT, 8)) return false;

   if(!MkLabel(m_est,"est", L, 334+DY2, W, "-", C_TEXT, 8)) return false;

   //--- action buttons
   if(!MkButton(m_btnBuy,  "bbuy",  L,  354+DY2, BTW,  30, "BUY",       C'0,168,80',   clrWhite, 12)) return false;
   if(!MkButton(m_btnSell, "bsell", C2, 354+DY2, BTW,  30, "SELL",      C'214,52,52',  clrWhite, 12)) return false;
   if(!MkButton(m_btnClose,"bcls",  C3, 354+DY2, BTW3, 30, "CLOSE ALL", C'82,90,112',  C_TEXT,   10)) return false;

   if(!MkLabel(m_pos,"pos", L, 388+DY2, W, "ready", C_TEXT, 8)) return false;

   //--- section 5: v4.0 auto trend engine
   if(!MkPanel(m_sep5,"sp5", L, 408+DY2, W, 1, C_SEP)) return false;
   if(!MkPanel(m_band4,"bd4", BX, 413+DY2, BW, 17, C_CARD)) return false;
   if(!MkLabel(m_auHdr,"ah", L+4, 414+DY2, W, "AUTO TREND ENGINE", C_HEAD)) return false;
   if(!MkLabel(m_auState,"as", L, 434+DY2, W, "-", C_TEXT, 8)) return false;
   if(!MkLabel(m_auStats,"st", L, 448+DY2, W, "-", C_TEXT, 8)) return false;
   if(!MkLabel(m_auMsg,  "am", L, 462+DY2, W, "-", C_DIM,  8)) return false;

   if(!MkButton(m_btnAutoOn,   "bon",  L,  480+DY2, BTW,  22, "AUTO: OFF",  C'82,90,112', C_TEXT, 9)) return false;
   if(!MkButton(m_btnTrail,    "btrl", C2, 480+DY2, BTW,  22, "TRAIL: ATR", C'52,58,76',  C_TEXT, 9)) return false;
   if(!MkButton(m_btnCloseAuto,"bca",  C3, 480+DY2, BTW3, 22, "CLOSE AUTO", C'96,76,34',  C_TEXT, 9)) return false;
   //--- bottom 502+DY2 (592) < client 596 (Panel_H 620 - 24)

   //--- v6.7: the watchlist, last because it is the section whose height
   //--- depends on how many symbols you asked for. Rows are created only
   //--- as far as the client area actually reaches, so a Panel_H that is
   //--- too short trims the list instead of drawing off the bottom edge.
   //--- v6.95: the hedge block that followed it is a tab now, so this is
   //--- the only section left whose height varies.
   int y = 506+DY2;

   m_wlRows=0;
   if(Watch_Count()>0)
   {
      const int rowTop=y+20;
      const int fits=MathMax(0,MathMin(Watch_Count(),
                     MathMin(MAX_WATCH,(ClientAreaHeight()-rowTop-2)/14)));
      if(fits>0)
      {
         if(!MkPanel(m_bandW,"bdw", BX, y, BW, 17, C_CARD)) return false;
         if(!MkLabel(m_wHdr,"wh", L+4, y+1, W, "WATCHLIST", C_HEAD)) return false;
         m_wlRows=fits;
         for(int i=0;i<m_wlRows;i++)
            if(!MkLabel(m_wl[i],"wl"+IntegerToString(i), L, rowTop+i*14, W, "", C_DIM, 8)) return false;
         y = rowTop + m_wlRows*14;
      }
      else Print("WATCHLIST: no room to draw - raise Panel_H");
   }

   return true;
}

//--- live update -------------------------------------------------------
void CScannerPanel::Refresh()
{
   ApplyDarkChrome();

   Paint("sub", C_TEXT, 8);
   Paint("mh",  C_HEAD, 9);
   Paint("col", C_DIM,  8);
   Paint("fh",  C_HEAD, 8);
   Paint("th",  C_HEAD, 9);
   Paint("ah",  C_HEAD, 9);
   Paint("llot",C_TEXT, 8);
   Paint("lrsk",C_TEXT, 8);
   Paint("lsl", C_TEXT, 8);
   Paint("ltp", C_TEXT, 8);
   Paint("lcap",C_DIM,  8);
   Paint("gp",  C_TEXT, 8);

   FitLabel(m_sub,"sub",StringFormat("%s   |   Chart TF: %s   |   Spread: %d pts   |   %s",
            _Symbol, TfName((ENUM_TIMEFRAMES)_Period), (int)SymbolInfoInteger(_Symbol,SYMBOL_SPREAD),
            Api_StatusLine()),
            C_TEXT, 8, m_lblW);

   //--- v6.52: build every row first, size them TOGETHER, then draw. Fitting
   //--- each row on its own would leave the table with mixed font sizes and
   //--- ragged columns, which is worse than a slightly smaller table.
   string rowTxt[TF_COUNT];
   for(int i=0;i<TF_COUNT;i++)
   {
      if(!g_R[i].ready)
      {
         //--- H4: this now means "history genuinely missing", not
         //--- "one indicator quietly failed and we scored it anyway".
         rowTxt[i]=StringFormat(" %-4s %s", g_tfName[i], "loading history...");
         continue;
      }
      //--- ">" marks the chart TF, "*" the timeframe the auto engine trades
      string mark = " ";
      if(i==SigIdx())                            mark = "*";
      if(g_tf[i]==(ENUM_TIMEFRAMES)_Period)      mark = (i==SigIdx() ? "@" : ">");
      //--- Indicators LAST: the arrow glyphs fall back to a proportional
      //--- font, so any column after them would go ragged.
      rowTxt[i]=StringFormat("%s%-4s %-12s %4.0f%%  %3.0f%-2s  %s",
                mark, g_tfName[i], g_R[i].label, g_R[i].buyPct,
                g_R[i].adx, g_R[i].ranging?"r":"", g_R[i].breakdown);
   }
   int rowFS=9;
   while(rowFS>6)
   {
      int wmax=0;
      for(int i=0;i<TF_COUNT;i++)
      { const int w=TextPxWidth(rowTxt[i],rowFS); if(w>wmax) wmax=w; }
      if(wmax<=m_lblW) break;
      rowFS--;
   }
   for(int i=0;i<TF_COUNT;i++)
   {
      m_tf[i].Text(rowTxt[i]);
      Paint("tf"+IntegerToString(i), g_R[i].ready ? DirColor(g_R[i].dir) : C_DIM, rowFS);
   }

   //--- v6.95: only the tab on show is drawn. SetTab draws a tab before it
   //--- shows it, so switching never flashes text from an earlier second.
   switch(g_uiTab)
   {
      case TAB_HIST:  RefreshHist();  break;
      case TAB_HEDGE: RefreshHedge(); break;
      case TAB_STATS: RefreshStats(); break;
      default:        RefreshBias();  break;
   }

   //--- v6.95: the verdict card sits in the first tab, so the call itself
   //--- rides on the ticket header too - the line you read before you
   //--- click, whichever tab is up
   FitLabel(m_tkHdr,"th",
            g_V.dir>0 ? StringFormat("TRADE TICKET   panel says ▲ BUY   grade %s   %d/%d",g_V.grade,g_V.pass,g_V.total)
          : g_V.dir<0 ? StringFormat("TRADE TICKET   panel says ▼ SELL   grade %s   %d/%d",g_V.grade,g_V.pass,g_V.total)
          :             "TRADE TICKET   panel says WAIT",
            C_HEAD, 9, m_lblW);

   FitLabel(m_flt,"fl",StringFormat("Session: %s   |   News: %s   |   Vol: %s", g_sessionMsg, g_newsMsg, g_volMsg),
            (g_sessionBlock||g_newsBlock)?C_WARN:C_TEXT, 8, m_lblW-62);

   //--- read the boxes live so the ticket is WYSIWYG even without Enter
   if(!g_ui_riskMode) g_ui_lot   = StringToDouble(m_edLot.Text());
   if(!g_ui_auto)   { g_ui_slPts = StringToDouble(m_edSL.Text());
                      g_ui_tpPts = StringToDouble(m_edTP.Text()); }
   else             { m_edSL.Text(DoubleToString(g_ui_slPts,0));
                      m_edTP.Text(DoubleToString(g_ui_tpPts,0)); }

   const double slp    = EffSLpts();
   const double effLot = g_ui_riskMode ? RiskToLot(slp) : NormalizeLot(g_ui_lot);
   if(g_ui_riskMode) m_edLot.Text(DoubleToString(effLot,2));

   //--- v6.51: every toggle now reads "<CURRENT> -> <what a click does>".
   //--- "SL/TP: AUTO" alone was ambiguous — it could be read as the state
   //--- the button is in or as the state it would put you in, and those are
   //--- opposites. Upper case is what IS, lower case is what a click makes.
   FitButton(m_btnAuto,"bauto", g_ui_auto ? "SL/TP: AUTO -> manual" : "SL/TP: MANUAL -> auto", 8, m_btn2W);
   m_btnAuto.ColorBackground(g_ui_auto?C'40,86,58':C'96,76,34');
   FitButton(m_btnSize,"bsize", g_ui_riskMode ? "SIZE: RISK% -> lot" : "SIZE: LOT -> risk%", 8, m_btn2W);
   //--- the ATR source cycles CHART -> M1 -> ... -> D1 -> CHART
   int nextAtr = g_ui_atrTF + 1; if(nextAtr >= TF_COUNT) nextAtr = -1;
   FitButton(m_btnAtrTF,"batf", StringFormat("ATR: %s -> %s",
             (g_ui_atrTF<0 ? "CHART" : g_tfName[g_ui_atrTF]),
             (nextAtr  <0 ? "chart" : g_tfName[nextAtr])), 8, m_btnW);

   const double riskMoney = effLot*LossPerLot(slp);
   //--- H7: always name the timeframe the stop actually came from.
   FitLabel(m_est,"est",StringFormat("Est. lot %.2f | risk %.2f %s | SL %.1fxATR(%s) | %s",
            effLot, riskMoney, AccountInfoString(ACCOUNT_CURRENCY),
            InpSL_ATR_Mult, g_atrSrc,
            InpAllowTrading?"buttons LIVE":"buttons OFF"),
            InpAllowTrading?C_TEXT:C_WARN, 8, m_lblW);

   int b,s; PosCounts(b,s);
   const double pl=FloatingPL();
   FitLabel(m_pos,"pos",StringFormat("Open: %d BUY / %d SELL   |   P/L %.2f %s   |   %s",
            b,s,pl,AccountInfoString(ACCOUNT_CURRENCY),g_lastAction),
            pl>0?C_BULL:pl<0?C_BEAR:C_TEXT, 8, m_lblW);

   //--- v4.0 auto engine strip
   int ab,asl; AutoPosCounts(ab,asl);
   FitLabel(m_auState,"as",StringFormat("Signal %s @ %.0f/%.0f | SL %.0f pts %.1fxATR | TP %s | trail %s/%s",
            g_tfName[SigIdx()], InpAutoBuyPct, InpAutoSellPct,
            AutoSLPts(), AutoSLMult(),
            InpAutoTP_RR>0 ? StringFormat("%.1fR",InpAutoTP_RR) : "trail",
            TrailModeName(g_trailMode), g_tfName[TrailIdx()]),
            C_TEXT, 8, m_lblW);

   //--- A9: realised results, not just floating ones
   //--- v6.0: the cap and the combined open risk are now the two numbers
   //--- that decide whether the next signal can be taken, so they belong
   //--- on the panel next to the count rather than only inside `why`.
   //--- C1: a halted engine is the most important thing on this panel, so
   //--- it takes the colour regardless of how the day's P&L is doing.
   FitLabel(m_auStats,"st",StringFormat("Auto %dB/%dS/%d | risk %.2f/%.2f%% | DD %.2f/%.0f%%%s | today %d %dW/%dL %+.2f | eq %+.2f%%",
            ab, asl, InpMaxPositions,
            OpenAutoRiskPct(), InpMaxTotalRiskPct,
            CurrentDDPct(), InpMaxDrawdownPct, (g_ddHalt ? " HALTED" : ""),
            g_tradesToday, g_autoWins, g_autoLosses, g_autoRealized,
            DayPnLPct()),
            g_ddHalt ? C_BEAR : (g_autoRealized>0?C_BULL:g_autoRealized<0?C_BEAR:C_TEXT), 8, m_lblW);

   FitLabel(m_auMsg,"am", g_autoMsg, g_autoSetup ? C_BULL : (g_auto_on ? C_WARN : C_DIM), 8, m_lblW);

   FitButton(m_btnAutoOn,"bon",
             g_dupInstance ? "DUPLICATE - scan only"
           : g_netting     ? "NETTING - no auto"
           : g_ddHalt      ? "HALTED -> re-arm"
           : (g_auto_on ? "AUTO: ON -> disarm" : "AUTO: OFF -> arm"), 9, m_btnW);
   m_btnAutoOn.ColorBackground((g_dupInstance||g_netting) ? C'120,70,30' : g_ddHalt ? C'150,40,40' : (g_auto_on ? C'0,140,70' : C'82,90,112'));
   //--- the trail cycles OFF -> POINTS -> ATR -> CHANDLR -> OFF
   int nextTrail = (int)g_trailMode + 1; if(nextTrail > (int)TRAIL_CHANDELIER) nextTrail = (int)TRAIL_OFF;
   FitButton(m_btnTrail,"btrl",StringFormat("TRAIL: %s -> %s",
             TrailModeName(g_trailMode), TrailModeName((ENUM_TRAIL_MODE)nextTrail)), 9, m_btnW);
   m_btnTrail.ColorBackground(g_trailMode==TRAIL_OFF ? C'82,90,112' : C'52,58,76');

   //--- v6.7: the watchlist, strongest reading first
   if(m_wlRows>0)
   {
      Paint("wh", C_HEAD, 9);
      const int total=Watch_Count();
      m_wHdr.Text(m_wlRows<total
                  ? StringFormat("WATCHLIST  (showing %d of %d - raise Panel_H for the rest)",m_wlRows,total)
                  : StringFormat("WATCHLIST  (%d pairs, scan only)",total));
      int ord[]; Watch_Order(ord);
      for(int i=0;i<m_wlRows;i++)
      {
         const int s=ord[i];
         FitLabel(m_wl[i],"wl"+IntegerToString(i), Watch_Row(s), Watch_RowColor(s), 8, m_lblW);
      }
   }

   //--- v6.95: last, so it also undoes anything the dialog library re-showed
   ApplyTabs();
}

//--- event handlers ----------------------------------------------------
void CScannerPanel::OnBuy()      { PlaceManual(true);  Refresh(); }
void CScannerPanel::OnSell()     { PlaceManual(false); Refresh(); }
void CScannerPanel::OnCloseAll() { CloseAll("Manual close-all"); Refresh(); }
void CScannerPanel::OnAuto()     { g_ui_auto=!g_ui_auto; UpdateAutoStops(); Refresh(); }
void CScannerPanel::OnSize()     { g_ui_riskMode=!g_ui_riskMode; Refresh(); }

//--- H7: cycle CHART -> M5 -> M15 -> ... -> D1 -> CHART
void CScannerPanel::OnAtrTF()
{
   g_ui_atrTF++;
   if(g_ui_atrTF>=TF_COUNT) g_ui_atrTF=-1;
   UpdateAutoStops();
   Refresh();
}

//--- v4.0: arming the engine mid-session must not let it act on the bar
//--- that is already half-formed, so the current signal bar is consumed.
void CScannerPanel::OnAutoOn()
{
   //--- v6.1/D2: while the drawdown HALT is latched this button is the
   //--- re-arm switch, not the on/off switch. Clearing the latch is a
   //--- deliberate human act, and it resets both peaks to the account as
   //--- it stands — the budget starts over from here.
   //--- v6.2: a duplicate or a netting account cannot arm at all
   if(g_dupInstance){ g_lastAction="cannot arm — duplicate instance (remove one chart or change InpAutoMagic)"; Refresh(); return; }
   if(g_netting)    { g_lastAction="cannot arm — netting account (the engine needs hedging)"; Refresh(); return; }
   if(g_ddHalt){ State_ReArm("panel"); g_lastAction="HALT cleared by hand — peaks reset"; Refresh(); return; }
   g_auto_on = !g_auto_on;
   g_lastSigBar = iTime(_Symbol,SigTF(),0);
   g_lastAction = g_auto_on ? "auto engine ARMED" : "auto engine disarmed";
   Print(g_lastAction," (open positions are still managed)");
   Refresh();
}
void CScannerPanel::OnTrail()
{
   int m = (int)g_trailMode + 1;
   if(m > (int)TRAIL_CHANDELIER) m = (int)TRAIL_OFF;
   g_trailMode = (ENUM_TRAIL_MODE)m;
   g_lastAction = "trail mode -> "+TrailModeName(g_trailMode);
   Refresh();
}
void CScannerPanel::OnCloseAuto(){ CloseAuto("Panel CLOSE AUTO"); Refresh(); }

//--- v6.95: MY STATS is a tab now; the button left inside it writes the
//--- full report (every split, by hour and by weekday) to a file.
void CScannerPanel::OnReport()
{
   //--- CWnd::OnMouseEvent hit-tests by position and never asks whether a
   //--- control is visible, so this button still "clicks" while its tab is
   //--- hidden - on whatever caption covers the same spot. Refuse then.
   if(g_uiTab!=TAB_STATS) return;
   Trader_Report();
   Refresh();
}

void CScannerPanel::OnTab0(){ SetTab(TAB_BIAS);  }
void CScannerPanel::OnTab1(){ SetTab(TAB_HIST);  }
void CScannerPanel::OnTab2(){ SetTab(TAB_HEDGE); }
void CScannerPanel::OnTab3(){ SetTab(TAB_STATS); }

//+------------------------------------------------------------------+
//| v6.95: tabs                                                       |
//+------------------------------------------------------------------+
void CScannerPanel::TabReg(const int t,CWnd &w)
{
   if(m_twN>=TAB_MAX_CTL){ Print("PANEL: TAB_MAX_CTL is too small - a tab control will not hide"); return; }
   m_tw[m_twN]=GetPointer(w);
   m_twTab[m_twN]=t;
   m_twN++;
}

bool CScannerPanel::TabLabel(const int t,CLabel &l,string id,int x,int y,int w,string txt,color c,int fs)
{
   if(!MkLabel(l,id,x,y,w,txt,c,fs)) return false;
   TabReg(t,l);
   return true;
}

bool CScannerPanel::TabPanel(const int t,CPanel &p,string id,int x,int y,int w,int h,color bg,color bd)
{
   if(!MkPanel(p,id,x,y,w,h,bg,bd)) return false;
   TabReg(t,p);
   return true;
}

//--- the selected tab in the accent colour with white text, the others
//--- dark with dim text; then show that tab's controls and hide the rest.
//--- Cheap enough to run every second, which is what makes it self-healing.
void CScannerPanel::ApplyTabs()
{
   for(int t=0;t<TAB_COUNT;t++)
   {
      const bool on=(t==g_uiTab);
      m_tabBtn[t].ColorBackground(on ? C_TABON : C_TABOFF);
      m_tabBtn[t].ColorBorder(on ? C_TABON : C_SEP);
      Paint("tab"+IntegerToString(t), on ? clrWhite : C_DIM);
   }
   //--- a minimised dialog shows nothing at all; Maximize re-applies this
   if(m_minimized) return;
   for(int k=0;k<m_twN;k++)
   {
      CWnd *w=m_tw[k];
      if(CheckPointer(w)==POINTER_INVALID) continue;
      const bool want=(m_twTab[k]==g_uiTab);
      if(want && !w.IsVisible())      w.Show();
      else if(!want && w.IsVisible()) w.Hide();
   }
}

void CScannerPanel::SetTab(const int t)
{
   if(t<0 || t>=TAB_COUNT) return;
   g_uiTab=t;
   if(t==TAB_STATS) g_tsDirty=true;     // opening the tab shows the file as it is now
   Refresh();                           // draws the tab, THEN ApplyTabs shows it
   ChartRedraw();
}

//--- CAppDialog::Maximize shows every child of the client area - the
//--- library's containers have no notion of tabs - so restoring a
//--- minimised panel would stack all four tabs on top of each other.
void CScannerPanel::Maximize(void)
{
   CAppDialog::Maximize();
   ApplyTabs();
}

//--- tab 0: the gauge, the reading, the verdict card
void CScannerPanel::RefreshBias()
{
   FitLabel(m_ovHdr,"oh","OVERALL MARKET BIAS  (higher timeframes weighted)",C_HEAD,8,m_inW);

   int buyW = (int)MathRound(m_gaugeW * g_overallBuyPct/100.0);
   buyW = MathMax(1, MathMin(m_gaugeW-1, buyW));
   m_gBuy.Size(buyW, 11);
   m_gSell.Move(m_gBuy.Left()+buyW, m_gSell.Top());
   m_gSell.Size(m_gaugeW-buyW, 11);
   m_gPct.Text(StringFormat("%.0f / %.0f", g_overallBuyPct, 100-g_overallBuyPct));

   string curNote; const int ci=CurrentTFIndex();
   if(ci>=0 && g_R[ci].ready)
   {
      const bool agree=(g_R[ci].dir>0&&g_overallDir>0)||(g_R[ci].dir<0&&g_overallDir<0)||(g_R[ci].dir==0&&g_overallDir==0);
      curNote=StringFormat("| %s %s", g_tfName[ci], agree?"AGREES":"DIVERGES");
   }
   else curNote="| chart TF not scanned";

   FitLabel(m_bias,"bi",StringFormat("%s %s  BUY %.0f%% / SELL %.0f%%  align %d▲ %d● %d▼ %s",
            g_overallDir>0?"▲":g_overallDir<0?"▼":"●", g_overallLabel,
            g_overallBuyPct, 100-g_overallBuyPct, g_up, g_nt, g_dn, curNote),
            DirColor(g_overallDir), 9, m_inW);

   //--- v6.5: the verdict card. The headline takes the direction's colour
   //--- when there is a trade and the warning colour when there is not, so
   //--- "no" is as visible as "yes".
   FitLabel(m_vHead,"vh", g_V.head, (g_V.dir>0 ? C_BULL : g_V.dir<0 ? C_BEAR : C_WARN), 10, m_vW);
   FitLabel(m_vLev, "vl", g_V.levels, C_TEXT, 8, m_vW);
   FitLabel(m_vPros,"vp", StringLen(g_V.pros)>0 ? "FOR      "+g_V.pros : "", C_BULL, 8, m_vW);
   FitLabel(m_vCons,"vc", StringLen(g_V.cons)>0 ? "AGAINST  "+g_V.cons : "AGAINST  nothing",
            StringLen(g_V.cons)>0 ? C_BEAR : C_DIM, 8, m_vW);
}

//--- tab 1: the ensemble at past moments (v6.93)
void CScannerPanel::RefreshHist()
{
   if(Hist_PanelRows()==0)
   {
      FitLabel(m_hsHdr,"hsh","SIGNAL HISTORY  (switched off)",C_HEAD,8,m_inW);
      FitLabel(m_hs[0],"hs0","Set InpShowHistory=true and list minutes in InpHistLookbacks to use this tab.",C_DIM,8,m_inW);
      return;
   }
   FitLabel(m_hsHdr,"hsh","SIGNAL HISTORY  (same ensemble on closed bars, and the move since)",C_HEAD,8,m_inW);
   for(int i=0;i<m_hsRows;i++)
   {
      string txt=""; color c=C_DIM;
      Hist_RowText(i,txt,c);
      FitLabel(m_hs[i],"hs"+IntegerToString(i),txt,c,8,m_inW);
   }
}

//--- tab 2: net exposure and offsets (v6.8)
void CScannerPanel::RefreshHedge()
{
   if(!Hedge_Enabled())
   {
      FitLabel(m_hHdr,"hh","EXPOSURE AND HEDGE  (switched off)",C_HEAD,8,m_inW);
      FitLabel(m_hExpo,"hx","Set InpShowHedge=true to net your currency exposure and size offsets.",C_DIM,8,m_inW);
      for(int i=0;i<MAX_HEDGE_ROWS;i++) FitLabel(m_hRow[i],"hr"+IntegerToString(i),"",C_DIM,8,m_inW);
      FitLabel(m_hNote,"hn","",C_DIM,8,m_inW);
      return;
   }
   FitLabel(m_hHdr,"hh",StringFormat("EXPOSURE AND HEDGE  (correlation over %d %s bars)",
            g_corrPairs, g_tfName[ResolveTFIdx(InpCorrTF)]), C_HEAD, 8, m_inW);
   FitLabel(m_hExpo,"hx", g_expoLine, C_TEXT, 8, m_inW);
   for(int i=0;i<MAX_HEDGE_ROWS;i++)
      FitLabel(m_hRow[i],"hr"+IntegerToString(i), (i<g_hedgeN ? g_hedgeRow[i] : ""), C_DIM, 8, m_inW);
   //--- the caveat AB_Hedge is built around, printed where the numbers are read
   FitLabel(m_hNote,"hn","Offsets swap direction risk for correlation risk. Correlations fail in a crisis.",
            C_DIM, 8, m_inW);
}

//--- tab 3: your own journal, read back (v6.6)
void CScannerPanel::RefreshStats()
{
   Trader_StatsRefresh();               // re-reads the file only after a trade closes, or once a minute
   string cap="",fnd=""; color fc=C_DIM;
   string lt[TRADER_TAB_ROWS],rt[TRADER_TAB_ROWS];
   color  lc[TRADER_TAB_ROWS],rc[TRADER_TAB_ROWS];
   Trader_TabText(cap,lt,lc,rt,rc,fnd,fc);

   FitLabel(m_sHdr,"sth",cap,C_HEAD,8,m_inW-m_repW-8);
   FitButton(m_btnReport,"brep","FULL REPORT",8,m_repW);

   //--- the grid is sized as ONE table, like the timeframe rows: every cell
   //--- at the same size, so the two columns stay aligned
   int fs=8;
   while(fs>6)
   {
      int wmax=0;
      for(int k=0;k<TRADER_TAB_ROWS;k++)
         wmax=MathMax(wmax,MathMax(TextPxWidth(lt[k],fs),TextPxWidth(rt[k],fs)));
      if(wmax<=m_colW) break;
      fs--;
   }
   //--- FitLabel keeps the ".." rule for any cell that still does not fit at 6pt
   for(int k=0;k<TRADER_TAB_ROWS;k++)
   {
      FitLabel(m_sL[k],"sl"+IntegerToString(k),lt[k],lc[k],fs,m_colW);
      FitLabel(m_sR[k],"sr"+IntegerToString(k),rt[k],rc[k],fs,m_colW);
   }
   FitLabel(m_sFind,"sf",fnd,fc,8,m_inW);
}

void CScannerPanel::OnEditLot()
{
   g_ui_lot=NormalizeLot(StringToDouble(m_edLot.Text()));
   g_ui_riskMode=false;
   m_edLot.Text(DoubleToString(g_ui_lot,2));
   Refresh();
}
void CScannerPanel::OnEditRisk()
{
   g_ui_risk=MathMax(0.0,MathMin(InpMaxRiskPct,StringToDouble(m_edRisk.Text())));
   g_ui_riskMode=true;
   m_edRisk.Text(DoubleToString(g_ui_risk,1));
   Refresh();
}
void CScannerPanel::OnEditSL(){ g_ui_slPts=MathMax(0.0,StringToDouble(m_edSL.Text())); g_ui_auto=false; Refresh(); }
void CScannerPanel::OnEditTP(){ g_ui_tpPts=MathMax(0.0,StringToDouble(m_edTP.Text())); g_ui_auto=false; Refresh(); }

//+------------------------------------------------------------------+
//| Standard event plumbing                                          |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- v6.1/D3: during an optimisation the terminal loads one more copy of
   //--- the EA purely to collect frames. That copy has no business building
   //--- a panel, opening 43 indicator handles or arming a timer.
   if((bool)MQLInfoInteger(MQL_FRAME_MODE)){ g_headless=true; return INIT_SUCCEEDED; }

   g_isTester=(bool)MQLInfoInteger(MQL_TESTER);
   g_haltCount=0; g_haltTime=0; g_haltReArmAt=0; g_haltedSecs=0;

   g_tf[0]=PERIOD_M1;  g_tfName[0]="M1";
   g_tf[1]=PERIOD_M5;  g_tfName[1]="M5";
   g_tf[2]=PERIOD_M15; g_tfName[2]="M15";
   g_tf[3]=PERIOD_M30; g_tfName[3]="M30";
   g_tf[4]=PERIOD_H1;  g_tfName[4]="H1";
   g_tf[5]=PERIOD_H4;  g_tfName[5]="H4";
   g_tf[6]=PERIOD_D1;  g_tfName[6]="D1";
   ApplyTFWeights();

   if(!m_symbol.Name(Symbol()) || !m_symbol.RefreshRates())
   { Print("ERROR: symbol init failed"); return INIT_FAILED; }

   //--- A1: the two engines MUST be separable, or the trail would treat
   //--- your hand-placed trades as its own and CLOSE AUTO would flatten
   //--- them. This is a configuration error, not something to guess past.
   if(InpAutoMagic == MagicNumber)
   { Print("ERROR: InpAutoMagic must differ from MagicNumber — auto and manual positions could not be told apart"); return INIT_FAILED; }
   if(InpAutoBuyPct <= InpAutoSellPct)
   { Print("ERROR: InpAutoBuyPct must be above InpAutoSellPct"); return INIT_FAILED; }
   if(InpMaxPositions < 1)
   { Print("ERROR: InpMaxPositions must be at least 1"); return INIT_FAILED; }
   //--- v6.0: refuse rather than clamp. A silent clamp would let an
   //--- optimiser sweep InpMaxPositions past the ceiling and report the
   //--- same result five times over, which reads as a plateau that is not
   //--- there. Failing tells you the sweep range is wrong.
   if(InpMaxPositions > MAX_AUTO_POSITIONS)
   { PrintFormat("ERROR: InpMaxPositions %d exceeds the hard ceiling of %d",InpMaxPositions,MAX_AUTO_POSITIONS); return INIT_FAILED; }
   if(InpMaxTotalRiskPct > 0 && InpAutoRiskPct > InpMaxTotalRiskPct)
   { Print("ERROR: InpAutoRiskPct is above InpMaxTotalRiskPct — the first entry could never pass its own budget"); return INIT_FAILED; }

   m_trade.SetExpertMagicNumber(MagicNumber);
   m_trade.SetDeviationInPoints(50);
   m_trade.LogLevel(LOG_LEVEL_ERRORS);
   SetBestFillingMode();

   //--- M15: validate every handle instead of degrading to permanent
   //--- silent neutrality when one of them fails to create.
   bool ok=true;
   for(int i=0;i<TF_COUNT;i++)
   {
      g_lastBar[i]=0;
      g_R[i].ready=false;

      g_H[i].emaF=iMA(_Symbol,g_tf[i],InpEMAFast,  0,MODE_EMA,PRICE_CLOSE);
      g_H[i].emaM=iMA(_Symbol,g_tf[i],InpEMAMedium,0,MODE_EMA,PRICE_CLOSE);
      g_H[i].emaS=iMA(_Symbol,g_tf[i],InpEMASlow,  0,MODE_EMA,PRICE_CLOSE);
      g_H[i].rsi =iRSI(_Symbol,g_tf[i],InpRSIPeriod,PRICE_CLOSE);
      g_H[i].adx =iADX(_Symbol,g_tf[i],InpADXPeriod);
      g_H[i].atr =iATR(_Symbol,g_tf[i],InpATRPeriod);

      if(g_H[i].emaF==INVALID_HANDLE || g_H[i].emaM==INVALID_HANDLE ||
         g_H[i].emaS==INVALID_HANDLE || g_H[i].rsi ==INVALID_HANDLE ||
         g_H[i].adx ==INVALID_HANDLE || g_H[i].atr ==INVALID_HANDLE)
      { PrintFormat("ERROR: indicator handle creation failed on %s",g_tfName[i]); ok=false; }
   }
   g_atr_cur=iATR(_Symbol,PERIOD_CURRENT,InpATRPeriod);
   if(g_atr_cur==INVALID_HANDLE)
   { Print("ERROR: chart-TF ATR handle creation failed"); ok=false; }
   if(!ok) return INIT_FAILED;

   //--- v6.7: the watchlist opens its handles before the panel is built,
   //--- because the panel sizes its list section from the symbol count
   Watch_Init();
   Hist_Init();         // v6.93: parse the lookbacks before the panel sizes itself around them

   g_ui_lot   = InpDefaultLot;
   g_ui_risk  = MathMin(InpDefaultRisk,InpMaxRiskPct);
   g_ui_atrTF = -1;

   //--- v4.0 engine state, all seeded FROM THE INPUTS
   g_auto_on   = InpEnableAutoTrading;
   g_trailMode = InpTrailMode;
   //--- v6.2/E2: a netting account disarms the engine here and now if the
   //--- account is already known; otherwise the timer re-checks each second.
   g_marginChecked=false;
   CheckMarginMode();
   g_autoMsg   = g_netting ? "auto OFF — netting account (the engine needs hedging)"
               : (g_auto_on ? "arming..." : "auto OFF (InpEnableAutoTrading=false)");
   //--- A2: consume the bar that is already in progress, so attaching the
   //--- EA halfway through an H1 candle cannot fire an instant entry.
   g_lastSigBar   = iTime(_Symbol,SigTF(),0);
   g_lastCloseBar = 0;
   //--- adopt whatever is already open, so a recompile mid-trade does not
   //--- read as "a position just closed" and arm the cooldown for nothing.
   int ab0,as0; AutoPosCounts(ab0,as0);
   g_prevAutoCount = ab0+as0;
   //--- B5: seed the pacing clock from the newest auto position rather than
   //--- from zero. Restarting the EA is otherwise a way to skip the wait,
   //--- and in the tester a re-init between passes would hand the first
   //--- bar of every pass a free entry.
   g_lastEntryBar = 0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      if(!m_position.SelectByIndex(i)) continue;
      if(m_position.Symbol()!=_Symbol || !IsAutoPos(m_position.Magic())) continue;
      const datetime t=(datetime)m_position.Time();
      if(t>g_lastEntryBar) g_lastEntryBar=t;
   }
   g_dayStamp = 0;
   RollDay();
   //--- C1: fresh seeds for the high-water marks. Until v6.1 this was also
   //--- the final word, so a restart forgave any drawdown already taken.
   g_eqPeak  = AccountInfoDouble(ACCOUNT_EQUITY);
   g_balPeak = AccountInfoDouble(ACCOUNT_BALANCE);
   g_ddHalt  = false;
   //--- v6.2/E1: before touching the store, is another chart already running
   //--- this symbol with this magic? If so this copy is a scanner and nothing
   //--- else: it neither loads nor saves, and it takes over only when the
   //--- owner's heartbeat goes stale.
   State_Init();
   if(State_GuardCheck())
   {
      g_dupInstance=true;
      g_auto_on=false;
      g_autoMsg="DUPLICATE — another chart owns "+_Symbol+" with this magic; this copy scans only";
      PrintFormat("GUARD: another chart is already running %s with InpAutoMagic %I64u. This copy is SCANNER-ONLY: no entries, no stop management, no journal rows, no state writes. Remove one chart or give this one a different InpAutoMagic; it takes over by itself if the other copy is removed.",
                  _Symbol,InpAutoMagic);
   }
   else
   {
      State_Heartbeat();
      //--- v6.1/D2: the store overrules the seeds. Both peaks and the HALT
      //--- latch come back from the previous run; today's counters and the
      //--- cooldown / pacing anchors are rebuilt from the broker's deal
      //--- history, which also counts anything that happened while the EA
      //--- was off.
      State_Load();
   }
   State_RebuildFromHistory();

   //--- A7: the panel is a convenience, not a precondition. Without it the
   //--- scanner has no output — but the auto engine still works, and the
   //--- non-visual tester can never build a CAppDialog.
   //--- v6.7: the panel grows itself to fit the watchlist rather than
   //--- making Panel_H a number you have to keep in step with the length
   //--- of InpWatchSymbols. Panel_H is still the floor, so a taller
   //--- setting is honoured and a shorter one is simply raised.
   int panelH = Panel_H;
   {
      //--- v6.95: the same offset BuildControls lays the ticket out with
      int y = 506 + PanelTicketDY();
      if(Watch_Count()>0)  y += 20 + Watch_Count()*14;
      const int needed = y + 2 + 24;
      if(needed>panelH)
      {
         PrintFormat("PANEL: height raised from %d to %d so every section fits%s",
                     panelH,needed,(Watch_Count()>0 ? StringFormat(" (%d watchlist rows)",Watch_Count()) : ""));
         panelH=needed;
      }
   }

   g_headless = false;
   if(!g_panel.Create(0,"AstroBot MTF Scanner",0,Panel_X,Panel_Y,Panel_X+Panel_W,Panel_Y+panelH))
   {
      const bool nonVisualTester = (bool)MQLInfoInteger(MQL_TESTER) && !(bool)MQLInfoInteger(MQL_VISUAL_MODE);
      if(nonVisualTester || InpEnableAutoTrading)
      {
         g_headless = true;
         Print("NOTE: panel unavailable (no visual chart) — running HEADLESS. Auto engine is unaffected.");
      }
      else
      {
         Print("ERROR: panel create failed (visual chart required — CAppDialog does not draw in the non-visual tester)");
         return INIT_FAILED;
      }
   }
   else g_panel.Run();

   AnalyzeAll();
   //--- v6.1/D1: after the first scan (so an adopted position can price its
   //--- fallback stop from a real ATR) and before the first engine pass (so
   //--- nothing can close without a tracker in place).
   Journal_Init();
   Trader_Init();       // v6.6: the trader's own journal
   RunEngine();
   if(!g_headless){ g_panel.Refresh(); ChartRedraw(); }

   EventSetTimer(1);
   PrintFormat("AstroBot v%s ready — manual cockpit + auto trend engine [%s]. Signal %s, trail %s on %s, up to %d position(s), total risk cap %.2f%%. Signals are analysis, not advice.",
               AB_VERSION, g_auto_on?"ARMED":"disarmed", g_tfName[SigIdx()], TrailModeName(g_trailMode),
               g_tfName[TrailIdx()], InpMaxPositions, InpMaxTotalRiskPct);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if((bool)MQLInfoInteger(MQL_FRAME_MODE)) return;   // v6.1/D3: the frame collector built nothing to tear down
   State_Save(true);                                  // v6.1/D2: the store gets the last word
   State_HeartbeatClear();                            // v6.2/E1: release the symbol/magic for a successor
   if(InpReportOnDeinit && reason!=REASON_CHARTCHANGE) Trader_Report();
   EventKillTimer();
   g_panel.Destroy(reason);
   for(int i=0;i<TF_COUNT;i++)
   {
      IndicatorRelease(g_H[i].emaF); IndicatorRelease(g_H[i].emaM); IndicatorRelease(g_H[i].emaS);
      IndicatorRelease(g_H[i].rsi);  IndicatorRelease(g_H[i].adx);  IndicatorRelease(g_H[i].atr);
   }
   if(g_atr_cur!=INVALID_HANDLE) IndicatorRelease(g_atr_cur);
   Watch_Deinit();      // v6.7
}

void OnTimer()
{
   CheckMarginMode();   // v6.2/E2: no-op once the account has been seen
   State_Heartbeat();   // v6.2/E1: the owner says it is alive (no-op for a duplicate)
   State_TryPromote();  // v6.2/E1: a duplicate takes over once the owner is gone
   AnalyzeAll();
   RunEngine();
   State_Flush();       // v6.1/D2: a peak that moved this second is written now, not per tick
   //--- v6.9: LAST, and only from the timer. WebRequest blocks the thread,
   //--- so a slow endpoint must delay the report rather than the trading.
   Api_Push();
   if(!g_headless){ g_panel.Refresh(); ChartRedraw(); }
}

void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
{
   if(!g_headless) g_panel.ChartEvent(id,lparam,dparam,sparam);
}

//--- v4.0: this is where the bot stopped being a scanner. Trailing has to
//--- see every tick; entries are still gated to one decision per signal bar.
void OnTick() { RunEngine(); }

//+------------------------------------------------------------------+
//| A9: how an auto position actually left.                           |
//|                                                                   |
//| v4.0 inferred closes from the position count falling. That armed  |
//| the cooldown but could never distinguish a stop-out from a target |
//| from a manual intervention — which is precisely what you want to  |
//| know when reading back a session. The closing DEAL carries the    |
//| reason, the realised P/L and an exact timestamp, so read it.      |
//|                                                                   |
//| The count check in ManagePositions stays as a backstop: a         |
//| transaction can be missed across a reconnect, and a cooldown that |
//| fails to arm is worse than one that arms twice.                    |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest     &request,
                        const MqlTradeResult      &result)
{
   if(trans.type!=TRADE_TRANSACTION_DEAL_ADD || trans.deal==0) return;
   if(!HistoryDealSelect(trans.deal)) return;
   if(HistoryDealGetString(trans.deal,DEAL_SYMBOL)!=_Symbol) return;

   //--- v6.6: anything that is NOT the engine's is the TRADER's decision —
   //--- the panel buttons, one-click trading, the order window, mobile, web.
   //--- It gets its own journal, because "does this edge work" and "do I
   //--- follow my own signal" are different questions with different files.
   if(!IsAutoPos(HistoryDealGetInteger(trans.deal,DEAL_MAGIC)))
   {
      const long en=HistoryDealGetInteger(trans.deal,DEAL_ENTRY);
      if(en==DEAL_ENTRY_IN)                                  Trader_OnDealIn(trans.deal);
      else if(en==DEAL_ENTRY_OUT || en==DEAL_ENTRY_OUT_BY)   Trader_OnDealOut(trans.deal);
      return;
   }

   const long entry=HistoryDealGetInteger(trans.deal,DEAL_ENTRY);
   if(entry==DEAL_ENTRY_IN){ Journal_OnDealIn(trans.deal); return; }   // v6.1/D1: backstop for a tracker PlaceAuto could not key
   if(entry!=DEAL_ENTRY_OUT && entry!=DEAL_ENTRY_OUT_BY) return;

   RollDay();
   const double pl = HistoryDealGetDouble(trans.deal,DEAL_PROFIT)
                   + HistoryDealGetDouble(trans.deal,DEAL_SWAP)
                   + HistoryDealGetDouble(trans.deal,DEAL_COMMISSION);
   g_autoRealized += pl;
   if(pl>=0) g_autoWins++; else g_autoLosses++;

   //--- exact cooldown anchor: the signal bar the position actually left on
   g_lastCloseBar = iTime(_Symbol,SigTF(),0);

   const string why=DealReasonName(HistoryDealGetInteger(trans.deal,DEAL_REASON));
   g_lastAction=StringFormat("auto closed by %s, %+.2f %s",why,pl,AccountInfoString(ACCOUNT_CURRENCY));
   PrintFormat("AUTO CLOSE (%s): %+.2f %s | day %dW/%dL, realised %+.2f",
               why,pl,AccountInfoString(ACCOUNT_CURRENCY),
               g_autoWins,g_autoLosses,g_autoRealized);

   //--- v6.1/D1: the EXIT row — R multiple, MFE / MAE, bars held, and the
   //--- ensemble as it stood when the position left
   Journal_OnExit(trans.deal);
}

string DealReasonName(long r)
{
   switch((ENUM_DEAL_REASON)r)
   {
      case DEAL_REASON_SL:       return "stop loss";
      case DEAL_REASON_TP:       return "take profit";
      case DEAL_REASON_SO:       return "STOP OUT";
      case DEAL_REASON_EXPERT:   return "engine";
      case DEAL_REASON_CLIENT:   return "manual";
      case DEAL_REASON_MOBILE:   return "mobile";
      case DEAL_REASON_WEB:      return "web";
      case DEAL_REASON_ROLLOVER: return "rollover";
      case DEAL_REASON_VMARGIN:  return "variation margin";
      case DEAL_REASON_SPLIT:    return "split";
   }
   return "other";
}

//+------------------------------------------------------------------+
//| Analysis engine                                                  |
//+------------------------------------------------------------------+
bool Copy1(int h,int buf,int start,double &v)
{
   double a[]; ArraySetAsSeries(a,true);
   if(h==INVALID_HANDLE || CopyBuffer(h,buf,start,1,a)!=1) return false;
   v=a[0]; return true;
}
bool Copy3(int h,int buf,int start,double &a3[])
{
   ArraySetAsSeries(a3,true);
   return (h!=INVALID_HANDLE && CopyBuffer(h,buf,start,3,a3)==3);
}
string Arrow(int s){ return s>0?"▲":s<0?"▼":"●"; }

//+------------------------------------------------------------------+
//| v6.5/H1: how strongly a vote is held.                             |
//|                                                                  |
//| Until now every vote was 0 or 1. A DI gap of 5.1 against a        |
//| threshold of 5 counted exactly as much as a gap of 40, so a       |
//| barely-crossed line and an overwhelming one were the same number, |
//| and buyPct flickered whenever a vote sat on its own boundary.     |
//| This ramps linearly from 0 AT the threshold to 1 at `full`, which |
//| each vote sets in its own units. Nothing crosses that could not   |
//| cross before: the threshold still decides whether a vote counts   |
//| at all, and the sign is unchanged. Only the weight is new.        |
//|                                                                  |
//| Returns a MAGNITUDE in [0,1]; the caller applies the sign.        |
//| With InpGradedVotes off it returns 1 and the old behaviour is     |
//| restored exactly.                                                 |
//+------------------------------------------------------------------+
double VoteGrade(const double mag,const double thresh,const double full)
{
   if(!InpGradedVotes)  return 1.0;
   if(mag <= thresh)    return 0.0;
   if(full <= thresh)   return 1.0;      // no room to grade (threshold of zero)
   return MathMin(1.0,(mag-thresh)/(full-thresh));
}

//--- H4: how much history any of the ensemble members actually needs
//--- before its output means anything.
int MinBarsNeeded()
{
   int n = InpEMASlow;
   n = MathMax(n, InpRSIPeriod);
   n = MathMax(n, InpADXPeriod*2);       // ADX needs roughly 2x its period to settle
   n = MathMax(n, InpATRPeriod);
   n = MathMax(n, InpDonchianBars + 2);  // DON reads bars 1..N
   n = MathMax(n, InpADBars + 2);        // AD reads bars 1..N
   return n + 5;
}

bool HandleHasBars(int h)
{
   if(h==INVALID_HANDLE) return false;
   return (BarsCalculated(h) >= 4);   // we read bars 1..3
}

//+------------------------------------------------------------------+
//| C2 + H4: ONE readiness gate for the whole timeframe.              |
//| v3.1 let the RSI block flip r.ready on its own, so a timeframe    |
//| short of EMA50 history was scored anyway with the heaviest vote   |
//| silently zeroed. Either everything is ready or the row says so.   |
//+------------------------------------------------------------------+
//--- v6.7: symbol-aware, so the watchlist gets the identical gate
//--- v6.93: shift-aware. A reading `shift` bars back needs that many more
//--- bars of history, and every buffer must be calculated as deep as the
//--- furthest bar the votes read (shift+2). At shift 1 this is exactly the
//--- old test: MinBarsNeeded() bars, and BarsCalculated >= 4.
bool TFDataReadyFor(const string sym,const ENUM_TIMEFRAMES tf,const MTFHandles &H,const int shift)
{
   if(iBars(sym,tf) < MinBarsNeeded()+shift) return false;
   const int need=shift+3;
   return (BarsCalculated(H.emaF)>=need && BarsCalculated(H.emaM)>=need &&
           BarsCalculated(H.emaS)>=need && BarsCalculated(H.rsi) >=need &&
           BarsCalculated(H.adx) >=need && BarsCalculated(H.atr) >=need);
}
bool TFDataReady(int i){ return TFDataReadyFor(_Symbol,g_tf[i],g_H[i],1); }

//+------------------------------------------------------------------+
//| H6: no STRONG calls while ADX says the timeframe is ranging.      |
//+------------------------------------------------------------------+
string LabelFromNet(double net,bool ranging,int &dir)
{
   //--- R3: the two thresholds are inputs now. They were set against the
   //--- pre-v5.0 collinear vote set and had never been re-derived since.
   const double strong = MathMax(0.1,InpLabelStrongNet);
   const double buy    = MathMax(0.1,MathMin(strong,InpLabelBuyNet));
   int s=0;
   if(net>= strong)      s= 2;
   else if(net>= buy)    s= 1;
   else if(net<=-strong) s=-2;
   else if(net<=-buy)    s=-1;

   if(ranging && s== 2) s= 1;
   if(ranging && s==-2) s=-1;

   dir=s;
   if(s== 2) return "STRONG BUY";
   if(s== 1) return ranging ? "BUY (rng)"  : "BUY";
   if(s==-1) return ranging ? "SELL (rng)" : "SELL";
   if(s==-2) return "STRONG SELL";
   return "NEUTRAL";
}

//+------------------------------------------------------------------+
//| v6.7: the ensemble, for ANY symbol and timeframe.                 |
//|                                                                  |
//| This was AnalyzeTF(i), which read _Symbol, g_H[i] and g_R[i]      |
//| directly. Nothing about the six votes was ever symbol-specific -  |
//| only the three globals were - so the body is unchanged apart from |
//| taking the symbol and handles as arguments. The chart symbol and  |
//| every watched symbol now run identical code, which is the point:  |
//| a watchlist computed by a second, parallel implementation would   |
//| drift out of agreement with the panel the first time either       |
//| changed.                                                          |
//+------------------------------------------------------------------+
//--- v6.93: `shift` is the bar the votes read. 1 = the last closed bar, which
//--- is every live caller. The signal history passes the bar that was last
//--- closed at some past moment, and gets exactly what the panel showed then.
void AnalyzeOne(const string sym,const ENUM_TIMEFRAMES tf,const MTFHandles &H,TFResult &r,const int shift)
{
   r.ready=false; r.bullPts=0; r.bearPts=0; r.buyPct=50.0; r.dir=0;
   r.label="NEUTRAL"; r.breakdown=""; r.adx=0; r.ranging=false; r.atrVal=0;
   r.stkS=0; r.slpS=0; r.dmiS=0; r.rsiS=0; r.donS=0; r.adS=0;
   r.stkV=0; r.slpV=0; r.dmiV=0; r.rsiV=0; r.donV=0; r.adV=0;

   if(!TFDataReadyFor(sym,tf,H,shift)) return;

   const double price=iClose(sym,tf,shift);
   if(price<=0) return;

   double ef[],em[],es[];
   double rv,adx,pdi,mdi,atr;
   //--- M9: buffers 1 and 2 of iADX are +DI and -DI. They were fetched
   //--- by the handle and never read; now they are a vote of their own.
   if(!Copy3(H.emaF,0,shift,ef)  || !Copy3(H.emaM,0,shift,em) ||
      !Copy3(H.emaS,0,shift,es)  || !Copy1(H.rsi,0,shift,rv)  ||
      !Copy1(H.adx,0,shift,adx)  || !Copy1(H.adx,1,shift,pdi) ||
      !Copy1(H.adx,2,shift,mdi)  || !Copy1(H.atr,0,shift,atr))
   { r.ready=false; return; }     // any short copy -> the WHOLE TF is not ready

   r.ready   = true;
   r.adx     = adx;
   r.ranging = (adx < InpADXMin);
   r.atrVal  = atr;

   int    stkS=0, slpS=0, dmiS=0, rsiS=0, donS=0, adS=0;
   double stkV=0, slpV=0, dmiV=0, rsiV=0, donV=0, adV=0;

   //--- 1. STK — trend STRUCTURE. The one vote still built from a bare
   //--- price comparison, so it keeps M10's ATR-scaled dead zone: EMAs
   //--- coiled inside InpStackSepATR are a consolidation, not a stack.
   //--- Strength is the NARROWEST of the two gaps, so a stack is only as
   //--- convincing as its weakest rung, and saturates at twice the gate.
   const double sep   = MathMax(0.0,InpStackSepATR)*atr;
   const double stkUp = MathMin(ef[0]-em[0], em[0]-es[0]);
   const double stkDn = MathMin(em[0]-ef[0], es[0]-em[0]);
   if(stkUp > sep)      { stkS= 1; stkV=  VoteGrade(stkUp,sep,2.0*sep); }
   else if(stkDn > sep) { stkS=-1; stkV= -VoteGrade(stkDn,sep,2.0*sep); }

   //--- 2. SLP — trend RATE (M14). Copy3 already paid for three bars;
   //--- index 2 is the far end. Where price SITS and how fast the curve
   //--- is MOVING are different derivatives, not the same reading twice.
   const double slope = em[0]-em[2];
   const double slpT  = InpSlopeATR*atr;
   if(slope >  slpT)      { slpS= 1; slpV=  VoteGrade(slope,slpT,3.0*slpT); }
   else if(slope < -slpT) { slpS=-1; slpV= -VoteGrade(-slope,slpT,3.0*slpT); }

   //--- 3. DMI — directional MOVEMENT. Built from range expansion, so it
   //--- is the one directional vote that never touches a moving average.
   const double diGap = pdi-mdi;
   if(diGap >  InpDIThresh)      { dmiS= 1; dmiV=  VoteGrade(diGap,InpDIThresh,3.0*InpDIThresh); }
   else if(-diGap > InpDIThresh) { dmiS=-1; dmiV= -VoteGrade(-diGap,InpDIThresh,3.0*InpDIThresh); }

   //--- 4. RSI — bounded MOMENTUM oscillator. Saturates halfway from its
   //--- own threshold to the extreme, so 77.5 is a full bull vote at the
   //--- default 55 and 22.5 is a full bear vote at the default 45.
   if(rv>InpRSIBull)
   { rsiS= 1; rsiV=  VoteGrade(rv,InpRSIBull,InpRSIBull+(100.0-InpRSIBull)*0.5); }
   else if(rv<InpRSIBear)
   { rsiS=-1; rsiV= -VoteGrade(100.0-rv,100.0-InpRSIBear,(100.0-InpRSIBear)+InpRSIBear*0.5); }

   //--- 5. DON — RANGE POSITION. Where the close sits inside the last
   //--- N bars' own high/low channel: a pure range measurement with no
   //--- average of any kind in it.
   const int hiSh=iHighest(sym,tf,MODE_HIGH,InpDonchianBars,shift);
   const int loSh=iLowest (sym,tf,MODE_LOW, InpDonchianBars,shift);
   if(hiSh>=0 && loSh>=0)
   {
      const double hh=iHigh(sym,tf,hiSh), ll=iLow(sym,tf,loSh);
      if(hh>ll)
      {
         const double pos  = (price-ll)/(hh-ll);                       // [0,1]
         const double band = MathMin(0.95,MathMax(0.55,InpDonchianPos));
         //--- full strength only at the very edge of the channel
         if(pos > band)          { donS= 1; donV=  VoteGrade(pos,band,1.0); }
         else if(pos < 1.0-band) { donS=-1; donV= -VoteGrade(1.0-pos,band,1.0); }
      }
   }

   //--- 6. AD — volume-weighted PRESSURE (M8). Volume is the WEIGHT;
   //--- the direction comes from where each bar closed inside its own
   //--- range. The old vote was close[1]>close[2] with a volume gate
   //--- bolted on — a price vote in a volume hat, collinear with the
   //--- rest of the set.
   long vv[]; ArraySetAsSeries(vv,true);
   const int nb=MathMax(1,InpADBars);
   if(CopyTickVolume(sym,tf,shift,nb,vv)==nb)
   {
      double num=0, den=0;
      for(int k=0;k<nb;k++)
      {
         const double h=iHigh(sym,tf,shift+k), l=iLow(sym,tf,shift+k), c=iClose(sym,tf,shift+k);
         const double rng=h-l, v=(double)vv[k];
         if(rng>0 && v>0){ num += (((c-l)-(h-c))/rng)*v; den += v; }
      }
      if(den>0)
      {
         const double pressure=num/den;                                // [-1,+1]
         if(pressure >  InpADThresh)      { adS= 1; adV=  VoteGrade(pressure,InpADThresh,1.0); }
         else if(pressure < -InpADThresh) { adS=-1; adV= -VoteGrade(-pressure,InpADThresh,1.0); }
      }
   }

   //--- v6.5/H1: a vote contributes its STRENGTH, not a flat 1. With
   //--- InpGradedVotes off every strength is exactly 1 and this is the
   //--- old sum unchanged.
   double vs[6];
   vs[0]=stkV; vs[1]=slpV; vs[2]=dmiV; vs[3]=rsiV; vs[4]=donV; vs[5]=adV;
   for(int k=0;k<6;k++)
   {
      if(vs[k] > 0)      r.bullPts += vs[k];
      else if(vs[k] < 0) r.bearPts += -vs[k];
   }

   //--- A3: keep the individual votes; the auto engine gates on STK.
   r.stkS=stkS; r.slpS=slpS; r.dmiS=dmiS; r.rsiS=rsiS; r.donS=donS; r.adS=adS;
   r.stkV=stkV; r.slpV=slpV; r.dmiV=dmiV; r.rsiV=rsiV; r.donV=donV; r.adV=adV;

   const double net = r.bullPts - r.bearPts;

   //--- C1: score against the FULL scale. Neutral votes now pull the
   //--- reading toward 50 instead of vanishing from the denominator.
   r.buyPct = MathMax(0.0, MathMin(100.0, 50.0 + (net/MAX_PTS)*50.0));
   r.label  = LabelFromNet(net, r.ranging, r.dir);
   r.breakdown = StringFormat("STK%s SLP%s DMI%s RSI%s DON%s AD%s",
                              Arrow(stkS),Arrow(slpS),Arrow(dmiS),
                              Arrow(rsiS),Arrow(donS),Arrow(adS));
}

//--- the chart symbol's own row, unchanged in behaviour
void AnalyzeTF(int i){ AnalyzeOne(_Symbol,g_tf[i],g_H[i],g_R[i],1); }

void AnalyzeAll()
{
   double oNet=0, oMax=0;
   g_up=0; g_dn=0; g_nt=0;

   for(int i=0;i<TF_COUNT;i++)
   {
      //--- M13: bar-1 values only change when a new bar opens. Re-run
      //--- while a timeframe is still not ready so history can catch up.
      const datetime bt = iTime(_Symbol,g_tf[i],0);
      if(bt==0 || bt!=g_lastBar[i] || !g_R[i].ready)
      {
         AnalyzeTF(i);
         g_lastBar[i]=bt;
      }

      if(!g_R[i].ready) continue;

      //--- H6: discount a ranging timeframe's directional evidence but
      //--- keep its full weight in the denominator, so the aggregate is
      //--- pulled toward neutral rather than the timeframe dropping out.
      const double regime = g_R[i].ranging ? MathMax(0.0,MathMin(1.0,InpRangingWeight)) : 1.0;
      oNet += (g_R[i].bullPts - g_R[i].bearPts) * g_tfW[i] * regime;
      oMax += MAX_PTS * g_tfW[i];

      if(g_R[i].dir>0) g_up++; else if(g_R[i].dir<0) g_dn++; else g_nt++;
   }

   //--- C1 at the aggregate level: net over TOTAL AVAILABLE weight.
   //--- The old form divided by cast votes only, so two votes across six
   //--- timeframes could read 100%. Thresholds below are unchanged but
   //--- now sit on a far more conservative scale: 65% means every ready
   //--- timeframe is carrying roughly net +2.
   g_overallBuyPct = (oMax>0) ? MathMax(0.0,MathMin(100.0, 50.0+(oNet/oMax)*50.0)) : 50.0;

   if(g_overallBuyPct>=65)      { g_overallDir= 2; g_overallLabel="BULLISH";      }
   else if(g_overallBuyPct>=55) { g_overallDir= 1; g_overallLabel="Weak Bullish"; }
   else if(g_overallBuyPct> 45) { g_overallDir= 0; g_overallLabel="NEUTRAL";      }
   else if(g_overallBuyPct> 35) { g_overallDir=-1; g_overallLabel="Weak Bearish"; }
   else                         { g_overallDir=-2; g_overallLabel="BEARISH";      }

   //--- session and news are wall-clock, so they run every second
   UpdateFilters();

   //--- M13: chart-TF ATR and the volatility tag are also bar-1 data
   const datetime btc = iTime(_Symbol,PERIOD_CURRENT,0);
   if(btc==0 || btc!=g_lastBarChart)
   {
      double a;
      if(Copy1(g_atr_cur,0,1,a) && a>0) g_atrChart=a;
      UpdateVolatility();
      g_lastBarChart=btc;
   }

   UpdateAutoStops();
   BuildVerdict();      // v6.5/H3: display only, and it reads what the engine reads
   Watch_Analyze();     // v6.7: other pairs, bar-gated like everything else
   Hedge_Update();      // v6.8: currency netting every pass, correlation once a bar
   Hist_Update();       // v6.93: past readings, once per M1 bar
}

//+------------------------------------------------------------------+
//| H7: size the stop from the timeframe that produced the conviction,|
//| not from whatever chart happens to be open. Falls back to the     |
//| chart TF if the selected one has no history yet, and says so.     |
//+------------------------------------------------------------------+
void UpdateAutoStops()
{
   if(!g_ui_auto) return;

   double atr=0;
   if(g_ui_atrTF>=0 && g_ui_atrTF<TF_COUNT && g_R[g_ui_atrTF].ready && g_R[g_ui_atrTF].atrVal>0)
   {
      atr      = g_R[g_ui_atrTF].atrVal;
      g_atrSrc = g_tfName[g_ui_atrTF];
   }
   else if(g_atrChart>0)
   {
      atr      = g_atrChart;
      g_atrSrc = TfName((ENUM_TIMEFRAMES)_Period) + (g_ui_atrTF>=0 ? " FALLBACK" : "");
   }

   if(atr<=0){ g_atrSrc="-"; return; }

   g_ui_slPts = MathRound(atr/m_symbol.Point()*InpSL_ATR_Mult);
   g_ui_tpPts = MathRound(g_ui_slPts*InpTP_RR);
}

void UpdateFilters()
{
   g_sessionMsg="OK"; g_newsMsg="clear";
   g_sessionBlock=false; g_newsBlock=false;
   if(UseNYSessionFilter)
   {
      MqlDateTime dt; TimeToStruct(TimeCurrent(),dt);
      const int nyM=NY_Session_Hour*60+NY_Session_Minute, curM=dt.hour*60+dt.min;
      if(curM>=nyM-Hours_Before_NY*60 && curM<=nyM+Hours_After_NY*60)
      {
         const int d=nyM-curM;
         g_sessionMsg=(d>0)?StringFormat("NY open in %dm — CAUTION",d):StringFormat("NY open %dm ago — CAUTION",-d);
         g_sessionBlock=true;
      }
   }
   if(UseNewsFilter)
   {
      const datetime now=TimeCurrent();
      if(now-g_newsUpdate>3600){ LoadNewsCalendar(); g_newsUpdate=now; }
      for(int i=0;i<ArraySize(g_news);i++)
      {
         if(g_news[i].impact<3) continue;
         const int dm=(int)((g_news[i].t-now)/60);
         if(dm>=-Minutes_After_News && dm<=Minutes_Before_News)
         { g_newsMsg=(dm>0)?StringFormat("high-impact in %dm — CAUTION",dm):StringFormat("high-impact %dm ago — CAUTION",-dm);
           g_newsBlock=true; break; }
      }
   }
}

void UpdateVolatility()
{
   double a[]; ArraySetAsSeries(a,true);
   if(g_atr_cur==INVALID_HANDLE || CopyBuffer(g_atr_cur,0,1,20,a)<20){ g_volMsg="-"; return; }
   double sum=0; for(int i=0;i<20;i++) sum+=a[i];
   const double mean=sum/20.0;
   const double atrPips=a[0]/m_symbol.Point()*((_Digits==3||_Digits==5)?0.1:1.0);
   string tag="normal";
   g_volRatio=0;
   if(mean>0){ const double r=a[0]/mean; g_volRatio=r; if(r>1.3) tag="HIGH"; else if(r<0.7) tag="LOW"; }
   g_volMsg=StringFormat("ATR %.1f %s",atrPips,tag);
}

void LoadNewsCalendar()
{
   ArrayResize(g_news,0);
   MqlCalendarValue values[];
   const datetime a=TimeCurrent(), b=a+86400;
   if(!CalendarValueHistory(values,a,b)) return;
   const string base=SymbolInfoString(_Symbol,SYMBOL_CURRENCY_BASE);
   const string profit=SymbolInfoString(_Symbol,SYMBOL_CURRENCY_PROFIT);
   int n=0;
   for(int i=0;i<ArraySize(values);i++)
   {
      MqlCalendarEvent ev; if(!CalendarEventById(values[i].event_id,ev)) continue;
      if(ev.importance!=CALENDAR_IMPORTANCE_HIGH) continue;
      MqlCalendarCountry ct; if(!CalendarCountryById(ev.country_id,ct)) continue;
      if(ct.currency!=base && ct.currency!=profit) continue;
      ArrayResize(g_news,n+1); g_news[n].t=values[i].time; g_news[n].title=ev.name; g_news[n].impact=3; n++;
   }
}

//+==================================================================+
//|                       AUTO TREND ENGINE                          |
//+==================================================================+

//--- small accessors so the enum inputs never leak into the logic ------
//--- v6.5: SIG_CHART resolves to the chart's own timeframe. When the chart
//--- sits on a period the ladder does not carry (M2, H8, W1, MN1) there is
//--- no row to read, so it falls back to M5 rather than pretending.
int ResolveTFIdx(const ENUM_SIG_TF sel)
{
   if(sel!=SIG_CHART) return (int)sel;
   const int ci=CurrentTFIndex();
   return (ci>=0 ? ci : 1);           // 1 = M5
}
int             SigIdx()     { return ResolveTFIdx(InpSignalTF);  }
ENUM_TIMEFRAMES SigTF()      { return g_tf[SigIdx()];             }
int             TrailIdx()   { return ResolveTFIdx(InpTrailTF);   }
ENUM_TIMEFRAMES TrailTF()    { return g_tf[TrailIdx()];           }
int             ConfirmIdx() { return ResolveTFIdx(InpConfirmTF); }

string TrailModeName(ENUM_TRAIL_MODE m)
{
   if(m==TRAIL_POINTS)     return "POINTS";
   if(m==TRAIL_ATR)        return "ATR";
   if(m==TRAIL_CHANDELIER) return "CHANDLR";
   return "OFF";
}

//--- A1: magic-based ownership. Comments are not trustworthy.
bool IsOurs(long m)   { return (m==(long)MagicNumber || m==(long)InpAutoMagic); }
bool IsAutoPos(long m){ return (m==(long)InpAutoMagic); }

//+------------------------------------------------------------------+
//| M11: the timeframe ladder, made explicit.                         |
//|                                                                   |
//| The legacy 1.3x step was invented, and the header admitted it. So |
//| is every alternative — HORIZON at least has a stated rationale     |
//| (a D1 bar covers 288 M5 bars, and log2 keeps that from letting D1  |
//| swamp the sum). LADDER remains the default so this pass does not   |
//| silently move anyone's numbers.                                    |
//+------------------------------------------------------------------+
void ApplyTFWeights()
{
   //--- v6.0: M1 takes the 1.0 base and the old rungs keep their spacing,
   //--- so the RELATIVE weights of M5..D1 are unchanged from v5.x. The
   //--- absolute numbers moved (the sum is larger), but buyPct is a ratio,
   //--- so a v5.x reading of M5..D1 alone still maps to the same percentage.
   const double ladder[TF_COUNT] = {0.8, 1.0, 1.3, 1.6, 2.1, 2.7, 3.4};
   const double base = (double)PeriodSeconds(g_tf[0]);
   for(int i=0;i<TF_COUNT;i++)
   {
      if(InpTFWeighting==TFW_FLAT) g_tfW[i]=1.0;
      else if(InpTFWeighting==TFW_HORIZON)
      {
         const double ratio=(base>0) ? (double)PeriodSeconds(g_tf[i])/base : 1.0;
         g_tfW[i]=1.0+MathLog(MathMax(1.0,ratio))/MathLog(2.0);
      }
      else g_tfW[i]=ladder[i];
   }
}

//+------------------------------------------------------------------+
//| A6: the daily governors reset on the SERVER day, because that is  |
//| the day the broker's statement uses.                              |
//+------------------------------------------------------------------+
void RollDay()
{
   MqlDateTime dt; TimeToStruct(TimeCurrent(),dt);
   const datetime day = StringToTime(StringFormat("%04d.%02d.%02d",dt.year,dt.mon,dt.day));
   if(day==g_dayStamp) return;
   g_dayStamp     = day;
   g_dayStartEq   = AccountInfoDouble(ACCOUNT_EQUITY);
   g_tradesToday  = 0;
   g_autoWins     = 0;
   g_autoLosses   = 0;
   g_autoRealized = 0;
   State_Save(true);    // v6.1/D2: the day's anchor outlives a restart (a no-op until State_Load has run)
}
double DayPnLPct()
{
   if(g_dayStartEq<=0) return 0.0;
   return (AccountInfoDouble(ACCOUNT_EQUITY)-g_dayStartEq)/g_dayStartEq*100.0;
}

//+------------------------------------------------------------------+
//| C1: the absolute drawdown governor.                               |
//|                                                                   |
//| C2: current equity is compared against the BALANCE peak by default,|
//| not the equity peak. Both count floating LOSS in full — a position |
//| 8% underwater has spent that 8% whether or not it is booked. They  |
//| differ on floating PROFIT, and that difference is the whole story: |
//| an equity peak includes profit the trail has not yet banked, so    |
//| the give-back on every winning exit registers as drawdown. That is |
//| not a risk event, it is how a trailing stop works. Measuring from  |
//| the balance peak scores only what has actually been lost.          |
//| DD_FROM_EQUITY restores the strict reading for anyone whose prop   |
//| firm measures it that way — see the C1 note in the header.         |
//|                                                                   |
//| The halt LATCHES and does not clear itself. That is not laziness — |
//| once flat and halted, equity stops moving, so a self-clearing      |
//| version could never recover the drawdown that triggered it and     |
//| would deadlock. A max-drawdown limit is terminal by nature; the    |
//| per-day limit above is the one built to resume. Re-arming means    |
//| restarting the EA, which is a decision a person should make.       |
//|                                                                   |
//| WHAT THIS DOES NOT PROMISE: it stops the engine ADDING risk at the |
//| limit. It cannot unwind the past. With InpDD_FlattenOnBreach off,  |
//| open positions keep running and can lose more; with it on, the     |
//| close still has to be filled, and a gap fills below the limit.     |
//| The realised figure will overshoot — by how much is the broker's   |
//| answer, not this EA's.                                            |
//+------------------------------------------------------------------+
double CurrentDDPct()
{
   const double eq=AccountInfoDouble(ACCOUNT_EQUITY);
   const double peak=(InpDD_Basis==DD_FROM_EQUITY ? g_eqPeak : g_balPeak);
   if(peak<=0 || eq<=0) return 0.0;
   const double dd=(peak-eq)/peak*100.0;
   return (dd>0 ? dd : 0.0);
}

void UpdateDrawdown()
{
   const double eq =AccountInfoDouble(ACCOUNT_EQUITY);
   const double bal=AccountInfoDouble(ACCOUNT_BALANCE);
   if(eq<=0) return;
   //--- v6.1: an EA that initialised before the account was connected has a
   //--- zero day anchor, which leaves the daily loss limit silently off until
   //--- the next server day. The first valid equity becomes the anchor.
   if(g_dayStartEq<=0){ g_dayStartEq=eq; State_Save(true); }
   if(eq >g_eqPeak) { g_eqPeak =eq;  State_Touch(); }   // v6.1/D2: written by the timer
   if(bal>g_balPeak){ g_balPeak=bal; State_Touch(); }
   if(InpMaxDrawdownPct<=0) return;

   if(g_ddHalt)
   {
      //--- v6.3/F1: TESTER ONLY. Live, the latch waits for a person. In a
      //--- backtest nobody comes, and a halt in week one would silence the
      //--- remaining months, so the halt is cleared InpTesterReArmDays
      //--- server days later exactly as the panel button would clear it.
      if(g_isTester && InpTesterReArmDays>0 && g_haltReArmAt>0 && TimeCurrent()>=g_haltReArmAt)
      {
         g_haltedSecs+=(long)(TimeCurrent()-g_haltTime);
         State_ReArm(StringFormat("tester, %d server day(s) after halt #%d",InpTesterReArmDays,g_haltCount));
         g_haltReArmAt=0;
      }
      return;
   }

   const double dd=CurrentDDPct();
   if(dd < InpMaxDrawdownPct) return;

   g_ddHalt=true;
   g_haltCount++;
   g_haltTime=TimeCurrent();
   g_haltReArmAt=((g_isTester && InpTesterReArmDays>0) ? DayStart(g_haltTime)+InpTesterReArmDays*86400 : 0);
   State_Save(true);    // v6.1/D2: a HALT is the one fact that must never be lost to a restart
   PrintFormat("HALT #%d: drawdown %.2f%% reached the %.2f%% limit (%s peak %.2f, equity now %.2f). %s",
               g_haltCount,dd,InpMaxDrawdownPct,
               (InpDD_Basis==DD_FROM_EQUITY?"equity":"balance"),
               (InpDD_Basis==DD_FROM_EQUITY?g_eqPeak:g_balPeak), eq,
               (g_haltReArmAt>0 ? "Tester: re-arms at "+TimeToString(g_haltReArmAt,TIME_DATE|TIME_MINUTES)+"."
                                : "No further auto entries until re-armed."));
   if(InpDD_FlattenOnBreach) CloseAuto("drawdown limit");
}

//--- A6: cooldown measured in real bars of the signal timeframe, so a
//--- weekend or a holiday cannot silently satisfy it.
int BarsSinceClose()
{
   if(g_lastCloseBar<=0) return 1000000;
   const datetime cur=iTime(_Symbol,SigTF(),0);
   if(cur<=0) return 1000000;
   const int n=Bars(_Symbol,SigTF(),g_lastCloseBar,cur);
   return (n>0 ? n-1 : 0);
}

//--- B5: the same measurement, anchored to the last ENTRY rather than the
//--- last close. These are different questions and both need asking:
//--- InpCooldownBars answers "how long after being stopped out do I sit
//--- still", InpMinBarsBetweenEntries answers "how fast may I build a
//--- stack". v6.0 had only the first, so on M1 three positions could open
//--- in three consecutive minutes — one per bar is the engine's ceiling,
//--- and one per bar on M1 is far too fast to be three separate ideas.
int BarsSinceEntry()
{
   if(g_lastEntryBar<=0) return 1000000;
   const datetime cur=iTime(_Symbol,SigTF(),0);
   if(cur<=0) return 1000000;
   const int n=Bars(_Symbol,SigTF(),g_lastEntryBar,cur);
   return (n>0 ? n-1 : 0);
}

//+------------------------------------------------------------------+
//| Auto sizing / stop distance — read ONLY from inputs, never from   |
//| the panel's edit boxes. The panel drives the manual ticket; the   |
//| engine drives itself.                                             |
//+------------------------------------------------------------------+
double AutoSLMult(){ return (InpAutoSL_ATR_Mult>0 ? InpAutoSL_ATR_Mult : InpSL_ATR_Mult); }
double AutoATR()
{
   const int si=SigIdx();
   if(g_R[si].ready && g_R[si].atrVal>0) return g_R[si].atrVal;
   return g_atrChart;                       // fallback: chart-TF ATR
}
//+------------------------------------------------------------------+
//| B1: the smallest stop distance this broker will actually accept,  |
//| in points, plus whatever floor the user asked for on top.         |
//|                                                                   |
//| This exists because SendEntry used to widen a too-tight stop AFTER |
//| PlaceAuto had already sized the lot against the narrow one — so    |
//| the position went on at the intended lot with a wider stop, and    |
//| the real risk quietly exceeded InpAutoRiskPct. On H1 the ATR stop  |
//| cleared the broker minimum every time and the bug never fired. On  |
//| M1 the ATR stop is inside it most bars. Same floor, one place,     |
//| applied BEFORE sizing.                                            |
//+------------------------------------------------------------------+
double MinStopPoints()
{
   const double pt=m_symbol.Point();
   if(pt<=0) return 0;
   const long stopsLvl=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL);
   const long freeze  =SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL);
   const double broker=(double)MathMax(stopsLvl,freeze)+2.0;
   return MathMax(broker,(double)MathMax(0,InpMinSLPoints));
}

double AutoSLPts()
{
   const double atr=AutoATR(), pt=m_symbol.Point();
   if(atr<=0 || pt<=0) return 0;
   return MathMax(MathRound(atr/pt*AutoSLMult()), MinStopPoints());
}

//+------------------------------------------------------------------+
//| B3: combined open risk of every AUTO position, as % of equity.    |
//|                                                                   |
//| Measured from each position's CURRENT stop, not its original one,  |
//| so a position the trail has pulled to break-even correctly frees   |
//| its budget for the next entry. A stop already past entry counts    |
//| as zero risk, never as negative — locked profit is not a licence   |
//| to take a bigger position elsewhere.                              |
//+------------------------------------------------------------------+
double OpenAutoRiskPct()
{
   const double eq=AccountInfoDouble(ACCOUNT_EQUITY);
   const double tv=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   const double ts=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(eq<=0 || tv<=0 || ts<=0) return 0.0;

   double money=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      if(!m_position.SelectByIndex(i)) continue;
      if(m_position.Symbol()!=_Symbol || !IsAutoPos(m_position.Magic())) continue;

      const double open=m_position.PriceOpen();
      const double sl  =m_position.StopLoss();
      const bool   isBuy=(m_position.PositionType()==POSITION_TYPE_BUY);

      //--- no stop at all is unbounded risk, not zero risk. Charge the
      //--- whole account so the engine stops adding until it has one, and
      //--- so the panel reads 100% rather than a comfortable small number.
      //--- Deliberately not scaled by InpMaxTotalRiskPct: this has to stay
      //--- honest on the display path, which runs with the governor off.
      if(sl<=0){ money+=eq; continue; }

      const double adverse = isBuy ? (open-sl) : (sl-open);
      if(adverse<=0) continue;                    // break-even or better
      money += adverse/ts*tv*m_position.Volume();
   }
   return money/eq*100.0;
}

//+------------------------------------------------------------------+
//| B2: is a new entry far enough from what is already open the same  |
//| way? Without this the cap is not "5 positions", it is one         |
//| position at 5x size — five consecutive M1 bars in a trend all     |
//| pass the same gates at almost the same price.                     |
//|                                                                   |
//| Absolute distance, deliberately: requiring the new entry be       |
//| FURTHER ALONG the trend would forbid re-entry after a pullback,   |
//| which is the entry this strategy is actually built to take.       |
//+------------------------------------------------------------------+
bool AutoStackOK(int dir,string &why)
{
   why="";
   if(InpStackMinSepATR<=0) return true;

   const double atr=AutoATR();
   if(atr<=0) return true;                       // no ATR yet: AutoSLPts already blocks
   const double need=InpStackMinSepATR*atr;
   //--- read the tick live rather than m_symbol's cache: that cache is only
   //--- refreshed on the paths that touch an order, and EvaluateSetup is
   //--- documented as reading state without changing any.
   const double px = SymbolInfoDouble(_Symbol, dir>0 ? SYMBOL_ASK : SYMBOL_BID);
   if(px<=0) return true;

   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      if(!m_position.SelectByIndex(i)) continue;
      if(m_position.Symbol()!=_Symbol || !IsAutoPos(m_position.Magic())) continue;
      const bool isBuy=(m_position.PositionType()==POSITION_TYPE_BUY);
      if((dir>0)!=isBuy) continue;               // only the same side crowds

      const double gap=MathAbs(px-m_position.PriceOpen());
      if(gap<need)
      {
         why=StringFormat("too close — %.*f from an open %s, need %.*f (%.2f x ATR)",
                          m_symbol.Digits(),gap,(isBuy?"long":"short"),
                          m_symbol.Digits(),need,InpStackMinSepATR);
         return false;
      }
   }
   return true;
}
double TrailATRVal()
{
   const int ti=TrailIdx();
   if(g_R[ti].ready && g_R[ti].atrVal>0) return g_R[ti].atrVal;
   return g_atrChart;
}

void AutoPosCounts(int &buys,int &sells)
{
   buys=0; sells=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      if(!m_position.SelectByIndex(i)) continue;
      if(m_position.Symbol()!=_Symbol || !IsAutoPos(m_position.Magic())) continue;
      if(m_position.PositionType()==POSITION_TYPE_BUY) buys++; else sells++;
   }
}

//+------------------------------------------------------------------+
//| v6.3/F2: the weekend window. From the Friday cut-off (server     |
//| time) until the week's close nothing new is opened and nothing   |
//| of the engine's stays open. A stop measured in dollars cannot    |
//| survive a gap measured in tens of them; the first journal showed |
//| exactly that trade. Manual positions are yours and are left be.  |
//+------------------------------------------------------------------+
datetime DayStart(const datetime t){ return (datetime)((long)t-((long)t%86400)); }

bool WeekendWindow()
{
   MqlDateTime dt; TimeToStruct(TimeCurrent(),dt);
   if(dt.day_of_week==6) return true;                   // Saturday: any late session is still "into the gap"
   if(dt.day_of_week!=5) return false;
   const int cut=MathMax(0,MathMin(23,InpFridayCutoffHour))*60+MathMax(0,MathMin(59,InpFridayCutoffMin));
   return (dt.hour*60+dt.min >= cut);
}

//--- every tick, owner only: flatten the engine's book inside the window
void WeekendFlattenCheck()
{
   if(!InpWeekendFlatten || !WeekendWindow()) return;
   int b,s; AutoPosCounts(b,s);
   if(b+s==0) return;
   const datetime now=TimeCurrent();
   if((long)(now-g_lastWeekendFlatten)<60) return;      // a failed close is retried once a minute, not per tick
   g_lastWeekendFlatten=now;
   PrintFormat("WEEKEND: Friday %02d:%02d cut-off passed with %d auto position(s) open - flattening",
               InpFridayCutoffHour,InpFridayCutoffMin,b+s);
   CloseAuto("weekend flatten");
}

//--- Join items into a readable list. CLabel CLIPS to its width and the
//--- card is 498 px of 8pt Consolas, which is roughly 76 characters, so
//--- the items below are deliberately terse rather than conversational.
void VAdd(string &s,const string item)
{
   if(StringLen(item)==0) return;
   if(StringLen(s)>0) s+="  ";
   s+=item;
}

//+------------------------------------------------------------------+
//| v6.5/H3: build the verdict. Display only — it places nothing and  |
//| changes nothing. It reads the same aggregate and the same         |
//| thresholds the auto engine reads, so the panel and the engine can |
//| never tell you two different stories about the same bar.          |
//|                                                                  |
//| The grade counts how many independent checks agree, and each      |
//| check is one an experienced reader would make by hand: does the   |
//| timeframe you are trading agree with the weighted picture, is the |
//| trend structurally there, is the market actually moving, does a   |
//| higher timeframe back it, and is anything in the way right now.   |
//+------------------------------------------------------------------+
void BuildVerdict()
{
   g_V.dir=0; g_V.pass=0; g_V.total=0; g_V.grade="-";
   g_V.head="WAIT   no setup"; g_V.levels=""; g_V.pros=""; g_V.cons="";

   const int si=SigIdx();
   const int ci=ConfirmIdx();

   if(!g_R[si].ready)
   { g_V.head=StringFormat("WAIT   %s is still loading history",g_tfName[si]); return; }

   //--- side, from the weighted aggregate
   int want=0;
   if(g_overallBuyPct>=InpAutoBuyPct)       want= 1;
   else if(g_overallBuyPct<=InpAutoSellPct) want=-1;

   if(want==0)
   {
      const bool up=(g_overallBuyPct>=50.0);
      const double gap=(up ? InpAutoBuyPct-g_overallBuyPct : g_overallBuyPct-InpAutoSellPct);
      g_V.head=StringFormat("WAIT   bias %.0f%% sits inside the %.0f-%.0f neutral band",
                            g_overallBuyPct,InpAutoSellPct,InpAutoBuyPct);
      g_V.levels=StringFormat("leaning %s, %.0f pts short of a signal | %d/%d TF %s",
                              (up?"long":"short"),gap,(up?g_up:g_dn),TF_COUNT,(up?"up":"down"));
      return;
   }

   //--- the checks
   const bool sigOK=(want>0 ? g_R[si].dir >0 : g_R[si].dir <0);
   const bool stkOK=(want>0 ? g_R[si].stkS>0 : g_R[si].stkS<0);
   const bool regOK=!g_R[si].ranging;
   const bool cfOK =(g_R[ci].ready && (want>0 ? g_R[ci].dir>0 : g_R[ci].dir<0));

   const int spread=(int)SymbolInfoInteger(_Symbol,SYMBOL_SPREAD);
   bool sprOK=true; string sprWhy="";
   if(InpMaxSpreadPoints>0 && spread>InpMaxSpreadPoints)
   { sprOK=false; sprWhy=StringFormat("spread %d pts over the %d cap",spread,InpMaxSpreadPoints); }
   if(sprOK && InpMaxSpreadATR>0)
   {
      const double a=AutoATR(), pt=m_symbol.Point();
      if(a>0 && pt>0 && spread*pt > InpMaxSpreadATR*a)
      { sprOK=false; sprWhy=StringFormat("spread is %.0f%% of ATR, cap %.0f%%",spread*pt/a*100.0,InpMaxSpreadATR*100.0); }
   }
   const bool fltOK=(!g_sessionBlock && !g_newsBlock && sprOK);

   int pass=0,total=0; string pros="",cons="";

   total++; if(sigOK){ pass++; VAdd(pros,g_tfName[si]+" "+g_R[si].label); }
            else VAdd(cons,g_tfName[si]+" "+g_R[si].label);

   total++; if(stkOK){ pass++; VAdd(pros,"stack"); }
            else VAdd(cons,"no stack");

   total++; if(regOK){ pass++; VAdd(pros,StringFormat("ADX %.0f",g_R[si].adx)); }
            else VAdd(cons,StringFormat("ranging ADX %.0f",g_R[si].adx));

   if(InpVerdictUseConfirm)
   {
      total++;
      if(cfOK){ pass++; VAdd(pros,g_tfName[ci]+" agrees"); }
      else VAdd(cons,g_tfName[ci]+" "+(g_R[ci].ready ? g_R[ci].label : "no data"));
   }

   total++; if(fltOK){ pass++; VAdd(pros,"clear"); }
            else VAdd(cons,(g_sessionBlock ? "session" : (g_newsBlock ? "news" : sprWhy)));

   VAdd(pros,StringFormat("%d/%d TF %s",(want>0?g_up:g_dn),TF_COUNT,(want>0?"up":"down")));

   const int miss=total-pass;
   g_V.pass=pass; g_V.total=total; g_V.pros=pros; g_V.cons=cons;
   g_V.grade=(miss==0 ? "A" : miss==1 ? "B" : miss==2 ? "C" : "-");
   g_V.dir  =(miss<=2 ? want : 0);

   if(g_V.dir!=0)
   {
      g_V.head=StringFormat("%s %s   grade %s   %d/%d checks   bias %.0f%%   %s",
                            (g_V.dir>0?"▲":"▼"),(g_V.dir>0?"BUY":"SELL"),
                            g_V.grade,pass,total,g_overallBuyPct,g_tfName[si]);

      const double slp=EffSLpts(), tpp=EffTPpts();
      const double pt=m_symbol.Point();
      const int    dg=m_symbol.Digits();
      const double px=SymbolInfoDouble(_Symbol,(g_V.dir>0?SYMBOL_ASK:SYMBOL_BID));
      const double sl=(g_V.dir>0 ? px-slp*pt : px+slp*pt);
      const double lot=(g_ui_riskMode ? RiskToLot(slp) : NormalizeLot(g_ui_lot));
      const double rm =lot*LossPerLot(slp);
      string tpTxt="trail";
      if(tpp>0)
      {
         const double tp=(g_V.dir>0 ? px+tpp*pt : px-tpp*pt);
         tpTxt=StringFormat("%.*f %.1fR",dg,tp,tpp/MathMax(1.0,slp));
      }
      g_V.levels=StringFormat("Entry %.*f  SL %.*f (%.0fp)  TP %s  %.2f lot / %.2f",
                              dg,px,dg,sl,slp,tpTxt,lot,rm);
   }
   else
   {
      g_V.head=StringFormat("WAIT   %s bias, but only %d of %d checks pass",
                            (want>0?"bullish":"bearish"),pass,total);
      g_V.levels=StringFormat("%d checks missing - the evidence is not lined up behind this one",miss);
   }
}

//+------------------------------------------------------------------+
//| EvaluateSetup — the single source of truth for "should the engine |
//| be in the market, and which way".                                 |
//|                                                                   |
//| PURE: it reads cached analysis and account state and writes       |
//| nothing. The panel calls it for display on every refresh; the     |
//| engine calls it once per signal bar to actually act. Because it   |
//| always fills `why`, a bot doing nothing can explain itself.       |
//+------------------------------------------------------------------+
bool EvaluateSetup(int &dir,string &why)
{
   dir=0;

   //--- v6.2: two states in which this copy may never trade, whatever the inputs say
   if(g_dupInstance){ why="DUPLICATE — another chart owns "+_Symbol+" with this magic; this copy scans only"; return false; }
   if(g_netting)    { why="blocked — netting account; the engine needs hedging (one position per fill)"; return false; }

   if(!InpAllowTrading){ why="auto OFF — InpAllowTrading is false"; return false; }
   if(!g_auto_on)      { why="auto OFF — press AUTO to arm the engine"; return false; }
   if(!(bool)TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)){ why="blocked — algo trading disabled in the terminal"; return false; }
   if(!(bool)MQLInfoInteger(MQL_TRADE_ALLOWED))          { why="blocked — trading not permitted for this EA"; return false; }
   if(!(bool)AccountInfoInteger(ACCOUNT_TRADE_EXPERT))   { why="blocked — EA trading disabled on this account"; return false; }

   //--- C1: checked before anything about the market, because no setup is
   //--- good enough to matter once the account has spent its drawdown.
   if(g_ddHalt)
   { why=StringFormat("HALTED — drawdown hit the %.2f%% limit (now %.2f%%); re-arm from the AUTO button or start once with InpResetState=true",
                      InpMaxDrawdownPct,CurrentDDPct()); return false; }

   const int si=SigIdx();
   if(!g_R[si].ready){ why="waiting — "+g_tfName[si]+" still loading history"; return false; }

   //--- v6.3/F2: nothing new goes into the weekend gap
   if(InpWeekendFlatten && WeekendWindow())
   { why=StringFormat("blocked — weekend window (Friday %02d:%02d cut-off): nothing is held into the gap",
                      InpFridayCutoffHour,InpFridayCutoffMin); return false; }

   //--- direction from the weighted aggregate
   int want=0;
   if(g_overallBuyPct>=InpAutoBuyPct)       want= 1;
   else if(g_overallBuyPct<=InpAutoSellPct) want=-1;
   else
   { why=StringFormat("no setup — bias %.0f%% sits inside the %.0f..%.0f%% dead band",
                      g_overallBuyPct,InpAutoSellPct,InpAutoBuyPct); return false; }

   const string side = (want>0 ? "LONG" : "SHORT");

   //--- A3: trend-following gates on the signal timeframe itself
   if(InpRequireSignalTFAgree && ((want>0 && g_R[si].dir<=0) || (want<0 && g_R[si].dir>=0)))
   { why=StringFormat("blocked %s — %s itself says %s",side,g_tfName[si],g_R[si].label); return false; }

   if(InpRequireStack && ((want>0 && g_R[si].stkS<=0) || (want<0 && g_R[si].stkS>=0)))
   { why=StringFormat("blocked %s — EMA stack on %s is not aligned",side,g_tfName[si]); return false; }

   //--- v6.5/H2: let a higher timeframe veto. Off by default, so this
   //--- changes nothing until you ask for it. The year of journal data
   //--- hinted at it (trades with D1 aligned returned +24.3R against
   //--- -10.9R for the rest) but that is one symbol and one year, so it
   //--- is offered as a switch rather than imposed as a default.
   if(InpRequireConfirmTF)
   {
      const int ci=ConfirmIdx();
      if(!g_R[ci].ready)
      { why=StringFormat("waiting — confirm TF %s has no data yet",g_tfName[ci]); return false; }
      if((want>0 && g_R[ci].dir<=0) || (want<0 && g_R[ci].dir>=0))
      { why=StringFormat("blocked %s — %s says %s",side,g_tfName[ci],g_R[ci].label); return false; }
   }

   if(InpSkipRanging && g_R[si].ranging)
   { why=StringFormat("blocked %s — %s ranging (ADX %.0f < %.0f)",side,g_tfName[si],g_R[si].adx,InpADXMin); return false; }

   if(InpRespectFilters && (g_sessionBlock||g_newsBlock))
   { why="blocked — filter: "+(g_sessionBlock?g_sessionMsg:g_newsMsg); return false; }

   const int spread=(int)SymbolInfoInteger(_Symbol,SYMBOL_SPREAD);
   if(InpMaxSpreadPoints>0 && spread>InpMaxSpreadPoints)
   { why=StringFormat("blocked — spread %d > %d pts",spread,InpMaxSpreadPoints); return false; }

   //--- B4: the points guard needs a number that is right for one symbol.
   //--- This one does not: on M1 the move being traded is small enough that
   //--- spread is a real share of it, and that share is what matters. A
   //--- widening spread blocks entries before the edge is eaten, on any
   //--- instrument, without anyone tuning a per-symbol constant.
   if(InpMaxSpreadATR>0)
   {
      const double atrSp=AutoATR(), ptSp=m_symbol.Point();
      if(atrSp>0 && ptSp>0)
      {
         const double spPrice=spread*ptSp;
         if(spPrice > InpMaxSpreadATR*atrSp)
         { why=StringFormat("blocked — spread %d pts is %.0f%% of ATR, cap is %.0f%%",
                            spread,spPrice/atrSp*100.0,InpMaxSpreadATR*100.0); return false; }
      }
   }

   //--- A6: risk governors. These stop NEW entries only.
   if(InpMaxTradesPerDay>0 && g_tradesToday>=InpMaxTradesPerDay)
   { why=StringFormat("blocked — daily trade cap reached (%d)",InpMaxTradesPerDay); return false; }

   if(InpDailyLossLimitPct>0 && DayPnLPct() <= -InpDailyLossLimitPct)
   { why=StringFormat("blocked — daily loss limit hit (%.2f%% of %.2f%%)",DayPnLPct(),-InpDailyLossLimitPct); return false; }

   int nBuy,nSell; AutoPosCounts(nBuy,nSell);
   if(nBuy+nSell >= InpMaxPositions)
   { why=StringFormat("holding — %d auto position(s), cap is %d",nBuy+nSell,InpMaxPositions); return false; }
   if(InpOnePerDirection && ((want>0 && nBuy>0) || (want<0 && nSell>0)))
   { why=StringFormat("holding — already %s and InpOnePerDirection is on",side); return false; }

   //--- B2: a second position has to be a second IDEA, not the same one
   //--- filled twice. Only checked when something is already open.
   if(nBuy+nSell > 0)
   {
      string sepWhy="";
      if(!AutoStackOK(want,sepWhy))
      { why=StringFormat("blocked %s — %s",side,sepWhy); return false; }
   }

   //--- B3: the per-trade risk % is a per-trade number. Five of them is
   //--- five times the risk, and nothing in v5.x said so out loud.
   if(InpMaxTotalRiskPct>0)
   {
      const double openRisk=OpenAutoRiskPct();
      const double wantRisk=MathMin(InpAutoRiskPct,InpMaxRiskPct);
      if(openRisk+wantRisk > InpMaxTotalRiskPct)
      { why=StringFormat("blocked %s — open risk %.2f%% + %.2f%% would pass the %.2f%% ceiling",
                         side,openRisk,wantRisk,InpMaxTotalRiskPct); return false; }
   }

   if(InpCooldownBars>0)
   {
      const int since=BarsSinceClose();
      if(since<InpCooldownBars)
      { why=StringFormat("cooldown — %d/%d %s bars since the last close",since,InpCooldownBars,g_tfName[si]); return false; }
   }

   //--- B5: pace the stack. Checked whether or not anything is open, so it
   //--- throttles re-entry after a close as well as building on top of a
   //--- live position — one gate, one meaning: no two entries closer
   //--- together than this many bars.
   if(InpMinBarsBetweenEntries>0)
   {
      const int sinceEntry=BarsSinceEntry();
      if(sinceEntry<InpMinBarsBetweenEntries)
      { why=StringFormat("pacing — %d/%d %s bars since the last entry",
                         sinceEntry,InpMinBarsBetweenEntries,g_tfName[si]); return false; }
   }

   if(AutoSLPts()<=0){ why="blocked — no ATR yet, stop distance unknown"; return false; }

   dir=want;
   why=StringFormat("SETUP %s — bias %.0f%%, %s %s, ADX %.0f, SL %.0f pts",
                    side,g_overallBuyPct,g_tfName[si],g_R[si].label,g_R[si].adx,AutoSLPts());
   return true;
}

//+------------------------------------------------------------------+
//| A2: entries happen at the open of a signal-TF bar, once.          |
//| Between bars the engine still evaluates — but only to keep the    |
//| panel's status line honest.                                       |
//+------------------------------------------------------------------+
void AutoEngine()
{
   RollDay();

   const datetime bt = iTime(_Symbol,SigTF(),0);
   const bool newBar = (bt!=0 && bt!=g_lastSigBar);

   //--- on a fresh bar, force the ensemble to re-read bar 1 (which is now
   //--- the bar that just closed) BEFORE deciding anything with it.
   if(newBar) AnalyzeAll();

   int dir=0; string why="";
   g_autoSetup = EvaluateSetup(dir,why);

   if(!newBar)
   {
      g_autoMsg = g_autoSetup
                  ? why+"  |  armed, acts at the next "+g_tfName[SigIdx()]+" open"
                  : why;
      return;
   }

   g_lastSigBar = bt;             // this bar is spent either way
   g_autoMsg    = why;
   if(!g_autoSetup) return;

   PlaceAuto(dir>0,why);
}

//+------------------------------------------------------------------+
//| A4/A5: stop management. Runs every tick on every position the     |
//| engine is allowed to touch.                                       |
//|                                                                   |
//| Order matters: reversal exits first (a closed position needs no   |
//| trail), then break-even, then the trail, and the best of the two  |
//| wins. Everything is finally filtered through the broker's         |
//| distance rules and the anti-spam step.                            |
//+------------------------------------------------------------------+
bool TrailTarget(bool isBuy,double openPrice,double bid,double ask,double &target)
{
   target=0;
   if(g_trailMode==TRAIL_OFF) return false;
   const double pt=m_symbol.Point();
   if(pt<=0) return false;

   if(g_trailMode==TRAIL_POINTS)
   {
      const double profitPts=(isBuy ? (bid-openPrice) : (openPrice-ask))/pt;
      if(profitPts < (double)InpTrailStartPts) return false;
      target = isBuy ? bid - InpTrailDistPts*pt : ask + InpTrailDistPts*pt;
      return true;
   }

   //--- ATR and CHANDELIER share the volatility gate
   const double atr=TrailATRVal();
   if(atr<=0) return false;
   const double profit=(isBuy ? (bid-openPrice) : (openPrice-ask));
   if(profit < InpTrailStartATR*atr) return false;

   if(g_trailMode==TRAIL_ATR)
   {
      target = isBuy ? bid - InpTrailATRMult*atr : ask + InpTrailATRMult*atr;
      return true;
   }

   //--- CHANDELIER: anchored to the swing extreme, not to the last tick,
   //--- so an ordinary pullback does not ratchet the stop upward with it.
   const ENUM_TIMEFRAMES tf=TrailTF();
   const int n=MathMax(1,InpChandelierBars);
   if(iBars(_Symbol,tf) < n+1) return false;
   if(isBuy)
   {
      const int h=iHighest(_Symbol,tf,MODE_HIGH,n,0);
      if(h<0) return false;
      target = iHigh(_Symbol,tf,h) - InpTrailATRMult*atr;
   }
   else
   {
      const int l=iLowest(_Symbol,tf,MODE_LOW,n,0);
      if(l<0) return false;
      target = iLow(_Symbol,tf,l) + InpTrailATRMult*atr;
   }
   return true;
}

//+------------------------------------------------------------------+
//| A10: has this position's stop been moved too recently?            |
//| Checked LAST, immediately before the request, and stamped only on |
//| success — so a rejected modify does not burn the position's slot. |
//+------------------------------------------------------------------+
bool TrailRateOK(ulong ticket)
{
   if(InpTrailMinSeconds<=0) return true;
   const datetime now=TimeCurrent();
   for(int i=0;i<TRAIL_SLOTS;i++)
      if(g_trailTicket[i]==ticket)
         return ((int)(now-g_trailWhen[i]) >= InpTrailMinSeconds);
   return true;                       // never modified -> always allowed
}
void TrailRateStamp(ulong ticket)
{
   const datetime now=TimeCurrent();
   int slot=-1, oldest=0;
   for(int i=0;i<TRAIL_SLOTS;i++)
   {
      if(g_trailTicket[i]==ticket){ g_trailWhen[i]=now; return; }
      if(g_trailTicket[i]==0 && slot<0) slot=i;
      if(g_trailWhen[i]<g_trailWhen[oldest]) oldest=i;
   }
   if(slot<0) slot=oldest;            // ring is full -> evict the stalest
   g_trailTicket[slot]=ticket;
   g_trailWhen[slot]=now;
}

//+------------------------------------------------------------------+
//| v6.4/G1: close and modify under the POSITION's own magic.         |
//|                                                                  |
//| CTrade stamps every request with its own m_magic, and SendEntry   |
//| leaves that set to MagicNumber (the manual one) when it is done.  |
//| So every close the ENGINE performed produced a deal tagged as a   |
//| manual trade: OnTradeTransaction's IsAutoPos test rejected it,    |
//| and the close never reached the journal, the realised W/L, the    |
//| day's P/L or the history rebuild. Server-triggered stops were     |
//| unaffected — those inherit the position's magic — which is why a  |
//| year of journal rows contained nothing but INIT_STOP and          |
//| TRAIL_STOP, and why seventeen weekend-flatten closes vanished.    |
//|                                                                  |
//| The magic is restored to MagicNumber afterwards, so the manual    |
//| ticket keeps behaving as it always did.                           |
//+------------------------------------------------------------------+
bool ClosePos(const ulong ticket,const long magic)
{
   m_trade.SetExpertMagicNumber((ulong)magic);
   const bool ok=m_trade.PositionClose(ticket);
   m_trade.SetExpertMagicNumber(MagicNumber);
   return ok;
}
bool ModifyPos(const ulong ticket,const double sl,const double tp,const long magic)
{
   m_trade.SetExpertMagicNumber((ulong)magic);
   const bool ok=m_trade.PositionModify(ticket,sl,tp);
   m_trade.SetExpertMagicNumber(MagicNumber);
   return ok;
}

void ManageStop(ulong ticket,bool isBuy,double openPrice,double curSL,double curTP,long magic)
{
   if(g_trailMode==TRAIL_OFF && !InpUseBreakEven) return;
   if(!m_symbol.RefreshRates()) return;

   const double pt=m_symbol.Point();
   const int    dg=m_symbol.Digits();
   const double bid=m_symbol.Bid(), ask=m_symbol.Ask();
   if(pt<=0 || bid<=0 || ask<=0) return;

   const double market   = isBuy ? bid : ask;     // the side the stop is measured from
   const double profitPts= (isBuy ? (bid-openPrice) : (openPrice-ask))/pt;

   double want=0; bool have=false;

   //--- break-even. Default trigger is the engine's own SL distance, i.e.
   //--- roughly 1R, expressed in points so it works in every trail mode.
   if(InpUseBreakEven)
   {
      double trig=(double)InpBE_TriggerPts;
      if(trig<=0) trig=AutoSLPts();
      if(trig<=0) trig=g_ui_slPts;
      if(trig>0 && profitPts>=trig)
      {
         want = isBuy ? openPrice + InpBE_LockPts*pt : openPrice - InpBE_LockPts*pt;
         have = true;
      }
   }

   //--- the trail may improve on break-even, never worsen it
   double tsl;
   if(TrailTarget(isBuy,openPrice,bid,ask,tsl))
   {
      if(!have || (isBuy ? tsl>want : tsl<want)) { want=tsl; have=true; }
   }
   if(!have) return;

   //--- A4: a stop may only ever ratchet in the position's favour
   if(curSL>0 && (isBuy ? want<=curSL : want>=curSL)) return;

   //--- broker minimum distance from market
   const long   stopsLvl=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL);
   const double minD=(double)stopsLvl*pt;
   if(isBuy) want=MathMin(want,bid-minD); else want=MathMax(want,ask+minD);
   if(isBuy ? (want>=bid) : (want<=ask)) return;
   if(curSL>0 && (isBuy ? want<=curSL : want>=curSL)) return;   // the clamp undid the gain

   //--- A10: anti-spam, gate one — minimum improvement. A points-only
   //--- threshold is meaningless across instruments (10 points is ten
   //--- cents on gold and one pip on EURUSD), so the ATR-scaled figure
   //--- runs alongside it and the LARGER of the two applies. The step
   //--- gates IMPROVEMENTS only: a position that somehow has no stop at
   //--- all still gets one immediately, however small the move.
   double step=MathMax(0.0,(double)InpTrailStepPts)*pt;
   if(InpTrailStepATR>0)
   {
      const double stepATR=TrailATRVal();
      if(stepATR>0) step=MathMax(step, InpTrailStepATR*stepATR);
   }
   if(curSL>0 && MathAbs(want-curSL)<step) return;

   //--- freeze level: the server refuses modifies too close to market
   const long frz=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL);
   if(frz>0)
   {
      const double fd=(double)frz*pt;
      if(curSL>0 && MathAbs(market-curSL)<fd) return;
      if(curTP>0 && MathAbs(market-curTP)<fd) return;
   }

   want=NormalizeDouble(want,dg);
   if(curSL>0 && MathAbs(want-curSL)<pt/2.0) return;

   //--- A10: anti-spam, gate two. The step above can still burst when
   //--- price runs; a clock cannot. Checked last so it only ever blocks
   //--- requests that were otherwise about to be sent.
   if(!TrailRateOK(ticket)) return;

   if(ModifyPos(ticket,want,curTP,magic))
   {
      TrailRateStamp(ticket);
      g_lastAction=StringFormat("trail %s #%I64u SL -> %.*f",TrailModeName(g_trailMode),ticket,dg,want);
   }
   else
   {
      PrintFormat("trail modify failed on #%I64u: %d — %s",
                  ticket,m_trade.ResultRetcode(),m_trade.ResultRetcodeDescription());
   }
}

//--- A3: the aggregate has flipped past the OPPOSITE threshold, not
//--- merely drifted off the entry threshold. One number, two gates,
//--- so a position is not knocked out by a single neutral reading.
bool ReversedAgainst(bool isBuy)
{
   return isBuy ? (g_overallBuyPct<=InpAutoSellPct) : (g_overallBuyPct>=InpAutoBuyPct);
}

void ManagePositions()
{
   if(!InpAllowTrading) return;

   int autoCount=0;
   bool closedSomething=false;

   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      if(!m_position.SelectByIndex(i)) continue;
      if(m_position.Symbol()!=_Symbol) continue;
      const long mg=m_position.Magic();
      if(!IsOurs(mg)) continue;

      const bool   isAuto = IsAutoPos(mg);
      const bool   isBuy  = (m_position.PositionType()==POSITION_TYPE_BUY);
      const ulong  ticket = m_position.Ticket();
      const double open   = m_position.PriceOpen();
      const double sl     = m_position.StopLoss();
      const double tp     = m_position.TakeProfit();

      if(isAuto) autoCount++;

      //--- reversal exit belongs to the engine alone; a position you
      //--- placed by hand is yours to close.
      if(isAuto && InpExitOnReversal && ReversedAgainst(isBuy))
      {
         g_closeTag="reversal";                       // v6.3/F3: named in the journal's exit_kind
         if(ClosePos(ticket,mg))
         {
            autoCount--;
            closedSomething=true;
            g_lastAction=StringFormat("auto EXIT #%I64u — bias reversed to %.0f%%",ticket,g_overallBuyPct);
            Print(g_lastAction);
         }
         continue;
      }

      //--- v6.2/E3: the tick net. An auto position with no stop gets one from
      //--- its initial distance; if that keeps failing past the grace period
      //--- it is closed. Unknown risk is not absent risk.
      if(isAuto && sl<=0)
      {
         StoplessNet(ticket,(ulong)m_position.Identifier(),isBuy,open,tp,(datetime)m_position.Time());
         continue;
      }

      if(!isAuto && !InpTrailManagesManual) continue;
      ManageStop(ticket,isBuy,open,sl,tp,mg);
   }

   //--- A9: any drop in the auto count (SL, TP, reversal, manual close)
   //--- arms the cooldown from the current signal bar.
   if(closedSomething || autoCount<g_prevAutoCount)
      g_lastCloseBar=iTime(_Symbol,SigTF(),0);
   g_prevAutoCount=autoCount;
}

void RunEngine()
{
   if(g_dupInstance){ AutoEngine(); return; }   // v6.2/E1: a duplicate scans and explains itself, nothing more
   UpdateDrawdown();    // C1: the governor sees every tick, before anything trades
   WeekendFlattenCheck(); // v6.3/F2: nothing of the engine's is held into the weekend gap
   Journal_TrackAll();  // v6.1/D1: MFE / MAE see this tick before any exit removes the position
   Trader_TrackAll();   // v6.6: the same, for the positions YOU placed
   ManagePositions();   // exits and stops first — they free capacity
   AutoEngine();        // then, at most once per signal bar, entries
}

//+------------------------------------------------------------------+
//| Trade + sizing helpers                                           |
//+------------------------------------------------------------------+
double EffSLpts(){ return (g_ui_slPts>0?g_ui_slPts:100); }
double EffTPpts(){ return (g_ui_tpPts>0?g_ui_tpPts:0);   }

//+------------------------------------------------------------------+
//| One order path for both engines. Everything either of them can    |
//| get wrong — spread, stop distance, lot bounds, margin — is        |
//| checked in exactly one place.                                     |
//+------------------------------------------------------------------+
bool SendEntry(bool isBuy,double slPts,double tpPts,double lot,ulong magic,string cmt,string &msg)
{
   if(!InpAllowTrading){ msg="trading OFF (InpAllowTrading=false)"; return false; }
   if(!m_symbol.RefreshRates()){ msg="no quotes"; return false; }

   const int spread=(int)SymbolInfoInteger(_Symbol,SYMBOL_SPREAD);
   if(InpMaxSpreadPoints>0 && spread>InpMaxSpreadPoints)
   { msg=StringFormat("blocked: spread %d>%d",spread,InpMaxSpreadPoints); return false; }

   const double point=m_symbol.Point();
   //--- B1: the same floor AutoSLPts already applied. For an auto entry
   //--- this is now a no-op, which is the point — the lot was sized
   //--- against exactly the stop that is about to be sent. Manual tickets
   //--- still get widened here, and still size from the panel's own value.
   const double minPts=MinStopPoints();

   if(slPts<minPts) slPts=minPts;
   if(tpPts>0 && tpPts<minPts) tpPts=minPts;

   const double price=isBuy?m_symbol.Ask():m_symbol.Bid();
   if(price<=0){ msg="bad price"; return false; }

   const double sl=NormalizeDouble(isBuy?price-slPts*point:price+slPts*point,m_symbol.Digits());
   const double tp=(tpPts>0)?NormalizeDouble(isBuy?price+tpPts*point:price-tpPts*point,m_symbol.Digits()):0.0;
   if(lot<=0){ msg="lot=0"; return false; }

   double margin=0;
   if(!OrderCalcMargin(isBuy?ORDER_TYPE_BUY:ORDER_TYPE_SELL,_Symbol,lot,price,margin) ||
      AccountInfoDouble(ACCOUNT_MARGIN_FREE)<=margin*1.5)
   { msg="insufficient margin"; return false; }

   m_trade.SetExpertMagicNumber(magic);
   const bool ok=isBuy?m_trade.Buy(lot,_Symbol,price,sl,tp,cmt):m_trade.Sell(lot,_Symbol,price,sl,tp,cmt);
   m_trade.SetExpertMagicNumber(MagicNumber);          // back to the manual default

   if(ok)
   {
      //--- v6.2: snapshot the fill before anything else can touch m_trade's result
      g_lastFillPosId =Journal_ResolvePosId();
      g_lastFillPrice =m_trade.ResultPrice();
      g_lastFillVolume=m_trade.ResultVolume();
      msg=StringFormat("%s %.2f @ %.*f",isBuy?"BOUGHT":"SOLD",lot,m_symbol.Digits(),price);
      Print("OK ",msg," | SL ",DoubleToString(sl,m_symbol.Digits()),
            " | TP ",(tp>0?DoubleToString(tp,m_symbol.Digits()):"none"),
            " | magic ",magic," | ",cmt);
      VerifyFillStop(isBuy,sl,tp,magic);              // v6.2/E3: trust, then verify
   }
   else
   {
      msg=StringFormat("FAILED %d",m_trade.ResultRetcode());
      Print("order failed: ",m_trade.ResultRetcode()," — ",m_trade.ResultRetcodeDescription());
   }
   return ok;
}

//+------------------------------------------------------------------+
//| v6.2/E2: the engine needs a hedging account. Evaluated once the   |
//| account is actually known: before the first connection every     |
//| AccountInfo integer reads 0, and 0 happens to be the NETTING     |
//| value, so a check at the instant of init would disarm everyone   |
//| who starts the terminal with the EA already on a chart.          |
//+------------------------------------------------------------------+
void CheckMarginMode()
{
   if(g_marginChecked) return;
   if(AccountInfoInteger(ACCOUNT_LOGIN)==0) return;          // no account data yet
   g_marginChecked=true;
   const long mm=AccountInfoInteger(ACCOUNT_MARGIN_MODE);
   g_netting=(mm!=ACCOUNT_MARGIN_MODE_RETAIL_HEDGING);
   if(!g_netting) return;
   g_auto_on=false;
   g_autoMsg="auto OFF — netting account (the engine needs hedging)";
   PrintFormat("WARNING: account margin mode is %s. The auto engine assumes one position per fill (stacking, per-ticket R, reversal exit) and will NOT arm on this account; the scanner and the manual ticket still work.",
               EnumToString((ENUM_ACCOUNT_MARGIN_MODE)mm));
}

//--- the live position that carries this identifier, if it is still open
bool FindPosByIdent(const ulong pid,ulong &ticket,double &sl,double &tp,bool &isBuy)
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      if(!m_position.SelectByIndex(i)) continue;
      if((ulong)m_position.Identifier()!=pid) continue;
      ticket=m_position.Ticket(); sl=m_position.StopLoss(); tp=m_position.TakeProfit();
      isBuy=(m_position.PositionType()==POSITION_TYPE_BUY);
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| v6.2/E3: put a stop on a position that has none.                  |
//|                                                                  |
//| wantSL is where the stop SHOULD be. Three outcomes:              |
//|   - price is already through it: that is the stop firing late,  |
//|     not a missing stop, so the position is closed at market;    |
//|   - it sits inside the broker's minimum distance: pushed out to |
//|     the nearest allowed price, which is still a stop;            |
//|   - otherwise it is sent as is.                                  |
//| Returns true when the position ends up protected or closed.      |
//+------------------------------------------------------------------+
bool EnsureStop(const ulong ticket,const bool isBuy,double wantSL,const double curTP,const string why,const long magic)
{
   if(!m_symbol.RefreshRates()) return false;
   const double pt=m_symbol.Point(); const int dg=m_symbol.Digits();
   const double bid=m_symbol.Bid(), ask=m_symbol.Ask();
   if(pt<=0 || bid<=0 || ask<=0 || wantSL<=0) return false;
   const datetime now=TimeCurrent();
   const bool     mayLog=((long)(now-g_netLastLog)>=10);

   //--- already through it: the stop-out that should have happened
   if(isBuy ? (bid<=wantSL) : (ask>=wantSL))
   {
      g_closeTag="stop guard: past stop";
      if(ClosePos(ticket,magic))
      { PrintFormat("STOP GUARD (%s): #%I64u had no stop and price is already past %.*f - closed at market",why,ticket,dg,wantSL); return true; }
      if(mayLog){ PrintFormat("STOP GUARD (%s): #%I64u is past its stop and the close FAILED: %d %s",why,ticket,m_trade.ResultRetcode(),m_trade.ResultRetcodeDescription()); g_netLastLog=now; }
      return false;
   }

   //--- inside the broker's minimum distance: as close as allowed, but on
   const double minD=(double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)*pt;
   if(isBuy){ if(wantSL>bid-minD) wantSL=bid-minD; }
   else     { if(wantSL<ask+minD) wantSL=ask+minD; }
   wantSL=NormalizeDouble(wantSL,dg);

   if(ModifyPos(ticket,wantSL,curTP,magic))
   { PrintFormat("STOP GUARD (%s): #%I64u had no stop - set to %.*f",why,ticket,dg,wantSL); return true; }
   if(mayLog){ PrintFormat("STOP GUARD (%s): #%I64u still has no stop - modify failed: %d %s",why,ticket,m_trade.ResultRetcode(),m_trade.ResultRetcodeDescription()); g_netLastLog=now; }
   return false;
}

//--- right after a fill: did the position come back with the stop we sent?
void VerifyFillStop(const bool isBuy,const double sl,const double tp,const ulong magic)
{
   if(sl<=0) return;
   if(g_lastFillPosId==0){ Print("STOP GUARD: fill accepted but the position id is not known yet - the tick net will check it"); return; }
   ulong ticket=0; double haveSL=0, haveTP=0; bool side=isBuy;
   if(!FindPosByIdent(g_lastFillPosId,ticket,haveSL,haveTP,side)){ Print("STOP GUARD: position not visible yet after the fill - the tick net will check it"); return; }
   if(haveSL>0) return;                                       // the normal case
   PrintFormat("STOP GUARD: the server accepted the %s order but position #%I64u carries NO STOP (requested %.*f)",
               (IsAutoPos((long)magic) ? "auto" : "manual"),ticket,m_symbol.Digits(),sl);
   EnsureStop(ticket,side,sl,(haveTP>0 ? haveTP : tp),"post-fill",(long)magic);
}

//--- every tick, for an auto position found with no stop
void StoplessNet(const ulong ticket,const ulong pid,const bool isBuy,const double open,const double tp,const datetime opened)
{
   const datetime now=TimeCurrent();
   if(now==g_netLastTry) return;                              // one request per second across the net
   g_netLastTry=now;

   //--- the INITIAL distance: the journal tracker keeps it, and recovers it
   //--- from the opening order after a restart
   const double pt=m_symbol.Point();
   double slPts=0;
   const int k=Journal_Find(pid);
   if(k>=0) slPts=g_trk[k].slPts;
   if(slPts<=0) slPts=AutoSLPts();
   if(slPts<=0 || pt<=0) return;                              // no ATR yet: nothing sensible to send
   const double want=(isBuy ? open-slPts*pt : open+slPts*pt);
   if(EnsureStop(ticket,isBuy,want,tp,"tick net",(long)InpAutoMagic)) return;

   if(InpNoStopAction!=NOSTOP_CLOSE) return;
   if((long)(now-opened)<InpNoStopGraceSec) return;
   g_closeTag="stop guard: no stop";
   if(ClosePos(ticket,(long)InpAutoMagic))
      PrintFormat("STOP GUARD: #%I64u could not be given a stop within %d s - CLOSED (InpNoStopAction=CLOSE)",ticket,InpNoStopGraceSec);
   else
      PrintFormat("STOP GUARD: #%I64u has no stop and the close failed too: %d %s",ticket,m_trade.ResultRetcode(),m_trade.ResultRetcodeDescription());
}

void PlaceManual(bool isBuy)
{
   const double slPts=EffSLpts(), tpPts=EffTPpts();
   const double lot=g_ui_riskMode?RiskToLot(slPts):NormalizeLot(g_ui_lot);
   string msg;
   SendEntry(isBuy,slPts,tpPts,lot,MagicNumber,isBuy?"AstroBot:MANUAL-BUY":"AstroBot:MANUAL-SELL",msg);
   g_lastAction=msg;
}

//+------------------------------------------------------------------+
//| The auto entry. Note what it does NOT read: g_ui_lot, g_ui_risk,  |
//| g_ui_slPts, g_ui_tpPts. The panel cannot change how the engine    |
//| sizes or stops a trade — only the inputs can.                     |
//+------------------------------------------------------------------+
void PlaceAuto(bool isBuy,const string why)
{
   const double slPts=AutoSLPts();
   if(slPts<=0){ g_autoMsg="entry skipped — no ATR for the stop"; return; }
   const double tpPts=(InpAutoTP_RR>0 ? MathRound(slPts*InpAutoTP_RR) : 0.0);

   const double lot = InpAutoUseRiskPct
                      ? RiskToLotPct(slPts,MathMin(InpAutoRiskPct,InpMaxRiskPct))
                      : NormalizeLot(InpAutoFixedLot);
   if(lot<=0){ g_autoMsg="entry skipped — computed lot is below the broker minimum"; return; }

   //--- v6.1/D1: what the book looked like BEFORE this entry, for the journal
   int nb0,ns0; AutoPosCounts(nb0,ns0);
   const double openRisk0=OpenAutoRiskPct();

   string msg;
   const bool ok=SendEntry(isBuy,slPts,tpPts,lot,InpAutoMagic,
                           isBuy?"AstroBot:AUTO-BUY":"AstroBot:AUTO-SELL",msg);
   if(ok)
   {
      g_tradesToday++;
      g_lastEntryBar=iTime(_Symbol,SigTF(),0);      // B5: start the pacing clock
      Journal_OnEntry(isBuy,lot,slPts,tpPts,why,nb0+ns0,openRisk0);   // v6.1/D1: ENTRY row + MFE/MAE tracker
      g_lastAction=StringFormat("AUTO %s",msg);
      g_autoMsg=StringFormat("ENTERED %s — %s | SL %.0f pts, TP %s, trail %s",
                             isBuy?"LONG":"SHORT",msg,slPts,
                             tpPts>0?StringFormat("%.0f pts",tpPts):"none",
                             TrailModeName(g_trailMode));
   }
   else
   {
      g_lastAction="AUTO "+msg;
      g_autoMsg="entry rejected — "+msg;
   }
}

void CloseAll(string reason)
{
   g_closeTag=reason;                                  // v6.3/F3
   int n=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      const ulong t=PositionGetTicket(i);
      if(t==0) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      const long mg=PositionGetInteger(POSITION_MAGIC);
      if(!IsOurs(mg)) continue;
      if(ClosePos(t,mg)) n++;
   }
   g_lastAction=StringFormat("closed %d position(s)",n);
   Print("Close-all: ",n," | ",reason);
}

//--- A1: flattens the engine's book only, leaving manual trades alone.
void CloseAuto(string reason)
{
   g_closeTag=reason;                                  // v6.3/F3
   int n=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      const ulong t=PositionGetTicket(i);
      if(t==0) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      if(!IsAutoPos(PositionGetInteger(POSITION_MAGIC))) continue;
      if(ClosePos(t,(long)InpAutoMagic)) n++;
   }
   if(n>0) g_lastCloseBar=iTime(_Symbol,SigTF(),0);
   g_lastAction=StringFormat("closed %d auto position(s)",n);
   Print("Close-auto: ",n," | ",reason);
}

double LossPerLot(double slPts)
{
   const double tv=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   const double ts=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(tv<=0||ts<=0||slPts<=0) return 0;
   return slPts*m_symbol.Point()/ts*tv;
}
double RiskToLotPct(double slPts,double pct)
{
   const double lpl=LossPerLot(slPts);
   if(lpl<=0) return 0;
   const double riskMoney=AccountInfoDouble(ACCOUNT_EQUITY)*MathMax(0.0,MathMin(pct,InpMaxRiskPct))/100.0;
   return NormalizeLot(riskMoney/lpl);
}
double RiskToLot(double slPts){ return RiskToLotPct(slPts,g_ui_risk); }

double NormalizeLot(double lot)
{
   const double vmin=m_symbol.LotsMin(),vmax=m_symbol.LotsMax(),vstep=m_symbol.LotsStep();
   lot=MathMax(vmin,MathMin(vmax,lot));
   if(vstep>0) lot=MathFloor(lot/vstep)*vstep;
   if(lot<vmin) return 0.0;
   return NormalizeDouble(lot,8);
}
void PosCounts(int &buys,int &sells)
{
   buys=0; sells=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      if(!m_position.SelectByIndex(i)) continue;
      if(m_position.Symbol()!=_Symbol||!IsOurs(m_position.Magic())) continue;
      if(m_position.PositionType()==POSITION_TYPE_BUY) buys++; else sells++;
   }
}
double FloatingPL()
{
   double pl=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      if(!m_position.SelectByIndex(i)) continue;
      if(m_position.Symbol()!=_Symbol||!IsOurs(m_position.Magic())) continue;
      pl+=m_position.Profit()+m_position.Swap()+m_position.Commission();
   }
   return pl;
}
string TfName(ENUM_TIMEFRAMES tf)
{
   if(tf==PERIOD_CURRENT) tf=(ENUM_TIMEFRAMES)_Period;   // PERIOD_CURRENT==0
   const string s=EnumToString(tf);
   return StringSubstr(s,7);
}
int CurrentTFIndex()
{
   for(int i=0;i<TF_COUNT;i++) if(g_tf[i]==(ENUM_TIMEFRAMES)_Period) return i;
   return -1;
}
color DirColor(int dir){ if(dir>0) return C_BULL; if(dir<0) return C_BEAR; return C_DIM; }

void SetBestFillingMode()
{
   const long fm=SymbolInfoInteger(_Symbol,SYMBOL_FILLING_MODE);
   if((fm&SYMBOL_FILLING_FOK)!=0)      m_trade.SetTypeFilling(ORDER_FILLING_FOK);
   else if((fm&SYMBOL_FILLING_IOC)!=0) m_trade.SetTypeFilling(ORDER_FILLING_IOC);
   else                                 m_trade.SetTypeFilling(ORDER_FILLING_RETURN);
}

//+------------------------------------------------------------------+
//| v6.1/D3: tester hooks. The work lives in AB_Tester.mqh.           |
//| OnTester runs at the end of every test and optimisation pass;     |
//| the other three run only in the terminal, only during an          |
//| optimisation, in the frame-collecting copy of the EA.             |
//+------------------------------------------------------------------+
double OnTester()       { return Tester_Score(); }
void   OnTesterInit()   { Tester_FramesInit(); }
void   OnTesterPass()   { Tester_FramesPass(); }
void   OnTesterDeinit() { Tester_FramesDeinit(); }
//+------------------------------------------------------------------+
