# MintyGrid
MintyGrid is a simple EA that does not use indicators nor market averages to trade. MintyGrid always buys and/or sells. On winning trades MintyGrid will take profit based on configuration. On losing trades MintyGrid uses a grid strategy to place resistance points using a martingale/reverse-martingale strategy to be prepared for when the market swings in the opposite direction. MintyGrid can be configured to run on many currency pairs simultaneously and will work as long as the pairs are similar in price.

Recommended usage is on a cent account with at least 300 EUR (30000 Euro Cents) and high leverage. Or 30000 EUR on a standard account if you want to take a big risk. It is not recommended to run MintyGrid alongside other EAs. If you wish to run it is advised to run MintyGrid on its own trading account with no more than 10% of your assets, use only assets you are prepared to possibly lose. MintyGrid is aggressive and effective but risky. MintyGrid does not use stop losses, your entire account balance is at risk.

By default MintyGrid runs on EURUSD, timeframe is irrelevant.

MintyGrid does not work well on netting accounts. MintyGrid works best on forex brokers with a 0.01 lot size and lot step.

Always backtest before using. It is not recommended to run MintyGrid alongside other EAs.

Install for free through [MetaTrader5 Market](https://www.mql5.com/en/market/product/78764)


# DISCLAIMER
Use at own risk, this strategy is effective but not foolproof.


### Copyright notice

Redistribution and use in source and binary forms, with or
without modification, are permitted provided that the following
conditions are met:

- Redistributions of source code must retain the above
copyright notice, this list of conditions and the following
disclaimer.
- Redistributions in binary form must reproduce the above
copyright notice, this list of conditions and the following
disclaimer in the documentation and/or other materials
provided with the distribution.
- All advertising materials mentioning features or use of this
software must display the following acknowledgement:
This product includes software developed by
Christopher Benjamin Hemmens.
- Neither the name of the Christopher Benjamin Hemmens nor the  
names of its contributors may be used to endorse or promote
products derived from this software without specific prior
written permission.

THIS SOFTWARE IS PROVIDED BY Christopher Benjamin Hemmens AS
IS AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT   
SHALL Christopher Benjamin Hemmens BE LIABLE FOR ANY DIRECT,   
INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF 
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF 
THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY  
OF SUCH DAMAGE.
