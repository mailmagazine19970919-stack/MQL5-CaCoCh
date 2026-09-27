//完成した為、保存用にノータッチで、コピペして使うように！
//2026年08月17日、Claudeで生成・修正。https://claude.ai/chat/ce278fc1-4a58-4b5a-a291-e83b049d73a9
//【2026/09/19 修正内容】
//2026年09月19日、Claude(モデルSonet/エフォート最大)でRsiDigtalKahlerをMql4をMql5へ変換。https://claude.ai/chat/e48fd52e-8065-453b-9a2b-8413f1b9bb22
//RsiDigtalKahlerをiCustomに組み込めるかを検証。
//+------------------------------------------------------------------+
//|                                              Colorful_Candle.mq5 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.01"
#property indicator_chart_window
#property indicator_buffers 7
#property indicator_plots   2

//--- plot Candle
#property indicator_label1  "Candle"
#property indicator_type1   DRAW_COLOR_CANDLES
#property indicator_color1  clrOrangeRed, clrDodgerBlue, clrNONE
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- plot Ma
#property indicator_label2  "Ma"
#property indicator_type2   DRAW_LINE
#property indicator_style2  STYLE_DOT
#property indicator_color2  clrOrangeRed, clrDodgerBlue, clrNONE
#property indicator_width2  1

//--- 外部インジケーターの読み込み設定(名前・パラメータは各自で指定すること。空文字なら未使用として無視する)
input string ExtInd1_Name = "MyModel(S)-HeikinAshiFilter"; //外部インジケーター1のパス
input string ExtInd2_Name = "MyModel(T)-CandleChangerTest"; //外部インジケーター2のパス //MyModel(S)-CandleStrenthFilter
input string ExtInd3_Name = "MyModel(S)-DigitalKahlerRsi"; //外部インジケーター3のパス
input string ExtInd4_Name = ""; //外部インジケーター4のパス
input string ExtInd5_Name = ""; //外部インジケーター5のパス

//--- 通知関連の設定
input bool EnableNotification = true; //ローソク足確定時にSendNotificationを送るかどうか

//--- 自己修復関連の設定
input int RecalcDepth = 10; //外部インジケーターの遅延に備え、毎ティック遡って再判定する本数(直近何本を再チェックするか)

//--- indicator buffers (ローソク足用)
double CandleBuffer1[]; double CandleBuffer2[]; double CandleBuffer3[]; double CandleBuffer4[]; double CandleColor[];

//--- indicator buffers (移動平均線用)
double MABuffer[]; double MaColor[]; int MaHandle;

//--- indicator buffers (iCustom用) 描画はしないので通常の配列でOK
double ExtInd1Buffer[]; double ExtInd2Buffer[]; double ExtInd3Buffer[]; double ExtInd4Buffer[]; double ExtInd5Buffer[];
int ExtInd1Handle; int ExtInd2Handle; int ExtInd3Handle; int ExtInd4Handle; int ExtInd5Handle;
bool ExtInd1Active = false; bool ExtInd2Active = false; bool ExtInd3Active = false; bool ExtInd4Active = false; bool ExtInd5Active = false;

//--- 今回のティックで実際に何本分のデータが取得できたか(これより外側のインデックスは信用しない)
int ExtInd1Copied = 0; int ExtInd2Copied = 0; int ExtInd3Copied = 0; int ExtInd4Copied = 0; int ExtInd5Copied = 0;

//--- 通知制御用の変数
datetime LastBarTime = 0; //直近で確認した最新バーの開始時刻(これが変化したら、1本前のバーが確定したと判定する)
bool IsFirstCalculation = true; //起動直後の一括計算時に、過去分の通知を一斉送信しないためのフラグ

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit(){
   //--- バッファ番号とグローバル配列を紐づける
   SetIndexBuffer(0,CandleBuffer1,INDICATOR_DATA);
   SetIndexBuffer(1,CandleBuffer2,INDICATOR_DATA);
   SetIndexBuffer(2,CandleBuffer3,INDICATOR_DATA);
   SetIndexBuffer(3,CandleBuffer4,INDICATOR_DATA);
   SetIndexBuffer(4,CandleColor,INDICATOR_COLOR_INDEX);

   SetIndexBuffer(5,MABuffer,INDICATOR_DATA);
   SetIndexBuffer(6,MaColor,INDICATOR_COLOR_INDEX);

   PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_COLOR_LINE);

   //--- 全てのバッファをシリーズ配列(index[0]が最新バー)に設定する
   ArraySetAsSeries(CandleBuffer1,true); 
   ArraySetAsSeries(CandleBuffer2,true);
   ArraySetAsSeries(CandleBuffer3,true);
   ArraySetAsSeries(CandleBuffer4,true);
   ArraySetAsSeries(CandleColor,true);
   ArraySetAsSeries(MABuffer,true);
   ArraySetAsSeries(MaColor,true);

   //--- 外部インジケーター用バッファもシリーズ配列にしておく
   ArraySetAsSeries(ExtInd1Buffer,true);
   ArraySetAsSeries(ExtInd2Buffer,true);
   ArraySetAsSeries(ExtInd3Buffer,true);
   ArraySetAsSeries(ExtInd4Buffer,true);
   ArraySetAsSeries(ExtInd5Buffer,true);

   //--- 移動平均線の指標ハンドルを取得する(これは必須なので失敗したら停止する)
   MaHandle = iMA(NULL,0,20,0,MODE_SMA,PRICE_CLOSE);
   if( MaHandle == INVALID_HANDLE ){ Print("移動平均線の指標ハンドルの取得に失敗しました。"); return(INIT_FAILED); }

   //--- 外部インジケーター5本のハンドルを取得する。名前が空文字の場合は未設定として読み込みをスキップする(失敗してもINIT_FAILEDにしない)
   //--- ※ここでのActiveは「名前が指定されていて、ハンドル取得に成功したか」だけを表す。毎ティックのCopyBufferが一時的に失敗しても、このActiveフラグはOnCalculate側では変更しない(要修正点①)。
   ExtInd1Handle = INVALID_HANDLE; ExtInd1Active = false;
   if( ExtInd1_Name != "" ){ ExtInd1Handle = iCustom(NULL,0,ExtInd1_Name); if( ExtInd1Handle == INVALID_HANDLE ){ Print("外部インジケーター1のハンドルの取得に失敗しました。未使用として続行します。"); }else{ ExtInd1Active = true; } }
   ExtInd2Handle = INVALID_HANDLE; ExtInd2Active = false; 
   if( ExtInd2_Name != "" ){ ExtInd2Handle = iCustom(NULL,0,ExtInd2_Name); if( ExtInd2Handle == INVALID_HANDLE ){ Print("外部インジケーター2のハンドルの取得に失敗しました。未使用として続行します。"); }else{ ExtInd2Active = true; } }
   ExtInd3Handle = INVALID_HANDLE; ExtInd3Active = false; 
   if( ExtInd3_Name != "" ){ ExtInd3Handle = iCustom(NULL,0,ExtInd3_Name); if( ExtInd3Handle == INVALID_HANDLE ){ Print("外部インジケーター3のハンドルの取得に失敗しました。未使用として続行します。"); }else{ ExtInd3Active = true; } }
   ExtInd4Handle = INVALID_HANDLE;  ExtInd4Active = false; 
   if( ExtInd4_Name != "" ){ ExtInd4Handle = iCustom(NULL,0,ExtInd4_Name); if( ExtInd4Handle == INVALID_HANDLE ){ Print("外部インジケーター4のハンドルの取得に失敗しました。未使用として続行します。"); }else{ ExtInd4Active = true; } }
   ExtInd5Handle = INVALID_HANDLE;  ExtInd5Active = false;
   if( ExtInd5_Name != "" ){ ExtInd5Handle = iCustom(NULL,0,ExtInd5_Name); if( ExtInd5Handle == INVALID_HANDLE ){ Print("外部インジケーター5のハンドルの取得に失敗しました。未使用として続行します。"); }else{ ExtInd5Active = true; } }
   
   //--- 通知制御用の変数を初期化する(この時点ではまだ何もしない。実際の基準時刻はOnCalculateの初回呼び出し時に記録する)
   LastBarTime = 0; IsFirstCalculation = true;

return(INIT_SUCCEEDED);}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit( const int reason ){ //使用した指標ハンドルを解放する(未使用のものはInvalidHandleなので何もしない)
   IndicatorRelease(MaHandle);
   if( ExtInd1Handle != INVALID_HANDLE ){ IndicatorRelease(ExtInd1Handle); }
   if( ExtInd2Handle != INVALID_HANDLE ){ IndicatorRelease(ExtInd2Handle); }
   if( ExtInd3Handle != INVALID_HANDLE ){ IndicatorRelease(ExtInd3Handle); }
   if( ExtInd4Handle != INVALID_HANDLE ){ IndicatorRelease(ExtInd4Handle); }
   if( ExtInd5Handle != INVALID_HANDLE ){ IndicatorRelease(ExtInd5Handle); }
}
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int prev_calculated, const datetime &time[], const double &open[], const double &high[], 
                const double &low[], const double &close[], const long &tick_volume[], const long &volume[], const int &spread[]){
                
   ArraySetAsSeries(open,true); ArraySetAsSeries(high,true); ArraySetAsSeries(low,true); ArraySetAsSeries(close,true); ArraySetAsSeries(time,true); //OnCalculateに渡される価格配列もシリーズ配列に設定する(timeも新規バー判定に使うので追加)

   int limit = rates_total - prev_calculated; //計算対象の本数(limit)を求める
   if( prev_calculated == 0 ){ limit = rates_total - 1; } //初回計算の場合は、最古の1本を除いた本数にする

   //--- 【修正点②】外部インジケーター側の計算タイミングのズレに備え、直近RecalcDepth本は毎ティック無条件で再判定する。これにより一時的な取得失敗があっても数ティック以内に自動的に正しい色へ上書きされる(自己修復)。
   if( limit < RecalcDepth ){ limit = RecalcDepth; }

   if( limit > rates_total - 1 ){ limit = rates_total - 1; } if( limit < 1 ){ limit = 1; }

   int copiedCount = CopyBuffer(MaHandle,0,0,rates_total,MABuffer); if( copiedCount <= 0 ){ return(prev_calculated); } //移動平均線のデータを一括で取得する(必須なので失敗したら計算を中断する)

   //--- 【修正点①】外部インジケーターのデータを一括で取得する。これまでは1回でも取得(CopyBuffer)に失敗すると Active=false のまま二度と取得を試みなくなっていたが、それを廃止し「名前が設定されハンドルが取得できている限り毎ティック再挑戦する」方式に変更。
   //--- 取得できた本数(Copiedカウント)だけを信用し、それより新しい/古いインデックスの値は判定に使わない(古いデータを誤って使うのを防止)。
   ExtInd1Copied = 0; if( ExtInd1Active == true ){ ExtInd1Copied = CopyBuffer(ExtInd1Handle,4,0,rates_total,ExtInd1Buffer); if( ExtInd1Copied < 0 ){ ExtInd1Copied = 0; } }
   ExtInd2Copied = 0; if( ExtInd2Active == true ){ ExtInd2Copied = CopyBuffer(ExtInd2Handle,0,0,rates_total,ExtInd2Buffer); if( ExtInd2Copied < 0 ){ ExtInd2Copied = 0; } }
   ExtInd3Copied = 0; if( ExtInd3Active == true ){ ExtInd3Copied = CopyBuffer(ExtInd3Handle,3,0,rates_total,ExtInd3Buffer); if( ExtInd3Copied < 0 ){ ExtInd3Copied = 0; } }
   ExtInd4Copied = 0; if( ExtInd4Active == true ){ ExtInd4Copied = CopyBuffer(ExtInd4Handle,0,0,rates_total,ExtInd4Buffer); if( ExtInd4Copied < 0 ){ ExtInd4Copied = 0; } }
   ExtInd5Copied = 0; if( ExtInd5Active == true ){ ExtInd5Copied = CopyBuffer(ExtInd5Handle,0,0,rates_total,ExtInd5Buffer); if( ExtInd5Copied < 0 ){ ExtInd5Copied = 0; } }

   //--- 新しいバーが立ったかどうかを判定する(time[0]が前回と変わっていれば、1本前のバーが確定した瞬間)
   bool IsNewBar = false;
   if( IsFirstCalculation == true ){ LastBarTime = time[0]; IsFirstCalculation = false; } //起動直後の一括計算では、基準時刻を記録するだけで通知はしない
   else if( LastBarTime != time[0] ){ IsNewBar = true; LastBarTime = time[0]; } //基準時刻を更新し、今回だけ通知対象とする

   for(int i = limit - 1; i >= 0; i--){ //各バーに対してループ処理を行う
      
      CandleBuffer1[i] = open[i]; CandleBuffer2[i] = high[i]; CandleBuffer3[i] = low[i]; CandleBuffer4[i] = close[i]; //ローソク足の四本値をバッファにコピーする
      bool UpTr = false; bool DnTr = false; bool UpDp = false; bool DnDp = false; //判定用の変数を初期化する
      
      if( i < ExtInd3Copied ){
      if( ExtInd3Buffer[i] ==  1 ){ UpTr = true; }else{ UpTr = false; }   //移動平均線が上昇しているかどうかを判定する 
      if( ExtInd3Buffer[i] == -1 ){ DnTr = true; }else{ DnTr = false; } } //移動平均線が下降しているかどうかを判定する 
      
      //--- 外部インジケーターの値が実際に取得できているインデックス範囲内(i+1 < Copied件数)の時だけ判定に使う。範囲外(未取得/失敗)の場合はUpDp/DnDpをfalseのままにし、次のティックの再判定(RecalcDepth)に委ねる。
      
      if( (i+1) < ExtInd1Copied && i < ExtInd2Copied ){
         if( ExtInd1Buffer[i+1] == 1 && ExtInd2Buffer[i] == 1 ){ UpDp = true; }else{ UpDp = false; }   // && ExtInd2Buffer[i] == 1
         if( ExtInd1Buffer[i+1] == 2 && ExtInd2Buffer[i] == 2 ){ DnDp = true; }else{ DnDp = false; } } // && ExtInd2Buffer[i] == 2

      if( UpTr == true ){ MaColor[i] = 0; }else if( DnTr == true ){ MaColor[i] = 1; }else{ MaColor[i] = 2; } //移動平均線の色を決定する
      if( UpTr == true && UpDp == true && CandleColor[i+1] != 0 ){ CandleColor[i] = 0; }else if( DnTr == true && DnDp == true && CandleColor[i+1] != 1 ){ CandleColor[i] = 1; }else{ CandleColor[i] = 2; } //ローソク足の色を決定する(直前の足と同色連続を禁止) 
  
   }

   //--- ローソク足が確定した瞬間(IsNewBar==true)だけ、1本前のバー(index[1]。ちょうど確定した色)についてSendNotificationを送る
   if( EnableNotification == true && IsNewBar == true ){
      string barTimeStr = TimeToString(time[1], TIME_DATE|TIME_MINUTES); //確定したバーの開始時刻
      if( CandleColor[1] == 0 ){ SendNotification(_Symbol + " " + EnumToString((ENUM_TIMEFRAMES)_Period) + "：買い" + barTimeStr); } //陽線(上昇)確定時の通知
      else if( CandleColor[1] == 1 ){ SendNotification(_Symbol + " " + EnumToString((ENUM_TIMEFRAMES)_Period) + "：売り" + barTimeStr); } //陰線(下降)確定時の通知
      //CandleColor[1] == 2 (どちらでもない)の場合は通知しない
   }

   return(rates_total);}
//+------------------------------------------------------------------