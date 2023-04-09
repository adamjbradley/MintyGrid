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
#property version   "4.2"

#include <checkhistory.mqh>
#include <Trade/Trade.mqh>
#include <ChartObjects\ChartObjectsShapes.mqh>
#include <ChartObjects\ChartObjectsTxtControls.mqh>

enum RiskBase   {Balance, Equity, Margin};
enum RiskType   {Fixed, Dynamic};

input group    "Risk settings";
input RiskType riskType                   = Dynamic;  // Whether to use fixed or dynamic risk
input RiskBase riskBase                   = Margin;   // Factor to base risk on when using dynamic risk
input double   riskFactor                 = 10.0;     // Fixed lot size or dynamic risk factor
input double   stopLoss                   = 0.00;     // Percentage of price to be used as stop loss (0 to disable)

input group    "Profit settings";
input RiskType profitType                 = Dynamic;  // Whether to use fixed or dynamic profit
input RiskBase profitBase                 = Margin;   // Factor to base profit on when using dynamic profit
input double   profitFactor               = 10.0;     // Fixed profit in deposit currency or dynamic profit factor
input double   profitManyPairsDeviser     = 0.00;     // Factor to divide total profit by for all symbol profit

input group    "Martingale grid settings";
input int      gridStepMax                = 10;       // Maximum amount of grid steps per direction
input int      gridStepBreakEven          = 3;        // Try break even on grid step (0 to disable)
input double   gridStepMovement           = 0.03;     // Step price movement percentage
input double   gridStepMultiplier         = 3.33;     // Step price movement multiplier (0 to disable)
input double   gridReverseStepMultiplier  = 1.00;     // Reverse price movement multiplier (0 to disable)
input double   gridStepProfitMultiplier   = 1.00;     // Step profit multiplier (0 to disable)
input double   gridStepLotMultiplier      = 2.00;     // Step martingale lot multiplier (0 to disable)
input double   gridReverseLotDeviser      = 1.50;     // Reverse martingale lot deviser (0 to disable)

input group    "Trade settings";
input bool     buy                        = true;     // Whether to enable buy trades
input bool     sell                       = true;     // Whether to enable sell trades

input group    "Symbol settings";
input string   currencyPairs              = "EURUSD,EURGBP,GBPUSD"; // Symbols to trade comma seperated

input group    "Expert Advisor settings";
input bool     showComment                = true;     // Show table, disable for faster testing
input int      magicNumber                = 901239;   // Magic number

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
int      currencyDigits;
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
MqlTick  symbolCurrentTick       [];
MqlTick  symbolLastTick          [];
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
   ArrayResize(symbolCurrentTick, totalSymbols);
   ArrayResize(symbolLastTick, totalSymbols);
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
   title.SetString(OBJPROP_TEXT, "MintyGrid v4.1");
   title.Create(0,"titlebackground0",0,width-84,padding+1);
   title.FontSize(9);
   title.Color(clrForestGreen);
   title.SetString(OBJPROP_TEXT, "MintyGrid v4.1");
   title.Create(0,"titlebackground1",0,width-82,padding-1);
   title.FontSize(9);
   title.Color(clrForestGreen);
   title.SetString(OBJPROP_TEXT, "MintyGrid v4.1");
   title.Create(0,"titlebackground2",0,width-84,padding);
   title.FontSize(9);
   title.Color(clrForestGreen);
   title.SetString(OBJPROP_TEXT, "MintyGrid v4.1");
   title.Create(0,"titlebackground3",0,width-82,padding+1);
   title.FontSize(9);
   title.Color(clrForestGreen);
   title.SetString(OBJPROP_TEXT, "MintyGrid v4.1");
   title.Create(0,"titlebackground4",0,width-84,padding+1);
   title.FontSize(9);
   title.Color(clrForestGreen);
   title.SetString(OBJPROP_TEXT, "MintyGrid v4.1");
   title.Create(0,"title",0,width-83,padding);
   title.FontSize(9);
   title.Color(clrHoneydew);
   title.SetString(OBJPROP_TEXT, "MintyGrid v4.1");


   CreateTableCell(-1,  0,                " Profit ");
   CreateTableCell(-1,  4);

   CreateTableCell(-1,  11,               " Trades ");
   CreateTableCell(-1,  16);

   CreateTableCell(1, symbolCol,          " symbol",        clrLightGreen);

   CreateTableCell(0, positionsBuyCol,    "positions",      clrLightGreen);
   CreateTableCell(1, positionsBuyCol,    "buy",            clrWhite);
   CreateTableCell(1, positionsSellCol,   "sell",           clrWhite);
   CreateTableCell(1, positionsTotalCol,  "total",          clrWhite);

   CreateTableCell(0, volumeBuyCol,       "volume",         clrLightGreen);
   CreateTableCell(1, volumeBuyCol,       "buy",            clrWhite);
   CreateTableCell(1, volumeSellCol,      "sell",           clrWhite);
   CreateTableCell(1, volumeTotalCol,     "total",          clrWhite);

   CreateTableCell(0, profitBuyCol,       "profit",         clrLightGreen);
   CreateTableCell(1, profitBuyCol,       "buy",            clrWhite);
   CreateTableCell(1, profitSellCol,      "sell",           clrWhite);
   CreateTableCell(1, profitTotalCol,     "total",          clrWhite);

   CreateTableCell(0, targetBuyCol,       "target profit",  clrLightGreen);
   CreateTableCell(1, targetBuyCol,       "buy",            clrWhite);
   CreateTableCell(1, targetSellCol,      "sell",           clrWhite);
   CreateTableCell(1, targetTotalCol,     "total",          clrWhite);

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
   CreateTableCell(i+2, positionsBuyCol,     clrWhite);
   CreateTableCell(i+2, positionsSellCol,    clrWhite);
   CreateTableCell(i+2, positionsTotalCol,   clrWhite);
   CreateTableCell(i+2, volumeBuyCol,        clrWhite);
   CreateTableCell(i+2, volumeSellCol,       clrWhite);
   CreateTableCell(i+2, volumeTotalCol,      clrWhite);
   CreateTableCell(i+2, profitBuyCol,        clrWhite);
   CreateTableCell(i+2, profitSellCol,       clrWhite);
   CreateTableCell(i+2, profitTotalCol,      clrWhite);
   CreateTableCell(i+2, targetBuyCol,        clrWhite);
   CreateTableCell(i+2, targetSellCol,       clrWhite);
   CreateTableCell(i+2, targetTotalCol,      clrWhite);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void UpdateTable()
  {
   double currentProfit = AccountInfoDouble(ACCOUNT_EQUITY)-startBalance;

   UpdateTableCell(-1, 4,  currentProfit);
   UpdateTableCell(-1, 16, (string)totalTrades);

   double positionsBuyTotal      = 0;
   double positionsSellTotal     = 0;
   double positionsTotal         = 0;
   double volumeBuyTotal         = 0;
   double volumeSellTotal        = 0;
   double volumeTotal            = 0;
   double profitBuyTotal         = 0;
   double profitSellTotal        = 0;
   double profitTotal            = 0;
   double targetBuyTotal         = 0;
   double targetSellTotal        = 0;

   int i = 0;

   for(i; i < totalSymbols; i++)
     {
      positionsBuyTotal    += symbolBuyPositions[i];
      positionsSellTotal   += symbolSellPositions[i];
      positionsTotal       += symbolTotalPositions[i];
      volumeBuyTotal       += symbolBuyVolume[i];
      volumeSellTotal      += symbolSellVolume[i];
      volumeTotal          += symbolTotalVolume[i];
      profitBuyTotal       += symbolBuyProfit[i];
      profitSellTotal      += symbolSellProfit[i];
      profitTotal          += symbolProfit[i];
      targetBuyTotal       += symbolTargetBuyProfit[i];
      targetSellTotal      += symbolTargetSellProfit[i];

      UpdateTableCell(i+2, symbolCol,        symbolProfit[i] > 0 ? clrGreen : symbolProfit[i] < 0 ? clrRed : clrSlateGray);

      UpdateTableCell(i+2, positionsBuyCol,  StringLen(DoubleToString(symbolBuyPositions[i],  0)) > 3 ? StringSubstr(DoubleToString(symbolBuyPositions[i],  0),3) : symbolBuyPositions[i]  == 0 ? " - " : DoubleToString(symbolBuyPositions[i], 0),  symbolBuyPositions[i]   >= gridStepMax ? clrRed : symbolBuyPositions[i]  >= gridStepBreakEven ? clrDarkGoldenrod : clrDarkSlateGray);
      UpdateTableCell(i+2, positionsSellCol, StringLen(DoubleToString(symbolSellPositions[i], 0)) > 3 ? StringSubstr(DoubleToString(symbolSellPositions[i], 0),3) : symbolSellPositions[i] == 0 ? " - " : DoubleToString(symbolSellPositions[i], 0), symbolSellPositions[i]  >= gridStepMax ? clrRed : symbolSellPositions[i] >= gridStepBreakEven ? clrDarkGoldenrod : clrDarkSlateGray);
      UpdateTableCell(i+2, positionsTotalCol,DoubleToString((symbolBuyPositions[i]+symbolSellPositions[i]), 0));

      UpdateTableCell(i+2, volumeBuyCol,     DoubleToString(symbolBuyVolume[i],symbolLotPrecision[i]));
      UpdateTableCell(i+2, volumeSellCol,    DoubleToString(symbolSellVolume[i],symbolLotPrecision[i]));
      UpdateTableCell(i+2, volumeTotalCol,   DoubleToString(symbolBuyVolume[i]+symbolSellVolume[i],symbolLotPrecision[i]));

      UpdateTableCell(i+2, profitBuyCol,     symbolBuyProfit[i]);
      UpdateTableCell(i+2, profitSellCol,    symbolSellProfit[i]);
      UpdateTableCell(i+2, profitTotalCol,   symbolProfit[i]);

      UpdateTableCell(i+2, targetBuyCol,     symbolTargetBuyProfit[i]   < 0 ? 0 : symbolTargetBuyProfit[i],   symbolBuyPositions[i]      == 0 ? clrSlateGray : symbolBuyPositions[i]   >= gridStepMax ? clrRed : symbolBuyPositions[i]  >= gridStepBreakEven ? clrDarkGoldenrod : clrDarkSlateGray);
      UpdateTableCell(i+2, targetSellCol,    symbolTargetSellProfit[i]  < 0 ? 0 : symbolTargetSellProfit[i],  symbolSellPositions[i]     == 0 ? clrSlateGray : symbolSellPositions[i]  >= gridStepMax ? clrRed : symbolSellPositions[i] >= gridStepBreakEven ? clrDarkGoldenrod : clrDarkSlateGray);
      UpdateTableCell(i+2, targetTotalCol,   symbolTargetTotalProfit[i] < 0 ? 0 : symbolTargetTotalProfit[i], symbolTargetTotalProfit[i] == 0 ? clrSlateGray : clrDarkSlateGray);
     }


   UpdateTableCell(i+2, positionsBuyCol,   DoubleToString(positionsBuyTotal,   0));
   UpdateTableCell(i+2, positionsSellCol,  DoubleToString(positionsSellTotal,  0));
   UpdateTableCell(i+2, positionsTotalCol, DoubleToString(positionsTotal,      0));

   UpdateTableCell(i+2, volumeBuyCol,      DoubleToString(volumeBuyTotal,   symbolLotPrecision[0]));
   UpdateTableCell(i+2, volumeSellCol,     DoubleToString(volumeSellTotal,  symbolLotPrecision[0]));
   UpdateTableCell(i+2, volumeTotalCol,    DoubleToString(volumeTotal,      symbolLotPrecision[0]));

   UpdateTableCell(i+2, profitBuyCol,      profitBuyTotal,   profitBuyTotal  > 0 ? clrLightGreen : profitBuyTotal  < 0 ? clrMistyRose : clrWhiteSmoke);
   UpdateTableCell(i+2, profitSellCol,     profitSellTotal,  profitSellTotal > 0 ? clrLightGreen : profitSellTotal < 0 ? clrMistyRose : clrWhiteSmoke);
   UpdateTableCell(i+2, profitTotalCol,    profitTotal,      profitTotal     > 0 ? clrLightGreen : profitTotal     < 0 ? clrMistyRose : clrWhiteSmoke);

   UpdateTableCell(i+2, targetBuyCol,      targetBuyTotal < 0 ? 0 : targetBuyTotal,        clrMintCream);
   UpdateTableCell(i+2, targetSellCol,     targetSellTotal < 0 ? 0 : targetSellTotal,       clrMintCream);
   UpdateTableCell(i+2, targetTotalCol,    allSymbolTargetProfit < 0 ? 0 : allSymbolTargetProfit, clrMintCream);

   ChartRedraw();
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
void UpdateTableCell(int rowNum, int colNum, double number, color clr, int maxLength = 8)
  {
   number = NormalizeDouble(number, currencyDigits);
   string   prefix = "";
   bool     negative = false;

   if(number < 0)
     {
      negative = true;
      number *= -1;
     }


   string   text = DoubleToString(number, currencyDigits);
   int length = StringLen(DoubleToString(number, currencyDigits));


   for(int i = 0; i < maxLength-length; i++)
     {
      prefix += " .";
     }

   if(StringCompare(StringSubstr(StringSubstr(text, 0, maxLength), StringLen(StringSubstr(text, 0, maxLength))-1, 1), ".") == 0)
     {

      prefix += " .";

      text = DoubleToString(number, 0);
     }
   else
     {
      text = DoubleToString(number, currencyDigits);
     }

   ObjectSetString(0, GetTableCellName(rowNum, colNum), OBJPROP_TEXT, prefix + (negative ? " -" : number == 0 ? " ." : "+") + StringSubstr(text, 0, maxLength));
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
void ResetData(int sIndex)
  {
   allSymbolTotalProfit              = 0;
   allSymbolTotalPositions           = 0;
   allSymbolTotalLots                = 0;
   allSymbolTargetProfit             = 0;

   symbolInitialLots       [sIndex]  = 0;
   symbolLowestBuyPrice    [sIndex]  = 0;
   symbolHighestBuyLots    [sIndex]  = 0;
   symbolHighestSellPrice  [sIndex]  = 0;
   symbolHighestSellLots   [sIndex]  = 0;
   symbolProfit            [sIndex]  = 0;
   symbolBuyProfit         [sIndex]  = 0;
   symbolSellProfit        [sIndex]  = 0;
   symbolTargetBuyProfit   [sIndex]  = 0;
   symbolTargetSellProfit  [sIndex]  = 0;
   symbolTargetTotalProfit [sIndex]  = 0;
   symbolBuyVolume         [sIndex]  = 0;
   symbolSellVolume        [sIndex]  = 0;
   symbolTotalVolume       [sIndex]  = 0;
   symbolBuyPositions      [sIndex]  = 0;
   symbolSellPositions     [sIndex]  = 0;
   symbolTotalPositions    [sIndex]  = 0;

   symbolAsk               [sIndex]  = SymbolInfoDouble(symbols[sIndex], SYMBOL_ASK);
   symbolBid               [sIndex]  = SymbolInfoDouble(symbols[sIndex], SYMBOL_BID);
   symbolLotMin            [sIndex]  = SymbolInfoDouble(symbols[sIndex], SYMBOL_VOLUME_MIN);
   symbolLotMax            [sIndex]  = SymbolInfoDouble(symbols[sIndex], SYMBOL_VOLUME_LIMIT) == 0 ? SymbolInfoDouble(symbols[sIndex], SYMBOL_VOLUME_MAX) : SymbolInfoDouble(symbols[sIndex], SYMBOL_VOLUME_LIMIT);
   symbolLotStep           [sIndex]  = SymbolInfoDouble(symbols[sIndex], SYMBOL_VOLUME_MIN);
   symbolMinMargin         [sIndex]  = GetMinMargin(sIndex);

   symbolLotPrecision      [sIndex]  = GetDoublePrecision(symbolLotStep[sIndex]);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void UpdateBalance()
  {
   balance        = AccountInfoDouble(ACCOUNT_BALANCE);
   equity         = AccountInfoDouble(ACCOUNT_EQUITY);
   freeMargin     = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void FilterPositions(int sIndex)
  {
   ResetData(sIndex);

   for(int i = 0; i < PositionsTotal(); i++)
     {
      position.SelectByIndex(i);
      if(position.Magic() == magicNumber)
        {
         allSymbolTotalPositions++;
         allSymbolTotalLots += position.Volume();
         allSymbolTotalProfit += position.Profit();

         if(position.Symbol() == symbols[sIndex])
           {
            symbolTotalPositions[sIndex]++;
            symbolProfit[sIndex] += position.Profit();
            symbolTotalVolume[sIndex] += position.Volume();

            if(position.PositionType() == POSITION_TYPE_BUY)
              {
               symbolBuyPositions[sIndex]++;
               symbolBuyVolume[sIndex] += position.Volume();
               symbolBuyProfit[sIndex] += position.Profit();

               if(symbolLowestBuyPrice[sIndex] == 0 || position.PriceOpen() < symbolLowestBuyPrice[sIndex])
                 {
                  symbolLowestBuyPrice[sIndex] = position.PriceOpen();
                 }
               if(symbolHighestBuyLots[sIndex] == 0 || position.Volume() > symbolHighestBuyLots[sIndex])
                 {
                  symbolHighestBuyLots[sIndex] = position.Volume();
                 }
              }

            if(position.PositionType() == POSITION_TYPE_SELL)
              {
               symbolSellPositions[sIndex]++;
               symbolSellVolume[sIndex] += position.Volume();
               symbolSellProfit[sIndex] += position.Profit();

               if(symbolHighestSellPrice[sIndex] == 0 || position.PriceOpen() > symbolHighestSellPrice[sIndex])
                 {
                  symbolHighestSellPrice[sIndex] = position.PriceOpen();
                 }
               if(symbolHighestSellLots[sIndex] == 0 || position.Volume() > symbolHighestSellLots[sIndex])
                 {
                  symbolHighestSellLots[sIndex] = position.Volume();
                 }
              }
           }
        }
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CalculateRisk(int sIndex)
  {

   if(riskType == Dynamic)
     {
      if(riskBase == Balance)
        {
         symbolInitialLots [sIndex] = NormalizeVolume((symbolMinMargin[sIndex]/balance)*symbolLotStep[sIndex]*riskFactor/totalSymbols,   sIndex);
        }

      if(riskBase == Equity)
        {
         symbolInitialLots[sIndex] = NormalizeVolume((symbolMinMargin[sIndex]/equity)*symbolLotStep[sIndex]*riskFactor/totalSymbols,      sIndex);
        }

      if(riskBase == Margin)
        {
         symbolInitialLots[sIndex] = NormalizeVolume((symbolMinMargin[sIndex]/freeMargin)*symbolLotStep[sIndex]*riskFactor/totalSymbols,  sIndex);
        }
     }

   if(riskType == Fixed)
     {
      symbolInitialLots[sIndex] = riskFactor;
     }

   symbolInitialLots[sIndex]  = NormalizeVolume(symbolInitialLots[sIndex] < symbolLotMin[sIndex] ? symbolLotMin[sIndex] : symbolInitialLots[sIndex] > symbolLotMax[sIndex]/gridStepMultiplier/gridStepMax ? symbolLotMax[sIndex]/gridStepMultiplier/gridStepMax : symbolInitialLots[sIndex], sIndex);

  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CalculateProfit(int sIndex)
  {

   if(profitType == Dynamic)
     {
      if(profitBase == Balance)
        {
         symbolTargetProfit[sIndex] = (leverage*(symbolMinMargin[sIndex]*symbolInitialLots[sIndex]/symbolLotMin[sIndex])/balance)*profitFactor;
        }

      if(profitBase == Equity)
        {
         symbolTargetProfit[sIndex] = (leverage*(symbolMinMargin[sIndex]*symbolInitialLots[sIndex]/symbolLotMin[sIndex])/equity)*profitFactor;
        }

      if(profitBase == Margin)
        {
         symbolTargetProfit[sIndex] = (leverage*(symbolMinMargin[sIndex]*symbolInitialLots[sIndex]/symbolLotMin[sIndex])/freeMargin)*profitFactor;
        }
     }

   if(profitType == Fixed)
     {
      symbolTargetProfit[sIndex] = profitFactor;
     }

   symbolTargetSellProfit[sIndex] = symbolSellPositions[sIndex]   == 0 ? 0 : (symbolTargetProfit[sIndex]*(symbolSellVolume[sIndex]  /symbolInitialLots[sIndex]))+((symbolTargetProfit[sIndex]*(symbolSellVolume[sIndex] /symbolInitialLots[sIndex]))*(symbolTotalPositions[sIndex]*gridStepProfitMultiplier));
   symbolTargetBuyProfit[sIndex] = symbolBuyPositions[sIndex]     == 0 ? 0 : (symbolTargetProfit[sIndex]*(symbolBuyVolume[sIndex]   /symbolInitialLots[sIndex]))+((symbolTargetProfit[sIndex]*(symbolBuyVolume[sIndex]  /symbolInitialLots[sIndex]))*(symbolTotalPositions[sIndex]*gridStepProfitMultiplier));

   if(symbolBuyPositions[sIndex] >= gridStepBreakEven && gridStepBreakEven > 0)
     {
      symbolTargetBuyProfit[sIndex] = 0;
     }

   if(symbolSellPositions[sIndex] >= gridStepBreakEven && gridStepBreakEven > 0)
     {
      symbolTargetSellProfit[sIndex] = 0;
     }

   symbolTargetTotalProfit[sIndex] = symbolTargetSellProfit[sIndex] + symbolTargetBuyProfit[sIndex];

   allSymbolTargetProfit = totalSymbols == 0 ? 0 : (symbolTargetProfit[sIndex]*allSymbolTotalLots/symbolLotMin[sIndex]/(profitManyPairsDeviser == 0 ? 1 : profitManyPairsDeviser));
   
   symbolTargetSellProfit[sIndex]   = symbolTargetSellProfit[sIndex]    < 0 ? 0 : symbolTargetSellProfit[sIndex];
   symbolTargetBuyProfit[sIndex]    = symbolTargetBuyProfit[sIndex]     < 0 ? 0 : symbolTargetBuyProfit[sIndex];
   symbolTargetTotalProfit[sIndex]  = symbolTargetTotalProfit[sIndex]   < 0 ? 0 : symbolTargetTotalProfit[sIndex];
   allSymbolTargetProfit            = allSymbolTargetProfit             < 0 ? 0 : allSymbolTargetProfit;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void TakeProfit(int sIndex)
  {

   CalculateProfit(sIndex);


   if(symbolSellProfit[sIndex] >= symbolTargetSellProfit[sIndex] && symbolSellProfit[sIndex] > 0)
     {
      for(int i = 0; i < PositionsTotal(); i++)
        {
         position.SelectByIndex(i);
         if(position.PositionType() == POSITION_TYPE_SELL && position.Symbol() == symbols[sIndex] && position.Magic() == magicNumber)
           {
            ClosePosition(position.Ticket());
           }
        }
     }

   if(symbolBuyProfit[sIndex] >= symbolTargetBuyProfit[sIndex] && symbolBuyProfit[sIndex] > 0)
     {
      for(int i = 0; i < PositionsTotal(); i++)
        {
         position.SelectByIndex(i);
         if(position.PositionType() == POSITION_TYPE_BUY && position.Symbol() == symbols[sIndex] && position.Magic() == magicNumber)
           {
            ClosePosition(position.Ticket());
           }
        }
     }

   if(symbolProfit[sIndex] >= symbolTargetTotalProfit[sIndex] && symbolProfit[sIndex] > 0)
     {
      for(int i = 0; i < PositionsTotal(); i++)
        {
         position.SelectByIndex(i);
         if(position.Symbol() == symbols[sIndex] && position.Magic() == magicNumber)
           {
            ClosePosition(position.Ticket());
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
            ClosePosition(position.Ticket());
           }
        }
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void TradeSymbol(int sIndex)
  {
   if(symbolLowestBuyPrice[sIndex]-(((symbolAsk[sIndex]-symbolBid[sIndex])*100*gridStepMovement)*((symbolBuyPositions[sIndex]*gridStepMultiplier)+1)) >= symbolAsk[sIndex] && symbolBuyVolume[sIndex] != 0 && symbolBuyPositions[sIndex] < gridStepMax && !IsNetting())
     {
      double volume = gridStepLotMultiplier == 0 ? symbolInitialLots[sIndex] : symbolBuyPositions[sIndex]*symbolInitialLots[sIndex]*gridStepLotMultiplier > symbolHighestBuyLots[sIndex]*gridStepLotMultiplier ? symbolBuyPositions[sIndex]*symbolInitialLots[sIndex]*gridStepLotMultiplier : symbolHighestBuyLots[sIndex]*gridStepLotMultiplier;
      double sl = stopLoss > 0 ? symbolAsk[sIndex]-(symbolAsk[sIndex]/100*stopLoss) : 0;

      Buy(sIndex,volume,sl);
     }

   if(symbolHighestSellPrice[sIndex]+(((symbolAsk[sIndex]-symbolBid[sIndex])*100*gridStepMovement)*((symbolSellPositions[sIndex]*gridStepMultiplier)+1)) <= symbolBid[sIndex] && symbolSellVolume[sIndex] != 0 && symbolSellPositions[sIndex] < gridStepMax && !IsNetting())
     {
      double volume = gridStepLotMultiplier == 0 ? symbolInitialLots[sIndex] : symbolSellPositions[sIndex]*symbolInitialLots[sIndex]*gridStepLotMultiplier > symbolHighestSellLots[sIndex]*gridStepLotMultiplier ? symbolSellPositions[sIndex]*symbolInitialLots[sIndex]*gridStepLotMultiplier : symbolHighestSellLots[sIndex]*gridStepLotMultiplier;
      double sl = stopLoss > 0 ? symbolBid[sIndex]+(symbolBid[sIndex]/100*stopLoss) : 0;

      Sell(sIndex,volume,sl);
     }

   if((symbolBuyPositions[sIndex] == 0) && (symbolSellPositions[sIndex] == 0 || (symbolAsk[sIndex] < symbolHighestSellPrice[sIndex]-(((symbolAsk[sIndex]-symbolBid[sIndex])*100*gridStepMovement)*gridReverseStepMultiplier*symbolSellPositions[sIndex]) && sell)) && buy)
     {
      double highestLot = symbolSellPositions[sIndex] == 0 ? 0 : gridReverseLotDeviser > 0 ? symbolSellVolume[sIndex]/symbolSellPositions[sIndex]/gridReverseLotDeviser : 0;
      double volume = IsNetting() ? symbolLotMin[sIndex] : highestLot < symbolInitialLots[sIndex] ? symbolInitialLots[sIndex] : highestLot;
      double sl = stopLoss > 0 ? symbolAsk[sIndex]-(symbolAsk[sIndex]/100*stopLoss) : 0;

      Buy(sIndex,volume,sl);
     }

   if((symbolSellPositions[sIndex] == 0) && (symbolBuyPositions[sIndex] == 0 || (symbolBid[sIndex] > symbolLowestBuyPrice[sIndex]+(((symbolAsk[sIndex]-symbolBid[sIndex])*100*gridStepMovement)*gridReverseStepMultiplier*symbolBuyPositions[sIndex]) && buy)) && sell)
     {
      double highestLot = symbolBuyPositions[sIndex] == 0 ? 0 : gridReverseLotDeviser > 0 ? symbolBuyVolume[sIndex]/symbolBuyPositions[sIndex]/gridReverseLotDeviser : 0;
      double volume = IsNetting() ? symbolLotMin[sIndex] : highestLot < symbolInitialLots[sIndex] ? symbolInitialLots[sIndex] : highestLot;
      double sl = stopLoss > 0 ? symbolBid[sIndex]+(symbolBid[sIndex]/100*stopLoss) : 0;

      Sell(sIndex,volume,sl);
     }
  }

//+------------------------------------------------------------------+
//| Expert HandleSymbol function                                     |
//+------------------------------------------------------------------+
void HandleSymbol(int sIndex)
  {
   SymbolInfoTick(symbols[sIndex],symbolCurrentTick[sIndex]);

   FilterPositions(sIndex);
   CalculateRisk(sIndex);
   TakeProfit(sIndex);
   TradeSymbol(sIndex);

   SymbolInfoTick(symbols[sIndex],symbolLastTick[sIndex]);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void HandleSymbols()
  {
   for(int i = 0; i < totalSymbols; i++)
     {
      HandleSymbol(i);
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void Buy(int sIndex, double volume, double sl = 0.0)
  {
   volume = NormalizeVolume(volume, sIndex);
   if(CheckMoneyForTrade(symbols[sIndex],volume,ORDER_TYPE_BUY) && CheckVolumeValue(symbols[sIndex],volume) && IsMarketOpen())
     {
      if(trade.Buy(volume, symbols[sIndex], 0, sl, 0, "MintyGrid Buy " + symbols[sIndex] + " step " + IntegerToString(symbolBuyPositions[sIndex] + 1)))
        {
         totalTrades++;
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void Sell(int sIndex, double volume, double sl = 0.0)
  {
   volume = NormalizeVolume(volume, sIndex);
   if(CheckMoneyForTrade(symbols[sIndex],volume,ORDER_TYPE_SELL) && CheckVolumeValue(symbols[sIndex],volume) && IsMarketOpen())
     {
      if(trade.Sell(volume, symbols[sIndex], 0, sl, 0, "MintyGrid Sell " + symbols[sIndex] + " step " + IntegerToString(symbolSellPositions[sIndex] + 1)))
        {
         totalTrades++;
        }
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double NormalizeVolume(double volume, int sIndex)
  {
   volume = NormalizeDouble(symbolLotStep[sIndex]*MathRound(volume/symbolLotStep[sIndex]),symbolLotPrecision[sIndex]);
   return NormalizeDouble(volume < symbolLotMin[sIndex] ? symbolLotMin[sIndex] : volume > symbolLotMax[sIndex] ? symbolLotMax[sIndex] : volume,symbolLotPrecision[sIndex]);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CheckMoneyForTrade(string symb,double lots,ENUM_ORDER_TYPE type)
  {
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
void ClosePosition(ulong ticket)
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
void CloseOpenPositions()
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
double GetMinMargin(int sIndex)
  {
   MqlTick mqltick;
   SymbolInfoTick(symbols[sIndex],mqltick);
   double price=mqltick.ask;
   double margin,free_margin=AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   if(!OrderCalcMargin(ORDER_TYPE_BUY,symbols[sIndex],symbolLotStep[sIndex],price,margin))
     {
      return -1;
     }

   return margin;
  }
ENUM_DAY_OF_WEEK day_of_week;
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsMarketOpen()
  {
   datetime time_now = TimeCurrent();
   MqlDateTime time;
   TimeToStruct(time_now, time);
   uint week_day_now = time.day_of_week;
   uint seconds_now = (time.hour * 3600) + (time.min * 60) + time.sec;
   if(week_day_now == 0)
      day_of_week = SUNDAY;
   if(week_day_now == 1)
      day_of_week = MONDAY;
   if(week_day_now == 2)
      day_of_week = TUESDAY;
   if(week_day_now == 3)
      day_of_week = WEDNESDAY;
   if(week_day_now == 4)
      day_of_week = THURSDAY;
   if(week_day_now == 5)
      day_of_week = FRIDAY;
   if(week_day_now == 6)
      day_of_week = SATURDAY;
   datetime from, to;
   uint session = 0;
   while(SymbolInfoSessionTrade(_Symbol, day_of_week, session, from, to))
     {
      session++;
     }
   uint trade_session_open_seconds = uint(from);
   uint trade_session_close_seconds = uint(to);
   if(trade_session_open_seconds < seconds_now && trade_session_close_seconds > seconds_now && week_day_now >= 1 && week_day_now <= 5)
      return(true);
   return(false);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void Mint()
  {
   UpdateBalance();
   HandleSymbols();
   CloseOpenPositions();
  }

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   startTime      = TimeCurrent();
   leverage       = (int)AccountInfoInteger(ACCOUNT_LEVERAGE);
   currencyDigits = (int)AccountInfoInteger(ACCOUNT_CURRENCY_DIGITS);
   startBalance   = AccountInfoDouble(ACCOUNT_BALANCE);

   trade.SetExpertMagicNumber(magicNumber);
   trade.LogLevel(LOG_LEVEL_NO);

   initSymbols();

   if(MQLInfoInteger(MQL_TESTER))
     {
      for(int i=0; i<totalSymbols; i++)
        {
         CheckLoadHistory(symbols[i], _Period, 1000);
        }
      EventSetTimer(300);
     }
   else
     {
      EventSetMillisecondTimer(1000/33);
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
   Mint();
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
   EventKillTimer();
  }



//+------------------------------------------------------------------+
//| Expert HandleSymbol function                                     |
//+------------------------------------------------------------------+
void OnTick()
  {
   Mint();
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
