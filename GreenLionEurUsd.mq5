#property copyright "TITAN LION FX"
#property version   "1.11"
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

const double VOLUME_ROUNDING_EPSILON = 1e-8;
const double STOP_BUFFER_POINTS = 5.0;
const double ENTRY_EXHAUSTION_ATR_RATIO = 0.10;
const double ENTRY_REJECTION_WICK_BODY_RATIO = 1.20;

input group "GEN - General"
input ulong           GEN_MagicNumber                  = 26050701;
input int             GEN_SlippagePoints              = 20;
input bool            GEN_AllowLongs                  = true;
input bool            GEN_AllowShorts                 = true;
input bool            GEN_OnlyOnNewBar                = false;
input bool            GEN_EnableBasketTrading         = true;
input int             GEN_MaxPositionsPerDirection    = 3;
input int             GEN_MaxTotalPositions           = 4;
input bool            GEN_AllowOppositeDirections     = true;

input group "RISK - Risk Management"
input ENUM_RISK_MODEL RISK_Model                      = RISK_PERCENT_EQUITY;
input double          RISK_FixedLot                   = 0.10;
input double          RISK_PercentPerTrade            = 1.00;
input double          RISK_ReducedPercentPerTrade     = 0.50;
input int             RISK_MaxTradesPerDay            = 6;
input double          RISK_MaxDailyDrawdownPercent    = 4.0;
input double          RISK_MaxWeeklyDrawdownPercent   = 10.0;
input bool            RISK_AllowPartialClose          = true;
input double          RISK_PartialClosePercent        = 50.0;
input bool            RISK_UseBasketLotProgression    = true;
input double          RISK_BasketInitialLot           = 0.01;
input double          RISK_BasketLotMultiplier        = 1.30;
input int             RISK_BasketMaxEntries           = 3;
input double          RISK_BasketMaxRiskPercent       = 50.0;

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
input double          ENTRY_MinTrendSeparationPoints  = 100.0;
input double          ENTRY_PullbackToleranceATR      = 0.65;
input double          ENTRY_StopATRMultiplier         = 2.40;
input double          ENTRY_BreakoutBufferPoints      = 8.0;
input double          ENTRY_MaxAsianRangePoints       = 900.0;
input double          ENTRY_MinAsianRangePoints       = 80.0;
input double          ENTRY_MaxSqueezeWidthPoints     = 320.0;
input int             ENTRY_SwingLookbackBars         = 6;

input group "EXIT - Trade Management"
input double          EXIT_FinalTargetRR              = 2.20;
input double          EXIT_BreakEvenRR                = 1.80;
input double          EXIT_TrailingStartRR            = 2.80;
input double          EXIT_TrailingATRMultiplier      = 1.50;
input double          EXIT_BreakEvenBufferPoints      = 5.0;
input bool            EXIT_UseAggregateLossOnlyClose  = true;
input double          EXIT_BasketLossClosePercent     = 50.0;
input double          EXIT_BasketTargetCurrency       = 0.0;
input double          EXIT_BasketTargetRR             = 0.0;
input bool            EXIT_UseBasketProfitTrailing    = true;
input double          EXIT_BasketTrailStartPercent    = 2.0;
input double          EXIT_BasketTrailGivebackPercent = 0.75;

input group "FILTER - Filters"
input double          FILTER_MaxSpreadPoints          = 18.0;
input double          FILTER_MinATRH1Points           = 60.0;
input double          FILTER_MaxATRH1Points           = 700.0;
input bool            FILTER_UseNewsFilter            = false;
input int             FILTER_NewsBlockMinutesBefore   = 30;
input int             FILTER_NewsBlockMinutesAfter    = 30;
input bool            FILTER_UseServerTime            = false;
input int             FILTER_ServerUtcOffsetHours     = 0;
input int             FILTER_MainWindow1StartHourUTC  = 7;
input int             FILTER_MainWindow1StartMinUTC   = 0;
input int             FILTER_MainWindow1EndHourUTC    = 12;
input int             FILTER_MainWindow1EndMinUTC     = 30;
input int             FILTER_MainWindow2StartHourUTC  = 12;
input int             FILTER_MainWindow2StartMinUTC   = 30;
input int             FILTER_MainWindow2EndHourUTC    = 18;
input int             FILTER_MainWindow2EndMinUTC     = 0;
input int             FILTER_BreakoutStartHourUTC     = 6;
input int             FILTER_BreakoutStartMinUTC      = 30;
input int             FILTER_BreakoutEndHourUTC       = 10;
input int             FILTER_BreakoutEndMinUTC        = 0;
input int             FILTER_AsianSessionStartHourUTC = 0;
input int             FILTER_AsianSessionStartMinUTC  = 0;
input int             FILTER_AsianSessionEndHourUTC   = 7;
input int             FILTER_AsianSessionEndMinUTC    = 0;

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
bool     g_loggedNewsFallback   = false;
int      g_nextBasketId         = 1;

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
   g_handleRsiM15      = iRSI(_Symbol, _Period, ENTRY_RSI_Period, PRICE_CLOSE);
   g_handleAtrH1       = iATR(_Symbol, PERIOD_H1, ENTRY_ATR_Period);
   g_handleAtrM15      = iATR(_Symbol, _Period, ENTRY_ATR_Period);
   g_handleMacdH1      = iMACD(_Symbol, PERIOD_H1, ENTRY_MACD_Fast, ENTRY_MACD_Slow, ENTRY_MACD_Signal, PRICE_CLOSE);
   g_handleMacdM15     = iMACD(_Symbol, _Period, ENTRY_MACD_Fast, ENTRY_MACD_Slow, ENTRY_MACD_Signal, PRICE_CLOSE);
   g_handleBandsM15    = iBands(_Symbol, _Period, ENTRY_BBands_Period, 0, ENTRY_BBands_Deviation, PRICE_CLOSE);

   if(!ValidateHandles())
     {
      WriteLog("Falha ao criar indicator handles.", true);
      return(INIT_FAILED);
     }

   InitializeBasketSequence();

   if(_Symbol != "EURUSD")
      WriteLog("EA desenhado para EURUSD. Verifique o símbolo atual.", false);

   if(GEN_EnableBasketTrading && !IsHedgingAccount())
      WriteLog("Conta sem hedging: baskets com múltiplas posições e hedge bidirecional ficam limitados pela lógica netting do broker.", false);

   if(GEN_AllowOppositeDirections && !CanOpenOppositeDirections())
      WriteLog("GEN_AllowOppositeDirections foi pedido, mas a conta atual não suporta posições opostas independentes.", false);

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
   FinalizeClosedBaskets();

   if(!HasManagedPosition())
      ClearAllPartialState();

   bool is_new_bar = CheckNewBar(_Period, g_lastExecutionBarTime);
   if(GEN_OnlyOnNewBar && !is_new_bar)
      return;

   datetime current_bar = iTime(_Symbol, _Period, 0);
   if(current_bar == 0 || current_bar == g_lastEntryBarTime)
      return;

   if(!PassCommonFilters())
      return;

   bool opened_position = false;
   SignalSetup buy_setup;
   SignalSetup sell_setup;

   if(GEN_AllowLongs && CanOpenManagedPosition(POSITION_TYPE_BUY) && CheckBuySignal(buy_setup))
     {
      if(OpenBuy(buy_setup))
         opened_position = true;
     }

   if(GEN_AllowShorts && CanOpenManagedPosition(POSITION_TYPE_SELL) && CheckSellSignal(sell_setup))
     {
      if(OpenSell(sell_setup))
         opened_position = true;
     }

   if(opened_position)
      g_lastEntryBarTime = current_bar;
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

double CalculateLotSize(const double stop_points, const int basket_id)
  {
   double min_volume  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max_volume  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step_volume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   double fallback_fixed_lot = NormalizeVolume(RISK_FixedLot, min_volume, max_volume, step_volume);
   int basket_entries = (basket_id > 0) ? CountOpenPositionsByBasket(basket_id) : 0;

   double progressive_lot = NormalizeVolume(RISK_BasketInitialLot, min_volume, max_volume, step_volume);
   if(progressive_lot <= 0.0)
      progressive_lot = fallback_fixed_lot;

   if(RISK_UseBasketLotProgression && basket_entries > 0)
     {
      double multiplier = MathMax(RISK_BasketLotMultiplier, 1.0);
      progressive_lot = NormalizeVolume(progressive_lot * MathPow(multiplier, basket_entries), min_volume, max_volume, step_volume);
     }

   if(RISK_Model == RISK_FIXED_LOT)
     {
      if(RISK_UseBasketLotProgression && GEN_EnableBasketTrading)
         return(progressive_lot);
      return(fallback_fixed_lot);
     }

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

   double risk_lot = NormalizeVolume(risk_amount / loss_per_lot, min_volume, max_volume, step_volume);
   if(GEN_EnableBasketTrading && basket_id > 0 && RISK_BasketMaxRiskPercent > 0.0)
     {
      double basket_risk_budget = AccountInfoDouble(ACCOUNT_BALANCE) * (RISK_BasketMaxRiskPercent / 100.0);
      double basket_risk_in_use = GetBasketOpenCommittedRiskCurrency(basket_id);
      double remaining_basket_risk = basket_risk_budget - basket_risk_in_use;
      if(remaining_basket_risk <= 0.0)
         return(0.0);

      double basket_cap_lot = NormalizeVolume(remaining_basket_risk / loss_per_lot, min_volume, max_volume, step_volume);
      risk_lot = NormalizeVolume(MathMin(risk_lot, basket_cap_lot), min_volume, max_volume, step_volume);
     }

   if(!(RISK_UseBasketLotProgression && GEN_EnableBasketTrading))
      return(risk_lot);

   if(progressive_lot <= 0.0)
      return(risk_lot);

   return(NormalizeVolume(MathMin(progressive_lot, risk_lot), min_volume, max_volume, step_volume));
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
    int basket_id = GetOrCreateBasketId(POSITION_TYPE_BUY);
    double lots = CalculateLotSize(setup.risk_points, basket_id);
   if(lots <= 0.0)
     {
      WriteLog("Lote inválido para BUY.", true);
      return(false);
     }

    string comment = BuildPositionComment((int)MathRound(setup.risk_points), setup.tag, basket_id, POSITION_TYPE_BUY);
   double order_sl = setup.stop_loss;
   if(EXIT_UseAggregateLossOnlyClose)
      order_sl = GetAggregateLossSafetyStop(true, setup.stop_loss, lots);
   bool result = trade.Buy(lots, _Symbol, 0.0, order_sl, setup.take_profit, comment);
   if(!result)
     {
      LogTradeFailure("BUY");
      return(false);
     }

    RegisterBasketAsActive(basket_id);
    WriteLog(StringFormat("BUY aberto. Lote=%.2f SL=%.5f TP=%.5f Setup=%s Basket=%d", lots, order_sl, setup.take_profit, setup.tag, basket_id), false);
    LogBasketSnapshot(basket_id, "abertura BUY");
   return(true);
  }

bool OpenSell(const SignalSetup &setup)
  {
    int basket_id = GetOrCreateBasketId(POSITION_TYPE_SELL);
    double lots = CalculateLotSize(setup.risk_points, basket_id);
   if(lots <= 0.0)
     {
      WriteLog("Lote inválido para SELL.", true);
      return(false);
     }

    string comment = BuildPositionComment((int)MathRound(setup.risk_points), setup.tag, basket_id, POSITION_TYPE_SELL);
   double order_sl = setup.stop_loss;
   if(EXIT_UseAggregateLossOnlyClose)
      order_sl = GetAggregateLossSafetyStop(false, setup.stop_loss, lots);
   bool result = trade.Sell(lots, _Symbol, 0.0, order_sl, setup.take_profit, comment);
   if(!result)
     {
      LogTradeFailure("SELL");
      return(false);
     }

    RegisterBasketAsActive(basket_id);
    WriteLog(StringFormat("SELL aberto. Lote=%.2f SL=%.5f TP=%.5f Setup=%s Basket=%d", lots, order_sl, setup.take_profit, setup.tag, basket_id), false);
    LogBasketSnapshot(basket_id, "abertura SELL");
   return(true);
  }

void ManageOpenPositions()
  {
    CheckBasketExitTargets();

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

         bool has_partial_close_run = LoadPartialState(ticket);

      double current_price = (position_type == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(current_price <= 0.0)
         continue;

      double profit_points = (position_type == POSITION_TYPE_BUY) ? (current_price - entry_price) / _Point : (entry_price - current_price) / _Point;
      double profit_rr     = profit_points / (double)risk_points;

      if(RISK_AllowPartialClose && !has_partial_close_run && profit_rr >= 1.0)
         TryPartialClose(ticket, volume);

      if(!EXIT_UseAggregateLossOnlyClose && profit_rr >= EXIT_BreakEvenRR)
         TryMoveToBreakEven(ticket, position_type, entry_price, current_sl, PositionGetDouble(POSITION_TP));

      if(!EXIT_UseAggregateLossOnlyClose && profit_rr >= EXIT_TrailingStartRR)
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
   if(!GetRates(_Period, MathMax(ENTRY_SwingLookbackBars + 2, 8), rates))
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
      Print("[TitanLionFX][ERROR] ", message);
   else
      Print("[TitanLionFX] ", message);
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
   if(!GetRates(PERIOD_H1, 5, h1_rates) || !GetRates(_Period, MathMax(ENTRY_SwingLookbackBars + 3, 8), m15_rates))
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
      bool momentum_ok = rsi_m15 > 48.0 && rsi_m15 >= (rsi_m15_prev - 1.0) && macd_hist_1 > macd_hist_2 && macd_hist_1 > -(atr_m15 * 0.05);
      bool exhaustion_ok = (bb_upper - close_m15) > (atr_m15 * 0.05);
      int confirmations = (candle_ok ? 1 : 0) + (momentum_ok ? 1 : 0) + (exhaustion_ok ? 1 : 0);
      if(!(pullback_ok && confirmations >= 2))
         return(false);

      double entry_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double swing_low   = GetRecentSwingLow(m15_rates, ENTRY_SwingLookbackBars);
      BuildTradeLevels(true, entry_price, swing_low, atr_m15, atr_h1, "TP", setup);
      return(ValidateSetup(setup, true));
     }

   bool candle_ok = IsBearishPattern(m15_rates);
   bool pullback_ok = close_h1 < ema200_h1 && (near_fast || near_medium);
   bool momentum_ok = rsi_m15 < 52.0 && rsi_m15 <= (rsi_m15_prev + 1.0) && macd_hist_1 < macd_hist_2 && macd_hist_1 < (atr_m15 * 0.05);
   bool exhaustion_ok = (close_m15 - bb_lower) > (atr_m15 * 0.05);
   int confirmations = (candle_ok ? 1 : 0) + (momentum_ok ? 1 : 0) + (exhaustion_ok ? 1 : 0);
   if(!(pullback_ok && confirmations >= 2))
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
   if(!GetRates(_Period, MathMax(ENTRY_SwingLookbackBars + 3, 8), m15_rates))
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
      if(!(breakout_ok && (squeeze_ok || momentum_ok)))
         return(false);

      double entry_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double anchor = MathMin(asian_low, GetRecentSwingLow(m15_rates, ENTRY_SwingLookbackBars));
      BuildTradeLevels(true, entry_price, anchor, atr_m15, atr_h1, "BO", setup);
      return(ValidateSetup(setup, true));
     }

   bool breakout_ok = m15_rates[1].close < asian_low - breakout_buffer && m15_rates[2].close >= asian_low - breakout_buffer;
   bool squeeze_ok = squeeze_width_prev <= ENTRY_MaxSqueezeWidthPoints && squeeze_width_now > squeeze_width_prev;
   bool momentum_ok = macd_hist_1 < 0.0 && macd_hist_1 < macd_hist_2;
   if(!(breakout_ok && (squeeze_ok || momentum_ok)))
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

   if(rsi_h1 >= 48.0 && rsi_h1 <= 52.0)
      return(0);

   double macd_hist = macd_main_h1 - macd_signal_h1;
   double macd_threshold = atr_h1 * 0.01;

   if(ema50_h4_1 > ema200_h4_1 && (ema50_h4_1 >= ema50_h4_2 || (rsi_h1 > 52.0 && macd_hist >= macd_threshold)))
      return(1);

   if(ema50_h4_1 < ema200_h4_1 && (ema50_h4_1 <= ema50_h4_2 || (rsi_h1 < 48.0 && macd_hist <= -macd_threshold)))
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
         WriteLog(StringFormat("Filtro de notícias ativado (%d/%d min), mas não irá bloquear trades nesta versão. É necessária integração manual com calendário económico externo para bloqueio automático.",
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

   bool CanOpenManagedPosition(const long desired_type)
     {
      if(!GEN_EnableBasketTrading || !IsHedgingAccount())
         return(!HasManagedPosition());

      int total_positions = CountManagedPositions();
      int max_positions_per_direction = GEN_MaxPositionsPerDirection;
      if(RISK_BasketMaxEntries > 0)
         max_positions_per_direction = MathMin(max_positions_per_direction, RISK_BasketMaxEntries);

      if(total_positions >= GEN_MaxTotalPositions)
         return(false);

      int same_direction = CountManagedPositions(desired_type);
      if(same_direction >= max_positions_per_direction)
         return(false);

      long opposite_type = GetOppositePositionType(desired_type);
      if(!GEN_AllowOppositeDirections && CountManagedPositions(opposite_type) > 0)
         return(false);

      if(GEN_AllowOppositeDirections && !CanOpenOppositeDirections() && CountManagedPositions(opposite_type) > 0)
         return(false);

      return(true);
     }

   int CountManagedPositions(const long filter_type = -1)
     {
      int count = 0;
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;

         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if((ulong)PositionGetInteger(POSITION_MAGIC) != GEN_MagicNumber)
            continue;
         if(filter_type != -1 && PositionGetInteger(POSITION_TYPE) != filter_type)
            continue;

         count++;
        }
      return(count);
     }

bool HasForeignSymbolPosition()
  {
   if(!PositionSelect(_Symbol))
      return(false);

   return((ulong)PositionGetInteger(POSITION_MAGIC) != GEN_MagicNumber);
  }

void DetectExistingManagedPosition()
  {
   return;
  }

void CacheOpenPositionState()
  {
   return;
  }

void TryPartialClose(const ulong ticket, const double volume)
  {
   double close_volume = volume * (RISK_PartialClosePercent / 100.0);
   double min_volume   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double step_volume  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   close_volume = NormalizeVolume(close_volume, min_volume, volume, step_volume);
   if(close_volume < min_volume || (volume - close_volume) < min_volume)
     {
      SavePartialState(ticket);
      return;
     }

   if(trade.PositionClosePartial(ticket, close_volume))
     {
      SavePartialState(ticket);
      WriteLog(StringFormat("Parcial executada no ticket %I64u com %.2f lots.", ticket, close_volume), false);
      return;
     }

    SavePartialState(ticket);
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
   if(!GetRates(_Period, 4, rates))
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
   int copied = CopyRates(_Symbol, _Period, from, to, rates);
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
   double steps   = MathFloor((bounded / step_volume) + VOLUME_ROUNDING_EPSILON);
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
   double min_stop_points    = MathCeil(GetBrokerStopDistancePrice() / _Point) + STOP_BUFFER_POINTS;
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
   return(rates[1].close > rates[1].open && lower_wick > (body * ENTRY_REJECTION_WICK_BODY_RATIO) && upper_wick < lower_wick);
  }

bool IsBearishRejection(MqlRates &rates[])
  {
   double body = MathAbs(rates[1].close - rates[1].open);
   double upper_wick = rates[1].high - MathMax(rates[1].open, rates[1].close);
   double lower_wick = MathMin(rates[1].open, rates[1].close) - rates[1].low;
   return(rates[1].close < rates[1].open && upper_wick > (body * ENTRY_REJECTION_WICK_BODY_RATIO) && lower_wick < upper_wick);
  }

string BuildPositionComment(const int risk_points, const string tag)
  {
   return(StringFormat("GL|%d|%s", risk_points, tag));
  }

string BuildPositionComment(const int risk_points, const string tag, const int basket_id, const long position_type)
   {
    string direction = (position_type == POSITION_TYPE_BUY) ? "BUY" : "SELL";
    return(StringFormat("GL|%d|%s|B%d|%s", risk_points, tag, basket_id, direction));
   }

string BuildPartialStatePrefix()
   {
    return(StringFormat("GreenLionPartial_%I64u_", GEN_MagicNumber));
   }

string BuildBasketActiveKey(const int basket_id)
   {
    return(StringFormat("GreenLionBasket_%I64u_%d", GEN_MagicNumber, basket_id));
   }

string BuildBasketPeakProfitKey(const int basket_id)
   {
    return(StringFormat("GreenLionBasketPeak_%I64u_%d", GEN_MagicNumber, basket_id));
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

void ClearAllPartialState()
   {
    GlobalVariablesDeleteAll(BuildPartialStatePrefix());
   }

int ParseRiskPoints(const string comment)
  {
   string parts[];
   int count = StringSplit(comment, '|', parts);
   if(count < 3)
      return(0);
   return((int)StringToInteger(parts[1]));
  }

int ParseBasketId(const string comment)
  {
   string parts[];
   int count = StringSplit(comment, '|', parts);
   if(count < 4)
      return(0);
   if(StringLen(parts[3]) < 2 || StringSubstr(parts[3], 0, 1) != "B")
      return(0);
   return((int)StringToInteger(StringSubstr(parts[3], 1)));
  }

long GetOppositePositionType(const long position_type)
  {
   if(position_type == POSITION_TYPE_BUY)
      return(POSITION_TYPE_SELL);
   return(POSITION_TYPE_BUY);
  }

bool IsHedgingAccount()
  {
   return((ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING);
  }

bool CanOpenOppositeDirections()
  {
   return(IsHedgingAccount() && (bool)AccountInfoInteger(ACCOUNT_HEDGE_ALLOWED));
  }

int GetOpenBasketId(const long position_type)
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
      if(PositionGetInteger(POSITION_TYPE) != position_type)
         continue;

      int basket_id = ParseBasketId(PositionGetString(POSITION_COMMENT));
      if(basket_id > 0)
         return(basket_id);
     }
   return(0);
  }

int GetOrCreateBasketId(const long position_type)
  {
   int basket_id = GetOpenBasketId(position_type);
   if(basket_id > 0)
      return(basket_id);

   basket_id = g_nextBasketId;
   g_nextBasketId++;
   return(basket_id);
  }

void InitializeBasketSequence()
  {
   int max_basket_id = 0;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != GEN_MagicNumber)
         continue;

      max_basket_id = MathMax(max_basket_id, ParseBasketId(PositionGetString(POSITION_COMMENT)));
     }

   if(HistorySelect(0, TimeCurrent()))
     {
      for(int i = HistoryDealsTotal() - 1; i >= 0; --i)
        {
         ulong ticket = HistoryDealGetTicket(i);
         if(ticket == 0)
            continue;
         if(HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol)
            continue;
         if((ulong)HistoryDealGetInteger(ticket, DEAL_MAGIC) != GEN_MagicNumber)
            continue;

         max_basket_id = MathMax(max_basket_id, ParseBasketId(HistoryDealGetString(ticket, DEAL_COMMENT)));
        }
     }

   g_nextBasketId = max_basket_id + 1;
   if(g_nextBasketId < 1)
      g_nextBasketId = 1;
  }

void RegisterBasketAsActive(const int basket_id)
  {
   if(basket_id > 0)
      GlobalVariableSet(BuildBasketActiveKey(basket_id), (double)TimeCurrent());
  }

int CountOpenPositionsByBasket(const int basket_id)
  {
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != GEN_MagicNumber)
         continue;
      if(ParseBasketId(PositionGetString(POSITION_COMMENT)) != basket_id)
         continue;
      count++;
     }
   return(count);
  }

double GetBasketOpenProfit(const int basket_id)
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
      if(ParseBasketId(PositionGetString(POSITION_COMMENT)) != basket_id)
         continue;

      profit += PositionGetDouble(POSITION_PROFIT);
     }
   return(profit);
  }

double GetBasketClosedProfit(const int basket_id)
  {
   double profit = 0.0;
   if(!HistorySelect(0, TimeCurrent()))
      return(0.0);

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
      if(ParseBasketId(HistoryDealGetString(ticket, DEAL_COMMENT)) != basket_id)
         continue;

      profit += HistoryDealGetDouble(ticket, DEAL_PROFIT) +
                HistoryDealGetDouble(ticket, DEAL_SWAP) +
                HistoryDealGetDouble(ticket, DEAL_COMMISSION);
     }
   return(profit);
  }

double GetBasketOpenVolume(const int basket_id)
  {
   double volume = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != GEN_MagicNumber)
         continue;
      if(ParseBasketId(PositionGetString(POSITION_COMMENT)) != basket_id)
         continue;

      volume += PositionGetDouble(POSITION_VOLUME);
     }
   return(volume);
  }

   double GetRiskValueForPoints(const int risk_points, const double volume)
     {
      double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double tick_size  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      if(risk_points <= 0 || volume <= 0.0 || tick_value <= 0.0 || tick_size <= 0.0)
         return(0.0);

      double stop_price_distance = risk_points * _Point;
      return((stop_price_distance / tick_size) * tick_value * volume);
     }

   double GetBasketCommittedRiskCurrency(const int basket_id)
     {
      double risk_value = 0.0;
      if(!HistorySelect(0, TimeCurrent()))
         return(0.0);

      for(int i = HistoryDealsTotal() - 1; i >= 0; --i)
        {
         ulong ticket = HistoryDealGetTicket(i);
         if(ticket == 0)
            continue;
         if(HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol)
            continue;
         if((ulong)HistoryDealGetInteger(ticket, DEAL_MAGIC) != GEN_MagicNumber)
            continue;
         if((long)HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_IN)
            continue;

         string comment = HistoryDealGetString(ticket, DEAL_COMMENT);
         if(ParseBasketId(comment) != basket_id)
            continue;

         risk_value += GetRiskValueForPoints(ParseRiskPoints(comment), HistoryDealGetDouble(ticket, DEAL_VOLUME));
        }
      return(risk_value);
     }

      double GetBasketOpenCommittedRiskCurrency(const int basket_id)
        {
         double risk_value = 0.0;

         for(int i = PositionsTotal() - 1; i >= 0; --i)
           {
            ulong ticket = PositionGetTicket(i);
            if(ticket == 0 || !PositionSelectByTicket(ticket))
               continue;
            if(PositionGetString(POSITION_SYMBOL) != _Symbol)
               continue;
            if((ulong)PositionGetInteger(POSITION_MAGIC) != GEN_MagicNumber)
               continue;

            string comment = PositionGetString(POSITION_COMMENT);
            if(ParseBasketId(comment) != basket_id)
               continue;

            double entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
            double stop_loss   = PositionGetDouble(POSITION_SL);
            double volume      = PositionGetDouble(POSITION_VOLUME);
            int risk_points    = ParseRiskPoints(comment);

            if(stop_loss > 0.0)
               risk_points = (int)MathRound(MathAbs(entry_price - stop_loss) / _Point);

            risk_value += GetRiskValueForPoints(risk_points, volume);
           }

         return(risk_value);
        }

   double GetBasketTotalProfit(const int basket_id)
     {
      return(GetBasketOpenProfit(basket_id) + GetBasketClosedProfit(basket_id));
     }

   double GetBasketProfitRR(const int basket_id)
     {
      double committed_risk = GetBasketCommittedRiskCurrency(basket_id);
      if(committed_risk <= 0.0)
         return(0.0);

      return(GetBasketTotalProfit(basket_id) / committed_risk);
     }

   double GetAggregateLossSafetyStop(const bool is_buy, const double fallback_stop, const double volume)
      {
       double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
       double tick_size  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
       double bid        = SymbolInfoDouble(_Symbol, SYMBOL_BID);
       double ask        = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
       double entry_price = is_buy ? ask : bid;
       if(entry_price <= 0.0 || volume <= 0.0 || tick_value <= 0.0 || tick_size <= 0.0)
            return(fallback_stop);

       double emergency_budget = AccountInfoDouble(ACCOUNT_BALANCE) * (EXIT_BasketLossClosePercent / 100.0);
       if(emergency_budget <= 0.0)
            return(fallback_stop);

       double price_distance = (emergency_budget / (tick_value * volume)) * tick_size;
       double safety_stop = is_buy ? entry_price - price_distance : entry_price + price_distance;
       return(NormalizeDouble(safety_stop, _Digits));
      }

   double LoadBasketPeakProfit(const int basket_id)
      {
       string key = BuildBasketPeakProfitKey(basket_id);
       if(!GlobalVariableCheck(key))
            return(0.0);
       return(GlobalVariableGet(key));
      }

   void SaveBasketPeakProfit(const int basket_id, const double profit_value)
      {
       GlobalVariableSet(BuildBasketPeakProfitKey(basket_id), profit_value);
      }

   void ClearBasketPeakProfit(const int basket_id)
      {
       string key = BuildBasketPeakProfitKey(basket_id);
       if(GlobalVariableCheck(key))
            GlobalVariableDel(key);
      }

   bool CloseBasketPositions(const int basket_id, const string reason)
     {
      bool all_closed = true;

      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if((ulong)PositionGetInteger(POSITION_MAGIC) != GEN_MagicNumber)
            continue;
         if(ParseBasketId(PositionGetString(POSITION_COMMENT)) != basket_id)
            continue;

         if(!trade.PositionClose(ticket))
           {
            all_closed = false;
            LogTradeFailure("BASKET_CLOSE");
           }
        }

      if(all_closed)
         WriteLog(StringFormat("Basket %d fechado por alvo agregado: %s", basket_id, reason), false);

      return(all_closed);
     }

   void CheckBasketExitTargets()
     {
      if(!EXIT_UseAggregateLossOnlyClose &&
         EXIT_BasketTargetCurrency <= 0.0 &&
         EXIT_BasketTargetRR <= 0.0 &&
         !EXIT_UseBasketProfitTrailing)
         return;

      for(int basket_id = 1; basket_id < g_nextBasketId; ++basket_id)
        {
         string key = BuildBasketActiveKey(basket_id);
         if(!GlobalVariableCheck(key))
            continue;
         if(CountOpenPositionsByBasket(basket_id) <= 0)
            continue;

         double open_profit = GetBasketOpenProfit(basket_id);
         double basket_profit = GetBasketTotalProfit(basket_id);
         double basket_rr = GetBasketProfitRR(basket_id);
         double balance = AccountInfoDouble(ACCOUNT_BALANCE);

         if(EXIT_UseAggregateLossOnlyClose && EXIT_BasketLossClosePercent > 0.0)
            {
             double loss_threshold = -(balance * (EXIT_BasketLossClosePercent / 100.0));
             if(open_profit <= loss_threshold)
                {
                  LogBasketSnapshot(basket_id, "limite de perda agregado atingido");
                  CloseBasketPositions(basket_id, StringFormat("loss %.2f <= %.2f", open_profit, loss_threshold));
                  continue;
                }
            }

         if(EXIT_UseBasketProfitTrailing)
            {
             double trail_start = balance * (EXIT_BasketTrailStartPercent / 100.0);
             double trail_giveback = balance * (EXIT_BasketTrailGivebackPercent / 100.0);
             double peak_profit = MathMax(LoadBasketPeakProfit(basket_id), basket_profit);
             SaveBasketPeakProfit(basket_id, peak_profit);

             if(trail_start > 0.0 && trail_giveback > 0.0 && peak_profit >= trail_start && basket_profit <= (peak_profit - trail_giveback))
                {
                  LogBasketSnapshot(basket_id, "trailing de lucro do basket acionado");
                  CloseBasketPositions(basket_id, StringFormat("trail %.2f <= peak %.2f - %.2f", basket_profit, peak_profit, trail_giveback));
                  continue;
                }
            }

         if(EXIT_BasketTargetCurrency > 0.0 && basket_profit >= EXIT_BasketTargetCurrency)
           {
            LogBasketSnapshot(basket_id, "alvo monetario atingido");
            CloseBasketPositions(basket_id, StringFormat("profit %.2f >= %.2f", basket_profit, EXIT_BasketTargetCurrency));
            continue;
           }

         if(EXIT_BasketTargetRR > 0.0 && basket_rr >= EXIT_BasketTargetRR)
           {
            LogBasketSnapshot(basket_id, "alvo RR atingido");
            CloseBasketPositions(basket_id, StringFormat("RR %.2f >= %.2f", basket_rr, EXIT_BasketTargetRR));
           }
        }
     }

void LogBasketSnapshot(const int basket_id, const string reason)
  {
   if(basket_id <= 0)
      return;

      WriteLog(StringFormat("Basket %d [%s] Open=%d Volume=%.2f Floating=%.2f Realized=%.2f Total=%.2f RR=%.2f",
                         basket_id,
                         reason,
                         CountOpenPositionsByBasket(basket_id),
                         GetBasketOpenVolume(basket_id),
                         GetBasketOpenProfit(basket_id),
                            GetBasketClosedProfit(basket_id),
                            GetBasketTotalProfit(basket_id),
                            GetBasketProfitRR(basket_id)), false);
  }

void FinalizeClosedBaskets()
  {
   for(int basket_id = 1; basket_id < g_nextBasketId; ++basket_id)
     {
      string key = BuildBasketActiveKey(basket_id);
      if(!GlobalVariableCheck(key))
         continue;
      if(CountOpenPositionsByBasket(basket_id) > 0)
         continue;

      WriteLog(StringFormat("Basket %d fechado. Profit realizado=%.2f", basket_id, GetBasketClosedProfit(basket_id)), false);
      ClearBasketPeakProfit(basket_id);
      GlobalVariableDel(key);
     }
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
