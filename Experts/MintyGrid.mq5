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
#property version   "3.2"

#include <checkhistory.mqh>
#include <Trade/Trade.mqh>
#include <ChartObjects\ChartObjectsShapes.mqh>
#include <ChartObjects\ChartObjectsTxtControls.mqh>

enum RiskBase {Balance, Equity};
enum RiskType {Fixed, Dynamic};

//--- Risk settings parameters
input group "Risk settings";

input RiskBase riskBase=Equity; // Factor to base risk on when using dynamic risk
input RiskType riskType=Dynamic; // Whether to use fixed or dynamic risk
input RiskType profitType=Dynamic; // Whether to use fixed or dynamic lot size
input double   riskFactor=1; // Fixed lot size or dynamic risk factor
input double   profitFactor=2; // Fixed profit in deposit currency or dynamic profit factor
input double   stopLoss=0.0; // Percentage of price to be used as stop loss (0 to disable)

input group "Martingale grid settings";
input double   lotMultiplier=2; // Step martingale lot multiplier (0 to disable)
input double   gridStep=0.02; // Step price movement percentage
input double   gridStepMultiplier=5; // Step distance multiplier (0 to disable)
input double   gridStepProfitMultiplier=0; // Step profit multiplier (0 to disable)
input double   gridReverseStepMultiplier=5; // Reverse direction step multiplier (0 to disable)
input double   gridReverseLotDeviser=1.5; // Reverse martingale lot deviser (0 to disable)
input int      breakEventGridStep=10; // Try break even on grid step (0 to disable)
input int      maxGridSteps=10; // Maximum amount of grid steps

input group "Trade settings";
input bool     buy = true; // Whether to enable buy trades
input bool     sell = true; // Whether to enable sell trades

input group "Symbol settings";
input string   currencyPairs = "EURUSD"; // Symbols to trade comma seperated

input group "Expert Advisor settings";
input bool     showComment = true; // Show comment, disable for faster testing
input int      magicNumber = 901239; // Magic number

CTrade trade;
CPositionInfo position;
COrderInfo order;

CChartObjectRectLabel* rect = new CChartObjectRectLabel;

CChartObjectLabel* title = new CChartObjectLabel;
CChartObjectLabel* profitLabel = new CChartObjectLabel;
CChartObjectLabel* profitValue = new CChartObjectLabel;
CChartObjectLabel* symbolCountLabel = new CChartObjectLabel;
CChartObjectLabel* symbolCountValue = new CChartObjectLabel;
CChartObjectLabel* allSymbolTargetProfitLabel = new CChartObjectLabel;
CChartObjectLabel* allSymbolTargetProfitValue = new CChartObjectLabel;

CChartObjectRectLabel* tableRects[];
CChartObjectLabel* tableCells[];


string symbols[];
int totalSymbols = 0;

double symbolProfit[];
double symbolBuyProfit[];
double symbolSellProfit[];
double symbolTargetBuyProfit[];
double symbolTargetSellProfit[];
double totalAllSymbolProfit;
int symbolBuyPositions[];
int symbolSellPositions[];

ulong positionsToClose[];

double startBalance;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- create timer
   EventSetTimer(1000/30);

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

   ArrayResize(symbolProfit, totalSymbols);
   ArrayResize(symbolBuyProfit, totalSymbols);
   ArrayResize(symbolSellProfit, totalSymbols);
   ArrayResize(symbolTargetBuyProfit, totalSymbols);
   ArrayResize(symbolTargetSellProfit, totalSymbols);
   ArrayResize(symbolBuyPositions, totalSymbols);
   ArrayResize(symbolSellPositions, totalSymbols);

   trade.SetExpertMagicNumber(magicNumber);
   trade.LogLevel(LOG_LEVEL_NO);


   startBalance = AccountInfoDouble(ACCOUNT_BALANCE);

   if(MQLInfoInteger(MQL_TESTER))
     {
      for(int i=0; i<totalSymbols; i++)
        {
         CheckLoadHistory(symbols[i], _Period, 100000);
        }
     }


   if(showComment)
     {

      int rowHeight = 25;
      int width = 640;
      int col1 = (width/8*0)+5;
      int col2 = (width/8*1)+5;
      int col3 = (width/8*2)+5;
      int col4 = (width/8*3)+5;
      int col5 = (width/8*4)+5;
      int col6 = (width/8*5)+5;
      int col7 = (width/8*6)+5;
      int col8 = (width/8*7)+5;

      rect.Create(0, "rect", 0,0,0,width,(totalSymbols*20)+67);
      rect.BackColor(clrPaleGreen);
      rect.BorderType(BORDER_FLAT);

      title.Create(0,"titlebackground00",0,width-82,6);
      title.FontSize(9);
      title.Color(clrWhite);
      title.SetString(OBJPROP_TEXT, "MintyGrid v3.2");
      title.Create(0,"titlebackground0",0,width-84,6);
      title.FontSize(9);
      title.Color(clrWhite);
      title.SetString(OBJPROP_TEXT, "MintyGrid v3.2");
      title.Create(0,"titlebackground1",0,width-82,4);
      title.FontSize(9);
      title.Color(clrWhite);
      title.SetString(OBJPROP_TEXT, "MintyGrid v3.2");
      title.Create(0,"titlebackground2",0,width-84,5);
      title.FontSize(9);
      title.Color(clrWhite);
      title.SetString(OBJPROP_TEXT, "MintyGrid v3.2");
      title.Create(0,"titlebackground3",0,width-82,6);
      title.FontSize(9);
      title.Color(clrWhite);
      title.SetString(OBJPROP_TEXT, "MintyGrid v3.2");
      title.Create(0,"titlebackground4",0,width-84,6);
      title.FontSize(9);
      title.Color(clrWhite);
      title.SetString(OBJPROP_TEXT, "MintyGrid v3.2");
      title.Create(0,"title",0,width-83,5);
      title.FontSize(9);
      title.Color(clrDarkSlateGray);
      title.SetString(OBJPROP_TEXT, "MintyGrid v3.2");


      symbolCountLabel.Create(0,"symbolCountLabel",0,col1,5);
      symbolCountLabel.FontSize(9);
      symbolCountLabel.Color(clrBlack);
      symbolCountLabel.SetString(OBJPROP_TEXT, "Symbols:");
      symbolCountValue.Create(0,"symbolCountValue",0,col2,5);
      symbolCountValue.FontSize(9);
      symbolCountValue.SetString(OBJPROP_TEXT, (string)totalSymbols);
      symbolCountValue.Color(clrBlack);

      ArrayResize(tableRects, ArraySize(tableRects)+8);

      tableRects[0] = new CChartObjectRectLabel;
      tableRects[0].Create(0, "allSymbolTargetProfitRect", 0,col1-2,(totalSymbols*20)+43,width-6,20);
      tableRects[0].BackColor(clrForestGreen);

      allSymbolTargetProfitLabel.Create(0,"allSymbolTargetProfitLabel",0,col7,(totalSymbols*20)+45);
      allSymbolTargetProfitLabel.FontSize(8);
      allSymbolTargetProfitLabel.Color(clrWhiteSmoke);
      allSymbolTargetProfitLabel.SetString(OBJPROP_TEXT, "target all profit:");
      allSymbolTargetProfitValue.Create(0,"allSymbolTargetProfitValue",0,col8,(totalSymbols*20)+45);
      allSymbolTargetProfitValue.FontSize(8);
      allSymbolTargetProfitValue.Color(clrWhiteSmoke);

      profitLabel.Create(0,"profitLabel",0,col3,5);
      profitLabel.FontSize(9);
      profitLabel.Color(clrBlack);
      profitLabel.SetString(OBJPROP_TEXT, "Profit:");
      profitValue.Create(0,"profitValue",0,col4,5);
      profitValue.FontSize(9);
      profitValue.Color(clrBlack);

      ArrayResize(tableCells, ArraySize(tableCells)+8);


      tableRects[1] = new CChartObjectRectLabel;
      tableRects[1].Create(0, "tableRects0", 0,col1-2,rowHeight-2,width-6,17);
      tableRects[1].BackColor(clrForestGreen);

      tableCells[0] = new CChartObjectLabel;
      tableCells[0].Create(0,"tableCells0",0,col1,rowHeight);
      tableCells[0].FontSize(7);
      tableCells[0].Color(clrWhiteSmoke);
      tableCells[0].SetString(OBJPROP_TEXT, " symbol");

      tableCells[1] = new CChartObjectLabel;
      tableCells[1].Create(0,"tableCells1",0,col2,rowHeight);
      tableCells[1].FontSize(7);
      tableCells[1].Color(clrWhiteSmoke);
      tableCells[1].SetString(OBJPROP_TEXT, " buy positions");

      tableCells[2] = new CChartObjectLabel;
      tableCells[2].Create(0,"tableCells2",0,col3,rowHeight);
      tableCells[2].FontSize(7);
      tableCells[2].Color(clrWhiteSmoke);
      tableCells[2].SetString(OBJPROP_TEXT, " sell positions");

      tableCells[3] = new CChartObjectLabel;
      tableCells[3].Create(0,"tableCells3",0,col4,rowHeight);
      tableCells[3].FontSize(7);
      tableCells[3].Color(clrWhiteSmoke);
      tableCells[3].SetString(OBJPROP_TEXT, " profit");

      tableCells[4] = new CChartObjectLabel;
      tableCells[4].Create(0,"tableCells4",0,col5,rowHeight);
      tableCells[4].FontSize(7);
      tableCells[4].Color(clrWhiteSmoke);
      tableCells[4].SetString(OBJPROP_TEXT, " buy profit");

      tableCells[5] = new CChartObjectLabel;
      tableCells[5].Create(0,"tableCells5",0,col6,rowHeight);
      tableCells[5].FontSize(7);
      tableCells[5].Color(clrWhiteSmoke);
      tableCells[5].SetString(OBJPROP_TEXT, " sell profit");

      tableCells[6] = new CChartObjectLabel;
      tableCells[6].Create(0,"tableCells6",0,col7,rowHeight);
      tableCells[6].FontSize(7);
      tableCells[6].Color(clrWhiteSmoke);
      tableCells[6].SetString(OBJPROP_TEXT, " target buy profit");

      tableCells[7] = new CChartObjectLabel;
      tableCells[7].Create(0,"tableCells7",0,col8,rowHeight);
      tableCells[7].FontSize(7);
      tableCells[7].Color(clrWhiteSmoke);
      tableCells[7].SetString(OBJPROP_TEXT, " target sell profit");

      for(int i = 0, o = ArraySize(tableCells)-1; i < (totalSymbols); i++)
        {
         ArrayResize(tableCells, ArraySize(tableCells)+8);
         ArrayResize(tableRects, ArraySize(tableRects)+1);
         rowHeight = (20*i)+43;


         tableRects[i+1] = new CChartObjectRectLabel;
         tableRects[i+1].Create(0, "tableRects" + i+1, 0,col1-2,rowHeight-3,width-6,23);
         tableRects[i+1].BackColor(i%2?clrLightGreen:clrPaleGreen);

         o++;
         tableCells[o] = new CChartObjectLabel;
         tableCells[o].Create(0,"tableCells" + (string)o,0,col1,rowHeight);
         tableCells[o].FontSize(8);
         tableCells[o].Color(clrBlack);
         tableCells[o].SetString(OBJPROP_TEXT, " " + symbols[i]);

         o++;
         tableCells[o] = new CChartObjectLabel;
         tableCells[o].Create(0,"tableCells" + (string)o,0,col2,rowHeight);
         tableCells[o].FontSize(8);
         tableCells[o].Color(clrBlack);

         o++;
         tableCells[o] = new CChartObjectLabel;
         tableCells[o].Create(0,"tableCells" + (string)o,0,col3,rowHeight);
         tableCells[o].FontSize(8);
         tableCells[o].Color(clrBlack);

         o++;
         tableCells[o] = new CChartObjectLabel;
         tableCells[o].Create(0,"tableCells" + (string)o,0,col4,rowHeight);
         tableCells[o].FontSize(8);
         tableCells[o].Color(clrBlack);

         o++;
         tableCells[o] = new CChartObjectLabel;
         tableCells[o].Create(0,"tableCells" + (string)o,0,col5,rowHeight);
         tableCells[o].FontSize(8);
         tableCells[o].Color(clrBlack);

         o++;
         tableCells[o] = new CChartObjectLabel;
         tableCells[o].Create(0,"tableCells" + (string)o,0,col6,rowHeight);
         tableCells[o].FontSize(8);
         tableCells[o].Color(clrBlack);

         o++;
         tableCells[o] = new CChartObjectLabel;
         tableCells[o].Create(0,"tableCells" + (string)o,0,col7,rowHeight);
         tableCells[o].FontSize(8);
         tableCells[o].Color(clrBlack);

         o++;
         tableCells[o] = new CChartObjectLabel;
         tableCells[o].Create(0,"tableCells" + (string)o,0,col8,rowHeight);
         tableCells[o].FontSize(8);
         tableCells[o].Color(clrBlack);
        }
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
   if(showComment)
     {

      double currentProfit = AccountInfoDouble(ACCOUNT_EQUITY)-startBalance;
      profitValue.SetString(OBJPROP_TEXT, (currentProfit > 0 ? "+" : "") + DoubleToString(currentProfit, (int)AccountInfoInteger(ACCOUNT_CURRENCY_DIGITS)));
      profitValue.Color(currentProfit > 0 ? clrGreen : currentProfit < 0 ? clrRed : clrSlateGray);


      allSymbolTargetProfitValue.SetString(OBJPROP_TEXT, DoubleToString(totalAllSymbolProfit,2));

      for(int i = 0, o = 7; i < (totalSymbols); i++)
        {

         o++;
         o++;
         tableCells[o].SetString(OBJPROP_TEXT, " " + (string)symbolBuyPositions[i]);

         o++;
         tableCells[o].SetString(OBJPROP_TEXT, " " + (string)symbolSellPositions[i]);

         o++;
         tableCells[o].SetString(OBJPROP_TEXT, " " + (symbolProfit[i] > 0 ? "+" : "") + DoubleToString(symbolProfit[i],2));
         tableCells[o].Color(symbolProfit[i] > 0 ? clrGreen : symbolProfit[i] < 0 ? clrRed : clrSlateGray);

         o++;
         tableCells[o].SetString(OBJPROP_TEXT, " " + (symbolBuyProfit[i] > 0 ? "+" : "") + DoubleToString(symbolBuyProfit[i],2));
         tableCells[o].Color(symbolBuyProfit[i] > 0 ? clrGreen : symbolBuyProfit[i] < 0 ? clrRed : clrSlateGray);

         o++;
         tableCells[o].SetString(OBJPROP_TEXT, " " + (symbolSellProfit[i] > 0 ? "+" : "") + DoubleToString(symbolSellProfit[i],2));
         tableCells[o].Color(symbolSellProfit[i] > 0 ? clrGreen : symbolSellProfit[i] < 0 ? clrRed : clrSlateGray);

         o++;
         tableCells[o].SetString(OBJPROP_TEXT, " " + DoubleToString(symbolTargetSellProfit[i],2));

         o++;
         tableCells[o].SetString(OBJPROP_TEXT, " " + DoubleToString(symbolTargetBuyProfit[i],2));


        }

      //label.SetString(OBJPROP_TEXT, GetComment());
      ChartRedraw();
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
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   for(int i = 0; i < totalSymbols; i++)
     {
      Tick(i, symbols[i]);
     }
  }

//---
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void Tick(int symbolIndex, string symbol)
  {
   double ask = SymbolInfoDouble(symbol,SYMBOL_ASK);
   double bid = SymbolInfoDouble(symbol,SYMBOL_BID);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double lotMin = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double lotMax = SymbolInfoDouble(symbol,SYMBOL_VOLUME_LIMIT) == 0 ? SymbolInfoDouble(symbol,SYMBOL_VOLUME_MAX) : SymbolInfoDouble(symbol,SYMBOL_VOLUME_LIMIT);
   double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   double leverage = (int)AccountInfoInteger(ACCOUNT_LEVERAGE);
   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double minMargin = GetMinMargin(symbol,lotStep);
   int lotPrecision = GetDoublePrecision(lotStep);

   double initialLots = 0;
   double targetProfit = 0;

   if(riskBase == Balance)
     {
      initialLots = NormalizeDouble((balance/minMargin)*lotStep/balance*riskFactor,lotPrecision);
      initialLots = NormalizeDouble(initialLots < lotMin ? lotMin : initialLots > lotMax/gridStepMultiplier/maxGridSteps ? lotMax/gridStepMultiplier/maxGridSteps : initialLots,lotPrecision);
      targetProfit = (balance/100/minMargin)*profitFactor;
     }

   if(riskBase == Equity)
     {
      initialLots = NormalizeDouble((equity/minMargin)*lotStep/equity*riskFactor,lotPrecision);
      initialLots = NormalizeDouble(initialLots < lotMin ? lotMin : initialLots > lotMax/gridStepMultiplier/maxGridSteps ? lotMax/gridStepMultiplier/maxGridSteps : initialLots,lotPrecision);
      targetProfit = (equity/100/minMargin)*profitFactor;
     }

   if(riskType == Fixed)
     {
      initialLots = riskFactor;
     }

   if(profitType == Fixed)
     {
      targetProfit = profitFactor;
     }


   int buyPositions = 0;
   int sellPositions = 0;
   int positions = 0;

   double buyProfit = 0;
   double sellProfit = 0;
   double lowestBuyPrice = 0;
   double highestBuyPrice = 0;
   double highestBuyLots = 0;
   double highestOverallBuyLots = 0;
   double lowestSellPrice = 0;
   double highestSellPrice = 0;
   double highestSellLots = 0;
   double highestOverallSellLots = 0;
   double totalOverallLots = 0;
   double buyLots = 0;
   double sellLots = 0;
   double profit = 0;
   double allSymbolProfit = 0;
   double totalAllSymbolPositions = 0;
   double totalAllSymbolLots = 0;

   for(int i = 0; i < PositionsTotal(); i++)
     {
      position.SelectByIndex(i);
      if(position.Magic() == magicNumber)
        {

         totalAllSymbolPositions++;
         totalAllSymbolLots += position.Volume();
         allSymbolProfit += position.Profit();
         if(position.Symbol() == symbol)
           {
            positions++;
            profit += position.Profit();
            totalOverallLots += position.Volume();

            if(position.PositionType() == POSITION_TYPE_BUY)
              {
               buyPositions++;
               buyLots += position.Volume();
               buyProfit += position.Profit();
               if(lowestBuyPrice == 0 || position.PriceOpen() < lowestBuyPrice)
                 {
                  lowestBuyPrice = position.PriceOpen();
                 }
               if(highestBuyPrice == 0 || position.PriceOpen() > highestBuyPrice)
                 {
                  highestBuyPrice = position.PriceOpen();
                 }
               if(highestBuyLots == 0 || position.Volume() > highestBuyLots)
                 {
                  highestBuyLots = position.Volume();
                 }
              }

            if(position.PositionType() == POSITION_TYPE_SELL)
              {
               sellPositions++;
               sellLots += position.Volume();
               sellProfit += position.Profit();
               if(lowestSellPrice == 0 || position.PriceOpen() < lowestSellPrice)
                 {
                  lowestSellPrice = position.PriceOpen();
                 }
               if(highestSellPrice == 0 || position.PriceOpen() > highestSellPrice)
                 {
                  highestSellPrice = position.PriceOpen();
                 }
               if(highestSellLots == 0 || position.Volume() > highestSellLots)
                 {
                  highestSellLots = position.Volume();
                 }
              }
           }
        }
     }


   double targetSellProfit = profitType == Fixed ? targetProfit : targetProfit+((targetProfit/positions*(sellPositions))*gridStepProfitMultiplier);
   double targetBuyProfit = profitType == Fixed ? targetProfit : targetProfit+((targetProfit/positions*(buyPositions))*gridStepProfitMultiplier);
   double targetOverallProfit = profitType == Fixed ? targetProfit : targetProfit+((targetProfit/positions*(positions))*gridStepProfitMultiplier);
   double targetAllPositionProfit = profitType == Fixed ? targetProfit : targetProfit+((targetProfit*totalAllSymbolPositions/totalSymbols)*gridStepProfitMultiplier);

   if(buyPositions >= breakEventGridStep && breakEventGridStep > 0)
     {
      targetBuyProfit = 0;
     }

   if(sellPositions >= breakEventGridStep && breakEventGridStep > 0)
     {
      targetSellProfit = 0;
     }

   if(sellProfit >= targetSellProfit)
     {
      for(int i = 0; i < PositionsTotal(); i++)
        {
         position.SelectByIndex(i);
         if(position.PositionType() == POSITION_TYPE_SELL && position.Symbol() == symbol && position.Magic() == magicNumber)
           {
            closePosition(position.Ticket());
           }
        }
     }

   if(buyProfit >= targetBuyProfit)
     {
      for(int i = 0; i < PositionsTotal(); i++)
        {
         position.SelectByIndex(i);
         if(position.PositionType() == POSITION_TYPE_BUY && position.Symbol() == symbol && position.Magic() == magicNumber)
           {
            closePosition(position.Ticket());
           }
        }
     }

   if(profit >= targetOverallProfit && (lowestSellPrice > highestBuyPrice))
     {
      for(int i = 0; i < PositionsTotal(); i++)
        {
         position.SelectByIndex(i);
         if(position.Symbol() == symbol && position.Magic() == magicNumber)
           {
            closePosition(position.Ticket());
           }
        }
     }


   if(allSymbolProfit >= targetAllPositionProfit)
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

   if(lowestBuyPrice-((lowestBuyPrice/100*gridStep)*((buyPositions*gridStepMultiplier)+1)) >= ask && buyLots != 0 && buyPositions < maxGridSteps && !IsNetting())
     {
      double volume = buyPositions*initialLots*lotMultiplier > highestBuyLots*lotMultiplier ? buyPositions*initialLots*lotMultiplier : highestBuyLots*lotMultiplier;
      if(lotMultiplier==0)
        {
         volume = initialLots;
        }
      volume = NormalizeDouble(lotStep*MathRound(volume/lotStep),lotPrecision);
      volume =  NormalizeDouble(volume < lotMin ? lotMin : volume > lotMax ? lotMax : volume,lotPrecision);

      if(CheckMoneyForTrade(symbol,volume,ORDER_TYPE_BUY) && totalOverallLots+volume < lotMax)
        {
         double sl = stopLoss > 0 ? ask-(ask/100*stopLoss) : 0;
         trade.Buy(volume,symbol,0,sl,0,"MintyGrid Buy " + symbol + " step " + IntegerToString(buyPositions + 1));
        }

     }

   if(highestSellPrice+((highestSellPrice/100*gridStep)*((sellPositions*gridStepMultiplier)+1)) <= bid && sellLots != 0 && sellPositions < maxGridSteps && !IsNetting())
     {
      double volume = sellPositions*initialLots*lotMultiplier > highestSellLots*lotMultiplier ? sellPositions*initialLots*lotMultiplier : highestSellLots*lotMultiplier;
      if(lotMultiplier==0)
        {
         volume = initialLots;
        }
      volume = NormalizeDouble(lotStep*MathRound(volume/lotStep),lotPrecision);
      volume = NormalizeDouble(volume < lotMin ? lotMin : volume > lotMax ? lotMax : volume,lotPrecision);

      if(CheckMoneyForTrade(symbol,volume,ORDER_TYPE_SELL) && CheckVolumeValue(symbol,volume) && totalOverallLots+volume < lotMax)
        {
         double sl = stopLoss > 0 ? bid+(bid/100*stopLoss) : 0;
         trade.Sell(volume,symbol,0,sl,0,"MintyGrid Sell " + symbol + " step " + IntegerToString(sellPositions + 1));
        }
     }

   if((buyPositions == 0) && (sellPositions == 0 || (ask < highestSellPrice-((highestSellPrice/100*gridStep)*((gridStepMultiplier*gridReverseStepMultiplier))) && sell)) && buy)
     {
      double highestLot = sellPositions == 0 ? 0 : gridReverseLotDeviser > 0 ? sellLots/sellPositions/gridReverseLotDeviser : 0;
      double volume = highestLot < initialLots ? initialLots : highestLot;
      volume = NormalizeDouble(lotStep*MathRound(volume/lotStep),lotPrecision);
      volume =  NormalizeDouble(volume < lotMin ? lotMin : volume > lotMax ? lotMax : volume,lotPrecision);

      if(IsNetting())
        {
         volume = lotMin;
        }

      if(CheckMoneyForTrade(symbol,volume,ORDER_TYPE_BUY) && CheckVolumeValue(symbol,volume) && totalOverallLots+volume < lotMax)
        {
         double sl = stopLoss > 0 ? ask-(ask/100*stopLoss) : 0;
         trade.Buy(volume,symbol,0,sl,0,"MintyGrid Buy " + symbol + " step " + IntegerToString(buyPositions + 1));
        }
     }

   if((sellPositions == 0) && (buyPositions == 0 || (bid > lowestBuyPrice+((lowestBuyPrice/100*gridStep)*((gridStepMultiplier*gridReverseStepMultiplier))) && buy)) && sell)
     {
      double highestLot = buyPositions == 0 ? 0 : gridReverseLotDeviser > 0 ? buyLots/buyPositions/gridReverseLotDeviser : 0;
      double volume = highestLot < initialLots ? initialLots : highestLot;
      volume = NormalizeDouble(lotStep*MathRound(volume/lotStep),lotPrecision);
      volume = NormalizeDouble(volume < lotMin ? lotMin : volume > lotMax ? lotMax : volume,lotPrecision);

      if(IsNetting())
        {
         volume = lotMin;
        }

      if(CheckMoneyForTrade(symbol,volume,ORDER_TYPE_SELL) && totalOverallLots+volume < lotMax)
        {
         double sl = stopLoss > 0 ? bid+(bid/100*stopLoss) : 0;
         trade.Sell(volume,symbol,0,sl,0,"MintyGrid Sell " + symbol + " step " + IntegerToString(sellPositions + 1));
        }
     }

   closeOpenPositions();

   if(showComment)
     {
      symbolProfit[symbolIndex] = profit;
      symbolSellProfit[symbolIndex] = sellProfit;
      symbolBuyProfit[symbolIndex] = buyProfit;
      symbolBuyPositions[symbolIndex] = buyPositions;
      symbolSellPositions[symbolIndex] = sellPositions;
      symbolTargetBuyProfit[symbolIndex] = targetBuyProfit;
      symbolTargetSellProfit[symbolIndex] = targetSellProfit;
      totalAllSymbolProfit = targetAllPositionProfit;
     }
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string WhiteSpaceToLength(string str, int length = 25)
  {
   int stringLength = StringLen(str);
   string output = str;

   for(int i = 0; i <= length-stringLength; i++)
     {
      output += " ";
     }

   return output;
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
double GetMinMargin(string symb,double lots)
  {
//--- Getting the opening price
   MqlTick mqltick;
   SymbolInfoTick(symb,mqltick);
   double price=mqltick.ask;
   double margin,free_margin=AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   if(!OrderCalcMargin(ORDER_TYPE_BUY,symb,lots,price,margin))
     {
      return -1;
     }

   return margin;
  }
//+------------------------------------------------------------------+
