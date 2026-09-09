//+------------------------------------------------------------------+
//|                                                     AB_Watch.mqh |
//|                     AstroBot MTF Scanner - v6.7 / WATCHLIST      |
//|                                                                  |
//| The same six-vote ensemble, run across other symbols, so the      |
//| panel can say WHERE to look as well as what to do here.           |
//|                                                                  |
//| SCANNING ONLY, AND THAT IS DELIBERATE. Nothing in this file       |
//| trades. The auto engine, the manual ticket, both journals and     |
//| every risk governor stay bound to the chart symbol exactly as     |
//| they were. Two reasons. The execution path is genuinely symbol-   |
//| bound - sizing, stops, the stop guard and the drawdown governor   |
//| all assume one instrument - and every governor filters on the     |
//| chart symbol, so trading several pairs from here would let two    |
//| correlated positions double the account's risk without any of     |
//| the ceilings noticing. And the year of journal data said this     |
//| strategy has no edge after costs; multiplying execution across    |
//| ten instruments would multiply a negative expectancy. Finding     |
//| where the setups are is worth having. Firing at all of them is    |
//| not, yet.                                                         |
//|                                                                  |
//| THE HANDLE BUDGET is the real constraint, and it is why the       |
//| watched symbols get a reduced timeframe set. MT5 allows 512       |
//| indicator handles per chart. The chart symbol alone uses 43 - six |
//| indicators across seven timeframes, plus the chart ATR - so at    |
//| the full ladder only about eleven symbols would fit. A watchlist  |
//| exists to say where to look, and M1 and M5 are noise at that job, |
//| so InpWatchTFs defaults to M15/H1/H4/D1: 24 handles each, and     |
//| room for roughly nineteen symbols. Watch_Init refuses to add a    |
//| symbol that would cross the ceiling rather than letting the       |
//| terminal fail a handle silently and score it as neutral.          |
//|                                                                  |
//| HISTORY ARRIVES LATE. A symbol the terminal has not seen before   |
//| downloads in the background, so its row reads "loading" for a few |
//| seconds. That is the existing readiness gate doing its job: a     |
//| timeframe short of history reports itself rather than voting      |
//| neutral, which is the C2 defect this codebase fixed in v3.2 and   |
//| is not about to reintroduce twenty symbols at a time.             |
//+------------------------------------------------------------------+

#define MAX_WATCH 20

struct WatchSym
{
   string     name;
   bool       ok;                  // exists, selected, handles created
   MTFHandles H[TF_COUNT];         // only the scanned indices are populated
   TFResult   R[TF_COUNT];
   datetime   lastBar[TF_COUNT];
   //--- the summary the panel row shows
   bool       ready;               // at least one scanned timeframe has data
   double     buyPct;
   int        dir;
   string     label;
   int        up, dn, nt;
   int        readyN;
   double     adxTop;              // ADX of the highest scanned timeframe
   bool       rangingTop;
   string     grade;               // A / B / C / "-"
   double     conv;                // |buyPct - 50|, what the sort uses
};

WatchSym g_W[];
int      g_wlIdx[];                // indices into g_tf[] that are scanned
int      g_wlTFn = 0;

int Watch_Count(){ return ArraySize(g_W); }

//--- which timeframes a watched symbol gets
void Watch_BuildTFSet()
{
   ArrayResize(g_wlIdx,0);
   int want[];
   if(InpWatchTFs==WTF_H1_D1)        { ArrayResize(want,3); want[0]=4; want[1]=5; want[2]=6; }
   else if(InpWatchTFs==WTF_ALL)     { ArrayResize(want,TF_COUNT); for(int i=0;i<TF_COUNT;i++) want[i]=i; }
   else                              { ArrayResize(want,4); want[0]=2; want[1]=4; want[2]=5; want[3]=6; }
   ArrayResize(g_wlIdx,ArraySize(want));
   for(int i=0;i<ArraySize(want);i++) g_wlIdx[i]=want[i];
   g_wlTFn=ArraySize(g_wlIdx);
}

//+------------------------------------------------------------------+
//| Init: parse the list, validate each symbol, open its handles.     |
//+------------------------------------------------------------------+
void Watch_Init()
{
   ArrayResize(g_W,0);
   Watch_BuildTFSet();

   string raw=InpWatchSymbols;
   StringTrimLeft(raw); StringTrimRight(raw);
   if(StringLen(raw)==0){ Print("WATCHLIST: empty (InpWatchSymbols) - scanning the chart symbol only"); return; }

   string parts[];
   const int n=StringSplit(raw,',',parts);
   if(n<=0) return;

   //--- 43 handles are already spent on the chart symbol
   const int perSym=g_wlTFn*6;
   int used=TF_COUNT*6+1;
   const int ceiling=500;                 // 512, less a margin for anything else

   for(int i=0;i<n;i++)
   {
      string s=parts[i];
      StringTrimLeft(s); StringTrimRight(s);
      if(StringLen(s)==0) continue;
      if(s==_Symbol){ PrintFormat("WATCHLIST: %s is the chart symbol, already scanned in full - skipped",s); continue; }
      if(ArraySize(g_W)>=MAX_WATCH){ PrintFormat("WATCHLIST: stopped at the %d-symbol limit, '%s' and the rest ignored",MAX_WATCH,s); break; }

      if(!SymbolSelect(s,true))
      { PrintFormat("WATCHLIST: '%s' is not a symbol on this server - skipped",s); continue; }

      if(used+perSym>ceiling)
      {
         PrintFormat("WATCHLIST: handle ceiling reached (%d of %d used, %d needed each) - '%s' and the rest skipped. Use a smaller InpWatchTFs or a shorter list.",
                     used,ceiling,perSym,s);
         break;
      }

      WatchSym w;
      w.name=s; w.ok=true; w.ready=false; w.buyPct=50; w.dir=0; w.label="loading";
      w.up=0; w.dn=0; w.nt=0; w.readyN=0; w.adxTop=0; w.rangingTop=false; w.grade="-"; w.conv=0;
      for(int t=0;t<TF_COUNT;t++)
      {
         w.lastBar[t]=0;
         w.H[t].emaF=INVALID_HANDLE; w.H[t].emaM=INVALID_HANDLE; w.H[t].emaS=INVALID_HANDLE;
         w.H[t].rsi =INVALID_HANDLE; w.H[t].adx =INVALID_HANDLE; w.H[t].atr =INVALID_HANDLE;
      }

      bool good=true;
      for(int k=0;k<g_wlTFn && good;k++)
      {
         const int t=g_wlIdx[k];
         const ENUM_TIMEFRAMES tf=g_tf[t];
         w.H[t].emaF=iMA (s,tf,InpEMAFast,  0,MODE_EMA,PRICE_CLOSE);
         w.H[t].emaM=iMA (s,tf,InpEMAMedium,0,MODE_EMA,PRICE_CLOSE);
         w.H[t].emaS=iMA (s,tf,InpEMASlow,  0,MODE_EMA,PRICE_CLOSE);
         w.H[t].rsi =iRSI(s,tf,InpRSIPeriod,PRICE_CLOSE);
         w.H[t].adx =iADX(s,tf,InpADXPeriod);
         w.H[t].atr =iATR(s,tf,InpATRPeriod);
         if(w.H[t].emaF==INVALID_HANDLE || w.H[t].emaM==INVALID_HANDLE || w.H[t].emaS==INVALID_HANDLE ||
            w.H[t].rsi ==INVALID_HANDLE || w.H[t].adx ==INVALID_HANDLE || w.H[t].atr ==INVALID_HANDLE)
            good=false;
      }
      if(!good)
      {
         PrintFormat("WATCHLIST: '%s' - could not create indicator handles, skipped",s);
         for(int t=0;t<TF_COUNT;t++)
         {
            if(w.H[t].emaF!=INVALID_HANDLE) IndicatorRelease(w.H[t].emaF);
            if(w.H[t].emaM!=INVALID_HANDLE) IndicatorRelease(w.H[t].emaM);
            if(w.H[t].emaS!=INVALID_HANDLE) IndicatorRelease(w.H[t].emaS);
            if(w.H[t].rsi !=INVALID_HANDLE) IndicatorRelease(w.H[t].rsi);
            if(w.H[t].adx !=INVALID_HANDLE) IndicatorRelease(w.H[t].adx);
            if(w.H[t].atr !=INVALID_HANDLE) IndicatorRelease(w.H[t].atr);
         }
         continue;
      }

      used+=perSym;
      const int idx=ArraySize(g_W);
      ArrayResize(g_W,idx+1);
      g_W[idx]=w;
   }

   string tfs="";
   for(int k=0;k<g_wlTFn;k++){ if(k>0) tfs+="/"; tfs+=g_tfName[g_wlIdx[k]]; }
   PrintFormat("WATCHLIST: %d symbol(s) on %s - %d indicator handles of the 512 ceiling in use",
               ArraySize(g_W),tfs,used);
   //--- the panel raises its own height for these rows in OnInit, so
   //--- Panel_H does not have to be kept in step with the list length
}

void Watch_Deinit()
{
   for(int i=0;i<ArraySize(g_W);i++)
      for(int t=0;t<TF_COUNT;t++)
      {
         if(g_W[i].H[t].emaF!=INVALID_HANDLE) IndicatorRelease(g_W[i].H[t].emaF);
         if(g_W[i].H[t].emaM!=INVALID_HANDLE) IndicatorRelease(g_W[i].H[t].emaM);
         if(g_W[i].H[t].emaS!=INVALID_HANDLE) IndicatorRelease(g_W[i].H[t].emaS);
         if(g_W[i].H[t].rsi !=INVALID_HANDLE) IndicatorRelease(g_W[i].H[t].rsi);
         if(g_W[i].H[t].adx !=INVALID_HANDLE) IndicatorRelease(g_W[i].H[t].adx);
         if(g_W[i].H[t].atr !=INVALID_HANDLE) IndicatorRelease(g_W[i].H[t].atr);
      }
   ArrayResize(g_W,0);
}

//+------------------------------------------------------------------+
//| Analyse one watched symbol. Bar-gated exactly like the chart      |
//| symbol (M13), so twenty symbols cost almost nothing between bars. |
//+------------------------------------------------------------------+
void Watch_AnalyzeOne(const int i)
{
   double oNet=0, oMax=0;
   int up=0,dn=0,nt=0,readyN=0;
   int topIdx=-1;

   for(int k=0;k<g_wlTFn;k++)
   {
      const int t=g_wlIdx[k];
      const datetime bt=iTime(g_W[i].name,g_tf[t],0);
      if(bt==0 || bt!=g_W[i].lastBar[t] || !g_W[i].R[t].ready)
      {
         AnalyzeOne(g_W[i].name,g_tf[t],g_W[i].H[t],g_W[i].R[t]);
         g_W[i].lastBar[t]=bt;
      }
      if(!g_W[i].R[t].ready) continue;

      readyN++;
      topIdx=t;                                  // g_wlIdx is ascending, so this ends on the highest
      const double regime=g_W[i].R[t].ranging ? MathMax(0.0,MathMin(1.0,InpRangingWeight)) : 1.0;
      oNet += (g_W[i].R[t].bullPts-g_W[i].R[t].bearPts)*g_tfW[t]*regime;
      oMax += MAX_PTS*g_tfW[t];
      if(g_W[i].R[t].dir>0) up++; else if(g_W[i].R[t].dir<0) dn++; else nt++;
   }

   g_W[i].readyN=readyN;
   g_W[i].ready =(readyN>0);
   g_W[i].up=up; g_W[i].dn=dn; g_W[i].nt=nt;
   g_W[i].adxTop    =(topIdx>=0 ? g_W[i].R[topIdx].adx     : 0);
   g_W[i].rangingTop=(topIdx>=0 ? g_W[i].R[topIdx].ranging : false);

   if(!g_W[i].ready || oMax<=0)
   { g_W[i].buyPct=50; g_W[i].dir=0; g_W[i].label="loading"; g_W[i].grade="-"; g_W[i].conv=0; return; }

   g_W[i].buyPct=MathMax(0.0,MathMin(100.0,50.0+(oNet/oMax)*50.0));
   g_W[i].conv  =MathAbs(g_W[i].buyPct-50.0);

   int d=0;
   g_W[i].label=LabelFromNet((g_W[i].buyPct-50.0)/50.0*MAX_PTS, g_W[i].rangingTop, d);
   g_W[i].dir=d;

   //--- the same idea as the verdict card, on the checks a reduced
   //--- timeframe set can actually answer
   int want=0;
   if(g_W[i].buyPct>=InpAutoBuyPct)       want= 1;
   else if(g_W[i].buyPct<=InpAutoSellPct) want=-1;
   if(want==0){ g_W[i].grade="-"; return; }

   int pass=0;
   const int agree=(want>0 ? up : dn);
   if(topIdx>=0 && ((want>0 && g_W[i].R[topIdx].dir>0) || (want<0 && g_W[i].R[topIdx].dir<0))) pass++;
   if(readyN>0 && agree*3 >= readyN*2) pass++;      // two thirds of the ready timeframes agree
   if(!g_W[i].rangingTop) pass++;
   g_W[i].grade=(pass>=3 ? "A" : pass==2 ? "B" : pass==1 ? "C" : "-");
}

void Watch_Analyze()
{
   for(int i=0;i<ArraySize(g_W);i++) Watch_AnalyzeOne(i);
}

//+------------------------------------------------------------------+
//| Display order: strongest conviction first, so the row worth       |
//| looking at is the one at the top. Simple insertion sort; the      |
//| list is at most twenty long and this runs once a second.          |
//+------------------------------------------------------------------+
void Watch_Order(int &out[])
{
   const int n=ArraySize(g_W);
   ArrayResize(out,n);
   for(int i=0;i<n;i++) out[i]=i;
   if(!InpWatchSortByConviction) return;
   for(int i=1;i<n;i++)
   {
      const int key=out[i];
      int j=i-1;
      while(j>=0 && g_W[out[j]].conv < g_W[key].conv){ out[j+1]=out[j]; j--; }
      out[j+1]=key;
   }
}

//--- one row of the watchlist, already formatted
string Watch_Row(const int i)
{
   if(!g_W[i].ready)
      return StringFormat("%-10s  loading history...",g_W[i].name);
   return StringFormat("%-10s %-12s %3.0f%%  %-1s  %d/%d %-4s  ADX %3.0f%s",
                       g_W[i].name, g_W[i].label, g_W[i].buyPct, g_W[i].grade,
                       (g_W[i].buyPct>=50 ? g_W[i].up : g_W[i].dn), g_W[i].readyN,
                       (g_W[i].buyPct>=50 ? "up" : "down"),
                       g_W[i].adxTop, (g_W[i].rangingTop ? " r" : ""));
}

color Watch_RowColor(const int i)
{
   if(!g_W[i].ready) return C_DIM;
   return DirColor(g_W[i].dir);
}
//+------------------------------------------------------------------+
