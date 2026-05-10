#property copyright "TITAN LION FX"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property description "AurumTitanX - EA modular para XAUUSD com 5 estratégias e 5 níveis de risco."

#include <Trade/Trade.mqh>

enum ENUM_ATX_STRATEGY_PROFILE
  {
   ATX_STRATEGY_IMPERIAL_TREND = 0,
   ATX_STRATEGY_LONDON_BREAKOUT = 1,
   ATX_STRATEGY_NEWYORK_MOMENTUM = 2,
   ATX_STRATEGY_ASIA_REVERSION = 3,
   ATX_STRATEGY_VOLATILITY_SWING = 4
  };

enum ENUM_ATX_RISK_MODEL
  {
   ATX_RISK_FIXED_LOT = 0,
   ATX_RISK_PERCENT_EQUITY = 1
  };

enum ENUM_ATX_RISK_PROFILE
  {
   ATX_RISK_LEVEL_1_DEFENSIVE = 0,
   ATX_RISK_LEVEL_2_CONSERVATIVE = 1,
   ATX_RISK_LEVEL_3_BALANCED = 2,
   ATX_RISK_LEVEL_4_DYNAMIC = 3,
   ATX_RISK_LEVEL_5_AGGRESSIVE = 4
  };

struct StrategyConfig
  {
   string            name;
   string            recommended_balance;
   string            notes;
   ENUM_TIMEFRAMES   signal_timeframe;
   ENUM_TIMEFRAMES   trend_timeframe;
   int               fast_ema;
   int               slow_ema;
   double            rsi_buy_min;
   double            rsi_buy_max;
   double            rsi_sell_min;
   double            rsi_sell_max;
   double            stop_atr_multiplier;
   double            risk_reward;
   bool              require_pullback;
   bool              require_asian_breakout;
   bool              require_momentum_breakout;
   bool              require_mean_reversion;
   bool              require_volatility_expansion;
   int               session_start_hour_utc;
   int               session_end_hour_utc;
  };

struct RiskProfileConfig
  {
   string            name;
   double            volume_multiplier;
   double            risk_multiplier;
   double            spread_multiplier;
   double            stop_multiplier;
   double            rr_multiplier;
   int               max_trades_per_day;
   bool              use_break_even;
   bool              use_trailing;
   double            break_even_rr;
   double            trailing_atr_multiplier;
  };

CTrade g_trade;

const double ATX_LOT_EPSILON = 1e-8;
const double ATX_STOP_BUFFER_ATR = 0.15;

input group "GEN - General"
input ulong                      GEN_MagicNumber                = 2026051021;
input ENUM_ATX_STRATEGY_PROFILE  GEN_StrategyProfile            = ATX_STRATEGY_IMPERIAL_TREND;
input int                        GEN_SlippagePoints             = 80;
input bool                       GEN_AllowLongs                 = true;
input bool                       GEN_AllowShorts                = true;
input bool                       GEN_OnlyOnNewBar               = true;
input bool                       GEN_RequireGoldSymbol          = true;

input group "RISK - Risk Management"
input ENUM_ATX_RISK_PROFILE      RISK_Profile                   = ATX_RISK_LEVEL_3_BALANCED;
input ENUM_ATX_RISK_MODEL        RISK_Model                     = ATX_RISK_PERCENT_EQUITY;
input double                     RISK_FixedLot                  = 0.01;
input double                     RISK_BasePercentPerTrade       = 0.75;
input double                     RISK_MaxDailyDrawdownPercent   = 4.0;

input group "ENTRY - Entry Logic"
input int                        ENTRY_RSI_Period               = 14;
input int                        ENTRY_ATR_Period               = 14;
input int                        ENTRY_BBands_Period            = 20;
input double                     ENTRY_BBands_Deviation         = 2.0;
input double                     ENTRY_BreakoutBufferPoints     = 120.0;
input double                     ENTRY_PullbackToleranceATR     = 0.35;
input double                     ENTRY_MinBodyToAtrRatio        = 0.35;
input int                        ENTRY_SwingLookbackBars        = 8;
input double                     ENTRY_MinAsianRangePoints      = 400.0;
input double                     ENTRY_MaxAsianRangePoints      = 3500.0;

input group "EXIT - Trade Management"
input bool                       EXIT_UseBreakEven              = true;
input double                     EXIT_BreakEvenBufferPoints     = 80.0;
input bool                       EXIT_UseTrailingStop           = true;
input double                     EXIT_TrailingAtrMultiplier     = 1.20;

input group "FILTER - Filters"
input double                     FILTER_MaxSpreadPoints         = 450.0;
input double                     FILTER_MinATRPoints            = 180.0;
input double                     FILTER_MaxATRPoints            = 5000.0;
input int                        FILTER_ServerUtcOffsetHours    = 0;
input int                        FILTER_AsiaSessionStartHourUTC = 0;
input int                        FILTER_AsiaSessionEndHourUTC   = 6;
input int                        FILTER_LondonStartHourUTC      = 6;
input int                        FILTER_LondonEndHourUTC        = 11;
input int                        FILTER_NewYorkStartHourUTC     = 12;
input int                        FILTER_NewYorkEndHourUTC       = 17;

input group "UI - Logging"
input bool                       UI_EnableLogs                  = true;
input bool                       UI_LogSignalRejections         = false;

int                 g_handleSignalFastEma = INVALID_HANDLE;
int                 g_handleSignalSlowEma = INVALID_HANDLE;
int                 g_handleTrendFastEma  = INVALID_HANDLE;
int                 g_handleTrendSlowEma  = INVALID_HANDLE;
int                 g_handleSignalRsi     = INVALID_HANDLE;
int                 g_handleSignalAtr     = INVALID_HANDLE;
int                 g_handleSignalBands   = INVALID_HANDLE;

datetime            g_lastProcessedBar    = 0;
datetime            g_lastEntryBar        = 0;
StrategyConfig      g_strategy;
RiskProfileConfig   g_risk;

void WriteLog(const string message, const bool is_error = false)
  {
   if(!UI_EnableLogs && !is_error)
      return;

   string prefix = is_error ? "[AurumTitanX][ERROR] " : "[AurumTitanX] ";
   Print(prefix + message);
  }

void ReleaseHandle(int &handle)
  {
   if(handle != INVALID_HANDLE)
     {
      IndicatorRelease(handle);
      handle = INVALID_HANDLE;
     }
  }

string TimeframeToText(const ENUM_TIMEFRAMES timeframe)
  {
   switch(timeframe)
     {
      case PERIOD_M5:
         return("M5");
      case PERIOD_M15:
         return("M15");
      case PERIOD_M30:
         return("M30");
      case PERIOD_H1:
         return("H1");
      case PERIOD_H4:
         return("H4");
      default:
         return("Custom");
     }
  }

StrategyConfig BuildStrategyConfig(const ENUM_ATX_STRATEGY_PROFILE profile)
  {
   StrategyConfig cfg;
   cfg.name = "Imperial Trend";
   cfg.recommended_balance = "USD 2000+";
   cfg.notes = "Trend pullback com H4/H1 para swing disciplinado.";
   cfg.signal_timeframe = PERIOD_H1;
   cfg.trend_timeframe = PERIOD_H4;
   cfg.fast_ema = 21;
   cfg.slow_ema = 55;
   cfg.rsi_buy_min = 52.0;
   cfg.rsi_buy_max = 70.0;
   cfg.rsi_sell_min = 30.0;
   cfg.rsi_sell_max = 48.0;
   cfg.stop_atr_multiplier = 2.20;
   cfg.risk_reward = 2.20;
   cfg.require_pullback = true;
   cfg.require_asian_breakout = false;
   cfg.require_momentum_breakout = false;
   cfg.require_mean_reversion = false;
   cfg.require_volatility_expansion = false;
   cfg.session_start_hour_utc = FILTER_LondonStartHourUTC;
   cfg.session_end_hour_utc = FILTER_NewYorkStartHourUTC;

   switch(profile)
     {
      case ATX_STRATEGY_LONDON_BREAKOUT:
         cfg.name = "London Breakout";
         cfg.recommended_balance = "USD 1500+";
         cfg.notes = "Range asiatico + breakout em Londres para ouro intraday.";
         cfg.signal_timeframe = PERIOD_M15;
         cfg.trend_timeframe = PERIOD_H1;
         cfg.fast_ema = 20;
         cfg.slow_ema = 50;
         cfg.rsi_buy_min = 55.0;
         cfg.rsi_buy_max = 74.0;
         cfg.rsi_sell_min = 26.0;
         cfg.rsi_sell_max = 45.0;
         cfg.stop_atr_multiplier = 1.80;
         cfg.risk_reward = 1.90;
         cfg.require_pullback = false;
         cfg.require_asian_breakout = true;
         cfg.require_momentum_breakout = false;
         cfg.require_mean_reversion = false;
         cfg.require_volatility_expansion = false;
         cfg.session_start_hour_utc = FILTER_LondonStartHourUTC;
         cfg.session_end_hour_utc = FILTER_LondonEndHourUTC;
         break;

      case ATX_STRATEGY_NEWYORK_MOMENTUM:
         cfg.name = "New York Momentum";
         cfg.recommended_balance = "USD 2500+";
         cfg.notes = "Continuidade intraday com velas impulsivas e confirmacao de tendencia.";
         cfg.signal_timeframe = PERIOD_M30;
         cfg.trend_timeframe = PERIOD_H1;
         cfg.fast_ema = 18;
         cfg.slow_ema = 50;
         cfg.rsi_buy_min = 56.0;
         cfg.rsi_buy_max = 76.0;
         cfg.rsi_sell_min = 24.0;
         cfg.rsi_sell_max = 44.0;
         cfg.stop_atr_multiplier = 1.90;
         cfg.risk_reward = 2.10;
         cfg.require_pullback = false;
         cfg.require_asian_breakout = false;
         cfg.require_momentum_breakout = true;
         cfg.require_mean_reversion = false;
         cfg.require_volatility_expansion = false;
         cfg.session_start_hour_utc = FILTER_NewYorkStartHourUTC;
         cfg.session_end_hour_utc = FILTER_NewYorkEndHourUTC;
         break;

      case ATX_STRATEGY_ASIA_REVERSION:
         cfg.name = "Asia Mean Reversion";
         cfg.recommended_balance = "USD 1000+";
         cfg.notes = "Reversoes de exaustao em consolidacao com Bollinger + RSI.";
         cfg.signal_timeframe = PERIOD_M15;
         cfg.trend_timeframe = PERIOD_H1;
         cfg.fast_ema = 20;
         cfg.slow_ema = 50;
         cfg.rsi_buy_min = 24.0;
         cfg.rsi_buy_max = 45.0;
         cfg.rsi_sell_min = 55.0;
         cfg.rsi_sell_max = 78.0;
         cfg.stop_atr_multiplier = 1.60;
         cfg.risk_reward = 1.60;
         cfg.require_pullback = false;
         cfg.require_asian_breakout = false;
         cfg.require_momentum_breakout = false;
         cfg.require_mean_reversion = true;
         cfg.require_volatility_expansion = false;
         cfg.session_start_hour_utc = FILTER_AsiaSessionStartHourUTC;
         cfg.session_end_hour_utc = FILTER_AsiaSessionEndHourUTC;
         break;

      case ATX_STRATEGY_VOLATILITY_SWING:
         cfg.name = "Volatility Swing";
         cfg.recommended_balance = "USD 3000+";
         cfg.notes = "Expansao de ATR com breakout de swing para trades mais espacados.";
         cfg.signal_timeframe = PERIOD_H1;
         cfg.trend_timeframe = PERIOD_H4;
         cfg.fast_ema = 34;
         cfg.slow_ema = 89;
         cfg.rsi_buy_min = 58.0;
         cfg.rsi_buy_max = 78.0;
         cfg.rsi_sell_min = 22.0;
         cfg.rsi_sell_max = 42.0;
         cfg.stop_atr_multiplier = 2.60;
         cfg.risk_reward = 2.60;
         cfg.require_pullback = false;
         cfg.require_asian_breakout = false;
         cfg.require_momentum_breakout = true;
         cfg.require_mean_reversion = false;
         cfg.require_volatility_expansion = true;
         cfg.session_start_hour_utc = FILTER_LondonStartHourUTC;
         cfg.session_end_hour_utc = FILTER_NewYorkStartHourUTC;
         break;

      default:
         break;
     }

   return(cfg);
  }

RiskProfileConfig BuildRiskProfile(const ENUM_ATX_RISK_PROFILE profile)
  {
   RiskProfileConfig cfg;
   cfg.name = "Balanced";
   cfg.volume_multiplier = 1.00;
   cfg.risk_multiplier = 1.00;
   cfg.spread_multiplier = 1.00;
   cfg.stop_multiplier = 1.00;
   cfg.rr_multiplier = 1.00;
   cfg.max_trades_per_day = 2;
   cfg.use_break_even = true;
   cfg.use_trailing = true;
   cfg.break_even_rr = 0.90;
   cfg.trailing_atr_multiplier = 1.00;

   switch(profile)
     {
      case ATX_RISK_LEVEL_1_DEFENSIVE:
         cfg.name = "Defensive";
         cfg.volume_multiplier = 0.60;
         cfg.risk_multiplier = 0.55;
         cfg.spread_multiplier = 0.80;
         cfg.stop_multiplier = 1.20;
         cfg.rr_multiplier = 0.95;
         cfg.max_trades_per_day = 1;
         cfg.use_break_even = true;
         cfg.use_trailing = true;
         cfg.break_even_rr = 0.70;
         cfg.trailing_atr_multiplier = 1.25;
         break;

      case ATX_RISK_LEVEL_2_CONSERVATIVE:
         cfg.name = "Conservative";
         cfg.volume_multiplier = 0.80;
         cfg.risk_multiplier = 0.80;
         cfg.spread_multiplier = 0.90;
         cfg.stop_multiplier = 1.10;
         cfg.rr_multiplier = 1.00;
         cfg.max_trades_per_day = 1;
         cfg.use_break_even = true;
         cfg.use_trailing = true;
         cfg.break_even_rr = 0.80;
         cfg.trailing_atr_multiplier = 1.15;
         break;

      case ATX_RISK_LEVEL_3_BALANCED:
         break;

      case ATX_RISK_LEVEL_4_DYNAMIC:
         cfg.name = "Dynamic";
         cfg.volume_multiplier = 1.20;
         cfg.risk_multiplier = 1.25;
         cfg.spread_multiplier = 1.10;
         cfg.stop_multiplier = 0.95;
         cfg.rr_multiplier = 1.05;
         cfg.max_trades_per_day = 3;
         cfg.use_break_even = true;
         cfg.use_trailing = true;
         cfg.break_even_rr = 1.00;
         cfg.trailing_atr_multiplier = 0.95;
         break;

      case ATX_RISK_LEVEL_5_AGGRESSIVE:
         cfg.name = "Aggressive";
         cfg.volume_multiplier = 1.45;
         cfg.risk_multiplier = 1.55;
         cfg.spread_multiplier = 1.20;
         cfg.stop_multiplier = 0.90;
         cfg.rr_multiplier = 1.10;
         cfg.max_trades_per_day = 4;
         cfg.use_break_even = true;
         cfg.use_trailing = true;
         cfg.break_even_rr = 1.10;
         cfg.trailing_atr_multiplier = 0.85;
         break;

      default:
         break;
     }

   return(cfg);
  }

bool IsGoldSymbol()
  {
   string symbol = _Symbol;
   StringToUpper(symbol);
   return(StringFind(symbol, "XAUUSD") >= 0 || StringFind(symbol, "GOLD") >= 0 || StringFind(symbol, "XAU") >= 0);
  }

bool ValidateHandles()
  {
   return(g_handleSignalFastEma != INVALID_HANDLE &&
          g_handleSignalSlowEma != INVALID_HANDLE &&
          g_handleTrendFastEma  != INVALID_HANDLE &&
          g_handleTrendSlowEma  != INVALID_HANDLE &&
          g_handleSignalRsi     != INVALID_HANDLE &&
          g_handleSignalAtr     != INVALID_HANDLE &&
          g_handleSignalBands   != INVALID_HANDLE);
  }

bool CopyIndicatorValue(const int handle, const int buffer_index, const int shift, double &value)
  {
   double values[1];
   if(CopyBuffer(handle, buffer_index, shift, 1, values) < 1)
     {
      WriteLog(StringFormat("CopyBuffer falhou. Handle=%d Buffer=%d Shift=%d", handle, buffer_index, shift), true);
      return(false);
     }

   value = values[0];
   return(true);
  }

datetime ConvertServerToUtc(const datetime server_time)
  {
   return(server_time - (datetime)(FILTER_ServerUtcOffsetHours * 3600));
  }

bool IsWithinUtcWindow(const int start_hour, const int end_hour)
  {
   MqlDateTime dt;
   TimeToStruct(ConvertServerToUtc(TimeCurrent()), dt);

   if(start_hour == end_hour)
      return(true);

   if(start_hour < end_hour)
      return(dt.hour >= start_hour && dt.hour < end_hour);

   return(dt.hour >= start_hour || dt.hour < end_hour);
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

bool GetAtrValue(const int shift, double &atr_value)
  {
   return(CopyIndicatorValue(g_handleSignalAtr, 0, shift, atr_value));
  }

bool GetSignalEmaFast(const int shift, double &value)
  {
   return(CopyIndicatorValue(g_handleSignalFastEma, 0, shift, value));
  }

bool GetSignalEmaSlow(const int shift, double &value)
  {
   return(CopyIndicatorValue(g_handleSignalSlowEma, 0, shift, value));
  }

bool GetTrendEmaFast(const int shift, double &value)
  {
   return(CopyIndicatorValue(g_handleTrendFastEma, 0, shift, value));
  }

bool GetTrendEmaSlow(const int shift, double &value)
  {
   return(CopyIndicatorValue(g_handleTrendSlowEma, 0, shift, value));
  }

bool GetRsiValue(const int shift, double &value)
  {
   return(CopyIndicatorValue(g_handleSignalRsi, 0, shift, value));
  }

bool GetBandsUpper(const int shift, double &value)
  {
   return(CopyIndicatorValue(g_handleSignalBands, 1, shift, value));
  }

bool GetBandsLower(const int shift, double &value)
  {
   return(CopyIndicatorValue(g_handleSignalBands, 2, shift, value));
  }

bool HasOpenPosition()
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)GEN_MagicNumber)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      return(true);
     }

   return(false);
  }

int CountTodayTrades()
  {
   MqlDateTime dt_now;
   TimeToStruct(ConvertServerToUtc(TimeCurrent()), dt_now);

   MqlDateTime dt_start = dt_now;
   dt_start.hour = 0;
   dt_start.min = 0;
   dt_start.sec = 0;

   datetime utc_start = StructToTime(dt_start);
   datetime server_start = utc_start + (datetime)(FILTER_ServerUtcOffsetHours * 3600);

   if(!HistorySelect(server_start, TimeCurrent() + 1))
      return(0);

   int count = 0;
   int deals = HistoryDealsTotal();
   for(int i = 0; i < deals; i++)
     {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0)
         continue;
      if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != (long)GEN_MagicNumber)
         continue;
      if(HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol)
         continue;
      if(HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_IN)
         count++;
     }

   return(count);
  }

bool CheckDailyDrawdown()
  {
   if(RISK_MaxDailyDrawdownPercent <= 0.0)
      return(true);

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(balance <= 0.0)
      return(true);

   double drawdown = ((balance - equity) / balance) * 100.0;
   if(drawdown >= RISK_MaxDailyDrawdownPercent)
     {
      WriteLog(StringFormat("Drawdown diario %.2f%% atingido. Novas entradas bloqueadas.", drawdown), false);
      return(false);
     }

   return(true);
  }

bool PassCommonFilters()
  {
   double spread = GetSpreadPoints();
   double max_spread = FILTER_MaxSpreadPoints * g_risk.spread_multiplier;
   if(spread > max_spread)
     {
      if(UI_LogSignalRejections)
         WriteLog(StringFormat("Spread %.1f acima do limite %.1f", spread, max_spread), false);
      return(false);
     }

   double atr = 0.0;
   if(!GetAtrValue(1, atr))
      return(false);

   double atr_points = atr / _Point;
   if(atr_points < FILTER_MinATRPoints || atr_points > FILTER_MaxATRPoints)
     {
      if(UI_LogSignalRejections)
         WriteLog(StringFormat("ATR %.1f fora do intervalo [%.1f, %.1f]", atr_points, FILTER_MinATRPoints, FILTER_MaxATRPoints), false);
      return(false);
     }

   if(!CheckDailyDrawdown())
      return(false);

   if(CountTodayTrades() >= g_risk.max_trades_per_day)
     {
      if(UI_LogSignalRejections)
         WriteLog(StringFormat("Limite diario de %d trades atingido.", g_risk.max_trades_per_day), false);
      return(false);
     }

   if(!IsWithinUtcWindow(g_strategy.session_start_hour_utc, g_strategy.session_end_hour_utc))
     {
      if(UI_LogSignalRejections)
         WriteLog("Fora da janela horaria da estrategia.", false);
      return(false);
     }

   return(true);
  }

bool GetHighestHigh(const ENUM_TIMEFRAMES timeframe, const int start_shift, const int bars, double &value)
  {
   if(bars <= 0)
      return(false);

   value = -DBL_MAX;
   for(int i = 0; i < bars; i++)
     {
      double price = iHigh(_Symbol, timeframe, start_shift + i);
      if(price <= 0.0)
         return(false);
      if(price > value)
         value = price;
     }

   return(value > -DBL_MAX / 2.0);
  }

bool GetLowestLow(const ENUM_TIMEFRAMES timeframe, const int start_shift, const int bars, double &value)
  {
   if(bars <= 0)
      return(false);

   value = DBL_MAX;
   for(int i = 0; i < bars; i++)
     {
      double price = iLow(_Symbol, timeframe, start_shift + i);
      if(price <= 0.0)
         return(false);
      if(price < value)
         value = price;
     }

   return(value < DBL_MAX / 2.0);
  }

bool GetAsianRange(double &range_high, double &range_low)
  {
   range_high = -DBL_MAX;
   range_low = DBL_MAX;

   datetime current_server_time = TimeCurrent();
   datetime current_utc_time = ConvertServerToUtc(current_server_time);

   MqlDateTime current_dt;
   TimeToStruct(current_utc_time, current_dt);

   for(int shift = 1; shift <= 96; shift++)
     {
      datetime bar_server_time = iTime(_Symbol, PERIOD_M15, shift);
      if(bar_server_time == 0)
         continue;

      datetime bar_utc_time = ConvertServerToUtc(bar_server_time);
      MqlDateTime bar_dt;
      TimeToStruct(bar_utc_time, bar_dt);

      if(bar_dt.year != current_dt.year || bar_dt.mon != current_dt.mon || bar_dt.day != current_dt.day)
         continue;
      if(bar_dt.hour < FILTER_AsiaSessionStartHourUTC || bar_dt.hour >= FILTER_AsiaSessionEndHourUTC)
         continue;

      double bar_high = iHigh(_Symbol, PERIOD_M15, shift);
      double bar_low = iLow(_Symbol, PERIOD_M15, shift);
      if(bar_high <= 0.0 || bar_low <= 0.0)
         continue;

      if(bar_high > range_high)
         range_high = bar_high;
      if(bar_low < range_low)
         range_low = bar_low;
     }

   if(range_high <= -DBL_MAX / 2.0 || range_low >= DBL_MAX / 2.0)
      return(false);

   double range_points = (range_high - range_low) / _Point;
   return(range_points >= ENTRY_MinAsianRangePoints && range_points <= ENTRY_MaxAsianRangePoints);
  }

bool CheckBuySignal()
  {
   double ema_fast = 0.0;
   double ema_slow = 0.0;
   double trend_fast = 0.0;
   double trend_slow = 0.0;
   double rsi = 0.0;
   double atr = 0.0;
   double upper_band = 0.0;
   double lower_band = 0.0;

   if(!GetSignalEmaFast(1, ema_fast) || !GetSignalEmaSlow(1, ema_slow) ||
      !GetTrendEmaFast(1, trend_fast) || !GetTrendEmaSlow(1, trend_slow) ||
      !GetRsiValue(1, rsi) || !GetAtrValue(1, atr) ||
      !GetBandsUpper(1, upper_band) || !GetBandsLower(1, lower_band))
      return(false);

   double open1 = iOpen(_Symbol, g_strategy.signal_timeframe, 1);
   double close1 = iClose(_Symbol, g_strategy.signal_timeframe, 1);
   double high1 = iHigh(_Symbol, g_strategy.signal_timeframe, 1);
   double low1 = iLow(_Symbol, g_strategy.signal_timeframe, 1);
   if(open1 <= 0.0 || close1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0)
      return(false);

   bool trend_ok = trend_fast > trend_slow;
   bool signal_ok = ema_fast > ema_slow;
   bool price_ok = close1 > ema_fast && close1 > ema_slow;
   bool rsi_ok = rsi >= g_strategy.rsi_buy_min && rsi <= g_strategy.rsi_buy_max;
   bool body_ok = (close1 - open1) >= (atr * ENTRY_MinBodyToAtrRatio);

   if(!trend_ok || !signal_ok || !rsi_ok)
      return(false);

   if(g_strategy.require_pullback)
     {
      bool pullback_ok = low1 <= ema_fast + (atr * ENTRY_PullbackToleranceATR) && close1 > open1 && price_ok;
      return(pullback_ok);
     }

   if(g_strategy.require_asian_breakout)
     {
      double range_high = 0.0;
      double range_low = 0.0;
      if(!GetAsianRange(range_high, range_low))
         return(false);

      double breakout_level = range_high + (ENTRY_BreakoutBufferPoints * _Point);
      return(price_ok && close1 > breakout_level && close1 > upper_band && rsi_ok);
     }

   if(g_strategy.require_mean_reversion)
     {
      bool trend_flat = MathAbs(trend_fast - trend_slow) <= (atr * 0.35);
      bool rejection = close1 > open1 && (open1 - low1) > MathAbs(close1 - open1);
      return(trend_flat && close1 <= lower_band && rejection && rsi_ok);
     }

   if(g_strategy.require_momentum_breakout)
     {
      double recent_high = 0.0;
      if(!GetHighestHigh(g_strategy.signal_timeframe, 2, ENTRY_SwingLookbackBars, recent_high))
         return(false);

      bool breakout_ok = close1 > recent_high + (ENTRY_BreakoutBufferPoints * 0.20 * _Point);
      bool volatility_ok = true;
      if(g_strategy.require_volatility_expansion)
        {
         double atr2 = 0.0;
         if(!GetAtrValue(2, atr2))
            return(false);
         volatility_ok = atr > (atr2 * 1.05);
        }

      return(price_ok && body_ok && breakout_ok && volatility_ok);
     }

   return(price_ok && rsi_ok);
  }

bool CheckSellSignal()
  {
   double ema_fast = 0.0;
   double ema_slow = 0.0;
   double trend_fast = 0.0;
   double trend_slow = 0.0;
   double rsi = 0.0;
   double atr = 0.0;
   double upper_band = 0.0;
   double lower_band = 0.0;

   if(!GetSignalEmaFast(1, ema_fast) || !GetSignalEmaSlow(1, ema_slow) ||
      !GetTrendEmaFast(1, trend_fast) || !GetTrendEmaSlow(1, trend_slow) ||
      !GetRsiValue(1, rsi) || !GetAtrValue(1, atr) ||
      !GetBandsUpper(1, upper_band) || !GetBandsLower(1, lower_band))
      return(false);

   double open1 = iOpen(_Symbol, g_strategy.signal_timeframe, 1);
   double close1 = iClose(_Symbol, g_strategy.signal_timeframe, 1);
   double high1 = iHigh(_Symbol, g_strategy.signal_timeframe, 1);
   double low1 = iLow(_Symbol, g_strategy.signal_timeframe, 1);
   if(open1 <= 0.0 || close1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0)
      return(false);

   bool trend_ok = trend_fast < trend_slow;
   bool signal_ok = ema_fast < ema_slow;
   bool price_ok = close1 < ema_fast && close1 < ema_slow;
   bool rsi_ok = rsi >= g_strategy.rsi_sell_min && rsi <= g_strategy.rsi_sell_max;
   bool body_ok = (open1 - close1) >= (atr * ENTRY_MinBodyToAtrRatio);

   if(!trend_ok || !signal_ok || !rsi_ok)
      return(false);

   if(g_strategy.require_pullback)
     {
      bool pullback_ok = high1 >= ema_fast - (atr * ENTRY_PullbackToleranceATR) && close1 < open1 && price_ok;
      return(pullback_ok);
     }

   if(g_strategy.require_asian_breakout)
     {
      double range_high = 0.0;
      double range_low = 0.0;
      if(!GetAsianRange(range_high, range_low))
         return(false);

      double breakout_level = range_low - (ENTRY_BreakoutBufferPoints * _Point);
      return(price_ok && close1 < breakout_level && close1 < lower_band && rsi_ok);
     }

   if(g_strategy.require_mean_reversion)
     {
      bool trend_flat = MathAbs(trend_fast - trend_slow) <= (atr * 0.35);
      bool rejection = close1 < open1 && (high1 - open1) > MathAbs(close1 - open1);
      return(trend_flat && close1 >= upper_band && rejection && rsi_ok);
     }

   if(g_strategy.require_momentum_breakout)
     {
      double recent_low = 0.0;
      if(!GetLowestLow(g_strategy.signal_timeframe, 2, ENTRY_SwingLookbackBars, recent_low))
         return(false);

      bool breakout_ok = close1 < recent_low - (ENTRY_BreakoutBufferPoints * 0.20 * _Point);
      bool volatility_ok = true;
      if(g_strategy.require_volatility_expansion)
        {
         double atr2 = 0.0;
         if(!GetAtrValue(2, atr2))
            return(false);
         volatility_ok = atr > (atr2 * 1.05);
        }

      return(price_ok && body_ok && breakout_ok && volatility_ok);
     }

   return(price_ok && rsi_ok);
  }

double NormalizeLot(const double lot, const double min_volume, const double max_volume, const double step_volume)
  {
   if(step_volume <= 0.0)
      return(0.0);

   double normalized = MathFloor((lot / step_volume) + ATX_LOT_EPSILON) * step_volume;
   normalized = MathMax(normalized, min_volume);
   normalized = MathMin(normalized, max_volume);

   int digits = 2;
   if(step_volume < 1.0)
      digits = (int)MathRound(-MathLog10(step_volume));
   digits = (int)MathMax(0, MathMin(8, digits));

   return(NormalizeDouble(normalized, digits));
  }

double CalculateLotSize(const double stop_points)
  {
   double min_volume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max_volume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step_volume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   if(min_volume <= 0.0 || max_volume <= 0.0 || step_volume <= 0.0 || stop_points <= 0.0)
      return(0.0);

   if(RISK_Model == ATX_RISK_FIXED_LOT)
      return(NormalizeLot(RISK_FixedLot * g_risk.volume_multiplier, min_volume, max_volume, step_volume));

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(equity <= 0.0 || tick_value <= 0.0 || tick_size <= 0.0)
      return(0.0);

   double effective_risk_percent = RISK_BasePercentPerTrade * g_risk.risk_multiplier;
   double risk_amount = equity * (effective_risk_percent / 100.0);
   double stop_distance = stop_points * _Point;
   double loss_per_lot = (stop_distance / tick_size) * tick_value;
   if(loss_per_lot <= 0.0)
      return(0.0);

   return(NormalizeLot(risk_amount / loss_per_lot, min_volume, max_volume, step_volume));
  }

int GetMinimumStopLevelPoints()
  {
   int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   int freeze_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   return(MathMax(stops_level, freeze_level) + 5);
  }

void EnforceMinimumStopDistance(const bool is_buy, const double entry_price, double &stop_loss, double &take_profit)
  {
   double minimum_distance = GetMinimumStopLevelPoints() * _Point;
   if(minimum_distance <= 0.0)
      return;

   if(is_buy)
     {
      if((entry_price - stop_loss) < minimum_distance)
         stop_loss = entry_price - minimum_distance;
      if((take_profit - entry_price) < minimum_distance)
         take_profit = entry_price + minimum_distance;
     }
   else
     {
      if((stop_loss - entry_price) < minimum_distance)
         stop_loss = entry_price + minimum_distance;
      if((entry_price - take_profit) < minimum_distance)
         take_profit = entry_price - minimum_distance;
     }
  }

int ExtractRiskPointsFromComment(const string comment)
  {
   string parts[];
   if(StringSplit(comment, '|', parts) < 4)
      return(0);

   return((int)StringToInteger(parts[3]));
  }

string BuildTradeComment(const double risk_points)
  {
   return(StringFormat("ATX|%d|%d|%d", (int)GEN_StrategyProfile, (int)RISK_Profile, (int)MathRound(risk_points)));
  }

bool OpenBuy()
  {
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double atr = 0.0;
   double swing_low = 0.0;
   if(ask <= 0.0 || !GetAtrValue(1, atr) || !GetLowestLow(g_strategy.signal_timeframe, 1, ENTRY_SwingLookbackBars, swing_low))
      return(false);

   double stop_distance_atr = atr * g_strategy.stop_atr_multiplier * g_risk.stop_multiplier;
   double stop_loss = MathMin(ask - stop_distance_atr, swing_low - (atr * ATX_STOP_BUFFER_ATR));
   double risk_points = (ask - stop_loss) / _Point;
   if(risk_points <= 0.0)
      return(false);

   double rr = MathMax(1.20, g_strategy.risk_reward * g_risk.rr_multiplier);
   double take_profit = ask + (risk_points * _Point * rr);

   EnforceMinimumStopDistance(true, ask, stop_loss, take_profit);

   risk_points = (ask - stop_loss) / _Point;
   double lot = CalculateLotSize(risk_points);
   if(lot <= 0.0)
     {
      WriteLog("OpenBuy cancelado: lote calculado invalido.", true);
      return(false);
     }

   stop_loss = NormalizeDouble(stop_loss, _Digits);
   take_profit = NormalizeDouble(take_profit, _Digits);

   if(!g_trade.Buy(lot, _Symbol, ask, stop_loss, take_profit, BuildTradeComment(risk_points)))
     {
      WriteLog(StringFormat("Falha ao abrir BUY: %d %s", g_trade.ResultRetcode(), g_trade.ResultRetcodeDescription()), true);
      return(false);
     }

   WriteLog(StringFormat("BUY aberto | Estratégia=%s | Risco=%s | Lot=%.2f | SL=%.2f pts | TP RR=%.2f",
                         g_strategy.name, g_risk.name, lot, risk_points, rr), false);
   return(true);
  }

bool OpenSell()
  {
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double atr = 0.0;
   double swing_high = 0.0;
   if(bid <= 0.0 || !GetAtrValue(1, atr) || !GetHighestHigh(g_strategy.signal_timeframe, 1, ENTRY_SwingLookbackBars, swing_high))
      return(false);

   double stop_distance_atr = atr * g_strategy.stop_atr_multiplier * g_risk.stop_multiplier;
   double stop_loss = MathMax(bid + stop_distance_atr, swing_high + (atr * ATX_STOP_BUFFER_ATR));
   double risk_points = (stop_loss - bid) / _Point;
   if(risk_points <= 0.0)
      return(false);

   double rr = MathMax(1.20, g_strategy.risk_reward * g_risk.rr_multiplier);
   double take_profit = bid - (risk_points * _Point * rr);

   EnforceMinimumStopDistance(false, bid, stop_loss, take_profit);

   risk_points = (stop_loss - bid) / _Point;
   double lot = CalculateLotSize(risk_points);
   if(lot <= 0.0)
     {
      WriteLog("OpenSell cancelado: lote calculado invalido.", true);
      return(false);
     }

   stop_loss = NormalizeDouble(stop_loss, _Digits);
   take_profit = NormalizeDouble(take_profit, _Digits);

   if(!g_trade.Sell(lot, _Symbol, bid, stop_loss, take_profit, BuildTradeComment(risk_points)))
     {
      WriteLog(StringFormat("Falha ao abrir SELL: %d %s", g_trade.ResultRetcode(), g_trade.ResultRetcodeDescription()), true);
      return(false);
     }

   WriteLog(StringFormat("SELL aberto | Estratégia=%s | Risco=%s | Lot=%.2f | SL=%.2f pts | TP RR=%.2f",
                         g_strategy.name, g_risk.name, lot, risk_points, rr), false);
   return(true);
  }

void ApplyBreakEven(const ulong ticket, const ENUM_POSITION_TYPE position_type,
                    const double open_price, const double current_sl, const double current_tp,
                    const int initial_risk_points)
  {
   if(!EXIT_UseBreakEven || !g_risk.use_break_even || initial_risk_points <= 0)
      return;

   double trigger_distance = initial_risk_points * _Point * g_risk.break_even_rr;
   double buffer_distance = EXIT_BreakEvenBufferPoints * _Point;
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   if(position_type == POSITION_TYPE_BUY)
     {
      if((bid - open_price) >= trigger_distance)
        {
         double new_sl = NormalizeDouble(open_price + buffer_distance, _Digits);
         if(new_sl > current_sl)
           {
            if(!g_trade.PositionModify(ticket, new_sl, current_tp))
               WriteLog(StringFormat("BreakEven BUY falhou ticket=%I64u: %d %s", ticket, g_trade.ResultRetcode(), g_trade.ResultRetcodeDescription()), true);
           }
        }
     }
   else if(position_type == POSITION_TYPE_SELL)
     {
      if((open_price - ask) >= trigger_distance)
        {
         double new_sl = NormalizeDouble(open_price - buffer_distance, _Digits);
         if(new_sl < current_sl || current_sl <= 0.0)
           {
            if(!g_trade.PositionModify(ticket, new_sl, current_tp))
               WriteLog(StringFormat("BreakEven SELL falhou ticket=%I64u: %d %s", ticket, g_trade.ResultRetcode(), g_trade.ResultRetcodeDescription()), true);
           }
        }
     }
  }

void ApplyTrailingStop(const ulong ticket, const ENUM_POSITION_TYPE position_type, const double current_sl, const double current_tp)
  {
   if(!EXIT_UseTrailingStop || !g_risk.use_trailing)
      return;

   double atr = 0.0;
   if(!GetAtrValue(0, atr) || atr <= 0.0)
      return;

   double trail_distance = atr * EXIT_TrailingAtrMultiplier * g_risk.trailing_atr_multiplier;
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   if(position_type == POSITION_TYPE_BUY)
     {
      double new_sl = NormalizeDouble(bid - trail_distance, _Digits);
      if(new_sl > current_sl && new_sl < bid)
        {
         if(!g_trade.PositionModify(ticket, new_sl, current_tp))
            WriteLog(StringFormat("Trailing BUY falhou ticket=%I64u: %d %s", ticket, g_trade.ResultRetcode(), g_trade.ResultRetcodeDescription()), true);
        }
     }
   else if(position_type == POSITION_TYPE_SELL)
     {
      double new_sl = NormalizeDouble(ask + trail_distance, _Digits);
      if((new_sl < current_sl || current_sl <= 0.0) && new_sl > ask)
        {
         if(!g_trade.PositionModify(ticket, new_sl, current_tp))
            WriteLog(StringFormat("Trailing SELL falhou ticket=%I64u: %d %s", ticket, g_trade.ResultRetcode(), g_trade.ResultRetcodeDescription()), true);
        }
     }
  }

void ManageOpenPositions()
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)GEN_MagicNumber)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      double current_sl = PositionGetDouble(POSITION_SL);
      double current_tp = PositionGetDouble(POSITION_TP);
      string comment = PositionGetString(POSITION_COMMENT);
      int initial_risk_points = ExtractRiskPointsFromComment(comment);
      if(initial_risk_points <= 0 && current_sl > 0.0)
         initial_risk_points = (int)MathRound(MathAbs(open_price - current_sl) / _Point);

      ApplyBreakEven(ticket, position_type, open_price, current_sl, current_tp, initial_risk_points);
      ApplyTrailingStop(ticket, position_type, PositionGetDouble(POSITION_SL), PositionGetDouble(POSITION_TP));
     }
  }

int OnInit()
  {
   g_strategy = BuildStrategyConfig(GEN_StrategyProfile);
   g_risk = BuildRiskProfile(RISK_Profile);

   if(GEN_RequireGoldSymbol && !IsGoldSymbol())
     {
      WriteLog("AurumTitanX foi desenhado para XAUUSD/XAU com sufixo do broker.", true);
      return(INIT_PARAMETERS_INCORRECT);
     }

   g_trade.SetExpertMagicNumber((long)GEN_MagicNumber);
   g_trade.SetDeviationInPoints(GEN_SlippagePoints);
   g_trade.SetTypeFillingBySymbol(_Symbol);

   g_handleSignalFastEma = iMA(_Symbol, g_strategy.signal_timeframe, g_strategy.fast_ema, 0, MODE_EMA, PRICE_CLOSE);
   g_handleSignalSlowEma = iMA(_Symbol, g_strategy.signal_timeframe, g_strategy.slow_ema, 0, MODE_EMA, PRICE_CLOSE);
   g_handleTrendFastEma = iMA(_Symbol, g_strategy.trend_timeframe, g_strategy.fast_ema, 0, MODE_EMA, PRICE_CLOSE);
   g_handleTrendSlowEma = iMA(_Symbol, g_strategy.trend_timeframe, g_strategy.slow_ema, 0, MODE_EMA, PRICE_CLOSE);
   g_handleSignalRsi = iRSI(_Symbol, g_strategy.signal_timeframe, ENTRY_RSI_Period, PRICE_CLOSE);
   g_handleSignalAtr = iATR(_Symbol, g_strategy.signal_timeframe, ENTRY_ATR_Period);
   g_handleSignalBands = iBands(_Symbol, g_strategy.signal_timeframe, ENTRY_BBands_Period, 0, ENTRY_BBands_Deviation, PRICE_CLOSE);

   if(!ValidateHandles())
     {
      WriteLog("Falha ao criar indicator handles.", true);
      return(INIT_FAILED);
     }

   if(_Period != g_strategy.signal_timeframe)
      WriteLog(StringFormat("Timeframe recomendado para %s: %s.", g_strategy.name, TimeframeToText(g_strategy.signal_timeframe)), false);

   WriteLog(StringFormat("Inicializado | Estratégia=%s | Risco=%s | Saldo sugerido=%s | Timeframe sugerido=%s",
                         g_strategy.name, g_risk.name, g_strategy.recommended_balance, TimeframeToText(g_strategy.signal_timeframe)), false);
   WriteLog(g_strategy.notes, false);
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   ReleaseHandle(g_handleSignalFastEma);
   ReleaseHandle(g_handleSignalSlowEma);
   ReleaseHandle(g_handleTrendFastEma);
   ReleaseHandle(g_handleTrendSlowEma);
   ReleaseHandle(g_handleSignalRsi);
   ReleaseHandle(g_handleSignalAtr);
   ReleaseHandle(g_handleSignalBands);
   WriteLog(StringFormat("EA finalizado. Reason=%d", reason), false);
  }

void OnTick()
  {
   ManageOpenPositions();

   bool is_new_bar = CheckNewBar(g_strategy.signal_timeframe, g_lastProcessedBar);
   if(GEN_OnlyOnNewBar && !is_new_bar)
      return;

   datetime signal_bar = iTime(_Symbol, g_strategy.signal_timeframe, 0);
   if(signal_bar == 0 || signal_bar == g_lastEntryBar)
      return;

   if(HasOpenPosition())
      return;

   if(!PassCommonFilters())
      return;

   bool opened = false;
   if(GEN_AllowLongs && CheckBuySignal())
      opened = OpenBuy();

   if(!opened && GEN_AllowShorts && CheckSellSignal())
      opened = OpenSell();

   if(opened)
      g_lastEntryBar = signal_bar;
  }
