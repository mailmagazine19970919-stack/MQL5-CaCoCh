//+------------------------------------------------------------------+
//|                                 MyModel(T)-CandleChangerTest.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   2

//--- 値(1/0)の受け渡し用なので描画はしない (Data Window / CopyBuffer から参照可能)
#property indicator_label1  "Up"
#property indicator_type1   DRAW_NONE
#property indicator_label2  "Dn"
#property indicator_type2   DRAW_NONE

input double Ratio1 = 1;  //Ratio1 > Ratio2
input double Ratio2 = 1;  //
input double Ratio3 = 1;  //Ratio3 < Ratio4
input double Ratio4 = 1;  //

double Up[]; double Dn[];
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, Up, INDICATOR_DATA);
   SetIndexBuffer(1, Dn, INDICATOR_DATA);

//--- MQL4 と同じく 0 = 最新足 の並びで扱う
   ArraySetAsSeries(Up, true);
   ArraySetAsSeries(Dn, true);

//--- EMPTY_VALUE は「値なし」として扱う
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
   if(rates_total < 2)
      return(0);

//--- 入力配列も 0 = 最新足 の並びにする (iOpen(NULL,0,i) などの代わりに直接使う)
   ArraySetAsSeries(open,  true);
   ArraySetAsSeries(high,  true);
   ArraySetAsSeries(low,   true);
   ArraySetAsSeries(close, true);

//--- 計算範囲 (MQL4 の Bars - IndicatorCounted() - 1 の代わり)
//    初回は全履歴、以降は新たに確定した足だけ
   int limit;
   if(prev_calculated <= 0 || prev_calculated > rates_total)
      limit = rates_total - 1;
   else
      limit = rates_total - prev_calculated;

//--- 形成中の足(0)は計算しない
   Up[0] = EMPTY_VALUE;
   Dn[0] = EMPTY_VALUE;

//--- 確定足条件の処理 (元コードの条件は NowBars が毎回 0 に戻るため実質 i >= 1)
   for(int i = limit; i >= 1; i--)
     {
      Up[i] = EMPTY_VALUE;
      Dn[i] = EMPTY_VALUE;

      double OpenNow  = open[i];
      double CloseNow = close[i];
      double HighNow  = high[i];
      double LowNow   = low[i];

      double BullBodyNow    = CloseNow - OpenNow;
      double BullUpperWick  = HighNow - CloseNow;
      double BullDownerWick = OpenNow - LowNow;

      double BearBodyNow    = OpenNow - CloseNow;
      double BearUpperWick  = HighNow - OpenNow;
      double BearDownerWick = CloseNow - LowNow;

      //買いの条件式
      if(   (OpenNow < CloseNow && (BullBodyNow + BullDownerWick) * Ratio1 > BullUpperWick * Ratio2)   //陽線におけるベア派の弱さの発露
         || (OpenNow > CloseNow && (BearBodyNow + BearUpperWick)  * Ratio3 < BearDownerWick * Ratio4)) //陰線におけるベア派の弱さの発露
        {
         Up[i] = 1;
         Dn[i] = 2;
        }

      //売りの条件式
      if(   (OpenNow > CloseNow && (BearBodyNow + BearUpperWick)  * Ratio1 > BearDownerWick * Ratio2)   //陽線におけるブル派の弱さの発露
         || (OpenNow < CloseNow && (BullBodyNow + BullDownerWick) * Ratio3 < BullUpperWick * Ratio4))   //陰線におけるブル派の弱さの発露
        {
         Up[i] = 2;
         Dn[i] = 1;
        }
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
