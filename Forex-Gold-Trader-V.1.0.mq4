#property copyright "Copyright © 2010, Forex Gold Trader"
#property link      "http://forexgoldtrader.com"


extern string Tittle = "ForexGoldTrader.com";
extern bool SafeMode = FALSE;
extern double Lots = 0.01;
extern int MaxTrades = 30;
extern int Range = 650;
extern int SecureProfit = 650;
int gi_unused_148 = 0;
double gd_unused_152 = 0.0;
double g_ord_open_price_160 = 0.0;
double gd_unused_168 = 0.0;
int gi_unused_176 = 0;
double gd_unused_180 = 0.0;
double gd_unused_188 = 0.0;

int init() {
   return (0);
}

int deinit() {
   return (0);
}

int start() {
   string lsa_0[256];
   int li_56;
   int li_60;
   string ls_64;
   double l_iopen_72;
   int l_str2int_80;
   string ls_84;
   string ls_92;
   int li_100;
   int li_104;
   string l_time2str_108;
   string ls_116;
   int li_124;
   for (int l_pos_4 = 0; l_pos_4 < 256; l_pos_4++) lsa_0[l_pos_4] = CharToStr(l_pos_4);
   string ls_8 = "Claudia Arteaga";
   string ls_16 = "claudiax@mail13.net";
   string ls_24 = "+1.310.854.3043";
   string ls_32 = StringSubstr(AccountName(), 1, 5);
   string ls_40 = StringSubstr(ls_8, 1, 5);
   string ls_48 = StringSubstr(Symbol(), 0, 3);
   if (ls_48 == "XAU" || ls_48 == "GOL") {
      l_iopen_72 = iOpen(Symbol(), 10080, 0);
      l_str2int_80 = 0;
      if (SafeMode) {
         ls_84 = "ON, EA will not trade at Down Trend";
      } else {
         ls_84 = "OFF, EA will trade at UP & DOWN Trend";
      }
      if (Ask > l_iopen_72) {
         if (SafeMode) l_str2int_80 = 1;
         else l_str2int_80 = 1;
         ls_92 = Symbol() + " going UP Trend";
      } else {
         if (SafeMode) l_str2int_80 = 0;
         else l_str2int_80 = 1;
         ls_92 = Symbol() + " going DOWN Trend";
      }
      li_100 = MarketInfo(Symbol(), StrToInteger(lsa_0[49] + lsa_0[50]));
      if (li_100 == 3) {
         li_56 = SecureProfit * StrToInteger(lsa_0[49] + lsa_0[48]);
         li_60 = Range * StrToInteger(lsa_0[49] + lsa_0[48]);
         ls_64 = lsa_0[89] + lsa_0[101] + lsa_0[115];
      } else {
         li_56 = SecureProfit * 1;
         li_60 = Range * 1;
         ls_64 = lsa_0[78] + lsa_0[111];
      }
      li_104 = CountOrders(Symbol(), 0);
      ModifyOrders(Symbol(), 0);
      for (l_pos_4 = 0; l_pos_4 < OrdersTotal(); l_pos_4++) {
         OrderSelect(l_pos_4, SELECT_BY_POS, 0);
         if (OrderSymbol() == Symbol() && OrderMagicNumber() == StrToInteger(lsa_0[51] + lsa_0[49] + lsa_0[48] + lsa_0[56] + lsa_0[56] + lsa_0[53]))
            if (OrderType() == 0) g_ord_open_price_160 = OrderOpenPrice();
      }
      l_time2str_108 = TimeToStr(TimeCurrent(), TIME_DATE|TIME_SECONDS);
      ls_116 = "\n" + "---------------------------------------------------------------------------";
      ls_116 = ls_116 + "\n" + "     FOREX GOLD TRADER V.1.0 Full Version";
      ls_116 = ls_116 + "\n" + "---------------------------------------------------------------------------";
      ls_116 = ls_116 + "\n" + "     Server Time : " + l_time2str_108;
      ls_116 = ls_116 + "\n" + "     Broker Name : " + AccountCompany();
/*
      ls_116 = ls_116 + "\n" + "     Owner Name : " + ls_8;
      ls_116 = ls_116 + "\n" + "     Owner Email : " + ls_16;
      ls_116 = ls_116 + "\n" + "     Owner Phone : " + ls_24;
*/
      ls_116 = ls_116 + "\n" + "     Extra Digits : " + ls_64;
      ls_116 = ls_116 + "\n" + "     Safe Mode : " + ls_84;
      ls_116 = ls_116 + "\n" + "     Long Term Trend : " + ls_92;
      ls_116 = ls_116 + "\n" + "     Lot : " + DoubleToStr(Lots, 2);
      ls_116 = ls_116 + "\n" + "     Target Profit (pip) : " + li_56;
      ls_116 = ls_116 + "\n" + "     Range per Order (pip) : " + li_60;
      ls_116 = ls_116 + "\n" + "     Last Buy Price : " + DoubleToStr(g_ord_open_price_160, Digits);
      ls_116 = ls_116 + "\n" + "     Maximum Order : " + MaxTrades;
      ls_116 = ls_116 + "\n" + "     Current Buy Opened : " + li_104;
      ls_116 = ls_116 + "\n" + "     Current Profit : $" + DoubleToStr(getProfit(Symbol()), 2);
      ls_116 = ls_116 + "\n" + "---------------------------------------------------------------------------";
      ls_116 = ls_116 + "\n" + "     Warning : Please dont share this EA to the others";
      ls_116 = ls_116 + "\n" + "     or we will disable your membership and you wont ";
      ls_116 = ls_116 + "\n" + "     get any update from us anymore.";
      ls_116 = ls_116 + "\n" + "\n" + "     Disclaimer : Use this EA wisely, do not greedy.";
      ls_116 = ls_116 + "\n" + "     Forex trading involves significant risk of loss ";
      ls_116 = ls_116 + "\n" + "     and is not suitable for all investors.";
      ls_116 = ls_116 + "\n" + "\n" + "     Release Date : Oct 01, 2010";
      ls_116 = ls_116 + "\n" + "     FGT V.1.0 Code : 310885";
      ls_116 = ls_116 + "\n" + "\n" 
      + "     © 2009-2010 Forexgoldtrader.com. All Rights Reserved.";
      ls_116 = ls_116 + "\n" + "---------------------------------------------------------------------------";
      Comment(ls_116);
      li_124 = 0;
      if (l_str2int_80 && li_104 < 1) {
         li_124 = OrderSend(Symbol(), 0, Lots, Ask, (Ask - Bid) * Point, 0, 0, lsa_0[51] + lsa_0[49] + lsa_0[48] +
            lsa_0[56] + lsa_0[56] + lsa_0[53], StrToInteger(lsa_0[51] + lsa_0[49] + lsa_0[48] + lsa_0[56] + lsa_0[56] + lsa_0[53]), 0, StrToInteger(lsa_0[49] +
            lsa_0[54] + lsa_0[55] + lsa_0[49] + lsa_0[49] + lsa_0[54] + lsa_0[56] + lsa_0[48]));
         if (li_124 > 0) {
            Print(lsa_0[70] + lsa_0[111] + lsa_0[114] + lsa_0[101] + lsa_0[120] + lsa_0[32] + lsa_0[71] + lsa_0[111] + lsa_0[108] + lsa_0[100] + lsa_0[32] + lsa_0[84] + lsa_0[114] +
               lsa_0[97] + lsa_0[100] + lsa_0[101] + lsa_0[114] + lsa_0[32] + lsa_0[79] + lsa_0[112] + lsa_0[101] + lsa_0[110] + lsa_0[32] + lsa_0[66] + lsa_0[85] + lsa_0[89] + lsa_0[32] +
               lsa_0[91] + lsa_0[79] + lsa_0[75] + lsa_0[93]);
         } else {
            Print(lsa_0[70] + lsa_0[111] + lsa_0[114] + lsa_0[101] + lsa_0[120] + lsa_0[32] + lsa_0[71] + lsa_0[111] + lsa_0[108] + lsa_0[100] + lsa_0[32] + lsa_0[84] + lsa_0[114] +
               lsa_0[97] + lsa_0[100] + lsa_0[101] + lsa_0[114] + lsa_0[32] + lsa_0[79] + lsa_0[112] + lsa_0[101] + lsa_0[110] + lsa_0[32] + lsa_0[66] + lsa_0[85] + lsa_0[89] + lsa_0[32] +
               lsa_0[91] + lsa_0[69] + lsa_0[114] + lsa_0[114] + lsa_0[111] + lsa_0[114] + lsa_0[93]);
         }
         return (0);
      }
      if (l_str2int_80 && li_104 > 0 && li_104 < MaxTrades) {
         if (g_ord_open_price_160 - Ask >= li_60 * Point) {
            li_124 = OrderSend(Symbol(), 0, Lots, Ask, (Ask - Bid) * Point, 0, 0, lsa_0[51] + lsa_0[49] + lsa_0[48] +
               lsa_0[56] + lsa_0[56] + lsa_0[53], StrToInteger(lsa_0[51] + lsa_0[49] + lsa_0[48] + lsa_0[56] + lsa_0[56] + lsa_0[53]), 0, StrToInteger(lsa_0[49] +
               lsa_0[54] + lsa_0[55] + lsa_0[49] + lsa_0[49] + lsa_0[54] + lsa_0[56] + lsa_0[48]));
            if (li_124 > 0) {
               Print(lsa_0[70] + lsa_0[111] + lsa_0[114] + lsa_0[101] + lsa_0[120] + lsa_0[32] + lsa_0[71] + lsa_0[111] + lsa_0[108] + lsa_0[100] + lsa_0[32] + lsa_0[84] + lsa_0[114] +
                  lsa_0[97] + lsa_0[100] + lsa_0[101] + lsa_0[114] + lsa_0[32] + lsa_0[79] + lsa_0[112] + lsa_0[101] + lsa_0[110] + lsa_0[32] + lsa_0[66] + lsa_0[85] + lsa_0[89] + lsa_0[32] +
                  lsa_0[91] + lsa_0[79] + lsa_0[75] + lsa_0[93]);
            } else {
               Print(lsa_0[70] + lsa_0[111] + lsa_0[114] + lsa_0[101] + lsa_0[120] + lsa_0[32] + lsa_0[71] + lsa_0[111] + lsa_0[108] + lsa_0[100] + lsa_0[32] + lsa_0[84] + lsa_0[114] +
                  lsa_0[97] + lsa_0[100] + lsa_0[101] + lsa_0[114] + lsa_0[32] + lsa_0[79] + lsa_0[112] + lsa_0[101] + lsa_0[110] + lsa_0[32] + lsa_0[66] + lsa_0[85] + lsa_0[89] + lsa_0[32] +
                  lsa_0[91] + lsa_0[69] + lsa_0[114] + lsa_0[114] + lsa_0[111] + lsa_0[114] + lsa_0[93]);
            }
            return (0);
         }
      }
      return (0);
   }
   Comment("ERROR!! This EA designed for GOLD or XAUUSD only!! " + "\n" + "Please contact support@forexgoldtrader.com");
   return (0);
}

int CountOrders(string a_symbol_0 = "", int a_cmd_8 = -1) {
   string lsa_12[256];
   for (int l_pos_16 = 0; l_pos_16 < 256; l_pos_16++) lsa_12[l_pos_16] = CharToStr(l_pos_16);
   int li_ret_20 = StrToInteger(lsa_12[48]);
   int l_ord_total_24 = OrdersTotal();
   for (l_pos_16 = StrToInteger(lsa_12[48]); l_pos_16 < l_ord_total_24; l_pos_16++) {
      OrderSelect(l_pos_16, SELECT_BY_POS, StrToInteger(lsa_12[48]));
      if (Symbol() == "" || OrderSymbol() == a_symbol_0 && a_cmd_8 == -1 || OrderType() == a_cmd_8 && OrderMagicNumber() == StrToInteger(lsa_12[51] + lsa_12[49] + lsa_12[48] +
         lsa_12[56] + lsa_12[56] + lsa_12[53])) li_ret_20++;
   }
   return (li_ret_20);
}

void ModifyOrders(string a_symbol_0 = "", int a_cmd_8 = -1) {
   string lsa_12[256];
   int li_28;
   for (int l_pos_16 = 0; l_pos_16 < 256; l_pos_16++) lsa_12[l_pos_16] = CharToStr(l_pos_16);
   int l_str2int_20 = StrToInteger(lsa_12[48]);
   int l_ord_total_24 = OrdersTotal();
   int li_32 = MarketInfo(Symbol(), StrToInteger(lsa_12[49] + lsa_12[50]));
   if (li_32 == StrToInteger(lsa_12[51])) li_28 = SecureProfit * StrToInteger(lsa_12[49] + lsa_12[48]);
   else li_28 = SecureProfit;
   for (l_pos_16 = StrToInteger(lsa_12[48]); l_pos_16 < l_ord_total_24; l_pos_16++) {
      OrderSelect(l_pos_16, SELECT_BY_POS, StrToInteger(lsa_12[48]));
      if (Symbol() == "" || OrderSymbol() == a_symbol_0 && a_cmd_8 == -1 || OrderType() == a_cmd_8 && OrderMagicNumber() == StrToInteger(lsa_12[51] + lsa_12[49] + lsa_12[48] +
         lsa_12[56] + lsa_12[56] + lsa_12[53]) && OrderTakeProfit() == 0.0) OrderModify(OrderTicket(), OrderOpenPrice(), StrToInteger(lsa_12[48]), OrderOpenPrice() + li_28 * Point, StrToInteger(lsa_12[48]), Blue);
   }
}

double getProfit(string as_unused_0) {
   string lsa_8[256];
   for (int l_pos_12 = 0; l_pos_12 < 256; l_pos_12++) lsa_8[l_pos_12] = CharToStr(l_pos_12);
   double ld_ret_16 = StrToInteger(lsa_8[48]);
   for (l_pos_12 = OrdersTotal(); l_pos_12 >= StrToInteger(lsa_8[48]); l_pos_12--) {
      if (OrderSelect(l_pos_12, SELECT_BY_POS, StrToInteger(lsa_8[48])))
         if (OrderSymbol() == Symbol() && OrderMagicNumber() == StrToInteger(lsa_8[51] + lsa_8[49] + lsa_8[48] + lsa_8[56] + lsa_8[56] + lsa_8[53])) ld_ret_16 = ld_ret_16 + OrderProfit() + OrderSwap() + OrderCommission();
   }
   return (ld_ret_16);
}