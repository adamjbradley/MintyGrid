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
#property copyright "Copyright 2021, Christopher Benjamin Hemmens Ltd."
#property link      "chrishemmens@hotmail.com"
#property version   "2.4"

#include <checkhistory.mqh>
#include <Trade/Trade.mqh>

enum RiskBase {Balance, Equity};

//--- Risk settings parameters
input RiskBase riskBase=Equity; // Factor to base risk on
input double   minInitialRiskFactor=0.015; // Initial risk factor, percentage of risk base by minimum lot
input double   profitFactor=0.5; // Profit factor, percentage of risk base
//--- Martingale grid settings
input double   lotMultiplier=1.5; // Grid step martingale lot multiplier
input double   lotDeviser=3; // Grid reverse martingale lot deviser
input double   gridStep=0.3; // Grid step price movement percentage
input double   gridStepMultiplier=0.3; // Grid step distance multiplier
input double   gridStepProfitMultiplier=0.3; // Grid step profit multiplier
input int      maxGridSteps=10; // Maximum amount of grid steps
//--- trade settings
input bool     buy = true;
input bool     sell = true;
//--- Symbol settings
input string   currencyPairs = "EURUSD"; // Symbols to trade comma seperated
//--- Expert Advisor settings
input int      magicNumber = 901239; // Magic

CTrade trade;
CPositionInfo position;
COrderInfo order;

string symbols[];
int totalSymbols = 0;
ulong positionsToClose[];
bool enableTrade = true;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- create timer
   EventSetTimer(1);

   int split=StringSplit(currencyPairs,",",symbols);
   ArrayRemove(symbols,ArraySize(symbols),1);
   totalSymbols=ArraySize(symbols);

   trade.SetExpertMagicNumber(magicNumber);
   trade.LogLevel(LOG_LEVEL_NO);

   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnTesterInit(void)
  {

   for(int i=0; i<totalSymbols; i++)
     {

   CheckLoadHistory(symbols[i], _Period, 100000);


     }
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
   if(enableTrade)
     {
      for(int i = 0; i < totalSymbols; i++)
        {
         Tick(symbols[i]);
        }
     }
  }

//---
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void Tick(string symbol)
  {
   double ask = SymbolInfoDouble(symbol,SYMBOL_ASK);
   double bid = SymbolInfoDouble(symbol,SYMBOL_BID);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);

   double profit = AccountInfoDouble(ACCOUNT_PROFIT);

   double lotMin = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double lotMax = SymbolInfoDouble(symbol,SYMBOL_VOLUME_LIMIT);
   if(lotMax==0)
      lotMax=SymbolInfoDouble(symbol,SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

   int lotDecimals = lotStep > 0.09 ? lotStep > 0.9 ? 0 : 1 : 2;

   double initialLots = 0;
   double targetProfit = 0;

   if(riskBase == Balance)
     {
      initialLots = NormalizeDouble((balance/100)*minInitialRiskFactor*lotStep,lotDecimals);
      targetProfit = balance/100*profitFactor;
     }

   if(riskBase == Equity)
     {
      initialLots = NormalizeDouble((equity/100)*minInitialRiskFactor*lotStep,lotDecimals);
      targetProfit = equity/100*profitFactor;
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
   double totalOverallBuyLots = 0;

   double lowestSellPrice = 0;
   double highestSellPrice = 0;
   double highestSellLots = 0;
   double highestOverallSellLots = 0;
   double totalOverallSellLots = 0;

   double totalOverallLots = 0;

   double buyLots = 0;
   double sellLots = 0;

   double symbolProfit = 0;

   for(int i = 0; i < PositionsTotal(); i++)
     {
     
      position.SelectByIndex(i);
      symbolProfit = position.Profit();
      if(position.PositionType() == POSITION_TYPE_BUY && position.Symbol() == symbol && position.Magic() == magicNumber)
        {
         buyPositions++;
         positions++;
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
      if(position.PositionType() == POSITION_TYPE_SELL && position.Symbol() == symbol && position.Magic() == magicNumber)
        {
         sellPositions++;
         positions++;
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


   double targetSellProfit = targetProfit*((positions)*gridStepProfitMultiplier);
   double targetBuyProfit = targetProfit*((positions)*gridStepProfitMultiplier);
   double targetOverallProfit = targetProfit*(positions*gridStepProfitMultiplier);

   if(sellProfit > targetSellProfit)
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

   if(buyProfit > targetBuyProfit)
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

   if(buyProfit+sellProfit > targetOverallProfit && (lowestSellPrice > highestBuyPrice))
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
     
   if(lowestBuyPrice-((lowestBuyPrice/100*gridStep)*((buyPositions*gridStepMultiplier)+1)) >= ask && buyLots != 0 && buyPositions < maxGridSteps && !IsNetting())
     {
      double volume = buyPositions*initialLots*lotMultiplier > highestBuyLots*lotMultiplier ? buyPositions*initialLots*lotMultiplier : highestBuyLots*lotMultiplier;
      //volume = NormalizeDouble(lotStep*MathRound(volume/lotStep),lotDecimals);
      volume =  NormalizeDouble(volume < lotMin ? lotMin : volume > lotMax ? lotMax : volume,lotDecimals);

      if(CheckMoneyForTrade(symbol,volume,ORDER_TYPE_BUY) && totalOverallLots+volume < lotMax)
        {
         trade.Buy(volume,symbol,0,0,0,"MintyGrid Buy " + symbol + " step " + IntegerToString(buyPositions + 1));
        }

     }

   if(highestSellPrice+((highestSellPrice/100*gridStep)*((sellPositions*gridStepMultiplier)+1)) <= bid && sellLots != 0 && sellPositions < maxGridSteps && !IsNetting())
     {
      double volume = sellPositions*initialLots*lotMultiplier > highestSellLots*lotMultiplier ? sellPositions*initialLots*lotMultiplier : highestSellLots*lotMultiplier;
      //volume = NormalizeDouble(lotStep*MathRound(volume/lotStep),lotDecimals);
      volume = NormalizeDouble(volume < lotMin ? lotMin : volume > lotMax ? lotMax : volume,lotDecimals);

      if(CheckMoneyForTrade(symbol,volume,ORDER_TYPE_SELL) && CheckVolumeValue(symbol,volume) && totalOverallLots+volume < lotMax)
        {
         trade.Sell(volume,symbol,0,0,0,"MintyGrid Sell " + symbol + " step " + IntegerToString(sellPositions + 1));
        }
     }

   if((buyPositions == 0) && (sellPositions == 0 || (ask < highestSellPrice && sell)) && buy)
     {
      double highestLot = sellPositions == 0 ? 0 : sellLots/sellPositions/lotDeviser;
      double volume = highestLot < initialLots ? initialLots : highestLot;
      //volume = NormalizeDouble(lotStep*MathRound(volume/lotStep),lotDecimals);
      volume =  NormalizeDouble(volume < lotMin ? lotMin : volume > lotMax ? lotMax : volume,lotDecimals);
      
      if(IsNetting()) {
         volume = lotMin;
      }
      
      if(CheckMoneyForTrade(symbol,volume,ORDER_TYPE_BUY) && CheckVolumeValue(symbol,volume) && totalOverallLots+volume < lotMax)
        {
         trade.Buy(volume,symbol,0,0,0,"MintyGrid Buy " + symbol + " step " + IntegerToString(buyPositions + 1));
        }
     }

   if((sellPositions == 0) && (buyPositions == 0 || (bid > lowestBuyPrice && buy)) && sell)
     {
      double highestLot = buyPositions == 0 ? 0 : buyLots/buyPositions/lotDeviser;
      double volume = highestLot < initialLots ? initialLots : highestLot;
      //volume = NormalizeDouble(lotStep*MathRound(volume/lotStep),lotDecimals);
      volume = NormalizeDouble(volume < lotMin ? lotMin : volume > lotMax ? lotMax : volume,lotDecimals);

      if(IsNetting()) {
         volume = lotMin;
      }

      if(CheckMoneyForTrade(symbol,volume,ORDER_TYPE_SELL) && totalOverallLots+volume < lotMax)
        {
         trade.Sell(volume,symbol,0,0,0,"MintyGrid Sell " + symbol + " step " + IntegerToString(sellPositions + 1));
        }
     }

   closeOpenPositions();

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

bool IsNetting()
  {
   ENUM_ACCOUNT_MARGIN_MODE res = (ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE);
   return(res==ACCOUNT_MARGIN_MODE_RETAIL_NETTING);
  }