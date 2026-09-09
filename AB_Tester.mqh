//+------------------------------------------------------------------+
//|                                                    AB_Tester.mqh |
//|                     AstroBot MTF Scanner - v6.1 / D3 TESTER      |
//|                                                                  |
//| Two jobs, both about making the optimiser answer the question    |
//| that was actually asked.                                          |
//|                                                                  |
//| 1. THE CRITERION. OnTester returns one number, and with "Custom   |
//|    max" selected the optimiser ranks passes by it. The built-in  |
//|    choices - balance, profit factor, expected payoff - each      |
//|    reward a spike: one lucky parameter set with three trades and |
//|    a huge net. The v5.1 header asked for plateaus instead, and   |
//|    a plateau needs a number that punishes small samples and deep |
//|    drawdowns by construction:                                    |
//|                                                                  |
//|      SQN         sqrt(min(N,100)) x mean(R) / stdev(R), over     |
//|                  the R multiple of every closing deal (the       |
//|                  journal tracker supplies them, so R is the      |
//|                  INITIAL stop, not the trailed one). Van Tharp's |
//|                  quality number: expectancy per unit of spread   |
//|                  in outcomes, scaled by sample size and capped   |
//|                  so N alone cannot buy a score.                  |
//|      PF_SQRTN    (PF - 1) x sqrt(N). Simpler, familiar, same     |
//|                  sample-size discipline.                         |
//|      RECOVERY    net profit / worst drawdown in money.           |
//|                                                                  |
//|    All three are then multiplied by a DRAWDOWN FACTOR that runs  |
//|    linearly from 1 at zero drawdown to 0 at InpScoreDDCap, on    |
//|    the same basis (balance or equity) the governor uses, so a    |
//|    pass that would have HALTED cannot win the sweep. Passes with |
//|    fewer than InpScoreMinTrades closed trades score exactly 0.   |
//|    A negative score (a losing pass) is left negative and         |
//|    unscaled, so losers still sort below every non-loser.         |
//|                                                                  |
//| 2. THE FRAMES. During an optimisation every agent packs its      |
//|    statistics into a frame; the terminal-side copy of the EA     |
//|    (MQL_FRAME_MODE) receives them and writes one CSV row per     |
//|    pass - score, the statistics behind it and the optimised      |
//|    inputs - to <Common>\Files\AstroBot\Opt_<symbol>_<stamp>\     |
//|    passes.csv. That file is the walk-forward review: sort it,    |
//|    plot a parameter against the score and look for the flat      |
//|    region rather than the tallest bar. With InpOptJournalFrames  |
//|    on, each pass's full journal travels the same way and lands   |
//|    beside it as pass_<n>.csv - useful, and heavy; leave it off   |
//|    for wide sweeps.                                              |
//+------------------------------------------------------------------+

#define AB_STATS_HEADER "trades,wins,losses,net,gross_profit,gross_loss,pf,mean_r,std_r,sqn_r,dd_bal_rel_pct,dd_eq_rel_pct,recovery,sharpe,dd_factor,halts,halted_days"

struct ABStats
{
   int    trades, wins, losses;
   double net, grossP, grossL, pf;
   double meanR, stdR, sqnR;
   double ddBal, ddEq;          // relative (%) maximum drawdowns, the tester's own figures
   double recovery, sharpe;
   double ddFactor;
   int    halts;                // v6.3/F1: how often the drawdown governor fired
   double haltedDays;           // v6.3/F1: and how long the engine sat out in total
   double score;
};

void Tester_Collect(ABStats &s)
{
   s.trades  =(int)TesterStatistics(STAT_TRADES);
   s.wins    =(int)TesterStatistics(STAT_PROFIT_TRADES);
   s.losses  =(int)TesterStatistics(STAT_LOSS_TRADES);
   s.net     =TesterStatistics(STAT_PROFIT);
   s.grossP  =TesterStatistics(STAT_GROSS_PROFIT);
   s.grossL  =MathAbs(TesterStatistics(STAT_GROSS_LOSS));
   s.pf      =(s.grossL>0 ? s.grossP/s.grossL : (s.grossP>0 ? 10.0 : 0.0));   // no losing trade at all: cap, do not divide by zero
   s.ddBal   =TesterStatistics(STAT_BALANCE_DDREL_PERCENT);
   s.ddEq    =TesterStatistics(STAT_EQUITY_DDREL_PERCENT);
   s.recovery=TesterStatistics(STAT_RECOVERY_FACTOR);
   s.sharpe  =TesterStatistics(STAT_SHARPE_RATIO);

   //--- R multiples from the journal tracker (one per closing deal)
   const int n=ArraySize(g_closedR);
   double sum=0, sq=0;
   for(int i=0;i<n;i++) sum+=g_closedR[i];
   s.meanR=(n>0 ? sum/n : 0.0);
   for(int i=0;i<n;i++){ const double d=g_closedR[i]-s.meanR; sq+=d*d; }
   s.stdR=(n>1 ? MathSqrt(sq/(n-1)) : 0.0);
   s.sqnR=((n>1 && s.stdR>0) ? MathSqrt((double)MathMin(n,100))*s.meanR/s.stdR : 0.0);

   const double dd=(InpDD_Basis==DD_FROM_EQUITY ? s.ddEq : s.ddBal);
   s.ddFactor=(InpScoreDDCap>0 ? MathMax(0.0,MathMin(1.0,1.0-dd/InpScoreDDCap)) : 1.0);

   //--- v6.3/F1: halts, and the time spent halted (a halt still latched at
   //--- the end of the run counts up to the last tick)
   s.halts=g_haltCount;
   long hs=g_haltedSecs;
   if(g_ddHalt && g_haltTime>0) hs+=(long)(TimeCurrent()-g_haltTime);
   s.haltedDays=hs/86400.0;

   double raw=0;
   if(InpScore==SCORE_PF_SQRTN)      raw=(s.pf-1.0)*MathSqrt((double)MathMax(0,s.trades));
   else if(InpScore==SCORE_RECOVERY) raw=s.recovery;
   else                              raw=s.sqnR;

   if(s.trades<InpScoreMinTrades) raw=0.0;
   s.score=(raw>0 ? raw*s.ddFactor : raw);
}

string Tester_StatsCSV(const ABStats &s)
{
   return StringFormat("%d,%d,%d,%.2f,%.2f,%.2f,%.3f,%.4f,%.4f,%.3f,%.2f,%.2f,%.3f,%.3f,%.3f,%d,%.1f",
                       s.trades,s.wins,s.losses,s.net,s.grossP,s.grossL,s.pf,s.meanR,s.stdR,s.sqnR,
                       s.ddBal,s.ddEq,s.recovery,s.sharpe,s.ddFactor,s.halts,s.haltedDays);
}

//+------------------------------------------------------------------+
//| OnTester: the agent's (or the single run's) side                  |
//+------------------------------------------------------------------+
double Tester_Score()
{
   ABStats s; Tester_Collect(s);
   PrintFormat("SCORE %s = %.4f | trades %d (%dW/%dL), net %.2f, PF %.2f, SQN(R) %.2f over %d closes, mean R %.3f, DD bal %.2f%% / eq %.2f%%, DD factor %.2f | halts %d (%.1f days halted)",
               EnumToString(InpScore),s.score,s.trades,s.wins,s.losses,s.net,s.pf,s.sqnR,ArraySize(g_closedR),
               s.meanR,s.ddBal,s.ddEq,s.ddFactor,s.halts,s.haltedDays);

   if((bool)MQLInfoInteger(MQL_OPTIMIZATION))
   {
      uchar bytes[];
      const string csv=Tester_StatsCSV(s);
      StringToCharArray(csv,bytes,0,StringLen(csv));
      FrameAdd("stats",0,s.score,bytes);
      if(InpOptJournalFrames && g_jrnOK) FrameAdd("journal",1,s.score,g_jrnFile);
   }
   return s.score;
}

//+------------------------------------------------------------------+
//| OnTesterInit / OnTesterPass / OnTesterDeinit: the terminal's side |
//+------------------------------------------------------------------+
string g_optDir    = "";
string g_optFile   = "";
bool   g_optHeader = false;
int    g_optRows   = 0;

void Tester_FramesInit()
{
   MqlDateTime dt; TimeToStruct(TimeLocal(),dt);
   const string stamp=StringFormat("%04d%02d%02d_%02d%02d%02d",dt.year,dt.mon,dt.day,dt.hour,dt.min,dt.sec);
   g_optDir   =StringFormat("AstroBot\\Opt_%s_%s",Journal_SafeSymbol(),stamp);
   g_optFile  =g_optDir+"\\passes.csv";
   g_optHeader=false;
   g_optRows  =0;
   PrintFormat("OPT: collecting frames -> %s\\Files\\%s",TerminalInfoString(TERMINAL_COMMONDATA_PATH),g_optFile);
}

void Tester_FramesPass()
{
   ulong pass; string name; long id; double value; uchar data[];
   while(FrameNext(pass,name,id,value,data))
   {
      if(name=="stats")
      {
         string inputs[]; uint n=0;
         FrameInputs(pass,inputs,n);
         const int h=FileOpen(g_optFile,FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_SHARE_READ|FILE_COMMON);
         if(h==INVALID_HANDLE){ PrintFormat("OPT: cannot open %s (error %d)",g_optFile,GetLastError()); continue; }
         FileSeek(h,0,SEEK_END);
         if(!g_optHeader)
         {
            string hdr="pass,score,"+AB_STATS_HEADER;
            for(uint i=0;i<n;i++)
            {
               const int eq=StringFind(inputs[i],"=");
               hdr+=","+(eq>0 ? StringSubstr(inputs[i],0,eq) : inputs[i]);
            }
            FileWriteString(h,hdr+"\r\n");
            g_optHeader=true;
         }
         string row=StringFormat("%I64u,%.6f,",pass,value)+CharArrayToString(data,0,ArraySize(data));
         for(uint i=0;i<n;i++)
         {
            const int eq=StringFind(inputs[i],"=");
            row+=","+(eq>=0 ? StringSubstr(inputs[i],eq+1) : "");
         }
         FileWriteString(h,row+"\r\n");
         FileClose(h);
         g_optRows++;
      }
      else if(name=="journal")
      {
         const string fn=StringFormat("%s\\pass_%I64u.csv",g_optDir,pass);
         const int h=FileOpen(fn,FILE_WRITE|FILE_BIN|FILE_COMMON);
         if(h==INVALID_HANDLE){ PrintFormat("OPT: cannot write %s (error %d)",fn,GetLastError()); continue; }
         FileWriteArray(h,data,0,ArraySize(data));
         FileClose(h);
      }
   }
}

void Tester_FramesDeinit()
{
   PrintFormat("OPT: done - %d pass row(s) in %s\\Files\\%s",g_optRows,TerminalInfoString(TERMINAL_COMMONDATA_PATH),g_optFile);
}
//+------------------------------------------------------------------+
