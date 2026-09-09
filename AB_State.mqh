//+------------------------------------------------------------------+
//|                                                     AB_State.mqh |
//|                       AstroBot MTF Scanner - v6.1 / D2 STATE     |
//|                                                                  |
//| What survives a restart, and how.                                 |
//|                                                                  |
//| Before v6.1 every number the risk governors depend on lived in    |
//| RAM: the equity and balance peaks, the drawdown HALT latch, the   |
//| day's anchor equity and the day's counters. A recompile, a chart  |
//| change or a terminal restart zeroed all of them - so a restart    |
//| silently forgave whatever drawdown had already been taken, and    |
//| re-armed an engine that had halted for a reason.                  |
//|                                                                  |
//| Two stores, chosen by what each fact IS:                          |
//|                                                                  |
//|   TERMINAL GLOBAL VARIABLES hold the facts that exist nowhere     |
//|   else: both peaks, the HALT latch, the day stamp and the equity  |
//|   at the start of that day. They are written whenever one of them |
//|   changes (throttled to the one-second timer for the peaks, at    |
//|   once for a HALT or a day roll) and read back at init. Keyed by  |
//|   symbol and the auto magic, so two charts do not share a peak.   |
//|                                                                  |
//|   THE DEAL HISTORY is the source for everything it already knows  |
//|   better than we do: today's entry count, wins, losses and        |
//|   realised P/L, and the timestamps of the last auto entry and     |
//|   last auto close that anchor pacing and cooldown. Rebuilt from   |
//|   the broker's record at init, so deals made while the EA was     |
//|   not running are counted, and nothing can drift.                 |
//|                                                                  |
//| WHAT THIS CHANGES ABOUT RE-ARMING. The C1 header said re-arming a |
//| halted engine "is a restart". It no longer is - the latch comes   |
//| back with the peaks. Re-arming is now one of two deliberate acts: |
//| the panel's AUTO button, which reads HALTED: RE-ARM while the     |
//| latch is set, or one start with InpResetState=true. Both reset    |
//| the peaks to the account as it stands, so the budget begins again |
//| from there rather than from a high-water mark that has already    |
//| been spent.                                                       |
//|                                                                  |
//| NOT PERSISTED, ON PURPOSE: the armed/disarmed toggle and the      |
//| trail-mode button. Those are seeded from the inputs on every      |
//| start, exactly as before, so a preset always means what it says.  |
//|                                                                  |
//| THE TESTER never loads or saves. Every pass has to start from     |
//| nothing, or pass N would inherit pass N-1's peak.                 |
//|                                                                  |
//| WITHDRAWALS: a withdrawal lowers the balance without lowering the |
//| stored peak, so it reads as drawdown. That is exactly what the    |
//| governor would have seen without a restart in between; if it is  |
//| not what you mean, start once with InpResetState=true.            |
//+------------------------------------------------------------------+

bool   g_stateReady  = false;   // State_Load has run; before that a save would overwrite the store with fresh seeds
bool   g_stateDirty  = false;   // a peak moved since the last write
string g_statePrefix = "";      // "AB_<symbol>_<magic>_"
bool   g_dupInstance = false;   // v6.2/E1: this copy is a scanner-only duplicate of another chart (see the guard section below)
#define AB_HEARTBEAT_STALE 10   // v6.2/E1: seconds without a heartbeat before an owner is presumed gone

string State_Key(const string k) { return g_statePrefix + k; }

void State_Init()
{
   //--- global variable names are capped at 63 characters; symbol + magic + key fits
   g_statePrefix = StringFormat("AB_%s_%I64u_", _Symbol, InpAutoMagic);
}

//--- persistence is a live-account concern; the tester must stay stateless
bool State_Enabled()
{
   if(!InpPersistState) return false;
   if((bool)MQLInfoInteger(MQL_TESTER)) return false;
   return true;
}

//+------------------------------------------------------------------+
//| Load. Called from OnInit AFTER the fresh seeds and AFTER RollDay, |
//| so a stored value can overrule a seed but a missing one leaves    |
//| the seed standing.                                                |
//+------------------------------------------------------------------+
void State_Load()
{
   State_Init();

   if(!State_Enabled())
   {
      g_stateReady = true;                 // saves stay no-ops through State_Enabled
      return;
   }

   if(InpResetState)
   {
      const int n = GlobalVariablesDeleteAll(g_statePrefix);
      PrintFormat("STATE: InpResetState=true - wiped %d stored value(s) for %s / %I64u. Peaks and the HALT latch restart from the account as it stands. Set InpResetState back to false, or every start will do this.",
                  n, _Symbol, InpAutoMagic);
      g_stateReady = true;
      State_Save(true);
      return;
   }

   if(!GlobalVariableCheck(State_Key("balPeak")) || GlobalVariableGet(State_Key("balPeak"))<=0)
   {
      Print("STATE: nothing stored for this symbol/magic yet - persisting from here on");
      g_stateReady = true;
      State_Save(true);
      return;
   }

   const double   eqPeak  = GlobalVariableGet(State_Key("eqPeak"));
   const double   balPeak = GlobalVariableGet(State_Key("balPeak"));
   const bool     halt    = (GlobalVariableGet(State_Key("ddHalt")) > 0.5);
   const datetime day     = (datetime)(long)GlobalVariableGet(State_Key("dayStamp"));
   const double   dayEq   = GlobalVariableGet(State_Key("dayStartEq"));
   const datetime savedAt = (datetime)(long)GlobalVariableGet(State_Key("savedAt"));

   //--- a stored peak can only RAISE ours. If the account grew while the EA
   //--- was off, the live figure is higher and UpdateDrawdown adopts it on
   //--- the first tick anyway; if it shrank, the stored peak is the one the
   //--- drawdown has to be measured from.
   if(eqPeak  > g_eqPeak)  g_eqPeak  = eqPeak;
   if(balPeak > g_balPeak) g_balPeak = balPeak;
   g_ddHalt = halt;

   //--- the day anchor only if the stored stamp IS today; otherwise RollDay's
   //--- fresh values are right and the store is about to be overwritten
   const bool sameDay = (day == g_dayStamp);
   if(sameDay && dayEq > 0) g_dayStartEq = dayEq;

   g_stateReady = true;
   PrintFormat("STATE: restored (saved %s) - balance peak %.2f, equity peak %.2f, HALT %s, day-start equity %.2f (%s)",
               TimeToString(savedAt, TIME_DATE|TIME_MINUTES), g_balPeak, g_eqPeak,
               (halt ? "LATCHED" : "clear"), g_dayStartEq,
               (sameDay ? "same server day" : "new server day"));
   if(halt)
      Print("STATE: the drawdown HALT is still latched from before the restart. Re-arm from the panel (AUTO button) or start once with InpResetState=true.");
   State_Save(true);
}

//+------------------------------------------------------------------+
//| Save. `hard` makes the terminal flush to disk now; the once-a-    |
//| second path leaves that to the terminal's own schedule.           |
//+------------------------------------------------------------------+
void State_Save(const bool hard)
{
   if(!g_stateReady || !State_Enabled() || g_dupInstance) return;   // a duplicate never writes the owner's store
   //--- no account data yet (started offline, or between reconnects): both
   //--- peaks are still their zero seeds, and a zero is not a fact worth
   //--- storing. The first valid tick raises them, and the timer saves then.
   if(g_eqPeak<=0 && g_balPeak<=0) return;
   GlobalVariableSet(State_Key("eqPeak"),     g_eqPeak);
   GlobalVariableSet(State_Key("balPeak"),    g_balPeak);
   GlobalVariableSet(State_Key("ddHalt"),     (g_ddHalt ? 1.0 : 0.0));
   GlobalVariableSet(State_Key("dayStamp"),   (double)(long)g_dayStamp);
   GlobalVariableSet(State_Key("dayStartEq"), g_dayStartEq);
   GlobalVariableSet(State_Key("savedAt"),    (double)(long)TimeCurrent());
   g_stateDirty = false;
   if(hard) GlobalVariablesFlush();
}

void State_Touch() { g_stateDirty = true; }
void State_Flush() { if(g_stateDirty) State_Save(false); }

//+------------------------------------------------------------------+
//| Re-arm: clear the HALT latch by hand and start the budget over.   |
//+------------------------------------------------------------------+
void State_ReArm(const string who)
{
   const double eq  = AccountInfoDouble(ACCOUNT_EQUITY);
   const double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   PrintFormat("RE-ARM (%s): drawdown HALT cleared by hand at %.2f%%. Peaks reset to equity %.2f / balance %.2f - the %.2f%% budget starts over from here.",
               who, CurrentDDPct(), eq, bal, InpMaxDrawdownPct);
   g_ddHalt  = false;
   g_eqPeak  = eq;
   g_balPeak = bal;
   State_Save(true);
}

//+------------------------------------------------------------------+
//| Rebuild from the deal history what the history knows best.        |
//|                                                                  |
//| Today's counters, and the two anchors: the signal-TF bar holding  |
//| the last auto ENTRY (pacing) and the last auto CLOSE (cooldown).  |
//| v6.0 seeded the entry anchor from open positions only, so a       |
//| position that had already closed left no trace, and the close     |
//| anchor started at zero on every restart - a restart was a way to  |
//| skip a cooldown.                                                  |
//+------------------------------------------------------------------+
void State_RebuildFromHistory()
{
   const datetime now  = TimeCurrent();
   const datetime from = now - 40*86400;   // bounds the scan; an anchor older than this is irrelevant to any bar count
   if(!HistorySelect(from, now + 86400))
   {
      Print("STATE: HistorySelect failed - today's counters start at zero");
      return;
   }

   int      entries=0, wins=0, losses=0;
   double   realised=0;
   datetime lastIn=0, lastOut=0;
   const int total = HistoryDealsTotal();
   for(int i=0;i<total;i++)
   {
      const ulong d = HistoryDealGetTicket(i);
      if(d==0) continue;
      if(HistoryDealGetString(d, DEAL_SYMBOL) != _Symbol) continue;
      if(!IsAutoPos(HistoryDealGetInteger(d, DEAL_MAGIC))) continue;

      const long     entry = HistoryDealGetInteger(d, DEAL_ENTRY);
      const datetime t     = (datetime)HistoryDealGetInteger(d, DEAL_TIME);
      if(entry == DEAL_ENTRY_IN)
      {
         if(t > lastIn) lastIn = t;
         if(t >= g_dayStamp) entries++;
      }
      else if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY)
      {
         if(t > lastOut) lastOut = t;
         if(t >= g_dayStamp)
         {
            const double pl = HistoryDealGetDouble(d, DEAL_PROFIT)
                            + HistoryDealGetDouble(d, DEAL_SWAP)
                            + HistoryDealGetDouble(d, DEAL_COMMISSION);
            realised += pl;
            if(pl >= 0) wins++; else losses++;
         }
      }
   }

   g_tradesToday  = entries;
   g_autoWins     = wins;
   g_autoLosses   = losses;
   g_autoRealized = realised;

   //--- anchors are bar OPEN times on the signal TF, which is what
   //--- BarsSinceClose / BarsSinceEntry count from
   if(lastOut > 0)
   {
      const int sh = iBarShift(_Symbol, SigTF(), lastOut, false);
      if(sh >= 0) g_lastCloseBar = iTime(_Symbol, SigTF(), sh);
   }
   if(lastIn > 0)
   {
      const int sh = iBarShift(_Symbol, SigTF(), lastIn, false);
      if(sh >= 0)
      {
         const datetime b = iTime(_Symbol, SigTF(), sh);
         if(b > g_lastEntryBar) g_lastEntryBar = b;
      }
   }

   PrintFormat("STATE: today from history - %d auto entr%s, %dW/%dL, realised %+.2f | last auto entry %s, last auto close %s",
               entries, (entries==1 ? "y" : "ies"), wins, losses, realised,
               (lastIn >0 ? TimeToString(lastIn,  TIME_DATE|TIME_MINUTES) : "none"),
               (lastOut>0 ? TimeToString(lastOut, TIME_DATE|TIME_MINUTES) : "none"));
}

//+------------------------------------------------------------------+
//| v6.2 / E1: one engine per symbol and magic.                       |
//|                                                                  |
//| Two charts running this EA on the same symbol with the same      |
//| InpAutoMagic are not two engines, they are one engine with a     |
//| double: each would open its own positions, count the other's,    |
//| trail every ticket twice, journal every close twice and overwrite |
//| the other's peaks in this store. The first instance to start     |
//| takes ownership by writing a heartbeat here every second; a later |
//| one that finds a fresh heartbeat under another chart's id runs as |
//| a scanner only - no entries, no management, no journal rows, no  |
//| saves - and says so on the panel and in the log. If the owner    |
//| goes away (chart closed, EA removed) the heartbeat goes stale and |
//| the scanner-only copy promotes itself within a few seconds.      |
//|                                                                  |
//| Keyed on ChartID, so a recompile, an input change or a period    |
//| change on the SAME chart never trips it. It cannot see another   |
//| terminal: two terminals on one account are still two engines.    |
//+------------------------------------------------------------------+
bool Guard_Enabled()
{
   if(!InpDupGuard) return false;
   if((bool)MQLInfoInteger(MQL_TESTER)) return false;
   return true;
}

//--- true when another chart owns this symbol/magic right now
bool State_GuardCheck()
{
   if(!Guard_Enabled()) return false;
   if(!GlobalVariableCheck(State_Key("alive"))) return false;
   const long owner=(long)GlobalVariableGet(State_Key("owner"));
   if(owner==ChartID()) return false;                        // our own previous life on this chart
   const datetime last=(datetime)(long)GlobalVariableGet(State_Key("alive"));
   return ((long)(TimeLocal()-last) < AB_HEARTBEAT_STALE);
}

void State_Heartbeat()
{
   if(!Guard_Enabled() || g_dupInstance) return;
   GlobalVariableSet(State_Key("alive"),(double)(long)TimeLocal());
   GlobalVariableSet(State_Key("owner"),(double)ChartID());
}

//--- the owner releases the slot on the way out, so a successor does not
//--- have to wait for the heartbeat to go stale
void State_HeartbeatClear()
{
   if(!Guard_Enabled() || g_dupInstance) return;
   if(!GlobalVariableCheck(State_Key("owner"))) return;
   if((long)GlobalVariableGet(State_Key("owner"))!=ChartID()) return;
   GlobalVariableDel(State_Key("alive"));
   GlobalVariableDel(State_Key("owner"));
}

bool State_OwnerGone()
{
   if(!GlobalVariableCheck(State_Key("alive"))) return true;
   const datetime last=(datetime)(long)GlobalVariableGet(State_Key("alive"));
   return ((long)(TimeLocal()-last) >= AB_HEARTBEAT_STALE);
}

//--- from OnTimer while g_dupInstance: take over once the owner is gone
void State_TryPromote()
{
   if(!g_dupInstance || !State_OwnerGone()) return;
   g_dupInstance=false;
   State_Heartbeat();
   State_Load();
   Journal_Init();
   g_auto_on   =InpEnableAutoTrading && !g_netting;
   g_lastSigBar=iTime(_Symbol,SigTF(),0);        // A2: never act on the bar already in progress
   g_lastAction="promoted to owner";
   PrintFormat("GUARD: the other %s / %I64u instance is gone - this chart now owns the engine (auto %s, per InpEnableAutoTrading).",
               _Symbol,InpAutoMagic,(g_auto_on ? "ARMED" : "disarmed"));
}
//+------------------------------------------------------------------+
