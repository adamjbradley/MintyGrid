//+------------------------------------------------------------------+
//|                                                    MintyGrid.mq5 |
//|                     Copyright 2021, Christopher Benjamin Hemmens |
//|                                         chrishemmens@hotmail.com |
//|                                                                  |
//|                                                                  |
//| Redistribution and use in source and binary forms, with or       |
//| without modification, are permitted provided that the following  |
//| conditions are met:                                              |
//|                                                                  |
//| - Redistributions of source code must retain the above           |
//| copyright notice, this list of conditions and the following      |
//| disclaimer.                                                      |
//| - Redistributions in binary form must reproduce the above        |
//| copyright notice, this list of conditions and the following      |
//| disclaimer in the documentation and/or other materials           |
//| provided with the distribution.                                  |
//| - All advertising materials mentioning features or use of this   |
//| software must display the following acknowledgement:             |
//| This product includes software developed by                      |
//| Christopher Benjamin Hemmens.                                    |
//| - Neither the name of the Christopher Benjamin Hemmens nor the   |
//| names of its contributors may be used to endorse or promote      |
//| products derived from this software without specific prior       |
//| written permission.                                              |
//|                                                                  |
//| THIS SOFTWARE IS PROVIDED BY Christopher Benjamin Hemmens AS     |
//| IS AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT     |
//| LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND        |
//| FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT     |
//| SHALL Christopher Benjamin Hemmens BE LIABLE FOR ANY DIRECT,     |
//| INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL       |
//| DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF           |
//| SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;     |
//| OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF    |
//| LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT        |
//| (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF    |
//| THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY     |
//| OF SUCH DAMAGE.                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2021, Christopher Benjamin Hemmens"
#property link      "chrishemmens@hotmail.com"
#property version   "3.4"

#include <checkhistory.mqh>
#include <Trade/Trade.mqh>
#include <ChartObjects\ChartObjectsShapes.mqh>
#include <ChartObjects\ChartObjectsTxtControls.mqh>

enum RiskBase {Balance, Equity, Margin};
enum RiskType {Fixed, Dynamic};

input group    "Risk settings";
input RiskBase riskBase=Equity; // Factor to base risk on when using dynamic risk
input RiskType riskType=Dynamic; // Whether to use fixed or dynamic risk
input RiskType profitType=Dynamic; // Whether to use fixed or dynamic lot size
input double   riskFactor=1; // Fixed lot size or dynamic risk factor
input double   profitFactor=0.5; // Fixed profit in deposit currency or dynamic profit factor
input double   stopLoss=0.0; // Percentage of price to be used as stop loss (0 to disable)

input group    "Martingale grid settings";
input double   lotMultiplier=2; // Step martingale lot multiplier (0 to disable)
input double   gridStep=0.01; // Step price movement percentage
input double   gridStepMultiplier=10; // Step distance multiplier (0 to disable)
input double   gridStepProfitMultiplier=1.1; // Step profit multiplier (0 to disable)
input double   gridReverseStepMultiplier=10; // Reverse direction step multiplier (0 to disable)
input double   gridReverseLotDeviser=0; // Reverse martingale lot deviser (0 to disable)
input int      breakEventGridStep=4; // Try break even on grid step (0 to disable)
input int      maxGridSteps=10; // Maximum amount of grid steps per direction

input group    "Trade settings";
input bool     buy = true; // Whether to enable buy trades
input bool     sell = true; // Whether to enable sell trades

input group    "Symbol settings";
input string   currencyPairs = "NZDCHF,AUDCHF,NZDUSD,AUDUSD,CADCHF,NZDCAD,EURGBP,AUDCAD,USDCHF,AUDNZD,EURUSD,GBPCHF,GBPUSD,USDCAD,EURCAD,EURAUD,GBPCAD,EURNZD,GBPAUD,GBPNZD,NZDJPY,AUDJPY,CADJPY,USDJPY,EURJPY,CHFJPY,GBPJPY"; // Symbols to trade comma seperated

input group    "Expert Advisor settings";
input bool     showComment = true; // Show table, disable for faster testing
input int      magicNumber = 901239; // Magic number

CTrade trade;
CPositionInfo position;
COrderInfo order;

CChartObjectLabel*      title             = new CChartObjectLabel;
CChartObjectRectLabel*  tableRects[];
CChartObjectLabel*      tableCells[];

string   EMPTY_STRING            = " ------ ";

int      rowHeight               = 24;
int      width                   = 800;
int      padding                 = 5;
int      colSize                 = 72;
int      col[72];
int      symbolCol               = 0;
int      positionsBuyCol         = 7;
int      positionsSellCol        = 10;
int      positionsTotalCol       = 13;
int      volumeBuyCol            = 18;
int      volumeSellCol           = 23;
int      volumeTotalCol          = 28;
int      profitBuyCol            = 34;
int      profitSellCol           = 40;
int      profitTotalCol          = 46;
int      targetBuyCol            = 54;
int      targetSellCol           = 60;
int      targetTotalCol          = 66;
datetime startTime;
double   startBalance;
string   symbols                 [];
int      totalSymbols            = 0;
int      totalTrades             = 0;
int   currencyDigits;
double   leverage;
double   balance;
double   equity;
double   freeMargin;
double   allSymbolTotalProfit    = 0;
double   allSymbolTotalPositions = 0;
double   allSymbolTotalLots      = 0;
double   allSymbolTargetProfit   = 0;
double   symbolInitialLots       [];
double   symbolLowestBuyPrice    [];
double   symbolHighestBuyLots    [];
double   symbolHighestSellPrice  [];
double   symbolHighestSellLots   [];
double   symbolProfit            [];
double   symbolBuyProfit         [];
double   symbolSellProfit        [];
double   symbolTargetProfit      [];
double   symbolTargetBuyProfit   [];
double   symbolTargetSellProfit  [];
double   symbolTargetTotalProfit [];
double   symbolBuyVolume         [];
double   symbolSellVolume        [];
double   symbolTotalVolume       [];
int      symbolBuyPositions      [];
int      symbolSellPositions     [];
int      symbolTotalPositions    [];
double   symbolAsk               [];
double   symbolBid               [];
double   symbolLotMin            [];
double   symbolLotMax            [];
double   symbolLotStep           [];
double   symbolMinMargin         [];
int      symbolLotPrecision      [];
ulong    positionsToClose        [];


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void initSymbols()
  {
   int split=StringSplit(currencyPairs,",",symbols);
   totalSymbols=ArraySize(symbols);

   for(int i = 0; i < totalSymbols; i++)
     {
      if(StringLen(symbols[i]) == 0 || !SymbolSelect(symbols[i],true))
        {
         ArrayRemove(symbols, i, 1);
         i--;
         totalSymbols--;
        }
     }

   ArrayResize(symbolInitialLots, totalSymbols);
   ArrayResize(symbolLowestBuyPrice, totalSymbols);
   ArrayResize(symbolHighestBuyLots, totalSymbols);
   ArrayResize(symbolHighestSellPrice, totalSymbols);
   ArrayResize(symbolHighestSellLots, totalSymbols);
   ArrayResize(symbolProfit, totalSymbols);
   ArrayResize(symbolTargetProfit, totalSymbols);
   ArrayResize(symbolBuyProfit, totalSymbols);
   ArrayResize(symbolSellProfit, totalSymbols);
   ArrayResize(symbolTargetBuyProfit, totalSymbols);
   ArrayResize(symbolTargetSellProfit, totalSymbols);
   ArrayResize(symbolTargetTotalProfit, totalSymbols);
   ArrayResize(symbolBuyVolume, totalSymbols);
   ArrayResize(symbolSellVolume, totalSymbols);
   ArrayResize(symbolTotalVolume, totalSymbols);
   ArrayResize(symbolBuyPositions, totalSymbols);
   ArrayResize(symbolSellPositions, totalSymbols);
   ArrayResize(symbolTotalPositions, totalSymbols);
   ArrayResize(symbolAsk, totalSymbols);
   ArrayResize(symbolBid, totalSymbols);
   ArrayResize(symbolLotMin, totalSymbols);
   ArrayResize(symbolLotMax, totalSymbols);
   ArrayResize(symbolLotStep, totalSymbols);
   ArrayResize(symbolMinMargin, totalSymbols);
   ArrayResize(symbolLotPrecision, totalSymbols);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void initTable()
  {
   for(int i = 0; i < colSize; i++)
     {
      col[i] = width/colSize*i;
     }

   CreateTableRow(-1,clrLightGreen);
   CreateTableRow(0, clrForestGreen, 2);
   CreateTableRow(totalSymbols+2, clrForestGreen);

   title.Create(0,"titlebackground00",0,width-82,padding+1);
   title.FontSize(9);
   title.Color(clrForestGreen);
   title.SetString(OBJPROP_TEXT, "MintyGrid v3.4");
   title.Create(0,"titlebackground0",0,width-84,padding+1);
   title.FontSize(9);
   title.Color(clrForestGreen);
   title.SetString(OBJPROP_TEXT, "MintyGrid v3.4");
   title.Create(0,"titlebackground1",0,width-82,padding-1);
   title.FontSize(9);
   title.Color(clrForestGreen);
   title.SetString(OBJPROP_TEXT, "MintyGrid v3.4");
   title.Create(0,"titlebackground2",0,width-84,padding);
   title.FontSize(9);
   title.Color(clrForestGreen);
   title.SetString(OBJPROP_TEXT, "MintyGrid v3.4");
   title.Create(0,"titlebackground3",0,width-82,padding+1);
   title.FontSize(9);
   title.Color(clrForestGreen);
   title.SetString(OBJPROP_TEXT, "MintyGrid v3.4");
   title.Create(0,"titlebackground4",0,width-84,padding+1);
   title.FontSize(9);
   title.Color(clrForestGreen);
   title.SetString(OBJPROP_TEXT, "MintyGrid v3.4");
   title.Create(0,"title",0,width-83,padding);
   title.FontSize(9);
   title.Color(clrHoneydew);
   title.SetString(OBJPROP_TEXT, "MintyGrid v3.4");

   CreateTableCell(-1,0," Profit ");
   CreateTableCell(-1,4);
   CreateTableCell(-1,11," Trades ");
   CreateTableCell(-1,16);

   CreateTableCell(1,symbolCol," symbol ", clrLightGreen);

   CreateTableCell(0,positionsBuyCol,"positions", clrLightGreen);
   CreateTableCell(1,positionsBuyCol,"buy", clrWhite);
   CreateTableCell(1,positionsSellCol,"sell", clrWhite);
   CreateTableCell(1,positionsTotalCol,"total", clrWhite);

   CreateTableCell(0,volumeBuyCol,"volume", clrLightGreen);
   CreateTableCell(1,volumeBuyCol,"buy", clrWhite);
   CreateTableCell(1,volumeSellCol,"sell", clrWhite);
   CreateTableCell(1,volumeTotalCol,"total", clrWhite);

   CreateTableCell(0,profitBuyCol,"profit", clrLightGreen);
   CreateTableCell(1,profitBuyCol,"buy", clrWhite);
   CreateTableCell(1,profitSellCol,"sell", clrWhite);
   CreateTableCell(1,profitTotalCol,"total", clrWhite);

   CreateTableCell(0,targetBuyCol,"target profit", clrLightGreen);
   CreateTableCell(1,targetBuyCol,"buy", clrWhite);
   CreateTableCell(1,targetSellCol,"sell", clrWhite);
   CreateTableCell(1,targetTotalCol,"total", clrWhite);

   int i = 0;

   for(i; i < (totalSymbols); i++)
     {
      CreateTableRow(i+2, (bool)(i%2)?clrLightGreen:clrPaleGreen);

      CreateTableCell(i+2, symbolCol, " " + symbols[i]);
      CreateTableCell(i+2, positionsBuyCol);
      CreateTableCell(i+2, positionsSellCol);
      CreateTableCell(i+2, positionsTotalCol);
      CreateTableCell(i+2, volumeBuyCol);
      CreateTableCell(i+2, volumeSellCol);
      CreateTableCell(i+2, volumeTotalCol);
      CreateTableCell(i+2, profitBuyCol);
      CreateTableCell(i+2, profitSellCol);
      CreateTableCell(i+2, profitTotalCol);
      CreateTableCell(i+2, targetBuyCol);
      CreateTableCell(i+2, targetSellCol);
      CreateTableCell(i+2, targetTotalCol);
     }

   CreateTableCell(i+2, symbolCol," (" + (string)totalSymbols + ")", clrLightGreen);
   CreateTableCell(i+2, positionsBuyCol, clrWhite);
   CreateTableCell(i+2, positionsSellCol, clrWhite);
   CreateTableCell(i+2, positionsTotalCol, clrWhite);
   CreateTableCell(i+2, volumeBuyCol, clrWhite);
   CreateTableCell(i+2, volumeSellCol, clrWhite);
   CreateTableCell(i+2, volumeTotalCol, clrWhite);
   CreateTableCell(i+2, profitBuyCol, clrWhite);
   CreateTableCell(i+2, profitSellCol, clrWhite);
   CreateTableCell(i+2, profitTotalCol, clrWhite);
   CreateTableCell(i+2, targetBuyCol, clrWhite);
   CreateTableCell(i+2, targetSellCol, clrWhite);
   CreateTableCell(i+2, targetTotalCol, clrWhite);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void UpdateTable()
  {
   double currentProfit = AccountInfoDouble(ACCOUNT_EQUITY)-startBalance;

   UpdateTableCell(-1, 4, currentProfit);
   UpdateTableCell(-1, 16, (string)totalTrades);
   
   double positionsBuyTotal = 0;
   double positionsSellTotal = 0;
   double positionsTotal = 0;
   double volumeBuyTotal = 0;
   double volumeSellTotal = 0;
   double volumeTotal = 0;
   double profitBuyTotal = 0;
   double profitSellTotal = 0;
   double profitTotal = 0;
   double targetBuyTotal = 0;
   double targetSellTotal = 0;

   int i = 0;

   for(i; i < totalSymbols; i++)
     {
      positionsBuyTotal += symbolBuyPositions[i];
      positionsSellTotal += symbolSellPositions[i];
      positionsTotal += symbolTotalPositions[i];
      volumeBuyTotal += symbolBuyVolume[i];
      volumeSellTotal += symbolSellVolume[i];
      volumeTotal += symbolTotalVolume[i];
      profitBuyTotal += symbolBuyProfit[i];
      profitSellTotal += symbolSellProfit[i];
      profitTotal += symbolProfit[i];
      targetBuyTotal += symbolTargetBuyProfit[i];
      targetSellTotal += symbolTargetSellProfit[i];

      UpdateTableCell(i+2, symbolCol, symbolProfit[i] > 0 ? clrGreen : symbolProfit[i] < 0 ? clrRed : clrSlateGray);
      UpdateTableCell(i+2, positionsBuyCol, symbolBuyPositions[i] == 0 ? " - " : DoubleToString(symbolBuyPositions[i], 0), symbolBuyPositions[i]>=maxGridSteps?clrRed:symbolBuyPositions[i]>=breakEventGridStep?clrDarkGoldenrod:clrDarkSlateGray);
      UpdateTableCell(i+2, positionsSellCol, symbolSellPositions[i] == 0 ? " - " : DoubleToString(symbolSellPositions[i], 0), symbolSellPositions[i]>=maxGridSteps?clrRed:symbolSellPositions[i]>=breakEventGridStep?clrDarkGoldenrod:clrDarkSlateGray);
      UpdateTableCell(i+2, positionsTotalCol, DoubleToString((symbolBuyPositions[i]+symbolSellPositions[i]), 0));
      UpdateTableCell(i+2, volumeBuyCol, DoubleToString(symbolBuyVolume[i],symbolLotPrecision[i]));
      UpdateTableCell(i+2, volumeSellCol, DoubleToString(symbolSellVolume[i],symbolLotPrecision[i]));
      UpdateTableCell(i+2, volumeTotalCol, DoubleToString(symbolBuyVolume[i] + symbolSellVolume[i],symbolLotPrecision[i]));
      UpdateTableCell(i+2, profitBuyCol, symbolBuyProfit[i]);
      UpdateTableCell(i+2, profitSellCol, symbolSellProfit[i]);
      UpdateTableCell(i+2, profitTotalCol, symbolProfit[i]);
      UpdateTableCell(i+2, targetBuyCol, symbolTargetBuyProfit[i] == 0 ? EMPTY_STRING : " +" + DoubleToString(symbolTargetBuyProfit[i],currencyDigits));
      UpdateTableCell(i+2, targetSellCol, symbolTargetSellProfit[i] == 0 ? EMPTY_STRING : " +" + DoubleToString(symbolTargetSellProfit[i],currencyDigits));
      UpdateTableCell(i+2, targetTotalCol, symbolTargetTotalProfit[i] == 0 ? EMPTY_STRING : " +" + DoubleToString(symbolTargetTotalProfit[i],currencyDigits));
     }


   UpdateTableCell(i+2, positionsBuyCol, DoubleToString(positionsBuyTotal,0));
   UpdateTableCell(i+2, positionsSellCol, DoubleToString(positionsSellTotal,0));
   UpdateTableCell(i+2, positionsTotalCol, DoubleToString(positionsTotal,0));
   UpdateTableCell(i+2, volumeBuyCol, DoubleToString(volumeBuyTotal,symbolLotPrecision[0]));
   UpdateTableCell(i+2, volumeSellCol,DoubleToString(volumeSellTotal,symbolLotPrecision[0]));
   UpdateTableCell(i+2, volumeTotalCol, DoubleToString(volumeTotal,symbolLotPrecision[0]));
   UpdateTableCell(i+2, profitBuyCol, profitBuyTotal, profitBuyTotal > 0 ? clrLightGreen : profitBuyTotal < 0 ? clrMistyRose : clrWhiteSmoke);
   UpdateTableCell(i+2, profitSellCol, profitSellTotal, profitSellTotal > 0 ? clrLightGreen : profitSellTotal < 0 ? clrMistyRose : clrWhiteSmoke);
   UpdateTableCell(i+2, profitTotalCol, profitTotal, profitTotal > 0 ? clrLightGreen : profitTotal < 0 ? clrMistyRose : clrWhiteSmoke);
   UpdateTableCell(i+2, targetBuyCol, targetBuyTotal == 0 ? EMPTY_STRING : " +" + DoubleToString(targetBuyTotal,currencyDigits));
   UpdateTableCell(i+2, targetSellCol, targetSellTotal == 0 ? EMPTY_STRING : " +" + DoubleToString(targetSellTotal,currencyDigits));
   UpdateTableCell(i+2, targetTotalCol, allSymbolTargetProfit == 0 ? EMPTY_STRING : " +" + DoubleToString(allSymbolTargetProfit,currencyDigits));


   ChartRedraw();
  }

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(MQLInfoInteger(MQL_TESTER))
     {
      EventSetTimer(300);
     }
   else
     {
      EventSetMillisecondTimer(1000/33);
     }

   startTime = TimeCurrent();
   leverage = (int)AccountInfoInteger(ACCOUNT_LEVERAGE);
   currencyDigits = (int)AccountInfoInteger(ACCOUNT_CURRENCY_DIGITS);
   startBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   trade.SetExpertMagicNumber(magicNumber);
   trade.LogLevel(LOG_LEVEL_NO);

   initSymbols();

   if(MQLInfoInteger(MQL_TESTER))
     {
      for(int i=0; i<totalSymbols; i++)
        {
         CheckLoadHistory(symbols[i], _Period, 1000);
        }
     }

   if(showComment)
     {
      initTable();
     }

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CreateTableRow(int rowNum, color clr = clrLightGreen, int rows = 1)
  {
   ArrayResize(tableRects, ArraySize(tableRects)+1);
   int index = ArraySize(tableRects)-1;

   tableRects[index] = new CChartObjectRectLabel;
   tableRects[index].Create(0, "tableRects[" + (string)(index) + "]", 0,col[0],((rowNum+1)*rowHeight),width,(rowHeight*rows));
   tableRects[index].BackColor(clr);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string GetTableCellName(int rowNum, int colNum)
  {
   return "tableCell[" + (string)rowNum + "][" + (string)colNum + "]";
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int CreateTableCell(int rowNum, int colNum)
  {
   return CreateTableCell(rowNum, colNum, EMPTY_STRING);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int CreateTableCell(int rowNum, int colNum, string text, color clr = clrDarkSlateGray, int fontSize = 9)
  {
   ArrayResize(tableCells, ArraySize(tableCells)+1);
   int cellIndex = ArraySize(tableCells)-1;

   tableCells[cellIndex] = new CChartObjectLabel;
   tableCells[cellIndex].Create(0,GetTableCellName(rowNum, colNum), 0, col[colNum], 5+((rowNum+1)*rowHeight));
   tableCells[cellIndex].FontSize(fontSize);
   tableCells[cellIndex].Color(clr);

   UpdateTableCell(rowNum, colNum, text);

   return cellIndex;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int CreateTableCell(int rowNum, int colNum, color clr)
  {
   return CreateTableCell(rowNum, colNum, EMPTY_STRING, clr);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void UpdateTableCell(int cellIndex, string text, color clr = clrDarkSlateGray)
  {
   tableCells[cellIndex].SetString(OBJPROP_TEXT, text);
   tableCells[cellIndex].Color(clr);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void UpdateTableCell(int rowNum, int colNum, string text)
  {
   if(StringLen(text) > 20)
     {
      text = StringSubstr(text, 0, 20);
     }

   if(StringLen(text) == 0)
     {
      text = EMPTY_STRING;
     }

   ObjectSetString(0, GetTableCellName(rowNum, colNum), OBJPROP_TEXT, " " + text);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void UpdateTableCell(int rowNum, int colNum, color clr)
  {
   ObjectSetInteger(0, GetTableCellName(rowNum, colNum), OBJPROP_COLOR, clr);

  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void UpdateTableCell(int rowNum, int colNum, double number)
  {
   UpdateTableCell(rowNum, colNum, number, number > 0 ? clrGreen : number < 0 ? clrRed : clrSlateGray);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void UpdateTableCell(int rowNum, int colNum, double number, color clr)
  {
   string text = EMPTY_STRING;
   if(number != INT_MAX && number != INT_MIN)
     {
      number = NormalizeDouble(number, currencyDigits);
      text = " " + (number > 0 ? "+" + DoubleToString(number, currencyDigits) : number < 0 ? DoubleToString(number, currencyDigits) : EMPTY_STRING);
     }
   ObjectSetString(0, GetTableCellName(rowNum, colNum), OBJPROP_TEXT, text);
   ObjectSetInteger(0, GetTableCellName(rowNum, colNum), OBJPROP_COLOR, clr);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void UpdateTableCell(int rowNum, int colNum, string text, color clr)
  {
   UpdateTableCell(rowNum, colNum, text);
   ObjectSetInteger(0, GetTableCellName(rowNum, colNum), OBJPROP_COLOR, clr);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnTesterInit(void)
  {
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTesterDeinit(void)
  {

  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTimer()
  {
   if(showComment)
     {
      UpdateTable();
     }
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- destroy timer
   EventKillTimer();

  }

//+------------------------------------------------------------------+
//| Expert handleSymbol function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {

   updateBalance();

   for(int i = 0; i < totalSymbols; i++)
     {
      handleSymbol(i);
     }

   closeOpenPositions();
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void resetData(int symbolIndex)
  {
   allSymbolTotalProfit                   = 0;
   allSymbolTotalPositions                = 0;
   allSymbolTotalLots                     = 0;
   allSymbolTargetProfit                  = 0;

   symbolInitialLots       [symbolIndex]  = 0;
   symbolLowestBuyPrice    [symbolIndex]  = 0;
   symbolHighestBuyLots    [symbolIndex]  = 0;
   symbolHighestSellPrice  [symbolIndex]  = 0;
   symbolHighestSellLots   [symbolIndex]  = 0;
   symbolProfit            [symbolIndex]  = 0;
   symbolBuyProfit         [symbolIndex]  = 0;
   symbolSellProfit        [symbolIndex]  = 0;
   symbolTargetBuyProfit   [symbolIndex]  = 0;
   symbolTargetSellProfit  [symbolIndex]  = 0;
   symbolTargetTotalProfit [symbolIndex]  = 0;
   symbolBuyVolume         [symbolIndex]  = 0;
   symbolSellVolume        [symbolIndex]  = 0;
   symbolTotalVolume       [symbolIndex]  = 0;
   symbolBuyPositions      [symbolIndex]  = 0;
   symbolSellPositions     [symbolIndex]  = 0;
   symbolTotalPositions    [symbolIndex]  = 0;

   symbolAsk               [symbolIndex]  = SymbolInfoDouble(symbols[symbolIndex], SYMBOL_ASK);
   symbolBid               [symbolIndex]  = SymbolInfoDouble(symbols[symbolIndex], SYMBOL_BID);
   symbolLotMin            [symbolIndex]  = SymbolInfoDouble(symbols[symbolIndex], SYMBOL_VOLUME_MIN);
   symbolLotMax            [symbolIndex]  = SymbolInfoDouble(symbols[symbolIndex], SYMBOL_VOLUME_LIMIT) == 0 ? SymbolInfoDouble(symbols[symbolIndex], SYMBOL_VOLUME_MAX) : SymbolInfoDouble(symbols[symbolIndex], SYMBOL_VOLUME_LIMIT);
   symbolLotStep           [symbolIndex]  = SymbolInfoDouble(symbols[symbolIndex], SYMBOL_VOLUME_MIN);
   symbolMinMargin         [symbolIndex]  = GetMinMargin(symbolIndex);

   symbolLotPrecision      [symbolIndex]  = GetDoublePrecision(symbolLotStep[symbolIndex]);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void updateBalance()
  {
   balance        = AccountInfoDouble(ACCOUNT_BALANCE);
   equity         = AccountInfoDouble(ACCOUNT_EQUITY);
   freeMargin     = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void filterPositions(int symbolIndex)
  {
   resetData(symbolIndex);

   for(int i = 0; i < PositionsTotal(); i++)
     {
      position.SelectByIndex(i);
      if(position.Magic() == magicNumber)
        {
         allSymbolTotalPositions++;
         allSymbolTotalLots += position.Volume();
         allSymbolTotalProfit += position.Profit();

         if(position.Symbol() == symbols[symbolIndex])
           {
            symbolTotalPositions[symbolIndex]++;
            symbolProfit[symbolIndex] += position.Profit();
            symbolTotalVolume[symbolIndex] += position.Volume();

            if(position.PositionType() == POSITION_TYPE_BUY)
              {
               symbolBuyPositions[symbolIndex]++;
               symbolBuyVolume[symbolIndex] += position.Volume();
               symbolBuyProfit[symbolIndex] += position.Profit();

               if(symbolLowestBuyPrice[symbolIndex] == 0 || position.PriceOpen() < symbolLowestBuyPrice[symbolIndex])
                 {
                  symbolLowestBuyPrice[symbolIndex] = position.PriceOpen();
                 }
               if(symbolHighestBuyLots[symbolIndex] == 0 || position.Volume() > symbolHighestBuyLots[symbolIndex])
                 {
                  symbolHighestBuyLots[symbolIndex] = position.Volume();
                 }
              }

            if(position.PositionType() == POSITION_TYPE_SELL)
              {
               symbolSellPositions[symbolIndex]++;
               symbolSellVolume[symbolIndex] += position.Volume();
               symbolSellProfit[symbolIndex] += position.Profit();

               if(symbolHighestSellPrice[symbolIndex] == 0 || position.PriceOpen() > symbolHighestSellPrice[symbolIndex])
                 {
                  symbolHighestSellPrice[symbolIndex] = position.PriceOpen();
                 }
               if(symbolHighestSellLots[symbolIndex] == 0 || position.Volume() > symbolHighestSellLots[symbolIndex])
                 {
                  symbolHighestSellLots[symbolIndex] = position.Volume();
                 }
              }
           }
        }
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void calculateRisk(int symbolIndex)
  {
   if(riskBase == Balance)
     {
      symbolInitialLots [symbolIndex] = NormalizeVolume((balance/symbolMinMargin[symbolIndex])*symbolLotStep[symbolIndex]/balance*riskFactor, symbolIndex);
     }

   if(riskBase == Equity)
     {
      symbolInitialLots[symbolIndex] = NormalizeVolume((equity/symbolMinMargin[symbolIndex])*symbolLotStep[symbolIndex]/equity*riskFactor, symbolIndex);
     }

   if(riskBase == Margin)
     {
      symbolInitialLots[symbolIndex] = NormalizeVolume((freeMargin/symbolMinMargin[symbolIndex])*symbolLotStep[symbolIndex]/equity*riskFactor, symbolIndex);
     }

   symbolInitialLots[symbolIndex]    = NormalizeVolume(symbolInitialLots[symbolIndex] < symbolLotMin[symbolIndex] ? symbolLotMin[symbolIndex] : symbolInitialLots[symbolIndex] > symbolLotMax[symbolIndex]/gridStepMultiplier/maxGridSteps ? symbolLotMax[symbolIndex]/gridStepMultiplier/maxGridSteps : symbolInitialLots[symbolIndex], symbolIndex);
   symbolTargetProfit[symbolIndex]   = symbolInitialLots[symbolIndex]/symbolLotStep[symbolIndex]*symbolMinMargin[symbolIndex]*profitFactor;

   if(riskType == Fixed)
     {
      symbolInitialLots[symbolIndex] = riskFactor;
     }

   if(profitType == Fixed)
     {
      symbolTargetTotalProfit[symbolIndex] = profitFactor;
     }

   symbolTargetSellProfit[symbolIndex] = symbolSellPositions[symbolIndex] == 0 ? 0 : symbolTargetProfit[symbolIndex]+((symbolTargetProfit[symbolIndex]*(symbolSellVolume[symbolIndex]/symbolInitialLots[symbolIndex]))*gridStepProfitMultiplier);
   symbolTargetBuyProfit[symbolIndex] = symbolBuyPositions[symbolIndex] == 0 ? 0 : symbolTargetProfit[symbolIndex]+((symbolTargetProfit[symbolIndex]*(symbolBuyVolume[symbolIndex]/symbolInitialLots[symbolIndex]))*gridStepProfitMultiplier);
   symbolTargetTotalProfit[symbolIndex] = symbolTotalPositions[symbolIndex] == 0 ? 0 : symbolTargetProfit[symbolIndex]+((symbolTargetProfit[symbolIndex]*(symbolTotalVolume[symbolIndex]/symbolInitialLots[symbolIndex]))*gridStepProfitMultiplier);

   allSymbolTargetProfit = totalSymbols == 0 ? 0 : symbolTargetProfit[symbolIndex]+((symbolTargetProfit[symbolIndex]*allSymbolTotalLots/symbolInitialLots[symbolIndex]/totalSymbols)*gridStepProfitMultiplier);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void takeProfit(int symbolIndex)
  {
   if(symbolBuyPositions[symbolIndex] >= breakEventGridStep && breakEventGridStep > 0)
     {
      symbolTargetBuyProfit[symbolIndex] = 0;
     }

   if(symbolSellPositions[symbolIndex] >= breakEventGridStep && breakEventGridStep > 0)
     {
      symbolTargetSellProfit[symbolIndex] = 0;
     }

   if(symbolSellProfit[symbolIndex] >= symbolTargetSellProfit[symbolIndex] && symbolSellProfit[symbolIndex] > 0)
     {
      for(int i = 0; i < PositionsTotal(); i++)
        {
         position.SelectByIndex(i);
         if(position.PositionType() == POSITION_TYPE_SELL && position.Symbol() == symbols[symbolIndex] && position.Magic() == magicNumber)
           {
            closePosition(position.Ticket());
           }
        }
     }

   if(symbolBuyProfit[symbolIndex] >= symbolTargetBuyProfit[symbolIndex] && symbolBuyProfit[symbolIndex] > 0)
     {
      for(int i = 0; i < PositionsTotal(); i++)
        {
         position.SelectByIndex(i);
         if(position.PositionType() == POSITION_TYPE_BUY && position.Symbol() == symbols[symbolIndex] && position.Magic() == magicNumber)
           {
            closePosition(position.Ticket());
           }
        }
     }

   if(symbolProfit[symbolIndex] >= symbolTargetTotalProfit[symbolIndex] && symbolProfit[symbolIndex] > 0)
     {
      for(int i = 0; i < PositionsTotal(); i++)
        {
         position.SelectByIndex(i);
         if(position.Symbol() == symbols[symbolIndex] && position.Magic() == magicNumber)
           {
            closePosition(position.Ticket());
           }
        }
     }

   if(allSymbolTotalProfit >= allSymbolTargetProfit && allSymbolTotalProfit > 0)
     {
      for(int i = 0; i < PositionsTotal(); i++)
        {
         position.SelectByIndex(i);
         if(position.Magic() == magicNumber)
           {
            closePosition(position.Ticket());
           }
        }
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void tradeSymbol(int symbolIndex)
  {
   if(symbolLowestBuyPrice[symbolIndex]-(((symbolAsk[symbolIndex]-symbolBid[symbolIndex])*100*gridStep)*((symbolBuyPositions[symbolIndex]*gridStepMultiplier)+1)) >= symbolAsk[symbolIndex] && symbolBuyVolume[symbolIndex] != 0 && symbolBuyPositions[symbolIndex] < maxGridSteps && !IsNetting())
     {
      double volume = lotMultiplier == 0 ? symbolInitialLots[symbolIndex] : symbolBuyPositions[symbolIndex]*symbolInitialLots[symbolIndex]*lotMultiplier > symbolHighestBuyLots[symbolIndex]*lotMultiplier ? symbolBuyPositions[symbolIndex]*symbolInitialLots[symbolIndex]*lotMultiplier : symbolHighestBuyLots[symbolIndex]*lotMultiplier;
      double sl = stopLoss > 0 ? symbolAsk[symbolIndex]-(symbolAsk[symbolIndex]/100*stopLoss) : 0;

      Buy(symbolIndex,volume,sl);
     }

   if(symbolHighestSellPrice[symbolIndex]+(((symbolAsk[symbolIndex]-symbolBid[symbolIndex])*100*gridStep)*((symbolSellPositions[symbolIndex]*gridStepMultiplier)+1)) <= symbolBid[symbolIndex] && symbolSellVolume[symbolIndex] != 0 && symbolSellPositions[symbolIndex] < maxGridSteps && !IsNetting())
     {
      double volume = lotMultiplier == 0 ? symbolInitialLots[symbolIndex] : symbolSellPositions[symbolIndex]*symbolInitialLots[symbolIndex]*lotMultiplier > symbolHighestSellLots[symbolIndex]*lotMultiplier ? symbolSellPositions[symbolIndex]*symbolInitialLots[symbolIndex]*lotMultiplier : symbolHighestSellLots[symbolIndex]*lotMultiplier;
      double sl = stopLoss > 0 ? symbolBid[symbolIndex]+(symbolBid[symbolIndex]/100*stopLoss) : 0;

      Sell(symbolIndex,volume,sl);
     }

   if((symbolBuyPositions[symbolIndex] == 0) && (symbolSellPositions[symbolIndex] == 0 || (symbolAsk[symbolIndex] < symbolHighestSellPrice[symbolIndex]-(((symbolAsk[symbolIndex]-symbolBid[symbolIndex])/100*gridStep)*((gridStepMultiplier*gridReverseStepMultiplier))) && sell)) && buy)
     {
      double highestLot = symbolSellPositions[symbolIndex] == 0 ? 0 : gridReverseLotDeviser > 0 ? symbolSellVolume[symbolIndex]/symbolSellPositions[symbolIndex]/gridReverseLotDeviser : 0;
      double volume = IsNetting() ? symbolLotMin[symbolIndex] : highestLot < symbolInitialLots[symbolIndex] ? symbolInitialLots[symbolIndex] : highestLot;
      double sl = stopLoss > 0 ? symbolAsk[symbolIndex]-(symbolAsk[symbolIndex]/100*stopLoss) : 0;

      Buy(symbolIndex,volume,sl);
     }

   if((symbolSellPositions[symbolIndex] == 0) && (symbolBuyPositions[symbolIndex] == 0 || (symbolBid[symbolIndex] > symbolLowestBuyPrice[symbolIndex]+(((symbolAsk[symbolIndex]-symbolBid[symbolIndex])/100*gridStep)*((gridStepMultiplier*gridReverseStepMultiplier))) && buy)) && sell)
     {
      double highestLot = symbolBuyPositions[symbolIndex] == 0 ? 0 : gridReverseLotDeviser > 0 ? symbolBuyVolume[symbolIndex]/symbolBuyPositions[symbolIndex]/gridReverseLotDeviser : 0;
      double volume = IsNetting() ? symbolLotMin[symbolIndex] : highestLot < symbolInitialLots[symbolIndex] ? symbolInitialLots[symbolIndex] : highestLot;
      double sl = stopLoss > 0 ? symbolBid[symbolIndex]+(symbolBid[symbolIndex]/100*stopLoss) : 0;

      Sell(symbolIndex,volume,sl);
     }
  }

//+------------------------------------------------------------------+
//| Expert handleSymbol function                                     |
//+------------------------------------------------------------------+
void handleSymbol(int symbolIndex)
  {
   filterPositions(symbolIndex);
   calculateRisk(symbolIndex);
   takeProfit(symbolIndex);
   tradeSymbol(symbolIndex);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void Buy(int symbolIndex, double volume, double sl = 0.0)
  {
   volume = NormalizeVolume(volume, symbolIndex);
   if(CheckMoneyForTrade(symbols[symbolIndex],volume,ORDER_TYPE_BUY) && CheckVolumeValue(symbols[symbolIndex],volume))
     {
      trade.Buy(volume, symbols[symbolIndex], 0, sl, 0, "MintyGrid Buy " + symbols[symbolIndex] + " step " + IntegerToString(symbolBuyPositions[symbolIndex] + 1));
      totalTrades++;
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void Sell(int symbolIndex, double volume, double sl = 0.0)
  {
   volume = NormalizeVolume(volume, symbolIndex);
   if(CheckMoneyForTrade(symbols[symbolIndex],volume,ORDER_TYPE_SELL) && CheckVolumeValue(symbols[symbolIndex],volume))
     {
      trade.Sell(volume, symbols[symbolIndex], 0, sl, 0, "MintyGrid Sell " + symbols[symbolIndex] + " step " + IntegerToString(symbolSellPositions[symbolIndex] + 1));
      totalTrades++;
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double NormalizeVolume(double volume, int symbolIndex)
  {
   volume = NormalizeDouble(symbolLotStep[symbolIndex]*MathRound(volume/symbolLotStep[symbolIndex]),symbolLotPrecision[symbolIndex]);
   return NormalizeDouble(volume < symbolLotMin[symbolIndex] ? symbolLotMin[symbolIndex] : volume > symbolLotMax[symbolIndex] ? symbolLotMax[symbolIndex] : volume,symbolLotPrecision[symbolIndex]);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CheckMoneyForTrade(string symb,double lots,ENUM_ORDER_TYPE type)
  {
//--- Getting the opening price
   MqlTick mqltick;
   SymbolInfoTick(symb,mqltick);
   double price=mqltick.ask;
   if(type==ORDER_TYPE_SELL)
      price=mqltick.bid;
   double margin,free_margin=AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   if(!OrderCalcMargin(type,symb,lots,price,margin))
     {

      return(false);
     }
   if(margin>free_margin)
     {

      return(false);
     }
   return(true);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int StringSplit(string string_value,string separator,string &result[],int limit = 0)
  {
   int n=1, pos=-1, len=StringLen(separator);
   while((pos=StringFind(string_value,separator,pos))>=0)
     {
      ArrayResize(result,++n);
      result[n-1]=StringSubstr(string_value,0,pos);
      if(n==limit)
         return n;
      string_value=StringSubstr(string_value,pos+len);
      pos=-1;
     }
//--- append the last part
   ArrayResize(result,++n);
   result[n-1]=string_value;
   return n;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void closePosition(ulong ticket)
  {
   int index = ArraySize(positionsToClose);

   for(int i = 0; i < index; i++)
     {
      if(positionsToClose[i] == ticket)
        {
         return;
        }
     }

   ArrayResize(positionsToClose, index+1);
   positionsToClose[index] = ticket;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void closeOpenPositions()
  {
   for(int i = 0; i < ArraySize(positionsToClose); i++)
     {
      position.SelectByTicket(positionsToClose[i]);
      if(position.PriceCurrent() > 0)
        {
         trade.PositionClose(position.Ticket());
        }
      else
        {
         ArrayRemove(positionsToClose, i, 1);
        }
     }
  }

//+------------------------------------------------------------------+
//| Check the correctness of the order volume                        |
//+------------------------------------------------------------------+
bool CheckVolumeValue(string symbol, double volume)
  {
//--- minimal allowed volume for trade operations
   double min_volume=SymbolInfoDouble(symbol,SYMBOL_VOLUME_MIN);
   if(volume<min_volume)
     {
      return(false);
     }

//--- maximal allowed volume of trade operations
   double max_volume=SymbolInfoDouble(symbol,SYMBOL_VOLUME_MAX);
   if(volume>max_volume)
     {
      return(false);
     }

//--- get minimal step of volume changing
   double volume_step=SymbolInfoDouble(symbol,SYMBOL_VOLUME_STEP);

   int ratio=(int)MathRound(volume/volume_step);
   if(MathAbs(ratio*volume_step-volume)>0.0000001)
     {
      return(false);
     }

   return true;

  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsNetting()
  {
   ENUM_ACCOUNT_MARGIN_MODE res = (ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE);
   return(res==ACCOUNT_MARGIN_MODE_RETAIL_NETTING);
  }

//+------------------------------------------------------------------+
//| Counts decimals places of a double                               |
//+------------------------------------------------------------------+
int GetDoublePrecision(double number)
  {
   int precision = 0;
   number = number < 0 ? number*-1 : number; // make a negative number positive
   for(number; number-(int)NormalizeDouble(number, 0)>0; number*=10, precision++)
     {
      if(precision>16)
         break;
     }
   return precision;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetMinMargin(int symbolIndex)
  {
//--- Getting the opening price
   MqlTick mqltick;
   SymbolInfoTick(symbols[symbolIndex],mqltick);
   double price=mqltick.ask;
   double margin,free_margin=AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   if(!OrderCalcMargin(ORDER_TYPE_BUY,symbols[symbolIndex],symbolLotStep[symbolIndex],price,margin))
     {
      return -1;
     }

   return margin;
  }
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
