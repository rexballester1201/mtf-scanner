//+------------------------------------------------------------------+
//|                                                   AB_History.mqh |
//|                   AstroBot MTF Scanner - v6.93 / SIGNAL HISTORY  |
//|                                                                  |
//| What the ensemble said 15 minutes, 30 minutes, 1 hour, 4 hours    |
//| and 1 day ago - and where price went since each of those.         |
//|                                                                  |
//| RECOMPUTED, NOT RECORDED. The obvious build is to store every     |
//| signal as it is emitted and look it up later. That only covers    |
//| time the EA has been running: on a fresh attach there is no       |
//| "1 day ago" for a day, and every restart wipes it. So instead the |
//| same AnalyzeOne() that produces the live panel is run again, but  |
//| reading from the bar that was LAST CLOSED at each past moment.    |
//| Every vote here reads closed bars only, and a closed bar never    |
//| changes, so this reproduces exactly what the panel would have     |
//| shown then. Available the moment the EA loads, and it survives    |
//| restarts because there is nothing to lose.                        |
//|                                                                  |
//| NO LOOK-AHEAD. For each timeframe, iBarShift finds the bar that   |
//| CONTAINED the past moment T - the one still forming at T - and    |
//| the reading comes from the bar before it. At T that was the       |
//| newest closed bar, so nothing after T can leak in. "Price then"   |
//| is the close of the last M1 bar completed by T, for the same      |
//| reason. The "now" row goes through this identical path rather     |
//| than borrowing the live numbers, so every row in the strip is     |
//| computed the same way and can be compared directly.               |
//|                                                                  |
//| GRADED ON FOUR CHECKS, NOT FIVE. The verdict card also checks     |
//| the session filter, the news filter and the spread. None of those |
//| can be reconstructed for a past moment - the news calendar is     |
//| read live and the spread at T was never kept - so every row here, |
//| "now" included, is graded on the four that can: the signal TF     |
//| agrees, its EMA stack is aligned, it is not ranging, and the      |
//| confirm TF agrees. "now" can therefore read one grade better than |
//| the verdict card when a filter is blocking. That is the honest    |
//| difference, not a bug.                                            |
//|                                                                  |
//| WHAT "RIGHT" DOES AND DOES NOT PROVE. A row is "right" when price |
//| has moved in the direction it called since it was made. In a      |
//| strong trend that is still running, a trend-following ensemble    |
//| will look right in hindsight almost by construction: it agrees    |
//| with trends, and you are only looking because the trend held.     |
//| That makes this strip a good CONSISTENCY check - has the signal   |
//| been pointing the same way long enough to trust that it is not a  |
//| one-bar flicker - and a weak RELIABILITY check. Reliability is    |
//| what the year of journal data measured, across trends that        |
//| failed as well as ones that held.                                 |
//|                                                                  |
//| COST. Six rows x seven timeframes = 42 AnalyzeOne calls, run once |
//| per new M1 bar rather than every second. The "since" column uses  |
//| the live bid at render time, so it moves every second anyway.     |
//+------------------------------------------------------------------+

#define MAX_HIST_LB   6
#define MAX_HIST_ROWS (MAX_HIST_LB+2)       // now + lookbacks + summary

struct HistRow
{
   int      mins;          // 0 = now
   datetime at;
   bool     ok;
   int      readyN;        // timeframes that had enough history at that moment
   double   buyPct;
   int      dir;           // aggregate, -2..+2, same bands as the live panel
   string   label;
   int      act;           // +1 BUY, -1 SELL, 0 WAIT - what the panel would have told you
   string   grade;         // A / B / C / "-", on the four reconstructable checks
   double   priceThen;
};

HistRow  g_hist[MAX_HIST_LB+1];            // [0] now, then each lookback
int      g_histN     = 0;
int      g_histMins[MAX_HIST_LB];
int      g_histCfgN  = 0;
datetime g_histBar   = 0;

int Hist_BlockH()
{
   if(!InpShowHistory || g_histCfgN<=0) return 0;
   return 20 + (2+g_histCfgN)*14;          // header, then now + lookbacks + summary
}

void Hist_Init()
{
   g_histCfgN=0; g_histN=0; g_histBar=0;
   if(!InpShowHistory) return;

   string parts[];
   const int n=StringSplit(InpHistLookbacks,',',parts);
   for(int i=0;i<n && g_histCfgN<MAX_HIST_LB;i++)
   {
      string s=parts[i]; StringTrimLeft(s); StringTrimRight(s);
      const int m=(int)StringToInteger(s);
      if(m>0) g_histMins[g_histCfgN++]=m;
   }
   //--- nearest first, whatever order they were typed in
   for(int i=1;i<g_histCfgN;i++)
   {
      const int key=g_histMins[i]; int j=i-1;
      while(j>=0 && g_histMins[j]>key){ g_histMins[j+1]=g_histMins[j]; j--; }
      g_histMins[j+1]=key;
   }
   if(g_histCfgN==0)
      Print("SIGNAL HISTORY: InpHistLookbacks holds no valid minute values - strip hidden");
}

string Hist_Span(const int m)
{
   if(m<=0)      return "now";
   if(m%1440==0) return IntegerToString(m/1440)+"d";
   if(m%60==0)   return IntegerToString(m/60)+"h";
   return IntegerToString(m)+"m";
}

//+------------------------------------------------------------------+
//| The ensemble exactly as it stood at time T.                       |
//+------------------------------------------------------------------+
void Hist_At(const datetime T,HistRow &row)
{
   row.ok=false; row.readyN=0; row.buyPct=50; row.dir=0;
   row.label="no data"; row.act=0; row.grade="-";

   TFResult R[TF_COUNT];
   double oNet=0,oMax=0;
   for(int i=0;i<TF_COUNT;i++)
   {
      R[i].ready=false; R[i].dir=0; R[i].stkS=0; R[i].ranging=false; R[i].adx=0;
      //--- the bar still forming at T; the reading comes from the one before it
      const int s=iBarShift(_Symbol,g_tf[i],T,false);
      if(s<0) continue;
      AnalyzeOne(_Symbol,g_tf[i],g_H[i],R[i],s+1);
      if(!R[i].ready) continue;

      row.readyN++;
      const double regime=R[i].ranging ? MathMax(0.0,MathMin(1.0,InpRangingWeight)) : 1.0;
      oNet+=(R[i].bullPts-R[i].bearPts)*g_tfW[i]*regime;
      oMax+=MAX_PTS*g_tfW[i];
   }
   if(oMax<=0) return;

   row.ok=true;
   row.buyPct=MathMax(0.0,MathMin(100.0,50.0+(oNet/oMax)*50.0));

   //--- the same bands AnalyzeAll uses for the live gauge
   if(row.buyPct>=65)      { row.dir= 2; row.label="BULLISH";      }
   else if(row.buyPct>=55) { row.dir= 1; row.label="Weak Bullish"; }
   else if(row.buyPct> 45) { row.dir= 0; row.label="NEUTRAL";      }
   else if(row.buyPct> 35) { row.dir=-1; row.label="Weak Bearish"; }
   else                    { row.dir=-2; row.label="BEARISH";      }

   int want=0;
   if(row.buyPct>=InpAutoBuyPct)       want= 1;
   else if(row.buyPct<=InpAutoSellPct) want=-1;
   if(want==0){ row.act=0; row.grade="-"; return; }

   //--- the four checks a past moment can actually answer
   const int si=SigIdx(), ci=ConfirmIdx();
   int pass=0,total=0;
   total++; if(R[si].ready && (want>0 ? R[si].dir >0 : R[si].dir <0)) pass++;
   total++; if(R[si].ready && (want>0 ? R[si].stkS>0 : R[si].stkS<0)) pass++;
   total++; if(R[si].ready && !R[si].ranging) pass++;
   if(InpVerdictUseConfirm)
   { total++; if(R[ci].ready && (want>0 ? R[ci].dir>0 : R[ci].dir<0)) pass++; }

   const int miss=total-pass;
   row.grade=(miss==0 ? "A" : miss==1 ? "B" : miss==2 ? "C" : "-");
   //--- like the verdict card: too many failed checks is a WAIT, not a call
   row.act=(miss<=2 ? want : 0);
}

//--- once per M1 bar: the lookback moments slide by a minute, nothing sooner
void Hist_Update()
{
   if(!InpShowHistory || g_histCfgN<=0) return;
   const datetime bt=iTime(_Symbol,PERIOD_M1,0);
   if(bt!=0 && bt==g_histBar && g_histN>0) return;
   g_histBar=bt;

   const datetime now=TimeCurrent();
   g_histN=0;

   //--- "now" goes through the same path as every past row
   g_hist[0].mins=0; g_hist[0].at=now;
   Hist_At(now,g_hist[0]);
   g_hist[0].priceThen=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   g_histN=1;

   for(int k=0;k<g_histCfgN;k++)
   {
      const datetime T=now-(datetime)(g_histMins[k]*60);
      HistRow r;
      r.mins=g_histMins[k]; r.at=T;
      Hist_At(T,r);
      //--- the last M1 bar COMPLETED by T - no look-ahead on price either
      const int s1=iBarShift(_Symbol,PERIOD_M1,T,false);
      r.priceThen=(s1>=0 ? iClose(_Symbol,PERIOD_M1,s1+1) : 0.0);
      g_hist[g_histN++]=r;
   }
}

//+------------------------------------------------------------------+
//| v6.94: one row's outcome, and the strip's summary. Shared by the  |
//| panel and the JSON feed, so the two can never disagree about      |
//| whether a call went its way.                                      |
//+------------------------------------------------------------------+
//--- "right", "wrong" or "no_call". mv is the price move since the reading,
//--- 0 when there is no price to compare against.
string Hist_Result(const HistRow &r,const double bid,double &mv)
{
   mv=(r.priceThen>0 ? bid-r.priceThen : 0.0);
   if(r.act==0 || r.priceThen<=0) return "no_call";
   return (((r.act>0 && mv>0) || (r.act<0 && mv<0)) ? "right" : "wrong");
}

//--- held  : past rows on the same side as now (bull / bear / neutral)
//--- past  : past rows that had enough history to compare at all
//--- calls : past rows that made a BUY or SELL call
//--- right : calls where price has since moved the way they said
void Hist_Summary(const double bid,int &held,int &past,int &calls,int &right)
{
   held=0; past=0; calls=0; right=0;
   if(g_histN<=1) return;
   const int nowSide=(g_hist[0].dir>0 ? 1 : g_hist[0].dir<0 ? -1 : 0);
   for(int k=1;k<g_histN;k++)
   {
      const HistRow r=g_hist[k];
      if(!r.ok) continue;
      past++;
      const int side=(r.dir>0 ? 1 : r.dir<0 ? -1 : 0);
      if(side==nowSide) held++;
      double mv=0;
      const string res=Hist_Result(r,bid,mv);
      if(res!="no_call"){ calls++; if(res=="right") right++; }
   }
}

//+------------------------------------------------------------------+
//| One panel row. The "since" column uses the live bid, so it moves  |
//| every second even though the readings refresh once a minute.      |
//+------------------------------------------------------------------+
void Hist_RowText(const int i,string &txt,color &c)
{
   txt=""; c=C_DIM;
   const int    dg =m_symbol.Digits();
   const double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);

   if(i<g_histN)
   {
      const HistRow r=g_hist[i];
      if(!r.ok)
      { txt=StringFormat("%-4s no history that far back",Hist_Span(r.mins)); return; }

      const string act    =(r.act>0 ? "BUY" : r.act<0 ? "SELL" : "WAIT");
      const string partial=(r.readyN<TF_COUNT ? StringFormat("  (%d/%d TF)",r.readyN,TF_COUNT) : "");
      c=(r.act>0 ? C_BULL : r.act<0 ? C_BEAR : C_DIM);

      if(r.mins==0)
      {
         txt=StringFormat("%-4s %-4s %-1s %3.0f%%  %-13s @%.*f%s",
                          "now",act,r.grade,r.buyPct,r.label,dg,bid,partial);
         return;
      }
      double mv=0;
      string res=Hist_Result(r,bid,mv);
      if(res=="no_call") res="no call";
      txt=StringFormat("%-4s %-4s %-1s %3.0f%%  %-13s @%.*f  %+.*f  %s%s",
                       Hist_Span(r.mins),act,r.grade,r.buyPct,r.label,
                       dg,r.priceThen,dg,mv,res,partial);
      return;
   }

   if(i==g_histN && g_histN>1)
   {
      //--- the two questions the strip exists to answer
      int held=0,past=0,calls=0,right=0;
      Hist_Summary(bid,held,past,calls,right);
      txt=StringFormat("same side as now in %d/%d   |   calls that moved their way: %d of %d",
                       held,past,right,calls);
      c=C_TEXT;
   }
}
//+------------------------------------------------------------------+
