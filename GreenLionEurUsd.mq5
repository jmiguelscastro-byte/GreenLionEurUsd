//+------------------------------------------------------------------+
//|                                            GreenLionEurUsd.mq5   |
//|                      TITAN LION FX — Expert Advisor for EURUSD  |
//|                                                                  |
//| Strategy:                                                        |
//|   - MA crossover for trend direction                             |
//|   - RSI filter to avoid overbought/oversold entries              |
//|   - ATR-based dynamic Stop Loss and Take Profit                  |
//|   - Trailing Stop based on ATR                                   |
//|   - Spread filter and same-candle entry prevention               |
//|   - Risk-based or fixed lot sizing                               |
//+------------------------------------------------------------------+
#property copyright "TITAN LION FX"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

//--- Input Parameters ---------------------------------------------------

// General
input string   InpComment       = "TitanLionFX"; // Trade comment
input long     InpMagicNumber   = 20240101;       // Magic Number
input string   InpSymbol        = "EURUSD";       // Expected symbol (validation check)

// Moving Averages
input int      InpFastMAPeriod  = 20;            // Fast MA period
input int      InpSlowMAPeriod  = 50;            // Slow MA period
input ENUM_MA_METHOD InpMAMethod = MODE_EMA;     // MA method
input ENUM_APPLIED_PRICE InpMAPrice = PRICE_CLOSE; // MA applied price

// RSI
input int      InpRSIPeriod     = 14;            // RSI period
input double   InpRSIOverbought = 70.0;          // RSI overbought level
input double   InpRSIOversold   = 30.0;          // RSI oversold level

// ATR
input int      InpATRPeriod     = 14;            // ATR period
input double   InpSLMultiplier  = 1.5;           // ATR multiplier for Stop Loss
input double   InpTPMultiplier  = 2.5;           // ATR multiplier for Take Profit
input double   InpTrailMultiplier = 1.0;         // ATR multiplier for Trailing Stop

// Risk Management
input bool     InpAutoLot       = true;          // Auto lot sizing
input double   InpRiskPercent   = 1.0;           // Risk % per trade (if auto lot)
input double   InpFixedLot      = 0.01;          // Fixed lot size (if not auto lot)
input double   InpMaxSpreadPips = 2.0;           // Maximum allowed spread (pips)
input int      InpMaxPositions  = 1;             // Max open positions per direction

//--- Global Variables ---------------------------------------------------
CTrade         g_trade;
CPositionInfo  g_position;

int            g_handleFastMA;
int            g_handleSlowMA;
int            g_handleRSI;
int            g_handleATR;

datetime       g_lastBarTime = 0;   // Time of the last processed bar

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Configure trade object
   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints(10);
   g_trade.SetTypeFilling(ORDER_FILLING_IOC);

   string sym = Symbol();

   // Validate that the EA is running on the expected symbol
   if(sym != InpSymbol)
   {
      PrintFormat("[TitanLionFX] WARNING: EA loaded on %s but expected %s. Verify symbol configuration.", sym, InpSymbol);
   }

   // Create indicator handles
   g_handleFastMA = iMA(sym, PERIOD_CURRENT, InpFastMAPeriod, 0, InpMAMethod, InpMAPrice);
   g_handleSlowMA = iMA(sym, PERIOD_CURRENT, InpSlowMAPeriod, 0, InpMAMethod, InpMAPrice);
   g_handleRSI    = iRSI(sym, PERIOD_CURRENT, InpRSIPeriod, InpMAPrice);
   g_handleATR    = iATR(sym, PERIOD_CURRENT, InpATRPeriod);

   if(g_handleFastMA == INVALID_HANDLE ||
      g_handleSlowMA == INVALID_HANDLE ||
      g_handleRSI    == INVALID_HANDLE ||
      g_handleATR    == INVALID_HANDLE)
   {
      PrintFormat("[TitanLionFX] ERROR: Failed to create indicator handles. FastMA=%d SlowMA=%d RSI=%d ATR=%d",
                  g_handleFastMA, g_handleSlowMA, g_handleRSI, g_handleATR);
      return INIT_FAILED;
   }

   PrintFormat("[TitanLionFX] Initialized on %s %s | Magic=%I64d | AutoLot=%s | Risk=%.1f%%",
               sym, EnumToString((ENUM_TIMEFRAMES)Period()),
               InpMagicNumber, InpAutoLot ? "true" : "false", InpRiskPercent);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(g_handleFastMA != INVALID_HANDLE) IndicatorRelease(g_handleFastMA);
   if(g_handleSlowMA != INVALID_HANDLE) IndicatorRelease(g_handleSlowMA);
   if(g_handleRSI    != INVALID_HANDLE) IndicatorRelease(g_handleRSI);
   if(g_handleATR    != INVALID_HANDLE) IndicatorRelease(g_handleATR);

   PrintFormat("[TitanLionFX] Deinitialized. Reason: %d", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Only act on new bar
   datetime currentBarTime = (datetime)SeriesInfoInteger(Symbol(), PERIOD_CURRENT, SERIES_LASTBAR_DATE);
   if(currentBarTime == g_lastBarTime)
      return;
   g_lastBarTime = currentBarTime;

   // Manage trailing stops on every new bar
   ManageTrailingStop();

   // Check entry conditions
   CheckEntrySignals();
}

//+------------------------------------------------------------------+
//| Get indicator values (shift=1 = completed/closed bar)            |
//+------------------------------------------------------------------+
bool GetIndicatorValues(double &fastMA, double &slowMA, double &rsi, double &atr)
{
   double bufFastMA[], bufSlowMA[], bufRSI[], bufATR[];

   if(CopyBuffer(g_handleFastMA, 0, 1, 1, bufFastMA) < 1) return false;
   if(CopyBuffer(g_handleSlowMA, 0, 1, 1, bufSlowMA) < 1) return false;
   if(CopyBuffer(g_handleRSI,    0, 1, 1, bufRSI)    < 1) return false;
   if(CopyBuffer(g_handleATR,    0, 1, 1, bufATR)     < 1) return false;

   fastMA = bufFastMA[0];
   slowMA = bufSlowMA[0];
   rsi    = bufRSI[0];
   atr    = bufATR[0];
   return true;
}

//+------------------------------------------------------------------+
//| Count open positions for this EA and direction                   |
//+------------------------------------------------------------------+
int CountPositions(ENUM_POSITION_TYPE direction)
{
   int count = 0;
   string sym = Symbol();
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(g_position.SelectByIndex(i))
      {
         if(g_position.Symbol() == sym &&
            g_position.Magic()  == InpMagicNumber &&
            g_position.PositionType() == direction)
            count++;
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Calculate lot size based on risk % and SL distance in pips      |
//+------------------------------------------------------------------+
double CalculateLotSize(double slDistancePoints)
{
   if(!InpAutoLot)
      return NormalizeLot(InpFixedLot);

   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount     = accountBalance * InpRiskPercent / 100.0;

   double tickValue      = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
   double tickSize       = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);
   double pointSize      = SymbolInfoDouble(Symbol(), SYMBOL_POINT);

   if(tickSize <= 0 || tickValue <= 0 || slDistancePoints <= 0)
   {
      PrintFormat("[TitanLionFX] WARNING: Invalid tick/point data. Using fixed lot %.2f", InpFixedLot);
      return NormalizeLot(InpFixedLot);
   }

   // valuePerPoint = monetary value of one point movement per one standard lot.
   // Formula: (tickValue / tickSize) * pointSize
   // - tickValue: account currency gain/loss per tick (smallest price increment) per lot
   // - tickSize:  size of one tick in price terms
   // - pointSize: value of one point (usually == tickSize, but can differ for some brokers)
   double valuePerPoint = tickValue / tickSize * pointSize;

   // lotSize = how many lots to trade so that (slDistancePoints * valuePerPoint * lots) == riskAmount
   double lotSize       = riskAmount / (slDistancePoints * valuePerPoint);

   return NormalizeLot(lotSize);
}

//+------------------------------------------------------------------+
//| Normalize lot to broker constraints                              |
//+------------------------------------------------------------------+
double NormalizeLot(double lots)
{
   double minLot  = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);

   if(stepLot > 0)
      lots = MathFloor(lots / stepLot) * stepLot;

   lots = MathMax(lots, minLot);
   lots = MathMin(lots, maxLot);
   return lots;
}

//+------------------------------------------------------------------+
//| Check and apply trailing stop to open positions                 |
//+------------------------------------------------------------------+
void ManageTrailingStop()
{
   double bufATR[];
   if(CopyBuffer(g_handleATR, 0, 1, 1, bufATR) < 1) return;
   double atr = bufATR[0];

   double trailDistance = atr * InpTrailMultiplier;
   string sym = Symbol();

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!g_position.SelectByIndex(i)) continue;
      if(g_position.Symbol() != sym)   continue;
      if(g_position.Magic()  != InpMagicNumber) continue;

      double currentSL = g_position.StopLoss();
      double bid        = SymbolInfoDouble(sym, SYMBOL_BID);
      double ask        = SymbolInfoDouble(sym, SYMBOL_ASK);
      int    digits     = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);

      if(g_position.PositionType() == POSITION_TYPE_BUY)
      {
         double newSL = NormalizeDouble(bid - trailDistance, digits);
         // Only move SL up (never down), and only if in profit
         if(newSL > currentSL && newSL < bid)
         {
            if(!g_trade.PositionModify(g_position.Ticket(), newSL, g_position.TakeProfit()))
               PrintFormat("[TitanLionFX] TRAIL BUY modify failed: %s", g_trade.ResultRetcodeDescription());
            else
               PrintFormat("[TitanLionFX] TRAIL BUY #%I64d | SL moved to %.5f", g_position.Ticket(), newSL);
         }
      }
      else if(g_position.PositionType() == POSITION_TYPE_SELL)
      {
         double newSL = NormalizeDouble(ask + trailDistance, digits);
         // Only move SL down (never up), and only if in profit
         if((currentSL == 0 || newSL < currentSL) && newSL > ask)
         {
            if(!g_trade.PositionModify(g_position.Ticket(), newSL, g_position.TakeProfit()))
               PrintFormat("[TitanLionFX] TRAIL SELL modify failed: %s", g_trade.ResultRetcodeDescription());
            else
               PrintFormat("[TitanLionFX] TRAIL SELL #%I64d | SL moved to %.5f", g_position.Ticket(), newSL);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check entry signals and open trades if conditions are met       |
//+------------------------------------------------------------------+
void CheckEntrySignals()
{
   string sym    = Symbol();
   int    digits = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);

   // Spread check — convert spread from points to pips dynamically.
   // For 5-digit (e.g. EURUSD) and 3-digit (e.g. USDJPY) symbols, 1 pip = 10 points.
   // For 4-digit and 2-digit symbols, 1 pip = 1 point.
   double symPoint      = SymbolInfoDouble(sym, SYMBOL_POINT);
   double pipSize       = ((digits == 5 || digits == 3) ? symPoint * 10.0 : symPoint);
   double spreadPoints  = (double)SymbolInfoInteger(sym, SYMBOL_SPREAD);
   double spreadPips    = spreadPoints * symPoint / pipSize;
   if(spreadPips > InpMaxSpreadPips)
   {
      PrintFormat("[TitanLionFX] Spread too high: %.1f pips (max %.1f). Skipping.", spreadPips, InpMaxSpreadPips);
      return;
   }

   // Get indicator values from last closed bar
   double fastMA, slowMA, rsi, atr;
   if(!GetIndicatorValues(fastMA, slowMA, rsi, atr))
   {
      Print("[TitanLionFX] WARNING: Could not read indicator values.");
      return;
   }

   double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
   double bid = SymbolInfoDouble(sym, SYMBOL_BID);

   double slDistance = atr * InpSLMultiplier;
   double tpDistance = atr * InpTPMultiplier;

   // --- BUY Signal: fastMA > slowMA and RSI not overbought ---
   bool bullish = (fastMA > slowMA) && (rsi < InpRSIOverbought) && (rsi > 50.0);
   // --- SELL Signal: fastMA < slowMA and RSI not oversold ---
   bool bearish = (fastMA < slowMA) && (rsi > InpRSIOversold)  && (rsi < 50.0);

   if(bullish && CountPositions(POSITION_TYPE_BUY) < InpMaxPositions)
   {
      double sl = NormalizeDouble(ask - slDistance, digits);
      double tp = NormalizeDouble(ask + tpDistance, digits);
      double lot = CalculateLotSize(slDistance);

      PrintFormat("[TitanLionFX] BUY signal | Ask=%.5f SL=%.5f TP=%.5f Lot=%.2f | FastMA=%.5f SlowMA=%.5f RSI=%.2f ATR=%.5f",
                  ask, sl, tp, lot, fastMA, slowMA, rsi, atr);

      if(!g_trade.Buy(lot, sym, ask, sl, tp, InpComment))
         PrintFormat("[TitanLionFX] BUY failed: %d - %s", g_trade.ResultRetcode(), g_trade.ResultRetcodeDescription());
      else
         PrintFormat("[TitanLionFX] BUY opened #%I64d at %.5f", g_trade.ResultOrder(), ask);
   }
   else if(bearish && CountPositions(POSITION_TYPE_SELL) < InpMaxPositions)
   {
      double sl = NormalizeDouble(bid + slDistance, digits);
      double tp = NormalizeDouble(bid - tpDistance, digits);
      double lot = CalculateLotSize(slDistance);

      PrintFormat("[TitanLionFX] SELL signal | Bid=%.5f SL=%.5f TP=%.5f Lot=%.2f | FastMA=%.5f SlowMA=%.5f RSI=%.2f ATR=%.5f",
                  bid, sl, tp, lot, fastMA, slowMA, rsi, atr);

      if(!g_trade.Sell(lot, sym, bid, sl, tp, InpComment))
         PrintFormat("[TitanLionFX] SELL failed: %d - %s", g_trade.ResultRetcode(), g_trade.ResultRetcodeDescription());
      else
         PrintFormat("[TitanLionFX] SELL opened #%I64d at %.5f", g_trade.ResultOrder(), bid);
   }
}

//+------------------------------------------------------------------+
//| Trade event handler - log trade results                         |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest     &request,
                        const MqlTradeResult      &result)
{
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
   {
      ulong dealTicket = trans.deal;
      if(HistoryDealSelect(dealTicket))
      {
         long dealMagic = HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
         if(dealMagic == InpMagicNumber)
         {
            double dealProfit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
            double dealVolume = HistoryDealGetDouble(dealTicket, DEAL_VOLUME);
            double dealPrice  = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
            string dealSym    = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
            ENUM_DEAL_TYPE dealType = (ENUM_DEAL_TYPE)HistoryDealGetInteger(dealTicket, DEAL_TYPE);
            ENUM_DEAL_ENTRY dealEntry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);

            if(dealEntry == DEAL_ENTRY_OUT || dealEntry == DEAL_ENTRY_OUT_BY)
            {
               PrintFormat("[TitanLionFX] DEAL CLOSED | #%I64d %s %s %.2f @ %.5f | Profit: %.2f",
                           dealTicket, dealSym, EnumToString(dealType),
                           dealVolume, dealPrice, dealProfit);
            }
         }
      }
   }
}
//+------------------------------------------------------------------+
