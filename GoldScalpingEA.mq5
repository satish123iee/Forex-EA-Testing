//+------------------------------------------------------------------+
//|                                               Gold_Scalper_AI.mq5 |
//|                              Copyright 2025, Your Name            |
//|                                      https://www.yoursite.com     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Winyu"
#property link      "https://www.facebook.com/WinyuWeb"
#property version   "1.00"
#property strict

// รวม include files ที่จำเป็น
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

// คลาส CTrade สำหรับการเปิด/ปิดออเดอร์
CTrade         Trade;
CPositionInfo  PositionInfo;

// Input Parameters
input string   Symbol_Name = "XAUUSD";     // สัญลักษณ์การเทรด (ทอง)
input ENUM_TIMEFRAMES Timeframe = PERIOD_M5; // timeframe สำหรับการวิเคราะห์
input double   TradeVolume = 0.01;        // ขนาดการเทรดคงที่ (lot)
input int      StopLoss = 50;             // Stop Loss (points)
input int      TakeProfit = 75;          // Take Profit (points)
input int      Slippage = 3;              // Slippage ที่ยอมรับได้ (points)
input bool     UseTrailingStop = true;    // ใช้ Trailing Stop หรือไม่
input int      TrailingStop = 30;         // ระยะ Trailing Stop (points)
input int      TrailingStep = 10;         // ระยะ Trailing Step (points)
input int      MaxSpread = 30;            // Spread สูงสุดที่ยอมรับได้ (points)
input int      MagicNumber = 987654;      // Magic Number
input bool     UseFixedSLTP = true;       // ใช้ SL/TP แบบคงที่ (true) หรือแบบไดนามิก (false)
input string   AIApiKey = ""; // DeepSeek AI API Key
input string   AIEndpoint = "https://api.deepseek.ai/v1/chat/completions"; // DeepSeek AI API Endpoint

// เอาตัวแปรเกี่ยวกับ Martingale และ Risk Percent ออก
// input bool     Use_Martingale = false;     // ใช้ระบบ Martingale
// input double   Martingale_Multiplier = 2.0;// ตัวคูณ Martingale
// input double   Risk_Percent = 2.0;         // เปอร์เซ็นต์ความเสี่ยงต่อเงินทุน (%)

// Global Variables
int handle_macd;
int handle_rsi;
int handle_atr;
int handle_ema_fast;
int handle_ema_slow;
double macd_buffer[];
double macd_signal_buffer[];
double rsi_buffer[];
double atr_buffer[];
double ema_fast_buffer[];
double ema_slow_buffer[];
datetime lastBarTime = 0;
bool isNewBar = false;
int RSI_Period = 14;
double RSI_OverBought = 70.0;
double RSI_OverSold = 30.0;
int MA_Fast_Period = 20;
int MA_Slow_Period = 50;
int ATR_Period = 14;
double ATR_Multiplier = 1.5;
bool IsTradingAllowed = true;
double PointSize;

// ลบตัวแปร LossCount เนื่องจากไม่ได้ใช้ Martingale แล้ว
// int LossCount = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Check Symbol
   if(Symbol() != Symbol_Name)
   {
      Print("EA ต้องทำงานบนชาร์ต ", Symbol_Name, " เท่านั้น!");
      return INIT_FAILED;
   }
   
   // ตั้งค่าความแม่นยำ
   PointSize = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
   
   // Initialize indicators
   handle_macd = iMACD(Symbol_Name, Timeframe, 12, 26, 9, PRICE_CLOSE);
   handle_rsi = iRSI(Symbol_Name, Timeframe, RSI_Period, PRICE_CLOSE);
   handle_atr = iATR(Symbol_Name, Timeframe, ATR_Period);
   handle_ema_fast = iMA(Symbol_Name, Timeframe, MA_Fast_Period, 0, MODE_EMA, PRICE_CLOSE);
   handle_ema_slow = iMA(Symbol_Name, Timeframe, MA_Slow_Period, 0, MODE_EMA, PRICE_CLOSE);
   
   if(handle_macd == INVALID_HANDLE || handle_rsi == INVALID_HANDLE || 
      handle_atr == INVALID_HANDLE || handle_ema_fast == INVALID_HANDLE || 
      handle_ema_slow == INVALID_HANDLE)
   {
      Print("เกิดข้อผิดพลาดในการสร้างตัวชี้วัด");
      return INIT_FAILED;
   }
   
   // Initialize arrays
   ArraySetAsSeries(macd_buffer, true);
   ArraySetAsSeries(macd_signal_buffer, true);
   ArraySetAsSeries(rsi_buffer, true);
   ArraySetAsSeries(atr_buffer, true);
   ArraySetAsSeries(ema_fast_buffer, true);
   ArraySetAsSeries(ema_slow_buffer, true);
   
   // Check if we can trade
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
   {
      Print("การเทรดไม่ได้รับอนุญาตในเทอร์มินัล");
      return INIT_FAILED;
   }
   
   if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED))
   {
      Print("การเทรดไม่ได้รับอนุญาตสำหรับบัญชีนี้");
      return INIT_FAILED;
   }
   
   // Check if WebRequest is allowed
   bool web_requests_allowed = false;
   
   // Try to check using GetLastError method
   string headers = "";
   char data[], result[];
   int dummy_res = WebRequest("GET", "https://www.google.com", headers, 500, data, result, headers);
   int error_code = GetLastError();
   
   // If error is 4060, WebRequest is allowed but URL is not in the list
   // If error is 4014, connection failed (which means WebRequest is allowed)
   if(error_code == 4060 || error_code == 4014)
   {
      web_requests_allowed = true;
   }
   
   if(!web_requests_allowed)
   {
      Print("คำเตือน: WebRequest ไม่ได้รับอนุญาตในเทอร์มินัล");
      Print("กรุณาเปิดใช้งาน WebRequest และเพิ่ม URL: ", AIEndpoint);
      Print("วิธีตั้งค่า: Tools -> Options -> Expert Advisors -> Allow WebRequest for listed URL");
      // We'll continue anyway, as we have a fallback mechanism
   }
   else
   {
      Print("WebRequest ได้รับอนุญาตแล้ว อย่าลืมเพิ่ม URL ของ DeepSeek AI ในรายการที่อนุญาตด้วย");
   }
   
   // Check if trade volume is valid
   double min_volume = SymbolInfoDouble(Symbol_Name, SYMBOL_VOLUME_MIN);
   double max_volume = SymbolInfoDouble(Symbol_Name, SYMBOL_VOLUME_MAX);
   double step_volume = SymbolInfoDouble(Symbol_Name, SYMBOL_VOLUME_STEP);
   
   if(TradeVolume < min_volume || TradeVolume > max_volume || 
      MathAbs(fmod(TradeVolume, step_volume)) > 0.00001)
   {
      Print("ขนาดการเทรดไม่ถูกต้อง: ", TradeVolume);
      Print("ขนาดต่ำสุด: ", min_volume, ", ขนาดสูงสุด: ", max_volume, ", ขนาดขั้น: ", step_volume);
      return INIT_FAILED;
   }
   
   // Set trade parameters
   Trade.SetExpertMagicNumber(MagicNumber); // Magic number สำหรับ EA นี้
   
   Print("Gold Scalper AI เริ่มต้นสำเร็จ! คู่เงิน: ", Symbol_Name);
   return INIT_SUCCEEDED;
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Release indicator handles
   if(handle_macd != INVALID_HANDLE) IndicatorRelease(handle_macd);
   if(handle_rsi != INVALID_HANDLE) IndicatorRelease(handle_rsi);
   if(handle_atr != INVALID_HANDLE) IndicatorRelease(handle_atr);
   if(handle_ema_fast != INVALID_HANDLE) IndicatorRelease(handle_ema_fast);
   if(handle_ema_slow != INVALID_HANDLE) IndicatorRelease(handle_ema_slow);
   
   // Clear chart comment
   Comment("");
   
   Print("Gold Scalper AI ปิดการทำงาน, เหตุผล: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // ตรวจสอบสภาวะตลาด
   if(!IsTradeAllowed())
      return;
      
   // Check for a new bar
   isNewBar = IsNewBar();
   
   // Only run analysis on a new bar
   if(isNewBar)
   {
      // Update indicators
      if(!UpdateIndicators())
      {
         Print("เกิดข้อผิดพลาดในการอัพเดตตัวชี้วัด");
         return;
      }
      
      // Prepare market data for AI analysis
      string market_data = PrepareDataForAI();
      
      // Get trading decision from DeepSeek AI or fallback to technical analysis
      string decision;
      if(market_data != "")
      {
         decision = GetAIDecision(market_data);
         Print("AI แนะนำให้: ", decision);
      }
      else
      {
         decision = FallbackTechnicalDecision();
         Print("ใช้การตัดสินใจจากการวิเคราะห์ทางเทคนิค: ", decision);
      }
      
      // Execute trading decisions
      ExecuteTradingDecision(decision);
   }
   
   // ตรวจสอบและปรับ Trailing Stop
   if(UseTrailingStop)
   {
      ManageTrailingStop();
   }
}

//+------------------------------------------------------------------+
//| Check for new bar                                                |
//+------------------------------------------------------------------+
bool IsNewBar()
{
   datetime current_time = iTime(Symbol_Name, Timeframe, 0);
   if(current_time != lastBarTime)
   {
      lastBarTime = current_time;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| อัปเดตข้อมูลตัวบ่งชี้                                              |
//+------------------------------------------------------------------+
bool UpdateIndicators()
{
   // เพิ่มการตรวจสอบความถูกต้องของ handle
   if(handle_macd == INVALID_HANDLE || handle_rsi == INVALID_HANDLE || 
      handle_atr == INVALID_HANDLE || handle_ema_fast == INVALID_HANDLE || 
      handle_ema_slow == INVALID_HANDLE)
   {
      Print("มี handle ไม่ถูกต้อง, ไม่สามารถอัปเดตตัวชี้วัดได้");
      return false;
   }
   
   // จองพื้นที่และตั้งค่าอาร์เรย์ก่อนเพื่อให้แน่ใจว่ามีพื้นที่เพียงพอ
   ArrayResize(macd_buffer, 10);
   ArrayResize(macd_signal_buffer, 10);
   ArrayResize(rsi_buffer, 10);
   ArrayResize(atr_buffer, 10);
   ArrayResize(ema_fast_buffer, 10);
   ArrayResize(ema_slow_buffer, 10);
   
   // ตรวจสอบ Timeframe ที่ใช้ว่าถูกต้องหรือไม่
   if(!ChartPeriodToString(Timeframe))
   {
      Print("Timeframe ไม่ถูกต้อง: ", Timeframe);
      return false;
   }
   
   // Copy indicator data to buffers และตรวจสอบจำนวนที่คัดลอกมา
   int macd_copied = CopyBuffer(handle_macd, 0, 0, 5, macd_buffer);
   int macd_signal_copied = CopyBuffer(handle_macd, 1, 0, 5, macd_signal_buffer);
   int rsi_copied = CopyBuffer(handle_rsi, 0, 0, 5, rsi_buffer);
   int atr_copied = CopyBuffer(handle_atr, 0, 0, 5, atr_buffer);
   int ema_fast_copied = CopyBuffer(handle_ema_fast, 0, 0, 5, ema_fast_buffer);
   int ema_slow_copied = CopyBuffer(handle_ema_slow, 0, 0, 5, ema_slow_buffer);
   
   // ตรวจสอบว่าคัดลอกได้อย่างน้อย 3 ค่า
   if(macd_copied < 3 || macd_signal_copied < 3 || rsi_copied < 3 || 
      atr_copied < 3 || ema_fast_copied < 3 || ema_slow_copied < 3)
   {
      Print("ไม่สามารถคัดลอกข้อมูลตัวชี้วัดได้เพียงพอ, ได้: ",
            "MACD=", macd_copied, ", Signal=", macd_signal_copied, ", RSI=", rsi_copied,
            ", ATR=", atr_copied, ", EMA Fast=", ema_fast_copied, ", EMA Slow=", ema_slow_copied);
      return false;
   }
   
   // ตรวจสอบว่าอาร์เรย์มีข้อมูลจริงหรือไม่
   if(ArraySize(macd_buffer) < 3 || ArraySize(macd_signal_buffer) < 3 || 
      ArraySize(rsi_buffer) < 3 || ArraySize(atr_buffer) < 3 || 
      ArraySize(ema_fast_buffer) < 3 || ArraySize(ema_slow_buffer) < 3)
   {
      Print("ขนาดอาร์เรย์ไม่เพียงพอหลังจาก CopyBuffer");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| ตรวจสอบว่าการเทรดได้รับอนุญาตหรือไม่                                |
//+------------------------------------------------------------------+
bool IsTradeAllowed()
{
   // ตรวจสอบ Spread
   if(SymbolInfoInteger(Symbol(), SYMBOL_SPREAD) > MaxSpread)
   {
      Comment("Spread สูงเกินไป: ", SymbolInfoInteger(Symbol(), SYMBOL_SPREAD), " > ", MaxSpread);
      return false;
   }
   
   // ตรวจสอบเวลาตลาดและการอนุญาตการเทรด
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED))
   {
      Comment("การเทรดไม่ได้รับอนุญาต");
      return false;
   }
   
   return IsTradingAllowed;
}

//+------------------------------------------------------------------+
//| Prepare market data for AI analysis                              |
//+------------------------------------------------------------------+
string PrepareDataForAI()
{
   // Get recent price data
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(Symbol_Name, Timeframe, 0, 30, rates); // เพิ่มจำนวนแท่งที่คัดลอกเพื่อความปลอดภัย
   if(copied < 20)
   {
      Print("เกิดข้อผิดพลาดในการคัดลอกข้อมูลราคา, คัดลอกได้ ", copied, " จาก 20");
      return "";
   }
   
   // ตรวจสอบจำนวนข้อมูลในบัฟเฟอร์
   int buffer_size = ArraySize(macd_buffer);
   if(buffer_size < 3 || ArraySize(macd_signal_buffer) < 3 || 
      ArraySize(rsi_buffer) < 3 || ArraySize(atr_buffer) < 3 || 
      ArraySize(ema_fast_buffer) < 3 || ArraySize(ema_slow_buffer) < 3)
   {
      Print("ขนาดบัฟเฟอร์ไม่เพียงพอสำหรับการวิเคราะห์: MACD=", ArraySize(macd_buffer), 
            ", Signal=", ArraySize(macd_signal_buffer), 
            ", RSI=", ArraySize(rsi_buffer), 
            ", ATR=", ArraySize(atr_buffer), 
            ", EMA Fast=", ArraySize(ema_fast_buffer), 
            ", EMA Slow=", ArraySize(ema_slow_buffer));
      return "";
   }
   
   // ตรวจสอบว่าอาร์เรย์ถูกตั้งค่าเป็น AsSeries หรือไม่
   if(!ArrayGetAsSeries(macd_buffer) || !ArrayGetAsSeries(macd_signal_buffer) || 
      !ArrayGetAsSeries(rsi_buffer) || !ArrayGetAsSeries(atr_buffer) || 
      !ArrayGetAsSeries(ema_fast_buffer) || !ArrayGetAsSeries(ema_slow_buffer))
   {
      Print("อาร์เรย์ไม่ได้ตั้งค่าเป็น AsSeries");
      ArraySetAsSeries(macd_buffer, true);
      ArraySetAsSeries(macd_signal_buffer, true);
      ArraySetAsSeries(rsi_buffer, true);
      ArraySetAsSeries(atr_buffer, true);
      ArraySetAsSeries(ema_fast_buffer, true);
      ArraySetAsSeries(ema_slow_buffer, true);
   }
   
   // Get current market status - ใช้การเข้าถึงอย่างปลอดภัย
   double current_price = copied > 0 ? rates[0].close : 0;
   double macd_current = buffer_size > 0 ? macd_buffer[0] : 0;
   double macd_signal = ArraySize(macd_signal_buffer) > 0 ? macd_signal_buffer[0] : 0;
   double rsi_current = ArraySize(rsi_buffer) > 0 ? rsi_buffer[0] : 50; // ค่ากลางเป็นค่าปลอดภัย
   double atr_current = ArraySize(atr_buffer) > 0 ? atr_buffer[0] : 0;
   double ema_fast_current = ArraySize(ema_fast_buffer) > 0 ? ema_fast_buffer[0] : 0;
   double ema_slow_current = ArraySize(ema_slow_buffer) > 0 ? ema_slow_buffer[0] : 0;
   
   // Calculate current trends and patterns
   string trend_direction = (ema_fast_current > ema_slow_current) ? "bullish" : "bearish";
   string macd_status = (macd_current > macd_signal) ? "bullish" : "bearish";
   string rsi_status = "";
   if(rsi_current > 70) rsi_status = "overbought";
   else if(rsi_current < 30) rsi_status = "oversold";
   else rsi_status = "neutral";
   
   // Check candlestick patterns - ตรวจสอบว่า rates มีข้อมูลเพียงพอ
   string candle_patterns = "[]";
   if(copied >= 3)
   {
      candle_patterns = IdentifyCandlestickPatterns(rates);
   }
   
   // Get support and resistance levels - ตรวจสอบว่า rates มีข้อมูลเพียงพอ
   string support_resistance = "{\"resistance\":[],\"support\":[],\"highest_high\":0,\"lowest_low\":0}";
   if(copied >= 20)
   {
      support_resistance = IdentifySupportResistance(rates);
   }
   
   // Check current open positions
   int buy_positions = CountPositions(POSITION_TYPE_BUY);
   int sell_positions = CountPositions(POSITION_TYPE_SELL);
   
   // Format data as JSON
   string json = "{";
   json += "\"symbol\":\"" + Symbol_Name + "\",";
   json += "\"timeframe\":\"" + EnumToString(Timeframe) + "\",";
   json += "\"current_price\":" + DoubleToString(current_price, _Digits) + ",";
   
   // Technical indicators
   json += "\"indicators\":{";
   json += "\"macd_current\":" + DoubleToString(macd_current, 5) + ",";
   json += "\"macd_signal\":" + DoubleToString(macd_signal, 5) + ",";
   json += "\"macd_status\":\"" + macd_status + "\",";
   json += "\"rsi_current\":" + DoubleToString(rsi_current, 2) + ",";
   json += "\"rsi_status\":\"" + rsi_status + "\",";
   json += "\"atr_current\":" + DoubleToString(atr_current, 5) + ",";
   json += "\"ema_fast\":" + DoubleToString(ema_fast_current, _Digits) + ",";
   json += "\"ema_slow\":" + DoubleToString(ema_slow_current, _Digits) + ",";
   json += "\"trend_direction\":\"" + trend_direction + "\"";
   json += "},";
   
   // Candlestick patterns
   json += "\"candle_patterns\":" + candle_patterns + ",";
   
   // Support and resistance
   json += "\"support_resistance\":" + support_resistance + ",";
   
   // Current positions
   json += "\"positions\":{";
   json += "\"buy_count\":" + IntegerToString(buy_positions) + ",";
   json += "\"sell_count\":" + IntegerToString(sell_positions);
   json += "},";
   
   // Recent price data - ตรวจสอบว่ามีข้อมูลเพียงพอ
   json += "\"recent_prices\":[";
   int max_price_records = MathMin(10, copied); // ใช้แท่งเทียนที่มีอยู่จริง ไม่เกิน 10 แท่ง
   for(int i = 0; i < max_price_records; i++)
   {
      if(i > 0) json += ",";
      json += "{";
      json += "\"time\":\"" + TimeToString(rates[i].time) + "\",";
      json += "\"open\":" + DoubleToString(rates[i].open, _Digits) + ",";
      json += "\"high\":" + DoubleToString(rates[i].high, _Digits) + ",";
      json += "\"low\":" + DoubleToString(rates[i].low, _Digits) + ",";
      json += "\"close\":" + DoubleToString(rates[i].close, _Digits) + ",";
      json += "\"volume\":" + IntegerToString(rates[i].tick_volume);
      json += "}";
   }
   json += "]";
   
   json += "}";
   
   return json;
}
//+------------------------------------------------------------------+
//| Get error description                                            |
//+------------------------------------------------------------------+
string GetErrorDescription(int error_code)
{
   switch(error_code)
   {
      case 4014: return "ERR_HTTP_ERROR - HTTP request failed";
      case 4060: return "ERR_WEBREQUEST_INVALID_ADDRESS - URL not allowed";
      case 4061: return "ERR_WEBREQUEST_CONNECT_FAILED - Failed to connect to server";
      case 4062: return "ERR_WEBREQUEST_TIMEOUT - HTTP request timed out";
      case 4063: return "ERR_WEBREQUEST_REQUEST_FAILED - HTTP request failed";
      case 4064: return "ERR_WEBREQUEST_NOT_ALLOWED - WebRequest not allowed for this URL";
      default: return "Error code: " + IntegerToString(error_code);
   }
}

//+------------------------------------------------------------------+
//| Fallback technical decision without AI                           |
//+------------------------------------------------------------------+
string FallbackTechnicalDecision()
{
   Print("ใช้การตัดสินใจจากการวิเคราะห์ทางเทคนิคแทน AI");
   
   // ตรวจสอบว่าอาร์เรย์ถูกตั้งค่าแล้วหรือไม่
   if(!ArrayGetAsSeries(macd_buffer) || !ArrayGetAsSeries(macd_signal_buffer) || 
      !ArrayGetAsSeries(rsi_buffer) || !ArrayGetAsSeries(ema_fast_buffer) || 
      !ArrayGetAsSeries(ema_slow_buffer))
   {
      Print("อาร์เรย์ยังไม่ได้ตั้งค่าเป็น AsSeries");
      ArraySetAsSeries(macd_buffer, true);
      ArraySetAsSeries(macd_signal_buffer, true);
      ArraySetAsSeries(rsi_buffer, true);
      ArraySetAsSeries(atr_buffer, true);
      ArraySetAsSeries(ema_fast_buffer, true);
      ArraySetAsSeries(ema_slow_buffer, true);
   }
   
   // ตรวจสอบขนาดของบัฟเฟอร์ให้ละเอียดเพื่อป้องกันการเข้าถึงนอกขอบเขต
   int macd_size = ArraySize(macd_buffer);
   int macd_signal_size = ArraySize(macd_signal_buffer);
   int rsi_size = ArraySize(rsi_buffer);
   int ema_fast_size = ArraySize(ema_fast_buffer);
   int ema_slow_size = ArraySize(ema_slow_buffer);
   
   Print("ขนาดของอาร์เรย์: MACD=", macd_size, ", Signal=", macd_signal_size, 
         ", RSI=", rsi_size, ", EMA Fast=", ema_fast_size, ", EMA Slow=", ema_slow_size);
   
   if(macd_size < 1 || macd_signal_size < 1 || rsi_size < 1 || 
      ema_fast_size < 1 || ema_slow_size < 1)
   {
      Print("ไม่มีข้อมูลเพียงพอสำหรับการวิเคราะห์ทางเทคนิค");
      return "HOLD";
   }
   
   // กำหนดค่าเริ่มต้นในกรณีที่ข้อมูลไม่สมบูรณ์
   double macd_current = 0;
   double macd_signal = 0;
   double rsi_current = 50;  // ค่ากลางเป็นค่าปลอดภัย
   double ema_fast_current = 0;
   double ema_slow_current = 0;
   
   // ตรวจสอบการเข้าถึงค่าแต่ละตัวอย่างปลอดภัย
   if(macd_size > 0) macd_current = macd_buffer[0];
   if(macd_signal_size > 0) macd_signal = macd_signal_buffer[0];
   if(rsi_size > 0) rsi_current = rsi_buffer[0];
   if(ema_fast_size > 0) ema_fast_current = ema_fast_buffer[0];
   if(ema_slow_size > 0) ema_slow_current = ema_slow_buffer[0];
   
   // แสดงค่าตัวชี้วัดเพื่อดีบัก
   Print("ค่าตัวชี้วัด: MACD=", macd_current, ", Signal=", macd_signal, 
         ", RSI=", rsi_current, ", EMA Fast=", ema_fast_current, ", EMA Slow=", ema_slow_current);
   
   // Check current positions
   int buy_positions = CountPositions(POSITION_TYPE_BUY);
   int sell_positions = CountPositions(POSITION_TYPE_SELL);
   Print("จำนวนตำแหน่ง: Buy=", buy_positions, ", Sell=", sell_positions);
   
   // CLOSE signals first (to prevent overtrading)
   if(buy_positions > 0)
   {
      // Close buy if trend changes to bearish
      if(macd_current < macd_signal && rsi_current > 70)
      {
         return "CLOSE_BUY";
      }
   }
   
   if(sell_positions > 0)
   {
      // Close sell if trend changes to bullish
      if(macd_current > macd_signal && rsi_current < 30)
      {
         return "CLOSE_SELL";
      }
   }
   
   // OPEN new positions only if we don't have any
   if(buy_positions == 0 && sell_positions == 0)
   {
      // Buy signal: MACD above signal, RSI not overbought, fast EMA above slow EMA
      if(macd_current > macd_signal && rsi_current < 70 && ema_fast_current > ema_slow_current)
      {
         return "BUY";
      }
      
      // Sell signal: MACD below signal, RSI not oversold, fast EMA below slow EMA
      if(macd_current < macd_signal && rsi_current > 30 && ema_fast_current < ema_slow_current)
      {
         return "SELL";
      }
   }
   
   // Default: hold current position
   return "HOLD";
}

//+------------------------------------------------------------------+
//| Get trading decision from DeepSeek AI                            |
//+------------------------------------------------------------------+
string GetAIDecision(string market_data)
{
   // Format the prompt for DeepSeek AI
   string prompt = "คุณเป็นผู้เชี่ยวชาญด้านการเทรดทอง (XAUUSD) แบบ Scalping วิเคราะห์ข้อมูลตลาดต่อไปนี้และให้คำแนะนำว่าควร 'BUY', 'SELL', 'CLOSE_BUY', 'CLOSE_SELL' หรือ 'HOLD' โดยใช้ความรู้เกี่ยวกับรูปแบบแท่งเทียน, แนวรับแนวต้าน, และตัวชี้วัดทางเทคนิค ข้อมูลตลาด: " + market_data;
   
   // Format the request body for DeepSeek AI
   string request_body = "{" +
      "\"model\": \"deepseek-chat\"," +
      "\"messages\": [" +
         "{\"role\": \"system\", \"content\": \"คุณเป็น AI ผู้เชี่ยวชาญการเทรดทอง (XAUUSD) แบบ Scalping คุณวิเคราะห์ตลาดและให้คำแนะนำที่ชัดเจนเพื่อทำกำไรสูงสุด ตอบเพียง: BUY, SELL, CLOSE_BUY, CLOSE_SELL, หรือ HOLD เท่านั้น\"}," +
         "{\"role\": \"user\", \"content\": \"" + prompt + "\"}" +
      "]," +
      "\"temperature\": 0.1," +
      "\"max_tokens\": 50" +
   "}";
   
   // Prepare headers and data for WebRequest
   char post_data[];
   StringToCharArray(request_body, post_data, 0, StringLen(request_body));
   
   char result[];
   string headers = "Content-Type: application/json\r\n" +
                   "Authorization: Bearer " + AIApiKey + "\r\n";
   
   Print("กำลังส่งข้อมูลไปยัง DeepSeek AI...");
   
   // Send request to DeepSeek AI
   int res = WebRequest("POST", AIEndpoint, headers, 30000, post_data, result, headers);
   
   if(res == -1)
   {
      int error_code = GetLastError();
      Print("เกิดข้อผิดพลาดในการเรียก AI API: ", error_code);
      Print("คำอธิบายข้อผิดพลาด: ", GetErrorDescription(error_code));
      
      // Check for specific errors
      if(error_code == 4060)
      {
         Print("ต้องเพิ่ม URL ในรายการที่อนุญาต: ", AIEndpoint);
         Print("Tools -> Options -> Expert Advisors -> Allow WebRequest for listed URL");
      }
      
      // Fallback to traditional technical analysis
      return FallbackTechnicalDecision();
   }
   
   string response = CharArrayToString(result);
   Print("การตอบกลับจาก DeepSeek AI: ", response);
   
   // Parse the response to extract the decision
   string decision = "HOLD"; // Default decision
   
   // Try to extract content from JSON response
   int content_pos = StringFind(response, "\"content\":");
   if(content_pos != -1)
   {
      int content_start = StringFind(response, "\"", content_pos + 11) + 1;
      int content_end = StringFind(response, "\"", content_start);
      string ai_message = StringSubstr(response, content_start, content_end - content_start);
      
      // Extract decision from AI message
      if(StringFind(ai_message, "BUY") != -1) decision = "BUY";
      else if(StringFind(ai_message, "SELL") != -1) decision = "SELL";
      else if(StringFind(ai_message, "CLOSE_BUY") != -1) decision = "CLOSE_BUY";
      else if(StringFind(ai_message, "CLOSE_SELL") != -1) decision = "CLOSE_SELL";
      else decision = "HOLD";
   }
   else
   {
      Print("ไม่สามารถแยกข้อความจากการตอบกลับของ AI ได้ ใช้การวิเคราะห์ทางเทคนิคแทน");
      decision = FallbackTechnicalDecision();
   }
   
   return decision;
}

//+------------------------------------------------------------------+
//| Execute trading decision                                         |
//+------------------------------------------------------------------+
void ExecuteTradingDecision(string decision)
{
   // Get current price and calculate stop loss and take profit levels
   MqlTick last_tick;
   if(!SymbolInfoTick(Symbol_Name, last_tick))
   {
      Print("ไม่สามารถรับข้อมูลราคาปัจจุบันได้");
      return;
   }
   
   double ask = last_tick.ask;
   double bid = last_tick.bid;
   
   // Check if we have enough money for margin requirements
   double margin_required = 0.0;
   if(decision == "BUY" || decision == "SELL")
   {
      // Calculate required margin
      if(!OrderCalcMargin(decision == "BUY" ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, 
                         Symbol_Name, TradeVolume, 
                         decision == "BUY" ? ask : bid, margin_required))
      {
         Print("ไม่สามารถคำนวณมาร์จิ้นที่ต้องการได้");
         return;
      }
      
      // Check if we have enough free margin
      double free_margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
      if(margin_required > free_margin)
      {
         Print("ไม่มีมาร์จิ้นเพียงพอสำหรับการเทรด ต้องการ: ", margin_required, ", มี: ", free_margin);
         return;
      }
   }
   
   // Execute decision based on command
   if(decision == "BUY")
   {
      OpenBuyPosition();
   }
   else if(decision == "SELL")
   {
      OpenSellPosition();
   }
   else if(decision == "CLOSE_BUY")
   {
      ClosePositions(POSITION_TYPE_BUY);
   }
   else if(decision == "CLOSE_SELL")
   {
      ClosePositions(POSITION_TYPE_SELL);
   }
   else // HOLD
   {
      Print("ถือครองตำแหน่งปัจจุบัน ไม่มีการดำเนินการใหม่");
   }
}
//+------------------------------------------------------------------+
//| เปิดตำแหน่งซื้อ                                                   |
//+------------------------------------------------------------------+
void OpenBuyPosition()
{
   double currentLotSize = CalculateLotSize(POSITION_TYPE_BUY);
   double sl = 0, tp = 0;
   
   // คำนวณ Stop Loss และ Take Profit
   if(UseFixedSLTP)
   {
      sl = SymbolInfoDouble(Symbol(), SYMBOL_ASK) - StopLoss * PointSize * 10;
      tp = SymbolInfoDouble(Symbol(), SYMBOL_ASK) + TakeProfit * PointSize * 10;
   }
   else
   {
      // ใช้ ATR สำหรับ SL/TP แบบไดนามิก
      sl = SymbolInfoDouble(Symbol(), SYMBOL_ASK) - atr_buffer[0] * ATR_Multiplier;
      tp = SymbolInfoDouble(Symbol(), SYMBOL_ASK) + atr_buffer[0] * ATR_Multiplier * 1.5;
   }
   
   // เปิดตำแหน่งซื้อ
   if(Trade.Buy(currentLotSize, Symbol(), 0, sl, tp, "Gold Scalper AI BUY"))
   {
      Print("ตำแหน่งซื้อเปิดสำเร็จ: Lot=", currentLotSize, ", SL=", sl, ", TP=", tp);
   }
   else
   {
      Print("ไม่สามารถเปิดตำแหน่งซื้อได้: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| เปิดตำแหน่งขาย                                                    |
//+------------------------------------------------------------------+
void OpenSellPosition()
{
   double currentLotSize = CalculateLotSize(POSITION_TYPE_SELL);
   double sl = 0, tp = 0;
   
   // คำนวณ Stop Loss และ Take Profit
   if(UseFixedSLTP)
   {
      sl = SymbolInfoDouble(Symbol(), SYMBOL_BID) + StopLoss * PointSize * 10;
      tp = SymbolInfoDouble(Symbol(), SYMBOL_BID) - TakeProfit * PointSize * 10;
   }
   else
   {
      // ใช้ ATR สำหรับ SL/TP แบบไดนามิก
      sl = SymbolInfoDouble(Symbol(), SYMBOL_BID) + atr_buffer[0] * ATR_Multiplier;
      tp = SymbolInfoDouble(Symbol(), SYMBOL_BID) - atr_buffer[0] * ATR_Multiplier * 1.5;
   }
   
   // เปิดตำแหน่งขาย
   if(Trade.Sell(currentLotSize, Symbol(), 0, sl, tp, "Gold Scalper AI SELL"))
   {
      Print("ตำแหน่งขายเปิดสำเร็จ: Lot=", currentLotSize, ", SL=", sl, ", TP=", tp);
   }
   else
   {
      Print("ไม่สามารถเปิดตำแหน่งขายได้: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| จัดการ Trailing Stop                                             |
//+------------------------------------------------------------------+
void ManageTrailingStop()
{
   if(TrailingStop <= 0)
      return;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0)
      {
         if(PositionGetString(POSITION_SYMBOL) == Symbol() && 
            PositionGetInteger(POSITION_MAGIC) == Trade.RequestMagic())
         {
            ulong posTicket = PositionGetInteger(POSITION_TICKET);
            double posOpenPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double currentSL = PositionGetDouble(POSITION_SL);
            double currentTP = PositionGetDouble(POSITION_TP);
            
            // Buy position
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
            {
               double newSL = NormalizeDouble(SymbolInfoDouble(Symbol(), SYMBOL_BID) - TrailingStop * PointSize * 10, _Digits);
               
               if(newSL > currentSL && newSL < SymbolInfoDouble(Symbol(), SYMBOL_BID))
               {
                  if(Trade.PositionModify(posTicket, newSL, currentTP))
                  {
                     Print("Trailing Stop ตำแหน่งซื้อปรับแล้ว: ", posTicket, ", SL ใหม่: ", newSL);
                  }
               }
            }
            // Sell position
            else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
            {
               double newSL = NormalizeDouble(SymbolInfoDouble(Symbol(), SYMBOL_ASK) + TrailingStop * PointSize * 10, _Digits);
               
               if((currentSL == 0 || newSL < currentSL) && newSL > SymbolInfoDouble(Symbol(), SYMBOL_ASK))
               {
                  if(Trade.PositionModify(posTicket, newSL, currentTP))
                  {
                     Print("Trailing Stop ตำแหน่งขายปรับแล้ว: ", posTicket, ", SL ใหม่: ", newSL);
                  }
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| ปิดตำแหน่งตามประเภท                                                |
//+------------------------------------------------------------------+
void ClosePositions(ENUM_POSITION_TYPE posType)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0)
      {
         if(PositionGetString(POSITION_SYMBOL) == Symbol() && 
            PositionGetInteger(POSITION_MAGIC) == Trade.RequestMagic() &&
            PositionGetInteger(POSITION_TYPE) == posType)
         {
            ulong posTicket = PositionGetInteger(POSITION_TICKET);
            if(Trade.PositionClose(posTicket))
            {
               Print("ตำแหน่งปิดสำเร็จ: ", posTicket);
               
               // แสดงข้อมูลกำไร/ขาดทุน
               double profit = PositionGetDouble(POSITION_PROFIT);
               Print("ผลการปิดตำแหน่ง: Ticket=", posTicket, ", Profit=", profit);
               
               // ลบการอ้างอิงถึง LossCount เนื่องจากเราไม่ได้ใช้ Martingale แล้ว
               // if(PositionGetDouble(POSITION_PROFIT) < 0)
               // {
               //    LossCount++;
               // }
               // else
               // {
               //    LossCount = 0;
               // }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| คำนวณขนาด Lot แบบคงที่ (Fixed Lot)                               |
//+------------------------------------------------------------------+
double CalculateLotSize(ENUM_POSITION_TYPE posType)
{
   // ใช้ค่า TradeVolume ที่กำหนดในพารามิเตอร์โดยตรง
   double lotSize = TradeVolume;
   
   // ตรวจสอบข้อจำกัดของ Lot
   double minLot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
   
   // ปรับ lotSize ให้อยู่ในขอบเขตที่กำหนด
   lotSize = MathMax(minLot, lotSize);  // ไม่น้อยกว่าค่าต่ำสุด
   lotSize = MathMin(maxLot, lotSize);  // ไม่มากกว่าค่าสูงสุด
   
   // ปัดเศษตามค่า lotStep
   lotSize = MathFloor(lotSize / lotStep) * lotStep;
   
   // ปัดเศษให้เป็นทศนิยม 2 ตำแหน่ง
   lotSize = NormalizeDouble(lotSize, 2);
   
   Print("กำลังใช้ Fixed Lot Size: ", lotSize);
   
   return lotSize;
}

//+------------------------------------------------------------------+
//| ฟังก์ชันจัดการเหตุการณ์การเทรด                                     |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
{
   // ตรวจสอบประเภทธุรกรรม
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
   {
      // รับข้อมูลดีล
      ulong dealTicket = trans.deal;
      
      if(dealTicket > 0)
      {
         HistorySelect(TimeCurrent() - 60, TimeCurrent());
         
         if(HistoryDealSelect(dealTicket))
         {
            // ตรวจสอบว่านี่เป็นการปิดตำแหน่งหรือไม่
            if(HistoryDealGetInteger(dealTicket, DEAL_ENTRY) == DEAL_ENTRY_OUT)
            {
               double dealProfit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
               
               // แสดงผลกำไร/ขาดทุน
               Print("ปิดตำแหน่ง: Ticket=", dealTicket, ", Profit=", dealProfit);
               
               // ลบการจัดการ LossCount สำหรับ Martingale
               // เนื่องจากเราใช้ Fixed Lot ไม่จำเป็นต้องติดตามจำนวนการขาดทุน
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Count positions by type                                          |
//+------------------------------------------------------------------+
int CountPositions(ENUM_POSITION_TYPE position_type)
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0)
      {
         if(PositionGetString(POSITION_SYMBOL) == Symbol_Name && 
            PositionGetInteger(POSITION_MAGIC) == MagicNumber && 
            PositionGetInteger(POSITION_TYPE) == position_type)
         {
            count++;
         }
      }
   }
   return count;
}
//+------------------------------------------------------------------+
//| Identify candlestick patterns                                    |
//+------------------------------------------------------------------+
string IdentifyCandlestickPatterns(const MqlRates &rates[])
{
   // ตรวจสอบขนาดของอาร์เรย์เพื่อป้องกันการเข้าถึงนอกขอบเขต
   int size = ArraySize(rates);
   Print("จำนวนแท่งเทียนสำหรับวิเคราะห์: ", size);
   
   if(size < 3)
   {
      Print("ข้อมูลไม่เพียงพอสำหรับการตรวจสอบรูปแบบแท่งเทียน (", size, " แท่ง)");
      return "[]";
   }
   
   // ตรวจสอบว่าข้อมูลแท่งเทียนถูกต้องหรือไม่
   if(rates[0].time == 0 || rates[1].time == 0 || rates[2].time == 0)
   {
      Print("ข้อมูลแท่งเทียนไม่ถูกต้อง (เวลาเป็น 0)");
      return "[]";
   }
   
   string patterns = "[";
   int pattern_count = 0;
   
   // ทำการตรวจสอบภายใต้ try-catch เพื่อป้องกันข้อผิดพลาด
   // (แม้ MQL5 จะไม่มี try-catch แต่นี่เป็นแนวคิดที่ควรใช้ในการป้องกันข้อผิดพลาด)
   
   // Check for Doji - พยายามตรวจจับข้อผิดพลาดที่อาจเกิดขึ้น
   bool doji = false;
   if(size > 0) {
      doji = IsDoji(rates[0]);
      if(doji)
      {
         patterns += "{\"name\":\"doji\",\"significance\":\"high\"}";
         pattern_count++;
      }
   }
   
   // Check for Hammer/Hanging Man
   bool hammer = false;
   if(size > 0) {
      hammer = IsHammer(rates[0]);
      if(hammer)
      {
         if(pattern_count > 0) patterns += ",";
         patterns += "{\"name\":\"hammer\",\"significance\":\"high\"}";
         pattern_count++;
      }
   }
   
   // Check for Engulfing pattern
   bool bullish_engulfing = false;
   bool bearish_engulfing = false;
   if(size > 1) {
      bullish_engulfing = IsBullishEngulfing(rates[0], rates[1]);
      if(bullish_engulfing)
      {
         if(pattern_count > 0) patterns += ",";
         patterns += "{\"name\":\"bullish_engulfing\",\"significance\":\"high\"}";
         pattern_count++;
      }
      
      bearish_engulfing = IsBearishEngulfing(rates[0], rates[1]);
      if(bearish_engulfing)
      {
         if(pattern_count > 0) patterns += ",";
         patterns += "{\"name\":\"bearish_engulfing\",\"significance\":\"high\"}";
         pattern_count++;
      }
   }
   
   // Check for Morning/Evening Star - เฉพาะเมื่อมีข้อมูลเพียงพอ
   bool morning_star = false;
   bool evening_star = false;
   if(size > 2) {
      morning_star = IsMorningStar(rates[0], rates[1], rates[2]);
      if(morning_star)
      {
         if(pattern_count > 0) patterns += ",";
         patterns += "{\"name\":\"morning_star\",\"significance\":\"very_high\"}";
         pattern_count++;
      }
      
      evening_star = IsEveningStar(rates[0], rates[1], rates[2]);
      if(evening_star)
      {
         if(pattern_count > 0) patterns += ",";
         patterns += "{\"name\":\"evening_star\",\"significance\":\"very_high\"}";
         pattern_count++;
      }
   }
   
   patterns += "]";
   return patterns;
}
//+------------------------------------------------------------------+
//| Identify support and resistance levels                           |
//+------------------------------------------------------------------+
string IdentifySupportResistance(const MqlRates &rates[])
{
   // ตรวจสอบขนาดของอาร์เรย์เพื่อป้องกันการเข้าถึงนอกขอบเขต
   int size = ArraySize(rates);
   Print("จำนวนแท่งเทียนสำหรับวิเคราะห์แนวรับแนวต้าน: ", size);
   
   // ต้องมีข้อมูลอย่างน้อย 20 แท่ง
   if(size < 20)
   {
      Print("ข้อมูลไม่เพียงพอสำหรับการระบุแนวรับแนวต้าน (", size, " จาก 20 แท่ง)");
      return "{\"resistance\":[],\"support\":[],\"highest_high\":0,\"lowest_low\":0}";
   }
   
   // ตรวจสอบว่าข้อมูลถูกต้องหรือไม่
   for(int i=0; i<20; i++)
   {
      if(rates[i].time == 0)
      {
         Print("ข้อมูลแท่งเทียนที่ ", i, " ไม่ถูกต้อง (เวลาเป็น 0)");
         return "{\"resistance\":[],\"support\":[],\"highest_high\":0,\"lowest_low\":0}";
      }
   }
   
   // ค่าเริ่มต้นที่ปลอดภัย
   double highest_high = rates[0].high;
   double lowest_low = rates[0].low;
   
   // Find highest high and lowest low in recent candles
   for(int i = 1; i < 20 && i < size; i++)
   {
      if(rates[i].high > highest_high) highest_high = rates[i].high;
      if(rates[i].low < lowest_low) lowest_low = rates[i].low;
   }
   
   // Find potential resistance levels - ตรวจสอบขอบเขตที่ปลอดภัย
   double resistance_levels[];
   ArrayResize(resistance_levels, 0);
   
   // ปรับช่วงการค้นหาให้ไม่เกินขนาดของอาร์เรย์
   for(int i = 5; i < MathMin(19, size-3); i++)
   {
      // Look for local highs
      if(i-2 >= 0 && i-1 >= 0 && i+1 < size && i+2 < size &&
         rates[i].high > rates[i-1].high && 
         rates[i].high > rates[i-2].high && 
         rates[i].high > rates[i+1].high && 
         rates[i].high > rates[i+2].high)
      {
         // Check if this level is not already in our array
         bool exists = false;
         for(int j = 0; j < ArraySize(resistance_levels); j++)
         {
            if(MathAbs(resistance_levels[j] - rates[i].high) < 10 * _Point)
            {
               exists = true;
               break;
            }
         }
         
         if(!exists)
         {
            int array_size = ArraySize(resistance_levels);
            ArrayResize(resistance_levels, array_size + 1);
            resistance_levels[array_size] = rates[i].high;
         }
      }
   }
   
   // Find potential support levels
   double support_levels[];
   ArrayResize(support_levels, 0);
   
   // ปรับช่วงการค้นหาให้ไม่เกินขนาดของอาร์เรย์
   for(int i = 5; i < MathMin(19, size-3); i++)
   {
      // Look for local lows - ตรวจสอบขอบเขตที่ปลอดภัย
      if(i-2 >= 0 && i-1 >= 0 && i+1 < size && i+2 < size &&
         rates[i].low < rates[i-1].low && 
         rates[i].low < rates[i-2].low && 
         rates[i].low < rates[i+1].low && 
         rates[i].low < rates[i+2].low)
      {
         // Check if this level is not already in our array
         bool exists = false;
         for(int j = 0; j < ArraySize(support_levels); j++)
         {
            if(MathAbs(support_levels[j] - rates[i].low) < 10 * _Point)
            {
               exists = true;
               break;
            }
         }
         
         if(!exists)
         {
            int array_size = ArraySize(support_levels);
            ArrayResize(support_levels, array_size + 1);
            support_levels[array_size] = rates[i].low;
         }
      }
   }
   
   // Format as JSON
   string json = "{";
   
   json += "\"resistance\":[";
   for(int i = 0; i < ArraySize(resistance_levels); i++)
   {
      if(i > 0) json += ",";
      json += DoubleToString(resistance_levels[i], _Digits);
   }
   json += "],";
   
   json += "\"support\":[";
   for(int i = 0; i < ArraySize(support_levels); i++)
   {
      if(i > 0) json += ",";
      json += DoubleToString(support_levels[i], _Digits);
   }
   json += "],";
   
   json += "\"highest_high\":" + DoubleToString(highest_high, _Digits) + ",";
   json += "\"lowest_low\":" + DoubleToString(lowest_low, _Digits);
   
   json += "}";
   
   return json;
}

//+------------------------------------------------------------------+
//| Check for Doji pattern                                           |
//+------------------------------------------------------------------+
bool IsDoji(const MqlRates &candle)
{
   // ป้องกันการหารด้วยศูนย์
   double candle_range = candle.high - candle.low;
   if(candle_range <= 0)
   {
      return false;
   }
   double body_size = MathAbs(candle.close - candle.open);
   
   // A doji has a very small body compared to its range
   return (body_size <= 0.1 * candle_range);
}

//+------------------------------------------------------------------+
//| Check for Hammer/Hanging Man pattern                             |
//+------------------------------------------------------------------+
bool IsHammer(const MqlRates &candle)
{
   // ป้องกันการหารด้วยศูนย์
   double candle_range = candle.high - candle.low;
   if(candle_range <= 0)
   {
      return false;
   }
   double body_size = MathAbs(candle.close - candle.open);
   double upper_shadow = candle.high - MathMax(candle.open, candle.close);
   double lower_shadow = MathMin(candle.open, candle.close) - candle.low;
   
   // A hammer has a small body, small upper shadow, and long lower shadow
   return (body_size <= 0.3 * candle_range &&
           upper_shadow <= 0.1 * candle_range &&
           lower_shadow >= 0.6 * candle_range);
}

//+------------------------------------------------------------------+
//| Check for Bullish Engulfing pattern                              |
//+------------------------------------------------------------------+
bool IsBullishEngulfing(const MqlRates &current, const MqlRates &previous)
{
   // Bullish engulfing: current candle is bullish, previous is bearish
   // Current candle's body completely engulfs previous candle's body
   return (current.close > current.open &&      // Current is bullish
           previous.close < previous.open &&    // Previous is bearish
           current.open < previous.close &&     // Current open is lower than previous close
           current.close > previous.open);      // Current close is higher than previous open
}

//+------------------------------------------------------------------+
//| Check for Bearish Engulfing pattern                              |
//+------------------------------------------------------------------+
bool IsBearishEngulfing(const MqlRates &current, const MqlRates &previous)
{
   // Bearish engulfing: current candle is bearish, previous is bullish
   // Current candle's body completely engulfs previous candle's body
   return (current.close < current.open &&      // Current is bearish
           previous.close > previous.open &&    // Previous is bullish
           current.open > previous.close &&     // Current open is higher than previous close
           current.close < previous.open);      // Current close is lower than previous open
}

//+------------------------------------------------------------------+
//| Check for Morning Star pattern                                   |
//+------------------------------------------------------------------+
bool IsMorningStar(const MqlRates &first, const MqlRates &middle, const MqlRates &last)
{
   // ป้องกันการหารด้วยศูนย์
   if(last.high - last.low <= 0 || middle.high - middle.low <= 0 || first.high - first.low <= 0)
   {
      return false;
   }
   // Last candle is bearish with significant body
   bool last_bearish = last.close < last.open && MathAbs(last.close - last.open) > 0.5 * (last.high - last.low);
   
   // Middle candle is small body (could be bullish or bearish)
   bool middle_small = MathAbs(middle.close - middle.open) <= 0.3 * (middle.high - middle.low);
   
   // First candle is bullish with significant body
   bool first_bullish = first.close > first.open && MathAbs(first.close - first.open) > 0.5 * (first.high - first.low);
   
   // Gap between last and middle, and between middle and first
   bool has_gaps = (MathMax(middle.open, middle.close) < last.open) && 
                   (MathMax(first.open, first.close) < MathMin(middle.open, middle.close));
   
   return last_bearish && middle_small && first_bullish && has_gaps;
}

//+------------------------------------------------------------------+
//| Check for Evening Star pattern                                   |
//+------------------------------------------------------------------+
bool IsEveningStar(const MqlRates &first, const MqlRates &middle, const MqlRates &last)
{
   // ป้องกันการหารด้วยศูนย์
   if(last.high - last.low <= 0 || middle.high - middle.low <= 0 || first.high - first.low <= 0)
   {
      return false;
   }
   // Last candle is bullish with significant body
   bool last_bullish = last.close > last.open && MathAbs(last.close - last.open) > 0.5 * (last.high - last.low);
   
   // Middle candle is small body (could be bullish or bearish)
   bool middle_small = MathAbs(middle.close - middle.open) <= 0.3 * (middle.high - middle.low);
   
   // First candle is bearish with significant body
   bool first_bearish = first.close < first.open && MathAbs(first.close - first.open) > 0.5 * (first.high - first.low);
   
   // Gap between last and middle, and between middle and first
   bool has_gaps = (MathMin(middle.open, middle.close) > last.open) && 
                   (MathMin(first.open, first.close) > MathMax(middle.open, middle.close));
   
   return last_bullish && middle_small && first_bearish && has_gaps;
}

//+------------------------------------------------------------------+
//| ตรวจสอบความถูกต้องของ Timeframe และแปลงเป็นข้อความ                   |
//+------------------------------------------------------------------+
bool ChartPeriodToString(ENUM_TIMEFRAMES period)
{
   switch(period)
   {
      case PERIOD_M1:
      case PERIOD_M2:
      case PERIOD_M3:
      case PERIOD_M4:
      case PERIOD_M5:
      case PERIOD_M6:
      case PERIOD_M10:
      case PERIOD_M12:
      case PERIOD_M15:
      case PERIOD_M20:
      case PERIOD_M30:
      case PERIOD_H1:
      case PERIOD_H2:
      case PERIOD_H3:
      case PERIOD_H4:
      case PERIOD_H6:
      case PERIOD_H8:
      case PERIOD_H12:
      case PERIOD_D1:
      case PERIOD_W1:
      case PERIOD_MN1:
         return true;
      default:
         return false;
   }
}
