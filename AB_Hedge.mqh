//+------------------------------------------------------------------+
//|                                                     AB_Hedge.mqh |
//|              AstroBot MTF Scanner - v6.8 / EXPOSURE AND HEDGING  |
//|                                                                  |
//| Two questions this answers, and one it deliberately refuses to.   |
//|                                                                  |
//| 1. WHAT AM I ACTUALLY LONG AND SHORT?                             |
//|                                                                  |
//|    Every FX pair is two currency bets. Long EURUSD is long EUR    |
//|    and short USD; long GBPUSD is long GBP and short USD. Hold     |
//|    both and you have not diversified, you have doubled a bet on   |
//|    the dollar. That is the commonest way a discretionary book     |
//|    ends up concentrated by accident, and it is invisible in a     |
//|    position list that shows four unrelated-looking tickets.       |
//|                                                                  |
//|    This is exact arithmetic, not statistics. Each position is     |
//|    split into its base and profit currency and the legs are       |
//|    summed. The unit is ACCOUNT CURRENCY PER 1% MOVE, which is     |
//|    comparable across pairs and metals alike, because it comes     |
//|    from the symbol's own tick value rather than from a notional   |
//|    that would need a conversion chain to mean anything.           |
//|                                                                  |
//| 2. WHAT WOULD OFFSET A POSITION I ALREADY HOLD?                   |
//|                                                                  |
//|    Correlation of returns across the watchlist, then the          |
//|    minimum-variance hedge size for the best-correlated pair.      |
//|    The ratio is |corr| x (exposure x volatility of the position)  |
//|    over (exposure x volatility of the hedge), so a WEAKER         |
//|    relationship gives a SMALLER hedge. That is the correct        |
//|    direction and the opposite of the common mistake: a loose      |
//|    correlation does not mean you need more of the hedge, it       |
//|    means the hedge does less and you should commit less to it.    |
//|                                                                  |
//| WHAT IT WILL NOT SAY IS THAT ANYTHING IS "HEDGED".                |
//|                                                                  |
//|    A correlation hedge is not a hedge. It is a bet that a         |
//|    relationship holds, which swaps directional risk for           |
//|    relationship risk. Correlations are unstable, and they         |
//|    converge toward 1 in a crisis - exactly when the hedge is      |
//|    being relied on. So every figure is shown with the window it   |
//|    was measured over and the judgement is left to the reader.     |
//|                                                                  |
//| THE ALIGNMENT TRAP, since this is where homemade correlation      |
//| code usually goes wrong: bar 50 on XAUUSD is not the same moment  |
//| as bar 50 on EURUSD. The symbols keep different sessions and have |
//| different gaps, so correlating by INDEX quietly compares          |
//| mismatched times and returns a confident, meaningless number.     |
//| Returns here are matched by TIMESTAMP with a two-pointer merge,   |
//| and a pair with too few overlapping bars reports no reading       |
//| rather than a number built from whatever happened to line up.     |
//+------------------------------------------------------------------+

#define MAX_CORR_SYM   (MAX_WATCH+1)
#define MAX_CORR_BARS  400
#define MAX_HEDGE_ROWS 4

//--- the correlation universe: the chart symbol first, then the watchlist
string   g_cName[MAX_CORR_SYM];
int      g_cN   [MAX_CORR_SYM];                   // usable returns fetched
datetime g_cTime[MAX_CORR_SYM][MAX_CORR_BARS];
double   g_cRet [MAX_CORR_SYM][MAX_CORR_BARS];
double   g_cSd  [MAX_CORR_SYM];                   // stdev of those returns
double   g_corr [MAX_CORR_SYM][MAX_CORR_SYM];
int      g_corrN     = 0;
int      g_corrPairs = 0;                         // overlapping bars on the last pair computed
datetime g_corrBar   = 0;

//--- currency exposure
string   g_ccyName[32];
double   g_ccyNet [32];
int      g_ccyN = 0;

//--- the lines the panel prints
string   g_hedgeRow[MAX_HEDGE_ROWS];
int      g_hedgeN = 0;
string   g_expoLine = "no open positions";

bool Hedge_Enabled(){ return InpShowHedge; }
int  Hedge_PanelRows(){ return Hedge_Enabled() ? (1+MAX_HEDGE_ROWS) : 0; }

//--- account currency gained or lost by ONE lot of `sym` on a 1% move.
//--- Built from tick value and tick size, both of which the broker states
//--- in account currency, so gold and yen crosses come out comparable
//--- without a conversion chain.
double ExpoPerLot(const string sym)
{
   const double tv=SymbolInfoDouble(sym,SYMBOL_TRADE_TICK_VALUE);
   const double ts=SymbolInfoDouble(sym,SYMBOL_TRADE_TICK_SIZE);
   const double px=SymbolInfoDouble(sym,SYMBOL_BID);
   if(tv<=0 || ts<=0 || px<=0) return 0.0;
   return (px*0.01)/ts*tv;
}

//+------------------------------------------------------------------+
//| Correlation                                                       |
//+------------------------------------------------------------------+
void Hedge_BuildUniverse()
{
   g_corrN=0;
   g_cName[g_corrN++]=_Symbol;
   for(int i=0;i<Watch_Count() && g_corrN<MAX_CORR_SYM;i++)
      g_cName[g_corrN++]=g_W[i].name;
}

//--- log returns, oldest first, tagged with the time of the bar they END on
bool Hedge_LoadReturns(const int s,const ENUM_TIMEFRAMES tf,const int bars)
{
   g_cN[s]=0; g_cSd[s]=0;
   MqlRates rr[];
   const int want=MathMin(MAX_CORR_BARS,MathMax(20,bars))+1;
   const int n=CopyRates(g_cName[s],tf,0,want,rr);
   if(n<21) return false;                         // not enough history yet

   int m=0;
   for(int k=1;k<n && m<MAX_CORR_BARS;k++)
   {
      if(rr[k-1].close<=0 || rr[k].close<=0) continue;
      g_cTime[s][m]=rr[k].time;
      g_cRet [s][m]=MathLog(rr[k].close/rr[k-1].close);
      m++;
   }
   g_cN[s]=m;
   if(m<20) return false;

   double sum=0; for(int k=0;k<m;k++) sum+=g_cRet[s][k];
   const double mean=sum/m;
   double sq=0; for(int k=0;k<m;k++){ const double d=g_cRet[s][k]-mean; sq+=d*d; }
   g_cSd[s]=(m>1 ? MathSqrt(sq/(m-1)) : 0.0);
   return (g_cSd[s]>0);
}

//--- Pearson over TIMESTAMP-MATCHED returns only
double Hedge_Pearson(const int a,const int b,int &usedOut)
{
   usedOut=0;
   int i=0,j=0,n=0;
   double sa=0,sb=0,saa=0,sbb=0,sab=0;
   while(i<g_cN[a] && j<g_cN[b])
   {
      if(g_cTime[a][i]<g_cTime[b][j])      i++;
      else if(g_cTime[a][i]>g_cTime[b][j]) j++;
      else
      {
         const double x=g_cRet[a][i], y=g_cRet[b][j];
         sa+=x; sb+=y; saa+=x*x; sbb+=y*y; sab+=x*y;
         n++; i++; j++;
      }
   }
   usedOut=n;
   if(n<20) return 0.0;                           // too little overlap to mean anything
   const double num=n*sab-sa*sb;
   const double den=MathSqrt((n*saa-sa*sa)*(n*sbb-sb*sb));
   if(den<=0) return 0.0;
   return MathMax(-1.0,MathMin(1.0,num/den));
}

void Hedge_ComputeCorr()
{
   if(!Hedge_Enabled()) return;
   const ENUM_TIMEFRAMES tf=g_tf[ResolveTFIdx(InpCorrTF)];
   const datetime bt=iTime(_Symbol,tf,0);
   if(bt!=0 && bt==g_corrBar && g_corrN>0) return;      // once per bar of the correlation TF
   g_corrBar=bt;

   Hedge_BuildUniverse();
   bool ok[MAX_CORR_SYM];
   for(int s=0;s<g_corrN;s++) ok[s]=Hedge_LoadReturns(s,tf,InpCorrBars);

   for(int a=0;a<g_corrN;a++)
      for(int b=0;b<g_corrN;b++)
      {
         if(a==b){ g_corr[a][b]=1.0; continue; }
         if(!ok[a] || !ok[b]){ g_corr[a][b]=0.0; continue; }
         int used=0;
         g_corr[a][b]=Hedge_Pearson(a,b,used);
         if(a==0) g_corrPairs=used;
      }
}

int Hedge_IndexOf(const string sym)
{
   for(int s=0;s<g_corrN;s++) if(g_cName[s]==sym) return s;
   return -1;
}

//+------------------------------------------------------------------+
//| Currency exposure                                                 |
//+------------------------------------------------------------------+
void Hedge_AddCcy(const string ccy,const double v)
{
   if(StringLen(ccy)==0) return;
   for(int i=0;i<g_ccyN;i++) if(g_ccyName[i]==ccy){ g_ccyNet[i]+=v; return; }
   if(g_ccyN>=32) return;
   g_ccyName[g_ccyN]=ccy; g_ccyNet[g_ccyN]=v; g_ccyN++;
}

void Hedge_Exposure()
{
   g_ccyN=0;
   int open=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      if(!m_position.SelectByIndex(i)) continue;
      const string sym=m_position.Symbol();
      const double e=ExpoPerLot(sym)*m_position.Volume()
                     *((m_position.PositionType()==POSITION_TYPE_BUY) ? 1.0 : -1.0);
      if(e==0) continue;
      open++;
      Hedge_AddCcy(SymbolInfoString(sym,SYMBOL_CURRENCY_BASE),   e);
      Hedge_AddCcy(SymbolInfoString(sym,SYMBOL_CURRENCY_PROFIT),-e);
   }

   if(open==0){ g_expoLine="no open positions"; return; }

   //--- largest absolute exposure first
   for(int i=1;i<g_ccyN;i++)
   {
      const string nm=g_ccyName[i]; const double v=g_ccyNet[i];
      int j=i-1;
      while(j>=0 && MathAbs(g_ccyNet[j])<MathAbs(v)){ g_ccyName[j+1]=g_ccyName[j]; g_ccyNet[j+1]=g_ccyNet[j]; j--; }
      g_ccyName[j+1]=nm; g_ccyNet[j+1]=v;
   }

   string s="";
   for(int i=0;i<g_ccyN && i<6;i++)
   {
      if(MathAbs(g_ccyNet[i])<0.005) continue;
      if(StringLen(s)>0) s+="  ";
      s+=StringFormat("%s %+.0f",g_ccyName[i],g_ccyNet[i]);
   }
   g_expoLine=(StringLen(s)>0 ? s+"   per 1% move" : "no measurable exposure");
}

//+------------------------------------------------------------------+
//| Hedge suggestions                                                 |
//+------------------------------------------------------------------+
void Hedge_Suggest()
{
   g_hedgeN=0;
   if(!Hedge_Enabled()) return;

   const ENUM_TIMEFRAMES tf=g_tf[ResolveTFIdx(InpCorrTF)];
   const string tfName=g_tfName[ResolveTFIdx(InpCorrTF)];

   for(int i=PositionsTotal()-1;i>=0 && g_hedgeN<MAX_HEDGE_ROWS;i--)
   {
      if(!m_position.SelectByIndex(i)) continue;
      const string sym=m_position.Symbol();
      const bool   isBuy=(m_position.PositionType()==POSITION_TYPE_BUY);
      const double vol=m_position.Volume();

      const int a=Hedge_IndexOf(sym);
      if(a<0)
      {
         g_hedgeRow[g_hedgeN++]=StringFormat("%s %.2f %s - not scanned, add it to the watchlist",
                                             sym,vol,(isBuy?"BUY":"SELL"));
         continue;
      }

      //--- the strongest relationship anywhere else in the universe
      int    best=-1; double bestAbs=0;
      for(int b=0;b<g_corrN;b++)
      {
         if(b==a) continue;
         const double c=MathAbs(g_corr[a][b]);
         if(c>bestAbs){ bestAbs=c; best=b; }
      }

      if(best<0 || bestAbs<InpCorrMinAbs)
      {
         g_hedgeRow[g_hedgeN++]=StringFormat("%s %.2f %s - nothing correlated above %.2f",
                                             sym,vol,(isBuy?"BUY":"SELL"),InpCorrMinAbs);
         continue;
      }

      const double c=g_corr[a][best];
      //--- positively correlated: offset by trading the OPPOSITE way.
      //--- negatively correlated: the SAME way already offsets.
      const bool hedgeBuy=(c>0 ? !isBuy : isBuy);

      const double eA=ExpoPerLot(sym), eB=ExpoPerLot(g_cName[best]);
      double lots=0;
      if(eB>0 && g_cSd[best]>0)
         lots=MathAbs(c)*vol*(eA*g_cSd[a])/(eB*g_cSd[best]);

      const double step=SymbolInfoDouble(g_cName[best],SYMBOL_VOLUME_STEP);
      if(step>0) lots=MathFloor(lots/step)*step;
      const double vmin=SymbolInfoDouble(g_cName[best],SYMBOL_VOLUME_MIN);

      if(lots<vmin)
         g_hedgeRow[g_hedgeN++]=StringFormat("%s %.2f %s - offset is under %s minimum lot (corr %+.2f)",
                                             sym,vol,(isBuy?"BUY":"SELL"),g_cName[best],c);
      else
         g_hedgeRow[g_hedgeN++]=StringFormat("%s %.2f %s  ->  %s %.2f %s   corr %+.2f, %d %s bars",
                                             sym,vol,(isBuy?"BUY":"SELL"),
                                             (hedgeBuy?"BUY":"SELL"),lots,g_cName[best],
                                             c,g_corrPairs,tfName);
   }

   if(g_hedgeN==0 && PositionsTotal()==0)
      g_hedgeRow[g_hedgeN++]="no open positions to offset";
}

void Hedge_Update()
{
   if(!Hedge_Enabled()) return;
   Hedge_ComputeCorr();     // bar-gated
   Hedge_Exposure();        // cheap, every pass
   Hedge_Suggest();
}
//+------------------------------------------------------------------+
