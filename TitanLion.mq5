#property copyright "TitanLion"
#property version   "1.00"
#include <Trade/Trade.mqh>

//--- Enumerations
enum ENUM_RISK_MODEL_TL
  {
   TL_RISK_FIXED_LOT      = 0,
   TL_RISK_PERCENT_EQUITY = 1
  };

//--- CTrade instance
CTrade tl_trade;

//--- Indicator handles
int      tl_handleEmaFast   = INVALID_HANDLE;
int      tl_handleEmaSlow   = INVALID_HANDLE;
int      tl_handleRsi       = INVALID_HANDLE;
int      tl_handleAtr       = INVALID_HANDLE;

//--- State variables
datetime tl_lastBarTime     = 0;
datetime tl_lastEntryBar    = 0;

// ============================================================
// GEN - General
// ============================================================
input group "GEN - General"
input ulong              GEN_MagicNumber        = 20260510;
input int                GEN_SlippagePoints     = 20;
input bool               GEN_AllowLongs         = true;
input bool               GEN_AllowShorts        = true;
input bool               GEN_OnlyOnNewBar       = true;

// ============================================================
// RISK - Risk Management
// ============================================================
input group "RISK - Risk Management"
input ENUM_RISK_MODEL_TL RISK_Model             = TL_RISK_PERCENT_EQUITY;
input double             RISK_FixedLot          = 0.10;
input double             RISK_PercentPerTrade   = 1.00;
input int                RISK_MaxTradesPerDay   = 4;
input double             RISK_MaxDailyDrawdown  = 3.0;   // % drawdown limit
input bool               RISK_AllowPartialClose = true;
input double             RISK_PartialClosePercent = 50.0;

// ============================================================
// ENTRY - Entry Logic
// ============================================================
input group "ENTRY - Entry Logic"
input int                ENTRY_FastEMA          = 20;
input int                ENTRY_SlowEMA          = 50;
input int                ENTRY_RSI_Period       = 14;
input double             ENTRY_RSI_OverboughtLevel = 70.0;
input double             ENTRY_RSI_OversoldLevel   = 30.0;
input int                ENTRY_ATR_Period       = 14;
input double             ENTRY_ATR_SL_Multiplier   = 1.80;

// ============================================================
// EXIT - Trade Management
// ============================================================
input group "EXIT - Trade Management"
input double             EXIT_RiskRewardRatio   = 2.00;
input bool               EXIT_UseBreakEven      = true;
input double             EXIT_BreakEvenRR       = 1.00;
input double             EXIT_BreakEvenBuffer   = 5.0;   // points
input bool               EXIT_UseTrailingStop   = true;
input double             EXIT_TrailingATRMult   = 1.20;

// ============================================================
// FILTER - Filters
// ============================================================
input group "FILTER - Filters"
input double             FILTER_MaxSpreadPoints = 18.0;
input double             FILTER_MinATRPoints    = 50.0;
input double             FILTER_MaxATRPoints    = 600.0;
input int                FILTER_TradeStartHour  = 7;
input int                FILTER_TradeEndHour    = 20;

// ============================================================
// UI - Logging
// ============================================================
input group "UI - Logging"
input bool               UI_EnableLogs          = true;

//+------------------------------------------------------------------+
//| Utility: write log message                                       |
//+------------------------------------------------------------------+
void WriteLog(const string msg, const bool is_error = false)
  {
   if(!UI_EnableLogs && !is_error)
      return;
   string prefix = is_error ? "[TitanLion][ERROR] " : "[TitanLion] ";
   Print(prefix + msg);
  }

//+------------------------------------------------------------------+
//| Utility: release indicator handle safely                         |
//+------------------------------------------------------------------+
void ReleaseHandle(int &handle)
  {
   if(handle != INVALID_HANDLE)
     {
      IndicatorRelease(handle);
      handle = INVALID_HANDLE;
     }
  }

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
   tl_trade.SetExpertMagicNumber((long)GEN_MagicNumber);
   tl_trade.SetDeviationInPoints(GEN_SlippagePoints);
   tl_trade.SetTypeFillingBySymbol(_Symbol);

   tl_handleEmaFast = iMA(_Symbol, PERIOD_H1, ENTRY_FastEMA, 0, MODE_EMA, PRICE_CLOSE);
   tl_handleEmaSlow = iMA(_Symbol, PERIOD_H1, ENTRY_SlowEMA, 0, MODE_EMA, PRICE_CLOSE);
   tl_handleRsi     = iRSI(_Symbol, PERIOD_H1, ENTRY_RSI_Period, PRICE_CLOSE);
   tl_handleAtr     = iATR(_Symbol, PERIOD_H1, ENTRY_ATR_Period);

   if(tl_handleEmaFast == INVALID_HANDLE ||
      tl_handleEmaSlow == INVALID_HANDLE ||
      tl_handleRsi     == INVALID_HANDLE ||
      tl_handleAtr     == INVALID_HANDLE)
     {
      WriteLog("Falha ao criar indicator handles.", true);
      return(INIT_FAILED);
     }

   WriteLog(StringFormat("TitanLion inicializado. Symbol=%s MagicNumber=%I64u", _Symbol, GEN_MagicNumber), false);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   ReleaseHandle(tl_handleEmaFast);
   ReleaseHandle(tl_handleEmaSlow);
   ReleaseHandle(tl_handleRsi);
   ReleaseHandle(tl_handleAtr);
   WriteLog(StringFormat("EA finalizado. Reason=%d", reason), false);
  }

//+------------------------------------------------------------------+
//| OnTick                                                           |
//+------------------------------------------------------------------+
void OnTick()
  {
   ManageOpenPositions();

   bool is_new_bar = CheckNewBar(PERIOD_H1, tl_lastBarTime);
   if(GEN_OnlyOnNewBar && !is_new_bar)
      return;

   datetime current_bar = iTime(_Symbol, PERIOD_H1, 0);
   if(current_bar == 0 || current_bar == tl_lastEntryBar)
      return;

   if(!PassCommonFilters())
      return;

   if(GEN_AllowLongs && !HasOpenPosition(POSITION_TYPE_BUY))
     {
      if(CheckBuySignal())
        {
         if(OpenBuy())
            tl_lastEntryBar = current_bar;
        }
     }

   if(GEN_AllowShorts && !HasOpenPosition(POSITION_TYPE_SELL))
     {
      if(CheckSellSignal())
        {
         if(OpenSell())
            tl_lastEntryBar = current_bar;
        }
     }
  }

//+------------------------------------------------------------------+
//| CheckNewBar - detects a new bar on the given timeframe           |
//+------------------------------------------------------------------+
bool CheckNewBar(const ENUM_TIMEFRAMES timeframe, datetime &last_bar_time)
  {
   datetime current = iTime(_Symbol, timeframe, 0);
   if(current == 0)
      return(false);
   if(current != last_bar_time)
     {
      last_bar_time = current;
      return(true);
     }
   return(false);
  }

//+------------------------------------------------------------------+
//| GetSpreadPoints - returns current spread in points               |
//+------------------------------------------------------------------+
double GetSpreadPoints()
  {
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return(DBL_MAX);
   return((ask - bid) / _Point);
  }

//+------------------------------------------------------------------+
//| CalculateLotSize - fixed lot or % equity                         |
//+------------------------------------------------------------------+
double CalculateLotSize(const double stop_points)
  {
   double min_vol  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max_vol  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double vol_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   if(RISK_Model == TL_RISK_FIXED_LOT)
      return(NormalizeLot(RISK_FixedLot, min_vol, max_vol, vol_step));

   if(stop_points <= 0.0)
      return(0.0);

   double equity     = AccountInfoDouble(ACCOUNT_EQUITY);
   double risk_amt   = equity * (RISK_PercentPerTrade / 100.0);
   double tick_val   = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tick_sz    = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

   if(equity <= 0.0 || tick_val <= 0.0 || tick_sz <= 0.0)
      return(0.0);

   double stop_dist  = stop_points * _Point;
   double loss_lot   = (stop_dist / tick_sz) * tick_val;
   if(loss_lot <= 0.0)
      return(0.0);

   return(NormalizeLot(risk_amt / loss_lot, min_vol, max_vol, vol_step));
  }

//+------------------------------------------------------------------+
//| NormalizeLot - clamp and round volume to broker constraints      |
//+------------------------------------------------------------------+
double NormalizeLot(const double lot, const double min_vol, const double max_vol, const double step)
  {
   if(step <= 0.0)
      return(0.0);
   double normalized = MathFloor(lot / step + 1e-8) * step;
   normalized = MathMax(normalized, min_vol);
   normalized = MathMin(normalized, max_vol);
   return(NormalizeDouble(normalized, 2));
  }

//+------------------------------------------------------------------+
//| GetAtrValue - returns ATR value for bar index on H1              |
//+------------------------------------------------------------------+
double GetAtrValue(const int bar_index = 1)
  {
   double buf[1];
   if(CopyBuffer(tl_handleAtr, 0, bar_index, 1, buf) < 1)
      return(0.0);
   return(buf[0]);
  }

//+------------------------------------------------------------------+
//| GetEmaFast - returns fast EMA value for bar index on H1          |
//+------------------------------------------------------------------+
double GetEmaFast(const int bar_index = 1)
  {
   double buf[1];
   if(CopyBuffer(tl_handleEmaFast, 0, bar_index, 1, buf) < 1)
      return(0.0);
   return(buf[0]);
  }

//+------------------------------------------------------------------+
//| GetEmaSlow - returns slow EMA value for bar index on H1          |
//+------------------------------------------------------------------+
double GetEmaSlow(const int bar_index = 1)
  {
   double buf[1];
   if(CopyBuffer(tl_handleEmaSlow, 0, bar_index, 1, buf) < 1)
      return(0.0);
   return(buf[0]);
  }

//+------------------------------------------------------------------+
//| GetRsiValue - returns RSI value for bar index on H1              |
//+------------------------------------------------------------------+
double GetRsiValue(const int bar_index = 1)
  {
   double buf[1];
   if(CopyBuffer(tl_handleRsi, 0, bar_index, 1, buf) < 1)
      return(50.0);
   return(buf[0]);
  }

//+------------------------------------------------------------------+
//| PassCommonFilters - spread, session, ATR range                   |
//+------------------------------------------------------------------+
bool PassCommonFilters()
  {
   // Spread filter
   double spread = GetSpreadPoints();
   if(spread > FILTER_MaxSpreadPoints)
     {
      if(UI_EnableLogs)
         WriteLog(StringFormat("Spread %.1f pts acima do limite %.1f pts", spread, FILTER_MaxSpreadPoints), false);
      return(false);
     }

   // Session filter (server time UTC approximate)
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.hour < FILTER_TradeStartHour || dt.hour >= FILTER_TradeEndHour)
      return(false);

   // ATR range filter
   double atr_pts = GetAtrValue(1) / _Point;
   if(atr_pts < FILTER_MinATRPoints || atr_pts > FILTER_MaxATRPoints)
      return(false);

   // Daily drawdown check
   if(!CheckDailyDrawdown())
      return(false);

   // Max trades per day
   if(CountTodayTrades() >= RISK_MaxTradesPerDay)
      return(false);

   return(true);
  }

//+------------------------------------------------------------------+
//| CheckDailyDrawdown - prevents trading if daily DD exceeded       |
//+------------------------------------------------------------------+
bool CheckDailyDrawdown()
  {
   if(RISK_MaxDailyDrawdown <= 0.0)
      return(true);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   if(balance <= 0.0)
      return(true);
   double dd_pct = (balance - equity) / balance * 100.0;
   if(dd_pct >= RISK_MaxDailyDrawdown)
     {
      WriteLog(StringFormat("Daily drawdown %.2f%% atingido. Sem novas entradas.", dd_pct), false);
      return(false);
     }
   return(true);
  }

//+------------------------------------------------------------------+
//| CountTodayTrades - counts deals opened today by this EA          |
//+------------------------------------------------------------------+
int CountTodayTrades()
  {
   MqlDateTime dt_now;
   TimeToStruct(TimeCurrent(), dt_now);
   MqlDateTime dt_start = dt_now;
   dt_start.hour   = 0;
   dt_start.min    = 0;
   dt_start.sec    = 0;
   datetime today_start = StructToTime(dt_start);

   int count = 0;
   HistorySelect(today_start, TimeCurrent() + 1);
   int deals = HistoryDealsTotal();
   for(int i = 0; i < deals; i++)
     {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0)
         continue;
      if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != (long)GEN_MagicNumber)
         continue;
      if(HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_IN)
         count++;
     }
   return(count);
  }

//+------------------------------------------------------------------+
//| HasOpenPosition - checks if EA has open position of given type   |
//+------------------------------------------------------------------+
bool HasOpenPosition(const ENUM_POSITION_TYPE pos_type)
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)GEN_MagicNumber)
         continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == pos_type)
         return(true);
     }
   return(false);
  }

//+------------------------------------------------------------------+
//| CheckBuySignal                                                   |
//| - Fast EMA > Slow EMA (bullish trend)                            |
//| - Price above both EMAs                                          |
//| - RSI above 50 but below overbought                              |
//+------------------------------------------------------------------+
bool CheckBuySignal()
  {
   double ema_fast = GetEmaFast(1);
   double ema_slow = GetEmaSlow(1);
   double rsi      = GetRsiValue(1);
   double close    = iClose(_Symbol, PERIOD_H1, 1);

   if(ema_fast <= 0.0 || ema_slow <= 0.0 || close <= 0.0)
      return(false);

   bool trend_up  = ema_fast > ema_slow;
   bool price_up  = close > ema_fast && close > ema_slow;
   bool rsi_ok    = rsi > 50.0 && rsi < ENTRY_RSI_OverboughtLevel;

   if(trend_up && price_up && rsi_ok)
     {
      if(UI_EnableLogs)
         WriteLog(StringFormat("BUY signal: EmaFast=%.5f EmaSlow=%.5f RSI=%.1f", ema_fast, ema_slow, rsi), false);
      return(true);
     }
   return(false);
  }

//+------------------------------------------------------------------+
//| CheckSellSignal                                                  |
//| - Fast EMA < Slow EMA (bearish trend)                            |
//| - Price below both EMAs                                          |
//| - RSI below 50 but above oversold                                |
//+------------------------------------------------------------------+
bool CheckSellSignal()
  {
   double ema_fast = GetEmaFast(1);
   double ema_slow = GetEmaSlow(1);
   double rsi      = GetRsiValue(1);
   double close    = iClose(_Symbol, PERIOD_H1, 1);

   if(ema_fast <= 0.0 || ema_slow <= 0.0 || close <= 0.0)
      return(false);

   bool trend_dn  = ema_fast < ema_slow;
   bool price_dn  = close < ema_fast && close < ema_slow;
   bool rsi_ok    = rsi < 50.0 && rsi > ENTRY_RSI_OversoldLevel;

   if(trend_dn && price_dn && rsi_ok)
     {
      if(UI_EnableLogs)
         WriteLog(StringFormat("SELL signal: EmaFast=%.5f EmaSlow=%.5f RSI=%.1f", ema_fast, ema_slow, rsi), false);
      return(true);
     }
   return(false);
  }

//+------------------------------------------------------------------+
//| OpenBuy                                                          |
//+------------------------------------------------------------------+
bool OpenBuy()
  {
   double atr     = GetAtrValue(1);
   double ask     = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(atr <= 0.0 || ask <= 0.0)
      return(false);

   double sl_dist = atr * ENTRY_ATR_SL_Multiplier;
   double tp_dist = sl_dist * EXIT_RiskRewardRatio;

   double sl = ask - sl_dist;
   double tp = ask + tp_dist;

   sl = NormalizeDouble(sl, _Digits);
   tp = NormalizeDouble(tp, _Digits);

   double stop_pts = sl_dist / _Point;
   double lot      = CalculateLotSize(stop_pts);
   if(lot <= 0.0)
     {
      WriteLog("OpenBuy: lote calculado é zero ou inválido.", true);
      return(false);
     }

   if(!tl_trade.Buy(lot, _Symbol, ask, sl, tp, "TL|BUY"))
     {
      WriteLog(StringFormat("OpenBuy falhou: %d %s", tl_trade.ResultRetcode(), tl_trade.ResultRetcodeDescription()), true);
      return(false);
     }

   WriteLog(StringFormat("BUY aberto: Lot=%.2f Ask=%.5f SL=%.5f TP=%.5f", lot, ask, sl, tp), false);
   return(true);
  }

//+------------------------------------------------------------------+
//| OpenSell                                                         |
//+------------------------------------------------------------------+
bool OpenSell()
  {
   double atr = GetAtrValue(1);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(atr <= 0.0 || bid <= 0.0)
      return(false);

   double sl_dist = atr * ENTRY_ATR_SL_Multiplier;
   double tp_dist = sl_dist * EXIT_RiskRewardRatio;

   double sl = bid + sl_dist;
   double tp = bid - tp_dist;

   sl = NormalizeDouble(sl, _Digits);
   tp = NormalizeDouble(tp, _Digits);

   double stop_pts = sl_dist / _Point;
   double lot      = CalculateLotSize(stop_pts);
   if(lot <= 0.0)
     {
      WriteLog("OpenSell: lote calculado é zero ou inválido.", true);
      return(false);
     }

   if(!tl_trade.Sell(lot, _Symbol, bid, sl, tp, "TL|SELL"))
     {
      WriteLog(StringFormat("OpenSell falhou: %d %s", tl_trade.ResultRetcode(), tl_trade.ResultRetcodeDescription()), true);
      return(false);
     }

   WriteLog(StringFormat("SELL aberto: Lot=%.2f Bid=%.5f SL=%.5f TP=%.5f", lot, bid, sl, tp), false);
   return(true);
  }

//+------------------------------------------------------------------+
//| ManageOpenPositions - break even and trailing stop               |
//+------------------------------------------------------------------+
void ManageOpenPositions()
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)GEN_MagicNumber)
         continue;

      double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      double current_sl = PositionGetDouble(POSITION_SL);
      double current_tp = PositionGetDouble(POSITION_TP);
      double lot        = PositionGetDouble(POSITION_VOLUME);
      ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      double sl_dist    = MathAbs(open_price - current_sl);
      if(sl_dist <= 0.0)
         continue;

      if(EXIT_UseBreakEven)
         ApplyBreakEven(ticket, pos_type, open_price, current_sl, current_tp, sl_dist);

      if(EXIT_UseTrailingStop)
         ApplyTrailingStop(ticket, pos_type, open_price, current_sl, sl_dist);

      if(RISK_AllowPartialClose)
         ApplyPartialClose(ticket, pos_type, open_price, current_sl, sl_dist, lot);
     }
  }

//+------------------------------------------------------------------+
//| ApplyBreakEven                                                   |
//+------------------------------------------------------------------+
void ApplyBreakEven(const ulong ticket, const ENUM_POSITION_TYPE pos_type,
                    const double open_price, const double current_sl,
                    const double current_tp, const double sl_dist)
  {
   double be_trigger = sl_dist * EXIT_BreakEvenRR;
   double be_buffer  = EXIT_BreakEvenBuffer * _Point;
   double bid        = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask        = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   if(pos_type == POSITION_TYPE_BUY)
     {
      double profit_dist = bid - open_price;
      if(profit_dist >= be_trigger)
        {
         double new_sl = NormalizeDouble(open_price + be_buffer, _Digits);
         if(new_sl > current_sl)
           {
            if(!tl_trade.PositionModify(ticket, new_sl, current_tp))
               WriteLog(StringFormat("BreakEven BUY falhou ticket=%I64u: %d", ticket, tl_trade.ResultRetcode()), true);
           }
        }
     }
   else if(pos_type == POSITION_TYPE_SELL)
     {
      double profit_dist = open_price - ask;
      if(profit_dist >= be_trigger)
        {
         double new_sl = NormalizeDouble(open_price - be_buffer, _Digits);
         if(new_sl < current_sl || current_sl <= 0.0)
           {
            if(!tl_trade.PositionModify(ticket, new_sl, current_tp))
               WriteLog(StringFormat("BreakEven SELL falhou ticket=%I64u: %d", ticket, tl_trade.ResultRetcode()), true);
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| ApplyTrailingStop                                                |
//+------------------------------------------------------------------+
void ApplyTrailingStop(const ulong ticket, const ENUM_POSITION_TYPE pos_type,
                       const double open_price, const double current_sl,
                       const double sl_dist)
  {
   double atr        = GetAtrValue(0);   // current bar ATR
   if(atr <= 0.0)
      return;
   double trail_dist = atr * EXIT_TrailingATRMult;
   double bid        = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask        = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double current_tp = PositionGetDouble(POSITION_TP);

   if(pos_type == POSITION_TYPE_BUY)
     {
      double new_sl = NormalizeDouble(bid - trail_dist, _Digits);
      if(new_sl > current_sl && new_sl < bid)
        {
         if(!tl_trade.PositionModify(ticket, new_sl, current_tp))
            WriteLog(StringFormat("TrailingStop BUY falhou ticket=%I64u: %d", ticket, tl_trade.ResultRetcode()), true);
        }
     }
   else if(pos_type == POSITION_TYPE_SELL)
     {
      double new_sl = NormalizeDouble(ask + trail_dist, _Digits);
      if((new_sl < current_sl || current_sl <= 0.0) && new_sl > ask)
        {
         if(!tl_trade.PositionModify(ticket, new_sl, current_tp))
            WriteLog(StringFormat("TrailingStop SELL falhou ticket=%I64u: %d", ticket, tl_trade.ResultRetcode()), true);
        }
     }
  }

//+------------------------------------------------------------------+
//| ApplyPartialClose - closes 50% at 1:1 RR if enabled             |
//+------------------------------------------------------------------+
void ApplyPartialClose(const ulong ticket, const ENUM_POSITION_TYPE pos_type,
                       const double open_price, const double current_sl,
                       const double sl_dist, const double lot)
  {
   if(RISK_PartialClosePercent <= 0.0 || RISK_PartialClosePercent >= 100.0)
      return;

   string comment = PositionGetString(POSITION_COMMENT);
   if(StringFind(comment, "TL|PC") >= 0)
      return;   // already partially closed

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   bool should_close = false;
   if(pos_type == POSITION_TYPE_BUY && (bid - open_price) >= sl_dist)
      should_close = true;
   if(pos_type == POSITION_TYPE_SELL && (open_price - ask) >= sl_dist)
      should_close = true;

   if(!should_close)
      return;

   double min_vol  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double vol_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double close_vol = NormalizeLot(lot * (RISK_PartialClosePercent / 100.0), min_vol, lot, vol_step);
   if(close_vol < min_vol)
      return;

   if(!tl_trade.PositionClosePartial(ticket, close_vol))
      WriteLog(StringFormat("PartialClose falhou ticket=%I64u: %d", ticket, tl_trade.ResultRetcode()), true);
   else
      WriteLog(StringFormat("PartialClose %.2f lotes em ticket=%I64u", close_vol, ticket), false);
  }
