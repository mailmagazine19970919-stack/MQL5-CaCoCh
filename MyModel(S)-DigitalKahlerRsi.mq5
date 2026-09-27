//------------------------------------------------------------------
#property copyright "mladen"
#property link      "www.forex-station.com"
//------------------------------------------------------------------
// Converted from MQL4 to MQL5
//------------------------------------------------------------------
#property indicator_separate_window
#property indicator_buffers 5
#property indicator_plots   3
#property indicator_color1  clrLimeGreen
#property indicator_color2  clrOrange
#property indicator_color3  clrOrange
#property indicator_width1  3
#property indicator_width2  3
#property indicator_width3  3
#property indicator_type1   DRAW_LINE
#property indicator_type2   DRAW_LINE
#property indicator_type3   DRAW_LINE
#property indicator_label1  "rsi digital Kahler"
#property indicator_label2  "trend down"
#property indicator_label3  "trend down"
 
input int                 period     = 14;          // Calculating period
input ENUM_APPLIED_PRICE  price      = PRICE_CLOSE;  // Price
input int                 speriod    = 14;          // Smoothing period
input ENUM_MA_METHOD      smethod    = MODE_SMA;     // Smoothing method
input int                 linesWidth = 3;            // Lines width
input double              fastr      = 8;            // Fast ratio
input double              slowr      = 22;           // Slow ratio
 
double buffer[];
double bufferda[];
double bufferdb[];
double trend[];
double work[];
 
double workEma[][1];
int    handle_rsi = INVALID_HANDLE;
 
//------------------------------------------------------------------
//
//------------------------------------------------------------------
int OnInit()
{
   SetIndexBuffer(0,buffer,  INDICATOR_DATA);
   SetIndexBuffer(1,bufferda,INDICATOR_DATA);
   SetIndexBuffer(2,bufferdb,INDICATOR_DATA);
   SetIndexBuffer(3,trend,   INDICATOR_CALCULATIONS);
   SetIndexBuffer(4,work,    INDICATOR_CALCULATIONS);
 
   PlotIndexSetInteger(0,PLOT_LINE_WIDTH,linesWidth);
   PlotIndexSetInteger(1,PLOT_LINE_WIDTH,linesWidth);
   PlotIndexSetInteger(2,PLOT_LINE_WIDTH,linesWidth);
 
   PlotIndexSetDouble(0,PLOT_EMPTY_VALUE,EMPTY_VALUE);
   PlotIndexSetDouble(1,PLOT_EMPTY_VALUE,EMPTY_VALUE);
   PlotIndexSetDouble(2,PLOT_EMPTY_VALUE,EMPTY_VALUE);
 
   handle_rsi = iRSI(_Symbol,_Period,period,price);
   if(handle_rsi==INVALID_HANDLE)
     {
      Print("rsi digital Kahler: failed to create RSI handle");
      return(INIT_FAILED);
     }
 
   IndicatorSetString(INDICATOR_SHORTNAME,"rsi digital Kahler ("+(string)period+","+(string)speriod+")");
   return(INIT_SUCCEEDED);
}
 
//------------------------------------------------------------------
//
//------------------------------------------------------------------
void OnDeinit(const int reason)
{
   if(handle_rsi!=INVALID_HANDLE) IndicatorRelease(handle_rsi);
}
 
//------------------------------------------------------------------
//
//------------------------------------------------------------------
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
   if(rates_total<3) return(0);
   if(BarsCalculated(handle_rsi)<rates_total) return(0);
 
   ArraySetAsSeries(buffer,  true);
   ArraySetAsSeries(bufferda,true);
   ArraySetAsSeries(bufferdb,true);
   ArraySetAsSeries(trend,   true);
   ArraySetAsSeries(work,    true);
 
   int counted_bars=prev_calculated;
   if(counted_bars>0) counted_bars--;
   int limit=(int)MathMin(rates_total-counted_bars,rates_total-2);
   if(limit<0) return(0);
 
   if(CopyBuffer(handle_rsi,0,0,limit+1,work)<=0) return(0);
 
   if(trend[limit]==-1) CleanPoint(limit,bufferda,bufferdb);
 
   for(int i=limit; i>=0; i--)
     {
      double fast_k = work[i];
      double slow_k = CalculateMAOnArray(work,0,speriod,0,smethod,i);
      double temp   = 0;
      if((slowr*slow_k+fastr*fast_k)/(fastr+slowr)>50.0) temp= 1;
      if((slowr*slow_k+fastr*fast_k)/(fastr+slowr)<50.0) temp=-1;
 
      buffer[i]   = iEma(temp,period,i,rates_total);
      bufferda[i] = EMPTY_VALUE;
      bufferdb[i] = EMPTY_VALUE;
      trend[i]    = trend[i+1];
 
      if(buffer[i]>buffer[i+1]) trend[i]= 1;
      if(buffer[i]<buffer[i+1]) trend[i]=-1;
      if(trend[i]==-1) PlotPoint(i,bufferda,bufferdb,buffer,rates_total);
     }
   return(rates_total);
}
 
//------------------------------------------------------------------
// Replacement for MQL4's iMAOnArray() - this function does not
// exist in MQL5, so it is reimplemented here (SMA/EMA/SMMA/LWMA).
//------------------------------------------------------------------
double CalculateMAOnArray(double &array[],int total,int ma_period,int ma_shift,int ma_method,int shift)
{
   if(total==0) total=ArraySize(array);
   if(ma_period<=0) return(0.0);
 
   int pos=shift+ma_shift;
   if(pos<0 || pos+ma_period>total) return(0.0);
 
   double result=0.0;
   switch(ma_method)
     {
      case MODE_SMA:
        {
         double sum=0.0;
         for(int k=0;k<ma_period;k++) sum+=array[pos+k];
         result=sum/ma_period;
         break;
        }
      case MODE_LWMA:
        {
         double lsum=0.0; int lweight=0;
         for(int k=0;k<ma_period;k++)
           {
            int weight=ma_period-k;
            lweight+=weight;
            lsum+=array[pos+k]*weight;
           }
         result=(lweight>0) ? lsum/lweight : 0.0;
         break;
        }
      case MODE_EMA:
        {
         double alpha=2.0/(1.0+ma_period);
         double prev=array[total-1];
         for(int k=total-2;k>=pos;k--)
            prev=prev+alpha*(array[k]-prev);
         result=prev;
         break;
        }
      case MODE_SMMA:
        {
         double sum=0.0;
         int startPos=total-ma_period;
         if(startPos<0) startPos=0;
         for(int k=total-1;k>=startPos;k--) sum+=array[k];
         double prev=sum/ma_period;
         for(int k=startPos-1;k>=pos;k--)
            prev=(prev*(ma_period-1)+array[k])/ma_period;
         result=prev;
         break;
        }
      default:
         result=0.0;
         break;
     }
   return(result);
}
 
//------------------------------------------------------------------
// Custom recursive EMA used to smooth the +1/-1 digital signal
// (kept from the original code; Bars -> total parameter for MQL5)
//------------------------------------------------------------------
double iEma(double tprice,double eperiod,int r,int total,int instanceNo=0)
{
   if(ArrayRange(workEma,0)!=total) ArrayResize(workEma,total);
   r=total-r-1;
 
   double alpha=2.0/(1.0+eperiod);
   workEma[r][instanceNo]=workEma[r-1][instanceNo]+alpha*(tprice-workEma[r-1][instanceNo]);
   return(workEma[r][instanceNo]);
}
 
//-------------------------------------------------------------------
//
//-------------------------------------------------------------------
void CleanPoint(int i,double &first[],double &second[])
{
   if((second[i]!=EMPTY_VALUE) && (second[i+1]!=EMPTY_VALUE))
      second[i+1]=EMPTY_VALUE;
   else
      if((first[i]!=EMPTY_VALUE) && (first[i+1]!=EMPTY_VALUE) && (first[i+2]==EMPTY_VALUE))
         first[i+1]=EMPTY_VALUE;
}
 
void PlotPoint(int i,double &first[],double &second[],double &from[],int total)
{
   if(i>=total-2) return;
   if(first[i+1]==EMPTY_VALUE)
     {
      if(first[i+2]==EMPTY_VALUE)
            { first[i]=from[i]; first[i+1]=from[i+1]; second[i]=EMPTY_VALUE; }
      else  { second[i]=from[i]; second[i+1]=from[i+1]; first[i]=EMPTY_VALUE; }
     }
   else  { first[i]=from[i]; second[i]=EMPTY_VALUE; }
}
 