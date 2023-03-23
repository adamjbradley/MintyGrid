# MintyGrid

MintyGrid is a simple EA that does not use indicators nor market averages to trade. MintyGrid always buys and/or sells. On winning trades MintyGrid will take profit based on configuration. On losing trades MintyGrid uses a grid strategy to place resistance points using a martingale/reverse-martingale strategy to be prepared for when the market swings in the opposite direction. MintyGrid can be configured to run on many currency pairs simultaneously and will work as long as the pairs are similar in price. MintyGrid does not try predict market movements in any way or form. MintyGrid always trades within its grid configuration. MintyGrid depends on market movements to function and does not depend on time factors other than betting that the price will change. The quicker market prices change the quicker MintyGrid will place trades depending on configuration.

Recommended usage is on a cent account with at least 100 EUR (10000 Euro Cents) and high leverage. Or 10000 EUR on a standard account if you want to take a big risk. It is not recommended to run MintyGrid alongside other EAs. If you wish to run it is advised to run MintyGrid on its own trading account with no more than 10% of your assets, use only assets you are prepared to possibly lose. MintyGrid is aggressive and effective but risky. MintyGrid does not use stop losses, your entire account balance is at risk. MintyGrid does not work well on netting accounts. MintyGrid works best on forex brokers with a 0.01 lot size and lot step. Backtesting is a must, you should try find settings that satisfy your need between risk and reward. Note it is possible to find really risky settings that give huge rewards, but keep in mind a slight tweak in the settings can also cause catastrophic failure. There is a very fine line between good settings, and settings that will lose everything. Settings must be well balanced together to produce an effective and good result. It is recommended to optimize the strategy yourself using the strategy tester. It is recommended to withdraw any profits from MintyGrid regularly and have a good exit strategy as MintyGrid is prone to failing on massive market swings. It is possible to find settings that run for long periods of time, generally they tend to be less profitable.

By default MintyGrid runs on EURUSD, timeframe is irrelevant.

# Always backtest before using.

Download and install on MetaTrader 5 Marketplace [https://www.mql5.com/en/market/product/78764](https://www.mql5.com/en/market/product/78764)

### CONFIGURATION PARAMETERS

| Type | Name | Description |
|---|---|---|
| double | minInitialRiskFactor | Initial risk factor, percentage of risk base by minimum lot  |
| double | profitFactor | Profit factor, percentage of risk base  |
| enum | riskBase | Factor to base risk on (Balance or Equity) |
| double | lotMultiplier | Grid step martingale lot multiplier |
| double | lotDeviser | Grid reverse martingale lot deviser |
| double | gridStep | Grid step price movement percentage |
| int | maxGridSteps | Maximum amount of positions per direction |
| double | gridStepMultiplier | Grid step distance multiplier |
| bool | buy | Whether to enable buy trades |
| bool | sell | Whether to enable sell trades |
| string | currencyPairs | Symbols to trade comma separated (EURUSD,EURGBP,GBPUSD) |
| int | magicNumber | Expert Advisor Magic Number |

### Lot calculation

Initial lot formula where `riskBase` is `Equity` :

```
accountEquity/100*minInitialRiskFactor*minimumLotSize
```

Example where minimumLotSize = 0.01:
| accountEquity | minInitialRiskFactor | formula | initial lot size |
|---|---|---|---|
| 10000 | 0.01 | 10000 / 100 * 0.01*0.01 | 0.01 |
| 20000 | 0.01  | 20000 / 100 * 0.01*0.01 | 0.02 |
| 30000 | 0.01  | 30000 / 100 * 0.01*0.01 | 0.03 |
| 40000 | 0.01  | 40000 / 100 * 0.01*0.01 | 0.04 |
| 50000 | 0.01  | 50000 / 100 * 0.01 * 0.01 | 0.05 |
| 10000 | 0.02 | 10000 / 100 * 0.02 * 0.01 | 0.02 |
| 20000 | 0.02  | 20000 / 100 * 0.02 * 0.01 | 0.04 |
| 30000 | 0.02  | 30000 / 100 * 0.02 * 0.01 | 0.06 |
| 40000 | 0.02  | 40000 / 100 * 0.02 * 0.01 | 0.08 |
| 50000 | 0.02  | 50000 / 100 * 0.02 * 0.01 | 0.1 |


# DISCLAIMER
Use at own risk, this strategy is effective but not foolproof.

THIS SOFTWARE IS PROVIDED BY Christopher Benjamin Hemmens AS IS AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL Christopher Benjamin Hemmens BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


# COPYRIGHT NOTICE
Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

Redistributions of source code must retain the above copyright notice, this list of conditions and the above disclaimer.
Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the above disclaimer in the documentation and/or other materials provided with the distribution.
All advertising materials mentioning features or use of this software must display the following acknowledgement: This product includes software developed by Christopher Benjamin Hemmens.
Neither the name of the Christopher Benjamin Hemmens nor the
names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.






