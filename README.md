# GreenLionEurUsd

Expert Advisor em **MQL5** para **MetaTrader 5**, focado no par **EURUSD**.

O projeto implementa um modelo híbrido com:
- **Trend Pullback Continuation**
- **Session Compression Breakout**
- filtros de regime, spread, sessão, volatilidade e drawdown
- gestão de risco por lote fixo ou percentagem

O ficheiro principal do EA é:

```text
/home/runner/work/GreenLionEurUsd/GreenLionEurUsd/GreenLionEurUsd.mq5
```

## Estratégia implementada

### 1. Regime filter

O EA só procura entradas quando:
- **H4 EMA 50** está claramente acima/abaixo da **H4 EMA 200**
- existe separação mínima entre médias
- **RSI H1** não está preso em zona neutra
- **MACD H1** confirma direção
- **ATR H1** está dentro de um intervalo aceitável
- o spread atual está abaixo do limite

### 2. Setup A — Trend Pullback Continuation

Compra:
- bias bullish em H4/H1
- preço H1 acima da EMA 200
- retracção para zona EMA 20/50
- candle bullish de rejeição ou engulfing em M15
- RSI M15 acima de 50 e a recuperar
- MACD M15 a reacelerar
- filtro de exaustão com Bollinger Bands

Venda:
- lógica simétrica

### 3. Setup B — Session Compression Breakout

Compra:
- cálculo do range asiático em M15
- ativação apenas na janela de breakout de Londres
- range asiático dentro de tamanho aceitável
- breakout acima do range com buffer
- squeeze/expansão de Bollinger
- confirmação de MACD

Venda:
- lógica simétrica

## Gestão de risco e execução

- **CTrade** para execução
- **Magic Number** dedicado
- nunca abre ordens sem **Stop Loss**
- nunca abre ordens sem validação de **spread**
- evita múltiplas entradas no mesmo candle
- permite **lote fixo** ou **risco por percentagem**
- reduz risco após perdas consecutivas no dia
- limita trades por dia
- bloqueia novas entradas ao atingir drawdown diário/semanal
- faz **break-even**
- faz **trailing stop**
- tenta **parcial em 1R**

## Inputs principais

Os inputs estão organizados por grupos:

- `GEN_` — geral
- `RISK_` — risco e sizing
- `ENTRY_` — lógica de entrada
- `EXIT_` — gestão de posição
- `FILTER_` — spread, sessão, volatilidade e horário
- `UI_` — logs

## Funções principais do EA

O EA segue a estrutura pedida:

- `OnInit`
- `OnDeinit`
- `OnTick`
- `CheckNewBar`
- `GetSpreadPoints`
- `CalculateLotSize`
- `CheckBuySignal`
- `CheckSellSignal`
- `OpenBuy`
- `OpenSell`
- `ManageOpenPositions`
- `ApplyTrailingStop`
- `WriteLog`

## Compilação

Não existe build pipeline no repositório.

Compilar no **MetaEditor / MetaTrader 5**:

1. Abrir o ficheiro `GreenLionEurUsd.mq5`
2. Carregar no MetaEditor
3. Compilar com **F7**
4. Corrigir qualquer diferença específica do terminal/broker, se existir

> Neste ambiente de tarefa não existe `MetaEditor`, por isso a compilação final não pôde ser executada aqui.

## Backtest recomendado

### Ambiente

- símbolo: **EURUSD**
- modo: **Every tick based on real ticks**
- spread variável
- slippage realista
- comissão configurada, se aplicável

### Intervalo

```text
01-01-2015 até à data atual
```

### Processo sugerido

1. **Backtest bruto**
2. **Backtest com custos realistas**
3. **Otimização limitada**
4. **Walk-forward**
5. **Sensitivity tests**
6. **Stress tests**
7. **Forward demo**

## Walk-forward sugerido

Modelo principal:
- **24 meses in-sample**
- **6 meses out-of-sample**
- avançando em blocos de 6 meses desde 2015

Alternativa:
- 2015-2018 treino
- 2019 validação
- 2020-2022 treino
- 2023 validação
- 2024-hoje forward/OOS

## Parâmetros que podem ser otimizados

Otimizar poucos parâmetros de cada vez:
- períodos EMA
- multiplicador ATR do stop
- target RR
- spread máximo
- piso/teto de ATR
- janelas horárias

Evitar:
- thresholds excessivos
- combinações demasiado finas
- tuning para um único período

## Critérios mínimos de robustez

- **max drawdown** preferível abaixo de **10-12%**
- **profit factor OOS** preferível acima de **1.15**
- **expectancy** positiva
- número suficiente de trades por janela agregada
- baixa degradação entre IS e OOS

## Limitação atual

O input `FILTER_UseNewsFilter` existe, mas a versão atual do EA não bloqueia notícias automaticamente sem integração adicional com um calendário económico externo ou fluxo calendar nativo do terminal.

## Fontes de referência usadas no plano

- MQL5 Documentation — https://www.mql5.com/en/docs/indicators
- MetaTrader 5 Help — https://www.metatrader5.com/en/terminal/help/algotrading/trade_robots_indicators
- MQL5 Articles — https://www.mql5.com/en/articles/expert_advisors
- BabyPips — https://www.babypips.com/learn/forex/session-overlaps
- ATFX — https://www.atfx.com/en/analysis/trading-strategies/best-time-to-trade-eurusd
- The Forex Geek — https://theforexgeek.com/eurusd-trading-strategy/
- Price Action Lab — https://www.priceactionlab.com/Blog/2023/02/combining-trend-following-mean-reversion/
- QuantInsti — https://blog.quantinsti.com/indicators-build-trend-following-strategy/
- NetPicks — https://www.netpicks.com/how-to-combine-trading-indicators/
- LuxAlgo — https://www.luxalgo.com/blog/technical-indicators-types-and-how-they-work/
- LuxAlgo Risk — https://www.luxalgo.com/blog/risk-management-strategies-for-algo-trading/
- DailyForex — https://www.dailyforex.com/forex-articles/algorithmic-trading-risk-management/216030
- FIA Risk Controls — https://www.fia.org/sites/default/files/2024-07/FIA_WP_AUTOMATED%20TRADING%20RISK%20CONTROLS_FINAL_0.pdf
