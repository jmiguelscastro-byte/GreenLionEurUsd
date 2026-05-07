#property copyright "GreenLionEurUsd"
#property version   "1.00"
#include <Trade/Trade.mqh>

enum ENUM_RISK_MODEL
  {
   RISK_FIXED_LOT = 0,
   RISK_PERCENT_EQUITY = 1
  };

struct SignalSetup
  {
   double            stop_loss;
   double            take_profit;
   double            risk_points;
   string            tag;
  };

CTrade trade;

input group "GEN - General"
input ulong           GEN_MagicNumber                  = 26050701;
input int             GEN_SlippagePoints              = 20;
input bool            GEN_AllowLongs                  = true;
input bool            GEN_AllowShorts                 = true;
input bool            GEN_OnlyOnNewBar                = true;

input group "RISK - Risk Management"
input ENUM_RISK_MODEL RISK_Model                      = RISK_PERCENT_EQUITY;
input double          RISK_FixedLot                   = 0.10;
input double          RISK_PercentPerTrade            = 0.50;
input double          RISK_ReducedPercentPerTrade     = 0.25;
input int             RISK_MaxTradesPerDay            = 2;
input double          RISK_MaxDailyDrawdownPercent    = 2.0;
input double          RISK_MaxWeeklyDrawdownPercent   = 5.0;
input bool            RISK_AllowPartialClose          = true;
input double          RISK_PartialClosePercent        = 50.0;

input group "ENTRY - Entry Logic"
input int             ENTRY_FastEMA                   = 20;
input int             ENTRY_MediumEMA                 = 50;
input int             ENTRY_SlowEMA                   = 200;
input int             ENTRY_RSI_Period                = 14;
input int             ENTRY_ATR_Period                = 14;
input int             ENTRY_MACD_Fast                 = 12;
input int             ENTRY_MACD_Slow                 = 26;
input int             ENTRY_MACD_Signal               = 9;
input int             ENTRY_BBands_Period             = 20;
input double          ENTRY_BBands_Deviation          = 2.0;
input double          ENTRY_MinTrendSeparationPoints  = 150.0;
input double          ENTRY_PullbackToleranceATR      = 0.35;
input double          ENTRY_StopATRMultiplier         = 1.40;
input double          ENTRY_BreakoutBufferPoints      = 20.0;
input double          ENTRY_MaxAsianRangePoints       = 900.0;
input double          ENTRY_MinAsianRangePoints       = 120.0;
input double          ENTRY_MaxSqueezeWidthPoints     = 250.0;
input int             ENTRY_SwingLookbackBars         = 6;

input group "EXIT - Trade Management"
input double          EXIT_FinalTargetRR              = 2.20;
input double          EXIT_BreakEvenRR                = 1.00;
input double          EXIT_TrailingStartRR            = 1.50;
input double          EXIT_TrailingATRMultiplier      = 1.50;
input double          EXIT_BreakEvenBufferPoints      = 5.0;

input group "FILTER - Filters"
input double          FILTER_MaxSpreadPoints          = 18.0;
input double          FILTER_MinATRH1Points           = 80.0;
input double          FILTER_MaxATRH1Points           = 700.0;
input bool            FILTER_UseNewsFilter            = false;
input int             FILTER_NewsBlockMinutesBefore   = 30;
input int             FILTER_NewsBlockMinutesAfter    = 30;
input bool            FILTER_UseServerTime            = false;
input int             FILTER_ServerUtcOffsetHours     = 0;
input int             FILTER_MainWindow1StartHourUTC  = 7;
input int             FILTER_MainWindow1StartMinUTC   = 0;
input int             FILTER_MainWindow1EndHourUTC    = 11;
input int             FILTER_MainWindow1EndMinUTC     = 30;
input int             FILTER_MainWindow2StartHourUTC  = 13;
input int             FILTER_MainWindow2StartMinUTC   = 0;
input int             FILTER_MainWindow2EndHourUTC    = 16;
input int             FILTER_MainWindow2EndMinUTC     = 30;
input int             FILTER_BreakoutStartHourUTC     = 6;
input int             FILTER_BreakoutStartMinUTC      = 55;
input int             FILTER_BreakoutEndHourUTC       = 9;
input int             FILTER_BreakoutEndMinUTC        = 0;
input int             FILTER_AsianSessionStartHourUTC = 0;
input int             FILTER_AsianSessionStartMinUTC  = 0;
input int             FILTER_AsianSessionEndHourUTC   = 6;
input int             FILTER_AsianSessionEndMinUTC    = 45;

input group "UI - Logging"
input bool            UI_EnableLogs                   = true;
input bool            UI_LogSignalRejections          = false;

int      g_handleEmaFastH1      = INVALID_HANDLE;
int      g_handleEmaMediumH1    = INVALID_HANDLE;
int      g_handleEmaSlowH1      = INVALID_HANDLE;
int      g_handleEmaMediumH4    = INVALID_HANDLE;
int      g_handleEmaSlowH4      = INVALID_HANDLE;
int      g_handleRsiH1          = INVALID_HANDLE;
int      g_handleRsiM15         = INVALID_HANDLE;
int      g_handleAtrH1          = INVALID_HANDLE;
int      g_handleAtrM15         = INVALID_HANDLE;
int      g_handleMacdH1         = INVALID_HANDLE;
int      g_handleMacdM15        = INVALID_HANDLE;
int      g_handleBandsM15       = INVALID_HANDLE;

datetime g_lastExecutionBarTime = 0;
datetime g_lastEntryBarTime     = 0;
ulong    g_partialTicket        = 0;
bool     g_hasPartialCloseRun   = false;
bool     g_loggedNewsFallback   = false;

int OnInit()
  {
   trade.SetExpertMagicNumber((long)GEN_MagicNumber);
   trade.SetDeviationInPoints(GEN_SlippagePoints);
   trade.SetTypeFillingBySymbol(_Symbol);

   g_handleEmaFastH1   = iMA(_Symbol, PERIOD_H1, ENTRY_FastEMA, 0, MODE_EMA, PRICE_CLOSE);
   g_handleEmaMediumH1 = iMA(_Symbol, PERIOD_H1, ENTRY_MediumEMA, 0, MODE_EMA, PRICE_CLOSE);
   g_handleEmaSlowH1   = iMA(_Symbol, PERIOD_H1, ENTRY_SlowEMA, 0, MODE_EMA, PRICE_CLOSE);
   g_handleEmaMediumH4 = iMA(_Symbol, PERIOD_H4, ENTRY_MediumEMA, 0, MODE_EMA, PRICE_CLOSE);
   g_handleEmaSlowH4   = iMA(_Symbol, PERIOD_H4, ENTRY_SlowEMA, 0, MODE_EMA, PRICE_CLOSE);
   g_handleRsiH1       = iRSI(_Symbol, PERIOD_H1, ENTRY_RSI_Period, PRICE_CLOSE);
   g_handleRsiM15      = iRSI(_Symbol, PERIOD_M15, ENTRY_RSI_Period, PRICE_CLOSE);
   g_handleAtrH1       = iATR(_Symbol, PERIOD_H1, ENTRY_ATR_Period);
   g_handleAtrM15      = iATR(_Symbol, PERIOD_M15, ENTRY_ATR_Period);
   g_handleMacdH1      = iMACD(_Symbol, PERIOD_H1, ENTRY_MACD_Fast, ENTRY_MACD_Slow, ENTRY_MACD_Signal, PRICE_CLOSE);
   g_handleMacdM15     = iMACD(_Symbol, PERIOD_M15, ENTRY_MACD_Fast, ENTRY_MACD_Slow, ENTRY_MACD_Signal, PRICE_CLOSE);
   g_handleBandsM15    = iBands(_Symbol, PERIOD_M15, ENTRY_BBands_Period, 0, ENTRY_BBands_Deviation, PRICE_CLOSE);

   if(!ValidateHandles())
     {
      WriteLog("Falha ao criar indicator handles.", true);
      return(INIT_FAILED);
     }

   DetectExistingManagedPosition();

   if(_Symbol != "EURUSD")
      WriteLog("EA desenhado para EURUSD. Verifique o símbolo atual.", false);

   WriteLog("EA inicializado com sucesso.", false);
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   ReleaseHandle(g_handleEmaFastH1);
   ReleaseHandle(g_handleEmaMediumH1);
   ReleaseHandle(g_handleEmaSlowH1);
   ReleaseHandle(g_handleEmaMediumH4);
   ReleaseHandle(g_handleEmaSlowH4);
   ReleaseHandle(g_handleRsiH1);
   ReleaseHandle(g_handleRsiM15);
   ReleaseHandle(g_handleAtrH1);
   ReleaseHandle(g_handleAtrM15);
   ReleaseHandle(g_handleMacdH1);
   ReleaseHandle(g_handleMacdM15);
   ReleaseHandle(g_handleBandsM15);
   WriteLog(StringFormat("EA finalizado. Reason=%d", reason), false);
  }

void OnTick()
  {
   ManageOpenPositions();

   if(!HasManagedPosition() && g_partialTicket != 0)
     {
      ClearPartialState(g_partialTicket);
      g_partialTicket = 0;
      g_hasPartialCloseRun = false;
     }

   if(HasManagedPosition())
      return;

   bool is_new_bar = CheckNewBar(PERIOD_M15, g_lastExecutionBarTime);
   if(GEN_OnlyOnNewBar && !is_new_bar)
      return;

   datetime current_bar = iTime(_Symbol, PERIOD_M15, 0);
   if(current_bar == 0 || current_bar == g_lastEntryBarTime)
      return;

   if(!PassCommonFilters())
      return;

   SignalSetup setup;
   if(GEN_AllowLongs && CheckBuySignal(setup))
     {
      if(OpenBuy(setup))
         g_lastEntryBarTime = current_bar;
      return;
     }

   if(GEN_AllowShorts && CheckSellSignal(setup))
     {
      if(OpenSell(setup))
         g_lastEntryBarTime = current_bar;
     }
  }

bool CheckNewBar(const ENUM_TIMEFRAMES timeframe, datetime &last_bar_time)
  {
   datetime current_bar_time = iTime(_Symbol, timeframe, 0);
   if(current_bar_time == 0)
      return(false);

   if(current_bar_time != last_bar_time)
     {
      last_bar_time = current_bar_time;
      return(true);
     }

   return(false);
  }

double GetSpreadPoints()
  {
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return(DBL_MAX);
   return((ask - bid) / _Point);
  }

double CalculateLotSize(const double stop_points)
  {
   double min_volume  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max_volume  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step_volume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   if(RISK_Model == RISK_FIXED_LOT)
      return(NormalizeVolume(RISK_FixedLot, min_volume, max_volume, step_volume));

   if(stop_points <= 0.0)
      return(0.0);

   double risk_percent = GetDynamicRiskPercent();
   double risk_amount  = AccountInfoDouble(ACCOUNT_EQUITY) * (risk_percent / 100.0);
   double tick_value   = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tick_size    = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

   if(risk_amount <= 0.0 || tick_value <= 0.0 || tick_size <= 0.0)
      return(0.0);

   double stop_price_distance = stop_points * _Point;
   double loss_per_lot        = (stop_price_distance / tick_size) * tick_value;
   if(loss_per_lot <= 0.0)
      return(0.0);

   double volume = risk_amount / loss_per_lot;
   return(NormalizeVolume(volume, min_volume, max_volume, step_volume));
  }

bool CheckBuySignal(SignalSetup &setup)
  {
   if(GetTrendBias() <= 0)
      return(false);

   if(CheckTrendPullbackSignal(true, setup))
      return(true);

   return(CheckSessionBreakoutSignal(true, setup));
  }

bool CheckSellSignal(SignalSetup &setup)
  {
   if(GetTrendBias() >= 0)
      return(false);

   if(CheckTrendPullbackSignal(false, setup))
      return(true);

   return(CheckSessionBreakoutSignal(false, setup));
  }

bool OpenBuy(const SignalSetup &setup)
  {
   double lots = CalculateLotSize(setup.risk_points);
   if(lots <= 0.0)
     {
      WriteLog("Lote inválido para BUY.", true);
      return(false);
     }

   string comment = BuildPositionComment((int)MathRound(setup.risk_points), setup.tag);
   bool result = trade.Buy(lots, _Symbol, 0.0, setup.stop_loss, setup.take_profit, comment);
   if(!result)
     {
      LogTradeFailure("BUY");
      return(false);
     }

   CacheOpenPositionState();
   WriteLog(StringFormat("BUY aberto. Lote=%.2f SL=%.5f TP=%.5f Setup=%s", lots, setup.stop_loss, setup.take_profit, setup.tag), false);
   return(true);
  }

bool OpenSell(const SignalSetup &setup)
  {
   double lots = CalculateLotSize(setup.risk_points);
   if(lots <= 0.0)
     {
      WriteLog("Lote inválido para SELL.", true);
      return(false);
     }

   string comment = BuildPositionComment((int)MathRound(setup.risk_points), setup.tag);
   bool result = trade.Sell(lots, _Symbol, 0.0, setup.stop_loss, setup.take_profit, comment);
   if(!result)
     {
      LogTradeFailure("SELL");
      return(false);
     }

   CacheOpenPositionState();
   WriteLog(StringFormat("SELL aberto. Lote=%.2f SL=%.5f TP=%.5f Setup=%s", lots, setup.stop_loss, setup.take_profit, setup.tag), false);
   return(true);
  }

void ManageOpenPositions()
  {
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != GEN_MagicNumber)
         continue;

      long   position_type = PositionGetInteger(POSITION_TYPE);
      double entry_price   = PositionGetDouble(POSITION_PRICE_OPEN);
      double current_sl    = PositionGetDouble(POSITION_SL);
      double volume        = PositionGetDouble(POSITION_VOLUME);
      string comment       = PositionGetString(POSITION_COMMENT);
      int    risk_points   = ParseRiskPoints(comment);

      if(risk_points <= 0)
         risk_points = (int)MathRound(MathAbs(entry_price - current_sl) / _Point);
      if(risk_points <= 0)
         continue;

      if(ticket != g_partialTicket)
        {
         g_partialTicket = ticket;
         g_hasPartialCloseRun = false;
        }

      double current_price = (position_type == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(current_price <= 0.0)
         continue;

      double profit_points = (position_type == POSITION_TYPE_BUY) ? (current_price - entry_price) / _Point : (entry_price - current_price) / _Point;
      double profit_rr     = profit_points / (double)risk_points;

      if(RISK_AllowPartialClose && !g_hasPartialCloseRun && profit_rr >= 1.0)
         TryPartialClose(ticket, volume);

      if(profit_rr >= EXIT_BreakEvenRR)
         TryMoveToBreakEven(ticket, position_type, entry_price, current_sl, PositionGetDouble(POSITION_TP));

      if(profit_rr >= EXIT_TrailingStartRR)
         ApplyTrailingStop(ticket);
     }
  }

void ApplyTrailingStop(const ulong ticket)
  {
   if(!PositionSelectByTicket(ticket))
      return;

   long position_type = PositionGetInteger(POSITION_TYPE);
   double current_tp  = PositionGetDouble(POSITION_TP);
   double current_sl  = PositionGetDouble(POSITION_SL);
   double bid         = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask         = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double atr_m15     = 0.0;
   if(!GetBufferValue(g_handleAtrM15, 0, 1, atr_m15))
      return;

   MqlRates rates[];
   if(!GetRates(PERIOD_M15, MathMax(ENTRY_SwingLookbackBars + 2, 8), rates))
      return;

   double swing_price = 0.0;
   double trail_price = 0.0;
   double min_stop_distance = GetBrokerStopDistancePrice();

   if(position_type == POSITION_TYPE_BUY)
     {
      swing_price = GetRecentSwingLow(rates, ENTRY_SwingLookbackBars);
      trail_price = MathMax(swing_price, bid - (atr_m15 * EXIT_TrailingATRMultiplier));
      trail_price = MathMin(trail_price, bid - min_stop_distance);
      if(trail_price > current_sl && trail_price < bid)
         ModifyPositionStops(ticket, trail_price, current_tp);
     }
   else if(position_type == POSITION_TYPE_SELL)
     {
      swing_price = GetRecentSwingHigh(rates, ENTRY_SwingLookbackBars);
      trail_price = MathMin(swing_price, ask + (atr_m15 * EXIT_TrailingATRMultiplier));
      trail_price = MathMax(trail_price, ask + min_stop_distance);
      if((current_sl == 0.0 || trail_price < current_sl) && trail_price > ask)
         ModifyPositionStops(ticket, trail_price, current_tp);
     }
  }

void WriteLog(const string message, const bool is_error)
  {
   if(!UI_EnableLogs && !is_error)
      return;

   if(is_error)
      Print("[GreenLion][ERROR] ", message);
   else
      Print("[GreenLion] ", message);
  }

bool PassCommonFilters()
  {
   if(HasForeignSymbolPosition())
     {
      if(UI_LogSignalRejections)
         WriteLog("Entrada rejeitada porque já existe posição externa no símbolo.", false);
      return(false);
     }

   if(GetSpreadPoints() > FILTER_MaxSpreadPoints)
     {
      if(UI_LogSignalRejections)
         WriteLog("Entrada rejeitada por spread.", false);
      return(false);
     }

   if(!IsWithinTradingHours())
     {
      if(UI_LogSignalRejections)
         WriteLog("Entrada rejeitada por janela horária.", false);
      return(false);
     }

   if(IsNewsWindow())
     {
      if(UI_LogSignalRejections)
         WriteLog("Entrada rejeitada por filtro de notícias.", false);
      return(false);
     }

   if(GetTradesOpenedToday() >= RISK_MaxTradesPerDay)
     {
      if(UI_LogSignalRejections)
         WriteLog("Entrada rejeitada por limite diário de trades.", false);
      return(false);
     }

   if(!CheckDrawdownLimits())
     {
      if(UI_LogSignalRejections)
         WriteLog("Entrada rejeitada por drawdown.", false);
      return(false);
     }

   return(true);
  }

bool CheckTrendPullbackSignal(const bool is_buy, SignalSetup &setup)
  {
   double ema20_h1 = 0.0, ema50_h1 = 0.0, ema200_h1 = 0.0;
   double rsi_m15 = 0.0, rsi_m15_prev = 0.0, atr_h1 = 0.0, atr_m15 = 0.0;
   double macd_main_1 = 0.0, macd_signal_1 = 0.0, macd_main_2 = 0.0, macd_signal_2 = 0.0;
   double bb_upper = 0.0, bb_lower = 0.0;

   if(!GetBufferValue(g_handleEmaFastH1, 0, 1, ema20_h1) ||
      !GetBufferValue(g_handleEmaMediumH1, 0, 1, ema50_h1) ||
      !GetBufferValue(g_handleEmaSlowH1, 0, 1, ema200_h1) ||
      !GetBufferValue(g_handleRsiM15, 0, 1, rsi_m15) ||
      !GetBufferValue(g_handleRsiM15, 0, 2, rsi_m15_prev) ||
      !GetBufferValue(g_handleAtrH1, 0, 1, atr_h1) ||
      !GetBufferValue(g_handleAtrM15, 0, 1, atr_m15) ||
      !GetBufferValue(g_handleMacdM15, 0, 1, macd_main_1) ||
      !GetBufferValue(g_handleMacdM15, 1, 1, macd_signal_1) ||
      !GetBufferValue(g_handleMacdM15, 0, 2, macd_main_2) ||
      !GetBufferValue(g_handleMacdM15, 1, 2, macd_signal_2) ||
      !GetBufferValue(g_handleBandsM15, 1, 1, bb_upper) ||
      !GetBufferValue(g_handleBandsM15, 2, 1, bb_lower))
      return(false);

   if(!IsAtrTradable(atr_h1))
      return(false);

   MqlRates h1_rates[];
   MqlRates m15_rates[];
   if(!GetRates(PERIOD_H1, 5, h1_rates) || !GetRates(PERIOD_M15, MathMax(ENTRY_SwingLookbackBars + 3, 8), m15_rates))
      return(false);

   double close_h1 = h1_rates[1].close;
   double pullback_tolerance = atr_h1 * ENTRY_PullbackToleranceATR;
   bool near_fast = MathAbs(close_h1 - ema20_h1) <= pullback_tolerance;
   bool near_medium = MathAbs(close_h1 - ema50_h1) <= pullback_tolerance;
   double macd_hist_1 = macd_main_1 - macd_signal_1;
   double macd_hist_2 = macd_main_2 - macd_signal_2;
   double close_m15 = m15_rates[1].close;

   if(is_buy)
     {
      bool candle_ok = IsBullishPattern(m15_rates);
      bool pullback_ok = close_h1 > ema200_h1 && (near_fast || near_medium);
      bool momentum_ok = rsi_m15 > 50.0 && rsi_m15 >= rsi_m15_prev && macd_hist_1 > 0.0 && macd_hist_1 > macd_hist_2;
      bool exhaustion_ok = (bb_upper - close_m15) > (atr_m15 * 0.10);
      if(!(candle_ok && pullback_ok && momentum_ok && exhaustion_ok))
         return(false);

      double entry_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double swing_low   = GetRecentSwingLow(m15_rates, ENTRY_SwingLookbackBars);
      BuildTradeLevels(true, entry_price, swing_low, atr_m15, atr_h1, "TP", setup);
      return(ValidateSetup(setup, true));
     }

   bool candle_ok = IsBearishPattern(m15_rates);
   bool pullback_ok = close_h1 < ema200_h1 && (near_fast || near_medium);
   bool momentum_ok = rsi_m15 < 50.0 && rsi_m15 <= rsi_m15_prev && macd_hist_1 < 0.0 && macd_hist_1 < macd_hist_2;
   bool exhaustion_ok = (close_m15 - bb_lower) > (atr_m15 * 0.10);
   if(!(candle_ok && pullback_ok && momentum_ok && exhaustion_ok))
      return(false);

   double entry_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double swing_high  = GetRecentSwingHigh(m15_rates, ENTRY_SwingLookbackBars);
   BuildTradeLevels(false, entry_price, swing_high, atr_m15, atr_h1, "TP", setup);
   return(ValidateSetup(setup, false));
  }

bool CheckSessionBreakoutSignal(const bool is_buy, SignalSetup &setup)
  {
   if(!IsWithinBreakoutWindow())
      return(false);

   double asian_high = 0.0, asian_low = 0.0;
   if(!GetAsianRange(asian_high, asian_low))
      return(false);

   double range_points = (asian_high - asian_low) / _Point;
   if(range_points < ENTRY_MinAsianRangePoints || range_points > ENTRY_MaxAsianRangePoints)
      return(false);

   double atr_h1 = 0.0, atr_m15 = 0.0, bb_upper_1 = 0.0, bb_lower_1 = 0.0, bb_upper_2 = 0.0, bb_lower_2 = 0.0;
   double macd_main_1 = 0.0, macd_signal_1 = 0.0, macd_main_2 = 0.0, macd_signal_2 = 0.0;

   if(!GetBufferValue(g_handleAtrH1, 0, 1, atr_h1) ||
      !GetBufferValue(g_handleAtrM15, 0, 1, atr_m15) ||
      !GetBufferValue(g_handleBandsM15, 1, 1, bb_upper_1) ||
      !GetBufferValue(g_handleBandsM15, 2, 1, bb_lower_1) ||
      !GetBufferValue(g_handleBandsM15, 1, 2, bb_upper_2) ||
      !GetBufferValue(g_handleBandsM15, 2, 2, bb_lower_2) ||
      !GetBufferValue(g_handleMacdM15, 0, 1, macd_main_1) ||
      !GetBufferValue(g_handleMacdM15, 1, 1, macd_signal_1) ||
      !GetBufferValue(g_handleMacdM15, 0, 2, macd_main_2) ||
      !GetBufferValue(g_handleMacdM15, 1, 2, macd_signal_2))
      return(false);

   if(!IsAtrTradable(atr_h1))
      return(false);

   MqlRates m15_rates[];
   if(!GetRates(PERIOD_M15, MathMax(ENTRY_SwingLookbackBars + 3, 8), m15_rates))
      return(false);

   double squeeze_width_prev = (bb_upper_2 - bb_lower_2) / _Point;
   double squeeze_width_now  = (bb_upper_1 - bb_lower_1) / _Point;
   double macd_hist_1 = macd_main_1 - macd_signal_1;
   double macd_hist_2 = macd_main_2 - macd_signal_2;
   double breakout_buffer = ENTRY_BreakoutBufferPoints * _Point;

   if(is_buy)
     {
      bool breakout_ok = m15_rates[1].close > asian_high + breakout_buffer && m15_rates[2].close <= asian_high + breakout_buffer;
      bool squeeze_ok = squeeze_width_prev <= ENTRY_MaxSqueezeWidthPoints && squeeze_width_now > squeeze_width_prev;
      bool momentum_ok = macd_hist_1 > 0.0 && macd_hist_1 > macd_hist_2;
      if(!(breakout_ok && squeeze_ok && momentum_ok))
         return(false);

      double entry_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double anchor = MathMin(asian_low, GetRecentSwingLow(m15_rates, ENTRY_SwingLookbackBars));
      BuildTradeLevels(true, entry_price, anchor, atr_m15, atr_h1, "BO", setup);
      return(ValidateSetup(setup, true));
     }

   bool breakout_ok = m15_rates[1].close < asian_low - breakout_buffer && m15_rates[2].close >= asian_low - breakout_buffer;
   bool squeeze_ok = squeeze_width_prev <= ENTRY_MaxSqueezeWidthPoints && squeeze_width_now > squeeze_width_prev;
   bool momentum_ok = macd_hist_1 < 0.0 && macd_hist_1 < macd_hist_2;
   if(!(breakout_ok && squeeze_ok && momentum_ok))
      return(false);

   double entry_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double anchor = MathMax(asian_high, GetRecentSwingHigh(m15_rates, ENTRY_SwingLookbackBars));
   BuildTradeLevels(false, entry_price, anchor, atr_m15, atr_h1, "BO", setup);
   return(ValidateSetup(setup, false));
  }

int GetTrendBias()
  {
   double ema50_h4_1 = 0.0, ema50_h4_2 = 0.0, ema200_h4_1 = 0.0;
   double rsi_h1 = 0.0, macd_main_h1 = 0.0, macd_signal_h1 = 0.0, atr_h1 = 0.0;

   if(!GetBufferValue(g_handleEmaMediumH4, 0, 1, ema50_h4_1) ||
      !GetBufferValue(g_handleEmaMediumH4, 0, 2, ema50_h4_2) ||
      !GetBufferValue(g_handleEmaSlowH4, 0, 1, ema200_h4_1) ||
      !GetBufferValue(g_handleRsiH1, 0, 1, rsi_h1) ||
      !GetBufferValue(g_handleMacdH1, 0, 1, macd_main_h1) ||
      !GetBufferValue(g_handleMacdH1, 1, 1, macd_signal_h1) ||
      !GetBufferValue(g_handleAtrH1, 0, 1, atr_h1))
      return(0);

   if(!IsAtrTradable(atr_h1))
      return(0);

   double separation_points = MathAbs(ema50_h4_1 - ema200_h4_1) / _Point;
   if(separation_points < ENTRY_MinTrendSeparationPoints)
      return(0);

   if(rsi_h1 >= 45.0 && rsi_h1 <= 55.0)
      return(0);

   double macd_hist = macd_main_h1 - macd_signal_h1;

   if(ema50_h4_1 > ema200_h4_1 && ema50_h4_1 > ema50_h4_2 && macd_hist >= 0.0)
      return(1);

   if(ema50_h4_1 < ema200_h4_1 && ema50_h4_1 < ema50_h4_2 && macd_hist <= 0.0)
      return(-1);

   return(0);
  }

bool IsWithinTradingHours()
  {
   datetime now_utc = GetReferenceUtcTime();
   return(IsWithinWindow(now_utc,
                         FILTER_MainWindow1StartHourUTC,
                         FILTER_MainWindow1StartMinUTC,
                         FILTER_MainWindow1EndHourUTC,
                         FILTER_MainWindow1EndMinUTC) ||
          IsWithinWindow(now_utc,
                         FILTER_MainWindow2StartHourUTC,
                         FILTER_MainWindow2StartMinUTC,
                         FILTER_MainWindow2EndHourUTC,
                         FILTER_MainWindow2EndMinUTC));
  }

bool IsWithinBreakoutWindow()
  {
   return(IsWithinWindow(GetReferenceUtcTime(),
                         FILTER_BreakoutStartHourUTC,
                         FILTER_BreakoutStartMinUTC,
                         FILTER_BreakoutEndHourUTC,
                         FILTER_BreakoutEndMinUTC));
  }

bool IsWithinWindow(const datetime timestamp, const int start_hour, const int start_minute, const int end_hour, const int end_minute)
  {
   MqlDateTime utc_time;
   TimeToStruct(timestamp, utc_time);
   int now_minutes = utc_time.hour * 60 + utc_time.min;
   int start_minutes = start_hour * 60 + start_minute;
   int end_minutes = end_hour * 60 + end_minute;
   return(now_minutes >= start_minutes && now_minutes <= end_minutes);
  }

datetime GetReferenceUtcTime()
  {
   if(FILTER_UseServerTime)
      return(TimeCurrent() - (FILTER_ServerUtcOffsetHours * 3600));

   datetime gmt_now = TimeGMT();
   if(gmt_now > 0)
      return(gmt_now);
   return(TimeCurrent());
  }

bool IsNewsWindow()
  {
   if(!FILTER_UseNewsFilter)
      return(false);
   if(!g_loggedNewsFallback)
     {
         WriteLog(StringFormat("Filtro de notícias ativado (%d/%d min), mas esta versão exige integração manual com calendário externo antes de bloquear trades.",
                               FILTER_NewsBlockMinutesBefore,
                               FILTER_NewsBlockMinutesAfter), false);
         g_loggedNewsFallback = true;
        }
   return(false);
  }

bool CheckDrawdownLimits()
  {
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(balance <= 0.0)
      return(false);

   double daily_loss_pct = (GetAggregateProfit(GetStartOfDay(), TimeCurrent()) / balance) * 100.0;
   double weekly_loss_pct = (GetAggregateProfit(GetStartOfWeek(), TimeCurrent()) / balance) * 100.0;

   if(daily_loss_pct <= -MathAbs(RISK_MaxDailyDrawdownPercent))
      return(false);
   if(weekly_loss_pct <= -MathAbs(RISK_MaxWeeklyDrawdownPercent))
      return(false);

   return(true);
  }

double GetAggregateProfit(const datetime from, const datetime to)
  {
   double total = GetClosedProfit(from, to) + GetOpenProfit();
   return(total);
  }

double GetClosedProfit(const datetime from, const datetime to)
  {
   if(!HistorySelect(from, to))
      return(0.0);

   double profit = 0.0;
   int deals_total = HistoryDealsTotal();
   for(int i = 0; i < deals_total; ++i)
     {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0)
         continue;

      if(HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol)
         continue;
      if((ulong)HistoryDealGetInteger(ticket, DEAL_MAGIC) != GEN_MagicNumber)
         continue;

      long entry = HistoryDealGetInteger(ticket, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_OUT)
         continue;

      profit += HistoryDealGetDouble(ticket, DEAL_PROFIT) +
                HistoryDealGetDouble(ticket, DEAL_SWAP) +
                HistoryDealGetDouble(ticket, DEAL_COMMISSION);
     }

   return(profit);
  }

double GetOpenProfit()
  {
   double profit = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != GEN_MagicNumber)
         continue;

      profit += PositionGetDouble(POSITION_PROFIT);
     }
   return(profit);
  }

int GetTradesOpenedToday()
  {
   datetime start_day = GetStartOfDay();
   if(!HistorySelect(start_day, TimeCurrent()))
      return(0);

   int count = 0;
   int deals_total = HistoryDealsTotal();
   for(int i = 0; i < deals_total; ++i)
     {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0)
         continue;

      if(HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol)
         continue;
      if((ulong)HistoryDealGetInteger(ticket, DEAL_MAGIC) != GEN_MagicNumber)
         continue;
      if((long)HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_IN)
         count++;
     }
   return(count);
  }

double GetDynamicRiskPercent()
  {
   int consecutive_losses = GetConsecutiveLossesToday();
   if(consecutive_losses >= 2)
      return(RISK_ReducedPercentPerTrade);
   return(RISK_PercentPerTrade);
  }

int GetConsecutiveLossesToday()
  {
   datetime start_day = GetStartOfDay();
   if(!HistorySelect(start_day, TimeCurrent()))
      return(0);

   int losses = 0;
   for(int i = HistoryDealsTotal() - 1; i >= 0; --i)
     {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0)
         continue;

      if(HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol)
         continue;
      if((ulong)HistoryDealGetInteger(ticket, DEAL_MAGIC) != GEN_MagicNumber)
         continue;
      if((long)HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_OUT)
         continue;

      double result = HistoryDealGetDouble(ticket, DEAL_PROFIT) +
                      HistoryDealGetDouble(ticket, DEAL_SWAP) +
                      HistoryDealGetDouble(ticket, DEAL_COMMISSION);
      if(result < 0.0)
         losses++;
      else
         break;
     }
   return(losses);
  }

bool HasManagedPosition()
  {
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;

      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         (ulong)PositionGetInteger(POSITION_MAGIC) == GEN_MagicNumber)
         return(true);
     }
   return(false);
  }

bool HasForeignSymbolPosition()
  {
   if(!PositionSelect(_Symbol))
      return(false);

   return((ulong)PositionGetInteger(POSITION_MAGIC) != GEN_MagicNumber);
  }

void DetectExistingManagedPosition()
  {
   g_partialTicket = 0;
   g_hasPartialCloseRun = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;

      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         (ulong)PositionGetInteger(POSITION_MAGIC) == GEN_MagicNumber)
        {
         g_partialTicket = ticket;
         g_hasPartialCloseRun = LoadPartialState(ticket);
         return;
        }
     }
  }

void CacheOpenPositionState()
  {
   if(!PositionSelect(_Symbol))
      return;

   if((ulong)PositionGetInteger(POSITION_MAGIC) != GEN_MagicNumber)
      return;

   g_partialTicket = (ulong)PositionGetInteger(POSITION_TICKET);
   g_hasPartialCloseRun = LoadPartialState(g_partialTicket);
  }

void TryPartialClose(const ulong ticket, const double volume)
  {
   double close_volume = volume * (RISK_PartialClosePercent / 100.0);
   double min_volume   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double step_volume  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   close_volume = NormalizeVolume(close_volume, min_volume, volume, step_volume);
   if(close_volume < min_volume || (volume - close_volume) < min_volume)
     {
      g_hasPartialCloseRun = true;
      SavePartialState(ticket);
      return;
     }

   if(trade.PositionClosePartial(ticket, close_volume))
     {
      g_hasPartialCloseRun = true;
      SavePartialState(ticket);
      WriteLog(StringFormat("Parcial executada no ticket %I64u com %.2f lots.", ticket, close_volume), false);
      return;
     }

   g_hasPartialCloseRun = true;
   LogTradeFailure("PARTIAL_CLOSE");
  }

void TryMoveToBreakEven(const ulong ticket, const long position_type, const double entry_price, const double current_sl, const double current_tp)
  {
   if(!HasContinuationStructure(position_type))
      return;

   double buffer_price = EXIT_BreakEvenBufferPoints * _Point;
   double min_stop_distance = GetBrokerStopDistancePrice();
   double new_sl = current_sl;

   if(position_type == POSITION_TYPE_BUY)
     {
      new_sl = entry_price + buffer_price;
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(new_sl >= bid - min_stop_distance)
         return;
      if(current_sl >= new_sl)
         return;
     }
   else if(position_type == POSITION_TYPE_SELL)
     {
      new_sl = entry_price - buffer_price;
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(new_sl <= ask + min_stop_distance)
         return;
      if(current_sl > 0.0 && current_sl <= new_sl)
         return;
     }

   ModifyPositionStops(ticket, new_sl, current_tp);
  }

bool HasContinuationStructure(const long position_type)
  {
   MqlRates rates[];
   if(!GetRates(PERIOD_M15, 4, rates))
      return(false);

   if(position_type == POSITION_TYPE_BUY)
      return(rates[1].close > rates[1].open && rates[1].close > rates[2].high);

   if(position_type == POSITION_TYPE_SELL)
      return(rates[1].close < rates[1].open && rates[1].close < rates[2].low);

   return(false);
  }

bool ModifyPositionStops(const ulong ticket, const double sl, const double tp)
  {
   double normalized_sl = NormalizeDouble(sl, _Digits);
   double normalized_tp = NormalizeDouble(tp, _Digits);
   if(trade.PositionModify(ticket, normalized_sl, normalized_tp))
      return(true);

   WriteLog(StringFormat("Falha ao modificar stops do ticket %I64u.", ticket), true);
   LogTradeFailure("POSITION_MODIFY");
   return(false);
  }

bool GetAsianRange(double &asian_high, double &asian_low)
  {
   datetime now_utc = GetReferenceUtcTime();
   MqlDateTime utc_parts;
   TimeToStruct(now_utc, utc_parts);
   utc_parts.hour = 0;
   utc_parts.min = 0;
   utc_parts.sec = 0;
   datetime day_start_utc = StructToTime(utc_parts);

   datetime from_utc = day_start_utc + (FILTER_AsianSessionStartHourUTC * 3600) + (FILTER_AsianSessionStartMinUTC * 60);
   datetime to_utc   = day_start_utc + (FILTER_AsianSessionEndHourUTC * 3600) + (FILTER_AsianSessionEndMinUTC * 60);

   datetime from = ConvertUtcToSeriesTime(from_utc);
   datetime to   = ConvertUtcToSeriesTime(to_utc);
   if(to <= from)
      return(false);

   MqlRates rates[];
   int copied = CopyRates(_Symbol, PERIOD_M15, from, to, rates);
   if(copied <= 0)
      return(false);

   ArraySetAsSeries(rates, false);
   asian_high = rates[0].high;
   asian_low  = rates[0].low;
   for(int i = 1; i < copied; ++i)
     {
      if(rates[i].high > asian_high)
         asian_high = rates[i].high;
      if(rates[i].low < asian_low)
         asian_low = rates[i].low;
     }

   return(asian_high > asian_low);
  }

datetime ConvertUtcToSeriesTime(const datetime utc_time)
  {
   if(FILTER_UseServerTime)
      return(utc_time + (FILTER_ServerUtcOffsetHours * 3600));

   datetime gmt_now = TimeGMT();
   datetime server_now = TimeCurrent();
   if(gmt_now <= 0 || server_now <= 0)
      return(utc_time);

   int offset_seconds = (int)(server_now - gmt_now);
   return(utc_time + offset_seconds);
  }

bool ValidateHandles()
  {
   return(g_handleEmaFastH1   != INVALID_HANDLE &&
          g_handleEmaMediumH1 != INVALID_HANDLE &&
          g_handleEmaSlowH1   != INVALID_HANDLE &&
          g_handleEmaMediumH4 != INVALID_HANDLE &&
          g_handleEmaSlowH4   != INVALID_HANDLE &&
          g_handleRsiH1       != INVALID_HANDLE &&
          g_handleRsiM15      != INVALID_HANDLE &&
          g_handleAtrH1       != INVALID_HANDLE &&
          g_handleAtrM15      != INVALID_HANDLE &&
          g_handleMacdH1      != INVALID_HANDLE &&
          g_handleMacdM15     != INVALID_HANDLE &&
          g_handleBandsM15    != INVALID_HANDLE);
  }

void ReleaseHandle(int &handle)
  {
   if(handle != INVALID_HANDLE)
     {
      IndicatorRelease(handle);
      handle = INVALID_HANDLE;
     }
  }

bool GetBufferValue(const int handle, const int buffer_index, const int shift, double &value)
  {
   if(handle == INVALID_HANDLE)
      return(false);

   double data[];
   ArraySetAsSeries(data, true);
   int copied = CopyBuffer(handle, buffer_index, shift, 1, data);
   if(copied != 1)
     {
      WriteLog(StringFormat("CopyBuffer falhou. Handle=%d Buffer=%d Shift=%d", handle, buffer_index, shift), true);
      return(false);
     }

   value = data[0];
   return(true);
  }

bool GetRates(const ENUM_TIMEFRAMES timeframe, const int count, MqlRates &rates[])
  {
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, timeframe, 0, count, rates);
   if(copied < count)
     {
      WriteLog(StringFormat("CopyRates falhou em %s. Esperado=%d Obtido=%d", EnumToString(timeframe), count, copied), true);
      return(false);
     }
   return(true);
  }

bool IsAtrTradable(const double atr_h1)
  {
   double atr_points = atr_h1 / _Point;
   return(atr_points >= FILTER_MinATRH1Points && atr_points <= FILTER_MaxATRH1Points);
  }

double NormalizeVolume(const double volume, const double min_volume, const double max_volume, const double step_volume)
  {
   if(step_volume <= 0.0)
      return(0.0);

   double bounded = MathMax(min_volume, MathMin(max_volume, volume));
   double steps   = MathFloor((bounded / step_volume) + 1e-8);
   double normalized = steps * step_volume;
   normalized = MathMax(min_volume, MathMin(max_volume, normalized));
   return(NormalizeDouble(normalized, 2));
  }

void BuildTradeLevels(const bool is_buy,
                      const double entry_price,
                      const double anchor_price,
                      const double atr_m15,
                      const double atr_h1,
                      const string tag,
                      SignalSetup &setup)
  {
   double anchor_risk_points = MathAbs(entry_price - anchor_price) / _Point;
   double atr_risk_points    = (MathMax(atr_m15, atr_h1) * ENTRY_StopATRMultiplier) / _Point;
   double min_stop_points    = MathCeil(GetBrokerStopDistancePrice() / _Point) + 5.0;
   double risk_points        = MathMax(anchor_risk_points, MathMax(atr_risk_points, min_stop_points));

   if(is_buy)
     {
      setup.stop_loss   = NormalizeDouble(entry_price - (risk_points * _Point), _Digits);
      setup.take_profit = NormalizeDouble(entry_price + (risk_points * EXIT_FinalTargetRR * _Point), _Digits);
     }
   else
     {
      setup.stop_loss   = NormalizeDouble(entry_price + (risk_points * _Point), _Digits);
      setup.take_profit = NormalizeDouble(entry_price - (risk_points * EXIT_FinalTargetRR * _Point), _Digits);
     }

   setup.risk_points = risk_points;
   setup.tag = tag;
  }

bool ValidateSetup(const SignalSetup &setup, const bool is_buy)
  {
   if(setup.risk_points <= 0.0)
      return(false);
   if(setup.stop_loss <= 0.0 || setup.take_profit <= 0.0)
      return(false);

   double min_stop_distance = GetBrokerStopDistancePrice();
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return(false);

   if(is_buy)
     {
      if(setup.stop_loss >= bid)
         return(false);
      if((bid - setup.stop_loss) < min_stop_distance)
         return(false);
      if(setup.take_profit <= ask)
         return(false);
     }
   else
     {
      if(setup.stop_loss <= ask)
         return(false);
      if((setup.stop_loss - ask) < min_stop_distance)
         return(false);
      if(setup.take_profit >= bid)
         return(false);
     }

   return(true);
  }

double GetBrokerStopDistancePrice()
  {
   long stop_level_points = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   return(MathMax((double)stop_level_points, 1.0) * _Point);
  }

double GetRecentSwingLow(MqlRates &rates[], const int lookback)
  {
   double low_value = rates[1].low;
   int limit = MathMin(lookback, ArraySize(rates) - 2);
   for(int i = 1; i <= limit; ++i)
      low_value = MathMin(low_value, rates[i].low);
   return(low_value);
  }

double GetRecentSwingHigh(MqlRates &rates[], const int lookback)
  {
   double high_value = rates[1].high;
   int limit = MathMin(lookback, ArraySize(rates) - 2);
   for(int i = 1; i <= limit; ++i)
      high_value = MathMax(high_value, rates[i].high);
   return(high_value);
  }

bool IsBullishPattern(MqlRates &rates[])
  {
   return(IsBullishEngulfing(rates) || IsBullishRejection(rates));
  }

bool IsBearishPattern(MqlRates &rates[])
  {
   return(IsBearishEngulfing(rates) || IsBearishRejection(rates));
  }

bool IsBullishEngulfing(MqlRates &rates[])
  {
   return(rates[2].close < rates[2].open &&
          rates[1].close > rates[1].open &&
          rates[1].open <= rates[2].close &&
          rates[1].close >= rates[2].open);
  }

bool IsBearishEngulfing(MqlRates &rates[])
  {
   return(rates[2].close > rates[2].open &&
          rates[1].close < rates[1].open &&
          rates[1].open >= rates[2].close &&
          rates[1].close <= rates[2].open);
  }

bool IsBullishRejection(MqlRates &rates[])
  {
   double body = MathAbs(rates[1].close - rates[1].open);
   double lower_wick = MathMin(rates[1].open, rates[1].close) - rates[1].low;
   double upper_wick = rates[1].high - MathMax(rates[1].open, rates[1].close);
   return(rates[1].close > rates[1].open && lower_wick > (body * 1.2) && upper_wick < lower_wick);
  }

bool IsBearishRejection(MqlRates &rates[])
  {
   double body = MathAbs(rates[1].close - rates[1].open);
   double upper_wick = rates[1].high - MathMax(rates[1].open, rates[1].close);
   double lower_wick = MathMin(rates[1].open, rates[1].close) - rates[1].low;
   return(rates[1].close < rates[1].open && upper_wick > (body * 1.2) && lower_wick < upper_wick);
  }

string BuildPositionComment(const int risk_points, const string tag)
  {
   return(StringFormat("GL|%d|%s", risk_points, tag));
  }

string BuildPartialStateKey(const ulong ticket)
  {
   return(StringFormat("GreenLionPartial_%I64u_%I64u", GEN_MagicNumber, ticket));
  }

bool LoadPartialState(const ulong ticket)
  {
   return(GlobalVariableCheck(BuildPartialStateKey(ticket)));
  }

void SavePartialState(const ulong ticket)
  {
   GlobalVariableSet(BuildPartialStateKey(ticket), 1.0);
  }

void ClearPartialState(const ulong ticket)
  {
   string key = BuildPartialStateKey(ticket);
   if(GlobalVariableCheck(key))
      GlobalVariableDel(key);
  }

int ParseRiskPoints(const string comment)
  {
   string parts[];
   int count = StringSplit(comment, '|', parts);
   if(count < 3)
      return(0);
   return((int)StringToInteger(parts[1]));
  }

datetime GetStartOfDay()
  {
   MqlDateTime now_parts;
   TimeToStruct(TimeCurrent(), now_parts);
   now_parts.hour = 0;
   now_parts.min = 0;
   now_parts.sec = 0;
   return(StructToTime(now_parts));
  }

datetime GetStartOfWeek()
  {
   MqlDateTime now_parts;
   TimeToStruct(TimeCurrent(), now_parts);
   datetime start_day = GetStartOfDay();
   int weekday = now_parts.day_of_week;
   if(weekday == 0)
      weekday = 7;
   return(start_day - ((weekday - 1) * 86400));
  }

void LogTradeFailure(const string action)
  {
   WriteLog(StringFormat("%s falhou. Retcode=%u Desc=%s LastError=%d",
                         action,
                         trade.ResultRetcode(),
                         trade.ResultRetcodeDescription(),
                         GetLastError()), true);
   ResetLastError();
  }
