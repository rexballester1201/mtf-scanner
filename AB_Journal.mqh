//+------------------------------------------------------------------+
//|                                                   AB_Journal.mqh |
//|                     AstroBot MTF Scanner - v6.1 / D1 JOURNAL     |
//|                                                                  |
//| One CSV, two kinds of row, one file per symbol and magic:         |
//|                                                                  |
//|   ENTRY  written the moment an auto order fills, with the whole   |
//|          state of the ensemble that produced it: every vote sign  |
//|          on every timeframe, per-timeframe bias / ADX / ranging,  |
//|          the overall bias, spread as points and as a share of     |
//|          ATR, session and news flags, the volatility ratio, the   |
//|          stop distance, the lot, the money at risk and the setup  |
//|          line the engine printed.                                 |
//|   EXIT   written from the closing deal, with the same context as  |
//|          it stood at the exit plus the outcome: P/L in money and  |
//|          in R, MFE and MAE in points and in R, bars and seconds   |
//|          held, and how the position left (stop / target / engine  |
//|          / hand). A partial close produces one EXIT row of its    |
//|          own, with R scaled to the fraction closed.               |
//|                                                                  |
//| Join the two on pos_id. Everything from "which gate earns its     |
//| keep" to a model gate starts from this file; nothing else in the  |
//| EA records why a trade was taken.                                 |
//|                                                                  |
//| R IS THE INITIAL RISK. sl_pts and risk_money on both rows are the |
//| stop distance and money at risk AT ENTRY, never the trailed stop, |
//| so pl_r, mfe_r and mae_r are honest multiples of what was staked. |
//| A position adopted after a restart recovers that distance from   |
//| the opening order in the history (ORDER_SL), and from_start=0    |
//| marks that its MFE/MAE only cover the time since adoption.        |
//|                                                                  |
//| WHERE. Live and single tester runs: <Common>\Files\AstroBot\      |
//| Journal_<symbol>_<magic>_v1.csv (tester runs add "_tester" and   |
//| start the file over on every run; live appends). Optimisation    |
//| passes write nothing unless InpOptJournalFrames is on, in which  |
//| case each agent writes a local file and ships it to the terminal |
//| as a frame - see AB_Tester.mqh. ANSI, comma-separated, one       |
//| header line; text fields have commas and line breaks removed.    |
//|                                                                  |
//| TRACKING RUNS EVEN WHEN THE FILE IS OFF. The per-position MFE /   |
//| MAE / initial-R tracker costs a few comparisons per tick and also |
//| feeds the R-multiple list the tester criterion uses, so it is    |
//| always on; InpJournal only decides whether rows reach a file.    |
//|                                                                  |
//| COLUMNS (114):                                                    |
//|   ver event time time_unix pos_id symbol magic side volume price  |
//|   sl tp sl_pts risk_money risk_pct spread_pts spread_atr atr_sig  |
//|   bias bias_dir align_up align_nt align_dn tf_ready               |
//|   <TF>_pct <TF>_adx <TF>_rng <TF>_stk <TF>_slp <TF>_dmi <TF>_rsi  |
//|   <TF>_don <TF>_ad                     (x M1 M5 M15 M30 H1 H4 D1) |
//|   hour dow session_block news_block vol_ratio sig_tf trail_mode   |
//|   trail_tf n_open_other open_risk_other_pct equity balance dd_pct |
//|   reason pl pl_r mfe_pts mfe_r mae_pts mae_r bars_held secs_held  |
//|   entry_price entry_time from_start entry_reason exit_kind        |
//|   On an ENTRY row `reason` is the setup line and the outcome      |
//|   fields are empty; on an EXIT row `reason` is how the deal       |
//|   closed and `entry_reason` echoes the setup line. exit_kind      |
//|   (v2) separates what the broker lumps together: INIT_STOP,       |
//|   TRAIL_STOP (any stop the engine had moved, break-even included),|
//|   TP, STOPOUT, MANUAL, ENGINE:<why> for the engine's own closes.  |
//+------------------------------------------------------------------+

#define AB_JOURNAL_SCHEMA "v2"   // v2 (6.3): + exit_kind

struct ABTrack
{
   ulong    posId;         // POSITION_IDENTIFIER == DEAL_POSITION_ID: the join key
   datetime openTime;
   double   openPrice;
   bool     isBuy;
   double   volume;        // volume at entry
   double   slPts;         // stop distance at entry, in points - the R unit
   double   riskMoney;     // money at risk at entry - the R unit in currency
   double   mfePts;        // best excursion so far, points (>= 0)
   double   maePts;        // worst excursion so far, points (>= 0)
   double   lastSL;        // the stop as last seen, so the EXIT row can say where it ended
   bool     fromStart;     // tracked since the fill; false = adopted after a restart
   datetime missingSince;  // first tick the position was not found (grace before pruning)
   string   why;           // the setup line at entry
};

ABTrack g_trk[];
double  g_closedR[];         // R multiple of every closing deal this session - the tester criterion reads it
bool    g_jrnOK    = false;  // the file is usable
string  g_jrnFile  = "";
int     g_jrnFlags = 0;

//--- rows reach a file only when this says so; the tracker ignores it
bool Journal_Enabled()
{
   if(g_dupInstance) return false;                  // v6.2/E1: the owner journals; a duplicate would write every close twice
   if(InpJournal == JOURNAL_OFF) return false;
   if((bool)MQLInfoInteger(MQL_FRAME_MODE)) return false;
   if((bool)MQLInfoInteger(MQL_OPTIMIZATION)) return InpOptJournalFrames;
   if((bool)MQLInfoInteger(MQL_TESTER)) return (InpJournal == JOURNAL_LIVE_TEST);
   return true;
}

string Journal_SafeSymbol()
{
   string s = _Symbol;
   const string bad[10] = {"\\", "/", ":", "*", "?", "\"", "<", ">", "|", " "};
   for(int i=0;i<10;i++) StringReplace(s, bad[i], "_");
   return s;
}

//--- text fields: one line, no commas, ASCII dashes
string Journal_Clean(string s)
{
   StringReplace(s, ",",  ";");
   StringReplace(s, "\r", " ");
   StringReplace(s, "\n", " ");
   StringReplace(s, ShortToString(0x2014), "-");   // em dash, which the setup lines use
   StringReplace(s, ShortToString(0x2013), "-");   // en dash
   return s;
}

void Journal_Blank(ABTrack &t)
{
   t.posId=0; t.openTime=0; t.openPrice=0; t.isBuy=true; t.volume=0; t.slPts=0; t.riskMoney=0;
   t.mfePts=0; t.maePts=0; t.lastSL=0; t.fromStart=true; t.missingSince=0; t.why="";
}

int Journal_Find(const ulong posId)
{
   for(int i=ArraySize(g_trk)-1;i>=0;i--) if(g_trk[i].posId==posId) return i;
   return -1;
}
int Journal_Add(const ABTrack &t)
{
   const int n=ArraySize(g_trk);
   ArrayResize(g_trk,n+1);
   g_trk[n]=t;
   return n;
}
void Journal_Remove(const int k)
{
   const int n=ArraySize(g_trk);
   if(k<0 || k>=n) return;
   for(int i=k;i<n-1;i++) g_trk[i]=g_trk[i+1];
   ArrayResize(g_trk,n-1);
}
bool Journal_PositionExists(const ulong posId)
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      if(!m_position.SelectByIndex(i)) continue;
      if((ulong)m_position.Identifier()==posId) return true;
   }
   return false;
}
bool Journal_ReadPosSLTP(const ulong posId,double &sl,double &tp)
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      if(!m_position.SelectByIndex(i)) continue;
      if((ulong)m_position.Identifier()!=posId) continue;
      sl=m_position.StopLoss(); tp=m_position.TakeProfit();
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Fill a tracker from the position's own history: the opening deal  |
//| for time / price / volume / side, the opening ORDER for the stop  |
//| that was requested at entry - the initial R, even after a restart |
//| and even after the trail has moved the live stop.                 |
//+------------------------------------------------------------------+
bool Journal_FillFromHistory(ABTrack &t)
{
   if(t.posId==0 || !HistorySelectByPosition((long)t.posId)) return false;

   bool found=false;
   const int nd=HistoryDealsTotal();
   for(int i=0;i<nd;i++)
   {
      const ulong d=HistoryDealGetTicket(i);
      if(d==0) continue;
      if(HistoryDealGetInteger(d,DEAL_ENTRY)!=DEAL_ENTRY_IN) continue;
      t.openTime =(datetime)HistoryDealGetInteger(d,DEAL_TIME);
      t.openPrice=HistoryDealGetDouble(d,DEAL_PRICE);
      t.volume   =HistoryDealGetDouble(d,DEAL_VOLUME);
      t.isBuy    =(HistoryDealGetInteger(d,DEAL_TYPE)==DEAL_TYPE_BUY);
      found=true;
      break;
   }
   if(!found) return false;

   double sl=0;
   const int no=HistoryOrdersTotal();
   for(int i=0;i<no;i++)
   {
      const ulong o=HistoryOrderGetTicket(i);
      if(o==0) continue;
      if((ulong)HistoryOrderGetInteger(o,ORDER_POSITION_ID)!=t.posId) continue;
      sl=HistoryOrderGetDouble(o,ORDER_SL);
      break;                                   // chronological: the first order for this id opened it
   }
   const double pt=m_symbol.Point();
   t.slPts=(sl>0 && pt>0) ? MathAbs(t.openPrice-sl)/pt : 0.0;
   if(t.slPts<=0) t.slPts=AutoSLPts();         // stripped by the broker, or never there: today's distance is the best estimate
   t.riskMoney=LossPerLot(t.slPts)*t.volume;
   return true;
}

//--- adopt the position m_position currently points at
int Journal_AdoptSelected()
{
   ABTrack t; Journal_Blank(t);
   t.posId    =(ulong)m_position.Identifier();
   t.fromStart=false;
   t.why      ="adopted after restart";
   if(!Journal_FillFromHistory(t))
   {
      t.openTime =(datetime)m_position.Time();
      t.openPrice=m_position.PriceOpen();
      t.volume   =m_position.Volume();
      t.isBuy    =(m_position.PositionType()==POSITION_TYPE_BUY);
      const double sl=m_position.StopLoss(), pt=m_symbol.Point();
      t.slPts    =(sl>0 && pt>0) ? MathAbs(t.openPrice-sl)/pt : AutoSLPts();
      t.riskMoney=LossPerLot(t.slPts)*t.volume;
   }
   t.lastSL=m_position.StopLoss();
   return Journal_Add(t);
}

void Journal_AdoptOpen()
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      if(!m_position.SelectByIndex(i)) continue;
      if(m_position.Symbol()!=_Symbol || !IsAutoPos(m_position.Magic())) continue;
      if(Journal_Find((ulong)m_position.Identifier())>=0) continue;
      Journal_AdoptSelected();
   }
}

//+------------------------------------------------------------------+
//| File plumbing                                                     |
//+------------------------------------------------------------------+
string Journal_Header()
{
   string h="ver,event,time,time_unix,pos_id,symbol,magic,side,volume,price,sl,tp,sl_pts,risk_money,risk_pct,spread_pts,spread_atr,atr_sig";
   h+=",bias,bias_dir,align_up,align_nt,align_dn,tf_ready";
   for(int i=0;i<TF_COUNT;i++)
   {
      const string n=g_tfName[i];
      h+=StringFormat(",%s_pct,%s_adx,%s_rng,%s_stk,%s_slp,%s_dmi,%s_rsi,%s_don,%s_ad",n,n,n,n,n,n,n,n,n);
   }
   h+=",hour,dow,session_block,news_block,vol_ratio,sig_tf,trail_mode,trail_tf,n_open_other,open_risk_other_pct,equity,balance,dd_pct";
   h+=",reason,pl,pl_r,mfe_pts,mfe_r,mae_pts,mae_r,bars_held,secs_held,entry_price,entry_time,from_start,entry_reason,exit_kind";
   return h;
}

void Journal_Init()
{
   ArrayResize(g_trk,0);
   ArrayResize(g_closedR,0);
   g_jrnOK=false;

   //--- the tracker adopts whatever is already open, file or no file
   Journal_AdoptOpen();

   if(!Journal_Enabled())
   {
      Print("JOURNAL: off (",(g_dupInstance ? "duplicate instance" : EnumToString(InpJournal)),
            ((bool)MQLInfoInteger(MQL_OPTIMIZATION) ? ", optimisation pass" : ""),")");
      return;
   }

   const bool tester=(bool)MQLInfoInteger(MQL_TESTER);
   const bool opt   =(bool)MQLInfoInteger(MQL_OPTIMIZATION);
   if(opt)
   {
      //--- agent-local, one file per pass, shipped to the terminal as a frame
      g_jrnFile =StringFormat("AstroBot\\Journal_pass_%s.csv",AB_JOURNAL_SCHEMA);
      g_jrnFlags=FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_SHARE_READ;
   }
   else
   {
      g_jrnFile =StringFormat("AstroBot\\Journal_%s_%I64u_%s%s.csv",
                              Journal_SafeSymbol(),InpAutoMagic,AB_JOURNAL_SCHEMA,(tester ? "_tester" : ""));
      g_jrnFlags=FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_SHARE_READ|FILE_COMMON;
   }

   //--- tester runs start the file over; live appends and writes the header once
   const int  common=(g_jrnFlags & FILE_COMMON);
   const bool fresh =(tester || !FileIsExist(g_jrnFile,common));
   const int  h=FileOpen(g_jrnFile,(fresh ? (g_jrnFlags & ~FILE_READ) : g_jrnFlags));
   if(h==INVALID_HANDLE)
   {
      PrintFormat("JOURNAL: cannot open %s (error %d) - rows will not be written",g_jrnFile,GetLastError());
      return;
   }
   if(fresh) FileWriteString(h,Journal_Header()+"\r\n");
   FileClose(h);
   g_jrnOK=true;

   const string where=(common!=0)
                      ? TerminalInfoString(TERMINAL_COMMONDATA_PATH)+"\\Files\\"+g_jrnFile
                      : TerminalInfoString(TERMINAL_DATA_PATH)+"\\MQL5\\Files\\"+g_jrnFile;
   PrintFormat("JOURNAL: %s -> %s",(fresh ? "new file" : "appending"),where);
}

void Journal_WriteLine(const string line)
{
   if(!g_jrnOK) return;
   const int h=FileOpen(g_jrnFile,g_jrnFlags);
   if(h==INVALID_HANDLE)
   {
      PrintFormat("JOURNAL: write failed, error %d (is the file open elsewhere?)",GetLastError());
      return;
   }
   FileSeek(h,0,SEEK_END);
   FileWriteString(h,line+"\r\n");
   FileClose(h);
}

//+------------------------------------------------------------------+
//| Row fragments. Header and fragments are kept adjacent on purpose: |
//| a column added to one must be added to the other.                 |
//+------------------------------------------------------------------+
string Journal_Common(const string ev,const datetime when,const ulong posId,const bool isBuy,
                      const double volume,const double price,const double sl,const double tp,
                      const double slPts,const double riskMoney)
{
   const int    dg=m_symbol.Digits();
   const double eq=AccountInfoDouble(ACCOUNT_EQUITY);
   const int    spread=(int)SymbolInfoInteger(_Symbol,SYMBOL_SPREAD);
   const double atr=AutoATR(), pt=m_symbol.Point();
   const double spreadATR=(atr>0 && pt>0) ? spread*pt/atr : 0.0;
   return StringFormat("%s,%s,%s,%I64d,%I64u,%s,%I64u,%s,%.2f,%.*f,%s,%s,%.1f,%.2f,%.3f,%d,%.4f,%.*f",
                       AB_VERSION,ev,TimeToString(when,TIME_DATE|TIME_SECONDS),(long)when,posId,
                       _Symbol,InpAutoMagic,(isBuy ? "BUY" : "SELL"),volume,dg,price,
                       (sl>0 ? DoubleToString(sl,dg) : ""),(tp>0 ? DoubleToString(tp,dg) : ""),
                       slPts,riskMoney,(eq>0 ? riskMoney/eq*100.0 : 0.0),
                       spread,spreadATR,dg,atr);
}

string Journal_Context(const int nOpenOther,const double openRiskOther)
{
   string s=StringFormat("%.2f,%d,%d,%d,%d",g_overallBuyPct,g_overallDir,g_up,g_nt,g_dn);
   int mask=0; string tf="";
   for(int i=0;i<TF_COUNT;i++)
   {
      if(g_R[i].ready) mask|=(1<<i);
      tf+=StringFormat(",%.1f,%.1f,%d,%d,%d,%d,%d,%d,%d",
                       (g_R[i].ready ? g_R[i].buyPct : 50.0),
                       (g_R[i].ready ? g_R[i].adx    : 0.0),
                       ((g_R[i].ready && g_R[i].ranging) ? 1 : 0),
                       g_R[i].stkS,g_R[i].slpS,g_R[i].dmiS,g_R[i].rsiS,g_R[i].donS,g_R[i].adS);
   }
   s+=StringFormat(",%d",mask)+tf;

   MqlDateTime dt; TimeToStruct(TimeCurrent(),dt);
   s+=StringFormat(",%d,%d,%d,%d,%.3f,%s,%s,%s,%d,%.2f,%.2f,%.2f,%.2f",
                   dt.hour,dt.day_of_week,(g_sessionBlock ? 1 : 0),(g_newsBlock ? 1 : 0),g_volRatio,
                   g_tfName[SigIdx()],TrailModeName(g_trailMode),g_tfName[TrailIdx()],
                   nOpenOther,openRiskOther,
                   AccountInfoDouble(ACCOUNT_EQUITY),AccountInfoDouble(ACCOUNT_BALANCE),CurrentDDPct());
   return s;
}

string Journal_Tail(const bool isExit,const string reason,const double pl,const double plR,
                    const ABTrack &t,const int barsHeld,const int secsHeld,const string kind)
{
   const int dg=m_symbol.Digits();
   if(!isExit)
      return StringFormat("%s,,,,,,,,,%.*f,%s,%d,,",
                          Journal_Clean(reason),dg,t.openPrice,
                          TimeToString(t.openTime,TIME_DATE|TIME_SECONDS),(t.fromStart ? 1 : 0));
   const double mfeR=(t.slPts>0 ? t.mfePts/t.slPts : 0.0);
   const double maeR=(t.slPts>0 ? t.maePts/t.slPts : 0.0);
   return StringFormat("%s,%.2f,%.3f,%.1f,%.3f,%.1f,%.3f,%d,%d,%.*f,%s,%d,%s,%s",
                       Journal_Clean(reason),pl,plR,t.mfePts,mfeR,t.maePts,maeR,barsHeld,secsHeld,
                       dg,t.openPrice,TimeToString(t.openTime,TIME_DATE|TIME_SECONDS),(t.fromStart ? 1 : 0),
                       Journal_Clean(t.why),kind);
}

//--- v6.3/F3: what the broker's "stop loss" actually was, and which of the
//--- engine's own reasons an EXPERT close had
string Journal_ExitKind(const long rcode,const ABTrack &t,const double plR)
{
   switch((ENUM_DEAL_REASON)rcode)
   {
      case DEAL_REASON_TP:     return "TP";
      case DEAL_REASON_SO:     return "STOPOUT";
      case DEAL_REASON_EXPERT: return "ENGINE:"+(StringLen(g_closeTag)>0 ? Journal_Clean(g_closeTag) : "unknown");
      case DEAL_REASON_CLIENT:
      case DEAL_REASON_MOBILE:
      case DEAL_REASON_WEB:    return "MANUAL";
      case DEAL_REASON_SL:
      {
         const double pt=m_symbol.Point();
         if(t.lastSL>0 && pt>0 && t.slPts>0)
         {
            const double initSL=(t.isBuy ? t.openPrice-t.slPts*pt : t.openPrice+t.slPts*pt);
            return ((MathAbs(t.lastSL-initSL)<=3.0*pt) ? "INIT_STOP" : "TRAIL_STOP");
         }
         return (plR<=-0.5 ? "INIT_STOP" : "TRAIL_STOP");
      }
   }
   return "OTHER";
}

//+------------------------------------------------------------------+
//| Events                                                            |
//+------------------------------------------------------------------+
//--- the position id of the order m_trade just filled
ulong Journal_ResolvePosId()
{
   const ulong deal=m_trade.ResultDeal();
   if(deal>0 && HistoryDealSelect(deal))
   {
      const ulong pid=(ulong)HistoryDealGetInteger(deal,DEAL_POSITION_ID);
      if(pid>0) return pid;
   }
   //--- POSITION_IDENTIFIER is the ticket of the order that opened the position
   return m_trade.ResultOrder();
}

//--- called by PlaceAuto right after a successful SendEntry
void Journal_OnEntry(const bool isBuy,const double lot,const double slPts,const double tpPts,
                     const string why,const int nOpenBefore,const double openRiskBefore)
{
   ABTrack t; Journal_Blank(t);
   //--- v6.2: from the fill snapshot SendEntry took before any post-fill
   //--- modify could overwrite m_trade's last result
   t.posId    =g_lastFillPosId;
   const double fill=g_lastFillPrice;
   const double vol =g_lastFillVolume;
   const double pt  =m_symbol.Point();
   t.openTime =TimeCurrent();
   t.openPrice=(fill>0 ? fill : (isBuy ? m_symbol.Ask() : m_symbol.Bid()));
   t.isBuy    =isBuy;
   t.volume   =(vol>0 ? vol : lot);
   t.slPts    =slPts;
   t.riskMoney=LossPerLot(slPts)*t.volume;
   t.fromStart=true;
   t.why      =why;

   //--- the stop and target as the server holds them, else as requested
   double sl=0, tp=0;
   if(t.posId==0 || !Journal_ReadPosSLTP(t.posId,sl,tp))
   {
      sl=(isBuy ? t.openPrice-slPts*pt : t.openPrice+slPts*pt);
      tp=(tpPts>0 ? (isBuy ? t.openPrice+tpPts*pt : t.openPrice-tpPts*pt) : 0.0);
   }
   t.lastSL=sl;
   Journal_Add(t);

   if(!g_jrnOK) return;
   const string row=Journal_Common("ENTRY",t.openTime,t.posId,isBuy,t.volume,t.openPrice,sl,tp,slPts,t.riskMoney)
                   +","+Journal_Context(nOpenBefore,openRiskBefore)
                   +","+Journal_Tail(false,why,0.0,0.0,t,0,0,"");
   Journal_WriteLine(row);
}

//--- backstop from OnTradeTransaction: an IN deal for an auto position
//--- nobody is tracking (the id could not be resolved at fill time, or the
//--- entry happened outside PlaceAuto). The deal must already be selected.
void Journal_OnDealIn(const ulong deal)
{
   const ulong pid=(ulong)HistoryDealGetInteger(deal,DEAL_POSITION_ID);
   if(pid==0 || Journal_Find(pid)>=0) return;
   const int k=Journal_Find(0);
   if(k>=0){ g_trk[k].posId=pid; return; }      // PlaceAuto's tracker, now with its id

   ABTrack t; Journal_Blank(t);
   t.posId    =pid;
   t.fromStart=true;
   t.why      ="untracked entry";
   t.openTime =(datetime)HistoryDealGetInteger(deal,DEAL_TIME);
   t.openPrice=HistoryDealGetDouble(deal,DEAL_PRICE);
   t.volume   =HistoryDealGetDouble(deal,DEAL_VOLUME);
   t.isBuy    =(HistoryDealGetInteger(deal,DEAL_TYPE)==DEAL_TYPE_BUY);
   t.slPts    =AutoSLPts();
   t.riskMoney=LossPerLot(t.slPts)*t.volume;
   Journal_Add(t);
}

//--- every tick, before ManagePositions can remove anything: MFE / MAE and
//--- the last seen stop for every auto position; adopt strangers; prune
//--- trackers whose position has been gone long enough that its EXIT deal
//--- is not coming (a transaction missed across a reconnect).
void Journal_TrackAll()
{
   if(ArraySize(g_trk)==0 && PositionsTotal()==0) return;
   const double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   const double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   const double pt =m_symbol.Point();
   if(bid<=0 || ask<=0 || pt<=0) return;
   const datetime now=TimeCurrent();

   int seen[]; ArrayResize(seen,ArraySize(g_trk)); ArrayInitialize(seen,0);
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      if(!m_position.SelectByIndex(i)) continue;
      if(m_position.Symbol()!=_Symbol || !IsAutoPos(m_position.Magic())) continue;
      const ulong pid=(ulong)m_position.Identifier();
      int k=Journal_Find(pid);
      if(k<0)
      {
         k=Journal_AdoptSelected();
         ArrayResize(seen,ArraySize(g_trk));
      }
      seen[k]=1;
      const double exc=(g_trk[k].isBuy ? (bid-g_trk[k].openPrice)/pt : (g_trk[k].openPrice-ask)/pt);
      if(exc>g_trk[k].mfePts)  g_trk[k].mfePts=exc;
      if(-exc>g_trk[k].maePts) g_trk[k].maePts=-exc;
      g_trk[k].lastSL=m_position.StopLoss();
      g_trk[k].missingSince=0;
   }
   for(int k=ArraySize(g_trk)-1;k>=0;k--)
   {
      if(k<ArraySize(seen) && seen[k]==1) continue;
      if(g_trk[k].missingSince==0){ g_trk[k].missingSince=now; continue; }
      if(now-g_trk[k].missingSince>120) Journal_Remove(k);
   }
}

//--- called by OnTradeTransaction for an auto OUT / OUT_BY deal, which the
//--- caller has already selected. Reads the deal BEFORE touching the
//--- history selection, because Journal_FillFromHistory changes it.
void Journal_OnExit(const ulong deal)
{
   const ulong    pid   =(ulong)HistoryDealGetInteger(deal,DEAL_POSITION_ID);
   const double   vol   =HistoryDealGetDouble(deal,DEAL_VOLUME);
   const double   price =HistoryDealGetDouble(deal,DEAL_PRICE);
   const double   pl    =HistoryDealGetDouble(deal,DEAL_PROFIT)
                        +HistoryDealGetDouble(deal,DEAL_SWAP)
                        +HistoryDealGetDouble(deal,DEAL_COMMISSION);
   const datetime when  =(datetime)HistoryDealGetInteger(deal,DEAL_TIME);
   const long     dtype =HistoryDealGetInteger(deal,DEAL_TYPE);
   const long     rcode =HistoryDealGetInteger(deal,DEAL_REASON);
   const string   reason=DealReasonName(rcode);

   int k=Journal_Find(pid);
   if(k<0)
   {
      ABTrack t; Journal_Blank(t);
      t.posId=pid; t.fromStart=false; t.why="untracked";
      if(!Journal_FillFromHistory(t))
      {
         t.isBuy    =(dtype==DEAL_TYPE_SELL);      // a long leaves through a SELL deal
         t.openTime =when;
         t.openPrice=price;
         t.volume   =vol;
         t.slPts    =AutoSLPts();
         t.riskMoney=LossPerLot(t.slPts)*vol;
      }
      k=Journal_Add(t);
   }

   //--- the exit print is an excursion too: a stop filled past the worst tick,
   //--- or a target filled at the best, belongs in MAE / MFE
   const double pt=m_symbol.Point();
   if(pt>0)
   {
      const double exc=(g_trk[k].isBuy ? (price-g_trk[k].openPrice)/pt : (g_trk[k].openPrice-price)/pt);
      if(exc>g_trk[k].mfePts)  g_trk[k].mfePts=exc;
      if(-exc>g_trk[k].maePts) g_trk[k].maePts=-exc;
   }

   const double frac    =(g_trk[k].volume>0 ? vol/g_trk[k].volume : 1.0);
   const double riskPart=g_trk[k].riskMoney*frac;
   const double plR     =(riskPart>0 ? pl/riskPart : 0.0);

   //--- the R list the tester criterion reads, file or no file
   const int nr=ArraySize(g_closedR);
   ArrayResize(g_closedR,nr+1);
   g_closedR[nr]=plR;

   const bool still=Journal_PositionExists(pid);
   if(g_jrnOK)
   {
      const int barsN   =Bars(_Symbol,SigTF(),g_trk[k].openTime,when);
      const int barsHeld=(barsN>0 ? barsN-1 : 0);
      const int secsHeld=(int)(when-g_trk[k].openTime);
      int nb,ns; AutoPosCounts(nb,ns);
      const int nOther=MathMax(0,nb+ns-(still ? 1 : 0));
      const string kind=Journal_ExitKind(rcode,g_trk[k],plR);
      const string row=Journal_Common("EXIT",when,pid,g_trk[k].isBuy,vol,price,g_trk[k].lastSL,0.0,g_trk[k].slPts,riskPart)
                      +","+Journal_Context(nOther,OpenAutoRiskPct())
                      +","+Journal_Tail(true,reason,pl,plR,g_trk[k],barsHeld,secsHeld,kind);
      Journal_WriteLine(row);
   }
   if(!still) Journal_Remove(k);
}
//+------------------------------------------------------------------+
