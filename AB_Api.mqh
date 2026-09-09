//+------------------------------------------------------------------+
//|                                                       AB_Api.mqh |
//|                       AstroBot MTF Scanner - v6.9 / JSON PUSH    |
//|                                                                  |
//| Publishes the whole panel state as one JSON document so a website |
//| can rebuild the display instead of scraping text.                 |
//|                                                                  |
//| THREE CONSTRAINTS SHAPE EVERYTHING HERE.                          |
//|                                                                  |
//|  1. WebRequest is BLOCKING. The EA thread stops until the server  |
//|     answers or the timeout expires. This EA manages trailing      |
//|     stops on every tick, so a slow endpoint could stall trade     |
//|     management. The push therefore runs from OnTimer only, never  |
//|     OnTick; it runs AFTER RunEngine so a stall delays the report  |
//|     rather than the trade; the timeout is short; and repeated     |
//|     failures back off to a ceiling instead of retrying every      |
//|     second into a dead host.                                      |
//|                                                                  |
//|  2. The URL must be whitelisted BY HAND in the terminal - Tools,  |
//|     Options, Expert Advisors, "Allow WebRequest for listed URL".  |
//|     Code cannot do it, by design. Without it every call returns   |
//|     -1 with error 4014 and nothing leaves the machine, so that    |
//|     specific failure is called out by name in the log rather      |
//|     than reported as a generic network problem.                   |
//|                                                                  |
//|  3. It does not work in the Strategy Tester. Always -1 there,     |
//|     so the whole module is disabled in tester and optimisation.   |
//|                                                                  |
//| QUIET BY DEFAULT. The payload is rebuilt every timer tick but     |
//| sent only when it differs from the last one accepted, and never   |
//| more often than InpApiMinSeconds. A still market costs one        |
//| request when it changes, not one per second. InpApiHeartbeatSec   |
//| forces a send even when nothing moved, so the dashboard can tell  |
//| "unchanged" from "the feed died".                                 |
//|                                                                  |
//| The exact bytes of the last payload are also written to           |
//| <Common>\Files\AstroBot\last_payload.json. When the dashboard     |
//| shows nothing, that file answers "did the EA build it correctly"  |
//| separately from "did it arrive", which are different faults with  |
//| different fixes.                                                  |
//|                                                                  |
//| SCHEMA. The document carries "v": 1. Version it from the first    |
//| day so the receiver can reject a payload it does not understand   |
//| instead of silently misreading a field that changed meaning.      |
//+------------------------------------------------------------------+

#define AB_API_SCHEMA 1

string   g_apiLastCore  = "";      // last payload accepted by the server, minus the timestamp
datetime g_apiLastSend  = 0;
datetime g_apiLastOK    = 0;
int      g_apiFails     = 0;
int      g_apiBackoff   = 0;       // extra seconds imposed after failures
long     g_apiSent      = 0;
string   g_apiStatus    = "idle";

bool Api_Enabled()
{
   if(StringLen(InpApiUrl)<8)                  return false;
   if((bool)MQLInfoInteger(MQL_TESTER))        return false;   // WebRequest always fails there
   if((bool)MQLInfoInteger(MQL_OPTIMIZATION))  return false;
   if((bool)MQLInfoInteger(MQL_FRAME_MODE))    return false;
   if(g_dupInstance)                           return false;   // the owner publishes, not the double
   return true;
}

//--- JSON string escaping. MQL5 strings are UTF-16 and the body is sent as
//--- UTF-8 bytes, so non-ASCII survives; only the structural characters and
//--- the control range have to be escaped.
string JEsc(string s)
{
   string o="";
   const int n=StringLen(s);
   for(int i=0;i<n;i++)
   {
      const ushort c=StringGetCharacter(s,i);
      if(c=='"')       o+="\\\"";
      else if(c=='\\') o+="\\\\";
      else if(c=='\n') o+="\\n";
      else if(c=='\r') o+="\\r";
      else if(c=='\t') o+="\\t";
      else if(c<0x20)  o+=StringFormat("\\u%04x",c);
      else             o+=ShortToString(c);
   }
   return o;
}
string JStr(const string k,const string v){ return StringFormat("\"%s\":\"%s\"",k,JEsc(v)); }
string JNum(const string k,const double v,const int d=2){ return StringFormat("\"%s\":%.*f",k,d,v); }
string JInt(const string k,const long v){ return StringFormat("\"%s\":%I64d",k,v); }
string JBool(const string k,const bool v){ return StringFormat("\"%s\":%s",k,(v?"true":"false")); }

//+------------------------------------------------------------------+
//| Build the document. Everything the panel shows, as data.          |
//+------------------------------------------------------------------+
string Api_BuildCore()
{
   string j="";

   j+=JInt("v",AB_API_SCHEMA)+","+JStr("ea",AB_VERSION)+","+JStr("symbol",_Symbol)+",";
   j+=JStr("chart_tf",TfName((ENUM_TIMEFRAMES)_Period))+",";
   j+=JInt("spread_pts",(long)SymbolInfoInteger(_Symbol,SYMBOL_SPREAD))+",";
   j+=JInt("digits",(long)m_symbol.Digits())+",";
   j+=JNum("bid",SymbolInfoDouble(_Symbol,SYMBOL_BID),m_symbol.Digits())+",";
   j+=JNum("ask",SymbolInfoDouble(_Symbol,SYMBOL_ASK),m_symbol.Digits())+",";

   //--- per-timeframe rows.
   //--- KEY NAMES ARE THE WIRE CONTRACT. These match readSnapshot() in the
   //--- dashboard's scanner.js exactly: the array is "tfs", and "votes" is an
   //--- ARRAY of {k,d} rather than an object keyed by vote name. An object
   //--- fails the reader's Array.isArray() test and yields no arrows at all,
   //--- which looks like a missing feature rather than a shape mismatch.
   const int atrIdx=(g_ui_atrTF>=0 ? g_ui_atrTF : CurrentTFIndex());
   j+="\"tfs\":[";
   for(int i=0;i<TF_COUNT;i++)
   {
      if(i>0) j+=",";
      j+="{"+JStr("tf",g_tfName[i])+","+JBool("ready",g_R[i].ready)+",";
      j+=JStr("label",g_R[i].ready?g_R[i].label:"loading")+",";
      j+=JNum("buy_pct",g_R[i].ready?g_R[i].buyPct:50.0,1)+",";
      j+=JNum("adx",g_R[i].ready?g_R[i].adx:0.0,1)+",";
      j+=JBool("ranging",g_R[i].ranging)+","+JInt("dir",g_R[i].dir)+",";
      //--- the two row markers the panel draws as ">" and "*". is_chart is
      //--- derivable from chart_tf, but is_atr_src is not - only the EA knows
      //--- which timeframe the stop is being sized from.
      j+=JBool("is_chart",(g_tf[i]==(ENUM_TIMEFRAMES)_Period))+",";
      j+=JBool("is_atr_src",(i==atrIdx))+",";
      j+="\"votes\":["
        +"{"+JStr("k","STK")+","+JInt("d",g_R[i].stkS)+"},"
        +"{"+JStr("k","SLP")+","+JInt("d",g_R[i].slpS)+"},"
        +"{"+JStr("k","DMI")+","+JInt("d",g_R[i].dmiS)+"},"
        +"{"+JStr("k","RSI")+","+JInt("d",g_R[i].rsiS)+"},"
        +"{"+JStr("k","DON")+","+JInt("d",g_R[i].donS)+"},"
        +"{"+JStr("k","AD") +","+JInt("d",g_R[i].adS)+"}],";
      //--- the graded strengths behind those signs. The reader ignores this
      //--- today; it is here so conviction can be shown without a new version.
      j+="\"strength\":{"+JNum("stk",g_R[i].stkV,3)+","+JNum("slp",g_R[i].slpV,3)+","
        +JNum("dmi",g_R[i].dmiV,3)+","+JNum("rsi",g_R[i].rsiV,3)+","
        +JNum("don",g_R[i].donV,3)+","+JNum("ad", g_R[i].adV,3)+"}}";
   }
   j+="],";

   //--- aggregate. up/neutral/down sit directly on `overall`, not nested
   //--- under an "align" object, because that is where the reader looks.
   j+="\"overall\":{"+JNum("buy_pct",g_overallBuyPct,1)+","+JInt("dir",g_overallDir)+","
     +JStr("label",g_overallLabel)+","
     +JInt("up",g_up)+","+JInt("neutral",g_nt)+","+JInt("down",g_dn);
   //--- chart_agrees is deliberately OMITTED rather than sent as false when
   //--- the chart timeframe is not in the ladder or has no data yet. The
   //--- reader treats absent as "the EA made no claim" and prints nothing;
   //--- sending false would print "DIVERGES", which is a specific assertion
   //--- about a timeframe we have not measured.
   {
      const int ci=CurrentTFIndex();
      if(ci>=0 && g_R[ci].ready)
      {
         const bool agrees=(g_R[ci].dir>0 && g_overallDir>0)
                        || (g_R[ci].dir<0 && g_overallDir<0)
                        || (g_R[ci].dir==0 && g_overallDir==0);
         j+=","+JBool("chart_agrees",agrees);
      }
   }
   j+="},";

   //--- verdict. action/reason/detail are the reader's names; head, pass and
   //--- total ride along for anything that wants the panel's own wording.
   j+="\"verdict\":{"+JStr("action",(g_V.dir>0?"BUY":g_V.dir<0?"SELL":"WAIT"))+","
     +JInt("dir",g_V.dir)+","+JStr("grade",g_V.grade)+","
     +JStr("reason",g_V.pros)+","+JStr("detail",g_V.levels)+","
     +JStr("against",g_V.cons)+","
     +JInt("pass",g_V.pass)+","+JInt("total",g_V.total)+","
     +JStr("head",g_V.head)+"},";

   //--- filters
   j+="\"filters\":{"+JStr("session",g_sessionMsg)+","+JBool("session_block",g_sessionBlock)+","
     +JStr("news",g_newsMsg)+","+JBool("news_block",g_newsBlock)+","
     +JStr("vol",g_volMsg)+","+JNum("vol_ratio",g_volRatio,3)+"},";

   //--- watchlist
   j+="\"watchlist\":[";
   for(int i=0;i<Watch_Count();i++)
   {
      if(i>0) j+=",";
      j+="{"+JStr("symbol",g_W[i].name)+","+JBool("ready",g_W[i].ready)+",";
      j+=JNum("buy_pct",g_W[i].buyPct,1)+","+JStr("label",g_W[i].label)+",";
      j+=JInt("dir",g_W[i].dir)+","+JStr("grade",g_W[i].grade)+",";
      j+=JInt("agree",(g_W[i].buyPct>=50?g_W[i].up:g_W[i].dn))+","+JInt("ready_tfs",g_W[i].readyN)+",";
      j+=JNum("adx",g_W[i].adxTop,1)+","+JBool("ranging",g_W[i].rangingTop)+"}";
   }
   j+="],";

   //--- currency exposure, account currency per 1% move
   j+="\"exposure\":[";
   for(int i=0;i<g_ccyN;i++)
   {
      if(i>0) j+=",";
      j+="{"+JStr("ccy",g_ccyName[i])+","+JNum("net",g_ccyNet[i],2)+"}";
   }
   j+="],";

   //--- hedge suggestion lines, as rendered
   j+="\"hedge\":[";
   for(int i=0;i<g_hedgeN;i++){ if(i>0) j+=","; j+="\""+JEsc(g_hedgeRow[i])+"\""; }
   j+="],";

   //--- open positions
   j+="\"positions\":[";
   int np=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      if(!m_position.SelectByIndex(i)) continue;
      if(np>0) j+=",";
      const int dg=(int)SymbolInfoInteger(m_position.Symbol(),SYMBOL_DIGITS);
      j+="{"+JInt("ticket",(long)m_position.Ticket())+","+JStr("symbol",m_position.Symbol())+",";
      j+=JStr("side",(m_position.PositionType()==POSITION_TYPE_BUY?"BUY":"SELL"))+",";
      j+=JNum("lots",m_position.Volume(),2)+","+JNum("open",m_position.PriceOpen(),dg)+",";
      j+=JNum("sl",m_position.StopLoss(),dg)+","+JNum("tp",m_position.TakeProfit(),dg)+",";
      j+=JNum("pl",m_position.Profit()+m_position.Swap()+m_position.Commission(),2)+",";
      j+=JInt("magic",(long)m_position.Magic())+","+JBool("auto",IsAutoPos(m_position.Magic()))+"}";
      np++;
   }
   j+="],";

   //--- account and engine
   j+="\"account\":{"+JStr("currency",AccountInfoString(ACCOUNT_CURRENCY))+","
     +JNum("balance",AccountInfoDouble(ACCOUNT_BALANCE),2)+","
     +JNum("equity",AccountInfoDouble(ACCOUNT_EQUITY),2)+","
     +JNum("dd_pct",CurrentDDPct(),2)+"},";

   int ab,asl; AutoPosCounts(ab,asl);
   j+="\"engine\":{"+JBool("on",g_auto_on)+","+JBool("halted",g_ddHalt)+","
     +JBool("netting",g_netting)+","+JStr("msg",g_autoMsg)+","
     +JInt("positions",ab+asl)+","+JInt("trades_today",g_tradesToday)+","
     +JNum("realized",g_autoRealized,2)+"}";

   return j;
}

//+------------------------------------------------------------------+
//| Send                                                              |
//+------------------------------------------------------------------+
void Api_WriteDebug(const string body)
{
   if(!InpApiDebugFile) return;
   const int h=FileOpen("AstroBot\\last_payload.json",FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON);
   if(h==INVALID_HANDLE) return;
   FileWriteString(h,body);
   FileClose(h);
}

void Api_Push()
{
   if(!Api_Enabled()) return;

   const datetime now=TimeCurrent();
   const int wait=MathMax(1,InpApiMinSeconds)+g_apiBackoff;
   if(g_apiLastSend>0 && (int)(now-g_apiLastSend)<wait) return;

   const string core=Api_BuildCore();
   const bool changed=(core!=g_apiLastCore);
   const bool heartbeat=(InpApiHeartbeatSec>0 && g_apiLastOK>0 &&
                         (int)(now-g_apiLastOK)>=InpApiHeartbeatSec);
   if(!changed && !heartbeat) return;

   const string body="{"+JInt("ts",(long)now)+","+JStr("sent_at",TimeToString(now,TIME_DATE|TIME_SECONDS))+","+core+"}";
   Api_WriteDebug(body);

   g_apiLastSend=now;

   string headers="Content-Type: application/json\r\n";
   if(StringLen(InpApiKey)>0) headers+="X-API-Key: "+InpApiKey+"\r\n";

   char post[], res[]; string rh="";
   //--- UTF-8 bytes, and StringToCharArray appends a terminating zero that
   //--- must not become part of the body
   int len=StringToCharArray(body,post,0,WHOLE_ARRAY,CP_UTF8);
   if(len>0) ArrayResize(post,len-1);

   ResetLastError();
   const int code=WebRequest("POST",InpApiUrl,headers,MathMax(500,InpApiTimeoutMs),post,res,rh);

   if(code>=200 && code<300)
   {
      g_apiLastCore=core;
      g_apiLastOK=now;
      g_apiFails=0; g_apiBackoff=0; g_apiSent++;
      g_apiStatus=StringFormat("ok %d, %I64d sent",code,g_apiSent);
      return;
   }

   g_apiFails++;
   //--- 1, 2, 4 ... up to five minutes, so a dead host is polled rarely
   g_apiBackoff=(int)MathMin(300,MathPow(2,MathMin(9,g_apiFails)));

   if(code==-1)
   {
      const int err=GetLastError();
      if(err==4014)
         g_apiStatus="BLOCKED - add the URL in Tools > Options > Expert Advisors";
      else
         g_apiStatus=StringFormat("network error %d",err);
      if(g_apiFails==1 || g_apiFails%20==0)
         PrintFormat("API: %s (%s). Retrying in %ds.",g_apiStatus,InpApiUrl,g_apiBackoff);
      return;
   }

   g_apiStatus=StringFormat("HTTP %d",code);
   if(g_apiFails==1 || g_apiFails%20==0)
      PrintFormat("API: server answered HTTP %d - %s. Retrying in %ds.",
                  code,CharArrayToString(res,0,MathMin(200,ArraySize(res))),g_apiBackoff);
}

string Api_StatusLine()
{
   if(StringLen(InpApiUrl)<8) return "feed off";
   if(!Api_Enabled())         return "feed disabled here";
   return StringFormat("feed %s%s",g_apiStatus,
                       (g_apiLastOK>0 ? ", last "+TimeToString(g_apiLastOK,TIME_MINUTES|TIME_SECONDS) : ""));
}
//+------------------------------------------------------------------+
