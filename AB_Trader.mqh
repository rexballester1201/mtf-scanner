//+------------------------------------------------------------------+
//|                                                    AB_Trader.mqh |
//|                  AstroBot MTF Scanner - v6.6 / TRADER JOURNAL    |
//|                                                                  |
//| WHAT THIS IS. AB_Journal.mqh records what the ENGINE did. This    |
//| file records what YOU did, and grades it against what the panel   |
//| was telling you at that exact moment.                             |
//|                                                                  |
//| The engine's journal exists to test a strategy. This one exists   |
//| to test a trader. They are deliberately separate files with       |
//| separate schemas, because the questions are different: one asks   |
//| "does this edge survive costs", the other asks "when I overrode   |
//| the signal, was I right to".                                      |
//|                                                                  |
//| WHAT IT CAPTURES. Every position that is NOT the auto engine's -  |
//| the panel's BUY and SELL buttons, one-click trading on the chart, |
//| the order window, the mobile app, the web terminal. Anything you  |
//| decided. On the way in and again on the way out.                  |
//|                                                                  |
//| The row carries the trade (pair, side, lot, price, stop, target)  |
//| and, more importantly, the CONTEXT you decided in:                |
//|                                                                  |
//|   THE CHART YOU WERE ON. Not the signal timeframe - the period    |
//|     actually open in front of you when you clicked.               |
//|   WHETHER YOU FOLLOWED THE SIGNAL. WITH, AGAINST, or NO_SIGNAL    |
//|     (you traded while the panel said wait), plus the verdict's    |
//|     grade, its check count and the bias reading at the time.      |
//|   HOW BIG, VERSUS HOW BIG YOU SAID. lot_ratio is your actual lot  |
//|     over the lot your own risk% would have chosen. 3.0 means you  |
//|     took three times the risk you told the panel you wanted.      |
//|   WHETHER YOU USED A STOP AT ALL.                                 |
//|   WHEN. Hour, weekday, session and news state, spread, and the    |
//|     volatility regime.                                            |
//|   WHAT YOU HAD JUST BEEN THROUGH. Seconds since the last trade,   |
//|     whether it lost, the current losing streak, and a revenge     |
//|     flag for a trade opened inside InpRevengeMinutes of a loss.   |
//|   THE BALANCE BEFORE AND AFTER, so every row shows what the       |
//|     decision actually cost or made, and the running total is      |
//|     reconstructable from the file alone.                          |
//|                                                                  |
//| On the way out it adds the result in money and in R, the best and |
//| worst the trade ever showed (MFE and MAE, also in R), how long it |
//| was held, and how it ended - your hand, a stop, or a target.      |
//|                                                                  |
//| WHAT IT IS FOR. The MY STATS tab reads the file back and          |
//| answers the questions a trading journal is supposed to answer and |
//| almost never does: does overriding the signal make or lose money, |
//| do the A-grade setups actually outperform the C-grade ones, what  |
//| do the no-stop trades cost, does size discipline correlate with   |
//| outcome, are the revenge trades as bad as they feel, which hours  |
//| and weekdays are worth trading, and are winners being cut short   |
//| while losers are held.                                            |
//|                                                                  |
//| WHAT IT IS NOT. It is a record, not a judge. "AGAINST the signal" |
//| is not automatically wrong - the whole point of measuring it is   |
//| that you may well be better than the ensemble, and until there is |
//| a file nobody knows. Enough trades have to accumulate before any  |
//| of these splits mean anything; the report says so where a sample  |
//| is too small to read.                                             |
//|                                                                  |
//| WHERE. <Common>\Files\AstroBot\Trader_<symbol>_v1.csv, one file   |
//| per symbol, appended across sessions and never rewritten. The     |
//| report lands beside it as Report_<symbol>_<stamp>.txt.            |
//+------------------------------------------------------------------+

#define AB_TRADER_SCHEMA "v1"
//--- 56 columns, indices 0..55. The context block below fills 19..42 and
//--- the row tails fill 43..55; the header, the builders and the report's
//--- parser are the three places that must agree on this.
#define AB_TRADER_COLS   56

//--- per-position tracking for the trades the user placed
struct MTrack
{
   ulong    posId;
   datetime openTime;
   double   openPrice;
   bool     isBuy;
   double   volume;
   double   slPts;        // the stop distance at entry: the R unit
   double   riskMoney;
   double   mfePts, maePts;
   double   lastSL;
   double   balAtEntry;
   string   aligned;      // WITH / AGAINST / NO_SIGNAL, as judged at entry
   string   grade;
   //--- the two discipline facts belong to the DECISION, so they are
   //--- captured once at entry and copied onto the exit row. Recomputing
   //--- them at exit would ask "does it have a stop now", which after a
   //--- stop-out is always yes and tells you nothing about the trader.
   bool     hadStop;
   double   lotRatio;
   datetime missingSince;
};

MTrack   g_mt[];
bool     g_trOK   = false;
string   g_trFile = "";
int      g_trFlags= 0;

//--- what the user had just been through, for the revenge flag
datetime g_trLastClose   = 0;
bool     g_trPrevLoss    = false;
int      g_trLossStreak  = 0;
double   g_trBalance     = 0;      // balance as of the previous event
int      g_trTradesToday = 0;
datetime g_trDayStamp    = 0;

//--- v6.95: the MY STATS tab keeps its last scan. Declared up here because
//--- Trader_Init and Trader_OnDealOut mark it stale.
bool     g_tsHave  = false;        // g_ts holds a scan that succeeded
bool     g_tsDirty = true;         // one of your trades closed since: re-read before showing
datetime g_tsAt    = 0;            // local time of the last scan

bool Trader_Enabled()
{
   if(!InpTraderJournal) return false;
   if((bool)MQLInfoInteger(MQL_OPTIMIZATION)) return false;
   if((bool)MQLInfoInteger(MQL_FRAME_MODE))   return false;
   return true;
}

//--- a position we care about: on this symbol, and not the engine's
bool Trader_IsMine(const long magic)
{
   if(IsAutoPos(magic)) return false;
   return true;
}

string Trader_Source(const long reason,const long magic)
{
   if(magic==(long)MagicNumber) return "PANEL";
   switch((ENUM_DEAL_REASON)reason)
   {
      case DEAL_REASON_CLIENT: return "TERMINAL";
      case DEAL_REASON_MOBILE: return "MOBILE";
      case DEAL_REASON_WEB:    return "WEB";
      case DEAL_REASON_EXPERT: return "OTHER_EA";
   }
   return "OTHER";
}

string Trader_Clean(string s)
{
   StringReplace(s,",",";");
   StringReplace(s,"\r"," ");
   StringReplace(s,"\n"," ");
   return s;
}

int  Trader_Find(const ulong pid){ for(int i=ArraySize(g_mt)-1;i>=0;i--) if(g_mt[i].posId==pid) return i; return -1; }
void Trader_Remove(const int k)
{
   const int n=ArraySize(g_mt);
   if(k<0||k>=n) return;
   for(int i=k;i<n-1;i++) g_mt[i]=g_mt[i+1];
   ArrayResize(g_mt,n-1);
}

void Trader_RollDay()
{
   MqlDateTime dt; TimeToStruct(TimeCurrent(),dt);
   const datetime d=StringToTime(StringFormat("%04d.%02d.%02d",dt.year,dt.mon,dt.day));
   if(d==g_trDayStamp) return;
   g_trDayStamp=d;
   g_trTradesToday=0;
}

//+------------------------------------------------------------------+
//| File                                                              |
//+------------------------------------------------------------------+
string Trader_Header()
{
   string h="ver,event,time,time_unix,pos_id,symbol,chart_tf,magic,source,side,volume,price,sl,tp";
   h+=",sl_pts,risk_money,risk_pct,has_stop,has_target,sug_lot,lot_ratio,sug_sl_pts";
   h+=",signal_dir,signal_grade,signal_checks,bias_pct,sig_tf,sigtf_label,adx,aligned";
   h+=",hour,dow,session_block,news_block,spread_pts,spread_atr,vol_ratio";
   h+=",open_before,trades_today,secs_since_prev,prev_was_loss,loss_streak,revenge";
   h+=",bal_before,bal_after,equity,dd_pct";
   h+=",pl,pl_r,mfe_r,mae_r,bars_held,secs_held,close_reason,entry_time,note";
   return h;
}

void Trader_Init()
{
   ArrayResize(g_mt,0);
   g_trOK=false;
   g_tsHave=false; g_tsDirty=true;    // v6.95: a new file, or the same one after a restart
   g_trBalance=AccountInfoDouble(ACCOUNT_BALANCE);
   g_trDayStamp=0;
   Trader_RollDay();

   if(!Trader_Enabled()){ Print("TRADER JOURNAL: off"); return; }

   g_trFile =StringFormat("AstroBot\\Trader_%s_%s.csv",Journal_SafeSymbol(),AB_TRADER_SCHEMA);
   g_trFlags=FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_SHARE_READ|FILE_COMMON;

   const bool fresh=!FileIsExist(g_trFile,FILE_COMMON);
   const int h=FileOpen(g_trFile,(fresh ? (g_trFlags & ~FILE_READ) : g_trFlags));
   if(h==INVALID_HANDLE)
   { PrintFormat("TRADER JOURNAL: cannot open %s (error %d)",g_trFile,GetLastError()); return; }
   if(fresh) FileWriteString(h,Trader_Header()+"\r\n");
   FileClose(h);
   g_trOK=true;
   PrintFormat("TRADER JOURNAL: %s -> %s\\Files\\%s",(fresh?"new file":"appending"),
               TerminalInfoString(TERMINAL_COMMONDATA_PATH),g_trFile);
}

void Trader_Write(const string line)
{
   if(!g_trOK) return;
   const int h=FileOpen(g_trFile,g_trFlags);
   if(h==INVALID_HANDLE){ PrintFormat("TRADER JOURNAL: write failed, error %d",GetLastError()); return; }
   FileSeek(h,0,SEEK_END);
   FileWriteString(h,line+"\r\n");
   FileClose(h);
}

//+------------------------------------------------------------------+
//| Tracking                                                          |
//+------------------------------------------------------------------+
void Trader_TrackAll()
{
   if(!Trader_Enabled()) return;
   const double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   const double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   const double pt =m_symbol.Point();
   if(bid<=0||ask<=0||pt<=0) return;
   const datetime now=TimeCurrent();

   int seen[]; ArrayResize(seen,ArraySize(g_mt)); ArrayInitialize(seen,0);
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      if(!m_position.SelectByIndex(i)) continue;
      if(m_position.Symbol()!=_Symbol) continue;
      if(!Trader_IsMine(m_position.Magic())) continue;
      const ulong pid=(ulong)m_position.Identifier();
      const int k=Trader_Find(pid);
      if(k<0) continue;                       // entry row not written yet; the deal hook owns creation
      seen[k]=1;
      const double exc=(g_mt[k].isBuy ? (bid-g_mt[k].openPrice)/pt : (g_mt[k].openPrice-ask)/pt);
      if(exc >  g_mt[k].mfePts) g_mt[k].mfePts= exc;
      if(-exc>  g_mt[k].maePts) g_mt[k].maePts=-exc;
      g_mt[k].lastSL=m_position.StopLoss();
      g_mt[k].missingSince=0;
   }
   for(int k=ArraySize(g_mt)-1;k>=0;k--)
   {
      if(k<ArraySize(seen) && seen[k]==1) continue;
      if(g_mt[k].missingSince==0){ g_mt[k].missingSince=now; continue; }
      if(now-g_mt[k].missingSince>120) Trader_Remove(k);
   }
}

//+------------------------------------------------------------------+
//| The context block, identical on ENTRY and EXIT rows so the two    |
//| can be compared directly.                                         |
//+------------------------------------------------------------------+
//--- Columns 19..42. On an EXIT row `alignedFixed` and `gradeFixed` carry
//--- the values recorded when the position was OPENED, because those
//--- describe the decision being judged. Recomputing them at exit would
//--- group a trade by the market's state when it ended, which is not a
//--- fact about the trader at all.
string Trader_Context(const int dirOfTrade,const double slPts,const double volume,
                      const int openBefore,const string alignedFixed,const string gradeFixed,
                      const double ratioFixed,string &alignedOut,double &ratioOut)
{
   const int    si=SigIdx();
   const int    spread=(int)SymbolInfoInteger(_Symbol,SYMBOL_SPREAD);
   const double atr=AutoATR(), pt=m_symbol.Point();
   const double sprATR=(atr>0&&pt>0) ? spread*pt/atr : 0.0;

   //--- did the trade follow the panel?
   if(StringLen(alignedFixed)>0) alignedOut=alignedFixed;
   else if(g_V.dir==0)           alignedOut="NO_SIGNAL";
   else if(g_V.dir==dirOfTrade)  alignedOut="WITH";
   else                          alignedOut="AGAINST";
   const string grade=(StringLen(gradeFixed)>0 ? gradeFixed : g_V.grade);

   //--- what the user's OWN stated risk% would have sized, so lot_ratio
   //--- measures them against their own intention rather than against ours
   const double sugSL =(slPts>0 ? slPts : EffSLpts());
   const double sugLot=RiskToLotPct(sugSL,g_ui_risk);
   const double ratio =(ratioFixed>0 ? ratioFixed : (sugLot>0 ? volume/sugLot : 0.0));
   ratioOut=ratio;

   MqlDateTime dt; TimeToStruct(TimeCurrent(),dt);
   const int  secsSince=(g_trLastClose>0 ? (int)(TimeCurrent()-g_trLastClose) : -1);
   const bool revenge  =(g_trPrevLoss && secsSince>=0 && secsSince<=InpRevengeMinutes*60);

   return StringFormat("%.2f,%.3f,%.0f,%d,%s,%d/%d,%.1f,%s,%s,%.1f,%s,%d,%d,%d,%d,%d,%.4f,%.3f,%d,%d,%d,%d,%d,%d",
                       sugLot,ratio,sugSL,
                       g_V.dir,Trader_Clean(grade),g_V.pass,g_V.total,
                       g_overallBuyPct,g_tfName[si],
                       Trader_Clean(g_R[si].ready ? g_R[si].label : "loading"),
                       (g_R[si].ready ? g_R[si].adx : 0.0),
                       alignedOut,
                       dt.hour,dt.day_of_week,(g_sessionBlock?1:0),(g_newsBlock?1:0),
                       spread,sprATR,g_volRatio,
                       openBefore,g_trTradesToday,secsSince,
                       (g_trPrevLoss?1:0),g_trLossStreak,(revenge?1:0));
}

//+------------------------------------------------------------------+
//| ENTRY: the user opened something                                  |
//+------------------------------------------------------------------+
void Trader_OnDealIn(const ulong deal)
{
   if(!Trader_Enabled()) return;
   Trader_RollDay();

   const ulong  pid   =(ulong)HistoryDealGetInteger(deal,DEAL_POSITION_ID);
   if(pid==0 || Trader_Find(pid)>=0) return;
   const long   magic =HistoryDealGetInteger(deal,DEAL_MAGIC);
   const long   reason=HistoryDealGetInteger(deal,DEAL_REASON);
   const double price =HistoryDealGetDouble(deal,DEAL_PRICE);
   const double vol   =HistoryDealGetDouble(deal,DEAL_VOLUME);
   const bool   isBuy =(HistoryDealGetInteger(deal,DEAL_TYPE)==DEAL_TYPE_BUY);
   const datetime when=(datetime)HistoryDealGetInteger(deal,DEAL_TIME);

   //--- the stop as the server holds it right now
   double sl=0,tp=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      if(!m_position.SelectByIndex(i)) continue;
      if((ulong)m_position.Identifier()!=pid) continue;
      sl=m_position.StopLoss(); tp=m_position.TakeProfit();
      break;
   }
   const double pt=m_symbol.Point();
   const double slPts=(sl>0&&pt>0 ? MathAbs(price-sl)/pt : 0.0);
   const double riskM=(slPts>0 ? LossPerLot(slPts)*vol : 0.0);
   const double eq   =AccountInfoDouble(ACCOUNT_EQUITY);

   int openBefore=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      if(!m_position.SelectByIndex(i)) continue;
      if(m_position.Symbol()!=_Symbol) continue;
      if(!Trader_IsMine(m_position.Magic())) continue;
      if((ulong)m_position.Identifier()==pid) continue;
      openBefore++;
   }

   string aligned=""; double ratio=0;
   const string ctx=Trader_Context((isBuy?1:-1),slPts,vol,openBefore,"","",0.0,aligned,ratio);

   //--- start tracking
   MTrack t;
   t.posId=pid; t.openTime=when; t.openPrice=price; t.isBuy=isBuy; t.volume=vol;
   t.slPts=(slPts>0?slPts:EffSLpts()); t.riskMoney=(riskM>0?riskM:LossPerLot(t.slPts)*vol);
   t.mfePts=0; t.maePts=0; t.lastSL=sl; t.missingSince=0;
   t.balAtEntry=AccountInfoDouble(ACCOUNT_BALANCE);
   t.aligned=aligned; t.grade=g_V.grade;
   t.hadStop=(sl>0); t.lotRatio=ratio;
   const int n=ArraySize(g_mt); ArrayResize(g_mt,n+1); g_mt[n]=t;

   g_trTradesToday++;

   const double balNow=AccountInfoDouble(ACCOUNT_BALANCE);
   const int dg=m_symbol.Digits();
   const string row=StringFormat("%s,ENTRY,%s,%I64d,%I64u,%s,%s,%I64d,%s,%s,%.2f,%.*f,%s,%s,%.1f,%.2f,%.3f,%d,%d,",
                    AB_TRADER_SCHEMA,TimeToString(when,TIME_DATE|TIME_SECONDS),(long)when,pid,_Symbol,
                    TfName((ENUM_TIMEFRAMES)_Period),magic,Trader_Source(reason,magic),
                    (isBuy?"BUY":"SELL"),vol,dg,price,
                    (sl>0?DoubleToString(sl,dg):""),(tp>0?DoubleToString(tp,dg):""),
                    slPts,riskM,(eq>0?riskM/eq*100.0:0.0),(sl>0?1:0),(tp>0?1:0))
                   +ctx
                   //--- 43 bal_before, 44 bal_after, 45 equity, 46 dd_pct,
                   //--- 47..53 outcome (empty on an entry), 54 entry_time, 55 note
                   +StringFormat(",%.2f,%.2f,%.2f,%.2f,,,,,,,,%s,",
                                 g_trBalance,balNow,eq,CurrentDDPct(),
                                 TimeToString(when,TIME_DATE|TIME_SECONDS));
   Trader_Write(row);
   g_trBalance=balNow;

   PrintFormat("YOUR TRADE: %s %.2f %s @ %.*f | chart %s | signal %s (grade %s, bias %.0f%%) | stop %s | lot %.1fx your risk%%",
               (isBuy?"BUY":"SELL"),vol,_Symbol,dg,price,
               TfName((ENUM_TIMEFRAMES)_Period),aligned,g_V.grade,g_overallBuyPct,
               (sl>0?"yes":"NONE"),
               (RiskToLotPct((slPts>0?slPts:EffSLpts()),g_ui_risk)>0 ? vol/RiskToLotPct((slPts>0?slPts:EffSLpts()),g_ui_risk) : 0.0));
}

//+------------------------------------------------------------------+
//| EXIT: the user's position left                                    |
//+------------------------------------------------------------------+
void Trader_OnDealOut(const ulong deal)
{
   if(!Trader_Enabled()) return;
   Trader_RollDay();

   const ulong  pid   =(ulong)HistoryDealGetInteger(deal,DEAL_POSITION_ID);
   const long   magic =HistoryDealGetInteger(deal,DEAL_MAGIC);
   const long   reason=HistoryDealGetInteger(deal,DEAL_REASON);
   const double price =HistoryDealGetDouble(deal,DEAL_PRICE);
   const double vol   =HistoryDealGetDouble(deal,DEAL_VOLUME);
   const datetime when=(datetime)HistoryDealGetInteger(deal,DEAL_TIME);
   const double pl    =HistoryDealGetDouble(deal,DEAL_PROFIT)
                      +HistoryDealGetDouble(deal,DEAL_SWAP)
                      +HistoryDealGetDouble(deal,DEAL_COMMISSION);
   const long   dtype =HistoryDealGetInteger(deal,DEAL_TYPE);

   int k=Trader_Find(pid);
   if(k<0)
   {
      //--- opened before the EA was attached: record what we can
      MTrack t;
      t.posId=pid; t.openTime=when; t.openPrice=price; t.isBuy=(dtype==DEAL_TYPE_SELL);
      t.volume=vol; t.slPts=EffSLpts(); t.riskMoney=LossPerLot(t.slPts)*vol;
      t.mfePts=0; t.maePts=0; t.lastSL=0; t.missingSince=0;
      t.balAtEntry=g_trBalance; t.aligned="UNKNOWN"; t.grade="-";
      t.hadStop=false; t.lotRatio=0;
      const int n=ArraySize(g_mt); ArrayResize(g_mt,n+1); g_mt[n]=t;
      k=n;
   }

   const double pt=m_symbol.Point();
   if(pt>0)
   {
      const double exc=(g_mt[k].isBuy ? (price-g_mt[k].openPrice)/pt : (g_mt[k].openPrice-price)/pt);
      if(exc >  g_mt[k].mfePts) g_mt[k].mfePts= exc;
      if(-exc>  g_mt[k].maePts) g_mt[k].maePts=-exc;
   }

   const double frac    =(g_mt[k].volume>0 ? vol/g_mt[k].volume : 1.0);
   const double riskPart=g_mt[k].riskMoney*frac;
   const double plR     =(riskPart>0 ? pl/riskPart : 0.0);
   const double mfeR    =(g_mt[k].slPts>0 ? g_mt[k].mfePts/g_mt[k].slPts : 0.0);
   const double maeR    =(g_mt[k].slPts>0 ? g_mt[k].maePts/g_mt[k].slPts : 0.0);

   int barsN=Bars(_Symbol,(ENUM_TIMEFRAMES)_Period,g_mt[k].openTime,when);
   const int barsHeld=(barsN>0?barsN-1:0);
   const int secsHeld=(int)(when-g_mt[k].openTime);

   int openBefore=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      if(!m_position.SelectByIndex(i)) continue;
      if(m_position.Symbol()!=_Symbol) continue;
      if(!Trader_IsMine(m_position.Magic())) continue;
      openBefore++;
   }

   //--- the decision's OWN context, carried from the entry
   string aligned=""; double ratio=0;
   const string ctx=Trader_Context((g_mt[k].isBuy?1:-1),g_mt[k].slPts,vol,openBefore,
                                   g_mt[k].aligned,g_mt[k].grade,g_mt[k].lotRatio,aligned,ratio);

   const double balNow=AccountInfoDouble(ACCOUNT_BALANCE);
   const double eqNow =AccountInfoDouble(ACCOUNT_EQUITY);
   const int dg=m_symbol.Digits();
   const string row=StringFormat("%s,EXIT,%s,%I64d,%I64u,%s,%s,%I64d,%s,%s,%.2f,%.*f,%s,,%.1f,%.2f,%.3f,%d,%d,",
                    AB_TRADER_SCHEMA,TimeToString(when,TIME_DATE|TIME_SECONDS),(long)when,pid,_Symbol,
                    TfName((ENUM_TIMEFRAMES)_Period),magic,Trader_Source(reason,magic),
                    (g_mt[k].isBuy?"BUY":"SELL"),vol,dg,price,
                    (g_mt[k].lastSL>0?DoubleToString(g_mt[k].lastSL,dg):""),
                    g_mt[k].slPts,riskPart,0.0,(g_mt[k].hadStop?1:0),0)
                   +ctx
                   //--- 43..46 balances, 47..53 the outcome, 54 entry_time, 55 note
                   +StringFormat(",%.2f,%.2f,%.2f,%.2f,%.2f,%.3f,%.3f,%.3f,%d,%d,%s,%s,%s",
                                 g_trBalance,balNow,eqNow,CurrentDDPct(),
                                 pl,plR,mfeR,maeR,barsHeld,secsHeld,
                                 Trader_Clean(DealReasonName(reason)),
                                 TimeToString(g_mt[k].openTime,TIME_DATE|TIME_SECONDS),
                                 "");
   Trader_Write(row);
   g_tsDirty=true;                    // v6.95: the MY STATS tab re-reads on its next pass

   //--- streak state for the revenge flag on the NEXT trade
   g_trBalance   =balNow;
   g_trLastClose =when;
   g_trPrevLoss  =(pl<0);
   if(pl<0) g_trLossStreak++; else g_trLossStreak=0;

   PrintFormat("YOUR EXIT: %s %.2f | %+.2f (%.2fR) | best %.2fR worst %.2fR | held %s | %s | entry was %s",
               (g_mt[k].isBuy?"BUY":"SELL"),vol,pl,plR,mfeR,maeR,
               (secsHeld>=3600?StringFormat("%.1fh",secsHeld/3600.0):StringFormat("%dm",secsHeld/60)),
               DealReasonName(reason),g_mt[k].aligned);

   bool still=false;
   for(int i=PositionsTotal()-1;i>=0;i--)
   { if(m_position.SelectByIndex(i) && (ulong)m_position.Identifier()==pid){ still=true; break; } }
   if(!still) Trader_Remove(k);
}

//+------------------------------------------------------------------+
//| THE REPORT                                                        |
//|                                                                  |
//| Reads the file back and answers the questions the file was kept   |
//| to answer. Every split states its sample size, and anything under |
//| InpReportMinN is marked as too thin to read rather than quietly   |
//| presented as a finding.                                           |
//|                                                                  |
//| v6.95: reading is split from writing. Trader_Scan fills one       |
//| TraderStats; the text report and the panel's MY STATS tab both    |
//| render from it, and the findings come from one function, so the   |
//| tab and the report cannot disagree about a number or a verdict.   |
//+------------------------------------------------------------------+
struct RGroup
{
   string name;
   int    n, wins;
   double sumR, sumMoney;
};

void RG_Init(RGroup &g,const string nm){ g.name=nm; g.n=0; g.wins=0; g.sumR=0; g.sumMoney=0; }
void RG_Add(RGroup &g,const double r,const double money){ g.n++; if(money>0) g.wins++; g.sumR+=r; g.sumMoney+=money; }
string RG_Line(const RGroup &g)
{
   if(g.n==0) return StringFormat("  %-22s  no trades",g.name);
   const string thin=(g.n<InpReportMinN ? "   (thin sample)" : "");
   return StringFormat("  %-22s  n=%-4d  win %3.0f%%  avg %+6.2fR  total %+8.2fR  %+10.2f%s",
                       g.name,g.n,(double)g.wins/g.n*100.0,g.sumR/g.n,g.sumR,g.sumMoney,thin);
}

struct TraderStats
{
   RGroup all,withS,against,noSig,gA,gB,gC,gNone,noStop,hasStop,over,sized,revY,revN,newsY,sessY;
   RGroup byHour[24], byDow[7];
   double gaveBack; int gaveN;
   long   winSecs,lossSecs; int winN,lossN;
   double firstBal,lastBal;
};

TraderStats g_ts;                  // v6.95: the last scan, for the MY STATS tab

//--- read the whole file into st. false when there is no file to read.
bool Trader_Scan(TraderStats &st)
{
   RG_Init(st.all,"ALL EXITS");             RG_Init(st.withS,"WITH the signal");
   RG_Init(st.against,"AGAINST the signal");RG_Init(st.noSig,"no signal (panel said wait)");
   RG_Init(st.gA,"grade A");                RG_Init(st.gB,"grade B");
   RG_Init(st.gC,"grade C");                RG_Init(st.gNone,"no grade");
   RG_Init(st.noStop,"NO stop loss");       RG_Init(st.hasStop,"with a stop");
   RG_Init(st.over,"oversized");            RG_Init(st.sized,"within your risk%");
   RG_Init(st.revY,"revenge trades");       RG_Init(st.revN,"not revenge");
   RG_Init(st.newsY,"during news");         RG_Init(st.sessY,"during session block");
   for(int i=0;i<24;i++) RG_Init(st.byHour[i],StringFormat("h%02d",i));
   for(int i=0;i<7;i++)  RG_Init(st.byDow[i], StringFormat("dow%d",i));
   st.gaveBack=0; st.gaveN=0;
   st.winSecs=0; st.lossSecs=0; st.winN=0; st.lossN=0;
   st.firstBal=0; st.lastBal=0;

   if(!g_trOK) return false;
   const int h=FileOpen(g_trFile,FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ|FILE_COMMON);
   if(h==INVALID_HANDLE){ PrintFormat("TRADER JOURNAL: cannot read %s (error %d)",g_trFile,GetLastError()); return false; }

   bool haveFirst=false;
   int  lineNo=0;
   while(!FileIsEnding(h))
   {
      const string line=FileReadString(h);
      lineNo++;
      if(lineNo==1 || StringLen(line)<10) continue;
      string f[]; const int nf=StringSplit(line,',',f);
      if(nf<AB_TRADER_COLS) continue;

      const double balA=StringToDouble(f[44]);
      if(!haveFirst && balA>0){ st.firstBal=StringToDouble(f[43]); haveFirst=true; }
      if(balA>0) st.lastBal=balA;

      if(f[1]!="EXIT") continue;

      const double r     =StringToDouble(f[48]);
      const double money =StringToDouble(f[47]);
      const double mfeR  =StringToDouble(f[49]);
      const int    secs  =(int)StringToInteger(f[52]);
      const string align =f[29];      // as judged when the position was OPENED
      const string grade =f[23];
      const int    hasSL =(int)StringToInteger(f[17]);
      const double ratio =StringToDouble(f[20]);
      const int    rev   =(int)StringToInteger(f[42]);
      const int    hour  =(int)StringToInteger(f[30]);
      const int    dow   =(int)StringToInteger(f[31]);
      const int    sBlk  =(int)StringToInteger(f[32]);
      const int    nBlk  =(int)StringToInteger(f[33]);

      RG_Add(st.all,r,money);
      if(align=="WITH")           RG_Add(st.withS,r,money);
      else if(align=="AGAINST")   RG_Add(st.against,r,money);
      else if(align=="NO_SIGNAL") RG_Add(st.noSig,r,money);

      if(grade=="A")      RG_Add(st.gA,r,money);
      else if(grade=="B") RG_Add(st.gB,r,money);
      else if(grade=="C") RG_Add(st.gC,r,money);
      else                RG_Add(st.gNone,r,money);

      if(hasSL==1) RG_Add(st.hasStop,r,money); else RG_Add(st.noStop,r,money);
      if(ratio>InpOversizeRatio) RG_Add(st.over,r,money); else RG_Add(st.sized,r,money);
      if(rev==1) RG_Add(st.revY,r,money); else RG_Add(st.revN,r,money);
      if(nBlk==1) RG_Add(st.newsY,r,money);
      if(sBlk==1) RG_Add(st.sessY,r,money);

      if(hour>=0&&hour<24) RG_Add(st.byHour[hour],r,money);
      if(dow >=0&&dow <7)  RG_Add(st.byDow[dow],  r,money);

      if(money>0){ st.winSecs+=secs; st.winN++; if(mfeR>r){ st.gaveBack+=(mfeR-r); st.gaveN++; } }
      else       { st.lossSecs+=secs; st.lossN++; }
   }
   FileClose(h);
   return true;
}

//--- the findings, as one list both renderers share: lng in the report's
//--- words, shr as a one-line version for the tab, good when it is praise
void TR_Push(string &lng[],string &shr[],bool &good[],const string l,const string s,const bool g)
{
   const int n=ArraySize(lng);
   ArrayResize(lng,n+1); ArrayResize(shr,n+1); ArrayResize(good,n+1);
   lng[n]=l; shr[n]=s; good[n]=g;
}

int Trader_Findings(const TraderStats &st,string &lng[],string &shr[],bool &good[])
{
   ArrayResize(lng,0); ArrayResize(shr,0); ArrayResize(good,0);
   if(st.noStop.n>=InpReportMinN && st.noStop.sumMoney<0)
      TR_Push(lng,shr,good,
              StringFormat("Trading without a stop has cost you %.2f over %d trades.",-st.noStop.sumMoney,st.noStop.n),
              StringFormat("Trading without a stop has cost you %.2f over %d trades",-st.noStop.sumMoney,st.noStop.n),false);
   if(st.against.n>=InpReportMinN && st.withS.n>=InpReportMinN)
   {
      const double a=st.against.sumR/st.against.n, w=st.withS.sumR/st.withS.n;
      if(a<w)
         TR_Push(lng,shr,good,
                 StringFormat("Overriding the panel is costing you: %+.2fR per trade against\r\n    it versus %+.2fR with it.",a,w),
                 StringFormat("Overriding the panel costs you: %+.2fR vs %+.2fR with it",a,w),false);
      else
         TR_Push(lng,shr,good,
                 StringFormat("You beat the panel when you override it: %+.2fR against versus\r\n    %+.2fR with. The ensemble may be too strict for you.",a,w),
                 StringFormat("You beat the panel when you override it: %+.2fR vs %+.2fR",a,w),true);
   }
   if(st.over.n>=InpReportMinN && st.over.sumR/st.over.n < st.sized.sumR/MathMax(1,st.sized.n))
   {
      const double o=st.over.sumR/st.over.n, z=st.sized.sumR/MathMax(1,st.sized.n);
      TR_Push(lng,shr,good,
              StringFormat("Oversized trades do worse: %+.2fR versus %+.2fR when you stay\r\n    inside your own risk setting.",o,z),
              StringFormat("Oversized trades do worse: %+.2fR vs %+.2fR inside your risk%%",o,z),false);
   }
   if(st.revY.n>=InpReportMinN && st.revY.sumR<0)
      TR_Push(lng,shr,good,
              StringFormat("The %d trades you opened within %d minutes of a loss total %+.2fR.",st.revY.n,InpRevengeMinutes,st.revY.sumR),
              StringFormat("%d trades opened within %d min of a loss: %+.2fR total",st.revY.n,InpRevengeMinutes,st.revY.sumR),false);
   return ArraySize(lng);
}

void Trader_Report()
{
   if(!g_trOK){ Print("TRADER JOURNAL: no file to report on"); return; }
   //--- straight into the tab's copy, so the tab shows what the report says
   g_tsHave=Trader_Scan(g_ts);
   g_tsDirty=false; g_tsAt=TimeLocal();
   if(!g_tsHave) return;
   if(g_ts.all.n==0){ Print("TRADER JOURNAL: no closed trades recorded yet"); return; }

   //--- assemble
   string rep="";
   rep+="=====================================================================\r\n";
   rep+=StringFormat("  TRADER BEHAVIOUR REPORT   %s   %s\r\n",_Symbol,TimeToString(TimeCurrent(),TIME_DATE|TIME_MINUTES));
   rep+="=====================================================================\r\n\r\n";
   rep+=StringFormat("  %d closed trades on record.  Balance %.2f -> %.2f  (%+.2f)\r\n\r\n",
                     g_ts.all.n,g_ts.firstBal,g_ts.lastBal,g_ts.lastBal-g_ts.firstBal);
   rep+="  Every line below is n / win rate / average R / total R / money.\r\n";
   rep+=StringFormat("  A split with fewer than %d trades is marked thin and should not\r\n",InpReportMinN);
   rep+="  be read as a finding.\r\n\r\n";

   rep+="--- OVERALL ---------------------------------------------------------\r\n";
   rep+=RG_Line(g_ts.all)+"\r\n\r\n";

   rep+="--- DID YOU FOLLOW THE PANEL? ---------------------------------------\r\n";
   rep+=RG_Line(g_ts.withS)+"\r\n"+RG_Line(g_ts.against)+"\r\n"+RG_Line(g_ts.noSig)+"\r\n\r\n";

   rep+="--- BY SETUP GRADE --------------------------------------------------\r\n";
   rep+=RG_Line(g_ts.gA)+"\r\n"+RG_Line(g_ts.gB)+"\r\n"+RG_Line(g_ts.gC)+"\r\n"+RG_Line(g_ts.gNone)+"\r\n\r\n";

   rep+="--- DISCIPLINE ------------------------------------------------------\r\n";
   rep+=RG_Line(g_ts.hasStop)+"\r\n"+RG_Line(g_ts.noStop)+"\r\n";
   rep+=RG_Line(g_ts.sized)+"\r\n"+RG_Line(g_ts.over)+"\r\n";
   rep+=RG_Line(g_ts.revN)+"\r\n"+RG_Line(g_ts.revY)+"\r\n";
   if(g_ts.newsY.n>0) rep+=RG_Line(g_ts.newsY)+"\r\n";
   if(g_ts.sessY.n>0) rep+=RG_Line(g_ts.sessY)+"\r\n";
   rep+="\r\n";

   rep+="--- HOLDING ---------------------------------------------------------\r\n";
   const int winN=g_ts.winN, lossN=g_ts.lossN;
   if(winN>0)  rep+=StringFormat("  winners held  %6.1f min average  (n=%d)\r\n",g_ts.winSecs/60.0/winN,winN);
   if(lossN>0) rep+=StringFormat("  losers  held  %6.1f min average  (n=%d)\r\n",g_ts.lossSecs/60.0/lossN,lossN);
   if(winN>0 && lossN>0 && (double)g_ts.winSecs/MathMax(1,winN) < (double)g_ts.lossSecs/MathMax(1,lossN))
      rep+="  You hold losers longer than winners. That is the classic pattern.\r\n";
   if(g_ts.gaveN>0)
      rep+=StringFormat("  winners gave back %.2fR on average from their best point (n=%d)\r\n",g_ts.gaveBack/g_ts.gaveN,g_ts.gaveN);
   rep+="\r\n";

   rep+="--- BY HOUR (server time, only hours you traded) ---------------------\r\n";
   for(int i=0;i<24;i++) if(g_ts.byHour[i].n>0) rep+=RG_Line(g_ts.byHour[i])+"\r\n";
   rep+="\r\n";

   rep+="--- BY WEEKDAY ------------------------------------------------------\r\n";
   const string dayName[7]={"Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"};
   for(int i=0;i<7;i++) if(g_ts.byDow[i].n>0)
   { RGroup g=g_ts.byDow[i]; g.name=dayName[i]; rep+=RG_Line(g)+"\r\n"; }
   rep+="\r\n";

   //--- the one or two things actually worth changing
   rep+="--- WHAT THE FILE SUGGESTS ------------------------------------------\r\n";
   string lng[],shr[]; bool good[];
   const int said=Trader_Findings(g_ts,lng,shr,good);
   for(int i=0;i<said;i++) rep+="  * "+lng[i]+"\r\n";
   if(said==0) rep+="  Nothing yet with a big enough sample to call. Keep trading and re-run.\r\n";
   rep+="\r\n=====================================================================\r\n";

   //--- write it out and put the highlights in the log
   MqlDateTime dt; TimeToStruct(TimeLocal(),dt);
   const string fn=StringFormat("AstroBot\\Report_%s_%04d%02d%02d_%02d%02d.txt",
                                Journal_SafeSymbol(),dt.year,dt.mon,dt.day,dt.hour,dt.min);
   const int wh=FileOpen(fn,FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON);
   if(wh!=INVALID_HANDLE){ FileWriteString(wh,rep); FileClose(wh); }

   Print("================ TRADER BEHAVIOUR REPORT ================");
   Print(RG_Line(g_ts.all));
   Print(RG_Line(g_ts.withS));
   Print(RG_Line(g_ts.against));
   Print(RG_Line(g_ts.noSig));
   Print(RG_Line(g_ts.noStop));
   Print(RG_Line(g_ts.over));
   Print(RG_Line(g_ts.revY));
   PrintFormat("Full report: %s\\Files\\%s",TerminalInfoString(TERMINAL_COMMONDATA_PATH),fn);
   g_lastAction="report written: "+fn;
}

//+------------------------------------------------------------------+
//| v6.95: THE MY STATS TAB                                           |
//|                                                                  |
//| The report's headlines as a two-column grid: you and the panel,   |
//| and by grade, on the left; discipline on the right; the first     |
//| finding under it. A row under InpReportMinN trades is dim - the   |
//| same "too thin to read" the report says in words.                 |
//+------------------------------------------------------------------+
#define TRADER_TAB_ROWS 7

//--- the tab shows the file as of the last trade to close, and re-reads
//--- it at most once a minute otherwise (another chart may append to it)
void Trader_StatsRefresh()
{
   if(!g_trOK) return;
   if(!g_tsDirty && g_tsAt>0 && TimeLocal()-g_tsAt<60) return;
   g_tsHave=Trader_Scan(g_ts);
   g_tsDirty=false; g_tsAt=TimeLocal();
}

string TR_Cell(const string name,const RGroup &g)
{
   if(g.n==0) return StringFormat("%-10s  -",name);
   return StringFormat("%-10s n=%-3d %3.0f%% %+.2fR",name,g.n,(double)g.wins/g.n*100.0,g.sumR/g.n);
}

color TR_CellColor(const RGroup &g)
{
   if(g.n==0 || g.n<InpReportMinN) return C_DIM;       // thin: not a finding yet
   const double a=g.sumR/g.n;
   return (a>0 ? C_BULL : a<0 ? C_BEAR : C_TEXT);
}

string TR_Mins(const double m){ return (m<60 ? StringFormat("%.0fm",m) : StringFormat("%.1fh",m/60.0)); }

void Trader_TabText(string &cap,string &lt[],color &lc[],string &rt[],color &rc[],string &fnd,color &fc)
{
   for(int k=0;k<TRADER_TAB_ROWS;k++){ lt[k]=""; rt[k]=""; lc[k]=C_DIM; rc[k]=C_DIM; }
   fnd=""; fc=C_DIM;

   if(!Trader_Enabled())
   { cap="MY STATS  (journal off)"; fnd="Set InpTraderJournal=true to record your own trades and grade them here."; return; }
   if(!g_trOK)
   { cap="MY STATS  (no journal file)"; fnd="The journal file could not be opened - the Experts log says why."; return; }
   if(!g_tsHave || g_ts.all.n==0)
   {
      cap="MY STATS  no closed trades on "+_Symbol+" yet";
      fnd="Every trade you open and close here is recorded and graded against the panel.";
      return;
   }

   cap=StringFormat("MY STATS  %d closed  |  balance %.2f -> %.2f (%+.2f)",
                    g_ts.all.n,g_ts.firstBal,g_ts.lastBal,g_ts.lastBal-g_ts.firstBal);

   //--- left: you and the panel
   lt[0]=TR_Cell("ALL",      g_ts.all);     lc[0]=TR_CellColor(g_ts.all);
   lt[1]=TR_Cell("WITH",     g_ts.withS);   lc[1]=TR_CellColor(g_ts.withS);
   lt[2]=TR_Cell("AGAINST",  g_ts.against); lc[2]=TR_CellColor(g_ts.against);
   lt[3]=TR_Cell("no signal",g_ts.noSig);   lc[3]=TR_CellColor(g_ts.noSig);
   lt[4]=TR_Cell("grade A",  g_ts.gA);      lc[4]=TR_CellColor(g_ts.gA);
   lt[5]=TR_Cell("grade B",  g_ts.gB);      lc[5]=TR_CellColor(g_ts.gB);
   lt[6]=TR_Cell("grade C",  g_ts.gC);      lc[6]=TR_CellColor(g_ts.gC);

   //--- right: discipline
   rt[0]=TR_Cell("with stop",g_ts.hasStop); rc[0]=TR_CellColor(g_ts.hasStop);
   rt[1]=TR_Cell("NO stop",  g_ts.noStop);  rc[1]=TR_CellColor(g_ts.noStop);
   rt[2]=TR_Cell("in size",  g_ts.sized);   rc[2]=TR_CellColor(g_ts.sized);
   rt[3]=TR_Cell("OVERSIZED",g_ts.over);    rc[3]=TR_CellColor(g_ts.over);
   rt[4]=TR_Cell("revenge",  g_ts.revY);    rc[4]=TR_CellColor(g_ts.revY);
   if(g_ts.winN>0 || g_ts.lossN>0)
   {
      const double wm=(g_ts.winN >0 ? g_ts.winSecs /60.0/g_ts.winN  : 0.0);
      const double lm=(g_ts.lossN>0 ? g_ts.lossSecs/60.0/g_ts.lossN : 0.0);
      rt[5]=StringFormat("%-10s win %s / loss %s","held",
                         (g_ts.winN>0 ? TR_Mins(wm) : "-"),(g_ts.lossN>0 ? TR_Mins(lm) : "-"));
      const bool thin=(g_ts.winN<InpReportMinN || g_ts.lossN<InpReportMinN);
      //--- holding losers longer than winners is the classic pattern: warn
      rc[5]=(thin ? C_DIM : (lm>wm ? C_WARN : C_TEXT));
   }
   if(g_ts.gaveN>0)
   {
      rt[6]=StringFormat("%-10s %.2fR from best, n=%d","gave back",g_ts.gaveBack/g_ts.gaveN,g_ts.gaveN);
      rc[6]=(g_ts.gaveN<InpReportMinN ? C_DIM : C_TEXT);
   }

   //--- the first finding; the full report lists the rest
   string lng[],shr[]; bool good[];
   const int nf=Trader_Findings(g_ts,lng,shr,good);
   if(nf>0)
   {
      fnd=shr[0]+(nf>1 ? StringFormat("  (+%d more in FULL REPORT)",nf-1) : "");
      fc=(good[0] ? C_BULL : C_WARN);
   }
   else if(g_ts.all.n<InpReportMinN)
      fnd=StringFormat("Findings need %d trades in a split - you have %d. Dim rows are too thin to read.",InpReportMinN,g_ts.all.n);
   else
      fnd="Nothing with a big enough sample to call yet. Dim rows are too thin to read.";
}
//+------------------------------------------------------------------+
