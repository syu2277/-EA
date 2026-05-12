//+------------------------------------------------------------------+
//| FX_Combined_Portfolio_Currency_V1_2.mq5                         |
//| 2つのEAを独立ロジックのまま統合 / 同時保有OK / MagicNumber分離       |
//+------------------------------------------------------------------+
#property strict
#property version "1.20"

// 通貨版V1.2変更メモ:
// - EA② BUY/SELL Portfolioを主役化。EA① DowFibは初期OFF。
// - EA②のSellロジックを復活。SELL専用スナイパーは初期OFF。
// - EA②のpips換算をFX通貨ペア標準へ変更。
// - V1.1: SELL専用スナイパー側も含め、Gold用の固定pips換算を通貨用AUTO pipsへ統一。
// - V1.2: EA②に最大保有バー数決済を追加（初期24本、M15で約6時間）。
// - 初期値はEURUSD/USDJPY共通のドル円寄せ守り設定。

#include <Trade/Trade.mqh>
CTrade trade;

input group "【統合EA 起動スイッチ】"
input bool ComboUse_DowFibEA      = false;  // EA① Dow+Fib側を稼働（通貨版V1では初期OFF）
input bool ComboUse_BuySellEA     = true;   // EA② BUY/SELL Portfolio側を稼働（通貨版V1の主役）

//====================================================================
// EA①: Dow + ZigZag + CHoCH + Fibonacci + FVG/OB  ※識別子 D_ で分離
//====================================================================
//====================================================================
// パラメータ
//====================================================================
input group "【基本設定】"
input bool   D_InpBuyEnable                   = true;      // 買いを有効
input bool   D_InpSellEnable                  = true;      // 売りを有効
input int    D_InpMaxSpreadPips               = 2;         // 最大スプレッド pips（通貨版）
input bool   D_InpOnePositionPerTF            = false;     // 時間足ごとに1ポジションのみ
input bool   D_InpBlockSameDirectionOtherTF   = false;     // 他時間足で同方向ポジション中は新規禁止
input int    D_InpSlippagePoints              = 30;        // 許容スリッページ points

input group "【プロップ用リスク制御】"
input bool   D_InpUseDailyLossStop            = true;      // 1日最大損失で停止
input double D_InpDailyMaxLossPercent         = 1.5;       // 1日最大損失 %（通貨版）
input int    D_InpDailyLossStopDays           = 1;         // 1日最大損失到達後の停止日数
input int    D_InpMaxOpenPositions            = 3;         // 最大同時ポジション数（通貨版）
input bool   D_InpUseMaxTotalRisk             = true;      // 最大合計リスク制限を使う
input double D_InpMaxTotalRiskPercent         = 1.0;       // 最大合計リスク %
input bool   D_InpUseMaxLotLimit              = true;      // 最大ロット制限を使う
input double D_InpMaxLotPerTrade              = 0.10;      // 1ポジション最大ロット（通貨版初期値）
input bool   D_InpUseConsecutiveLossStop      = true;      // 連敗停止を使う
input int    D_InpMaxConsecutiveLosses        = 3;         // 当日最大連敗数
input int    D_InpConsecutiveLossStopDays     = 1;         // 連敗到達後の停止日数

input group "【稼働曜日】"
input bool   D_InpTradeMonday                 = false;     // 月曜日 稼働
input bool   D_InpTradeTuesday                = true;      // 火曜日 稼働
input bool   D_InpTradeWednesday              = true;      // 水曜日 稼働
input bool   D_InpTradeThursday               = true;      // 木曜日 稼働
input bool   D_InpTradeFriday                 = true;      // 金曜日 稼働
input bool   D_InpTradeSaturday               = false;     // 土曜日 稼働
input bool   D_InpTradeSunday                 = false;     // 日曜日 稼働

input group "【稼働時間フィルター・2部制・サーバー時間】"
input bool   D_InpUseTimeFilter               = true;      // 稼働時間フィルターを使う

input bool   D_InpUseSession1                 = true;      // 第1部を使う
input int    D_InpSession1StartHour           = 6;         // 第1部 開始 時
input int    D_InpSession1StartMinute         = 0;         // 第1部 開始 分
input int    D_InpSession1EndHour             = 16;        // 第1部 終了 時
input int    D_InpSession1EndMinute           = 0;         // 第1部 終了 分

input bool   D_InpUseSession2                 = true;      // 第2部を使う
input int    D_InpSession2StartHour           = 18;        // 第2部 開始 時
input int    D_InpSession2StartMinute         = 0;         // 第2部 開始 分
input int    D_InpSession2EndHour             = 20;        // 第2部 終了 時
input int    D_InpSession2EndMinute           = 0;         // 第2部 終了 分

input bool   D_InpUseFridaySpecialTime        = true;      // 金曜だけ特別時間を使う
input bool   D_InpFridayUseSession2           = true;      // 金曜 第2部を使う
input int    D_InpFridayEndHour               = 17;        // 金曜 終了 時
input int    D_InpFridayEndMinute             = 0;         // 金曜 終了 分

input group "【監視時間足】"
input bool   D_InpUseM10                      = true;      // 10分足を監視
input bool   D_InpUseM15                      = true;      // 15分足を監視
input bool   D_InpUseM30                      = true;      // 30分足を監視
input bool   D_InpUseH1                       = true;      // 1時間足を監視
input bool   D_InpUseH4                       = true;      // 4時間足を監視

input group "【リスク設定】"
input double D_InpRiskPercent_M10             = 0.25;      // 10分足 リスク%（通貨版）
input double D_InpRiskPercent_M15             = 0.25;      // 15分足 リスク%（通貨版）
input double D_InpRiskPercent_M30             = 0.25;      // 30分足 リスク%（通貨版）
input double D_InpRiskPercent_H1              = 0.25;      // 1時間足 リスク%（通貨版）
input double D_InpRiskPercent_H4              = 0.25;      // 4時間足 リスク%（通貨版）

input group "【ZigZag設定】"
input int    D_InpZZDepth                     = 20;        // ZigZag Depth
input int    D_InpZZDeviation                 = 25;        // ZigZag Deviation
input int    D_InpZZBackstep                  = 10;        // ZigZag Backstep

input group "【CHoCH後セットアップ設定】"
input int    D_InpSetupExpiryBars             = 50;        // CHoCH後の有効本数
input double D_InpMinImpulsePips              = 30.0;      // 1波の最小値幅 pips（通貨版）
input bool   D_InpRequirePullbackClose        = true;      // 終値がフィボゾーン内必須

input group "【BUYフィボ設定】"
input double D_InpBuyFibEntryUpper            = 50.0;      // BUY 押し上限 %
input double D_InpBuyFibEntryLower            = 61.8;      // BUY 押し下限 %
input double D_InpBuyFibSLLevel               = 78.6;      // BUY SL用フィボ %

input group "【SELLフィボ設定】"
input double D_InpSellFibEntryUpper           = 50.0;      // SELL 戻り上限 %
input double D_InpSellFibEntryLower           = 61.8;      // SELL 戻り下限 %
input double D_InpSellFibSLLevel              = 78.6;      // SELL SL用フィボ %

input group "【SL設定】"
input double D_InpSLBufferPips                = 3.0;       // SLバッファ pips（通貨版）
input bool   D_InpUseSLWidthFilter            = true;      // SL幅フィルターを使う
input double D_InpMinSLPips                   = 10.0;      // 最小SL幅 pips（通貨版）
input double D_InpMaxSLPips                   = 25.0;      // 最大SL幅 pips（通貨版）

input group "【FVG / OB設定】"
input bool   D_InpUseFVG                      = true;      // FVGを使う
input bool   D_InpUseOB                       = true;      // OBを使う
input bool   D_InpRequireBothFVGOB            = false;     // FVGとOBの両方重複を必須
input double D_InpMinFVGSizePips              = 2.0;       // 最小FVGサイズ pips（通貨版）
input int    D_InpFVGSearchBars               = 50;        // FVG探索本数
input int    D_InpOBLookbackBars              = 50;        // OB探索本数

input group "【反発足確認】"
input bool   D_InpUseRejectionCandle          = true;      // 反発足確認を使う
input bool   D_InpRequireCandleColor          = false;     // BUY陽線/SELL陰線を必須
input bool   D_InpRequireCloseOutsideZone     = false;     // BUYは上抜け終値/SELLは下抜け終値
input double D_InpWickRatio                   = 1.0;       // ヒゲ比率
input double D_InpMinBodyPips                 = 2.0;       // 最小実体 pips（通貨版）

input group "【利確・SL管理】"
input double D_InpTP_RR                       = 1.0;       // 初期TP RR
input bool   D_InpUsePartialTakeProfit        = false;     // 部分利確を使う
input double D_InpPartialRR                   = 1.2;       // 部分利確RR
input double D_InpPartialClosePercent         = 50.0;      // 部分利確 %
input double D_InpMoveSLPlusPips              = 2.0;       // 部分利確後 SLを建値+〇pips（通貨版）
input bool   D_InpUseSecondSLMove             = false;     // 追加SL移動を使う
input double D_InpSecondLockRR                = 2.0;       // 追加SL移動RR
input double D_InpSecondSL_RR                 = 1.5;       // SL移動先RR

input group "【トレーリング設定】"
input bool   D_InpUseZigZagTrailing           = false;     // ZigZagトレーリングを使う
input double D_InpTrailBufferPips             = 3.0;       // トレーリングバッファ pips（通貨版）

input group "【マジックナンバー】"
input int    D_InpMagic_M10                   = 10010;     // 10分足 Magic
input int    D_InpMagic_M15                   = 15001;     // 15分足 Magic
input int    D_InpMagic_M30                   = 30001;     // 30分足 Magic
input int    D_InpMagic_H1                    = 10001;     // 1時間足 Magic
input int    D_InpMagic_H4                    = 40001;     // 4時間足 Magic

input group "【チャート表示】"
input bool   D_InpDrawObjects                 = true;      // 矢印/Fib/CHoCH/FVG/OBを表示

//====================================================================
// 構造体
//====================================================================
struct D_TFInfo
{
   ENUM_TIMEFRAMES tf;
   bool enable;
   int magic;
   double risk;
   datetime lastBarTime;
   int zzHandle;
};

struct D_SwingPoint
{
   int index;
   datetime time;
   double price;
   bool isHigh;
};

struct D_SetupState
{
   bool active;
   int dir;
   bool locked;
   datetime chochTime;
   datetime startTime;
   datetime extremeTime;
   double breakLevel;
   double startPrice;
   double extremePrice;
};

D_TFInfo D_TFs[5];
D_SetupState D_Setups[5];

//====================================================================
// 基本関数
//====================================================================
double D_Pip()
{
   if(_Digits == 3 || _Digits == 5)
      return _Point * 10.0;

   return _Point;
}

double D_PipsToPrice(double pips)
{
   return pips * D_Pip();
}

double D_NormalizePrice(double price)
{
   return NormalizeDouble(price, _Digits);
}

string D_TFName(ENUM_TIMEFRAMES tf)
{
   if(tf == PERIOD_M10) return "M10";
   if(tf == PERIOD_M15) return "M15";
   if(tf == PERIOD_M30) return "M30";
   if(tf == PERIOD_H1)  return "H1";
   if(tf == PERIOD_H4)  return "H4";

   return "TF";
}

bool D_IsOurMagic(int magic)
{
   return magic == D_InpMagic_M10 ||
          magic == D_InpMagic_M15 ||
          magic == D_InpMagic_M30 ||
          magic == D_InpMagic_H1  ||
          magic == D_InpMagic_H4;
}

double D_SpreadPips()
{
   return (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID)) / D_Pip();
}

bool D_IsNewBar(D_TFInfo &info)
{
   datetime t = iTime(_Symbol, info.tf, 0);

   if(t != info.lastBarTime)
   {
      info.lastBarTime = t;
      return true;
   }

   return false;
}

datetime D_TodayStart()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);

   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;

   return StructToTime(dt);
}

//====================================================================
// 稼働時間フィルター
//====================================================================
bool D_IsInTimeRange(int nowMin, int startMin, int endMin)
{
   if(startMin == endMin)
      return true;

   if(startMin < endMin)
      return nowMin >= startMin && nowMin <= endMin;

   return nowMin >= startMin || nowMin <= endMin;
}

bool D_IsDayAllowed(int dayOfWeek)
{
   if(dayOfWeek == 0) return D_InpTradeSunday;
   if(dayOfWeek == 1) return D_InpTradeMonday;
   if(dayOfWeek == 2) return D_InpTradeTuesday;
   if(dayOfWeek == 3) return D_InpTradeWednesday;
   if(dayOfWeek == 4) return D_InpTradeThursday;
   if(dayOfWeek == 5) return D_InpTradeFriday;
   if(dayOfWeek == 6) return D_InpTradeSaturday;

   return false;
}

bool D_IsTradingTime()
{
   if(!D_InpUseTimeFilter)
      return true;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);

   if(!D_IsDayAllowed(dt.day_of_week))
      return false;

   int nowMin = dt.hour * 60 + dt.min;

   int s1Start = D_InpSession1StartHour * 60 + D_InpSession1StartMinute;
   int s1End   = D_InpSession1EndHour   * 60 + D_InpSession1EndMinute;

   int s2Start = D_InpSession2StartHour * 60 + D_InpSession2StartMinute;
   int s2End   = D_InpSession2EndHour   * 60 + D_InpSession2EndMinute;

   if(dt.day_of_week == 5 && D_InpUseFridaySpecialTime)
   {
      int fridayEnd = D_InpFridayEndHour * 60 + D_InpFridayEndMinute;

      bool ok1 = false;
      bool ok2 = false;

      if(D_InpUseSession1)
      {
         int end1 = MathMin(s1End, fridayEnd);
         ok1 = D_IsInTimeRange(nowMin, s1Start, end1);
      }

      if(D_InpUseSession2 && D_InpFridayUseSession2)
      {
         int end2 = MathMin(s2End, fridayEnd);

         if(s2Start <= fridayEnd)
            ok2 = D_IsInTimeRange(nowMin, s2Start, end2);
      }

      return ok1 || ok2;
   }

   bool session1OK = false;
   bool session2OK = false;

   if(D_InpUseSession1)
      session1OK = D_IsInTimeRange(nowMin, s1Start, s1End);

   if(D_InpUseSession2)
      session2OK = D_IsInTimeRange(nowMin, s2Start, s2End);

   return session1OK || session2OK;
}

//====================================================================
// 停止管理
//====================================================================
string D_GV_DayKey()
{
   return "GD20_DAY_" + _Symbol;
}

string D_GV_DayEquityKey()
{
   return "GD20_DAY_EQUITY_" + _Symbol;
}

string D_GV_PauseUntilKey()
{
   return "GD20_PAUSE_UNTIL_" + _Symbol;
}

void D_UpdateDailyBaseEquity()
{
   datetime today = D_TodayStart();

   if(!GlobalVariableCheck(D_GV_DayKey()) || (datetime)GlobalVariableGet(D_GV_DayKey()) != today)
   {
      GlobalVariableSet(D_GV_DayKey(), (double)today);
      GlobalVariableSet(D_GV_DayEquityKey(), AccountInfoDouble(ACCOUNT_EQUITY));
   }
}

void D_SetTradingPauseDays(int days, string reason)
{
   if(days < 1)
      days = 1;

   datetime until = TimeCurrent() + days * 86400;
   double currentUntil = 0;

   if(GlobalVariableCheck(D_GV_PauseUntilKey()))
      currentUntil = GlobalVariableGet(D_GV_PauseUntilKey());

   if((double)until > currentUntil)
   {
      GlobalVariableSet(D_GV_PauseUntilKey(), (double)until);
      Print("EA停止: ", reason, " / 停止期限: ", TimeToString(until, TIME_DATE | TIME_MINUTES));
   }
}

bool D_IsTradingPaused()
{
   if(!GlobalVariableCheck(D_GV_PauseUntilKey()))
      return false;

   datetime until = (datetime)GlobalVariableGet(D_GV_PauseUntilKey());

   if(until <= TimeCurrent())
   {
      GlobalVariableDel(D_GV_PauseUntilKey());
      return false;
   }

   return true;
}

bool D_IsDailyLossStopHit()
{
   if(!D_InpUseDailyLossStop)
      return false;

   D_UpdateDailyBaseEquity();

   double startEquity = GlobalVariableGet(D_GV_DayEquityKey());

   if(startEquity <= 0)
      return false;

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double lossPercent = (startEquity - equity) / startEquity * 100.0;

   if(lossPercent >= D_InpDailyMaxLossPercent)
   {
      D_SetTradingPauseDays(D_InpDailyLossStopDays, "1日最大損失到達");
      return true;
   }

   return false;
}

int D_CountOurOpenPositions()
{
   int count = 0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);

      if(!PositionSelectByTicket(ticket))
         continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      int magic = (int)PositionGetInteger(POSITION_MAGIC);

      if(D_IsOurMagic(magic))
         count++;
   }

   return count;
}

double D_RiskMoneyByDistance(double entry, double sl, double volume)
{
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

   double dist = MathAbs(entry - sl);

   if(dist <= 0 || tickValue <= 0 || tickSize <= 0)
      return 0.0;

   return dist / tickSize * tickValue * volume;
}

double D_PositionRiskPercent()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);

   if(balance <= 0)
      return 0.0;

   double totalRiskMoney = 0.0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);

      if(!PositionSelectByTicket(ticket))
         continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      int magic = (int)PositionGetInteger(POSITION_MAGIC);

      if(!D_IsOurMagic(magic))
         continue;

      long type = PositionGetInteger(POSITION_TYPE);
      double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl = PositionGetDouble(POSITION_SL);
      double volume = PositionGetDouble(POSITION_VOLUME);

      if(sl <= 0)
         continue;

      bool riskExists = false;

      if(type == POSITION_TYPE_BUY && sl < entry)
         riskExists = true;

      if(type == POSITION_TYPE_SELL && sl > entry)
         riskExists = true;

      if(riskExists)
         totalRiskMoney += D_RiskMoneyByDistance(entry, sl, volume);
   }

   return totalRiskMoney / balance * 100.0;
}

double D_ProposedRiskPercent(double entry, double sl, double lot)
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);

   if(balance <= 0)
      return 0.0;

   double riskMoney = D_RiskMoneyByDistance(entry, sl, lot);

   return riskMoney / balance * 100.0;
}

int D_TodayConsecutiveLosses()
{
   if(!D_InpUseConsecutiveLossStop)
      return 0;

   datetime from = D_TodayStart();
   datetime to = TimeCurrent();

   if(!HistorySelect(from, to))
      return 0;

   int losses = 0;

   for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
   {
      ulong deal = HistoryDealGetTicket(i);

      if(deal == 0)
         continue;

      if(HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol)
         continue;

      int magic = (int)HistoryDealGetInteger(deal, DEAL_MAGIC);

      if(!D_IsOurMagic(magic))
         continue;

      long entryType = HistoryDealGetInteger(deal, DEAL_ENTRY);

      if(entryType != DEAL_ENTRY_OUT &&
         entryType != DEAL_ENTRY_OUT_BY &&
         entryType != DEAL_ENTRY_INOUT)
         continue;

      double profit =
         HistoryDealGetDouble(deal, DEAL_PROFIT) +
         HistoryDealGetDouble(deal, DEAL_SWAP) +
         HistoryDealGetDouble(deal, DEAL_COMMISSION);

      if(profit < -0.01)
         losses++;
      else if(profit > 0.01)
         break;
   }

   return losses;
}

bool D_IsConsecutiveLossStopHit()
{
   if(!D_InpUseConsecutiveLossStop)
      return false;

   int losses = D_TodayConsecutiveLosses();

   if(losses >= D_InpMaxConsecutiveLosses)
   {
      D_SetTradingPauseDays(D_InpConsecutiveLossStopDays, "連敗停止到達");
      return true;
   }

   return false;
}

bool D_RiskGuardAllowsNewTrade(double entry, double sl, double lot)
{
   if(D_IsTradingPaused())
      return false;

   if(D_IsDailyLossStopHit())
      return false;

   if(D_IsConsecutiveLossStopHit())
      return false;

   if(D_InpMaxOpenPositions > 0 && D_CountOurOpenPositions() >= D_InpMaxOpenPositions)
      return false;

   if(D_InpUseMaxTotalRisk)
   {
      double currentRisk = D_PositionRiskPercent();
      double newRisk = D_ProposedRiskPercent(entry, sl, lot);

      if(currentRisk + newRisk > D_InpMaxTotalRiskPercent)
         return false;
   }

   return true;
}

//====================================================================
// ZigZag取得
//====================================================================
bool D_GetLastSwings(D_TFInfo &info,
                   D_SwingPoint &s1,
                   D_SwingPoint &s2,
                   D_SwingPoint &s3,
                   D_SwingPoint &s4,
                   D_SwingPoint &s5,
                   D_SwingPoint &s6)
{
   double zz[];
   ArraySetAsSeries(zz, true);

   int copied = CopyBuffer(info.zzHandle, 0, 0, 500, zz);

   if(copied <= 0)
      return false;

   int found = 0;

   for(int i = 2; i < copied && found < 6; i++)
   {
      if(zz[i] != 0.0)
      {
         double high = iHigh(_Symbol, info.tf, i);
         double low  = iLow(_Symbol, info.tf, i);

         D_SwingPoint sp;
         sp.index = i;
         sp.time = iTime(_Symbol, info.tf, i);
         sp.price = zz[i];
         sp.isHigh = MathAbs(zz[i] - high) < MathAbs(zz[i] - low);

         if(found == 0) s1 = sp;
         if(found == 1) s2 = sp;
         if(found == 2) s3 = sp;
         if(found == 3) s4 = sp;
         if(found == 4) s5 = sp;
         if(found == 5) s6 = sp;

         found++;
      }
   }

   return found >= 6;
}

bool D_FindRecentHighLow(D_TFInfo &info,
                       D_SwingPoint &lastHigh,
                       D_SwingPoint &lastLow)
{
   D_SwingPoint s1, s2, s3, s4, s5, s6;

   if(!D_GetLastSwings(info, s1, s2, s3, s4, s5, s6))
      return false;

   D_SwingPoint arr[6];

   arr[0] = s1;
   arr[1] = s2;
   arr[2] = s3;
   arr[3] = s4;
   arr[4] = s5;
   arr[5] = s6;

   bool highFound = false;
   bool lowFound = false;

   for(int i = 0; i < 6; i++)
   {
      if(arr[i].isHigh && !highFound)
      {
         lastHigh = arr[i];
         highFound = true;
      }

      if(!arr[i].isHigh && !lowFound)
      {
         lastLow = arr[i];
         lowFound = true;
      }
   }

   return highFound && lowFound;
}

//====================================================================
// ポジション確認
//====================================================================
bool D_HasPositionByMagic(int magic)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);

      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
            PositionGetInteger(POSITION_MAGIC) == magic)
            return true;
      }
   }

   return false;
}

bool D_HasSameDirectionOtherTF(int currentMagic, long positionType)
{
   if(!D_InpBlockSameDirectionOtherTF)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);

      if(!PositionSelectByTicket(ticket))
         continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      int magic = (int)PositionGetInteger(POSITION_MAGIC);

      if(!D_IsOurMagic(magic))
         continue;

      if(magic == currentMagic)
         continue;

      if(PositionGetInteger(POSITION_TYPE) == positionType)
         return true;
   }

   return false;
}

//====================================================================
// セットアップ初期化
//====================================================================
void D_ResetSetup(int idx)
{
   D_Setups[idx].active = false;
   D_Setups[idx].dir = 0;
   D_Setups[idx].locked = false;
   D_Setups[idx].chochTime = 0;
   D_Setups[idx].startTime = 0;
   D_Setups[idx].extremeTime = 0;
   D_Setups[idx].breakLevel = 0;
   D_Setups[idx].startPrice = 0;
   D_Setups[idx].extremePrice = 0;
}

//====================================================================
// 描画
//====================================================================
void D_DrawArrow(string name, datetime t, double price, bool buy)
{
   if(!D_InpDrawObjects)
      return;

   ObjectCreate(0, name, OBJ_ARROW, 0, t, price);
   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, buy ? 233 : 234);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
}

void D_DrawLine(string name, datetime t1, datetime t2, double price)
{
   if(!D_InpDrawObjects)
      return;

   ObjectCreate(0, name, OBJ_TREND, 0, t1, price, t2, price);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
}

void D_DrawFibo(string name, datetime t1, double p1, datetime t2, double p2, bool buy)
{
   if(!D_InpDrawObjects)
      return;

   ObjectCreate(0, name, OBJ_FIBO, 0, t1, p1, t2, p2);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);

   ObjectSetInteger(0, name, OBJPROP_LEVELS, 6);

   double upper = buy ? D_InpBuyFibEntryUpper / 100.0 : D_InpSellFibEntryUpper / 100.0;
   double lower = buy ? D_InpBuyFibEntryLower / 100.0 : D_InpSellFibEntryLower / 100.0;
   double slLv  = buy ? D_InpBuyFibSLLevel / 100.0    : D_InpSellFibSLLevel / 100.0;

   ObjectSetDouble(0, name, OBJPROP_LEVELVALUE, 0, 0.0);
   ObjectSetDouble(0, name, OBJPROP_LEVELVALUE, 1, upper);
   ObjectSetDouble(0, name, OBJPROP_LEVELVALUE, 2, lower);
   ObjectSetDouble(0, name, OBJPROP_LEVELVALUE, 3, slLv);
   ObjectSetDouble(0, name, OBJPROP_LEVELVALUE, 4, 1.0);
   ObjectSetDouble(0, name, OBJPROP_LEVELVALUE, 5, 1.618);

   ObjectSetString(0, name, OBJPROP_LEVELTEXT, 0, "0.0");
   ObjectSetString(0, name, OBJPROP_LEVELTEXT, 1, "Entry Upper");
   ObjectSetString(0, name, OBJPROP_LEVELTEXT, 2, "Entry Lower");
   ObjectSetString(0, name, OBJPROP_LEVELTEXT, 3, "SL");
   ObjectSetString(0, name, OBJPROP_LEVELTEXT, 4, "100.0");
   ObjectSetString(0, name, OBJPROP_LEVELTEXT, 5, "161.8");
}

void D_DrawZone(string name, datetime t1, datetime t2, double high, double low)
{
   if(!D_InpDrawObjects)
      return;

   ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, high, t2, low);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
}

//====================================================================
// FVG / OB
//====================================================================
bool D_FindFVG(ENUM_TIMEFRAMES tf,
             bool buy,
             double zoneHigh,
             double zoneLow,
             double &fvgHigh,
             double &fvgLow,
             datetime &fvgTime)
{
   int maxBars = MathMax(5, D_InpFVGSearchBars);

   for(int i = 2; i <= maxBars; i++)
   {
      double hOlder = iHigh(_Symbol, tf, i + 1);
      double lOlder = iLow(_Symbol, tf, i + 1);
      double hNewer = iHigh(_Symbol, tf, i - 1);
      double lNewer = iLow(_Symbol, tf, i - 1);

      if(buy)
      {
         if(lNewer > hOlder)
         {
            fvgLow = hOlder;
            fvgHigh = lNewer;

            if((fvgHigh - fvgLow) / D_Pip() < D_InpMinFVGSizePips)
               continue;

            if(fvgHigh >= zoneLow && fvgLow <= zoneHigh)
            {
               fvgTime = iTime(_Symbol, tf, i);
               return true;
            }
         }
      }
      else
      {
         if(hNewer < lOlder)
         {
            fvgLow = hNewer;
            fvgHigh = lOlder;

            if((fvgHigh - fvgLow) / D_Pip() < D_InpMinFVGSizePips)
               continue;

            if(fvgHigh >= zoneLow && fvgLow <= zoneHigh)
            {
               fvgTime = iTime(_Symbol, tf, i);
               return true;
            }
         }
      }
   }

   return false;
}

bool D_FindOB(ENUM_TIMEFRAMES tf,
            bool buy,
            double zoneHigh,
            double zoneLow,
            double &obHigh,
            double &obLow,
            datetime &obTime)
{
   for(int i = 1; i <= D_InpOBLookbackBars; i++)
   {
      double open = iOpen(_Symbol, tf, i);
      double close = iClose(_Symbol, tf, i);
      double high = iHigh(_Symbol, tf, i);
      double low = iLow(_Symbol, tf, i);

      if(buy)
      {
         if(close < open)
         {
            obHigh = high;
            obLow = low;

            if(obHigh >= zoneLow && obLow <= zoneHigh)
            {
               obTime = iTime(_Symbol, tf, i);
               return true;
            }
         }
      }
      else
      {
         if(close > open)
         {
            obHigh = high;
            obLow = low;

            if(obHigh >= zoneLow && obLow <= zoneHigh)
            {
               obTime = iTime(_Symbol, tf, i);
               return true;
            }
         }
      }
   }

   return false;
}

bool D_IsFVGOBConditionOK(bool hasFVG, bool hasOB)
{
   if(D_InpRequireBothFVGOB)
      return hasFVG && hasOB;

   return hasFVG || hasOB;
}

//====================================================================
// 反発足判定
//====================================================================
bool D_RejectionCandle(ENUM_TIMEFRAMES tf, bool buy, double zoneHigh, double zoneLow)
{
   if(!D_InpUseRejectionCandle)
      return true;

   double open = iOpen(_Symbol, tf, 1);
   double close = iClose(_Symbol, tf, 1);
   double high = iHigh(_Symbol, tf, 1);
   double low = iLow(_Symbol, tf, 1);

   double body = MathAbs(close - open);

   if(body <= 0)
      body = _Point;

   if((body / D_Pip()) < D_InpMinBodyPips)
      return false;

   double upperWick = high - MathMax(open, close);
   double lowerWick = MathMin(open, close) - low;

   if(buy)
   {
      if(D_InpRequireCandleColor && close <= open)
         return false;

      if(lowerWick < body * D_InpWickRatio)
         return false;

      if(D_InpRequireCloseOutsideZone && close <= zoneHigh)
         return false;

      return true;
   }

   if(D_InpRequireCandleColor && close >= open)
      return false;

   if(upperWick < body * D_InpWickRatio)
      return false;

   if(D_InpRequireCloseOutsideZone && close >= zoneLow)
      return false;

   return true;
}

//====================================================================
// ロット計算
//====================================================================
double D_NormalizeVolume(double vol)
{
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   if(D_InpUseMaxLotLimit)
      maxLot = MathMin(maxLot, D_InpMaxLotPerTrade);

   if(vol < minLot)
      vol = minLot;

   if(vol > maxLot)
      vol = maxLot;

   vol = MathFloor(vol / step) * step;

   return NormalizeDouble(vol, 2);
}

double D_CalcLotByRisk(double riskPercent, double entry, double sl)
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskMoney = balance * riskPercent / 100.0;

   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

   double slDistance = MathAbs(entry - sl);

   if(slDistance <= 0 || tickValue <= 0 || tickSize <= 0)
      return 0.0;

   double lossPerLot = slDistance / tickSize * tickValue;

   if(lossPerLot <= 0)
      return 0.0;

   double lot = riskMoney / lossPerLot;

   return D_NormalizeVolume(lot);
}

bool D_IsSLWidthOK(double slPips)
{
   if(!D_InpUseSLWidthFilter)
      return true;

   if(slPips < D_InpMinSLPips)
      return false;

   if(slPips > D_InpMaxSLPips)
      return false;

   return true;
}

//====================================================================
// CHoCH検出
//====================================================================
void D_DetectCHoCHAndCreateSetup(D_TFInfo &info, int idx)
{
   if(D_Setups[idx].active)
      return;

   if(D_IsTradingPaused())
      return;

   if(!D_IsTradingTime())
      return;

   if(D_IsDailyLossStopHit())
      return;

   if(D_IsConsecutiveLossStopHit())
      return;

   D_SwingPoint lastHigh, lastLow;

   if(!D_FindRecentHighLow(info, lastHigh, lastLow))
      return;

   double close1 = iClose(_Symbol, info.tf, 1);
   double close2 = iClose(_Symbol, info.tf, 2);
   datetime barTime = iTime(_Symbol, info.tf, 1);

   if(D_InpBuyEnable)
   {
      if(close1 > lastHigh.price && close2 <= lastHigh.price)
      {
         double startPrice = lastLow.price;
         double extremePrice = iHigh(_Symbol, info.tf, 1);

         if((extremePrice - startPrice) / D_Pip() >= D_InpMinImpulsePips)
         {
            D_Setups[idx].active = true;
            D_Setups[idx].dir = 1;
            D_Setups[idx].locked = false;
            D_Setups[idx].chochTime = barTime;
            D_Setups[idx].startTime = lastLow.time;
            D_Setups[idx].extremeTime = barTime;
            D_Setups[idx].breakLevel = lastHigh.price;
            D_Setups[idx].startPrice = startPrice;
            D_Setups[idx].extremePrice = extremePrice;

            string base = "GD20_SETUP_" + D_TFName(info.tf) + "_" + TimeToString(TimeCurrent(), TIME_SECONDS);
            D_DrawLine(base + "_BUY_CHoCH", lastHigh.time, barTime, lastHigh.price);
         }
      }
   }

   if(D_InpSellEnable)
   {
      if(close1 < lastLow.price && close2 >= lastLow.price)
      {
         double startPrice = lastHigh.price;
         double extremePrice = iLow(_Symbol, info.tf, 1);

         if((startPrice - extremePrice) / D_Pip() >= D_InpMinImpulsePips)
         {
            D_Setups[idx].active = true;
            D_Setups[idx].dir = -1;
            D_Setups[idx].locked = false;
            D_Setups[idx].chochTime = barTime;
            D_Setups[idx].startTime = lastHigh.time;
            D_Setups[idx].extremeTime = barTime;
            D_Setups[idx].breakLevel = lastLow.price;
            D_Setups[idx].startPrice = startPrice;
            D_Setups[idx].extremePrice = extremePrice;

            string base = "GD20_SETUP_" + D_TFName(info.tf) + "_" + TimeToString(TimeCurrent(), TIME_SECONDS);
            D_DrawLine(base + "_SELL_CHoCH", lastLow.time, barTime, lastLow.price);
         }
      }
   }
}

//====================================================================
// セットアップ更新
//====================================================================
void D_UpdateSetupExtreme(D_TFInfo &info, int idx)
{
   if(!D_Setups[idx].active)
      return;

   int barsPassed = iBarShift(_Symbol, info.tf, D_Setups[idx].chochTime);

   if(barsPassed < 0 || barsPassed > D_InpSetupExpiryBars)
   {
      D_ResetSetup(idx);
      return;
   }

   double high1 = iHigh(_Symbol, info.tf, 1);
   double low1  = iLow(_Symbol, info.tf, 1);

   if(D_Setups[idx].dir == 1)
   {
      double fibUpper = D_Setups[idx].extremePrice -
                        (D_Setups[idx].extremePrice - D_Setups[idx].startPrice) *
                        (D_InpBuyFibEntryUpper / 100.0);

      if(low1 <= fibUpper)
         D_Setups[idx].locked = true;

      if(!D_Setups[idx].locked && high1 > D_Setups[idx].extremePrice)
      {
         D_Setups[idx].extremePrice = high1;
         D_Setups[idx].extremeTime = iTime(_Symbol, info.tf, 1);
      }
   }

   if(D_Setups[idx].dir == -1)
   {
      double fibUpper = D_Setups[idx].extremePrice +
                        (D_Setups[idx].startPrice - D_Setups[idx].extremePrice) *
                        (D_InpSellFibEntryUpper / 100.0);

      if(high1 >= fibUpper)
         D_Setups[idx].locked = true;

      if(!D_Setups[idx].locked && low1 < D_Setups[idx].extremePrice)
      {
         D_Setups[idx].extremePrice = low1;
         D_Setups[idx].extremeTime = iTime(_Symbol, info.tf, 1);
      }
   }
}

//====================================================================
// エントリー判定
//====================================================================
void D_CheckEntryFromSetup(D_TFInfo &info, int idx)
{
   if(!D_Setups[idx].active)
      return;

   if(D_IsTradingPaused())
      return;

   if(!D_IsTradingTime())
      return;

   if(D_SpreadPips() > D_InpMaxSpreadPips)
      return;

   if(D_InpOnePositionPerTF && D_HasPositionByMagic(info.magic))
      return;

   double high1 = iHigh(_Symbol, info.tf, 1);
   double low1  = iLow(_Symbol, info.tf, 1);
   double close1 = iClose(_Symbol, info.tf, 1);
   datetime barTime = iTime(_Symbol, info.tf, 1);

   // BUY
   if(D_Setups[idx].dir == 1)
   {
      if(D_HasSameDirectionOtherTF(info.magic, POSITION_TYPE_BUY))
         return;

      double start = D_Setups[idx].startPrice;
      double top = D_Setups[idx].extremePrice;

      if(top <= start)
         return;

      double fibUpper = top - (top - start) * (D_InpBuyFibEntryUpper / 100.0);
      double fibLower = top - (top - start) * (D_InpBuyFibEntryLower / 100.0);
      double fibSL    = top - (top - start) * (D_InpBuyFibSLLevel / 100.0);

      double zoneHigh = MathMax(fibUpper, fibLower);
      double zoneLow  = MathMin(fibUpper, fibLower);

      bool touched = low1 <= zoneHigh && high1 >= zoneLow;

      if(D_InpRequirePullbackClose)
         touched = close1 <= zoneHigh && close1 >= zoneLow;

      if(!touched)
         return;

      double fvgH = 0, fvgL = 0, obH = 0, obL = 0;
      datetime fvgT = 0, obT = 0;

      bool hasFVG = D_InpUseFVG && D_FindFVG(info.tf, true, zoneHigh, zoneLow, fvgH, fvgL, fvgT);
      bool hasOB  = D_InpUseOB  && D_FindOB(info.tf, true, zoneHigh, zoneLow, obH, obL, obT);

      if(!D_IsFVGOBConditionOK(hasFVG, hasOB))
         return;

      if(!D_RejectionCandle(info.tf, true, zoneHigh, zoneLow))
         return;

      double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double sl = fibSL - D_PipsToPrice(D_InpSLBufferPips);
      double riskDist = entry - sl;

      if(riskDist <= 0)
         return;

      double slPips = riskDist / D_Pip();

      if(!D_IsSLWidthOK(slPips))
         return;

      double tp = entry + riskDist * D_InpTP_RR;
      double lot = D_CalcLotByRisk(info.risk, entry, sl);

      if(lot <= 0)
         return;

      if(!D_RiskGuardAllowsNewTrade(entry, sl, lot))
         return;

      trade.SetExpertMagicNumber(info.magic);
      trade.SetDeviationInPoints(D_InpSlippagePoints);

      if(trade.Buy(lot, _Symbol, 0.0, D_NormalizePrice(sl), D_NormalizePrice(tp), "BUY " + D_TFName(info.tf)))
      {
         string base = "GD20_ENTRY_" + D_TFName(info.tf) + "_" + TimeToString(TimeCurrent(), TIME_SECONDS);

         D_DrawArrow(base + "_BUY", barTime, entry, true);
         D_DrawFibo(base + "_FIB", D_Setups[idx].startTime, start, D_Setups[idx].extremeTime, top, true);

         if(hasFVG)
            D_DrawZone(base + "_FVG", fvgT, barTime, fvgH, fvgL);

         if(hasOB)
            D_DrawZone(base + "_OB", obT, barTime, obH, obL);

         D_ResetSetup(idx);
      }
   }

   // SELL
   if(D_Setups[idx].dir == -1)
   {
      if(D_HasSameDirectionOtherTF(info.magic, POSITION_TYPE_SELL))
         return;

      double start = D_Setups[idx].startPrice;
      double bottom = D_Setups[idx].extremePrice;

      if(start <= bottom)
         return;

      double fibUpper = bottom + (start - bottom) * (D_InpSellFibEntryUpper / 100.0);
      double fibLower = bottom + (start - bottom) * (D_InpSellFibEntryLower / 100.0);
      double fibSL    = bottom + (start - bottom) * (D_InpSellFibSLLevel / 100.0);

      double zoneLow  = MathMin(fibUpper, fibLower);
      double zoneHigh = MathMax(fibUpper, fibLower);

      bool touched = high1 >= zoneLow && low1 <= zoneHigh;

      if(D_InpRequirePullbackClose)
         touched = close1 >= zoneLow && close1 <= zoneHigh;

      if(!touched)
         return;

      double fvgH = 0, fvgL = 0, obH = 0, obL = 0;
      datetime fvgT = 0, obT = 0;

      bool hasFVG = D_InpUseFVG && D_FindFVG(info.tf, false, zoneHigh, zoneLow, fvgH, fvgL, fvgT);
      bool hasOB  = D_InpUseOB  && D_FindOB(info.tf, false, zoneHigh, zoneLow, obH, obL, obT);

      if(!D_IsFVGOBConditionOK(hasFVG, hasOB))
         return;

      if(!D_RejectionCandle(info.tf, false, zoneHigh, zoneLow))
         return;

      double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double sl = fibSL + D_PipsToPrice(D_InpSLBufferPips);
      double riskDist = sl - entry;

      if(riskDist <= 0)
         return;

      double slPips = riskDist / D_Pip();

      if(!D_IsSLWidthOK(slPips))
         return;

      double tp = entry - riskDist * D_InpTP_RR;
      double lot = D_CalcLotByRisk(info.risk, entry, sl);

      if(lot <= 0)
         return;

      if(!D_RiskGuardAllowsNewTrade(entry, sl, lot))
         return;

      trade.SetExpertMagicNumber(info.magic);
      trade.SetDeviationInPoints(D_InpSlippagePoints);

      if(trade.Sell(lot, _Symbol, 0.0, D_NormalizePrice(sl), D_NormalizePrice(tp), "SELL " + D_TFName(info.tf)))
      {
         string base = "GD20_ENTRY_" + D_TFName(info.tf) + "_" + TimeToString(TimeCurrent(), TIME_SECONDS);

         D_DrawArrow(base + "_SELL", barTime, entry, false);
         D_DrawFibo(base + "_FIB", D_Setups[idx].startTime, start, D_Setups[idx].extremeTime, bottom, false);

         if(hasFVG)
            D_DrawZone(base + "_FVG", fvgT, barTime, fvgH, fvgL);

         if(hasOB)
            D_DrawZone(base + "_OB", obT, barTime, obH, obL);

         D_ResetSetup(idx);
      }
   }
}

//====================================================================
// ポジション管理
//====================================================================
void D_ManagePositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);

      if(!PositionSelectByTicket(ticket))
         continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      int magic = (int)PositionGetInteger(POSITION_MAGIC);

      if(!D_IsOurMagic(magic))
         continue;

      long type = PositionGetInteger(POSITION_TYPE);
      double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);
      double volume = PositionGetDouble(POSITION_VOLUME);

      if(tp <= 0 || sl <= 0)
         continue;

      double price = type == POSITION_TYPE_BUY
         ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
         : SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      double initialRisk = MathAbs(tp - entry) / D_InpTP_RR;

      if(initialRisk <= 0)
         continue;

      double profitDist = type == POSITION_TYPE_BUY
         ? price - entry
         : entry - price;

      double rr = profitDist / initialRisk;

      string key1  = "GD20_TP1_"  + IntegerToString((long)ticket);
      string key15 = "GD20_TP15_" + IntegerToString((long)ticket);

      if(!GlobalVariableCheck(key1))
         GlobalVariableSet(key1, 0);

      if(!GlobalVariableCheck(key15))
         GlobalVariableSet(key15, 0);

      if(D_InpUsePartialTakeProfit && rr >= D_InpPartialRR && GlobalVariableGet(key1) == 0)
      {
         double closeVol = volume * D_InpPartialClosePercent / 100.0;
         closeVol = D_NormalizeVolume(closeVol);

         double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

         if(closeVol >= minLot && closeVol < volume)
            trade.PositionClosePartial(ticket, closeVol);

         double newSL;

         if(type == POSITION_TYPE_BUY)
            newSL = entry + D_PipsToPrice(D_InpMoveSLPlusPips);
         else
            newSL = entry - D_PipsToPrice(D_InpMoveSLPlusPips);

         trade.PositionModify(ticket, D_NormalizePrice(newSL), tp);
         GlobalVariableSet(key1, 1);
      }

      if(D_InpUseSecondSLMove && rr >= D_InpSecondLockRR && GlobalVariableGet(key15) == 0)
      {
         double newSL;

         if(type == POSITION_TYPE_BUY)
            newSL = entry + initialRisk * D_InpSecondSL_RR;
         else
            newSL = entry - initialRisk * D_InpSecondSL_RR;

         bool improve = false;

         if(type == POSITION_TYPE_BUY && newSL > sl)
            improve = true;

         if(type == POSITION_TYPE_SELL && newSL < sl)
            improve = true;

         if(improve)
            trade.PositionModify(ticket, D_NormalizePrice(newSL), tp);

         GlobalVariableSet(key15, 1);
      }

      if(D_InpUseZigZagTrailing && GlobalVariableGet(key15) == 1)
      {
         ENUM_TIMEFRAMES tf = PERIOD_M15;
         int zzHandle = INVALID_HANDLE;

         for(int k = 0; k < 5; k++)
         {
            if(D_TFs[k].magic == magic)
            {
               tf = D_TFs[k].tf;
               zzHandle = D_TFs[k].zzHandle;
               break;
            }
         }

         if(zzHandle != INVALID_HANDLE)
         {
            D_TFInfo temp;
            temp.tf = tf;
            temp.zzHandle = zzHandle;

            D_SwingPoint s1, s2, s3, s4, s5, s6;

            if(D_GetLastSwings(temp, s1, s2, s3, s4, s5, s6))
            {
               if(type == POSITION_TYPE_BUY)
               {
                  double lastLow = 0;

                  if(!s1.isHigh)
                     lastLow = s1.price;
                  else if(!s2.isHigh)
                     lastLow = s2.price;
                  else if(!s3.isHigh)
                     lastLow = s3.price;

                  if(lastLow > 0)
                  {
                     double newSL = lastLow - D_PipsToPrice(D_InpTrailBufferPips);

                     if(newSL > sl && newSL < price)
                        trade.PositionModify(ticket, D_NormalizePrice(newSL), tp);
                  }
               }
               else
               {
                  double lastHigh = 0;

                  if(s1.isHigh)
                     lastHigh = s1.price;
                  else if(s2.isHigh)
                     lastHigh = s2.price;
                  else if(s3.isHigh)
                     lastHigh = s3.price;

                  if(lastHigh > 0)
                  {
                     double newSL = lastHigh + D_PipsToPrice(D_InpTrailBufferPips);

                     if(newSL < sl && newSL > price)
                        trade.PositionModify(ticket, D_NormalizePrice(newSL), tp);
                  }
               }
            }
         }
      }
   }
}

//====================================================================
// 初期化
//====================================================================
int D_OnInit()
{
   D_TFs[0].tf = PERIOD_M10;
   D_TFs[0].enable = D_InpUseM10;
   D_TFs[0].magic = D_InpMagic_M10;
   D_TFs[0].risk = D_InpRiskPercent_M10;
   D_TFs[0].lastBarTime = 0;

   D_TFs[1].tf = PERIOD_M15;
   D_TFs[1].enable = D_InpUseM15;
   D_TFs[1].magic = D_InpMagic_M15;
   D_TFs[1].risk = D_InpRiskPercent_M15;
   D_TFs[1].lastBarTime = 0;

   D_TFs[2].tf = PERIOD_M30;
   D_TFs[2].enable = D_InpUseM30;
   D_TFs[2].magic = D_InpMagic_M30;
   D_TFs[2].risk = D_InpRiskPercent_M30;
   D_TFs[2].lastBarTime = 0;

   D_TFs[3].tf = PERIOD_H1;
   D_TFs[3].enable = D_InpUseH1;
   D_TFs[3].magic = D_InpMagic_H1;
   D_TFs[3].risk = D_InpRiskPercent_H1;
   D_TFs[3].lastBarTime = 0;

   D_TFs[4].tf = PERIOD_H4;
   D_TFs[4].enable = D_InpUseH4;
   D_TFs[4].magic = D_InpMagic_H4;
   D_TFs[4].risk = D_InpRiskPercent_H4;
   D_TFs[4].lastBarTime = 0;

   for(int i = 0; i < 5; i++)
   {
      D_ResetSetup(i);

      D_TFs[i].zzHandle = iCustom(_Symbol,
                                D_TFs[i].tf,
                                "Examples\\ZigZag",
                                D_InpZZDepth,
                                D_InpZZDeviation,
                                D_InpZZBackstep);

      if(D_TFs[i].zzHandle == INVALID_HANDLE)
      {
         Print("ZigZag handle error: ", D_TFName(D_TFs[i].tf));
         return INIT_FAILED;
      }
   }

   D_UpdateDailyBaseEquity();

   Print("Gold Du V2.0 started / M5 removed / M10-M15-M30-H1-H4 / Risk 0.5%");
   return INIT_SUCCEEDED;
}

//====================================================================
// 終了処理
//====================================================================
void D_OnDeinit(const int reason)
{
   for(int i = 0; i < 5; i++)
   {
      if(D_TFs[i].zzHandle != INVALID_HANDLE)
         IndicatorRelease(D_TFs[i].zzHandle);
   }
}

//====================================================================
// メイン
//====================================================================
void D_OnTick()
{
   D_UpdateDailyBaseEquity();

   // 時間外・停止中でもポジション管理は動かす
   D_ManagePositions();

   for(int i = 0; i < 5; i++)
   {
      if(!D_TFs[i].enable)
         continue;

      if(D_IsNewBar(D_TFs[i]))
      {
         D_UpdateSetupExtreme(D_TFs[i], i);
         D_CheckEntryFromSetup(D_TFs[i], i);
         D_DetectCHoCHAndCreateSetup(D_TFs[i], i);
      }
   }
}
//+------------------------------------------------------------------+

//====================================================================
// EA②: BUY回転型 + SELLスナイパー型 Portfolio  ※元ロジック維持
//====================================================================
//==================================================
// Inputs
//==================================================
//==================== BUY側パラメータ ====================//
input int    InpMagicNumber               = 20260421;   // BUY専用マジックナンバー
input double InpBuyLots                   = 0.01;       // BUY/SELL初回・ナンピンの基本ロット（自動ロットOFF時）

input double InpMinConfluence             = 1.5;        // BUYエントリー最低合流スコア（FVG/OB=1.0、SMA/Pivot=0.5）
input int    InpTP_Pips                   = 15;         // BUY/SELL利確幅(pips)（通貨版初期値）
input int    InpSL_Pips                   = 20;         // BUY/SELL損切り幅(pips)（通貨版初期値）

input int    InpNanpinStepPips            = 12;         // BUY/SELLナンピン間隔(pips) ※初期OFF
input int    InpMaxNanpinCount            = 0;          // BUY/SELL最大ナンピン回数（通貨版V1はOFF）

input ENUM_TIMEFRAMES InpZoneTF           = PERIOD_H1;  // BUYゾーン検出時間足
input int    InpZoneLookbackBars          = 30;         // BUYゾーン探索本数
input int    InpMaxStoredFVG              = 20;         // BUY保存するFVG最大数
input int    InpSwingStrength             = 3;          // BUYスイング判定強度
input double InpOB_MinBodyPips            = 2.0;        // BUY/SELL OB判定の最小実体(pips)（通貨版）
input double InpTouchTolerancePips        = 3.0;        // BUY/SELLゾーンタッチ許容幅(pips)（通貨版）
input bool   InpOneEntryPerBar            = true;       // BUY 1バー1回のみエントリー

input bool   InpAllowBuy                  = true;       // BUYエントリー許可
input bool   InpAllowSell                 = true;       // BUY側SELLエントリー許可（通貨版では復活テスト）

input bool   InpUseBuyTrendFilter         = true;       // BUYトレンドフィルター使用（通貨版初期ON）
input bool   InpUseSellTrendFilter        = true;       // BUY側SELLトレンドフィルター使用

input bool   InpUsePullbackEntry          = false;      // BUY押し戻りエントリー使用
input int    InpPullbackEntryPips         = 5;          // BUY/SELL押し戻り待ち幅(pips)（使用時）
input int    InpSignalExpireBars          = 5;          // BUYシグナル有効期限(本)

input int    InpBETriggerPips             = 8;          // BUY/SELL建値移動開始(pips)（通貨版）
input int    InpBEOffsetPips              = 1;          // BUY/SELL建値移動後の利益確保(pips)（通貨版）
input int    InpPartialTriggerPips        = 10;         // BUY/SELL部分利確開始(pips)（通貨版）
input int    InpPartialSLPips             = 5;          // BUY/SELL部分利確後SL位置(pips)（通貨版）
input double InpPartialClosePercent       = 50.0;       // BUY/SELL部分利確割合(%)（通貨版）

input bool   InpUseMaxHoldBars            = true;       // BUY/SELL最大保有バー数決済を使用（通貨版V1.2）
input int    InpMaxHoldBars               = 24;         // BUY/SELL最大保有バー数（M15で24本=約6時間）

input bool   InpUseTimeFilter             = true;       // BUY時間帯フィルター使用
input int    InpSession1StartHour         = 15;         // BUY時間帯1 開始時刻
input int    InpSession1EndHour           = 21;         // BUY時間帯1 終了時刻
input int    InpSession2StartHour         = 21;         // BUY時間帯2 開始時刻
input int    InpSession2EndHour           = 3;          // BUY時間帯2 終了時刻（日跨ぎOK）

input bool   InpUseSpreadFilter           = true;       // BUY/SELLスプレッドフィルター使用（通貨版）
input double InpMaxSpreadPips             = 2.0;        // BUY最大スプレッド(pips)

input bool   InpUseAutoLot                = true;      // BUY自動ロット使用
input double InpRiskPercentPerTrade       = 0.25;       // BUY/SELL自動ロット時の1回あたりリスク(%)（通貨版）
input double InpFixedLotFallback          = 0.01;       // BUY/SELL自動ロット計算失敗時の予備ロット（通貨版）
input double InpMinLot                    = 0.01;       // BUY最小ロット
input double InpMaxLot                    = 0.10;       // BUY/SELL最大ロット（通貨版初期値）

input double InpMaxTotalLotsPerCycle      = 0.10;       // BUY/SELL 1サイクル最大合計ロット（通貨版初期値）
input double InpMaxCycleRiskPercent       = 1.0;        // BUY/SELL 1サイクル最大リスク(%)（通貨版）

//==================== 共通資金管理・停止フィルター ====================//
input bool   InpUseMasterRiskFilter       = true;       // 共通資金管理フィルター使用
input int    InpMasterStopLosses          = 2;          // 共通：〇連敗で新規停止（通貨版）
input int    InpMasterStopDays            = 1;          // 共通：停止日数
input double InpMaxDrawdownPercent        = 5.0;        // 共通：最大DD停止(%)（通貨版）
input bool   InpClosePositionsOnDDStop    = false;      // 共通：DD停止時に全ポジション決済する
input bool   InpResetRiskStateOnInit      = true;       // 共通：起動時に停止状態/ピーク残高をリセット（バックテスト向け）

input bool   InpEnableDebugLog            = true;       // BUYデバッグログ表示

//==================================================
// Structs
//==================================================
struct FVGZone
{
   double low;
   double high;
   bool bullish;
   datetime timeStart;
};

struct OBZone
{
   double low;
   double high;
   bool bullish;
   datetime timeStart;
   bool valid;
};

struct SwingPoint
{
   double price;
   int shift;
   datetime time;
};

struct PivotLevels
{
   double pp;
   double r1, r2, r3, r4;
   double s1, s2, s3, s4;
   bool valid;
};

struct CacheData
{
   FVGZone bullFVGs[];
   FVGZone bearFVGs[];
   OBZone  bullOB;
   OBZone  bearOB;
   PivotLevels dailyPivots;
   PivotLevels weeklyPivots;
};

//==================================================
// Globals
//==================================================
datetime g_lastChartBarTime = 0;
datetime g_lastZoneBarTime  = 0;

bool     g_cycleActive       = false;
int      g_cycleDirection    = 0;
double   g_initialEntryPrice = 0.0;
double   g_fixedTPPrice      = 0.0;
double   g_fixedSLPrice      = 0.0;
int      g_nanpinCount       = 0;
double   g_initialLot        = 0.0;
bool     g_breakEvenDone     = false;
bool     g_partialDone       = false;

CacheData g_cache;

bool     g_pendingBuy        = false;
bool     g_pendingSell       = false;
double   g_pendingBuyPrice   = 0.0;
double   g_pendingSellPrice  = 0.0;
int      g_pendingBuyBars    = 0;
int      g_pendingSellBars   = 0;

int g_maM15_20  = INVALID_HANDLE;
int g_maM15_50  = INVALID_HANDLE;
int g_maM15_200 = INVALID_HANDLE;

int g_maH1_20   = INVALID_HANDLE;
int g_maH1_50   = INVALID_HANDLE;
int g_maH1_200  = INVALID_HANDLE;

int g_maH4_20   = INVALID_HANDLE;
int g_maH4_50   = INVALID_HANDLE;
int g_maH4_200  = INVALID_HANDLE;

int g_maD1_20   = INVALID_HANDLE;
int g_maD1_50   = INVALID_HANDLE;
int g_maD1_200  = INVALID_HANDLE;

//==================================================
// Utils
//==================================================
void DebugLog(string msg)
{
   if(InpEnableDebugLog)
      Print("[BUY_SELL_PORTFOLIO_JP] ", msg);
}

double PipSize()
{
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(digits == 3 || digits == 5)
      return _Point * 10.0;
   return _Point;
}

double EffectivePips(double pips)
{
   // 通貨版V1では入力値をそのまま一般的なFXのpipsとして扱う。
   // 例: EURUSD 1pip=0.0001, USDJPY 1pip=0.01。
   // 元Gold版のEA②はここで10倍補正していたため、通貨版では無効化。
   return pips;
}

double PipsToPrice(double pips)
{
   return EffectivePips(pips) * PipSize();
}

double NormalizePrice(double price)
{
   return NormalizeDouble(price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
}

double CurrentMidPrice()
{
   return (SymbolInfoDouble(_Symbol, SYMBOL_BID) + SymbolInfoDouble(_Symbol, SYMBOL_ASK)) / 2.0;
}

double CurrentSpreadPips()
{
   return (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID)) / PipsToPrice(1.0);
}

bool IsInsideZone(double price, double low, double high)
{
   return price >= low && price <= high;
}

bool IsNearLevel(double price, double level, double tolerancePips)
{
   return MathAbs(price - level) <= PipsToPrice(tolerancePips);
}

bool IsNewChartBar()
{
   datetime t = iTime(_Symbol, _Period, 0);
   if(t != g_lastChartBarTime)
   {
      g_lastChartBarTime = t;
      return true;
   }
   return false;
}

bool IsNewZoneBar()
{
   datetime t = iTime(_Symbol, InpZoneTF, 0);
   if(t != g_lastZoneBarTime)
   {
      g_lastZoneBarTime = t;
      return true;
   }
   return false;
}

double CandleBodyPips(ENUM_TIMEFRAMES tf, int shift)
{
   return MathAbs(iClose(_Symbol, tf, shift) - iOpen(_Symbol, tf, shift)) / PipsToPrice(1.0);
}

//==================================================
// Time / Spread
//==================================================
bool IsHourInRange(int hour, int startHour, int endHour)
{
   if(startHour == endHour)
      return true;

   if(startHour < endHour)
      return hour >= startHour && hour < endHour;

   return hour >= startHour || hour < endHour;
}

bool IsTradingHourAllowed()
{
   if(!InpUseTimeFilter)
      return true;

   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);

   return IsHourInRange(tm.hour, InpSession1StartHour, InpSession1EndHour)
       || IsHourInRange(tm.hour, InpSession2StartHour, InpSession2EndHour);
}

bool IsSpreadAllowed()
{
   if(!InpUseSpreadFilter)
      return true;

   return CurrentSpreadPips() <= InpMaxSpreadPips;
}

//==================================================
// MA
//==================================================
bool CreateMAHandle(int &handle, ENUM_TIMEFRAMES tf, int period)
{
   handle = iMA(_Symbol, tf, period, 0, MODE_SMA, PRICE_CLOSE);
   return handle != INVALID_HANDLE;
}

void ReleaseMAHandle(int &handle)
{
   if(handle != INVALID_HANDLE)
   {
      IndicatorRelease(handle);
      handle = INVALID_HANDLE;
   }
}

bool InitMAHandles()
{
   bool ok = true;

   if(!CreateMAHandle(g_maM15_20,  PERIOD_M15, 20))  ok = false;
   if(!CreateMAHandle(g_maM15_50,  PERIOD_M15, 50))  ok = false;
   if(!CreateMAHandle(g_maM15_200, PERIOD_M15, 200)) ok = false;

   if(!CreateMAHandle(g_maH1_20,   PERIOD_H1, 20))   ok = false;
   if(!CreateMAHandle(g_maH1_50,   PERIOD_H1, 50))   ok = false;
   if(!CreateMAHandle(g_maH1_200,  PERIOD_H1, 200))  ok = false;

   if(!CreateMAHandle(g_maH4_20,   PERIOD_H4, 20))   ok = false;
   if(!CreateMAHandle(g_maH4_50,   PERIOD_H4, 50))   ok = false;
   if(!CreateMAHandle(g_maH4_200,  PERIOD_H4, 200))  ok = false;

   if(!CreateMAHandle(g_maD1_20,   PERIOD_D1, 20))   ok = false;
   if(!CreateMAHandle(g_maD1_50,   PERIOD_D1, 50))   ok = false;
   if(!CreateMAHandle(g_maD1_200,  PERIOD_D1, 200))  ok = false;

   return ok;
}

void ReleaseAllMAHandles()
{
   ReleaseMAHandle(g_maM15_20);
   ReleaseMAHandle(g_maM15_50);
   ReleaseMAHandle(g_maM15_200);

   ReleaseMAHandle(g_maH1_20);
   ReleaseMAHandle(g_maH1_50);
   ReleaseMAHandle(g_maH1_200);

   ReleaseMAHandle(g_maH4_20);
   ReleaseMAHandle(g_maH4_50);
   ReleaseMAHandle(g_maH4_200);

   ReleaseMAHandle(g_maD1_20);
   ReleaseMAHandle(g_maD1_50);
   ReleaseMAHandle(g_maD1_200);
}

bool ReadMA(int handle, int shift, double &value)
{
   if(handle == INVALID_HANDLE)
      return false;

   double buf[];
   ArraySetAsSeries(buf, true);

   if(CopyBuffer(handle, 0, shift, 1, buf) < 1)
      return false;

   value = buf[0];
   return true;
}

int CountSMATouches(double price)
{
   int count = 0;
   double ma = 0.0;

   if(ReadMA(g_maM15_20, 0, ma)  && IsNearLevel(price, ma, InpTouchTolerancePips)) count++;
   if(ReadMA(g_maM15_50, 0, ma)  && IsNearLevel(price, ma, InpTouchTolerancePips)) count++;
   if(ReadMA(g_maM15_200, 0, ma) && IsNearLevel(price, ma, InpTouchTolerancePips)) count++;

   if(ReadMA(g_maH1_20, 0, ma)   && IsNearLevel(price, ma, InpTouchTolerancePips)) count++;
   if(ReadMA(g_maH1_50, 0, ma)   && IsNearLevel(price, ma, InpTouchTolerancePips)) count++;
   if(ReadMA(g_maH1_200, 0, ma)  && IsNearLevel(price, ma, InpTouchTolerancePips)) count++;

   if(ReadMA(g_maH4_20, 0, ma)   && IsNearLevel(price, ma, InpTouchTolerancePips)) count++;
   if(ReadMA(g_maH4_50, 0, ma)   && IsNearLevel(price, ma, InpTouchTolerancePips)) count++;
   if(ReadMA(g_maH4_200, 0, ma)  && IsNearLevel(price, ma, InpTouchTolerancePips)) count++;

   if(ReadMA(g_maD1_20, 0, ma)   && IsNearLevel(price, ma, InpTouchTolerancePips)) count++;
   if(ReadMA(g_maD1_50, 0, ma)   && IsNearLevel(price, ma, InpTouchTolerancePips)) count++;
   if(ReadMA(g_maD1_200, 0, ma)  && IsNearLevel(price, ma, InpTouchTolerancePips)) count++;

   return count;
}

//==================================================
// Trend Filter
//==================================================
bool IsBuyTrendAllowed()
{
   if(!InpUseBuyTrendFilter)
      return true;

   double h1_20 = 0.0;
   double h1_50 = 0.0;
   double h1_200 = 0.0;

   if(!ReadMA(g_maH1_20, 1, h1_20))   return false;
   if(!ReadMA(g_maH1_50, 1, h1_50))   return false;
   if(!ReadMA(g_maH1_200, 1, h1_200)) return false;

   double h1Close = iClose(_Symbol, PERIOD_H1, 1);
   if(h1Close <= 0.0)
      return false;

   return h1_20 > h1_50 && h1Close > h1_200;
}

bool IsSellTrendAllowed()
{
   if(!InpUseSellTrendFilter)
      return true;

   double h1_20 = 0.0;
   double h1_50 = 0.0;
   double h1_200 = 0.0;

   if(!ReadMA(g_maH1_20, 1, h1_20))   return false;
   if(!ReadMA(g_maH1_50, 1, h1_50))   return false;
   if(!ReadMA(g_maH1_200, 1, h1_200)) return false;

   double h1Close = iClose(_Symbol, PERIOD_H1, 1);
   if(h1Close <= 0.0)
      return false;

   return h1_20 < h1_50 && h1Close < h1_200;
}

//==================================================
// Pivots
//==================================================
PivotLevels CalcPivots(ENUM_TIMEFRAMES tf)
{
   PivotLevels p;
   p.valid = false;

   double high  = iHigh(_Symbol, tf, 1);
   double low   = iLow(_Symbol, tf, 1);
   double close = iClose(_Symbol, tf, 1);

   if(high <= 0 || low <= 0 || close <= 0)
      return p;

   double range = high - low;

   p.pp = (high + low + close) / 3.0;
   p.r1 = 2.0 * p.pp - low;
   p.s1 = 2.0 * p.pp - high;
   p.r2 = p.pp + range;
   p.s2 = p.pp - range;
   p.r3 = high + 2.0 * (p.pp - low);
   p.s3 = low  - 2.0 * (high - p.pp);
   p.r4 = p.r3 + range;
   p.s4 = p.s3 - range;

   p.valid = true;
   return p;
}

int CountPivotTouchesOne(double price, PivotLevels &p)
{
   if(!p.valid)
      return 0;

   int count = 0;

   if(IsNearLevel(price, p.pp, InpTouchTolerancePips)) count++;

   if(IsNearLevel(price, p.r1, InpTouchTolerancePips)) count++;
   if(IsNearLevel(price, p.r2, InpTouchTolerancePips)) count++;
   if(IsNearLevel(price, p.r3, InpTouchTolerancePips)) count++;
   if(IsNearLevel(price, p.r4, InpTouchTolerancePips)) count++;

   if(IsNearLevel(price, p.s1, InpTouchTolerancePips)) count++;
   if(IsNearLevel(price, p.s2, InpTouchTolerancePips)) count++;
   if(IsNearLevel(price, p.s3, InpTouchTolerancePips)) count++;
   if(IsNearLevel(price, p.s4, InpTouchTolerancePips)) count++;

   return count;
}

int CountAllPivotTouches(double price)
{
   return CountPivotTouchesOne(price, g_cache.dailyPivots)
        + CountPivotTouchesOne(price, g_cache.weeklyPivots);
}

//==================================================
// Structure
//==================================================
bool IsSwingHigh(ENUM_TIMEFRAMES tf, int shift, int strength)
{
   if(shift - strength < 0)
      return false;

   double candidate = iHigh(_Symbol, tf, shift);
   if(candidate == 0.0)
      return false;

   for(int i = 1; i <= strength; i++)
   {
      if(iHigh(_Symbol, tf, shift + i) >= candidate) return false;
      if(iHigh(_Symbol, tf, shift - i) > candidate)  return false;
   }

   return true;
}

bool IsSwingLow(ENUM_TIMEFRAMES tf, int shift, int strength)
{
   if(shift - strength < 0)
      return false;

   double candidate = iLow(_Symbol, tf, shift);
   if(candidate == 0.0)
      return false;

   for(int i = 1; i <= strength; i++)
   {
      if(iLow(_Symbol, tf, shift + i) <= candidate) return false;
      if(iLow(_Symbol, tf, shift - i) < candidate)  return false;
   }

   return true;
}

bool GetLatestTwoSwingHighs(ENUM_TIMEFRAMES tf, int lookback, int strength, SwingPoint &latest, SwingPoint &previous)
{
   bool f1 = false;
   bool f2 = false;

   for(int shift = strength + 2; shift <= lookback; shift++)
   {
      if(IsSwingHigh(tf, shift, strength))
      {
         if(!f1)
         {
            latest.price = iHigh(_Symbol, tf, shift);
            latest.shift = shift;
            latest.time  = iTime(_Symbol, tf, shift);
            f1 = true;
         }
         else
         {
            previous.price = iHigh(_Symbol, tf, shift);
            previous.shift = shift;
            previous.time  = iTime(_Symbol, tf, shift);
            f2 = true;
            break;
         }
      }
   }

   return f1 && f2;
}

bool GetLatestTwoSwingLows(ENUM_TIMEFRAMES tf, int lookback, int strength, SwingPoint &latest, SwingPoint &previous)
{
   bool f1 = false;
   bool f2 = false;

   for(int shift = strength + 2; shift <= lookback; shift++)
   {
      if(IsSwingLow(tf, shift, strength))
      {
         if(!f1)
         {
            latest.price = iLow(_Symbol, tf, shift);
            latest.shift = shift;
            latest.time  = iTime(_Symbol, tf, shift);
            f1 = true;
         }
         else
         {
            previous.price = iLow(_Symbol, tf, shift);
            previous.shift = shift;
            previous.time  = iTime(_Symbol, tf, shift);
            f2 = true;
            break;
         }
      }
   }

   return f1 && f2;
}

bool HasBullishBreakNow()
{
   SwingPoint h1, h2;
   if(!GetLatestTwoSwingHighs(InpZoneTF, InpZoneLookbackBars, InpSwingStrength, h1, h2))
      return false;

   return iClose(_Symbol, InpZoneTF, 1) > h1.price;
}

bool HasBearishBreakNow()
{
   SwingPoint l1, l2;
   if(!GetLatestTwoSwingLows(InpZoneTF, InpZoneLookbackBars, InpSwingStrength, l1, l2))
      return false;

   return iClose(_Symbol, InpZoneTF, 1) < l1.price;
}

//==================================================
// FVG
//==================================================
void CollectFVGZones(FVGZone &zones[], bool bullish)
{
   ArrayResize(zones, 0);

   for(int shift = 1; shift <= InpZoneLookbackBars; shift++)
   {
      double zoneLow = 0.0;
      double zoneHigh = 0.0;
      bool found = false;

      if(bullish)
      {
         double newerLow  = iLow(_Symbol, InpZoneTF, shift);
         double olderHigh = iHigh(_Symbol, InpZoneTF, shift + 2);

         if(newerLow > olderHigh)
         {
            zoneLow = olderHigh;
            zoneHigh = newerLow;
            found = true;
         }
      }
      else
      {
         double newerHigh = iHigh(_Symbol, InpZoneTF, shift);
         double olderLow  = iLow(_Symbol, InpZoneTF, shift + 2);

         if(newerHigh < olderLow)
         {
            zoneLow = newerHigh;
            zoneHigh = olderLow;
            found = true;
         }
      }

      if(!found)
         continue;

      double mid = (zoneLow + zoneHigh) / 2.0;
      bool mitigated = false;

      for(int k = shift - 1; k >= 0; k--)
      {
         if(bullish && iLow(_Symbol, InpZoneTF, k) <= mid)
         {
            mitigated = true;
            break;
         }

         if(!bullish && iHigh(_Symbol, InpZoneTF, k) >= mid)
         {
            mitigated = true;
            break;
         }
      }

      if(mitigated)
         continue;

      FVGZone z;
      z.low = zoneLow;
      z.high = zoneHigh;
      z.bullish = bullish;
      z.timeStart = iTime(_Symbol, InpZoneTF, shift + 2);

      int sz = ArraySize(zones);
      ArrayResize(zones, sz + 1);
      zones[sz] = z;

      if(ArraySize(zones) >= InpMaxStoredFVG)
         break;
   }
}

int CountFVGHits(double price, FVGZone &zones[])
{
   int hits = 0;

   for(int i = 0; i < ArraySize(zones); i++)
   {
      if(IsInsideZone(price, zones[i].low, zones[i].high))
         hits++;
   }

   return hits;
}

//==================================================
// OB
//==================================================
OBZone FindBullishOB()
{
   OBZone z;
   z.valid = false;

   if(!HasBullishBreakNow())
      return z;

   for(int shift = 2; shift <= InpZoneLookbackBars; shift++)
   {
      double o1 = iOpen(_Symbol, InpZoneTF, shift);
      double c1 = iClose(_Symbol, InpZoneTF, shift);
      double h1 = iHigh(_Symbol, InpZoneTF, shift);
      double l1 = iLow(_Symbol, InpZoneTF, shift);

      double o0 = iOpen(_Symbol, InpZoneTF, shift - 1);
      double c0 = iClose(_Symbol, InpZoneTF, shift - 1);

      bool bearishCandle = c1 < o1;
      bool nextBullish   = c0 > o0;
      bool strongBody    = CandleBodyPips(InpZoneTF, shift - 1) >= InpOB_MinBodyPips;
      bool displaced     = c0 > h1;

      if(!(bearishCandle && nextBullish && strongBody && displaced))
         continue;

      double mid = (l1 + h1) / 2.0;
      bool mitigated = false;

      for(int k = shift - 1; k >= 0; k--)
      {
         if(iLow(_Symbol, InpZoneTF, k) <= mid)
         {
            mitigated = true;
            break;
         }
      }

      if(mitigated)
         continue;

      z.low = l1;
      z.high = h1;
      z.bullish = true;
      z.timeStart = iTime(_Symbol, InpZoneTF, shift);
      z.valid = true;
      return z;
   }

   return z;
}

OBZone FindBearishOB()
{
   OBZone z;
   z.valid = false;

   if(!HasBearishBreakNow())
      return z;

   for(int shift = 2; shift <= InpZoneLookbackBars; shift++)
   {
      double o1 = iOpen(_Symbol, InpZoneTF, shift);
      double c1 = iClose(_Symbol, InpZoneTF, shift);
      double h1 = iHigh(_Symbol, InpZoneTF, shift);
      double l1 = iLow(_Symbol, InpZoneTF, shift);

      double o0 = iOpen(_Symbol, InpZoneTF, shift - 1);
      double c0 = iClose(_Symbol, InpZoneTF, shift - 1);

      bool bullishCandle = c1 > o1;
      bool nextBearish   = c0 < o0;
      bool strongBody    = CandleBodyPips(InpZoneTF, shift - 1) >= InpOB_MinBodyPips;
      bool displaced     = c0 < l1;

      if(!(bullishCandle && nextBearish && strongBody && displaced))
         continue;

      double mid = (l1 + h1) / 2.0;
      bool mitigated = false;

      for(int k = shift - 1; k >= 0; k--)
      {
         if(iHigh(_Symbol, InpZoneTF, k) >= mid)
         {
            mitigated = true;
            break;
         }
      }

      if(mitigated)
         continue;

      z.low = l1;
      z.high = h1;
      z.bullish = false;
      z.timeStart = iTime(_Symbol, InpZoneTF, shift);
      z.valid = true;
      return z;
   }

   return z;
}

//==================================================
// Cache
//==================================================
void RefreshSignalCache()
{
   g_cache.dailyPivots  = CalcPivots(PERIOD_D1);
   g_cache.weeklyPivots = CalcPivots(PERIOD_W1);

   CollectFVGZones(g_cache.bullFVGs, true);
   CollectFVGZones(g_cache.bearFVGs, false);

   g_cache.bullOB = FindBullishOB();
   g_cache.bearOB = FindBearishOB();
}

void RefreshHeavyPartsIfNeeded()
{
   if(IsNewZoneBar())
      RefreshSignalCache();
}

//==================================================
// Position / Lot / Risk
//==================================================
int CountMyPositions()
{
   int count = 0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!PositionSelectByTicket(ticket)) continue;

      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         PositionGetInteger(POSITION_MAGIC) == (long)InpMagicNumber)
         count++;
   }

   return count;
}

bool HasMyPosition()
{
   return CountMyPositions() > 0;
}

double GetMyTotalOpenLots()
{
   double totalLots = 0.0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!PositionSelectByTicket(ticket)) continue;

      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         PositionGetInteger(POSITION_MAGIC) == (long)InpMagicNumber)
         totalLots += PositionGetDouble(POSITION_VOLUME);
   }

   return totalLots;
}

void ResetCycleIfFlat()
{
   if(!HasMyPosition())
   {
      g_cycleActive = false;
      g_cycleDirection = 0;
      g_initialEntryPrice = 0.0;
      g_fixedTPPrice = 0.0;
      g_fixedSLPrice = 0.0;
      g_nanpinCount = 0;
      g_initialLot = 0.0;
      g_breakEvenDone = false;
      g_partialDone = false;
   }
}

double NormalizeLot(double lot)
{
   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   if(stepLot <= 0.0)
      stepLot = 0.01;

   lot = MathMax(minLot, lot);
   lot = MathMin(maxLot, lot);
   lot = MathFloor(lot / stepLot) * stepLot;
   lot = NormalizeDouble(lot, 2);

   lot = MathMax(InpMinLot, lot);
   lot = MathMin(InpMaxLot, lot);

   return lot;
}

double RiskMoneyByDistance(double lot, double distancePrice)
{
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

   if(tickValue <= 0.0 || tickSize <= 0.0 || distancePrice <= 0.0 || lot <= 0.0)
      return 0.0;

   return (distancePrice / tickSize) * tickValue * lot;
}

double CurrentOpenRiskMoney()
{
   double totalRisk = 0.0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!PositionSelectByTicket(ticket)) continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         PositionGetInteger(POSITION_MAGIC) != (long)InpMagicNumber)
         continue;

      double volume = PositionGetDouble(POSITION_VOLUME);
      double open   = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl     = PositionGetDouble(POSITION_SL);

      if(sl <= 0.0)
         sl = g_fixedSLPrice;

      double distance = MathAbs(open - sl);
      totalRisk += RiskMoneyByDistance(volume, distance);
   }

   return totalRisk;
}

bool CanAddPositionBySL(double nextLot, double entryPrice, double slPrice)
{
   if(!MasterCanOpenNewTrade())
      return false;

   double nextTotalLots = GetMyTotalOpenLots() + nextLot;

   if(nextTotalLots > InpMaxTotalLotsPerCycle + 0.0000001)
   {
      DebugLog("Reject: total lot limit. nextTotalLots=" + DoubleToString(nextTotalLots, 2));
      return false;
   }

   double distance = MathAbs(entryPrice - slPrice);
   double nextRisk = RiskMoneyByDistance(nextLot, distance);
   double openRisk = CurrentOpenRiskMoney();

   double maxRiskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * InpMaxCycleRiskPercent / 100.0;
   double totalRisk = openRisk + nextRisk;

   if(totalRisk > maxRiskMoney)
   {
      DebugLog("Reject: cycle risk limit. openRisk=" + DoubleToString(openRisk, 2) +
               " nextRisk=" + DoubleToString(nextRisk, 2) +
               " totalRisk=" + DoubleToString(totalRisk, 2) +
               " maxRisk=" + DoubleToString(maxRiskMoney, 2));
      return false;
   }

   return true;
}

double CalcLot()
{
   // 自動ロットOFF時はBUY専用ロットを使用
   if(!InpUseAutoLot)
      return NormalizeLot(InpBuyLots);

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskMoney = balance * InpRiskPercentPerTrade / 100.0;

   double slDistance = PipsToPrice(InpSL_Pips);
   double riskPerLot = RiskMoneyByDistance(1.0, slDistance);

   if(riskPerLot <= 0.0)
      return NormalizeLot(InpFixedLotFallback);

   return NormalizeLot(riskMoney / riskPerLot);
}

//==================================================
// V5.2 Weighted Score
// FVG = 1.0 / OB = 1.0 / SMA = 0.5 / Pivot = 0.5
//==================================================
double BuildBuyScore(double price, string &detail)
{
   double score = 0.0;
   detail = "";

   if(!IsBuyTrendAllowed())
   {
      detail = "[BuyTrendNG] ";
      return 0.0;
   }

   if(CountFVGHits(price, g_cache.bullFVGs) > 0)
   {
      score += 1.0;
      detail += "[BullFVG+1] ";
   }

   if(g_cache.bullOB.valid && IsInsideZone(price, g_cache.bullOB.low, g_cache.bullOB.high))
   {
      score += 1.0;
      detail += "[BullOB+1] ";
   }

   if(CountSMATouches(price) > 0)
   {
      score += 0.5;
      detail += "[SMA+0.5] ";
   }

   if(CountAllPivotTouches(price) > 0)
   {
      score += 0.5;
      detail += "[Pivot+0.5] ";
   }

   return score;
}

double BuildSellScore(double price, string &detail)
{
   double score = 0.0;
   detail = "";

   if(!IsSellTrendAllowed())
   {
      detail = "[SellTrendNG] ";
      return 0.0;
   }

   if(CountFVGHits(price, g_cache.bearFVGs) > 0)
   {
      score += 1.0;
      detail += "[BearFVG+1] ";
   }

   if(g_cache.bearOB.valid && IsInsideZone(price, g_cache.bearOB.low, g_cache.bearOB.high))
   {
      score += 1.0;
      detail += "[BearOB+1] ";
   }

   if(CountSMATouches(price) > 0)
   {
      score += 0.5;
      detail += "[SMA+0.5] ";
   }

   if(CountAllPivotTouches(price) > 0)
   {
      score += 0.5;
      detail += "[Pivot+0.5] ";
   }

   return score;
}

//==================================================
// Orders
//==================================================
bool OpenInitialBuy()
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double lot = CalcLot();

   double sl = NormalizePrice(ask - PipsToPrice(InpSL_Pips));
   double tp = NormalizePrice(ask + PipsToPrice(InpTP_Pips));

   if(!CanAddPositionBySL(lot, ask, sl))
      return false;

   g_cycleActive = true;
   g_cycleDirection = 1;
   g_initialEntryPrice = ask;
   g_fixedTPPrice = tp;
   g_fixedSLPrice = sl;
   g_nanpinCount = 0;
   g_initialLot = lot;
   g_breakEvenDone = false;
   g_partialDone = false;

   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(20);

   bool ok = trade.Buy(lot, _Symbol, 0.0, g_fixedSLPrice, g_fixedTPPrice, "InitialBuy");

   if(ok)
      DebugLog("InitialBuy opened. lot=" + DoubleToString(lot, 2));

   return ok;
}

bool OpenInitialSell()
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double lot = CalcLot();

   double sl = NormalizePrice(bid + PipsToPrice(InpSL_Pips));
   double tp = NormalizePrice(bid - PipsToPrice(InpTP_Pips));

   if(!CanAddPositionBySL(lot, bid, sl))
      return false;

   g_cycleActive = true;
   g_cycleDirection = -1;
   g_initialEntryPrice = bid;
   g_fixedTPPrice = tp;
   g_fixedSLPrice = sl;
   g_nanpinCount = 0;
   g_initialLot = lot;
   g_breakEvenDone = false;
   g_partialDone = false;

   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(20);

   bool ok = trade.Sell(lot, _Symbol, 0.0, g_fixedSLPrice, g_fixedTPPrice, "InitialSell");

   if(ok)
      DebugLog("InitialSell opened. lot=" + DoubleToString(lot, 2));

   return ok;
}

bool OpenNanpinBuy()
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double lot = g_initialLot;

   if(lot <= 0.0)
      return false;

   if(!CanAddPositionBySL(lot, ask, g_fixedSLPrice))
      return false;

   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(20);

   bool ok = trade.Buy(lot, _Symbol, 0.0, g_fixedSLPrice, g_fixedTPPrice, "NanpinBuy");

   if(ok)
   {
      g_nanpinCount++;
      DebugLog("NanpinBuy opened. count=" + IntegerToString(g_nanpinCount));
   }

   return ok;
}

bool OpenNanpinSell()
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double lot = g_initialLot;

   if(lot <= 0.0)
      return false;

   if(!CanAddPositionBySL(lot, bid, g_fixedSLPrice))
      return false;

   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(20);

   bool ok = trade.Sell(lot, _Symbol, 0.0, g_fixedSLPrice, g_fixedTPPrice, "NanpinSell");

   if(ok)
   {
      g_nanpinCount++;
      DebugLog("NanpinSell opened. count=" + IntegerToString(g_nanpinCount));
   }

   return ok;
}

//==================================================
// Manage
//==================================================
bool UpdateAllMyPositionsTP_SL(double newSL, double newTP)
{
   bool allOk = true;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!PositionSelectByTicket(ticket)) continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         PositionGetInteger(POSITION_MAGIC) != (long)InpMagicNumber)
         continue;

      if(!trade.PositionModify(ticket, newSL, newTP))
         allOk = false;
   }

   return allOk;
}

bool CloseAllMyPositionsByMaxHold()
{
   bool anyClosed = false;

   trade.SetExpertMagicNumber(InpMagicNumber);

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!PositionSelectByTicket(ticket)) continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         PositionGetInteger(POSITION_MAGIC) != (long)InpMagicNumber)
         continue;

      if(trade.PositionClose(ticket))
         anyClosed = true;
      else
         DebugLog("MaxHold close failed. ticket=" + IntegerToString((long)ticket) +
                  " retcode=" + IntegerToString((int)trade.ResultRetcode()));
   }

   return anyClosed;
}

void ManageMaxHoldBars()
{
   if(!InpUseMaxHoldBars || InpMaxHoldBars <= 0)
      return;

   if(!HasMyPosition())
      return;

   datetime earliestOpenTime = 0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!PositionSelectByTicket(ticket)) continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         PositionGetInteger(POSITION_MAGIC) != (long)InpMagicNumber)
         continue;

      datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);

      if(earliestOpenTime == 0 || openTime < earliestOpenTime)
         earliestOpenTime = openTime;
   }

   if(earliestOpenTime <= 0)
      return;

   int openBarShift = iBarShift(_Symbol, _Period, earliestOpenTime, false);

   if(openBarShift < 0)
      return;

   if(openBarShift >= InpMaxHoldBars)
   {
      DebugLog("MaxHoldBars reached. bars=" + IntegerToString(openBarShift) +
               " / limit=" + IntegerToString(InpMaxHoldBars) +
               " -> close EA2 positions.");

      if(CloseAllMyPositionsByMaxHold())
         ResetCycleIfFlat();
   }
}

void ManageBreakEvenAndPartial()
{
   if(!HasMyPosition() || !g_cycleActive)
      return;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   double profitMove = 0.0;

   if(g_cycleDirection == 1)
      profitMove = bid - g_initialEntryPrice;
   else if(g_cycleDirection == -1)
      profitMove = g_initialEntryPrice - ask;

   if(!g_breakEvenDone && profitMove >= PipsToPrice(InpBETriggerPips))
   {
      double newSL = 0.0;

      if(g_cycleDirection == 1)
         newSL = NormalizePrice(g_initialEntryPrice + PipsToPrice(InpBEOffsetPips));
      else
         newSL = NormalizePrice(g_initialEntryPrice - PipsToPrice(InpBEOffsetPips));

      if(UpdateAllMyPositionsTP_SL(newSL, g_fixedTPPrice))
      {
         g_fixedSLPrice = newSL;
         g_breakEvenDone = true;
         DebugLog("BE moved.");
      }
   }

   if(InpPartialClosePercent <= 0.0)
      return;

   if(!g_partialDone && profitMove >= PipsToPrice(InpPartialTriggerPips))
   {
      double newSL = 0.0;

      if(g_cycleDirection == 1)
         newSL = NormalizePrice(g_initialEntryPrice + PipsToPrice(InpPartialSLPips));
      else
         newSL = NormalizePrice(g_initialEntryPrice - PipsToPrice(InpPartialSLPips));

      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0) continue;
         if(!PositionSelectByTicket(ticket)) continue;

         if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
            PositionGetInteger(POSITION_MAGIC) != (long)InpMagicNumber)
            continue;

         double volume = PositionGetDouble(POSITION_VOLUME);
         double step   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
         double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

         double closeVol = volume * InpPartialClosePercent / 100.0;

         if(step > 0.0)
            closeVol = MathFloor(closeVol / step) * step;

         closeVol = NormalizeDouble(closeVol, 2);

         if(closeVol >= minLot)
            trade.PositionClosePartial(ticket, closeVol);
      }

      UpdateAllMyPositionsTP_SL(newSL, g_fixedTPPrice);
      g_fixedSLPrice = newSL;
      g_partialDone = true;
      DebugLog("Partial close done.");
   }
}

void ManageNanpin()
{
   if(!g_cycleActive || !HasMyPosition())
      return;

   if(g_nanpinCount >= InpMaxNanpinCount)
      return;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double step = PipsToPrice(InpNanpinStepPips);

   int nextNanpinNo = g_nanpinCount + 1;
   double requiredAdverse = step * nextNanpinNo;

   if(g_cycleDirection == 1)
   {
      double adverse = g_initialEntryPrice - bid;

      if(adverse >= requiredAdverse)
      {
         DebugLog("NanpinBuy step reached. no=" + IntegerToString(nextNanpinNo) +
                  " adverse=" + DoubleToString(adverse, _Digits) +
                  " required=" + DoubleToString(requiredAdverse, _Digits));

         OpenNanpinBuy();
         return;
      }
   }
   else if(g_cycleDirection == -1)
   {
      double adverse = ask - g_initialEntryPrice;

      if(adverse >= requiredAdverse)
      {
         DebugLog("NanpinSell step reached. no=" + IntegerToString(nextNanpinNo) +
                  " adverse=" + DoubleToString(adverse, _Digits) +
                  " required=" + DoubleToString(requiredAdverse, _Digits));

         OpenNanpinSell();
         return;
      }
   }
}

//==================================================
// Entry
//==================================================
void UpdatePendingSignal(bool newBar)
{
   if(!newBar)
      return;

   if(g_pendingBuy)
   {
      g_pendingBuyBars++;
      if(g_pendingBuyBars > InpSignalExpireBars)
      {
         g_pendingBuy = false;
         g_pendingBuyBars = 0;
      }
   }

   if(g_pendingSell)
   {
      g_pendingSellBars++;
      if(g_pendingSellBars > InpSignalExpireBars)
      {
         g_pendingSell = false;
         g_pendingSellBars = 0;
      }
   }
}

void ProcessEntrySignal()
{
   if(!IsTradingHourAllowed()) return;
   if(!IsSpreadAllowed()) return;
   if(HasMyPosition()) return;

   bool newBar = IsNewChartBar();

   if(InpOneEntryPerBar && !newBar)
      return;

   UpdatePendingSignal(newBar);

   double price = CurrentMidPrice();

   string buyDetail = "";
   string sellDetail = "";

   double buyScore = BuildBuyScore(price, buyDetail);
   double sellScore = BuildSellScore(price, sellDetail);

   DebugLog("BuyScore=" + DoubleToString(buyScore, 1) + " " + buyDetail +
            " | SellScore=" + DoubleToString(sellScore, 1) + " " + sellDetail);

   if(!InpUsePullbackEntry)
   {
      if(InpAllowBuy && buyScore >= InpMinConfluence && buyScore > sellScore)
      {
         OpenInitialBuy();
         return;
      }

      if(InpAllowSell && sellScore >= InpMinConfluence && sellScore > buyScore)
      {
         OpenInitialSell();
         return;
      }

      return;
   }

   if(InpAllowBuy && buyScore >= InpMinConfluence && buyScore > sellScore)
   {
      g_pendingBuy = true;
      g_pendingSell = false;
      g_pendingBuyPrice = price;
      g_pendingBuyBars = 0;
   }

   if(InpAllowSell && sellScore >= InpMinConfluence && sellScore > buyScore)
   {
      g_pendingSell = true;
      g_pendingBuy = false;
      g_pendingSellPrice = price;
      g_pendingSellBars = 0;
   }

   double pullback = PipsToPrice(InpPullbackEntryPips);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   if(g_pendingBuy && InpAllowBuy && bid <= g_pendingBuyPrice - pullback)
   {
      OpenInitialBuy();
      g_pendingBuy = false;
      return;
   }

   if(g_pendingSell && InpAllowSell && ask >= g_pendingSellPrice + pullback)
   {
      OpenInitialSell();
      g_pendingSell = false;
      return;
   }
}

//==================================================
// SELL ONLY MODULE S1.0 / separate Magic / simultaneous with BUY allowed
//====================================================================
//==================== SELL側パラメータ ====================//
input bool              S_InpEnable                   = false;     // SELL専用スナイパーを使う（通貨版V1はOFF）
input long              S_InpMagicNumber              = 26042404;  // SELL専用マジックナンバー
input double            S_InpLots                     = 0.01;  // SELLロット（通貨版初期値）
input double            S_InpPipSize                  = 0.0;   // SELL 1pip価格幅（0=自動判定 / EURUSD=0.0001 / USDJPY=0.01）
input int               S_InpMaxSpreadPips            = 2;    // SELL最大スプレッド(pips)（通貨版）
input bool              S_InpUseSessionFilter         = true;  // SELL時間帯フィルター使用
input int               S_InpSessionStartHour         = 15;  // SELL開始時刻
input int               S_InpSessionEndHour           = 3;  // SELL終了時刻（日跨ぎOK）
input int               S_InpMaxInitialEntriesPerDay  = 3;  // SELL 1日最大エントリー数
input ENUM_TIMEFRAMES   S_InpHigherTF                 = PERIOD_H1;  // SELL EMA判定時間足
input bool              S_InpUseEMAFilter             = true;  // SELL EMA50フィルター使用
input int               S_InpEMA_Period               = 50;  // SELL EMA期間
input int               S_InpSweepLookbackBars        = 80;  // SELL流動性スイープ探索本数
input int               S_InpSweepRangeBars           = 5;  // SELLスイープ比較本数
input int               S_InpPreSwingLookbackBars     = 10;  // SELL CHoCH用スイング探索本数
input double            S_InpSweepReclaimPips         = 5;  // SELLスイープ後の戻し幅(pips)
input int               S_InpFVGSearchBars            = 50;  // SELL FVG探索本数
input double            S_InpMinFVGSizePips           = 2;   // SELL最小FVGサイズ(pips)（通貨版）
input int               S_InpOBSearchBars             = 50;  // SELL OB探索本数
input bool              S_InpRequireOBConfirm         = true;  // SELL OB確認必須
input double            S_InpMaxFVG_OB_DistancePips   = 10;  // SELL FVGとOBの最大距離(pips)（通貨版）
input bool              S_InpUseOverlapZoneIfPossible = false;  // SELL FVG/OB重複ゾーン使用
input int               S_InpSetupValidBars           = 50;  // SELLセットアップ有効本数
input double            S_InpRetestTolerancePips      = 3;   // SELLリテスト許容幅(pips)（通貨版）
input bool              S_InpTouchByWickAllowed       = true;  // SELLヒゲタッチ許可
input bool              S_InpTouchByCloseAllowed      = true;  // SELL終値タッチ許可
input bool              S_InpInvalidateIfZoneBroken   = true;  // SELLゾーンブレイクで無効化
input double            S_InpSL_BufferPips            = 3;   // SELL SLバッファ(pips)（通貨版）
input double            S_InpMinSL_Pips               = 10;  // SELL最小SL幅(pips)（通貨版）
input double            S_InpMaxSL_Pips               = 25;  // SELL最大SL幅(pips)（通貨版）
input double            S_InpRR                       = 2.0;  // SELLリスクリワード倍率
input int               S_InpCooldownAfterSL_Minutes  = 120;  // SELL SL後クールダウン(分)
input int               S_InpMaxSellLosses            = 2;  // SELL同方向連敗ロック発動数
input int               S_InpSellLockMinutes          = 240;  // SELL連敗後ロック時間(分)
input int               S_InpStopAfterConsecutiveLosses = 5;  // SELL 〇連敗で停止
input int               S_InpStopEntryDaysAfterLosses   = 1;  // SELL停止日数
input bool              S_InpUseZoneReuseBan          = true;  // SELL使用済みゾーン再利用禁止
input double            S_InpZoneMatchTolerancePips   = 3;  // SELLゾーン同一判定許容幅(pips)（通貨版）
input bool              S_InpOneInitialEntryPerBar    = true;  // SELL 1バー1回のみエントリー
input int               S_InpSlippagePoints           = 50;  // SELL許容スリッページ(points)
input bool              S_InpDebugPrint               = true;  // SELLデバッグログ表示

//==================================================
// Master Money Management / Stop Filters
//==================================================
string MasterGVKey(string name)
{
   return "FX_CURRENCY_MASTER_" + _Symbol + "_" + IntegerToString((int)InpMagicNumber) + "_" + IntegerToString((int)S_InpMagicNumber) + "_" + name;
}

void MasterSetGV(string name, double value)
{
   GlobalVariableSet(MasterGVKey(name), value);
}

double MasterGetGV(string name, double def = 0.0)
{
   string key = MasterGVKey(name);
   if(GlobalVariableCheck(key))
      return GlobalVariableGet(key);
   return def;
}

void MasterDelGV(string name)
{
   string key = MasterGVKey(name);
   if(GlobalVariableCheck(key))
      GlobalVariableDel(key);
}

bool IsPortfolioMagic(long magic)
{
   return (magic == (long)InpMagicNumber || magic == (long)S_InpMagicNumber);
}

void MasterResetRiskState()
{
   MasterDelGV("LOSS_BAN_UNTIL");
   MasterDelGV("LOSS_RESET_TIME");
   MasterSetGV("PEAK_EQUITY", AccountInfoDouble(ACCOUNT_EQUITY));
}

void MasterUpdatePeakEquity()
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double peak = MasterGetGV("PEAK_EQUITY", 0.0);

   if(peak <= 0.0 || equity > peak)
      MasterSetGV("PEAK_EQUITY", equity);
}

double MasterCurrentDDPercent()
{
   MasterUpdatePeakEquity();

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double peak = MasterGetGV("PEAK_EQUITY", equity);

   if(peak <= 0.0)
      return 0.0;

   return MathMax(0.0, (peak - equity) / peak * 100.0);
}

void MasterCloseAllPortfolioPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(!IsPortfolioMagic(PositionGetInteger(POSITION_MAGIC))) continue;

      trade.PositionClose(ticket);
   }
}

bool MasterDDStopOK()
{
   if(!InpUseMasterRiskFilter || InpMaxDrawdownPercent <= 0.0)
      return true;

   double dd = MasterCurrentDDPercent();

   if(dd >= InpMaxDrawdownPercent)
   {
      DebugLog("Master DD stop active. DD=" + DoubleToString(dd, 2) + "% / limit=" + DoubleToString(InpMaxDrawdownPercent, 2) + "%");

      if(InpClosePositionsOnDDStop)
         MasterCloseAllPortfolioPositions();

      return false;
   }

   return true;
}

bool MasterLossStopOK()
{
   if(!InpUseMasterRiskFilter || InpMasterStopLosses <= 0 || InpMasterStopDays <= 0)
      return true;

   datetime nowTime = TimeCurrent();
   datetime banUntil = (datetime)MasterGetGV("LOSS_BAN_UNTIL", 0);

   if(banUntil > nowTime)
   {
      DebugLog("Master loss stop active until " + TimeToString(banUntil, TIME_DATE | TIME_MINUTES));
      return false;
   }

   if(banUntil > 0 && banUntil <= nowTime)
   {
      MasterSetGV("LOSS_RESET_TIME", (double)banUntil);
      MasterDelGV("LOSS_BAN_UNTIL");
      DebugLog("Master loss stop expired. Loss count reset.");
      return true;
   }

   datetime resetTime = (datetime)MasterGetGV("LOSS_RESET_TIME", 0);

   if(!HistorySelect(resetTime, nowTime))
      return true;

   int losses = 0;
   datetime latestLossTime = 0;
   int deals = HistoryDealsTotal();

   for(int i = deals - 1; i >= 0; i--)
   {
      ulong deal = HistoryDealGetTicket(i);
      if(deal == 0) continue;

      datetime dealTime = (datetime)HistoryDealGetInteger(deal, DEAL_TIME);
      if(dealTime <= resetTime) continue;

      if(HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol) continue;
      if(!IsPortfolioMagic(HistoryDealGetInteger(deal, DEAL_MAGIC))) continue;
      if(HistoryDealGetInteger(deal, DEAL_ENTRY) != DEAL_ENTRY_OUT) continue;

      double profit = HistoryDealGetDouble(deal, DEAL_PROFIT)
                    + HistoryDealGetDouble(deal, DEAL_SWAP)
                    + HistoryDealGetDouble(deal, DEAL_COMMISSION);

      if(profit < 0.0)
      {
         losses++;
         if(latestLossTime == 0)
            latestLossTime = dealTime;
      }
      else
      {
         break;
      }
   }

   if(losses >= InpMasterStopLosses && latestLossTime > 0)
   {
      datetime untilTime = latestLossTime + (InpMasterStopDays * 86400);
      MasterSetGV("LOSS_BAN_UNTIL", (double)untilTime);

      DebugLog("Master loss stop triggered. losses=" + IntegerToString(losses) +
               " banUntil=" + TimeToString(untilTime, TIME_DATE | TIME_MINUTES));
      return false;
   }

   return true;
}

bool MasterCanOpenNewTrade()
{
   if(!MasterDDStopOK())
      return false;

   if(!MasterLossStopOK())
      return false;

   return true;
}

datetime S_lastBarTime = 0;
double S_lastUsedSellLow = 0.0;
double S_lastUsedSellHigh = 0.0;

struct S_SetupData
{
   bool valid; double entryLow; double entryHigh; double fvgLow; double fvgHigh; double obLow; double obHigh; double sweepExtreme; datetime detectedBarTime; int barsRemaining;
};
S_SetupData S_sellSetup;

void S_Debug(string msg){ if(S_InpDebugPrint) Print("[SELL_S1] ", msg); }
double S_Pip(){ if(S_InpPipSize > 0.0) return S_InpPipSize; int digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS); if(digits==3 || digits==5) return _Point*10.0; return _Point; }
double S_NormalizePrice(double price){ return NormalizeDouble(price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)); }
int S_SafeHour(int h){ int r=h%24; if(r<0) r+=24; return r; }
string S_GVKey(string name){ return "FX_CURRENCY_SELL_S1_" + _Symbol + "_" + IntegerToString((int)S_InpMagicNumber) + "_" + name; }
void S_SetGV(string name,double value){ GlobalVariableSet(S_GVKey(name), value); }
double S_GetGV(string name,double def=0.0){ string key=S_GVKey(name); if(GlobalVariableCheck(key)) return GlobalVariableGet(key); return def; }
void S_DelGV(string name){ string key=S_GVKey(name); if(GlobalVariableCheck(key)) GlobalVariableDel(key); }

bool S_IsNewBar(){ datetime t=iTime(_Symbol,_Period,0); if(t!=S_lastBarTime){ S_lastBarTime=t; return true; } return false; }
bool S_InSession(){ if(!S_InpUseSessionFilter) return true; int s=S_SafeHour(S_InpSessionStartHour), e=S_SafeHour(S_InpSessionEndHour); MqlDateTime dt; TimeToStruct(TimeCurrent(),dt); int h=dt.hour; if(s==e) return true; if(s<e) return (h>=s && h<e); return (h>=s || h<e); }
double S_CurrentSpreadPips(){ return (SymbolInfoDouble(_Symbol,SYMBOL_ASK)-SymbolInfoDouble(_Symbol,SYMBOL_BID))/S_Pip(); }
bool S_SpreadOK(){ double sp=S_CurrentSpreadPips(); if(sp>S_InpMaxSpreadPips){ S_Debug("Spread NG: "+DoubleToString(sp,1)); return false; } return true; }
void S_ResetSetup(S_SetupData &st){ st.valid=false; st.entryLow=0; st.entryHigh=0; st.fvgLow=0; st.fvgHigh=0; st.obLow=0; st.obHigh=0; st.sweepExtreme=0; st.detectedBarTime=0; st.barsRemaining=0; }
double S_HighestHighShiftRange(int startShift,int count){ double highest=-DBL_MAX; for(int i=startShift;i<startShift+count;i++){ double h=iHigh(_Symbol,_Period,i); if(h>highest) highest=h; } return highest; }
double S_LowestLowShiftRange(int startShift,int count){ double lowest=DBL_MAX; for(int i=startShift;i<startShift+count;i++){ double l=iLow(_Symbol,_Period,i); if(l<lowest) lowest=l; } return lowest; }

int S_CountPositions(){ int count=0; for(int i=PositionsTotal()-1;i>=0;i--){ ulong ticket=PositionGetTicket(i); if(ticket==0) continue; if(!PositionSelectByTicket(ticket)) continue; if(PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_MAGIC)==S_InpMagicNumber) count++; } return count; }
int S_CountInitialEntriesToday(){ MqlDateTime dt; TimeToStruct(TimeCurrent(),dt); dt.hour=0; dt.min=0; dt.sec=0; datetime dayStart=StructToTime(dt); if(!HistorySelect(dayStart,TimeCurrent())) return 0; int count=0, deals=HistoryDealsTotal(); for(int i=0;i<deals;i++){ ulong deal=HistoryDealGetTicket(i); if(deal==0) continue; if(HistoryDealGetString(deal,DEAL_SYMBOL)!=_Symbol) continue; if(HistoryDealGetInteger(deal,DEAL_MAGIC)!=S_InpMagicNumber) continue; if(HistoryDealGetInteger(deal,DEAL_ENTRY)!=DEAL_ENTRY_IN) continue; string comment=HistoryDealGetString(deal,DEAL_COMMENT); if(StringFind(comment,"INIT SELL")>=0) count++; } return count; }

bool S_GetEMAValue(int period,double &ema){ ema=0.0; int h=iMA(_Symbol,S_InpHigherTF,period,0,MODE_EMA,PRICE_CLOSE); if(h==INVALID_HANDLE) return false; double buf[]; ArraySetAsSeries(buf,true); if(CopyBuffer(h,0,1,1,buf)<1){ IndicatorRelease(h); return false; } IndicatorRelease(h); ema=buf[0]; return (ema>0.0); }
bool S_PassEMAFilterSell(){ if(!S_InpUseEMAFilter) return true; double closeHTF=iClose(_Symbol,S_InpHigherTF,1); if(closeHTF<=0) return false; double ema=0.0; if(!S_GetEMAValue(S_InpEMA_Period,ema)) return false; return (closeHTF<ema); }

bool S_GetLastClosedTrade(datetime &closeTime,double &profit,string &comment){ closeTime=0; profit=0.0; comment=""; datetime resetTime=(datetime)S_GetGV("LOSS_RESET_TIME",0); if(!HistorySelect(resetTime,TimeCurrent())) return false; int deals=HistoryDealsTotal(); for(int i=deals-1;i>=0;i--){ ulong deal=HistoryDealGetTicket(i); if(deal==0) continue; datetime dealTime=(datetime)HistoryDealGetInteger(deal,DEAL_TIME); if(dealTime<=resetTime) continue; if(HistoryDealGetString(deal,DEAL_SYMBOL)!=_Symbol) continue; if(HistoryDealGetInteger(deal,DEAL_MAGIC)!=S_InpMagicNumber) continue; if(HistoryDealGetInteger(deal,DEAL_ENTRY)!=DEAL_ENTRY_OUT) continue; if(HistoryDealGetInteger(deal,DEAL_TYPE)!=DEAL_TYPE_BUY) continue; closeTime=dealTime; profit=HistoryDealGetDouble(deal,DEAL_PROFIT)+HistoryDealGetDouble(deal,DEAL_SWAP)+HistoryDealGetDouble(deal,DEAL_COMMISSION); comment=HistoryDealGetString(deal,DEAL_COMMENT); return true; } return false; }
bool S_CooldownOK(){ if(S_InpCooldownAfterSL_Minutes<=0) return true; datetime t; double profit; string comment; if(!S_GetLastClosedTrade(t,profit,comment)) return true; bool wasSL=(StringFind(comment,"sl")>=0 || profit<0.0); if(!wasSL) return true; int elapsed=(int)((TimeCurrent()-t)/60); if(elapsed<S_InpCooldownAfterSL_Minutes){ S_Debug("Cooldown after SL active"); return false; } return true; }
int S_ConsecutiveSellLosses(){ datetime resetTime=(datetime)S_GetGV("LOSS_RESET_TIME",0); if(!HistorySelect(resetTime,TimeCurrent())) return 0; int losses=0, deals=HistoryDealsTotal(); for(int i=deals-1;i>=0;i--){ ulong deal=HistoryDealGetTicket(i); if(deal==0) continue; datetime dealTime=(datetime)HistoryDealGetInteger(deal,DEAL_TIME); if(dealTime<=resetTime) continue; if(HistoryDealGetString(deal,DEAL_SYMBOL)!=_Symbol) continue; if(HistoryDealGetInteger(deal,DEAL_MAGIC)!=S_InpMagicNumber) continue; if(HistoryDealGetInteger(deal,DEAL_ENTRY)!=DEAL_ENTRY_OUT) continue; if(HistoryDealGetInteger(deal,DEAL_TYPE)!=DEAL_TYPE_BUY) continue; double profit=HistoryDealGetDouble(deal,DEAL_PROFIT)+HistoryDealGetDouble(deal,DEAL_SWAP)+HistoryDealGetDouble(deal,DEAL_COMMISSION); if(profit<0.0) losses++; else break; } return losses; }
bool S_SellLockOK(){ if(S_InpMaxSellLosses<=0) return true; int losses=S_ConsecutiveSellLosses(); if(losses<S_InpMaxSellLosses) return true; datetime t; double profit; string comment; if(!S_GetLastClosedTrade(t,profit,comment)) return true; int elapsed=(int)((TimeCurrent()-t)/60); if(elapsed<S_InpSellLockMinutes){ S_Debug("SELL lock active. losses="+IntegerToString(losses)); return false; } return true; }
bool S_LossStopDaysOK(){ if(S_InpStopAfterConsecutiveLosses<=0 || S_InpStopEntryDaysAfterLosses<=0) return true; datetime nowTime=TimeCurrent(); datetime banUntil=(datetime)S_GetGV("LOSS_BAN_UNTIL",0); if(banUntil>nowTime) return false; if(banUntil>0 && banUntil<=nowTime){ S_SetGV("LOSS_RESET_TIME",(double)banUntil); S_DelGV("LOSS_BAN_UNTIL"); return true; } datetime resetTime=(datetime)S_GetGV("LOSS_RESET_TIME",0); if(!HistorySelect(resetTime,nowTime)) return true; int losses=0; datetime latestLossTime=0; int deals=HistoryDealsTotal(); for(int i=deals-1;i>=0;i--){ ulong deal=HistoryDealGetTicket(i); if(deal==0) continue; datetime dealTime=(datetime)HistoryDealGetInteger(deal,DEAL_TIME); if(dealTime<=resetTime) continue; if(HistoryDealGetString(deal,DEAL_SYMBOL)!=_Symbol) continue; if(HistoryDealGetInteger(deal,DEAL_MAGIC)!=S_InpMagicNumber) continue; if(HistoryDealGetInteger(deal,DEAL_ENTRY)!=DEAL_ENTRY_OUT) continue; if(HistoryDealGetInteger(deal,DEAL_TYPE)!=DEAL_TYPE_BUY) continue; double profit=HistoryDealGetDouble(deal,DEAL_PROFIT)+HistoryDealGetDouble(deal,DEAL_SWAP)+HistoryDealGetDouble(deal,DEAL_COMMISSION); if(profit<0.0){ losses++; if(latestLossTime==0) latestLossTime=dealTime; } else break; } if(losses>=S_InpStopAfterConsecutiveLosses && latestLossTime>0){ datetime untilTime=latestLossTime+(S_InpStopEntryDaysAfterLosses*86400); S_SetGV("LOSS_BAN_UNTIL",(double)untilTime); return false; } return true; }

bool S_ZoneSame(double aLow,double aHigh,double bLow,double bHigh){ double tol=S_InpZoneMatchTolerancePips*S_Pip(); return (MathAbs(aLow-bLow)<=tol && MathAbs(aHigh-bHigh)<=tol); }
bool S_IsZoneUsed(const S_SetupData &st){ if(!S_InpUseZoneReuseBan) return false; return S_ZoneSame(st.entryLow,st.entryHigh,S_lastUsedSellLow,S_lastUsedSellHigh); }
void S_SaveUsedZone(const S_SetupData &st){ S_lastUsedSellLow=st.entryLow; S_lastUsedSellHigh=st.entryHigh; }

bool S_FindSellSetup(S_SetupData &st){ S_ResetSetup(st); if(!S_PassEMAFilterSell()) return false; double pip=S_Pip(); if(Bars(_Symbol,_Period)<200) return false; int sweepShift=-1; double sweepHigh=0.0; double preLow=0.0; for(int i=5;i<=S_InpSweepLookbackBars;i++){ double high_i=iHigh(_Symbol,_Period,i); double close_i=iClose(_Symbol,_Period,i); double prevHighest=S_HighestHighShiftRange(i+1,S_InpSweepRangeBars); if(high_i>prevHighest && close_i<prevHighest-S_InpSweepReclaimPips*pip){ sweepShift=i; sweepHigh=high_i; preLow=S_LowestLowShiftRange(i+1,S_InpPreSwingLookbackBars); break; } } if(sweepShift<0) return false; int chochShift=-1; for(int j=sweepShift-1;j>=1;j--){ if(iClose(_Symbol,_Period,j)<preLow){ chochShift=j; break; } } if(chochShift<0) return false; int fvgShift=-1; double fvgLow=0.0, fvgHigh=0.0; for(int s=chochShift-1;s>=1 && s>=chochShift-S_InpFVGSearchBars;s--){ double low_s2=iLow(_Symbol,_Period,s+2); double high_s=iHigh(_Symbol,_Period,s); if(low_s2>high_s+S_InpMinFVGSizePips*pip){ fvgLow=high_s; fvgHigh=low_s2; fvgShift=s; break; } } if(fvgShift<0) return false; int obShift=-1; double obLow=0.0, obHigh=0.0; for(int b=fvgShift+2;b<=fvgShift+S_InpOBSearchBars;b++){ double o=iOpen(_Symbol,_Period,b); double c=iClose(_Symbol,_Period,b); if(c>o){ obLow=iLow(_Symbol,_Period,b); obHigh=iHigh(_Symbol,_Period,b); obShift=b; break; } } if(S_InpRequireOBConfirm && obShift<0) return false; if(obShift>0){ double fvgMid=(fvgLow+fvgHigh)*0.5; double obMid=(obLow+obHigh)*0.5; double dist=MathAbs(fvgMid-obMid)/pip; if(dist>S_InpMaxFVG_OB_DistancePips) return false; } double entryLow=fvgLow, entryHigh=fvgHigh; if(S_InpRequireOBConfirm && obShift>0 && S_InpUseOverlapZoneIfPossible){ double ovLow=MathMax(fvgLow,obLow); double ovHigh=MathMin(fvgHigh,obHigh); if(ovLow<ovHigh){ entryLow=ovLow; entryHigh=ovHigh; } } st.valid=true; st.entryLow=entryLow; st.entryHigh=entryHigh; st.fvgLow=fvgLow; st.fvgHigh=fvgHigh; st.obLow=obLow; st.obHigh=obHigh; st.sweepExtreme=sweepHigh; st.detectedBarTime=iTime(_Symbol,_Period,1); st.barsRemaining=S_InpSetupValidBars; return true; }

bool S_SetupTouchSell(const S_SetupData &st){ double tol=S_InpRetestTolerancePips*S_Pip(); double barLow=iLow(_Symbol,_Period,1), barHigh=iHigh(_Symbol,_Period,1), barClose=iClose(_Symbol,_Period,1); double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID); bool wickTouch=!(barHigh<st.entryLow-tol || barLow>st.entryHigh+tol); bool closeTouch=(barClose>=st.entryLow-tol && barClose<=st.entryHigh+tol); bool nowNear=(bid>=st.entryLow-tol && bid<=st.entryHigh+tol); if(S_InpTouchByWickAllowed && wickTouch) return true; if(S_InpTouchByCloseAllowed && closeTouch) return true; if(nowNear) return true; return false; }
bool S_SetupInvalidatedSell(const S_SetupData &st){ if(!S_InpInvalidateIfZoneBroken) return false; double tol=S_InpRetestTolerancePips*S_Pip(); double barClose=iClose(_Symbol,_Period,1); return (barClose>st.entryHigh+tol); }
bool S_CalcSLTPSell(const S_SetupData &st,double &sl,double &tp){ double pip=S_Pip(); double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID); double base=st.sweepExtreme; if(st.obHigh>0) base=MathMax(base,st.obHigh); base=MathMax(base,st.entryHigh); double rawSL=base+S_InpSL_BufferPips*pip; double slDist=(rawSL-bid)/pip; if(slDist<S_InpMinSL_Pips) rawSL=bid+S_InpMinSL_Pips*pip; if(slDist>S_InpMaxSL_Pips) rawSL=bid+S_InpMaxSL_Pips*pip; sl=S_NormalizePrice(rawSL); double risk=sl-bid; if(risk<=0) return false; tp=S_NormalizePrice(bid-risk*S_InpRR); return true; }
bool S_CanEnterSell(){ if(S_CountPositions()>0) return false; if(S_CountInitialEntriesToday()>=S_InpMaxInitialEntriesPerDay) return false; if(!S_SpreadOK()) return false; if(!S_InSession()) return false; if(!S_CooldownOK()) return false; if(!S_SellLockOK()) return false; if(!S_LossStopDaysOK()) return false; if(!S_PassEMAFilterSell()) return false; return true; }
bool S_OpenSellTrade(const S_SetupData &st){ if(S_IsZoneUsed(st)){ S_Debug("SELL zone already used"); return false; } if(!MasterCanOpenNewTrade()) return false; if(!S_CanEnterSell()) return false; double sl=0.0,tp=0.0; if(!S_CalcSLTPSell(st,sl,tp)) return false; trade.SetExpertMagicNumber(S_InpMagicNumber); trade.SetDeviationInPoints(S_InpSlippagePoints); bool ok=trade.Sell(S_InpLots,_Symbol,0.0,sl,tp,"INIT SELL"); if(ok){ S_SaveUsedZone(st); S_Debug("SELL opened. SL="+DoubleToString(sl,2)+" TP="+DoubleToString(tp,2)); } else S_Debug("SELL failed retcode="+IntegerToString((int)trade.ResultRetcode())); return ok; }
void S_UpdateSetupLifetime(){ if(S_sellSetup.valid) S_sellSetup.barsRemaining--; if(S_sellSetup.valid && S_sellSetup.barsRemaining<=0){ S_Debug("SELL setup expired"); S_ResetSetup(S_sellSetup); } }
void S_RefreshSellSetup(){ S_SetupData tmp; if(S_FindSellSetup(tmp)){ if(!S_sellSetup.valid || S_sellSetup.detectedBarTime!=tmp.detectedBarTime){ S_sellSetup=tmp; S_Debug("SELL setup saved: "+DoubleToString(tmp.entryLow,2)+" - "+DoubleToString(tmp.entryHigh,2)); } } }
void S_CheckSavedSellSetup(){ if(!S_sellSetup.valid) return; if(S_SetupInvalidatedSell(S_sellSetup)){ S_Debug("SELL setup invalidated"); S_ResetSetup(S_sellSetup); return; } if(S_SetupTouchSell(S_sellSetup)){ if(S_OpenSellTrade(S_sellSetup)) S_ResetSetup(S_sellSetup); } }
void S_OnInitModule(){ S_lastBarTime=iTime(_Symbol,_Period,0); S_ResetSetup(S_sellSetup); }
void S_OnTickModule(){ bool newBar=S_IsNewBar(); if(newBar){ S_UpdateSetupLifetime(); S_RefreshSellSetup(); } if(S_InpOneInitialEntryPerBar && !newBar) return; S_CheckSavedSellSetup(); }
// Lifecycle
//==================================================
int P_OnInit()
{
   trade.SetExpertMagicNumber(InpMagicNumber);

   ArrayResize(g_cache.bullFVGs, 0);
   ArrayResize(g_cache.bearFVGs, 0);

   g_cache.bullOB.valid = false;
   g_cache.bearOB.valid = false;
   g_cache.dailyPivots.valid = false;
   g_cache.weeklyPivots.valid = false;

   if(!InitMAHandles())
   {
      Print("MA handle initialization failed.");
      ReleaseAllMAHandles();
      return INIT_FAILED;
   }

   RefreshSignalCache();

   if(InpResetRiskStateOnInit)
      MasterResetRiskState();
   else
      MasterUpdatePeakEquity();

   if(S_InpEnable)
      S_OnInitModule();
   Print("BUY + SELL Portfolio EA initialized. Currency V1.2 / SELL sniper=" + (S_InpEnable ? "ON" : "OFF"));
   return INIT_SUCCEEDED;
}

void P_OnDeinit(const int reason)
{
   ReleaseAllMAHandles();
}

void P_OnTick()
{
   MasterDDStopOK();

   ResetCycleIfFlat();

   RefreshHeavyPartsIfNeeded();

   if(HasMyPosition())
   {
      ManageMaxHoldBars();

      if(HasMyPosition())
      {
         ManageBreakEvenAndPartial();
         ManageNanpin();
      }
   }
   else
   {
      ProcessEntrySignal();
   }

   if(S_InpEnable)
      S_OnTickModule();
}
//====================================================================


//====================================================================
// 統合EA Lifecycle
//====================================================================
int OnInit()
{
   int r1 = INIT_SUCCEEDED;
   int r2 = INIT_SUCCEEDED;

   if(ComboUse_DowFibEA)
      r1 = D_OnInit();

   if(ComboUse_BuySellEA)
      r2 = P_OnInit();

   if(r1 != INIT_SUCCEEDED || r2 != INIT_SUCCEEDED)
   {
      Print("Combined EA init failed. DowFib=", r1, " Portfolio=", r2);
      return INIT_FAILED;
   }

   Print("Combined EA started. DowFib and Portfolio are separated by MagicNumber.");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(ComboUse_DowFibEA)
      D_OnDeinit(reason);

   if(ComboUse_BuySellEA)
      P_OnDeinit(reason);
}

void OnTick()
{
   // 先にEA①、次にEA②を実行。MagicNumber別なので同時保有OK。
   if(ComboUse_DowFibEA)
      D_OnTick();

   if(ComboUse_BuySellEA)
      P_OnTick();
}
