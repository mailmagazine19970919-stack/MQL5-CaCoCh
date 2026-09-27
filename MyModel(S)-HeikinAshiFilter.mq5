//+------------------------------------------------------------------+
//|                                                  Heiken Ashi.mq5 |
//|                   Copyright 2006-2014, MetaQuotes Software Corp. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright   "2006-2014, MetaQuotes Software Corp."
#property link        "http://www.mql5.com"
#property description "Heiken Ashi indicator for MT5"
#property indicator_chart_window
#property indicator_buffers 5
#property indicator_plots   1

//--- plot HeikenAshi (DRAW_COLOR_CANDLESはOpen/High/Low/Closeの4バッファ+カラーバッファ1本の構成)
#property indicator_label1  "HA Open;HA High;HA Low;HA Close"
#property indicator_type1   DRAW_COLOR_CANDLES
#property indicator_color1  clrNONE, clrOrangeRed, clrDodgerBlue //0=陽線, 1=陰線
#property indicator_width1  1

//--- indicator buffers (平均足のOHLC用、DRAW_COLOR_CANDLESの仕様によりOpen→High→Low→Closeの順で登録すること)
double HAOpen[]; double HAHigh[]; double HALow[]; double HAClose[]; double HAColor[];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit(){
   IndicatorSetString(INDICATOR_SHORTNAME, "Heiken Ashi");
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

   //--- バッファ番号とグローバル配列を紐づける(DRAW_COLOR_CANDLESはOpen→High→Low→Closeの順で登録必須)
   SetIndexBuffer(0, HAOpen,  INDICATOR_DATA);
   SetIndexBuffer(1, HAHigh,  INDICATOR_DATA);
   SetIndexBuffer(2, HALow,   INDICATOR_DATA);
   SetIndexBuffer(3, HAClose, INDICATOR_DATA);
   SetIndexBuffer(4, HAColor, INDICATOR_COLOR_INDEX);

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, 1);
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);

return(INIT_SUCCEEDED);}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int prev_calculated, const datetime &time[], const double &open[], const double &high[], 
                const double &low[], const double &close[], const long &tick_volume[], const long &volume[], const int &spread[]){

   if( rates_total < 2 ){ return(0); } //バー本数が足りない場合は計算しない

   //--- このインジケーターはインデックス0=最古のバーという通常配列(シリーズ配列ではない)前提で計算する
   ArraySetAsSeries(HAOpen,  false);
   ArraySetAsSeries(HAHigh,  false);
   ArraySetAsSeries(HALow,   false);
   ArraySetAsSeries(HAClose, false);
   ArraySetAsSeries(HAColor, false);
   ArraySetAsSeries(open,    false);
   ArraySetAsSeries(high,    false);
   ArraySetAsSeries(low,     false);
   ArraySetAsSeries(close,   false);

   int start; //計算開始インデックス

   if( prev_calculated <= 1 ){
      //--- 最初のバーは実際の四本値をそのまま平均足の値として使用する
      HAOpen[0]  = open[0];
      HAClose[0] = close[0];
      HAHigh[0]  = high[0];
      HALow[0]   = low[0];
      HAColor[0] = (HAOpen[0] < HAClose[0]) ? 0.0 : 1.0;
      start = 1;
   }else{
      start = prev_calculated - 1;
   }

   for(int i = start; i < rates_total; i++){ //各バーに対してループ処理を行う

      double haOpen  = (HAOpen[i-1] + HAClose[i-1]) / 2.0; //1本前の平均足Open/Closeの中値を今回のOpenとする
      double haClose = (open[i] + high[i] + low[i] + close[i]) / 4.0; //実際の四本値の平均を今回のCloseとする
      double haHigh  = MathMax(high[i], MathMax(haOpen, haClose)); //実際の高値とhaOpen/haCloseの最大値を今回のHighとする
      double haLow   = MathMin(low[i],  MathMin(haOpen, haClose)); //実際の安値とhaOpen/haCloseの最小値を今回のLowとする

      HAOpen[i]  = haOpen;
      HAClose[i] = haClose;
      HAHigh[i]  = haHigh;
      HALow[i]   = haLow;

      if( haOpen > haClose ){ HAColor[i] = 1.0; }else{ HAColor[i] = 2.0; } //平均足の色を決定する(0=陽線/OrangeRed, 1=陰線/DodgerBlue)
   }

return(rates_total);}
//+------------------------------------------------------------------+